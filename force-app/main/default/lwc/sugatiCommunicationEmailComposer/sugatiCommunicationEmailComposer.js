import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTemplates from '@salesforce/apex/SugatiCommunicationHubController.getTemplates';
import getOpportunityAttachments from '@salesforce/apex/SugatiCommunicationHubController.getOpportunityAttachments';
import saveDraftDirect from '@salesforce/apex/SugatiCommunicationHubController.saveDraftDirect';
import discardDraftDirect from '@salesforce/apex/SugatiCommunicationHubController.discardDraftDirect';

const MAX_ATTACHMENT_BYTES = 4.5 * 1024 * 1024;
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import USER_NAME from '@salesforce/schema/User.Name';
import USER_EMAIL from '@salesforce/schema/User.Email';

const DEBUG_PREVIEW_FLOW = true;

export default class SugatiCommunicationEmailComposer extends LightningElement {
    @api opportunityId;
    @api tripName = '';
    @api stageLabel = '';
    @api openWithTemplatePicker = false;

    toChips = [];
    ccChips = [];
    subject = '';
    activeTemplateName = '';
    activeTemplateMeta = '';
    activeTemplateId = null;
    templateSearch = '';
    activeFolder = 'all';
    deliveryMode = 'postmark';
    showAiAssist = false;
    attCount = 0;
    _pickerOpenRequested = false;
    isSavingDraft = false;
    isDiscarding = false;
    editingCommLogId = null;
    bodyTemplate = '';
    currentUserName = '';
    currentUserEmail = '';
    _lastFocusedField = 'body';
    _subjectCursorPos = 0;
    _bodyCursorPos = 0;
    _bodySelectionRange = null;
    _editorSyncedHtml = null;

    _templates = [];
    _attachments = [];
    _opportunityFiles = [];
    _pendingUploads = [];
    _draftSelectedDocIds = null;
    _draftAttachmentRows = [];
    _draftForEditPayload = null;
    isUploadingAttachments = false;

    @api
    get draftForEdit() {
        return this._draftForEditPayload;
    }

    set draftForEdit(value) {
        this._draftForEditPayload = value;
        if (value) {
            this.loadDraft(value);
        }
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME, USER_EMAIL] })
    wiredCurrentUser({ data }) {
        if (!data) return;
        this.currentUserName = data.fields.Name?.value || '';
        this.currentUserEmail = data.fields.Email?.value || '';
    }

    @wire(getOpportunityAttachments, { opportunityId: '$opportunityId' })
    wiredOpportunityAttachments({ data, error }) {
        if (data) {
            this._opportunityFiles = data;
            this.rebuildAttachmentList();
            if (this._draftSelectedDocIds || (this._draftAttachmentRows || []).length) {
                this.applySelectedAttachmentIds([...(this._draftSelectedDocIds || [])]);
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Failed to load opportunity attachments', error);
        }
    }

    connectedCallback() {
        if (!this._draftForEditPayload) {
            this.restoreDraft();
        }
        if (this.openWithTemplatePicker && !this._pickerOpenRequested) {
            this._pickerOpenRequested = true;
            this.dispatchEvent(
                new CustomEvent('opentemplates', {
                    bubbles: true,
                    composed: true
                })
            );
        }
        this.loadTemplates();
    }

    renderedCallback() {
        this.syncBodyEditorFromState();
    }

    get draftStorageKey() {
        return `sugati.email.draft.${this.opportunityId || 'default'}`;
    }

    persistDraft() {
        try {
            const payload = {
                toChips: this.toChips || [],
                ccChips: this.ccChips || [],
                subject: this.subject || '',
                bodyTemplate: this.bodyTemplate || '',
                activeTemplateName: this.activeTemplateName || '',
                activeTemplateMeta: this.activeTemplateMeta || '',
                activeTemplateId: this.activeTemplateId || null,
                editingCommLogId: this.editingCommLogId || null,
                deliveryMode: this.deliveryMode || 'postmark',
                lastFocusedField: this._lastFocusedField || 'body',
                subjectCursorPos: this._subjectCursorPos || 0,
                bodyCursorPos: this._bodyCursorPos || 0,
                selectedAttachmentIds: this.getSelectedContentDocumentIds(),
                pendingAttachmentNames: (this._pendingUploads || []).map((p) => p.name)
            };
            window.localStorage.setItem(this.draftStorageKey, JSON.stringify(payload));
        } catch (e) {
            // ignore storage errors
        }
    }

    clearDraftStorage() {
        try {
            window.localStorage.removeItem(this.draftStorageKey);
        } catch (e) {
            // ignore storage errors
        }
    }

    restoreDraft() {
        try {
            const raw = window.localStorage.getItem(this.draftStorageKey);
            if (!raw) return;
            const payload = JSON.parse(raw);
            this.toChips = Array.isArray(payload.toChips) ? payload.toChips : [];
            this.ccChips = Array.isArray(payload.ccChips) ? payload.ccChips : [];
            this.subject = payload.subject || '';
            this.bodyTemplate = payload.bodyTemplate || '';
            this.activeTemplateName = payload.activeTemplateName || '';
            this.activeTemplateMeta = payload.activeTemplateMeta || '';
            this.activeTemplateId = payload.activeTemplateId || null;
            this.editingCommLogId = payload.editingCommLogId || null;
            this.deliveryMode = payload.deliveryMode || 'postmark';
            this._lastFocusedField = payload.lastFocusedField || 'body';
            this._subjectCursorPos = payload.subjectCursorPos || 0;
            this._bodyCursorPos = payload.bodyCursorPos || 0;
            if (Array.isArray(payload.selectedAttachmentIds)) {
                this.applySelectedAttachmentIds(payload.selectedAttachmentIds);
            }
        } catch (e) {
            // ignore parse errors
        }
    }

    get railRecipients() {
        return this.toChips.map((c) => ({
            ...c,
            role: c.role || 'Traveller'
        }));
    }

    get folderTabs() {
        const folders = ['all', 'traveller', 'supplier', 'ops', 'compliance', 'finance'];
        const labels = { all: 'All', traveller: 'Traveller', supplier: 'Supplier', ops: 'Ops', compliance: 'Compliance', finance: 'Finance' };
        return folders.map((f) => ({
            id: f,
            label: labels[f],
            className: f === this.activeFolder ? 'tmpl-ftab on' : 'tmpl-ftab'
        }));
    }

    get filteredTemplates() {
        const q = (this.templateSearch || '').toLowerCase();
        return this._templates
            .filter((t) => this.activeFolder === 'all' || t.folder === this.activeFolder)
            .filter((t) => !q || t.name.toLowerCase().includes(q))
            .map((t) => ({
                ...t,
                itemClass: t.active ? 'tmpl-item on' : 'tmpl-item',
                stageClass: `tmpl-stage-badge ${t.stage}`
            }));
    }

    @api
    async refreshTemplates() {
        await this.loadTemplates();
    }

    get attachments() {
        return this._attachments.map((a) => ({
            ...a,
            cbClass: a.checked ? 'att-cb ck' : 'att-cb',
            icClass: a.type === 'pdf' ? 'att-ic ic-pdf' : 'att-ic ic-gen'
        }));
    }

    get deliveryPostmarkClass() {
        return this.deliveryMode === 'postmark' ? 'del-opt on' : 'del-opt';
    }

    get deliveryNativeClass() {
        return this.deliveryMode === 'native' ? 'del-opt on' : 'del-opt';
    }

    get attCountLabel() {
        return `${this.attCount} selected`;
    }

    get recipientSummary() {
        return this.toChips.map((c) => c.name.split(' ')[0]).join(' & ') || 'Recipients';
    }

    get fromDisplay() {
        if (this.currentUserName && this.currentUserEmail) {
            return `${this.currentUserName} <${this.currentUserEmail}>`;
        }
        return this.currentUserName || this.currentUserEmail || 'Current User';
    }

    @api
    setRecipients(recipients) {
        if (recipients && recipients.length) {
            this.toChips = recipients.map((r, i) => this.mapSelectorRecipientToChip(r, i, 'r'));
        } else {
            this.toChips = [];
        }
        this.persistDraft();
    }

    @api
    setCcRecipients(recipients) {
        if (recipients && recipients.length) {
            this.ccChips = recipients.map((r, i) => this.mapSelectorRecipientToChip(r, i, 'cc'));
        } else {
            this.ccChips = [];
        }
        this.persistDraft();
    }

    mapSelectorRecipientToChip(recipient, index, prefix) {
        return {
            id: recipient.id || `${prefix}-${index}`,
            commRecipientId: recipient.commRecipientId || null,
            contactId: this.resolveContactIdForChip({ ...recipient, audience: recipient.audience }),
            audience: recipient.audience || 'travellers',
            initials: recipient.initials,
            name: recipient.name,
            email: recipient.email,
            role: recipient.role
        };
    }

    mapDraftRecipientToChip(recipient, index) {
        const contactId = recipient.contactId || null;
        return {
            id: contactId || recipient.commRecipientId || `draft-${index}`,
            commRecipientId: recipient.commRecipientId || null,
            contactId,
            initials: this.buildInitialsFromName(recipient.name || recipient.email),
            name: recipient.name || recipient.email,
            email: recipient.email,
            role: recipient.role || 'Traveller'
        };
    }

    isSalesforceId(value) {
        return value && /^[a-zA-Z0-9]{15,18}$/.test(value);
    }

    isContactId(value) {
        return this.isSalesforceId(value) && value.substring(0, 3) === '003';
    }

    resolveContactIdForChip(chip) {
        if (chip.contactId && this.isContactId(chip.contactId)) {
            return chip.contactId;
        }
        const audience = chip.audience || '';
        if (audience === 'travellers' && chip.id && this.isContactId(chip.id)) {
            return chip.id;
        }
        return null;
    }

    buildInitialsFromName(fullName) {
        if (!fullName) {
            return '--';
        }
        const parts = fullName.trim().split(/\s+/);
        if (!parts.length) {
            return '--';
        }
        const first = parts[0].charAt(0).toUpperCase();
        const second = parts.length > 1 ? parts[1].charAt(0).toUpperCase() : first;
        return `${first}${second}`;
    }

    @api
    loadDraft(draft) {
        if (!draft) {
            return;
        }
        this.editingCommLogId = draft.commLogId || null;
        this.subject = draft.subject || '';
        this.bodyTemplate = draft.bodyHtml || '';
        this.deliveryMode = draft.deliveryMode || 'postmark';
        this.toChips = (draft.recipients || []).map((recipient, index) =>
            this.mapDraftRecipientToChip(recipient, index)
        );
        this.ccChips = [];
        this.activeTemplateId = null;
        this.activeTemplateName = '';
        this.activeTemplateMeta = '';
        this.templateSearch = '';
        this._templates = (this._templates || []).map((t) => ({ ...t, active: false }));
        this._editorSyncedHtml = null;
        this._bodySelectionRange = null;
        this._bodyCursorPos = this.plainTextFromHtml(this.bodyTemplate).length;
        this.applyDraftAttachments(draft.attachments || []);
        try {
            window.localStorage.removeItem(this.draftStorageKey);
        } catch (e) {
            // ignore storage errors
        }
        requestAnimationFrame(() => {
            this.syncBodyEditorFromState();
            this.focusBodyAtCursor();
        });
        this.persistDraft();
    }

    applyDraftAttachments(attachmentRows) {
        const rows = attachmentRows || [];
        this._draftAttachmentRows = rows.filter((row) => row.contentDocumentId);
        this._draftSelectedDocIds = new Set(
            rows.filter((row) => row.selected && row.contentDocumentId).map((row) => row.contentDocumentId)
        );
        this.rebuildAttachmentList();
    }

    applySelectedAttachmentIds(selectedIds) {
        const selectedSet = new Set(selectedIds || []);
        if (selectedIds && selectedIds.length) {
            this._draftSelectedDocIds = selectedSet;
        }
        this._attachments = (this._attachments || []).map((row) => ({
            ...row,
            checked: row.contentDocumentId ? selectedSet.has(row.contentDocumentId) : row.checked
        }));
        this.updateAttCount();
    }

    getSelectedContentDocumentIds() {
        return (this._attachments || [])
            .filter((row) => row.checked && row.contentDocumentId)
            .map((row) => row.contentDocumentId);
    }

    rebuildAttachmentList() {
        const rows = [];
        const seen = new Set();
        const selectedSet = this._draftSelectedDocIds || new Set();

        (this._pendingUploads || []).forEach((pending) => {
            rows.push(pending);
            seen.add(pending.id);
        });

        (this._opportunityFiles || []).forEach((fileRow) => {
            const docId = fileRow.contentDocumentId;
            if (!docId || seen.has(docId)) {
                return;
            }
            const existing = (this._attachments || []).find((row) => row.contentDocumentId === docId);
            const checkedFromDraft = selectedSet.has(docId);
            rows.push({
                id: docId,
                contentDocumentId: docId,
                name: fileRow.name,
                meta: fileRow.meta || 'File',
                type: fileRow.fileType === 'pdf' ? 'pdf' : 'gen',
                checked: existing ? !!existing.checked : checkedFromDraft || !!fileRow.selected,
                pending: false
            });
            seen.add(docId);
        });

        (this._draftAttachmentRows || []).forEach((fileRow) => {
            const docId = fileRow.contentDocumentId;
            if (!docId || seen.has(docId)) {
                return;
            }
            rows.push({
                id: docId,
                contentDocumentId: docId,
                name: fileRow.name,
                meta: fileRow.meta || 'File',
                type: fileRow.fileType === 'pdf' ? 'pdf' : 'gen',
                checked: !!fileRow.selected || selectedSet.has(docId),
                pending: false
            });
            seen.add(docId);
        });

        this._attachments = rows;
        this.updateAttCount();
    }

    updateAttCount() {
        this.attCount = (this._attachments || []).filter((row) => row.checked).length;
    }

    buildDraftAttachmentArrays() {
        const selected = (this._attachments || []).filter((row) => row.checked);
        return {
            attachmentContentDocumentIds: selected
                .filter((row) => row.contentDocumentId)
                .map((row) => row.contentDocumentId),
            newAttachmentFileNames: selected.filter((row) => row.pending).map((row) => row.name),
            newAttachmentFileData: selected.filter((row) => row.pending).map((row) => row.base64Data)
        };
    }

    getSelectedAttachmentsForPayload() {
        return (this._attachments || [])
            .filter((row) => row.checked)
            .map((row) => ({
                contentDocumentId: row.contentDocumentId || null,
                name: row.name,
                type: row.type,
                meta: row.meta,
                pending: !!row.pending,
                fileData: row.pending ? row.base64Data : null,
                checked: true
            }));
    }

    async handleFilesSelected(event) {
        const files = Array.from(event.target.files || []);
        event.target.value = '';
        if (!files.length) {
            return;
        }
        this.isUploadingAttachments = true;
        try {
            const additions = [];
            for (const file of files) {
                if (file.size > MAX_ATTACHMENT_BYTES) {
                    this.showToast('File too large', `"${file.name}" exceeds the 4.5 MB limit.`, 'error');
                    continue;
                }
                const base64Data = await this.readFileAsBase64(file);
                additions.push({
                    id: `pending-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
                    contentDocumentId: null,
                    name: file.name,
                    meta: this.formatFileSize(file.size),
                    type: this.inferFileType(file.name),
                    checked: true,
                    pending: true,
                    base64Data
                });
            }
            if (additions.length) {
                this._pendingUploads = [...(this._pendingUploads || []), ...additions];
                this.rebuildAttachmentList();
                this.persistDraft();
                this.showToast('Files added', `${additions.length} file(s) ready to include with this message.`, 'success');
            }
        } catch (e) {
            this.showToast('Upload failed', e?.message || 'Unable to read selected file(s).', 'error');
        } finally {
            this.isUploadingAttachments = false;
        }
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = () => reject(new Error('Unable to read file.'));
            reader.readAsDataURL(file);
        });
    }

    formatFileSize(bytes) {
        if (!bytes) {
            return '0 B';
        }
        if (bytes < 1024) {
            return `${bytes} B`;
        }
        if (bytes < 1024 * 1024) {
            return `${Math.round(bytes / 1024)} KB`;
        }
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }

    inferFileType(fileName) {
        const lower = (fileName || '').toLowerCase();
        return lower.endsWith('.pdf') ? 'pdf' : 'gen';
    }

    @api
    getRecipientState() {
        return {
            to: [...this.toChips],
            cc: [...this.ccChips]
        };
    }

    @api
    resetComposer() {
        this.editingCommLogId = null;
        this.toChips = [];
        this.ccChips = [];
        this.subject = '';
        this.bodyTemplate = '';
        this.activeTemplateName = '';
        this.activeTemplateMeta = '';
        this.activeTemplateId = null;
        this.templateSearch = '';
        this.deliveryMode = 'postmark';
        this._lastFocusedField = 'body';
        this._subjectCursorPos = 0;
        this._bodyCursorPos = 0;
        this._bodySelectionRange = null;
        this._editorSyncedHtml = '';
        this._templates = (this._templates || []).map((t) => ({ ...t, active: false }));
        this._attachments = [];
        this._pendingUploads = [];
        this._draftSelectedDocIds = null;
        this._draftAttachmentRows = [];
        this._draftForEditPayload = null;
        this.attCount = 0;
        this.rebuildAttachmentList();
        this.clearDraftStorage();
        requestAnimationFrame(() => {
            const editor = this.template?.querySelector('.editor-body');
            if (editor) {
                editor.innerHTML = '';
            }
        });
    }

    @api
    getComposeState() {
        return {
            subject: this.subject || '',
            bodyTemplate: this.bodyTemplate || '',
            activeTemplateId: this.activeTemplateId || null,
            activeTemplateName: this.activeTemplateName || '',
            activeTemplateMeta: this.activeTemplateMeta || '',
            lastFocusedField: this._lastFocusedField || 'body',
            subjectCursorPos: this._subjectCursorPos || 0,
            bodyCursorPos: this._bodyCursorPos || 0
        };
    }

    @api
    applyComposeState(state) {
        if (!state) return;
        this.subject = state.subject || '';
        this.bodyTemplate = state.bodyTemplate || '';
        this.activeTemplateId = state.activeTemplateId || null;
        this.activeTemplateName = state.activeTemplateName || '';
        this.activeTemplateMeta = state.activeTemplateMeta || '';
        this._lastFocusedField = state.lastFocusedField || 'body';
        this._subjectCursorPos = state.subjectCursorPos || 0;
        this._bodyCursorPos = state.bodyCursorPos || 0;
        this._bodySelectionRange = null;
        this._editorSyncedHtml = null;
        this._templates = this._templates.map((t) => ({ ...t, active: t.id === this.activeTemplateId }));
        requestAnimationFrame(() => {
            this.syncBodyEditorFromState();
            this.focusBodyAtCursor();
        });
        this.persistDraft();
    }

    handleRemoveChip(event) {
        const email = event.currentTarget.dataset.email;
        this.toChips = this.toChips.filter((c) => c.email !== email);
        this.persistDraft();
    }

    handleRemoveCcChip(event) {
        const email = event.currentTarget.dataset.email;
        this.ccChips = this.ccChips.filter((c) => c.email !== email);
        this.persistDraft();
    }

    handleFolderTab(event) {
        this.activeFolder = event.currentTarget.dataset.folder;
        this.templateSearch = '';
    }

    handleTemplateSearch(event) {
        this.templateSearch = event.target.value;
    }

    handleTemplateActivate(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this._templates = this._templates.map((t) => ({ ...t, active: t.id === id || t.name === name }));
        this.activeTemplateName = name;
        const active = this._templates.find((t) => t.active);
        this.activeTemplateId = active?.id || null;
        this.activeTemplateMeta = active ? active.meta : '';
        if (active?.subject) {
            this.subject = active.subject;
        }
        if (active?.body) {
            this.bodyTemplate = active.body || '';
            this._bodyCursorPos = this.plainTextFromHtml(this.bodyTemplate).length;
            this._editorSyncedHtml = null;
            requestAnimationFrame(() => this.syncBodyEditorFromState());
        }
        this.persistDraft();
    }

    handleAttachmentToggle(event) {
        const id = event.currentTarget.dataset.id;
        this._attachments = this._attachments.map((a) => {
            if (a.id === id) {
                return { ...a, checked: !a.checked };
            }
            return a;
        });
        this._pendingUploads = (this._pendingUploads || []).map((row) => {
            const match = (this._attachments || []).find((att) => att.id === row.id);
            return match ? { ...row, checked: !!match.checked } : row;
        });
        this.updateAttCount();
        this.persistDraft();
    }

    handleDeliveryPostmark() {
        this.deliveryMode = 'postmark';
        this.persistDraft();
    }

    handleDeliveryNative() {
        this.deliveryMode = 'native';
        this.persistDraft();
    }

    handleOpenTemplates() {
        this.dispatchEvent(
            new CustomEvent('opentemplates', {
                bubbles: true,
                composed: true
            })
        );
    }

    @api
    applyTemplateSelection(detail) {
        const { name } = detail || {};
        if (name) {
            const selected = this._templates.find((t) => t.name === name);
            if (selected) {
                this.handleTemplateActivate({ currentTarget: { dataset: { name: selected.name, id: selected.id } } });
            }
        } else {
            this._templates = this._templates.map((t) => ({ ...t, active: false }));
            this.activeTemplateId = null;
            this.activeTemplateName = '';
            this.activeTemplateMeta = '';
            this.subject = '';
            this.bodyTemplate = '';
            this._bodyCursorPos = 0;
        }
        this.persistDraft();
    }

    handleFormatMouseDown(event) {
        event.preventDefault();
        this.captureBodySelection();
    }

    captureFieldCursor(field) {
        if (field === 'subject') {
            const input = this.template.querySelector('.subj-input');
            if (input && typeof input.selectionStart === 'number') {
                this._subjectCursorPos = input.selectionStart;
            }
            return;
        }
        this.captureBodySelection();
    }

    syncBodyEditorFromState() {
        const editor = this.template?.querySelector('.editor-body');
        if (!editor) {
            return;
        }
        const nextHtml = this.bodyTemplate || '';
        if (this._editorSyncedHtml === nextHtml && editor.innerHTML === nextHtml) {
            return;
        }
        if (document.activeElement === editor) {
            return;
        }
        editor.innerHTML = nextHtml;
        this._editorSyncedHtml = nextHtml;
    }

    captureBodySelection() {
        const editor = this.template?.querySelector('.editor-body');
        const selection = window.getSelection ? window.getSelection() : null;
        if (!editor || !selection || selection.rangeCount === 0) {
            return;
        }
        const range = selection.getRangeAt(0);
        if (!editor.contains(range.commonAncestorContainer)) {
            return;
        }
        this._bodySelectionRange = range.cloneRange();
        this._bodyCursorPos = this._textOffsetOf(editor, range.endContainer, range.endOffset);
    }

    restoreBodySelection(editor) {
        if (!editor) {
            return;
        }
        const selection = window.getSelection ? window.getSelection() : null;
        if (!selection) {
            return;
        }
        if (this._bodySelectionRange && editor.contains(this._bodySelectionRange.startContainer)) {
            selection.removeAllRanges();
            selection.addRange(this._bodySelectionRange);
            return;
        }
        const textLength = editor.textContent ? editor.textContent.length : 0;
        const pos = Math.max(0, Math.min(this._bodyCursorPos || 0, textLength));
        const point = this._findNodeAtTextOffset(editor, pos);
        if (!point) {
            return;
        }
        const range = document.createRange();
        range.setStart(point.node, point.offset);
        range.collapse(true);
        selection.removeAllRanges();
        selection.addRange(range);
        this._bodySelectionRange = range.cloneRange();
    }

    focusBodyAtCursor() {
        const editor = this.template.querySelector('.editor-body');
        if (!editor) {
            return;
        }
        editor.focus();
        this.restoreBodySelection(editor);
    }

    handleEditorAction(event) {
        event.preventDefault();
        const action = event.currentTarget?.dataset?.action;
        if (!action) {
            return;
        }
        const editor = this.template.querySelector('.editor-body');
        if (!editor) {
            return;
        }
        this._lastFocusedField = 'body';
        editor.focus();
        this.restoreBodySelection(editor);
        if (action === 'h1' || action === 'h2') {
            document.execCommand('formatBlock', false, action.toUpperCase());
        } else {
            document.execCommand(action, false, null);
        }
        this.bodyTemplate = editor.innerHTML;
        this._editorSyncedHtml = this.bodyTemplate;
        this.captureBodySelection();
        this.persistDraft();
    }

    handleOpenAi() {
        this.showAiAssist = true;
    }

    handleCloseAi() {
        this.showAiAssist = false;
    }

    handleAiApply(event) {
        const { mode, body, subjects } = event.detail;
        if (mode === 'subject' && subjects && subjects.length) {
            this.subject = subjects[0];
        } else if (body) {
            this.bodyTemplate = body || '';
            this._bodyCursorPos = this.plainTextFromHtml(this.bodyTemplate).length;
            this._editorSyncedHtml = null;
            requestAnimationFrame(() => this.syncBodyEditorFromState());
        }
        this.showAiAssist = false;
        this.persistDraft();
    }

    handleSubjectFocus() {
        this._lastFocusedField = 'subject';
    }

    handleSubjectChange(event) {
        this._lastFocusedField = 'subject';
        this.subject = event.target.value;
        this._subjectCursorPos = event.target.selectionStart ?? this.subject.length;
        this.persistDraft();
    }

    handleSubjectCursor(event) {
        this._lastFocusedField = 'subject';
        this._subjectCursorPos = event.target.selectionStart ?? (this.subject || '').length;
    }

    handleBodyFocus() {
        this._lastFocusedField = 'body';
        this.captureBodySelection();
    }

    handleBodyInput() {
        this._lastFocusedField = 'body';
        const editor = this.template.querySelector('.editor-body');
        this.bodyTemplate = editor ? editor.innerHTML : '';
        this._editorSyncedHtml = this.bodyTemplate;
        this.captureBodySelection();
        this.persistDraft();
    }

    handleBodyCursor() {
        this._lastFocusedField = 'body';
        this.captureBodySelection();
    }

    buildDraftRecipientArrays() {
        const chips = [...(this.toChips || []), ...(this.ccChips || [])];
        return {
            recipientRowIds: chips.map((chip) => chip.commRecipientId || null),
            recipientContactIds: chips.map((chip) => this.resolveContactIdForChip(chip)),
            recipientEmails: chips.map((chip) => chip.email || ''),
            recipientNames: chips.map((chip) => chip.name || chip.email || ''),
            recipientRoles: chips.map((chip) => chip.role || 'Traveller')
        };
    }

    buildDraftRequestPayload() {
        return {
            commLogId: this.editingCommLogId || null,
            opportunityId: this.opportunityId,
            templateId: this.activeTemplateId || null,
            ...this.buildDraftRecipientArrays(),
            ...this.buildDraftAttachmentArrays(),
            subjectTemplate: this.subject || '',
            bodyTemplate: this.bodyTemplate || '',
            deliveryMode: this.deliveryMode || 'postmark',
            channel: 'Email'
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    get hasComposeContent() {
        const hasBody =
            !!(this.bodyTemplate || '').trim() &&
            !!(this.bodyTemplate || '').replace(/<[^>]+>/g, '').trim();
        return (
            !!(this.subject || '').trim() ||
            hasBody ||
            (this.toChips || []).length > 0 ||
            (this.ccChips || []).length > 0
        );
    }

    async handleDiscard() {
        if (this.isDiscarding || this.isSavingDraft) {
            return;
        }

        const hasSavedDraft = !!this.editingCommLogId;
        if (!hasSavedDraft && !this.hasComposeContent) {
            this.resetComposer();
            return;
        }

        const message = hasSavedDraft
            ? 'Discard this draft? It will be permanently deleted.'
            : 'Discard this message? Your unsaved changes will be lost.';
        if (!window.confirm(message)) {
            return;
        }

        this.isDiscarding = true;
        try {
            if (hasSavedDraft) {
                await discardDraftDirect({ commLogId: this.editingCommLogId });
            }
            this.resetComposer();
            this.dispatchEvent(
                new CustomEvent('draftdiscarded', {
                    detail: { hadSavedDraft: hasSavedDraft },
                    bubbles: true,
                    composed: true
                })
            );
            this.showToast(
                'Discarded',
                hasSavedDraft ? 'Draft deleted.' : 'Message cleared.',
                'success'
            );
        } catch (e) {
            this.showToast(
                'Discard failed',
                e?.body?.message || e?.message || 'Unable to discard.',
                'error'
            );
        } finally {
            this.isDiscarding = false;
        }
    }

    async handleSaveDraft() {
        if (!this.opportunityId) {
            this.showToast('Cannot save draft', 'Opportunity is required.', 'error');
            return;
        }
        if (this.isSavingDraft) {
            return;
        }
        this.isSavingDraft = true;
        try {
            const payload = this.buildDraftRequestPayload();
            const wasUpdate = !!this.editingCommLogId;
            await saveDraftDirect(payload);
            this._pendingUploads = [];
            this.resetComposer();
            this.dispatchEvent(
                new CustomEvent('draftsaved', {
                    detail: { isUpdate: wasUpdate },
                    bubbles: true,
                    composed: true
                })
            );
            this.showToast(
                'Draft saved',
                wasUpdate ? 'Your draft has been updated.' : 'Your email has been saved as a draft.',
                'success'
            );
        } catch (e) {
            this.showToast('Save failed', e?.body?.message || e?.message || 'Unable to save draft.', 'error');
        } finally {
            this.isSavingDraft = false;
        }
    }

    handlePreview() {
        this.persistDraft();
        const detail = {
            channel: 'email',
            subject: this.subject,
            subjectTemplate: this.subject,
            bodyTemplate: this.bodyTemplate,
            recipients: this.toChips,
            ccRecipients: this.ccChips,
            fromLabel: this.fromDisplay,
            deliveryMode: this.deliveryMode,
            templateName: this.activeTemplateName,
            templateId: this.activeTemplateId,
            editingCommLogId: this.editingCommLogId || null,
            attachments: this.getSelectedAttachmentsForPayload(),
            ...this.buildDraftAttachmentArrays()
        };
        if (DEBUG_PREVIEW_FLOW) {
            console.log('[Composer] navigatepreview detail', JSON.parse(JSON.stringify(detail)));
        }
        this.dispatchEvent(
            new CustomEvent('navigatepreview', {
                detail
            })
        );
    }

    handleRecipientsNav() {
        this.dispatchEvent(new CustomEvent('navigaterecipients', { detail: { target: 'to' } }));
    }

    handleCcNav() {
        this.dispatchEvent(new CustomEvent('navigaterecipients', { detail: { target: 'cc' } }));
    }

    async loadTemplates() {
        if (!this.opportunityId) {
            return;
        }
        try {
            const rows = await getTemplates({
                opportunityId: this.opportunityId,
                stage: null,
                recipientType: null,
                channel: 'Email'
            });
            if (!rows?.length) {
                return;
            }
            this._templates = rows.map((t, idx) => ({
                // Keep all templates unselected until user explicitly chooses one.
                id: t.id,
                name: t.name,
                meta: t.meta,
                folder: this.mapFolder(t.type),
                stage: this.mapStage(t.stage),
                suggested: idx < 2,
                active: false,
                subject: t.subject,
                body: t.body
            }));
            if (this.activeTemplateId) {
                this._templates = this._templates.map((t) => ({ ...t, active: t.id === this.activeTemplateId }));
            }
        } catch (e) { }
    }

    mapFolder(type) {
        const key = (type || '').toLowerCase();
        if (key.includes('supplier')) return 'supplier';
        if (key.includes('ops')) return 'ops';
        if (key.includes('compliance')) return 'compliance';
        if (key.includes('finance')) return 'finance';
        return 'traveller';
    }

    mapStage(stage) {
        const val = (stage || '').toLowerCase();
        if (val.includes('pre')) return 'pre-dep';
        if (val.includes('book')) return 'booked';
        if (val.includes('proposal')) return 'proposal';
        if (val.includes('travelling')) return 'travelling';
        if (val.includes('post')) return 'post';
        return 'enquiry';
    }

    plainTextFromHtml(html) {
        if (!html) {
            return '';
        }
        return html
            .replace(/<br\s*\/?>/gi, '\n')
            .replace(/<\/p>/gi, '\n')
            .replace(/<[^>]+>/g, '')
            .replace(/&nbsp;/gi, ' ')
            .replace(/&amp;/gi, '&')
            .replace(/&lt;/gi, '<')
            .replace(/&gt;/gi, '>')
            .replace(/\n{3,}/g, '\n\n')
            .trim();
    }

    _textOffsetOf(root, node, offset) {
        let acc = 0;
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
        let current = walker.nextNode();
        while (current) {
            if (current === node) {
                return acc + offset;
            }
            acc += current.textContent ? current.textContent.length : 0;
            current = walker.nextNode();
        }
        return acc;
    }

    _findNodeAtTextOffset(root, targetOffset) {
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
        let acc = 0;
        let current = walker.nextNode();
        while (current) {
            const len = current.textContent ? current.textContent.length : 0;
            if (targetOffset <= acc + len) {
                return { node: current, offset: Math.max(0, targetOffset - acc) };
            }
            acc += len;
            current = walker.nextNode();
        }
        if (root.childNodes && root.childNodes.length > 0) {
            const last = root.childNodes[root.childNodes.length - 1];
            if (last.nodeType === Node.TEXT_NODE) {
                return { node: last, offset: last.textContent ? last.textContent.length : 0 };
            }
        }
        return null;
    }
}
