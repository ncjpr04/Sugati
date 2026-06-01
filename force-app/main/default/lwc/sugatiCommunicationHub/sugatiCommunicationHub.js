import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getHubContext from '@salesforce/apex/SugatiCommunicationHubController.getHubContext';
import getDraftForEdit from '@salesforce/apex/SugatiCommunicationHubController.getDraftForEdit';

const VIEWS = {
    HUB: 'hub',
    CHANNEL: 'channel',
    EMAIL: 'email',
    WA: 'wa',
    IA: 'ia',
    RECIPIENTS: 'recipients',
    PREVIEW: 'preview',
    HISTORY: 'history'
};
const HARDCODED_OPPORTUNITY_ID = '006d3000005oJpNAAU';
const DEBUG_PREVIEW_FLOW = true;

export default class SugatiCommunicationHub extends LightningElement {
    @api recordId;

    currentView = VIEWS.HUB;
    _returnView = VIEWS.HUB;
    previewChannel = 'email';
    tripName = '';
    tripSubtitle = '';
    stageLabel = '';
    contextSummary = '';
    stats = { sent: 0, delivered: 0, opened: 0, draft: 0 };
    emailOpenWithTemplatePicker = false;
    showTemplatePicker = false;
    previewPayload = {};
    pendingRecipients = [];
    recipientTarget = 'to';
    toRecipients = [];
    ccRecipients = [];
    bccRecipients = [];
    draftForEdit = null;
    historyRefreshKey = 0;
    _wiredHubContextResult;
    _pageRecordId;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        const recordId = pageRef?.attributes?.recordId;
        if (recordId && String(recordId).startsWith('006')) {
            this._pageRecordId = recordId;
        }
    }

    get effectiveOpportunityId() {
        if (this.recordId && String(this.recordId).startsWith('006')) {
            return this.recordId;
        }
        if (this._pageRecordId) {
            return this._pageRecordId;
        }
        return HARDCODED_OPPORTUNITY_ID;
    }

    get emailDraftStorageKey() {
        return `sugati.email.draft.${this.effectiveOpportunityId || 'default'}`;
    }

    clearEmailDraftStorage() {
        try {
            window.localStorage.removeItem(this.emailDraftStorageKey);
        } catch (e) {
            // ignore storage errors
        }
    }

    beginNewMessage() {
        this.draftForEdit = null;
        this.previewPayload = {};
        this.toRecipients = [];
        this.ccRecipients = [];
        this.bccRecipients = [];
        this.clearEmailDraftStorage();
    }

    prepareEmailComposerForNewMessage() {
        Promise.resolve().then(() => {
            const composer = this.template.querySelector('c-sugati-communication-email-composer');
            if (composer && typeof composer.startNewCompose === 'function') {
                composer.startNewCompose();
            }
        });
    }

    @wire(getHubContext, { opportunityId: '$effectiveOpportunityId' })
    wiredHubContext(result) {
        this._wiredHubContextResult = result;
        const data = result?.data;
        if (!data) {
            return;
        }
        this.tripName = data.opportunityName || this.tripName;
        this.tripSubtitle = data.ownerName || this.tripSubtitle;
        this.stageLabel = data.stageLabel || this.stageLabel;
        this.stats = {
            sent: data.sentCount ?? this.stats.sent,
            delivered: data.deliveredCount ?? this.stats.delivered,
            opened: data.openedCount ?? this.stats.opened,
            draft: data.draftCount ?? this.stats.draft
        };
    }

    get hubPageClass() {
        return this.showHub ? 'page on' : 'page page-off';
    }

    async refreshHubData() {
        const tasks = [];
        if (this._wiredHubContextResult) {
            tasks.push(refreshApex(this._wiredHubContextResult));
        }
        this.template.querySelectorAll('c-sugati-communication-history').forEach((history) => {
            if (history && typeof history.refreshHistory === 'function') {
                tasks.push(history.refreshHistory());
            }
        });
        await Promise.all(tasks);
    }

    scheduleHubDataRefresh() {
        this.historyRefreshKey += 1;
        // Allow hub history (kept mounted) to re-render, then bust cacheable Apex wires.
        requestAnimationFrame(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            Promise.resolve(this.refreshHubData()).catch(() => { });
        });
    }

    get showHub() {
        return this.currentView === VIEWS.HUB;
    }

    get showChannel() {
        return this.currentView === VIEWS.CHANNEL;
    }

    get showEmail() {
        return this.currentView === VIEWS.EMAIL;
    }

    get showEmailComposerShell() {
        return (
            this.currentView === VIEWS.EMAIL ||
            this.currentView === VIEWS.RECIPIENTS ||
            this.currentView === VIEWS.PREVIEW
        );
    }

    get hideEmailComposer() {
        return this.currentView === VIEWS.RECIPIENTS || this.currentView === VIEWS.PREVIEW;
    }

    get showWa() {
        return this.currentView === VIEWS.WA;
    }

    get showIa() {
        return this.currentView === VIEWS.IA;
    }

    get showRecipients() {
        return this.currentView === VIEWS.RECIPIENTS;
    }

    get showPreview() {
        return this.currentView === VIEWS.PREVIEW;
    }

    get showHistory() {
        return this.currentView === VIEWS.HISTORY;
    }

    get hubNavClass() {
        return this.currentView === VIEWS.HUB ? 'tn on' : 'tn';
    }

    get emailNavClass() {
        return this.currentView === VIEWS.EMAIL ? 'tn on' : 'tn';
    }

    get waNavClass() {
        return this.currentView === VIEWS.WA ? 'tn on' : 'tn';
    }

    get iaNavClass() {
        return this.currentView === VIEWS.IA ? 'tn on' : 'tn';
    }

    get newMsgNavClass() {
        return this.currentView === VIEWS.CHANNEL ? 'tn on' : 'tn';
    }

    get historyNavClass() {
        return this.currentView === VIEWS.HISTORY ? 'tn on' : 'tn';
    }

    handleNewMessage() {
        this.beginNewMessage();
        this.currentView = VIEWS.CHANNEL;
    }

    handleChannelSelect(event) {
        const { channel } = event.detail;
        if (channel === 'email') {
            this.beginNewMessage();
            this.emailOpenWithTemplatePicker = true;
            this.currentView = VIEWS.EMAIL;
            this.prepareEmailComposerForNewMessage();
        } else if (channel === 'wa') {
            this.currentView = VIEWS.WA;
        } else if (channel === 'ia') {
            this.currentView = VIEWS.IA;
        }
    }

    handleNavigateRecipients(event) {
        this.emailOpenWithTemplatePicker = false;
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (composer) {
            if (typeof composer.persistComposerState === 'function') {
                composer.persistComposerState();
            }
            if (typeof composer.getRecipientState === 'function') {
                const state = composer.getRecipientState();
                this.toRecipients = state?.to || this.toRecipients;
                this.ccRecipients = state?.cc || this.ccRecipients;
                this.bccRecipients = state?.bcc || this.bccRecipients;
            }
        }
        const target = event?.detail?.target || 'to';
        this.recipientTarget = target === 'cc' || target === 'bcc' ? target : 'to';
        if (this.pendingRecipients.length) {
            this.toRecipients = [...this.pendingRecipients];
            this.pendingRecipients = [];
        }
        this.currentView = VIEWS.RECIPIENTS;
    }

    handleRecipientsApply(event) {
        const selected = (event.detail?.recipients || []).filter((r) => (r?.email || '').trim());
        if (this.recipientTarget === 'cc') {
            this.ccRecipients = selected;
        } else if (this.recipientTarget === 'bcc') {
            this.bccRecipients = selected;
        } else {
            this.toRecipients = selected;
        }
        this.currentView = VIEWS.EMAIL;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            this.applySelectedRecipients();
            this.syncRecipientStateFromComposer();
        });
    }

    handleRecipientsBack() {
        this.currentView = VIEWS.EMAIL;
    }

    handleDraftDiscarded(event) {
        if (event?.detail?.hadSavedDraft) {
            this.currentView = VIEWS.HUB;
        }
        this.scheduleHubDataRefresh();
    }

    handleDraftSaved() {
        this.clearEmailDraftStorage();
        this.emailOpenWithTemplatePicker = false;
        this.showTemplatePicker = false;
        this.currentView = VIEWS.HUB;
        Promise.resolve().then(() => {
            const composer = this.template.querySelector('c-sugati-communication-email-composer');
            if (composer && typeof composer.resetComposer === 'function') {
                composer.resetComposer();
            }
            this.scheduleHubDataRefresh();
        });
    }

    buildSendPayloadFromComposer(basePayload) {
        const payload = { ...(basePayload || this.previewPayload || {}) };
        if (this.previewChannel !== 'email') {
            return payload;
        }
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (!composer || typeof composer.getRecipientState !== 'function') {
            return payload;
        }
        const state = composer.getRecipientState();
        const to = state?.to || [];
        const cc = state?.cc || [];
        const bcc = state?.bcc || [];
        const emailFromRows = (rows) => (rows || []).map((r) => (r?.email || '').trim()).filter(Boolean);
        let templateContext = {};
        if (typeof composer.getEmailSendContext === 'function') {
            templateContext = composer.getEmailSendContext() || {};
        }
        return {
            ...payload,
            recipients: to,
            ccRecipients: cc,
            bccRecipients: bcc,
            toEmails: emailFromRows(to),
            ccEmails: emailFromRows(cc),
            bccEmails: emailFromRows(bcc),
            sugatiEmailTemplateConfigId:
                templateContext.sugatiEmailTemplateConfigId || payload.sugatiEmailTemplateConfigId || null,
            relatedRecordId:
                templateContext.relatedRecordId || payload.relatedRecordId || this.effectiveOpportunityId
        };
    }

    handleFreshSendPayload(event) {
        event.preventDefault();
        const payload = this.buildSendPayloadFromComposer();
        this.previewPayload = payload;
        event.detail.payload = payload;
    }

    handleNavigatePreview(event) {
        if (DEBUG_PREVIEW_FLOW) {
            console.log(
                '[Hub] handleNavigatePreview detail',
                JSON.parse(JSON.stringify(event?.detail || {}))
            );
        }
        this.previewChannel = event.detail?.channel || 'email';
        this.previewPayload = this.buildSendPayloadFromComposer({
            ...(event.detail || {}),
            opportunityId: this.effectiveOpportunityId
        });
        if (DEBUG_PREVIEW_FLOW) {
            console.log('[Hub] previewPayload assigned', JSON.parse(JSON.stringify(this.previewPayload)));
        }
        this.currentView = VIEWS.PREVIEW;
    }

    handlePreviewBack(event) {
        const ch = event.detail?.channel || this.previewChannel;
        if (ch === 'wa') {
            this.currentView = VIEWS.WA;
        } else if (ch === 'ia') {
            this.currentView = VIEWS.IA;
        } else {
            this.currentView = VIEWS.EMAIL;
        }
    }

    handleSent() {
        this.beginNewMessage();
        this.clearEmailDraftStorage();
        this.currentView = VIEWS.HISTORY;
        Promise.resolve().then(() => {
            const composer = this.template.querySelector('c-sugati-communication-email-composer');
            if (composer && typeof composer.resetComposer === 'function') {
                composer.resetComposer();
            }
        });
        this.scheduleHubDataRefresh();
    }

    handleHistoryChannelNav(event) {
        const { channel } = event.detail;
        if (channel === 'email') {
            this.currentView = VIEWS.EMAIL;
        } else if (channel === 'wa') {
            this.currentView = VIEWS.WA;
        } else if (channel === 'ia') {
            this.currentView = VIEWS.IA;
        }
    }

    async handleContinueDraft(event) {
        const commLogId = event?.detail?.commLogId;
        if (!commLogId) {
            this.draftForEdit = null;
            this.currentView = VIEWS.EMAIL;
            return;
        }
        try {
            const draft = await getDraftForEdit({ commLogId });
            this.draftForEdit = draft;
            this.currentView = VIEWS.EMAIL;
            this.syncRecipientStateFromComposer();
        } catch (e) {
            this.draftForEdit = null;
            // eslint-disable-next-line no-console
            console.error('Failed to load draft for editing', e);
        }
    }

    syncRecipientStateFromComposer() {
        Promise.resolve().then(() => {
            const composer = this.template.querySelector('c-sugati-communication-email-composer');
            if (!composer || typeof composer.getRecipientState !== 'function') {
                return;
            }
            const state = composer.getRecipientState();
            this.toRecipients = state?.to || [];
            this.ccRecipients = state?.cc || [];
            this.bccRecipients = state?.bcc || [];
        });
    }

    handleViewHistory() {
        this.currentView = VIEWS.HISTORY;
    }

    handleViewHub() {
        this.currentView = VIEWS.HUB;
        this.scheduleHubDataRefresh();
    }

    handleViewEmail() {
        this.emailOpenWithTemplatePicker = false;
        this.showTemplatePicker = false;
        this.draftForEdit = null;
        this.currentView = VIEWS.EMAIL;
        Promise.resolve().then(() => {
            const composer = this.template.querySelector('c-sugati-communication-email-composer');
            if (composer && typeof composer.loadDefaultTemplate === 'function') {
                composer.loadDefaultTemplate();
            }
        });
    }

    handleViewWa() {
        this.emailOpenWithTemplatePicker = false;
        this.showTemplatePicker = false;
        this.draftForEdit = null;
        this.currentView = VIEWS.WA;
    }

    handleViewIa() {
        this.emailOpenWithTemplatePicker = false;
        this.showTemplatePicker = false;
        this.draftForEdit = null;
        this.currentView = VIEWS.IA;
    }

    handleOpenTemplatePicker() {
        this.showTemplatePicker = true;
    }

    handleCloseTemplatePicker() {
        this.showTemplatePicker = false;
        this.emailOpenWithTemplatePicker = false;
    }

    handleTemplatePickerSelect(event) {
        this.showTemplatePicker = false;
        this.emailOpenWithTemplatePicker = false;
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (composer) {
            if (typeof composer.applyLegacyTemplateSelection === 'function') {
                composer.applyLegacyTemplateSelection(event.detail);
            } else if (typeof composer.applyTemplateSelection === 'function') {
                composer.applyTemplateSelection(event.detail);
            }
        }
    }

    mergeRecipientsByEmail(existing, selected) {
        const byEmail = new Map();
        (existing || []).forEach((row) => {
            const email = (row.email || '').trim().toLowerCase();
            if (email) {
                byEmail.set(email, row);
            }
        });
        (selected || []).forEach((row) => {
            const email = (row.email || '').trim().toLowerCase();
            if (email) {
                byEmail.set(email, row);
            }
        });
        return [...byEmail.values()];
    }

    applySelectedRecipients() {
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (!composer) {
            return;
        }
        const rows = this.getActiveRecipientListForPicker() || [];
        if (this.recipientTarget === 'cc') {
            if (typeof composer.setCcRecipients === 'function') {
                composer.setCcRecipients(this.ccRecipients);
            }
        } else if (this.recipientTarget === 'bcc') {
            if (typeof composer.setBccRecipients === 'function') {
                composer.setBccRecipients(this.bccRecipients);
            }
        } else if (typeof composer.setRecipients === 'function') {
            composer.setRecipients(this.toRecipients);
        }
    }

    get composerHostClass() {
        return this.hideEmailComposer ? 'composer-host composer-host-hidden' : 'composer-host';
    }

    getActiveRecipientListForPicker() {
        if (this.recipientTarget === 'cc') {
            return this.ccRecipients || [];
        }
        if (this.recipientTarget === 'bcc') {
            return this.bccRecipients || [];
        }
        return this.toRecipients || [];
    }

    get selectedRecipientIds() {
        return (this.getActiveRecipientListForPicker() || [])
            .map((r) => r.contactId || (this.isContactRowId(r.id) ? r.id : null))
            .filter(Boolean);
    }

    isContactRowId(value) {
        return value && /^003[a-zA-Z0-9]{12,15}$/.test(value);
    }

    get selectedRecipientEmails() {
        return (this.getActiveRecipientListForPicker() || [])
            .map((r) => (r.email || '').trim().toLowerCase())
            .filter(Boolean);
    }
}
