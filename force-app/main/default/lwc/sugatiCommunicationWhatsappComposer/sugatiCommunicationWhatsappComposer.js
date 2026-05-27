import { LightningElement } from 'lwc';

const DEFAULT_BODY = `Hello {{1}},

Your Tokyo Honeymoon begins in just {{2}} days! 🎉

We wanted to remind you that your Park Hyatt Tokyo check-in is on {{3}} at 3:00pm local time. Your transfer has been arranged from Narita Airport.

If you have any questions, Sarah is available on WhatsApp or by calling the Sugati Concierge line.

Safe travels,
Sugati Travel`;

const TEMPLATES_DATA = [
    { id: 'arrival_reminder', label: 'arrival_reminder', meta: 'Traveller · Approved', active: true },
    { id: 'flight_reminder',  label: 'flight_reminder',  meta: 'Traveller · Approved', active: false },
    { id: 'booking_update',   label: 'booking_update',   meta: 'Supplier · Approved',  active: false }
];

export default class SugatiCommunicationWhatsappComposer extends LightningElement {
    messageBody = DEFAULT_BODY;
    _activeTemplate = 'arrival_reminder';

    get templates() {
        return TEMPLATES_DATA.map((t) => ({
            ...t,
            className: t.id === this._activeTemplate ? 'tmpl on-wa' : 'tmpl'
        }));
    }

    handleTemplateClick(event) {
        this._activeTemplate = event.currentTarget.dataset.id;
    }

    handleBodyChange(event) {
        this.messageBody = event.target.value;
    }

    handleAiDraft() {
        // future: open AI assist
    }

    handlePreview() {
        this.dispatchEvent(new CustomEvent('navigatepreview', { detail: { channel: 'wa' }, bubbles: true, composed: true }));
    }
}
