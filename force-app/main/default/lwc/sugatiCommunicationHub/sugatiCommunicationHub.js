import { LightningElement, api, wire } from 'lwc';
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
    TOKENS: 'tokens',
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
    tokenInsertTarget = 'body';
    composerDraftState = null;
    draftForEdit = null;
    historyRefreshKey = 0;
    _wiredHubContextResult;

    get effectiveOpportunityId() {
        return HARDCODED_OPPORTUNITY_ID;
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
            Promise.resolve(this.refreshHubData()).catch(() => {});
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

    get showTokens() {
        return this.currentView === VIEWS.TOKENS;
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

    get tokensNavClass() {
        return this.currentView === VIEWS.TOKENS ? 'tn on' : 'tn';
    }

    isComposerView(view) {
        return view === VIEWS.EMAIL || view === VIEWS.WA || view === VIEWS.IA;
    }

    handleNewMessage() {
        this.currentView = VIEWS.CHANNEL;
    }

    handleChannelSelect(event) {
        const { channel } = event.detail;
        if (channel === 'email') {
            this.emailOpenWithTemplatePicker = true;
            this.currentView = VIEWS.EMAIL;
        } else if (channel === 'wa') {
            this.currentView = VIEWS.WA;
        } else if (channel === 'ia') {
            this.currentView = VIEWS.IA;
        }
    }

    handleNavigateRecipients(event) {
        this.emailOpenWithTemplatePicker = false;
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (composer && typeof composer.getRecipientState === 'function') {
            const state = composer.getRecipientState();
            this.toRecipients = state?.to || this.toRecipients;
            this.ccRecipients = state?.cc || this.ccRecipients;
        }
        this.recipientTarget = event?.detail?.target === 'cc' ? 'cc' : 'to';
        if (this.pendingRecipients.length) {
            this.toRecipients = [...this.pendingRecipients];
            this.pendingRecipients = [];
        }
        this.currentView = VIEWS.RECIPIENTS;
    }

    handleEmailNavigateTokens(event) {
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (composer && typeof composer.getComposeState === 'function') {
            this.composerDraftState = composer.getComposeState();
        }
        this.tokenInsertTarget = event?.detail?.target || 'body';
        this._returnView = VIEWS.EMAIL;
        this.currentView = VIEWS.TOKENS;
    }

    handleRecipientsApply(event) {
        const selected = event.detail?.recipients || [];
        if (this.recipientTarget === 'cc') {
            this.ccRecipients = selected;
        } else {
            this.toRecipients = selected;
        }
        this.currentView = VIEWS.EMAIL;
        Promise.resolve().then(() => this.applySelectedRecipients());
    }

    handleRecipientsBack() {
        this.currentView = VIEWS.CHANNEL;
    }

    handleDraftDiscarded(event) {
        if (event?.detail?.hadSavedDraft) {
            this.currentView = VIEWS.HUB;
        }
        this.scheduleHubDataRefresh();
    }

    handleDraftSaved() {
        try {
            window.localStorage.removeItem(`sugati.email.draft.${this.effectiveOpportunityId || 'default'}`);
        } catch (e) {
            // ignore
        }
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

    handleNavigatePreview(event) {
        if (DEBUG_PREVIEW_FLOW) {
            console.log(
                '[Hub] handleNavigatePreview detail',
                JSON.parse(JSON.stringify(event?.detail || {}))
            );
        }
        this.previewChannel = event.detail?.channel || 'email';
        this.previewPayload = { ...(event.detail || {}) };
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
        this.currentView = VIEWS.HISTORY;
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
        } catch (e) {
            this.draftForEdit = null;
            // eslint-disable-next-line no-console
            console.error('Failed to load draft for editing', e);
        }
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

    handleViewTokens() {
        const fromView = this.currentView;
        this._returnView =
            fromView === VIEWS.TOKENS || !this.isComposerView(fromView) ? VIEWS.EMAIL : fromView;
        this.currentView = VIEWS.TOKENS;
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
            composer.applyTemplateSelection(event.detail);
        }
    }

    handleTokensBack() {
        this.currentView = this._returnView || VIEWS.EMAIL;
    }

    handleTokensInsert(event) {
        const token = event.detail?.token;
        const target = this.tokenInsertTarget || 'body';
        const returnView = this._returnView || VIEWS.EMAIL;
        this.currentView = returnView;
        if (returnView !== VIEWS.EMAIL) {
            this.composerDraftState = null;
            return;
        }
        Promise.resolve().then(() => {
            const composer = this.template.querySelector('c-sugati-communication-email-composer');
            if (!composer) return;
            if (this.composerDraftState && typeof composer.applyComposeState === 'function') {
                composer.applyComposeState(this.composerDraftState);
            }
            if (token && typeof composer.insertToken === 'function') {
                composer.insertToken(token, target);
            }
            this.composerDraftState = null;
        });
    }

    applySelectedRecipients() {
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (!composer) {
            return;
        }
        if (typeof composer.setRecipients === 'function') {
            composer.setRecipients(this.toRecipients);
        }
        if (typeof composer.setCcRecipients === 'function') {
            composer.setCcRecipients(this.ccRecipients);
        }
    }

    get selectedRecipientIds() {
        const list = this.recipientTarget === 'cc' ? this.ccRecipients : this.toRecipients;
        return (list || []).map((r) => r.id).filter(Boolean);
    }
}
