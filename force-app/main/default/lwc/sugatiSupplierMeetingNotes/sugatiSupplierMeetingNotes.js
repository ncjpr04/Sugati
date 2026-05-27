import { LightningElement, api } from 'lwc';

export default class SugatiSupplierMeetingNotes extends LightningElement {
    @api recordId;

    handleAddNote() {
        this.dispatchEvent(new CustomEvent('addnote', { bubbles: true }));
    }
}