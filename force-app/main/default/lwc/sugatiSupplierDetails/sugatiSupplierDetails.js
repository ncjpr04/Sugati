import { LightningElement, api } from 'lwc';

/**
 * Supplier Details component for the Supplier page.
 * Displays key supplier information fields in a two-column grid.
 * All data is derived from the Supplier record passed from the parent.
 */
export default class SugatiSupplierDetails extends LightningElement {

    /** Supplier sObject passed from the parent SugatiSupplierPage component */
    @api supplier;

    // ---- PUBLIC GETTERS ----

    /**
     * Returns the supplier type from the Type field.
     * @returns {string} Supplier type or 'N/A' if not set
     */
    get supplierType() {
        return this.supplier?.sugati__S_Type__c || 'N/A';
    }

    /**
     * Returns the name of the parent supplier (chain or group).
     * @returns {string} Parent supplier name or 'N/A' if not set
     */
    get chainGroup() {
        return this.supplier?.sugati__S_Parent_Supplier__r?.Name || 'N/A';
    }

    /**
     * Builds a formatted address from city and country fields.
     * @returns {string} 'City, Country', 'City', 'Country' or 'N/A' if neither is set
     */
    get address() {
        if (!this.supplier) {
            return 'N/A';
        }
        const addressParts = [
            this.supplier.sugati__S_City__c,
            this.supplier.sugati__S1_Country__c
        ].filter(Boolean);
        return addressParts.length ? addressParts.join(', ') : 'N/A';
    }

    /**
     * Returns the formatted date the Supplier record was created,
     * used as the Partnership Since display value.
     * @returns {string} Formatted date e.g. 'March 2019' or 'N/A' if not available
     */
    get partnerSince() {
        const createdDate = this.supplier?.CreatedDate;
        if (!createdDate) {
            return 'N/A';
        }
        return new Date(createdDate).toLocaleDateString('en-GB', {
            month: 'long',
            year:  'numeric'
        });
    }

    /**
     * Returns the commission rate as a formatted percentage string.
     * @returns {string} Commission string e.g. '10% on net value' or 'N/A' if not set
     */
    get commissionRate() {
        const commissionValue = this.supplier?.sugati__S_Commission__c;
        if (commissionValue == null || commissionValue === '') {
            return 'N/A';
        }
        return `${commissionValue}% on net value`;
    }
}