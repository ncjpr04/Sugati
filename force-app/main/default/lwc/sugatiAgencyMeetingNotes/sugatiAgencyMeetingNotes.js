import { LightningElement, api, track, wire } from 'lwc';

export default class SugatiAgencyMeetingNotes extends LightningElement {

    handleAddNote() {
        console.log('Action: Add Note clicked');
    }
}