import { LightningElement, api, wire, track } from 'lwc';
import getAccount from '@salesforce/apex/SugatiAccountPageCtrl.getAccount';
import getOpportunities from '@salesforce/apex/SugatiAccountPageCtrl.getOpportunities';

export default class SugatiAccountPage extends LightningElement {
    @api recordId;
    @track account;
    @track opportunities = [];
    @track activeTab = 'b2c'; // default

    @wire(getAccount, { accountId: '$recordId' })
    wiredAccount({ data }) { if (data) this.account = data; 
        console.log('Account data:', JSON.stringify(data));

    }

    @wire(getOpportunities, { accountId: '$recordId' })
    wiredOpps({ data }) { if (data) this.opportunities = data; }

    handleTabChange(event) { this.activeTab = event.detail; }

    get isB2C()      { return this.activeTab === 'b2c'; }
    get isB2B()      { return this.activeTab === 'b2b'; }
    get isSupplier() { return this.activeTab === 'supplier'; }
}