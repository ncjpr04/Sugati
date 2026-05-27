import { LightningElement } from 'lwc';

const NOTIF_TYPES = [
    { id: 'doc',       icon: '📄', label: 'Document', tmplLabel: 'Document Available', tmplMeta: 'Documents · Alert' },
    { id: 'trip',      icon: '✈',  label: 'Trip Update', tmplLabel: 'Trip Update',     tmplMeta: 'Itinerary change' },
    { id: 'concierge', icon: '💬', label: 'Concierge', tmplLabel: 'Concierge Message', tmplMeta: 'Personalised' }
];

export default class SugatiCommunicationInAppComposer extends LightningElement {
    title = 'Your itinerary documents are ready';
    body = 'Your final Tokyo itinerary, hotel vouchers, and Japan entry requirements are now available in your trip documents. Tap to view and download.';
    documentLink = 'Trip Documents — Tokyo Honeymoon 2026';

    _activeType = 'doc';

    get notifTypesDisplay() {
        return NOTIF_TYPES.map((t) => ({
            ...t,
            className: t.id === this._activeType ? 'ia-nt-opt on' : 'ia-nt-opt',
            tmplClass: t.id === this._activeType ? 'tmpl on-ia' : 'tmpl'
        }));
    }

    handleTypeClick(event) {
        this._activeType = event.currentTarget.dataset.id;
    }

    handleTitleChange(event)    { this.title        = event.target.value; }
    handleBodyChange(event)     { this.body         = event.target.value; }
    handleLinkChange(event)     { this.documentLink = event.target.value; }

    handlePreview() {
        this.dispatchEvent(new CustomEvent('navigatepreview', { detail: { channel: 'ia' }, bubbles: true, composed: true }));
    }
}
