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
        if (this.phase === 'sent') {
            return 'send-modal-icon sent';
        }
        if (this.phase === 'sending') {
            return 'send-modal-icon sending';
        }
        return 'send-modal-icon';
    }

    get iconText() {
        if (this.phase === 'sent') {
            return '✓';
        }
        if (this.phase === 'sending') {
            return '⟳';
        }
        return '⟳';
    }

    get showOkButton() {
        return this.phase === 'sent';
    }

    get subtitleHtml() {
        return this.subtitle || `Dispatching via Postmark to ${this.recipientLabel}`;
    }

    handleOk() {
        this.dispatchEvent(new CustomEvent('complete'));
    }
}
