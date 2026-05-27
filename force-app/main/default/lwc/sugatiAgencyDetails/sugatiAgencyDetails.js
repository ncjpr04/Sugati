import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

/**
 * Maps lowercase consortium names to their corresponding CSS class string.
 * All keys must be lowercase as getCssClass lowercases the input before lookup.
 * Add new entries here when new consortium values are added to the picklist.
 */
const CONSORTIUM_CSS_CLASS_MAP = {
    'virtuoso':       'assoc-logo virtuoso',
    'traveller made': 'assoc-logo tmade',
    'travellermade':  'assoc-logo tmade',
    'ensemble':       'assoc-logo ensemble',
    'signature':      'assoc-logo signature',
    'travel leaders': 'assoc-logo tleaders'
};

/**
 * Returns the CSS class string for a given consortium name.
 * Performs a case-insensitive lookup against CONSORTIUM_CSS_CLASS_MAP.
 * Falls back to a default grey style if the name is not in the map.
 * @param {string} consortiumName - The consortium name to look up
 * @returns {string} CSS class string for the logo element
 */
function getCssClass(consortiumName) {
    return CONSORTIUM_CSS_CLASS_MAP[consortiumName?.toLowerCase()]
        || 'assoc-logo assoc-default';
}

/**
 * Derives up to 2 uppercase initials from a consortium name.
 * Splits on spaces and takes the first character of each word.
 * @param {string} consortiumName - The consortium name to derive initials from
 * @returns {string} Uppercase initials e.g. 'TM' for 'Traveller Made', or '?' if empty
 */
function getInitials(consortiumName) {
    if (!consortiumName) {
        return '?';
    }
    return consortiumName.trim()
        .split(' ')
        .filter(Boolean)
        .slice(0, 2)
        .map(word => word.charAt(0).toUpperCase())
        .join('');
}

/**
 * Agency Details component for the Agency page.
 * Displays key agency information fields and travel association badges
 * derived from the Supplier record passed from the parent component.
 */
export default class SugatiAgencyDetails extends NavigationMixin(LightningElement) {

    /** Supplier sObject passed from the parent SugatiAgencyTab component */
    @api supplier;

    // ---- PUBLIC GETTERS ----

    /**
     * Returns the agency type from the Supplier record.
     * @returns {string} Supplier type or 'N/A' if not set
     */
    get agencyType() {
        return this.supplier?.sugati__S_Type__c || 'N/A';
    }

    /**
     * Builds a formatted head office address from street, city and postcode.
     * @returns {string} Comma-separated address or 'Not Specified' if no fields are set
     */
    get headOffice() {
        const addressParts = [
            this.supplier?.sugati__S_Street__c,
            this.supplier?.sugati__S_City__c,
            this.supplier?.sugati__S_Postcode__c
        ].filter(Boolean);
        return addressParts.join(', ') || 'Not Specified';
    }

    /**
     * Returns the formatted date the Supplier record was created,
     * used as the Partnership Since display value.
     * @returns {string} Formatted date e.g. 'March 2019' or 'N/A' if not available
     */
    get partnershipSince() {
        const createdDate = this.supplier?.CreatedDate;
        return createdDate
            ? new Date(createdDate).toLocaleDateString('en-GB', {
                month: 'long',
                year:  'numeric'
              })
            : 'N/A';
    }

    /**
     * Returns the commission rate from the Supplier record as a percentage string.
     * @returns {string} Commission percentage e.g. '10%' or 'Not Specified' if not set
     */
    get commissionRate() {
        const commissionValue = this.supplier?.sugati__S_Commission__c;
        return commissionValue != null ? `${commissionValue}%` : 'Not Specified';
    }

    /**
     * Parses the Marketing Consortium field (single picklist or
     * semicolon-separated multi-select) into an array of display objects
     * for the travel associations badge grid.
     * @returns {Array} Array of consortium descriptor objects with key, initials, cssClass and name
     */
    get travelAssociations() {
        const rawConsortiumValue = this.supplier?.sugati__S_Marketing_Consortium__c;
        if (!rawConsortiumValue) {
            return [];
        }
        return rawConsortiumValue
            .split(';')
            .map(consortiumName => consortiumName.trim())
            .filter(Boolean)
            .map((consortiumName, index) => ({
                key:      `${consortiumName}-${index}`,
                initials: getInitials(consortiumName),
                cssClass: getCssClass(consortiumName),
                name:     consortiumName
            }));
    }

    /**
     * Returns true if at least one travel association exists,
     * used to conditionally render the associations section.
     * @returns {boolean}
     */
    get hasTravelAssociations() {
        return this.travelAssociations.length > 0;
    }

    // ---- EVENT HANDLERS ----

    /**
     * Handles the Edit button click.
     * Navigates to the standard Salesforce record edit page for this Supplier.
     */
    handleEditOptions() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId:   this.supplier?.Id,
                actionName: 'edit'
            }
        });
    }
}