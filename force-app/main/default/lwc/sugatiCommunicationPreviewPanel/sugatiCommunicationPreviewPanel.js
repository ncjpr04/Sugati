import { LightningElement, api } from 'lwc';

export default class SugatiCommunicationPreviewPanel extends LightningElement {
    @api initialChannel = 'email';
    @api subject = 'Your Tokyo Honeymoon — Final Itinerary & Arrival Details';

    previewChannel = 'email';
    showCover = true;
    deliveryMode = 'postmark';
    scheduleMode = 'now';
    previewAs = 'hiroshi';

    sendModalOpen = false;
    sendPhase = 'idle';
    sendTitle = 'Sending…';
    sendSubtitle = '';

    connectedCallback() {
        this.previewChannel = this.initialChannel || 'email';
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

    handleSendNow() {
        this.sendModalOpen = true;
        this.sendPhase = 'sending';
        this.sendTitle = 'Sending…';
        this.sendSubtitle = '';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.sendPhase = 'sent';
            this.sendTitle = this.previewChannel === 'email' ? 'Email Sent' : 'Message Sent';
            this.sendSubtitle = 'Logged to Opportunity Activity History';
        }, 1800);
    }

    handleSendComplete() {
        this.sendModalOpen = false;
        this.dispatchEvent(
            new CustomEvent('sent', {
                detail: {
                    channel: this.previewChannel,
                    subject: this.subject,
                    messageId: `PM-${Math.random().toString(36).substr(2, 9).toUpperCase()}`
                }
            })
        );
    }
}
