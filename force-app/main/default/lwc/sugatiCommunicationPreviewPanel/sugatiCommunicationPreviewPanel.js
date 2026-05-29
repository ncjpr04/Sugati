import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import previewMessageDirect from '@salesforce/apex/SugatiCommunicationHubController.previewMessageDirect';
import sendMessage from '@salesforce/apex/SugatiCommunicationHubController.sendMessage';
import saveDraftDirect from '@salesforce/apex/SugatiCommunicationHubController.saveDraftDirect';

const DEBUG_PREVIEW_FLOW = true;

export default class SugatiCommunicationPreviewPanel extends LightningElement {
    @api opportunityId;
    @api initialChannel = 'email';
    @api subject = '';
    _previewPayload = {};
    _isConnected = false;
    _previewRequestSeq = 0;

    previewChannel = 'email';
    showCover = true;
    deliveryMode = 'postmark';
    scheduleMode = 'now';
    previewAs = 'hiroshi';

    sendModalOpen = false;
    sendPhase = 'idle';
    sendTitle = 'Sending…';
    sendSubtitle = '';
    resolvedBody = '';
    unresolvedTokens = [];
    recipientLabel = '';
    fromLabel = '';
    _pendingBodyHtml = '';
    isPreviewLoading = false;
    isSavingDraft = false;

    @api
    get previewPayload() {
        return this._previewPayload;
    }

    set previewPayload(value) {
        this._previewPayload = value || {};
        if (DEBUG_PREVIEW_FLOW) {
            console.log('[Preview] previewPayload set', this.debugStringify(this._previewPayload));
        }
        this.fromLabel = this._previewPayload?.fromLabel || '';
        this.recipientLabel = (this._previewPayload?.recipients || []).map((r) => r.name).join(', ');
        if (this._isConnected) {
            this.loadPreview();
        }
    }

    connectedCallback() {
        this._isConnected = true;
        this.previewChannel = this.initialChannel || 'email';
        if (DEBUG_PREVIEW_FLOW) {
            console.log(
                '[Preview] connectedCallback',
                this.debugStringify({
                    previewChannel: this.previewChannel,
                    opportunityId: this.opportunityId
                })
            );
        }
        if (this._previewPayload?.subject) {
            this.subject = this._previewPayload.subject;
        }
        this.fromLabel = this._previewPayload?.fromLabel || '';
        this.recipientLabel = (this._previewPayload?.recipients || []).map((r) => r.name).join(', ');
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

    get sendBtnClass() {
        const ch = this.previewChannel;
        return `send-btn ${ch === 'wa' ? 'wa' : ch === 'ia' ? 'ia' : 'email'}`;
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
        const chips = [
            ...(this._previewPayload?.recipients || []),
            ...(this._previewPayload?.ccRecipients || [])
        ];
        return {
            recipientRowIds: chips.map((chip) => chip.commRecipientId || null),
            recipientContactIds: chips.map((chip) => resolveContactId(chip)),
            recipientEmails: chips.map((chip) => chip.email || ''),
            recipientNames: chips.map((chip) => chip.name || chip.email || ''),
            recipientRoles: chips.map((chip) => chip.role || 'Traveller')
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
        if (!this.opportunityId) {
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
                opportunityId: this.opportunityId,
                templateId: this._previewPayload?.templateId || null,
                ...this.buildDraftRecipientArraysFromPayload(),
                ...this.buildDraftAttachmentArraysFromPayload(),
                subjectTemplate: this._previewPayload?.subjectTemplate || this.subject || '',
                bodyTemplate: this._previewPayload?.bodyTemplate || this.resolvedBody || '',
                deliveryMode: this._previewPayload?.deliveryMode || this.deliveryMode,
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

    async handleSendNow() {
        this.sendModalOpen = true;
        this.sendPhase = 'sending';
        this.sendTitle = 'Sending…';
        this.sendSubtitle = '';
        try {
            const recipients = [
                ...(this.previewPayload?.recipients || []),
                ...(this.previewPayload?.ccRecipients || [])
            ];
            const recipientIds = recipients.map((r) => r.id).filter(Boolean);
            const recipientEmails = recipients.map((r) => r.email).filter(Boolean);
            const recipientNames = recipients.map((r) => r.name || r.email || '');
            const attachmentPayload = this.buildDraftAttachmentArraysFromPayload();
            const result = await sendMessage({
                request: {
                    opportunityId: this.opportunityId,
                    templateId: this.previewPayload?.templateId || null,
                    recipientIds,
                    recipientEmails,
                    recipientNames,
                    subjectTemplate: this.previewPayload?.subjectTemplate || this.subject,
                    bodyTemplate: this.previewPayload?.bodyTemplate || '',
                    resolvedSubject: this.subject,
                    resolvedBodyHtml: this.resolvedBody,
                    deliveryMode: this.previewPayload?.deliveryMode || this.deliveryMode,
                    channel: this.previewChannel === 'email' ? 'Email' : this.previewChannel,
                    attachmentContentDocumentIds: attachmentPayload.attachmentContentDocumentIds,
                    newAttachmentFileNames: attachmentPayload.newAttachmentFileNames,
                    newAttachmentFileData: attachmentPayload.newAttachmentFileData
                }
            });
            this.sendPhase = 'sent';
            this.sendTitle = this.previewChannel === 'email' ? 'Email Sent' : 'Message Sent';
            this.sendSubtitle = result?.status || 'Logged to Opportunity Activity History';
        } catch (e) {
            this.sendPhase = 'sent';
            this.sendTitle = 'Send Failed';
            this.sendSubtitle = e?.body?.message || e?.message || 'Unknown error';
        }
    }

    handleSendComplete() {
        this.sendModalOpen = false;
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

    async loadPreview() {
        if (!this.opportunityId || this.previewChannel !== 'email') {
            return;
        }
        const requestSeq = ++this._previewRequestSeq;
        this.isPreviewLoading = true;
        try {
            const recipients = [
                ...(this._previewPayload?.recipients || []),
                ...(this._previewPayload?.ccRecipients || [])
            ];
            const recipientIds = recipients.map((r) => r.id).filter(Boolean);
            const recipientEmails = recipients.map((r) => r.email).filter(Boolean);
            const recipientNames = recipients.map((r) => r.name || r.email || '');
            const requestPayload = {
                opportunityId: this.opportunityId,
                templateId: this._previewPayload?.templateId || null,
                recipientIds,
                recipientEmails,
                recipientNames,
                subjectTemplate: this._previewPayload?.subjectTemplate || this.subject,
                bodyTemplate: this._previewPayload?.bodyTemplate || ''
            };
            if (DEBUG_PREVIEW_FLOW) {
                console.log(`[Preview] loadPreview request#${requestSeq}`, this.debugStringify(requestPayload));
            }
            const result = await previewMessageDirect({
                opportunityId: requestPayload.opportunityId,
                templateId: requestPayload.templateId,
                recipientIds: requestPayload.recipientIds,
                recipientEmails: requestPayload.recipientEmails,
                recipientNames: requestPayload.recipientNames,
                subjectTemplate: requestPayload.subjectTemplate,
                bodyTemplate: requestPayload.bodyTemplate
            });
            if (requestSeq !== this._previewRequestSeq) {
                return;
            }
            if (DEBUG_PREVIEW_FLOW) {
                console.log(`[Preview] loadPreview response#${requestSeq}`, this.debugStringify(result || {}));
            }
            const apexResolvedSubject = result?.subject ?? '';
            const apexResolvedBody = result?.bodyHtml || '';
            this.subject = apexResolvedSubject;
            this.resolvedBody = apexResolvedBody;
            this._pendingBodyHtml = this.resolvedBody;
            this.unresolvedTokens = result?.unresolvedTokens || [];
            if (DEBUG_PREVIEW_FLOW) {
                console.log(
                    `[Preview] final render state#${requestSeq}`,
                    this.debugStringify({
                        subject: this.subject,
                        resolvedBody: this.resolvedBody,
                        unresolvedTokens: this.unresolvedTokens
                    })
                );
            }
        } catch (e) {
            if (requestSeq !== this._previewRequestSeq) {
                return;
            }
            if (DEBUG_PREVIEW_FLOW) {
                console.error(
                    `[Preview] loadPreview error#${requestSeq}`,
                    this.debugStringify({
                        message: e?.body?.message || e?.message || 'Unknown error',
                        bodyMessage: e?.body?.message || null,
                        body: e?.body || null,
                        stack: e?.stack || null
                    })
                );
            }
            this.subject = '';
            this.unresolvedTokens = [];
            this.resolvedBody = '';
            this._pendingBodyHtml = '<p>Unable to generate preview.</p>';
        } finally {
            if (requestSeq === this._previewRequestSeq) {
                this.isPreviewLoading = false;
            }
        }
    }

    debugStringify(value) {
        try {
            return JSON.stringify(value);
        } catch (e) {
            return String(value);
        }
    }
}
