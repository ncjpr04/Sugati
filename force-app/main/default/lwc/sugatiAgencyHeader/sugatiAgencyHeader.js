import { LightningElement, api } from 'lwc';

/**
 * Header component for the Agency page.
 * Displays the agency name, contact details, badges and profile note
 * based on the Supplier record passed from the parent component.
 */
export default class SugatiAgencyHeader extends LightningElement {

    /** Supplier sObject passed from the parent SugatiAgencyTab component */
    @api supplier;

    /** Array of Supplier Contact records — used to derive agent count */
    @api supplierContacts = [];

    // ---- PUBLIC GETTERS ----

    /**
     * Returns the agency name from the Supplier record.
     * @returns {string} Agency name or empty string if not loaded
     */
    get agencyName() {
        return this.supplier?.Name || '';
    }

    /**
     * Returns the agency website URL from the Supplier record.
     * @returns {string} Website URL or empty string if not set
     */
    get website() {
        return this.supplier?.sugati__S_Website__c || '';
    }

    /**
     * Builds a formatted address string from city and country fields.
     * Returns city + country if both are present, otherwise whichever is available.
     * @returns {string} Formatted address or empty string if neither field is set
     */
    get address() {
        const city    = this.supplier?.sugati__S_City__c    || '';
        const country = this.supplier?.sugati__S1_Country__c || '';
        if (city && country) {
            return `${city}, ${country}`;
        }
        return city || country || '';
    }

    /**
     * Returns the profile note / description from the Supplier record.
     * @returns {string} Rich text description or empty string if not set
     */
    get profileNote() {
        return this.supplier?.sugati__S_Description__c || '';
    }

    /**
     * Returns true if a profile note exists, used to conditionally render
     * the note section in the template.
     * @returns {boolean}
     */
    get hasNote() {
        return !!this.profileNote;
    }

    /**
     * Returns the star rating value from the Supplier record.
     * @returns {number|null} Star rating number or null if not set
     */
    get starRating() {
        return this.supplier?.sugati__S_Rating__c || null;
    }

    /**
     * Returns a string of star emojis representing the supplier rating,
     * capped at 5 stars.
     * @returns {string} Star emoji string e.g. '⭐⭐⭐' or empty string if no rating
     */
    get starDisplay() {
        const starRatingNumber = parseInt(this.starRating, 10);
        if (!starRatingNumber) {
            return '';
        }
        return '⭐'.repeat(Math.min(starRatingNumber, 5));
    }

    /**
     * Returns the year the Supplier record was created,
     * used as the "Partner Since" badge value.
     * @returns {number|string} Four-digit year or empty string if CreatedDate not available
     */
    get partnerSince() {
        if (!this.supplier?.CreatedDate) {
            return '';
        }
        return new Date(this.supplier.CreatedDate).getFullYear();
    }

    /**
     * Returns the emergency phone number from the Supplier record.
     * @returns {string} Emergency phone number or empty string if not set
     */
    get emergencyPhone() {
        return this.supplier?.sugati__S_Emergency_Phone__c || '';
    }

    /**
     * Returns the agency type from the Supplier record,
     * used as the primary status badge label.
     * @returns {string} Supplier type or empty string if not set
     */
    get statusBadge() {
        return this.supplier?.sugati__S_Type__c || '';
    }

    /**
     * Derives a volume tier label based on total commission value.
     * Thresholds: > 50,000 = Top Agency, > 10,000 = High Volume, else Standard Agency.
     * @returns {string} Volume tier label
     */
    get volumeBadge() {
        const totalCommission = this.supplier?.sugati__S_Total_Commission_Value__c || 0;
        if (totalCommission > 50000) {
            return 'Top Agency';
        }
        if (totalCommission > 10000) {
            return 'High Volume';
        }
        return 'Standard Agency';
    }

    /**
     * Returns the count of Supplier Contacts passed from the parent.
     * @returns {number} Number of contacts
     */
    get agentCount() {
        return (this.supplierContacts || []).length;
    }

    /**
     * Returns a formatted agent count string with correct pluralisation.
     * @returns {string} e.g. '1 Agent' or '5 Agents'
     */
    get agentCountText() {
        return `${this.agentCount} Agent${this.agentCount === 1 ? '' : 's'}`;
    }

    /**
     * Returns true if at least one Supplier Contact exists,
     * used to conditionally render the agent count badge.
     * @returns {boolean}
     */
    get hasAgentCount() {
        return this.agentCount > 0;
    }

    /**
     * Derives up to 3 initials from the agency name for the avatar display.
     * Splits on spaces and takes the first character of each word.
     * @returns {string} Uppercase initials e.g. 'LTG' for 'Luxe Travel Group'
     */
    get agencyInitials() {
        if (!this.supplier?.Name) {
            return '';
        }
        return this.supplier.Name
            .split(' ')
            .filter(Boolean)
            .slice(0, 3)
            .map(word => word.charAt(0).toUpperCase())
            .join('');
    }

}