import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSendEmailTemplateCatalog from '@salesforce/apex/SugatiCommunicationHubController.getSendEmailTemplateCatalog';
import getRecordAttachments from '@salesforce/apex/SugatiCommunicationHubController.getRecordAttachments';
import getOrgWideFromAddresses from '@salesforce/apex/SugatiCommunicationHubController.getOrgWideFromAddresses';
import getSendEmailBccDefaults from '@salesforce/apex/SugatiCommunicationHubController.getSendEmailBccDefaults';
import getRecipients from '@salesforce/apex/SugatiCommunicationHubController.getRecipients';
import loadDefaultSendEmailTemplate from '@salesforce/apex/SugatiCommunicationHubController.loadDefaultSendEmailTemplate';
import loadSendEmailTemplate from '@salesforce/apex/SugatiCommunicationHubController.loadSendEmailTemplate';
import saveDraftDirect from '@salesforce/apex/SugatiCommunicationHubController.saveDraftDirect';
import discardDraftDirect from '@salesforce/apex/SugatiCommunicationHubController.discardDraftDirect';
import resolveAutoAttachmentIds from '@salesforce/apex/SugatiCommunicationHubController.resolveAutoAttachmentIds';
import { refreshApex } from '@salesforce/apex';

const MAX_ATTACHMENT_BYTES = 4.5 * 1024 * 1024;
const ALL_STAGES = '__all__';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import USER_NAME from '@salesforce/schema/User.Name';
import USER_EMAIL from '@salesforce/schema/User.Email';

const DEBUG_PREVIEW_FLOW = true;

export default class SugatiCommunicationEmailComposer extends LightningElement {
    @api opportunityId;
    @api tripName = '';
    @api stageLabel = '';

    toChips = [];
    ccChips = [];
    bccChips = [];
    orgWideEmailAddressId = '';
    _fromAddressesLoadComplete = false;
    _currentUserLoaded = false;
    _fromUserPicked = false;
    _fromRestoredFromDraft = false;
    relatedRecordId = null;
    attachmentParentLabel = '';
    sugatiEmailTemplateConfigId = null;
    _fromOptions = [];
    subject = '';
    activeTemplateName = '';
    activeTemplateMeta = '';
    activeTemplateId = null;
    templateSearch = '';
    selectedStageFilter = ALL_STAGES;
    templateSidebarStep = 'list';
    _pendingComposerTemplate = null;
    pendingComposerRecordId = '';
    composerRecordSearch = '';
    _templateCatalog = {
        templates: [],
        relatedRecords: [],
        opportunityStage: null,
        opportunityStageOrder: []
    };
    deliveryMode = 'native';
    showAiAssist = false;
    _activeAddrDropdown = null;
    _addrSearchTerm = '';
    _recipientRows = [];
    _focusAddrSearch = false;
    attCount = 0;
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

    _attachments = [];
    _opportunityFiles = [];
    _pendingUploads = [];
    _draftSelectedDocIds = null;
    _draftSelectedRecordIds = null;
    _draftAttachmentRows = [];
    _draftForEditPayload = null;
    _isBlankCompose = false;
    isUploadingAttachments = false;
    _boundDocClick = null;

    @wire(getRecipients, { opportunityId: '$opportunityId' })
    wiredRecipients({ data }) {
        this._recipientRows = data || [];
    }

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
        this._currentUserLoaded = true;
        this.ensureFromSelected();
    }

    _wiredRecordAttachmentsResult;

    get attachmentParentId() {
        return this.relatedRecordId || this.opportunityId || null;
    }

    get attachmentSectionLabel() {
        const label = (this.attachmentParentLabel || '').trim();
        return label ? `${label} files` : 'Related record files';
    }

    get attachmentUploadHint() {
        return 'Add files for this email — kept in the browser until you save draft or send, then stored on the communication log';
    }

    @wire(getRecordAttachments, { parentRecordId: '$attachmentParentId', opportunityId: '$opportunityId' })
    wiredRecordAttachments(result) {
        this._wiredRecordAttachmentsResult = result;
        const data = result?.data;
        const error = result?.error;
        if (data) {
            this._opportunityFiles = data;
            this.rebuildAttachmentList();
            if (this._draftSelectedDocIds || (this._draftAttachmentRows || []).length) {
                this.applySelectedAttachmentRecordIds([...(this._draftSelectedRecordIds || [])]);
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Failed to load record attachments', error);
        }
    }

    async refreshRecordAttachments() {
        if (this._wiredRecordAttachmentsResult) {
            await refreshApex(this._wiredRecordAttachmentsResult);
        }
    }

    connectedCallback() {
        this._boundDocClick = this.handleDocumentClick.bind(this);
        document.addEventListener('click', this._boundDocClick);
        this.loadTemplates();
        this.loadFromAddresses();
    }

    disconnectedCallback() {
        if (this._boundDocClick) {
            document.removeEventListener('click', this._boundDocClick);
        }
    }

    @api
    persistComposerState() {
        // Composer state is no longer persisted in browser storage.
    }

    renderedCallback() {
        if (this._focusAddrSearch && this._activeAddrDropdown) {
            this._focusAddrSearch = false;
            const input = this.template.querySelector(`.addr-search[data-field="${this._activeAddrDropdown}"]`);
            if (input) {
                input.focus();
            }
        }
        this.syncBodyEditorFromState();
    }

    persistDraft() {
        // Intentionally no-op: email composer no longer uses browser storage.
    }

    clearDraftStorage() {
        // Intentionally no-op: email composer no longer uses browser storage.
    }

    get addrSearchTerm() {
        return this._addrSearchTerm;
    }

    get toDropdownClass() {
        return this._activeAddrDropdown === 'to' ? 'addr-dropdown open' : 'addr-dropdown';
    }

    get ccDropdownClass() {
        return this._activeAddrDropdown === 'cc' ? 'addr-dropdown open' : 'addr-dropdown';
    }

    get bccDropdownClass() {
        return this._activeAddrDropdown === 'bcc' ? 'addr-dropdown open' : 'addr-dropdown';
    }

    get toAddrDropdownEntries() {
        return this.buildAddrDropdownEntries('to');
    }

    get ccAddrDropdownEntries() {
        return this.buildAddrDropdownEntries('cc');
    }

    get bccAddrDropdownEntries() {
        return this.buildAddrDropdownEntries('bcc');
    }

    get railRecipients() {
        return this.toChips.map((c) => ({
            ...c,
            role: c.role || 'Traveller'
        }));
    }

    get isComposerRecordStep() {
        return this.templateSidebarStep === 'record';
    }

    get effectiveOpportunityStage() {
        return (
            this._templateCatalog.templateStageForOpportunity ||
            this._templateCatalog.opportunityStage ||
            this.stageLabel ||
            ''
        );
    }

    get orderedTemplateStages() {
        return (this._templateCatalog.opportunityStageOrder || [])
            .map((stage) => (stage || '').trim())
            .filter((stage) => stage.length > 0);
    }

    get showComposerStageFilters() {
        return !this.isComposerRecordStep && this.orderedTemplateStages.length > 0;
    }

    get composerStageFilters() {
        const oppStage = this.effectiveOpportunityStage;
        const filters = [
            {
                id: ALL_STAGES,
                label: 'All stages',
                className: this.composerStageFilterClass(ALL_STAGES, false)
            }
        ];
        this.orderedTemplateStages.forEach((stage) => {
            const isOppStage =
                !!oppStage && this.normalizeStageKey(oppStage) === this.normalizeStageKey(stage);
            filters.push({
                id: stage,
                label: isOppStage ? `${stage} ●` : stage,
                className: this.composerStageFilterClass(stage, isOppStage)
            });
        });
        return filters;
    }

    get filteredTemplates() {
        const q = (this.templateSearch || '').trim().toLowerCase();
        const filterKey =
            this.selectedStageFilter === ALL_STAGES
                ? null
                : this.normalizeStageKey(this.selectedStageFilter);
        const filtered = (this._templateCatalog.templates || []).filter((t) => {
            if (filterKey) {
                if (!t.templateStage) {
                    return false;
                }
                if (this.normalizeStageKey(t.templateStage) !== filterKey) {
                    return false;
                }
            }
            if (!q) {
                return true;
            }
            const haystack = [
                t.name,
                t.templateName,
                t.meta,
                t.relatedToRecord,
                t.templateStage,
                this.formatObjectLabel(t.relatedToRecord)
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase();
            return haystack.includes(q);
        });
        const sorted = this.sortTemplatesByOpportunityStage(filtered);
        const oppStage = this.effectiveOpportunityStage;
        return sorted.map((t) => {
            const isSuggested = this.isTemplateSuggested(t, oppStage);
            const isActive = this.activeTemplateId === t.id;
            const stagePill = this.buildTemplateStagePillLabel(t);
            return {
                id: t.id,
                displayName: t.templateName || t.name || 'Template',
                stagePill,
                showStagePill: !!stagePill,
                stagePillClass: this.buildTemplateStagePillClass(isSuggested),
                relatedBadge: this.formatObjectLabel(t.relatedToRecord || 'Opportunity'),
                relatedBadgeClass: this.buildRelatedBadgeClass(t.relatedToRecord),
                showRelatedPill: true,
                isSuggested,
                itemClass:
                    'tmpl-item' +
                    (isActive ? ' on' : '') +
                    (isSuggested ? ' suggested' : '')
            };
        });
    }

    get pendingComposerTemplateName() {
        return (
            this._pendingComposerTemplate?.templateName ||
            this._pendingComposerTemplate?.name ||
            'Template'
        );
    }

    get pendingComposerRelatedLabel() {
        return this.formatObjectLabel(this._pendingComposerTemplate?.relatedToRecord || 'Record');
    }

    get composerFilteredRecordRows() {
        const term = (this.composerRecordSearch || '').trim().toLowerCase();
        const relatedType = this._pendingComposerTemplate?.relatedToRecord || 'Opportunity';
        const rows = this.filterRelatedRecords(relatedType).map((row) => ({
            recordId: row.recordId,
            label: row.label,
            objectTypeLabel: this.formatObjectLabel(row.objectType),
            isSelected: row.recordId === this.pendingComposerRecordId,
            rowClass:
                'composer-record-row' +
                (row.recordId === this.pendingComposerRecordId ? ' selected' : '')
        }));
        if (!term) {
            return rows;
        }
        return rows.filter((row) => (row.label || '').toLowerCase().includes(term));
    }

    get composerConfirmRecordDisabled() {
        return !this.pendingComposerRecordId;
    }

    get composerHasRelatedRecordOptions() {
        return (
            this.filterRelatedRecords(this._pendingComposerTemplate?.relatedToRecord || '').length > 0
        );
    }

    get composerHasNoFilteredRecords() {
        return this.composerHasRelatedRecordOptions && this.composerFilteredRecordRows.length === 0;
    }

    get composerRelatedRecordEmptyMessage() {
        const type = this.formatObjectLabel(this._pendingComposerTemplate?.relatedToRecord || 'record');
        return `No ${type} records found on this Opportunity. Add one on the trip or choose a different template.`;
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

    get fromComboboxValue() {
        return this.orgWideEmailAddressId ?? '';
    }

    get fromOptions() {
        const userFallback = {
            label: this.currentUserEmail
                ? `${this.currentUserName || 'Me'} <${this.currentUserEmail}>`
                : 'Current user',
            value: ''
        };
        const orgRows = (this._fromOptions || []).map((row) => ({
            label: row.label || row.email,
            value: row.value
        }));
        return [userFallback, ...orgRows];
    }

    get fromDisplay() {
        if (this.orgWideEmailAddressId) {
            const match = (this._fromOptions || []).find((o) => o.value === this.orgWideEmailAddressId);
            if (match) {
                return match.label;
            }
        }
        if (this.currentUserName && this.currentUserEmail) {
            return `${this.currentUserName} <${this.currentUserEmail}>`;
        }
        return this.currentUserName || this.currentUserEmail || 'Current User';
    }

    get resolvedFromEmail() {
        if (this.orgWideEmailAddressId) {
            const match = (this._fromOptions || []).find((o) => o.value === this.orgWideEmailAddressId);
            return (match?.email || '').trim();
        }
        return (this.currentUserEmail || '').trim();
    }

    ensureFromSelected() {
        if (this._fromUserPicked || this._fromRestoredFromDraft) {
            return;
        }
        if (!this._fromAddressesLoadComplete || !this._currentUserLoaded) {
            return;
        }
        const userEmail = (this.currentUserEmail || '').trim().toLowerCase();
        const options = this._fromOptions || [];
        const match =
            options.find((row) => row.isDefault) ||
            (userEmail
                ? options.find((row) => (row.email || '').trim().toLowerCase() === userEmail)
                : null);
        this.orgWideEmailAddressId = match?.value || '';
    }

    @api
    setRecipients(recipients) {
        this.toChips = this.mergeRecipientChips(
            [],
            (recipients || []).filter((r) => (r?.email || '').trim()).map((r, i) => this.mapSelectorRecipientToChip(r, i, 'to'))
        );
        this.persistDraft();
        this.notifyRecipientsUpdated();
    }

    @api
    setCcRecipients(recipients) {
        this.ccChips = this.mergeRecipientChips(
            [],
            (recipients || []).filter((r) => (r?.email || '').trim()).map((r, i) => this.mapSelectorRecipientToChip(r, i, 'cc'))
        );
        this.persistDraft();
        this.notifyRecipientsUpdated();
    }

    @api
    setBccRecipients(recipients) {
        this.bccChips = this.mergeRecipientChips(
            [],
            (recipients || []).filter((r) => (r?.email || '').trim()).map((r, i) => this.mapSelectorRecipientToChip(r, i, 'bcc'))
        );
        this.persistDraft();
        this.notifyRecipientsUpdated();
    }

    @api
    addRecipients(recipients, line) {
        const target = line === 'cc' || line === 'bcc' ? line : 'to';
        const prefix = target === 'cc' ? 'cc' : target === 'bcc' ? 'bcc' : 'to';
        const incoming = (recipients || [])
            .filter((r) => (r?.email || '').trim())
            .map((r, i) => this.mapSelectorRecipientToChip(r, i, prefix));
        if (target === 'cc') {
            this.ccChips = this.mergeRecipientChips(this.ccChips || [], incoming);
        } else if (target === 'bcc') {
            this.bccChips = this.mergeRecipientChips(this.bccChips || [], incoming);
        } else {
            this.toChips = this.mergeRecipientChips(this.toChips || [], incoming);
        }
        this.persistDraft();
        this.notifyRecipientsUpdated();
    }

    @api
    async loadDefaultTemplate() {
        if (!this.opportunityId || this.editingCommLogId) {
            return;
        }
        try {
            const loaded = await loadDefaultSendEmailTemplate({ opportunityId: this.opportunityId });
            this.applyLegacyLoad(loaded);
        } catch (e) {
            const message = e?.body?.message || e?.message || 'Unable to load default Send Email template.';
            this.showToast('Template not loaded', message, 'warning');
            // eslint-disable-next-line no-console
            console.warn('Default Send Email template not loaded', e);
        }
    }

    @api
    async applyTemplateSelection(detail) {
        if (detail?.blank) {
            await this.applyBlankCompose();
            return;
        }
        if (!detail?.configId || !this.opportunityId) {
            return;
        }
        try {
            const loaded = await loadSendEmailTemplate({
                opportunityId: this.opportunityId,
                configId: detail.configId,
                relatedRecordId: detail.relatedRecordId || this.opportunityId,
                clientGroupId: null,
                previewAsContactId: null
            });
            this.applyLegacyLoad(loaded, detail);
        } catch (e) {
            this.showToast('Template load failed', e?.body?.message || e?.message || 'Unable to load template.', 'error');
        }
    }

    async applyBlankCompose() {
        this._isBlankCompose = true;
        this.sugatiEmailTemplateConfigId = null;
        this.relatedRecordId = this.opportunityId || null;
        this.attachmentParentLabel = '';
        this.activeTemplateId = null;
        this.activeTemplateName = 'Blank';
        this.activeTemplateMeta = 'No template — compose from scratch';
        this.subject = '';
        this.bodyTemplate = '';
        this.toChips = [];
        this.ccChips = [];
        this.bccChips = [];
        this._fromUserPicked = false;
        this._fromRestoredFromDraft = false;
        this._bodyCursorPos = 0;
        this._bodySelectionRange = null;
        this._editorSyncedHtml = null;
        this._attachments = (this._attachments || []).map((row) => ({
            ...row,
            checked: false,
            autoSuggested: false
        }));
        this._pendingUploads = [];
        this._draftSelectedDocIds = null;
        this._draftSelectedRecordIds = null;
        this._draftAttachmentRows = [];
        this.attCount = 0;
        this.rebuildAttachmentList();
        this.ensureFromSelected();
        try {
            const bccDefaults = await getSendEmailBccDefaults();
            this.bccChips = this.mapLegacyAddressesToChips(bccDefaults || [], 'bcc');
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('Send Email BCC defaults not loaded', e);
        }
        this.persistDraft();
        this.notifyRecipientsUpdated();
        this.refreshRecordAttachments();
        requestAnimationFrame(() => {
            const editor = this.template?.querySelector('.editor-body');
            if (editor) {
                editor.innerHTML = '';
            }
            this.syncBodyEditorFromState();
            this.focusBodyAtCursor();
        });
    }

    applyLegacyLoad(loaded, meta) {
        if (!loaded) {
            return;
        }
        this._isBlankCompose = false;
        this.sugatiEmailTemplateConfigId = loaded.sugatiEmailTemplateConfigId || meta?.configId || null;
        this.relatedRecordId = loaded.relatedRecordId || meta?.relatedRecordId || this.opportunityId;
        this.attachmentParentLabel =
            meta?.attachmentParentLabel ||
            loaded.attachmentParentLabel ||
            this.attachmentParentLabel ||
            '';
        this.activeTemplateId = this.sugatiEmailTemplateConfigId;
        this.activeTemplateName = meta?.name || loaded.sfEmailTemplateName || 'Send Email';
        this.activeTemplateMeta = meta?.meta || loaded.sfEmailTemplateName || '';
        this.subject = loaded.subject || '';
        this.bodyTemplate = loaded.bodyHtml || '';
        const templateTo = this.mapLegacyAddressesToChips(loaded.toAddresses || [], 'to');
        const templateCc = this.mapLegacyAddressesToChips(loaded.ccAddresses || [], 'cc');
        const templateBcc = this.mapLegacyAddressesToChips(loaded.bccAddresses || [], 'bcc');
        if (!(this.toChips || []).length) {
            this.toChips = templateTo;
        }
        if (!(this.ccChips || []).length) {
            this.ccChips = templateCc;
        }
        if (!(this.bccChips || []).length) {
            this.bccChips = templateBcc;
        }
        this._bodyCursorPos = this.plainTextFromHtml(this.bodyTemplate).length;
        this._editorSyncedHtml = null;
        requestAnimationFrame(() => this.syncBodyEditorFromState());
        this.applyAutoAttachmentsFromTemplate(loaded);
        this.persistDraft();
        this.refreshRecordAttachments();
    }

    async applyAutoAttachmentsFromTemplate(loaded) {
        const docTypes = loaded?.autoAttachmentDocTypes || [];
        const preselected = loaded?.autoSelectedAttachmentIds || [];
        let recordIds = [...preselected];
        if (!recordIds.length && docTypes.length && this.attachmentParentId) {
            try {
                recordIds = await resolveAutoAttachmentIds({
                    parentRecordId: this.attachmentParentId,
                    opportunityId: this.opportunityId,
                    docTypes
                });
            } catch (e) {
                // eslint-disable-next-line no-console
                console.warn('Auto-attachment resolution failed', e);
            }
        }
        if (recordIds.length) {
            this.applySelectedAttachmentRecordIds(recordIds, { autoSuggested: true });
        }
    }

    mapLegacyAddressesToChips(addresses, prefix) {
        return (addresses || []).map((opt, index) => {
            const label = opt.label || opt.email || '';
            const paren = label.indexOf('(');
            const name = paren > 0 ? label.substring(0, paren).trim() : label;
            const contactId =
                opt.contactId && this.isContactId(opt.contactId)
                    ? opt.contactId
                    : opt.recordId && this.isContactId(opt.recordId)
                        ? opt.recordId
                        : null;
            return {
                id: contactId || `${prefix}-${index}-${opt.email}`,
                contactId,
                audience: this.resolveLegacyChipAudience(opt, contactId),
                name: name || opt.email,
                email: opt.email,
                initials: this.buildInitialsFromName(name || opt.email),
                role: contactId ? 'Traveller' : opt.supplierContactTypes?.length ? 'Contact' : opt.supplierId ? 'Supplier' : 'Contact',
                emailSendType: prefix === 'bcc' ? 'BCC' : prefix === 'cc' ? 'CC' : 'TO'
            };
        });
    }

    resolveLegacyChipAudience(opt, contactId) {
        if (contactId) {
            return 'travellers';
        }
        if (opt.supplierContactTypes?.length) {
            return 'contacts';
        }
        if (opt.supplierId) {
            return 'suppliers';
        }
        return 'contacts';
    }

    async loadFromAddresses() {
        try {
            const rows = await getOrgWideFromAddresses();
            this._fromOptions = (rows || []).map((row) => ({
                label: row.label || row.email,
                value: row.recordId,
                email: row.email,
                isDefault: !!row.isDefault
            }));
        } catch (e) {
            this._fromOptions = [];
        } finally {
            this._fromAddressesLoadComplete = true;
            this.ensureFromSelected();
        }
    }

    handleFromChange(event) {
        this._fromUserPicked = true;
        this.orgWideEmailAddressId = event.detail.value ?? '';
        this.persistDraft();
    }

    mapSelectorRecipientToChip(recipient, index, prefix) {
        const emailSendType = prefix === 'cc' ? 'CC' : prefix === 'bcc' ? 'BCC' : 'TO';
        const audience = recipient.audience || 'travellers';
        const contactId =
            recipient.contactId && this.isContactId(recipient.contactId)
                ? recipient.contactId
                : this.resolveContactIdForChip({ ...recipient, audience });
        const email = (recipient.email || '').trim();
        return {
            id: this.buildChipRowId(prefix, contactId, recipient.id, email, index),
            commRecipientId: recipient.commRecipientId || null,
            contactId,
            audience,
            initials: recipient.initials || this.buildInitialsFromName(recipient.name || email),
            name: recipient.name || email,
            email,
            role: recipient.role || 'Traveller',
            emailSendType
        };
    }

    buildChipRowId(prefix, contactId, fallbackId, email, index) {
        const base = contactId || fallbackId || email || String(index);
        return `${prefix}-${base}-${index}`;
    }

    mergeRecipientChips(existing, incoming) {
        const byEmail = new Map();
        (existing || []).forEach((chip) => {
            const key = (chip.email || '').trim().toLowerCase();
            if (key) {
                byEmail.set(key, chip);
            }
        });
        (incoming || []).forEach((chip) => {
            const key = (chip.email || '').trim().toLowerCase();
            if (key) {
                byEmail.set(key, chip);
            }
        });
        return [...byEmail.values()];
    }

    notifyRecipientsUpdated() {
        this.dispatchEvent(
            new CustomEvent('recipientsupdated', {
                bubbles: true,
                composed: true
            })
        );
    }

    mapDraftRecipientToChip(recipient, index) {
        const contactId = recipient.contactId || null;
        const emailSendType = (recipient.emailSendType || 'TO').toUpperCase();
        return {
            id: contactId || recipient.commRecipientId || `draft-${index}`,
            commRecipientId: recipient.commRecipientId || null,
            contactId,
            initials: this.buildInitialsFromName(recipient.name || recipient.email),
            name: recipient.name || recipient.email,
            email: recipient.email,
            role: recipient.role || 'Traveller',
            emailSendType
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
        this._isBlankCompose = false;
        this.editingCommLogId = draft.commLogId || null;
        this.subject = draft.subject || '';
        this.bodyTemplate = draft.bodyHtml || '';
        this.deliveryMode = draft.deliveryMode || 'postmark';
        const draftRecipients = draft.recipients || [];
        this.toChips = draftRecipients
            .filter((recipient) => this.isToSendType(recipient.emailSendType))
            .map((recipient, index) => this.mapDraftRecipientToChip(recipient, index));
        this.ccChips = draftRecipients
            .filter((recipient) => this.isCcSendType(recipient.emailSendType))
            .map((recipient, index) => this.mapDraftRecipientToChip(recipient, index));
        this.bccChips = draftRecipients
            .filter((recipient) => this.isBccSendType(recipient.emailSendType))
            .map((recipient, index) => this.mapDraftRecipientToChip(recipient, index));
        this.activeTemplateId = null;
        this.activeTemplateName = '';
        this.activeTemplateMeta = '';
        this.templateSearch = '';
        this._editorSyncedHtml = null;
        this._bodySelectionRange = null;
        this._bodyCursorPos = this.plainTextFromHtml(this.bodyTemplate).length;
        this.applyDraftAttachments(draft.attachments || []);
        requestAnimationFrame(() => {
            this.syncBodyEditorFromState();
            this.focusBodyAtCursor();
        });
        this.dispatchEvent(
            new CustomEvent('recipientsloaded', {
                bubbles: true,
                composed: true
            })
        );
    }

    applyDraftAttachments(attachmentRows) {
        const rows = attachmentRows || [];
        this._draftAttachmentRows = rows.filter(
            (row) => row.attachmentRecordId || row.contentDocumentId
        );
        this._draftSelectedRecordIds = new Set(
            rows
                .filter((row) => row.selected)
                .map((row) => row.attachmentRecordId || row.contentDocumentId)
                .filter(Boolean)
        );
        this._draftSelectedDocIds = this._draftSelectedRecordIds;
        this.rebuildAttachmentList();
    }

    applySelectedAttachmentRecordIds(selectedIds, options = {}) {
        const selectedSet = new Set((selectedIds || []).map((id) => String(id)));
        if (selectedIds && selectedIds.length) {
            this._draftSelectedRecordIds = selectedSet;
            this._draftSelectedDocIds = selectedSet;
        }
        const autoSuggested = !!options.autoSuggested;
        this._attachments = (this._attachments || []).map((row) => {
            const recordId = row.attachmentRecordId || row.contentDocumentId || row.id;
            const checked = recordId ? selectedSet.has(String(recordId)) : row.checked;
            return {
                ...row,
                checked: checked || row.checked,
                ai: autoSuggested && checked ? true : row.ai
            };
        });
        this.updateAttCount();
    }

    applySelectedAttachmentIds(selectedIds) {
        this.applySelectedAttachmentRecordIds(selectedIds);
    }

    getSelectedAttachmentRecordIds() {
        return (this._attachments || [])
            .filter((row) => row.checked)
            .map((row) => row.attachmentRecordId || row.contentDocumentId || row.id)
            .filter(Boolean);
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
            const recordId = fileRow.attachmentRecordId || fileRow.contentDocumentId;
            if (!recordId || seen.has(recordId)) {
                return;
            }
            const existing = (this._attachments || []).find(
                (row) => (row.attachmentRecordId || row.contentDocumentId || row.id) === recordId
            );
            const checkedFromDraft = selectedSet.has(recordId);
            rows.push({
                id: recordId,
                attachmentRecordId: recordId,
                contentDocumentId: fileRow.contentDocumentId || null,
                storageKind: fileRow.storageKind || (fileRow.contentDocumentId ? 'ContentDocument' : 'Attachment'),
                name: fileRow.name,
                meta: fileRow.meta || 'File',
                type: fileRow.fileType === 'pdf' ? 'pdf' : 'gen',
                checked: existing ? !!existing.checked : checkedFromDraft || !!fileRow.selected,
                pending: false,
                ai: existing ? !!existing.ai : !!fileRow.autoSuggested
            });
            seen.add(recordId);
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

    @api
    buildDraftAttachmentArrays() {
        const selected = (this._attachments || []).filter((row) => row.checked);
        const existing = selected.filter((row) => !row.pending);
        const pending = selected.filter((row) => row.pending && row.base64Data);
        return {
            attachmentContentDocumentIds: existing
                .filter((row) => row.contentDocumentId)
                .map((row) => row.contentDocumentId),
            attachmentRecordIds: existing
                .map((row) => row.attachmentRecordId || row.contentDocumentId || row.id)
                .filter(Boolean),
            newAttachmentFileNames: pending.map((row) => row.name),
            newAttachmentFileData: pending.map((row) => row.base64Data)
        };
    }

    @api
    getSelectedAttachmentsForPayload() {
        return (this._attachments || [])
            .filter((row) => row.checked)
            .map((row) => ({
                attachmentRecordId: row.attachmentRecordId || row.contentDocumentId || row.id || null,
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
        if (!this.opportunityId) {
            this.showToast('Upload failed', 'Open the Communication Hub from an Opportunity first.', 'error');
            return;
        }
        this.isUploadingAttachments = true;
        try {
            const stagedRows = [];
            for (const file of files) {
                if (file.size > MAX_ATTACHMENT_BYTES) {
                    this.showToast('File too large', `"${file.name}" exceeds the 4.5 MB limit.`, 'error');
                    continue;
                }
                const base64Data = await this.readFileAsBase64(file);
                const clientId = `pending-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
                stagedRows.push({
                    id: clientId,
                    attachmentRecordId: clientId,
                    contentDocumentId: null,
                    name: file.name,
                    meta: `${this.formatFileSize(file.size)} · not saved yet`,
                    type: file.name.toLowerCase().endsWith('.pdf') ? 'pdf' : 'gen',
                    checked: true,
                    pending: true,
                    base64Data
                });
            }
            if (stagedRows.length) {
                this._pendingUploads = [...(this._pendingUploads || []), ...stagedRows];
                this.rebuildAttachmentList();
                this.persistDraft();
                this.showToast(
                    'Files added',
                    `${stagedRows.length} file(s) will be saved to the communication log when you save draft or send.`,
                    'success'
                );
            }
        } catch (e) {
            this.showToast('Upload failed', e?.body?.message || e?.message || 'Unable to read selected file(s).', 'error');
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

    normalizeChipForRecipientPicker(chip) {
        if (!chip) {
            return chip;
        }
        const preselectId = this.resolvePreselectId(chip);
        return {
            ...chip,
            id: preselectId,
            contactId: chip.contactId || (this.isContactId(chip.id) ? chip.id : null),
            email: chip.email || '',
            name: chip.name || chip.email || '',
            initials: chip.initials || this.buildInitialsFromName(chip.name || chip.email),
            role: chip.role || 'Traveller',
            audience: chip.audience || 'travellers'
        };
    }

    resolvePreselectId(chip) {
        if (chip.contactId && this.isContactId(chip.contactId)) {
            return chip.contactId;
        }
        if (chip.id && this.isContactId(chip.id)) {
            return chip.id;
        }
        if (chip.id && this.isSalesforceId(chip.id)) {
            return chip.id;
        }
        return chip.id;
    }

    @api
    getRecipientState() {
        return {
            to: (this.toChips || []).map((chip) => this.normalizeChipForRecipientPicker(chip)),
            cc: (this.ccChips || []).map((chip) => this.normalizeChipForRecipientPicker(chip)),
            bcc: (this.bccChips || []).map((chip) => this.normalizeChipForRecipientPicker(chip))
        };
    }

    @api
    getEmailSendContext() {
        return {
            sugatiEmailTemplateConfigId: this.sugatiEmailTemplateConfigId || null,
            relatedRecordId: this.relatedRecordId || this.opportunityId || null
        };
    }

    @api
    hasActiveTemplateSelection() {
        if (this.editingCommLogId) {
            return true;
        }
        if (this.sugatiEmailTemplateConfigId) {
            return true;
        }
        return this._isBlankCompose;
    }

    @api
    async startNewCompose() {
        this.resetComposer();
    }

    @api
    resetComposer() {
        this.editingCommLogId = null;
        this._isBlankCompose = false;
        this.sugatiEmailTemplateConfigId = null;
        this.relatedRecordId = null;
        this.attachmentParentLabel = '';
        this.toChips = [];
        this.ccChips = [];
        this.bccChips = [];
        this.subject = '';
        this.bodyTemplate = '';
        this.activeTemplateName = '';
        this.activeTemplateMeta = '';
        this.activeTemplateId = null;
        this.templateSearch = '';
        this.resetComposerTemplateStep();
        this.selectedStageFilter = ALL_STAGES;
        this.deliveryMode = 'postmark';
        this.orgWideEmailAddressId = '';
        this._fromUserPicked = false;
        this._fromRestoredFromDraft = false;
        this._lastFocusedField = 'body';
        this._subjectCursorPos = 0;
        this._bodyCursorPos = 0;
        this._bodySelectionRange = null;
        this._editorSyncedHtml = '';
        this._attachments = [];
        this._pendingUploads = [];
        this._draftSelectedDocIds = null;
        this._draftSelectedRecordIds = null;
        this._draftAttachmentRows = [];
        this._draftForEditPayload = null;
        this.attCount = 0;
        this.rebuildAttachmentList();
        this.ensureFromSelected();
        this.refreshRecordAttachments();
        requestAnimationFrame(() => {
            const editor = this.template?.querySelector('.editor-body');
            if (editor) {
                editor.innerHTML = '';
            }
        });
    }

    @api
    syncBodyFromEditor() {
        const editor = this.template?.querySelector('.editor-body');
        if (editor) {
            this.bodyTemplate = editor.innerHTML || '';
            this._editorSyncedHtml = this.bodyTemplate;
        }
    }

    @api
    getComposeState() {
        this.syncBodyFromEditor();
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

    handleRemoveBccChip(event) {
        const email = event.currentTarget.dataset.email;
        this.bccChips = this.bccChips.filter((c) => c.email !== email);
        this.persistDraft();
    }

    handleBccNav() {
        this.openAddrDropdown('bcc');
    }

    @api
    openRecipientPicker(target) {
        this.openAddrDropdown(target);
    }

    openAddrDropdown(target) {
        const field = target === 'cc' || target === 'bcc' ? target : 'to';
        if (this._activeAddrDropdown === field) {
            this.closeAddrDropdown();
            return;
        }
        this._activeAddrDropdown = field;
        this._addrSearchTerm = '';
        this._focusAddrSearch = true;
    }

    closeAddrDropdown() {
        this._activeAddrDropdown = null;
        this._addrSearchTerm = '';
    }

    stopAddrWrapPropagation(event) {
        event.stopPropagation();
    }

    handleDocumentClick(event) {
        if (!this._activeAddrDropdown) {
            return;
        }
        const wrap = this.template.querySelector(`.r-add-wrap[data-field="${this._activeAddrDropdown}"]`);
        if (wrap && !wrap.contains(event.target)) {
            this.closeAddrDropdown();
        }
    }

    handleOpenAddrDropdown(event) {
        event.stopPropagation();
        const field = event.currentTarget.dataset.field || 'to';
        this.openAddrDropdown(field);
    }

    handleAddrSearch(event) {
        this._addrSearchTerm = event.target.value || '';
    }

    handleAddrSearchKey(event) {
        const field = event.currentTarget.dataset.field || 'to';
        if (event.key === 'Escape') {
            this.closeAddrDropdown();
            return;
        }
        if (event.key === 'Enter') {
            const value = (event.target.value || '').trim();
            if (value.includes('@')) {
                const localPart = value.split('@')[0] || value;
                const initials = localPart.slice(0, 2).toUpperCase();
                this.addRecipients(
                    [
                        {
                            name: value,
                            email: value,
                            initials,
                            audience: 'contacts',
                            role: 'Contact'
                        }
                    ],
                    field
                );
                this.closeAddrDropdown();
            }
        }
    }

    handleAddrItemClick(event) {
        event.stopPropagation();
        const el = event.currentTarget;
        const field = el.dataset.field || 'to';
        const email = (el.dataset.email || '').trim();
        if (!email) {
            return;
        }
        this.addRecipients(
            [
                {
                    id: el.dataset.rowId || email,
                    contactId: el.dataset.contactId || null,
                    audience: el.dataset.audience || 'travellers',
                    name: el.dataset.name || email,
                    email,
                    initials: el.dataset.initials || this.buildInitialsFromName(el.dataset.name || email),
                    role: el.dataset.role || 'Traveller'
                }
            ],
            field
        );
        this.closeAddrDropdown();
    }

    buildAddrDropdownEntries(field) {
        if (this._activeAddrDropdown !== field) {
            return [];
        }
        const term = (this._addrSearchTerm || '').trim().toLowerCase();
        const existing = new Set(
            this.getChipsForField(field)
                .map((chip) => (chip.email || '').trim().toLowerCase())
                .filter(Boolean)
        );
        const entries = [];
        let isFirstGroup = true;

        this.getContactGroups().forEach((group) => {
            const visible = group.contacts.filter((contact) => {
                const email = (contact.email || '').trim().toLowerCase();
                if (!email || existing.has(email)) {
                    return false;
                }
                if (!term) {
                    return true;
                }
                return (
                    (contact.name || '').toLowerCase().includes(term) ||
                    email.includes(term) ||
                    (contact.subrole || '').toLowerCase().includes(term) ||
                    (contact.role || '').toLowerCase().includes(term)
                );
            });
            if (!visible.length) {
                return;
            }
            entries.push({
                key: `hdr-${group.key}`,
                isGroupHeader: true,
                headerClass: `addr-dd-group-hdr ${isFirstGroup ? 'first' : ''} ${group.headerClass}`,
                icon: group.icon,
                label: group.label,
                count: visible.length
            });
            isFirstGroup = false;
            visible.forEach((contact) => {
                entries.push({
                    key: `item-${group.key}-${contact.email}`,
                    isGroupHeader: false,
                    field,
                    name: contact.name,
                    email: contact.email,
                    initials: contact.initials,
                    subrole: contact.subrole,
                    status: contact.status,
                    badgeLabel: contact.badgeLabel,
                    badgeClass: contact.badgeClass,
                    avClass: contact.avClass,
                    contactId: contact.contactId,
                    id: contact.id,
                    audience: contact.audience,
                    role: contact.role
                });
            });
        });

        if (!entries.length) {
            entries.push({ key: 'empty', isEmpty: true });
        }
        return entries;
    }

    getContactGroups() {
        const buckets = {
            travellers: [],
            suppliers: [],
            contacts: [],
            agents: []
        };
        (this._recipientRows || []).forEach((row) => {
            const email = (row.email || '').trim();
            if (!email) {
                return;
            }
            const audience = row.audience || 'travellers';
            const bucket = buckets[audience] || buckets.travellers;
            bucket.push(this.mapRecipientToDdContact(row));
        });
        return [
            {
                key: 'travellers',
                label: 'Travellers',
                icon: '🧳',
                headerClass: 'group-travellers',
                contacts: buckets.travellers
            },
            {
                key: 'suppliers',
                label: 'Suppliers',
                icon: '🏨',
                headerClass: 'group-suppliers',
                contacts: buckets.suppliers
            },
            {
                key: 'contacts',
                label: 'Supplier Contacts',
                icon: '📋',
                headerClass: 'group-contacts',
                contacts: buckets.contacts
            },
            {
                key: 'agents',
                label: 'Agency & Agents',
                icon: '🏢',
                headerClass: 'group-agency',
                contacts: buckets.agents
            }
        ].filter((group) => group.contacts.length);
    }

    mapRecipientToDdContact(row) {
        const roleKey = row.roleKey || 'traveller';
        const subrole = row.linkedToLabel || row.role || '';
        return {
            id: row.id,
            contactId: row.contactId || null,
            audience: row.audience || 'travellers',
            name: row.name,
            email: row.email,
            initials: row.initials || this.buildInitialsFromName(row.name || row.email),
            role: row.role || 'Traveller',
            subrole,
            status:
                row.audience === 'travellers' || row.audience === 'suppliers'
                    ? row.status || ''
                    : '',
            badgeLabel: this.resolveAddrBadgeLabel(roleKey, row.role),
            badgeClass: `addr-dd-role ${roleKey}`,
            avClass: `addr-dd-av ${roleKey}`
        };
    }

    resolveAddrBadgeLabel(roleKey, role) {
        if (roleKey === 'lead') {
            return 'Lead Booker';
        }
        if (roleKey === 'traveller') {
            return 'Traveller';
        }
        if (roleKey === 'supplier') {
            return 'Supplier';
        }
        if (roleKey === 'contact') {
            return 'Sup. Contact';
        }
        if (roleKey === 'agent' || roleKey === 'agency') {
            return role === 'Agency' ? 'Agency' : 'Agency';
        }
        return role || 'Contact';
    }

    getChipsForField(field) {
        if (field === 'cc') {
            return this.ccChips || [];
        }
        if (field === 'bcc') {
            return this.bccChips || [];
        }
        return this.toChips || [];
    }

    handleTemplateSearch(event) {
        this.templateSearch = event.target.value;
    }

    handleTemplateActivate(event) {
        const id = event.currentTarget.dataset.id;
        if (id) {
            this.selectComposerTemplateById(id);
        }
    }

    handleComposerStageFilter(event) {
        this.selectedStageFilter = event.currentTarget.dataset.stage || ALL_STAGES;
    }

    handleComposerRecordSearch(event) {
        this.composerRecordSearch = event.detail.value || '';
    }

    handleComposerRecordRadioChange(event) {
        this.pendingComposerRecordId = event.target.value;
    }

    handleComposerCancelRecord() {
        this.resetComposerTemplateStep();
    }

    handleComposerConfirmRecord() {
        if (!this._pendingComposerTemplate || !this.pendingComposerRecordId) {
            return;
        }
        const selected = this._pendingComposerTemplate;
        const match = (this._templateCatalog.relatedRecords || []).find(
            (row) => row.recordId === this.pendingComposerRecordId
        );
        this.activeTemplateId = selected.id;
        this.activeTemplateName = selected.name;
        this.activeTemplateMeta = selected.meta || '';
        this.applyTemplateSelection({
            configId: selected.id,
            name: selected.name,
            meta: selected.meta,
            relatedRecordId: this.pendingComposerRecordId,
            attachmentParentLabel: match?.label || this.tripName || ''
        });
        this.resetComposerTemplateStep();
        this.persistDraft();
    }

    selectComposerTemplateById(id) {
        const selected = (this._templateCatalog.templates || []).find((t) => t.id === id);
        if (!selected) {
            return;
        }
        const relatedType = selected.relatedToRecord || 'Opportunity';
        if (this.normalizeRelatedObjectKey(relatedType) === 'opportunity') {
            this.activeTemplateId = selected.id;
            this.activeTemplateName = selected.name;
            this.activeTemplateMeta = selected.meta || '';
            this.applyTemplateSelection({
                configId: selected.id,
                name: selected.name,
                meta: selected.meta,
                relatedRecordId: this.opportunityId
            });
            this.persistDraft();
            return;
        }
        const matches = this.filterRelatedRecords(relatedType);
        this._pendingComposerTemplate = selected;
        this.composerRecordSearch = '';
        this.templateSidebarStep = 'record';
        this.pendingComposerRecordId = matches.length ? matches[0].recordId : '';
    }

    resetComposerTemplateStep() {
        this._pendingComposerTemplate = null;
        this.pendingComposerRecordId = '';
        this.composerRecordSearch = '';
        this.templateSidebarStep = 'list';
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

    @api
    getDeliveryMode() {
        return this.deliveryMode === 'native' ? 'native' : 'postmark';
    }

    handleOpenTemplates() {
        this.dispatchEvent(
            new CustomEvent('opentemplates', {
                bubbles: true,
                composed: true
            })
        );
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

    buildEmailListFromChips(chips) {
        return (chips || []).map((c) => c.email).filter(Boolean);
    }

    isToSendType(sendType) {
        const value = (sendType || 'TO').toUpperCase();
        return value !== 'CC' && value !== 'BCC';
    }

    isCcSendType(sendType) {
        return (sendType || '').toUpperCase() === 'CC';
    }

    isBccSendType(sendType) {
        return (sendType || '').toUpperCase() === 'BCC';
    }

    flattenRecipientChipsForDraft() {
        const withType = (chips, emailSendType) =>
            (chips || []).map((chip) => ({
                chip,
                emailSendType: chip.emailSendType || emailSendType
            }));
        return [
            ...withType(this.toChips, 'TO'),
            ...withType(this.ccChips, 'CC'),
            ...withType(this.bccChips, 'BCC')
        ];
    }

    buildDraftRecipientArrays() {
        const rows = this.flattenRecipientChipsForDraft();
        return {
            recipientRowIds: rows.map((row) => row.chip.commRecipientId || null),
            recipientContactIds: rows.map((row) => this.resolveContactIdForChip(row.chip)),
            recipientEmails: rows.map((row) => row.chip.email || ''),
            recipientNames: rows.map((row) => row.chip.name || row.chip.email || ''),
            recipientRoles: rows.map((row) => row.chip.role || 'Traveller'),
            recipientEmailSendTypes: rows.map((row) => row.emailSendType)
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
            channel: 'Email',
            orgWideEmailAddressId: this.orgWideEmailAddressId || null
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
        this.syncBodyFromEditor();
        this.persistDraft();
        const detail = {
            channel: 'email',
            opportunityId: this.opportunityId,
            subject: this.subject,
            subjectTemplate: this.subject,
            bodyTemplate: this.bodyTemplate,
            recipients: this.toChips,
            ccRecipients: this.ccChips,
            bccRecipients: this.bccChips,
            toEmails: this.buildEmailListFromChips(this.toChips),
            ccEmails: this.buildEmailListFromChips(this.ccChips),
            bccEmails: this.buildEmailListFromChips(this.bccChips),
            fromLabel: this.fromDisplay,
            orgWideEmailAddressId: this.orgWideEmailAddressId || null,
            deliveryMode: this.deliveryMode,
            templateName: this.activeTemplateName,
            templateId: this.activeTemplateId,
            sugatiEmailTemplateConfigId: this.sugatiEmailTemplateConfigId,
            relatedRecordId: this.relatedRecordId,
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
        this.openAddrDropdown('to');
    }

    handleCcNav() {
        this.openAddrDropdown('cc');
    }

    async loadTemplates() {
        if (!this.opportunityId) {
            return;
        }
        try {
            const catalog = await getSendEmailTemplateCatalog({ opportunityId: this.opportunityId });
            this._templateCatalog = catalog || {
                templates: [],
                relatedRecords: [],
                opportunityStage: null,
                opportunityStageOrder: []
            };
            if (!this._templateCatalog.opportunityStageOrder) {
                this._templateCatalog.opportunityStageOrder = [];
            }
            this.selectedStageFilter = ALL_STAGES;
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('Template catalog not loaded', e);
        }
    }

    normalizeStageKey(stage) {
        return (stage || '').trim().toLowerCase();
    }

    normalizeRelatedObjectKey(value) {
        let key = (value || '').trim().toLowerCase();
        if (key.startsWith('sugati__')) {
            key = key.substring('sugati__'.length);
        }
        return key.endsWith('__c') ? key.slice(0, -3) : key;
    }

    formatObjectLabel(raw) {
        const key = this.normalizeRelatedObjectKey(raw);
        if (key === 'opportunity') {
            return 'Opportunity';
        }
        if (key === 'supplier_booking') {
            return 'Supplier booking';
        }
        if (key === 'supplier_cost_payment') {
            return 'Supplier cost / payment';
        }
        if (key === 'group_member') {
            return 'Traveller';
        }
        if (key === 'contact') {
            return 'Contact';
        }
        if (key === 'client_group') {
            return 'Client group';
        }
        return (raw || 'Record').replace(/__c$/i, '').replace(/_/g, ' ');
    }

    buildRelatedBadgeClass(relatedRaw) {
        const key = this.normalizeRelatedObjectKey(relatedRaw);
        return key === 'opportunity' ? 'tmpl-rel-badge opp' : 'tmpl-rel-badge custom';
    }

    buildTemplateStagePillLabel(t) {
        if (!t.templateStage) {
            return '';
        }
        return this.stripStageSuffix(t.templateStage);
    }

    buildTemplateStagePillClass(isSuggested) {
        let cls = 'tmpl-stage-pill';
        if (isSuggested) {
            cls += ' suggested';
        }
        return cls;
    }

    stripStageSuffix(stage) {
        if (!stage) {
            return '';
        }
        return String(stage)
            .replace(/\s*stage\s*$/i, '')
            .trim();
    }

    composerStageFilterClass(stageId, isOppStage) {
        let cls = 'tmpl-sf';
        if (stageId === ALL_STAGES) {
            if (this.selectedStageFilter === ALL_STAGES) {
                cls += ' on';
            }
            return cls;
        }
        if (this.normalizeStageKey(this.selectedStageFilter) === this.normalizeStageKey(stageId)) {
            cls += ' on';
        } else if (isOppStage) {
            cls += ' active-stage';
        }
        return cls;
    }

    filterRelatedRecords(relatedObjectType) {
        const needle = this.normalizeRelatedObjectKey(relatedObjectType);
        return (this._templateCatalog.relatedRecords || []).filter((row) => {
            return this.normalizeRelatedObjectKey(row.objectType) === needle;
        });
    }

    getStageOrderIndex(stage) {
        const key = this.normalizeStageKey(stage);
        if (!key) {
            return 9999;
        }
        const order = this._templateCatalog.opportunityStageOrder || [];
        const index = order.findIndex((s) => this.normalizeStageKey(s) === key);
        return index >= 0 ? index : 9998;
    }

    isTemplateSuggested(t, oppStage) {
        if (!oppStage || !t.templateStage) {
            return false;
        }
        return this.normalizeStageKey(t.templateStage) === this.normalizeStageKey(oppStage);
    }

    sortTemplatesByOpportunityStage(templates) {
        const oppStage = this.effectiveOpportunityStage;
        return [...templates].sort((a, b) => {
            const aSuggested = this.isTemplateSuggested(a, oppStage);
            const bSuggested = this.isTemplateSuggested(b, oppStage);
            if (aSuggested !== bSuggested) {
                return aSuggested ? -1 : 1;
            }
            const stageDiff =
                this.getStageOrderIndex(a.templateStage) - this.getStageOrderIndex(b.templateStage);
            if (stageDiff !== 0) {
                return stageDiff;
            }
            const aName = a.templateName || a.name || '';
            const bName = b.templateName || b.name || '';
            return aName.localeCompare(bName, undefined, { sensitivity: 'base' });
        });
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
