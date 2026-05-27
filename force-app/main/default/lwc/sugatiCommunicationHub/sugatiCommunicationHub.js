import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import OPPORTUNITY_NAME from '@salesforce/schema/Opportunity.Name';

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

export default class SugatiCommunicationHub extends LightningElement {
    @api recordId;

    currentView = VIEWS.HUB;
    _returnView = VIEWS.HUB;
    previewChannel = 'email';
    tripName = 'Tokyo Honeymoon 2026';
    tripSubtitle = 'Yamamura';
    stageLabel = 'Pre-Departure';
    stats = { sent: 8, delivered: 5, opened: 2, draft: 1 };
    emailOpenWithTemplatePicker = false;
    showTemplatePicker = false;

    @wire(getRecord, { recordId: '$recordId', fields: [OPPORTUNITY_NAME] })
    wiredOpportunity({ data }) {
        if (data) {
            this.tripName = data.fields.Name.value || this.tripName;
        }
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

    get newMsgNavClass() {
        return this.currentView === VIEWS.CHANNEL ? 'tn on' : 'tn';
    }

    get historyNavClass() {
        return this.currentView === VIEWS.HISTORY ? 'tn on' : 'tn';
    }

    get tokensNavClass() {
        return this.currentView === VIEWS.TOKENS ? 'tn on' : 'tn';
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

    handleNavigateRecipients() {
        this.emailOpenWithTemplatePicker = false;
        this.currentView = VIEWS.RECIPIENTS;
    }

    handleEmailNavigateTokens() {
        this._returnView = VIEWS.EMAIL;
        this.currentView = VIEWS.TOKENS;
    }

    handleRecipientsApply(event) {
        this.currentView = VIEWS.EMAIL;
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (composer) {
            composer.setRecipients(event.detail.recipients);
        }
    }

    handleRecipientsBack() {
        this.currentView = VIEWS.CHANNEL;
    }

    handleNavigatePreview(event) {
        this.previewChannel = event.detail?.channel || 'email';
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

    handleSent(event) {
        this.currentView = VIEWS.HISTORY;
        const history = this.template.querySelector('c-sugati-communication-history');
        if (history) {
            history.addSentEntry({
                subject: event.detail?.subject,
                who: 'Hiroshi & Akemi Yamamura',
                messageId: event.detail?.messageId
            });
        }
        this.stats = { ...this.stats, sent: this.stats.sent + 1 };
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

    handleContinueDraft() {
        this.currentView = VIEWS.EMAIL;
    }

    handleViewHistory() {
        this.currentView = VIEWS.HISTORY;
    }

    handleViewHub() {
        this.currentView = VIEWS.HUB;
    }

    handleViewTokens() {
        this._returnView = this.currentView === VIEWS.TOKENS ? VIEWS.EMAIL : this.currentView;
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
        const composer = this.template.querySelector('c-sugati-communication-email-composer');
        if (token && composer && typeof composer.insertToken === 'function') {
            composer.insertToken(token);
        }
        this.currentView = this._returnView || VIEWS.EMAIL;
    }
}
