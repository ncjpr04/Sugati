import { LightningElement } from 'lwc';

export default class SugatiCommunicationChannelSelector extends LightningElement {
    handleEmail() {
        this.dispatchEvent(new CustomEvent('channelselect', { detail: { channel: 'email' } }));
    }

    handleWhatsApp() {
        this.dispatchEvent(new CustomEvent('channelselect', { detail: { channel: 'wa' } }));
    }

    handleInApp() {
        this.dispatchEvent(new CustomEvent('channelselect', { detail: { channel: 'ia' } }));
    }
}
