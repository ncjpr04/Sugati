import { LightningElement, api } from 'lwc';

const OBJECT_GROUPS = [
    { id: 'opportunity', label: 'Opportunity', count: 14 },
    { id: 'traveller', label: 'Traveller', count: 8 },
    { id: 'lead', label: 'Lead Booker', count: 6 },
    { id: 'client', label: 'Client Group', count: 5 },
    { id: 'supplier', label: 'Supplier', count: 7 },
    { id: 'supcontact', label: 'Supplier Contact', count: 5 },
    { id: 'supbooking', label: 'Supplier Booking', count: 9 },
    { id: 'cost', label: 'Cost & Payment', count: 6 }
];

const FIELDS_BY_OBJECT = {
    opportunity: [
        { name: 'Trip Name', api: 'Opportunity.Name', highlight: false },
        { name: 'Start Date', api: 'Start_Date__c', highlight: true },
        { name: 'End Date', api: 'End_Date__c', highlight: false },
        { name: 'Days Until Departure', api: 'Formula field', highlight: true },
        { name: 'Destination Country', api: 'Travelling_Country__c', highlight: false },
        { name: 'Trip Value', api: 'Amount', highlight: false },
        { name: 'Balance Due', api: 'Balance_Due__c', highlight: false },
        { name: 'Payment Due Date', api: 'Payment_Due_Date__c', highlight: false },
        { name: 'Specialist Name', api: 'Owner.Name', highlight: true },
        { name: 'Specialist Email', api: 'Owner.Email', highlight: false },
        { name: 'First Accommodation', api: 'First Supplier_Booking', highlight: true },
        { name: 'Reference Number', api: 'Reference__c', highlight: false },
        { name: 'Stage', api: 'StageName', highlight: false },
        { name: 'Specialist Phone', api: 'Owner.Phone', highlight: false }
    ],
    traveller: [
        { name: 'Traveller First Name', api: 'Contact.FirstName', highlight: true },
        { name: 'Traveller Last Name', api: 'Contact.LastName', highlight: false },
        { name: 'Traveller Email', api: 'Contact.Email', highlight: false },
        { name: 'Traveller Phone', api: 'Contact.Phone', highlight: false },
        { name: 'Passport Number', api: 'Passport_Number__c', highlight: false },
        { name: 'Date of Birth', api: 'Contact.Birthdate', highlight: false },
        { name: 'Nationality', api: 'Nationality__c', highlight: false },
        { name: 'Dietary Requirements', api: 'Dietary__c', highlight: false }
    ],
    lead: [
        { name: 'Lead Booker Name', api: 'Lead_Contact.Name', highlight: true },
        { name: 'Lead Booker Email', api: 'Lead_Contact.Email', highlight: false },
        { name: 'Lead Booker Phone', api: 'Lead_Contact.Phone', highlight: false },
        { name: 'Agency Name', api: 'Agency__c', highlight: false },
        { name: 'Commission Rate', api: 'Commission__c', highlight: false },
        { name: 'Booking Reference', api: 'Booking_Ref__c', highlight: false }
    ],
    client: [
        { name: 'Client Group Name', api: 'Client_Group__c', highlight: false },
        { name: 'Client Account Manager', api: 'Account_Manager__c', highlight: false },
        { name: 'Client Tier', api: 'Client_Tier__c', highlight: false },
        { name: 'Lifetime Value', api: 'LTV__c', highlight: false },
        { name: 'Preferred Channel', api: 'Preferred_Channel__c', highlight: false }
    ],
    supplier: [
        { name: 'Supplier Name', api: 'Supplier__c', highlight: false },
        { name: 'Supplier Country', api: 'Supplier_Country__c', highlight: false },
        { name: 'Supplier Rating', api: 'Supplier_Rating__c', highlight: false },
        { name: 'Contract Type', api: 'Contract_Type__c', highlight: false },
        { name: 'Payment Terms', api: 'Payment_Terms__c', highlight: false },
        { name: 'Cancellation Policy', api: 'Cancel_Policy__c', highlight: false },
        { name: 'Commission', api: 'Commission__c', highlight: false }
    ],
    supcontact: [
        { name: 'Supplier Contact First Name', api: 'Supplier_Contact.FirstName', highlight: true },
        { name: 'Supplier Contact Last Name', api: 'Supplier_Contact.LastName', highlight: false },
        { name: 'Supplier Contact Email', api: 'Supplier_Contact.Email', highlight: false },
        { name: 'Supplier Contact Phone', api: 'Supplier_Contact.Phone', highlight: false },
        { name: 'Supplier Contact Role', api: 'Supplier_Contact.Title', highlight: false }
    ],
    supbooking: [
        { name: 'Booking Reference', api: 'SB_Reference__c', highlight: false },
        { name: 'Check-in Date', api: 'Check_In__c', highlight: true },
        { name: 'Check-out Date', api: 'Check_Out__c', highlight: false },
        { name: 'Room Type', api: 'Room_Type__c', highlight: false },
        { name: 'Board Basis', api: 'Board_Basis__c', highlight: false },
        { name: 'Confirmation Number', api: 'Confirmation__c', highlight: false },
        { name: 'Net Rate', api: 'Net_Rate__c', highlight: false },
        { name: 'Sell Rate', api: 'Sell_Rate__c', highlight: false },
        { name: 'Supplier Notes', api: 'Supplier_Notes__c', highlight: false }
    ],
    cost: [
        { name: 'Invoice Number', api: 'Invoice_Number__c', highlight: false },
        { name: 'Invoice Date', api: 'Invoice_Date__c', highlight: false },
        { name: 'Total Amount', api: 'Total_Amount__c', highlight: false },
        { name: 'Amount Paid', api: 'Amount_Paid__c', highlight: false },
        { name: 'Outstanding Balance', api: 'Outstanding__c', highlight: true },
        { name: 'Payment Method', api: 'Payment_Method__c', highlight: false }
    ]
};

export default class SugatiCommunicationMergeFieldPicker extends LightningElement {
    @api embedded = false;

    selectedObjectId = 'opportunity';

    get objectGroups() {
        return OBJECT_GROUPS.map((obj) => ({
            ...obj,
            rowClass: obj.id === this.selectedObjectId ? 'mfp-obj on' : 'mfp-obj',
            sidebarClass: obj.id === this.selectedObjectId ? 'sb-item on' : 'sb-item'
        }));
    }

    get fields() {
        return (FIELDS_BY_OBJECT[this.selectedObjectId] || []).map((f) => ({
            ...f,
            rowClass: f.highlight ? 'mfp-f hi' : 'mfp-f',
            tokenLabel: f.name
        }));
    }

    get panelClass() {
        return this.embedded ? 'mfp-wrap embedded' : 'mfp-wrap fullpage';
    }

    handleObjectClick(event) {
        this.selectedObjectId = event.currentTarget.dataset.id;
    }

    handleFieldClick(event) {
        const label = event.currentTarget.dataset.label;
        this.dispatchEvent(
            new CustomEvent('tokeninsert', {
                detail: { label, token: `{{${label}}}` },
                bubbles: true,
                composed: true
            })
        );
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', { bubbles: true, composed: true }));
    }
}
