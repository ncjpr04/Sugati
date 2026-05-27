import { LightningElement, api } from 'lwc';

/** Number of FAM visit cards shown before the expand toggle appears */
const DEFAULT_VISIBLE_COUNT = 3;

/**
 * FAM Trips component for the Agency page.
 * Displays a grid of Familiarisation visit cards for the current Supplier,
 * with an expand/collapse toggle when there are more than DEFAULT_VISIBLE_COUNT visits.
 * Data is passed in from the parent SugatiAgencyTab component.
 */
export default class SugatiAgencyFamTrips extends LightningElement {

    /** FAM Visit records for this Supplier, passed from parent */
    @api famVisits = [];

    /** Whether all visits are shown or only the first DEFAULT_VISIBLE_COUNT */
    expanded = false;

    // ---- PUBLIC GETTERS ----

    /**
     * Maps FAM Visit sObjects into display-ready row objects for the template.
     * Returns either all rows or the first DEFAULT_VISIBLE_COUNT depending
     * on the expanded state.
     * @returns {Array} Array of visit display objects
     */
    get visitRows() {
        const visitDisplayRows = (this.famVisits || []).map(famVisit => ({
            id:          famVisit.Id,
            consultant:  famVisit.sugati__FV_Consultant__r?.Name || 'N/A',
            role:        'Sugati Staff',
            dateRange:   this.formatDateRange(
                             famVisit.sugati__FV_FAM_Visit_Start_Date__c,
                             famVisit.sugati__FV_FAM_Visit_End_Date__c
                         ),
            type:        famVisit.sugati__FV_Type_of_FAM__c || '',
            description: this.stripHtml(famVisit.sugati__FV_Description__c || '')
        }));

        return this.expanded
            ? visitDisplayRows
            : visitDisplayRows.slice(0, DEFAULT_VISIBLE_COUNT);
    }

    /**
     * Returns true if there are any FAM visits to display.
     * Used to toggle between the grid and the empty state.
     * @returns {boolean}
     */
    get hasTrips() {
        return (this.famVisits || []).length > 0;
    }

    /**
     * Returns true if there are more visits than the default visible count.
     * Used to conditionally render the expand/collapse toggle.
     * @returns {boolean}
     */
    get hasMore() {
        return (this.famVisits || []).length > DEFAULT_VISIBLE_COUNT;
    }

    /**
     * Returns the label for the expand/collapse toggle button.
     * @returns {string} 'Show less ↑' or 'See all N visits ↓'
     */
    get expandLabel() {
        return this.expanded
            ? 'Show less ↑'
            : `See all ${(this.famVisits || []).length} visits ↓`;
    }

    // ---- EVENT HANDLERS ----

    /**
     * Toggles the expanded state to show or hide all FAM visits.
     */
    toggleExpand() {
        this.expanded = !this.expanded;
    }

    // ---- PRIVATE METHODS ----

    /**
     * Strips HTML tags and decodes common HTML entities from a string.
     * Used to sanitise the FAM Visit description field for plain text display.
     * @param {string} htmlString - Raw HTML string to sanitise
     * @returns {string} Plain text string with tags and entities removed
     */
    stripHtml(htmlString) {
        if (!htmlString) {
            return '';
        }
        return htmlString
            .replace(/<[^>]*>/g, ' ')
            .replace(/&nbsp;/g, ' ')
            .replace(/&amp;/g, '&')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/\s+/g, ' ')
            .trim();
    }

    /**
     * Formats a start and end date into a human-readable date range string.
     * If only a start date is provided, returns just that date.
     * If neither date is provided, returns an empty string.
     * @param {string} fromDate - ISO date string for the visit start date
     * @param {string} toDate   - ISO date string for the visit end date
     * @returns {string} Formatted date range e.g. '12 Sep 2024 – 14 Sep 2024'
     */
    formatDateRange(fromDate, toDate) {
        const dateFormatOptions  = { day: 'numeric', month: 'short', year: 'numeric' };
        const formattedFrom = fromDate
            ? new Date(fromDate).toLocaleDateString('en-GB', dateFormatOptions)
            : '';
        const formattedTo   = toDate
            ? new Date(toDate).toLocaleDateString('en-GB', dateFormatOptions)
            : '';

        if (formattedFrom && formattedTo) {
            return `${formattedFrom} – ${formattedTo}`;
        }
        return formattedFrom ? formattedFrom : '';
    }
}