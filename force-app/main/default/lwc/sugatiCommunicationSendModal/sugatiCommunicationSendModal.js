import { LightningElement, api } from 'lwc';

export default class SugatiCommunicationSendModal extends LightningElement {
    @api isOpen = false;
    @api phase = 'idle';
    @api title = 'Sending…';
    @api subtitle = '';
    @api recipientLabel = '';

    get overlayClass() {
        return this.isOpen ? 'send-overlay show' : 'send-overlay';
    }

    get iconClass() {
        if (this.phase === 'failed') {
            return 'send-modal-icon failed';
        }
        if (this.phase === 'sent') {
            return 'send-modal-icon sent';
        }
        if (this.phase === 'sending') {
            return 'send-modal-icon sending';
        }
        return 'send-modal-icon';
    }

    get iconText() {
        if (this.phase === 'failed') {
            return '✕';
        }
        if (this.phase === 'sent') {
            return '✓';
        }
        if (this.phase === 'sending') {
            return '⟳';
        }
        return '⟳';
    }

    get showOkButton() {
        return this.phase === 'sent' || this.phase === 'failed';
    }

    get isSuccess() {
        return this.phase === 'sent';
    }

    get isFailure() {
        return this.phase === 'failed';
    }

    get okButtonLabel() {
        return this.isFailure ? 'Close' : 'View in Activity History →';
    }

    get okButtonClass() {
        return this.isFailure ? 'send-modal-ok send-modal-ok-failed' : 'send-modal-ok';
    }

    get subtitleHtml() {
        return this.subtitle || `Dispatching via Postmark to ${this.recipientLabel}`;
    }

    handleOk() {
        this.dispatchEvent(new CustomEvent('complete'));
    }
}
