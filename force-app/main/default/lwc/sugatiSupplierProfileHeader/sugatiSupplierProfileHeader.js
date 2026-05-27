import { LightningElement, api } from 'lwc';

/**
 * Profile Header component for the Supplier page.
 * Displays the supplier name, avatar initials, contact details,
 * type badge, star rating, links and supplier note.
 * All data is derived from the Supplier record passed from the parent.
 */
export default class SugatiSupplierProfileHeader extends LightningElement {

    /** Supplier sObject passed from the parent SugatiSupplierPage component */
    @api supplier;

    // ---- PUBLIC GETTERS ----

    /**
     * Derives up to 3 uppercase initials from the supplier name
     * for display in the square avatar element.
     * @returns {string} Uppercase initials e.g. 'GMA' for 'Giraffe Manor Africa'
     */
    get initials() {
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

    /**
     * Returns the supplier name.
     * @returns {string} Supplier name or empty string if not set
     */
    get supplierName() {
        return this.supplier?.Name || '';
    }

    /**
     * Returns the supplier type from the Type field.
     * @returns {string} Supplier type or empty string if not set
     */
    get supplierType() {
        return this.supplier?.sugati__S_Type__c || '';
    }

    /**
     * Builds a formatted address string from city and country fields.
     * @returns {string} 'City, Country', 'City', 'Country' or empty string
     */
    get address() {
        const city    = this.supplier?.sugati__S_City__c     || '';
        const country = this.supplier?.sugati__S1_Country__c || '';
        if (city && country) {
            return `${city}, ${country}`;
        }
        return city || country || '';
    }

    /**
     * Returns the supplier website URL.
     * @returns {string} Website URL or empty string if not set
     */
    get website() {
        return this.supplier?.sugati__S_Website__c || '';
    }

    /**
     * Returns the star rating value.
     * @returns {number|null} Star rating or null if not set
     */
    get starRating() {
        return this.supplier?.sugati__S_Rating__c || null;
    }

    /**
     * Returns the emergency phone number.
     * @returns {string} Emergency phone number or empty string if not set
     */
    get emergencyPhone() {
        return this.supplier?.sugati__S_Emergency_Phone__c || '';
    }

    /**
     * Returns the supplier confirmation link URL.
     * @returns {string} Confirmation link URL or empty string if not set
     */
    get confirmationLink() {
        return this.supplier?.sugati__S_Supplier_Confirmation_Link__c || '';
    }

    /**
     * Returns the booking link URL.
     * @returns {string} Booking link URL or empty string if not set
     */
    get bookingLink() {
        return this.supplier?.sugati__S_Booking_Link__c || '';
    }

    /**
     * Returns the supplier description / note.
     * @returns {string} Rich text description or empty string if not set
     */
    get supplierNote() {
        return this.supplier?.sugati__S_Description__c || '';
    }

    /**
     * Returns true if a supplier note exists.
     * Used to conditionally render the note section.
     * @returns {boolean}
     */
    get hasNote() {
        return !!this.supplierNote;
    }

    /**
     * Returns a fully qualified website URL with protocol prefix.
     * Ensures the href is valid for external navigation.
     * @returns {string} URL with https:// prefix, or '#' if website is empty
     */
    get websiteUrl() {
        const websiteValue = this.website;
        if (!websiteValue) {
            return '#';
        }
        return websiteValue.startsWith('http') ? websiteValue : `https://${websiteValue}`;
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
     * used as the 'Partner since' badge value.
     * @returns {number|string} Four-digit year or empty string if not available
     */
    get partnerSince() {
        if (!this.supplier?.CreatedDate) {
            return '';
        }
        return new Date(this.supplier.CreatedDate).getFullYear();
    }
}