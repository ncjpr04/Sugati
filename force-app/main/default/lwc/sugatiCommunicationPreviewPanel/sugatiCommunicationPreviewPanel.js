import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendMessage from '@salesforce/apex/SugatiCommunicationHubController.sendMessage';
import loadSendEmailTemplate from '@salesforce/apex/SugatiCommunicationHubController.loadSendEmailTemplate';
import saveDraftDirect from '@salesforce/apex/SugatiCommunicationHubController.saveDraftDirect';
import getRecipients from '@salesforce/apex/SugatiCommunicationHubController.getRecipients';

export default class SugatiCommunicationPreviewPanel extends LightningElement {
    @api opportunityId;
    @api initialChannel = 'email';
    @api subject = '';
    _previewPayload = {};
    _isConnected = false;
    _pageRecordId;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        const recordId = pageRef?.attributes?.recordId;
        if (recordId && String(recordId).startsWith('006')) {
            this._pageRecordId = recordId;
        }
    }

    previewChannel = 'email';
    showCover = true;
    deliveryMode = 'native';
    scheduleMode = 'now';
    scheduledAt = null;
    previewAsContactId = null;

    sendModalOpen = false;
    sendPhase = 'idle';
    sendTitle = 'Sending…';
    sendSubtitle = '';
    sendSucceeded = false;
    resolvedBody = '';
    recipientLabel = '';
    fromLabel = '';
    previewAsLabel = '';
    _pendingBodyHtml = '';
    isPreviewLoading = false;
    isSavingDraft = false;
    _travellerContactByEmail = new Map();

    get wireOpportunityId() {
        return this.resolveOpportunityId();
    }

    @wire(getRecipients, { opportunityId: '$wireOpportunityId' })
    wiredTravellerContacts({ data }) {
        const map = new Map();
        if (data) {
            data.forEach((row) => {
                const audience = row.audience || 'travellers';
                if (audience !== 'travellers') {
                    return;
                }
                const email = (row.email || '').trim().toLowerCase();
                const contactId = row.contactId;
                if (email && contactId) {
                    map.set(email, contactId);
                }
            });
        }
        this._travellerContactByEmail = map;
        if (this._isConnected) {
            this.syncPreviewAsFromPayload();
        }
    }

    @api
    get previewPayload() {
        return this._previewPayload;
    }

    set previewPayload(value) {
        this._previewPayload = value || {};
        if (this._previewPayload.deliveryMode) {
            this.deliveryMode = this._previewPayload.deliveryMode;
        }
        this.fromLabel = this._previewPayload?.fromLabel || '';
        this.recipientLabel = (this._previewPayload?.recipients || []).map((r) => r.name || r.email).join(', ');
        this.syncPreviewAsFromPayload();
        if (this._isConnected) {
            this.loadPreview();
        }
    }

    connectedCallback() {
        this._isConnected = true;
        this.previewChannel = this.initialChannel || 'email';
        if (this._previewPayload?.subject) {
            this.subject = this._previewPayload.subject;
        }
        if (this._previewPayload?.deliveryMode) {
            this.deliveryMode = this._previewPayload.deliveryMode;
        }
        this.fromLabel = this._previewPayload?.fromLabel || '';
        this.recipientLabel = (this._previewPayload?.recipients || []).map((r) => r.name || r.email).join(', ');
        this.syncPreviewAsFromPayload();
        this.initializePreview();
    }

    renderedCallback() {
        const body = this.template.querySelector('.ec-body-content');
        if (!body) return;
        if (this._pendingBodyHtml === null) return;
        body.innerHTML = this._pendingBodyHtml || '';
        this._pendingBodyHtml = null;
    }

    async initializePreview() {
        await this.loadPreview();
    }

    syncPreviewAsFromPayload() {
        const personas = this.buildPreviewAsPersonas();
        if (!personas.length) {
            this.previewAsContactId = null;
            this.previewAsLabel = '';
            return;
        }
        const stillValid = personas.some((p) => p.contactId === this.previewAsContactId);
        if (!stillValid) {
            this.previewAsContactId = personas[0].contactId;
        }
        const active = personas.find((p) => p.contactId === this.previewAsContactId);
        this.previewAsLabel = active?.name || '';
    }

    buildPreviewAsPersonas() {
        const chips = [
            ...(this._previewPayload?.recipients || []),
            ...(this._previewPayload?.ccRecipients || []),
            ...(this._previewPayload?.bccRecipients || [])
        ];
        const seen = new Set();
        const list = [];
        for (const chip of chips) {
            const contactId = this.resolveContactIdForChip(chip);
            if (!contactId || seen.has(contactId)) {
                continue;
            }
            seen.add(contactId);
            list.push({
                contactId,
                name: chip.name || chip.email || 'Traveller'
            });
        }
        return list;
    }

    isContactId(value) {
        return value && /^003[a-zA-Z0-9]{12,15}$/.test(value);
    }

    resolveContactIdForChip(chip) {
        if (chip?.contactId && this.isContactId(chip.contactId)) {
            return chip.contactId;
        }
        const audience = chip?.audience || '';
        if (audience === 'travellers' && chip?.id && this.isContactId(chip.id)) {
            return chip.id;
        }
        const email = (chip?.email || '').trim().toLowerCase();
        if (email && this._travellerContactByEmail?.has(email)) {
            return this._travellerContactByEmail.get(email);
        }
        return null;
    }

    get toLine() {
        return this.recipientLabel || 'No recipients';
    }

    get fromLine() {
        return this.fromLabel || 'Current User';
    }

    get displaySubject() {
        return this.isPreviewLoading ? 'Loading preview...' : this.subject;
    }

    get showEmail() {
        return this.previewChannel === 'email';
    }

    get showWa() {
        return this.previewChannel === 'wa';
    }

    get showIa() {
        return this.previewChannel === 'ia';
    }

    get emailTabClass() {
        return this.previewChannel === 'email' ? 'prev-ch-tab active' : 'prev-ch-tab';
    }

    get waTabClass() {
        return this.previewChannel === 'wa' ? 'prev-ch-tab active' : 'prev-ch-tab';
    }

    get iaTabClass() {
        return this.previewChannel === 'ia' ? 'prev-ch-tab active' : 'prev-ch-tab';
    }

    get coverHiddenClass() {
        return this.showCover ? '' : 'ec-cover hidden';
    }

    get postmarkClass() {
        return this.deliveryMode === 'postmark' ? 'pp-opt on' : 'pp-opt';
    }

    get nativeClass() {
        return this.deliveryMode === 'native' ? 'pp-opt on' : 'pp-opt';
    }

    get scheduleNowClass() {
        return this.scheduleMode === 'now' ? 'pp-opt on' : 'pp-opt';
    }

    get scheduleLaterClass() {
        return this.scheduleMode === 'later' ? 'pp-opt on' : 'pp-opt';
    }

    get showScheduleDateTime() {
        return this.scheduleMode === 'later';
    }

    get previewAsOptions() {
        const selected = this.previewAsContactId;
        return this.buildPreviewAsPersonas().map((person) => ({
            key: person.contactId,
            contactId: person.contactId,
            name: person.name,
            className: person.contactId === selected ? 'pp-opt on' : 'pp-opt'
        }));
    }

    get hasPreviewAsOptions() {
        return this.previewAsOptions.length > 0;
    }

    get showPreviewAsEmpty() {
        return !this.hasPreviewAsOptions;
    }

    get showPreviewAsHint() {
        return Boolean(this.previewAsLabel);
    }

    get sendBtnClass() {
        const ch = this.previewChannel;
        const disabled = this.sendButtonDisabled ? ' disabled' : '';
        return `send-btn ${ch === 'wa' ? 'wa' : ch === 'ia' ? 'ia' : 'email'}${disabled}`;
    }

    get sendButtonLabel() {
        return this.scheduleMode === 'later' ? 'Schedule Send' : 'Send Now';
    }

    get sendButtonDisabled() {
        if (this.isPreviewLoading) {
            return true;
        }
        if (this.scheduleMode === 'later') {
            return !this.scheduledAt;
        }
        return false;
    }

    handleChannelTab(event) {
        this.previewChannel = event.currentTarget.dataset.channel;
    }

    handleCoverToggle(event) {
        this.showCover = event.target.checked;
    }

    handleDeliveryPostmark() {
        this.deliveryMode = 'postmark';
    }

    handleDeliveryNative() {
        this.deliveryMode = 'native';
    }

    handleScheduleNow() {
        this.scheduleMode = 'now';
        this.scheduledAt = null;
    }

    handleScheduleLater() {
        this.scheduleMode = 'later';
    }

    handleScheduledAtChange(event) {
        this.scheduledAt = event.detail.value || null;
    }

    handlePreviewAs(event) {
        const contactId = event.currentTarget.dataset.contactId;
        if (!contactId || contactId === this.previewAsContactId) {
            return;
        }
        this.previewAsContactId = contactId;
        const active = this.buildPreviewAsPersonas().find((p) => p.contactId === contactId);
        this.previewAsLabel = active?.name || '';
        this.loadPreview();
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', { detail: { channel: this.previewChannel } }));
    }

    buildDraftAttachmentArraysFromPayload() {
        const attachments = this._previewPayload?.attachments || [];
        const selected = attachments.filter((row) => row.checked !== false);
        return {
            attachmentContentDocumentIds: selected
                .filter((row) => row.contentDocumentId)
                .map((row) => row.contentDocumentId),
            newAttachmentFileNames: selected.filter((row) => row.pending && row.fileData).map((row) => row.name),
            newAttachmentFileData: selected.filter((row) => row.pending && row.fileData).map((row) => row.fileData)
        };
    }

    get previewAttachmentChips() {
        const attachments = (this._previewPayload?.attachments || []).filter((row) => row.checked !== false);
        if (!attachments.length) {
            return [];
        }
        return attachments.map((row, index) => ({
            id: row.contentDocumentId || `att-${index}`,
            name: row.name || 'File',
            typeLabel: (row.type || 'gen').toUpperCase(),
            iconClass: row.type === 'pdf' ? 'ec-att-chip-ic pdf' : 'ec-att-chip-ic gen'
        }));
    }

    get hasPreviewAttachments() {
        return this.previewAttachmentChips.length > 0;
    }

    get showNoAttachments() {
        return !this.hasPreviewAttachments;
    }

    collectEmailList(explicitList, chips) {
        const seen = new Set();
        const out = [];
        const add = (raw) => {
            const email = (raw || '').trim();
            const key = email.toLowerCase();
            if (!email || seen.has(key)) {
                return;
            }
            seen.add(key);
            out.push(email);
        };
        if (Array.isArray(chips)) {
            chips.forEach((chip) => add(chip?.email));
        }
        (explicitList || []).forEach(add);
        return out;
    }

    resolveSendPayload() {
        const freshEvent = new CustomEvent('freshsendpayload', {
            bubbles: true,
            composed: true,
            cancelable: true,
            detail: {}
        });
        this.dispatchEvent(freshEvent);
        return freshEvent.detail?.payload || this._previewPayload || {};
    }

    buildToRecipientsJson(payload) {
        const isSalesforceId = (value) => value && /^[a-zA-Z0-9]{15,18}$/.test(value);
        const isContactId = (value) => isSalesforceId(value) && value.substring(0, 3) === '003';
        const rows = (payload?.recipients || [])
            .map((chip) => {
                const email = (chip?.email || '').trim();
                if (!email) {
                    return null;
                }
                let contactId = chip.contactId && isContactId(chip.contactId) ? chip.contactId : null;
                if (!contactId && chip.audience === 'travellers' && chip.id && isContactId(chip.id)) {
                    contactId = chip.id;
                }
                if (!contactId) {
                    const emailKey = email.toLowerCase();
                    if (this._travellerContactByEmail?.has(emailKey)) {
                        contactId = this._travellerContactByEmail.get(emailKey);
                    }
                }
                let groupMemberId = null;
                if (chip.id && isSalesforceId(chip.id) && !isContactId(chip.id)) {
                    groupMemberId = chip.id;
                }
                return { email, contactId, groupMemberId };
            })
            .filter(Boolean);
        return JSON.stringify(rows);
    }

    buildDraftRecipientArraysFromPayload() {
        const isSalesforceId = (value) => value && /^[a-zA-Z0-9]{15,18}$/.test(value);
        const isContactId = (value) => isSalesforceId(value) && value.substring(0, 3) === '003';
        const resolveContactId = (chip) => {
            if (chip.contactId && isContactId(chip.contactId)) {
                return chip.contactId;
            }
            const audience = chip.audience || '';
            if (audience === 'travellers' && chip.id && isContactId(chip.id)) {
                return chip.id;
            }
            return null;
        };
        const withType = (chips, emailSendType) =>
            (chips || []).map((chip) => ({
                chip,
                emailSendType: chip.emailSendType || emailSendType
            }));
        const rows = [
            ...withType(this._previewPayload?.recipients, 'TO'),
            ...withType(this._previewPayload?.ccRecipients, 'CC'),
            ...withType(this._previewPayload?.bccRecipients, 'BCC')
        ];
        return {
            recipientRowIds: rows.map((row) => row.chip.commRecipientId || null),
            recipientContactIds: rows.map((row) => resolveContactId(row.chip)),
            recipientEmails: rows.map((row) => row.chip.email || ''),
            recipientNames: rows.map((row) => row.chip.name || row.chip.email || ''),
            recipientRoles: rows.map((row) => row.chip.role || 'Traveller'),
            recipientEmailSendTypes: rows.map((row) => row.emailSendType)
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

    async handleSaveDraft() {
        const opportunityId = this.resolveOpportunityId();
        if (!opportunityId) {
            this.showToast('Cannot save draft', 'Opportunity is required.', 'error');
            return;
        }
        if (this.isSavingDraft) {
            return;
        }
        this.isSavingDraft = true;
        try {
            await saveDraftDirect({
                commLogId: this._previewPayload?.editingCommLogId || null,
                opportunityId,
                templateId: this._previewPayload?.templateId || null,
                ...this.buildDraftRecipientArraysFromPayload(),
                ...this.buildDraftAttachmentArraysFromPayload(),
                subjectTemplate: this._previewPayload?.subjectTemplate || this.subject || '',
                bodyTemplate: this._previewPayload?.bodyTemplate || this.resolvedBody || '',
                deliveryMode: this.deliveryMode,
                channel: 'Email'
            });
            this.dispatchEvent(
                new CustomEvent('draftsaved', {
                    bubbles: true,
                    composed: true
                })
            );
            this.showToast('Draft saved', 'Your email has been saved as a draft.', 'success');
        } catch (e) {
            this.showToast('Save failed', e?.body?.message || e?.message || 'Unable to save draft.', 'error');
        } finally {
            this.isSavingDraft = false;
        }
    }

    extractApexError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (typeof error === 'string') {
            return error;
        }
        if (Array.isArray(error)) {
            return error.map((entry) => this.extractApexError(entry)).filter(Boolean).join('; ');
        }
        if (error.body) {
            if (typeof error.body.message === 'string' && error.body.message) {
                return error.body.message;
            }
            if (Array.isArray(error.body.pageErrors) && error.body.pageErrors.length) {
                return error.body.pageErrors.map((entry) => entry.message).filter(Boolean).join('; ');
            }
            if (Array.isArray(error.body) && error.body.length) {
                return this.extractApexError(error.body);
            }
        }
        if (error.message) {
            return error.message;
        }
        return 'Unknown error';
    }

    async handleSendNow() {
        if (this.sendButtonDisabled) {
            return;
        }
        if (this.scheduleMode === 'later') {
            this.showToast(
                'Scheduled send',
                'Scheduled delivery is not enabled yet. Save as draft or choose Send immediately.',
                'info'
            );
            return;
        }
        this.sendModalOpen = true;
        this.sendPhase = 'sending';
        this.sendTitle = 'Sending…';
        this.sendSubtitle = '';
        this.sendSucceeded = false;
        try {
            const attachmentPayload = this.buildDraftAttachmentArraysFromPayload();
            const payload = this.resolveSendPayload();
            const opportunityId = this.resolveOpportunityId();
            if (!opportunityId) {
                throw new Error(
                    'Opportunity is required for send. Open Communication Hub from an Opportunity record.'
                );
            }
            const toEmails = this.collectEmailList(payload.toEmails, payload.recipients);
            const ccEmails = this.collectEmailList(payload.ccEmails, payload.ccRecipients);
            const bccEmails = this.collectEmailList(payload.bccEmails, payload.bccRecipients);
            if (!toEmails.length) {
                throw new Error('At least one To recipient with an email address is required.');
            }
            const deliveryMode = this.deliveryMode === 'postmark' ? 'postmark' : 'native';
            const resolvedSubject = (this.subject || payload.subjectTemplate || payload.subject || '').trim();
            const resolvedBodyHtml = (this.resolvedBody || payload.bodyTemplate || '').trim();
            if (!resolvedSubject) {
                throw new Error('Subject is required. Return to the composer or wait for the preview to finish loading.');
            }
            if (!resolvedBodyHtml) {
                throw new Error('Email body is required. Return to the composer or wait for the preview to finish loading.');
            }
            const templateConfigId = payload.sugatiEmailTemplateConfigId || payload.templateId || null;
            const relatedRecordId = payload.relatedRecordId || opportunityId;
            const result = await sendMessage({
                opportunityId,
                toEmails,
                ccEmails,
                bccEmails,
                toEmailsJson: JSON.stringify(toEmails),
                ccEmailsJson: JSON.stringify(ccEmails),
                bccEmailsJson: JSON.stringify(bccEmails),
                toRecipientsJson: this.buildToRecipientsJson(payload),
                deliveryMode,
                orgWideEmailAddressId: payload.orgWideEmailAddressId || null,
                sugatiEmailTemplateConfigId: templateConfigId,
                relatedRecordId,
                resolvedSubject,
                resolvedBodyHtml,
                request: {
                    opportunityId,
                    templateId: payload.sugatiEmailTemplateConfigId || payload.templateId || null,
                    sugatiEmailTemplateConfigId: payload.sugatiEmailTemplateConfigId || null,
                    relatedRecordId: payload.relatedRecordId || opportunityId,
                    orgWideEmailAddressId: payload.orgWideEmailAddressId || null,
                    toEmails,
                    ccEmails,
                    bccEmails,
                    toRecipientsJson: this.buildToRecipientsJson(payload),
                    subjectTemplate: resolvedSubject,
                    bodyTemplate: resolvedBodyHtml,
                    resolvedSubject,
                    resolvedBodyHtml,
                    deliveryMode,
                    channel: this.previewChannel === 'email' ? 'Email' : this.previewChannel,
                    attachmentContentDocumentIds: attachmentPayload.attachmentContentDocumentIds,
                    newAttachmentFileNames: attachmentPayload.newAttachmentFileNames,
                    newAttachmentFileData: attachmentPayload.newAttachmentFileData
                }
            });
            if (result?.status === 'Failed') {
                throw new Error(result?.message || 'Send failed.');
            }
            this.sendSucceeded = true;
            this.sendPhase = 'sent';
            this.sendTitle = this.previewChannel === 'email' ? 'Email Sent' : 'Message Sent';
            this.sendSubtitle = result?.message || result?.status || 'Logged to Opportunity Activity History';
        } catch (e) {
            this.sendSucceeded = false;
            this.sendPhase = 'failed';
            this.sendTitle = 'Send Failed';
            this.sendSubtitle = this.extractApexError(e);
        }
    }

    handleSendComplete() {
        this.sendModalOpen = false;
        if (this.sendSucceeded) {
            this.dispatchEvent(
                new CustomEvent('sent', {
                    detail: {
                        channel: this.previewChannel,
                        subject: this.subject,
                        who: this.toLine,
                        recipients: this.toLine,
                        messageId: `PM-${Math.random().toString(36).substr(2, 9).toUpperCase()}`
                    }
                })
            );
        }
        this.sendSucceeded = false;
        this.sendPhase = 'idle';
    }

    resolveOpportunityId() {
        const candidates = [
            this.opportunityId,
            this._previewPayload?.opportunityId,
            this._pageRecordId
        ];
        for (const id of candidates) {
            if (id && String(id).startsWith('006')) {
                return id;
            }
        }
        const relatedId = this._previewPayload?.relatedRecordId;
        if (relatedId && String(relatedId).startsWith('006')) {
            return relatedId;
        }
        return null;
    }

    async loadPreview() {
        if (this.previewChannel !== 'email') {
            return;
        }
        let opportunityId = this.resolveOpportunityId();
        if (!opportunityId && !this._previewOppRetry) {
            this._previewOppRetry = true;
            await new Promise((resolve) => {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                requestAnimationFrame(resolve);
            });
            opportunityId = this.resolveOpportunityId();
        }
        if (!opportunityId) {
            this.showToast(
                'Preview limited',
                'Opportunity ID is missing. Open Communication Hub from an Opportunity record.',
                'warning'
            );
            return;
        }
        this.isPreviewLoading = true;
        try {
            const payload = this._previewPayload || {};
            const configId = payload.sugatiEmailTemplateConfigId || payload.templateId || null;
            const relatedRecordId = payload.relatedRecordId || opportunityId;
            const loaded = await loadSendEmailTemplate({
                opportunityId,
                configId,
                relatedRecordId,
                clientGroupId: null,
                previewAsContactId: this.previewAsContactId || null
            });
            this.subject = loaded?.subject || payload.subjectTemplate || payload.subject || '';
            this.resolvedBody = loaded?.bodyHtml || '';
            if (!this.resolvedBody) {
                throw new Error('Template rendered empty body. Check Email Template and Sugati Email Template configuration.');
            }
            this._pendingBodyHtml = this.resolvedBody;
        } catch (e) {
            const payload = this._previewPayload || {};
            const errMsg = e?.body?.message || e?.message || 'Unable to render email preview.';
            this.subject = payload.subjectTemplate || payload.subject || 'Preview unavailable';
            this.resolvedBody =
                '<p><strong>Preview could not be rendered.</strong></p>' +
                '<p>Fix configuration (see toast), then return to the composer and try again.</p>' +
                `<p style="color:#706e6b;font-size:12px;">${this.escapeHtml(errMsg)}</p>`;
            this._pendingBodyHtml = this.resolvedBody;
            this.showToast('Preview failed', errMsg, 'error');
        } finally {
            this.isPreviewLoading = false;
        }
    }

    escapeHtml(value) {
        return String(value || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }
}
