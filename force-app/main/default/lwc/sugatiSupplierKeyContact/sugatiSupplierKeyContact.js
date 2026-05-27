import { LightningElement, api } from 'lwc';

const AVATAR_COLORS = [
    'linear-gradient(135deg,#FFC543,#FFF49D)',
    'linear-gradient(135deg,#7ab8e0,#4a8fb0)',
    'linear-gradient(135deg,#4caf82,#2a7a54)',
    'linear-gradient(135deg,#e0a87a,#b07040)',
    'linear-gradient(135deg,#9b8de0,#6a5cb0)',
    'linear-gradient(135deg,#e07a8a,#b04050)'
];

export default class SugatiSupplierKeyContact extends LightningElement {

    @api supplierContacts = [];

    get contactRows() {
        return (this.supplierContacts || []).map((c, idx) => {
            const first = c.sugati__SC_First_Name__c || '';
            const last  = c.sugati__SC_Last_Name__c  || '';
            const initials = `${first.charAt(0)}${last.charAt(0)}`.toUpperCase() || '?';
            const salutation = c.sugati__SC_Salutation__c ? `${c.sugati__SC_Salutation__c} ` : '';
            return {
                id: c.Id,
                initials,
                fullName: `${salutation}${first} ${last}`.trim() || 'Unknown',
                title: c.sugati__SC_Title__c || '',
                phone: c.sugati__SC_Phone__c || '',
                email: c.sugati__SC_Email__c || '',
                language: c.sugati__SC_Language__c || '',
                avatarStyle: `background:${AVATAR_COLORS[idx % AVATAR_COLORS.length]};color:#1C1C1A`
            };
        });
    }

    get hasContacts() {
        return this.contactRows.length > 0;
    }
}