import { LightningElement, api } from 'lwc';

import FV_CONSULTANT_FIELD   from '@salesforce/schema/sugati__FAM_Visit__c.sugati__FV_Consultant__c';
import FV_START_DATE_FIELD   from '@salesforce/schema/sugati__FAM_Visit__c.sugati__FV_FAM_Visit_Start_Date__c';
import FV_END_DATE_FIELD     from '@salesforce/schema/sugati__FAM_Visit__c.sugati__FV_FAM_Visit_End_Date__c';
import FV_TYPE_FIELD         from '@salesforce/schema/sugati__FAM_Visit__c.sugati__FV_Type_of_FAM__c';
import FV_DESCRIPTION_FIELD  from '@salesforce/schema/sugati__FAM_Visit__c.sugati__FV_Description__c';

// Cache field API name strings once so getters do not re-evaluate them on every render.
const F_CONSULTANT  = FV_CONSULTANT_FIELD.fieldApiName;
const F_START_DATE  = FV_START_DATE_FIELD.fieldApiName;
const F_END_DATE    = FV_END_DATE_FIELD.fieldApiName;
const F_TYPE        = FV_TYPE_FIELD.fieldApiName;
const F_DESCRIPTION = FV_DESCRIPTION_FIELD.fieldApiName;

/** Number of visit cards shown before the expand toggle is activated. */
const DEFAULT_SHOW = 3;

export default class SugatiSupplierVisitFam extends LightningElement {

    /**
     * Array of FAM Visit SObject records passed in by the parent component.
     * Expected fields: FV_Consultant__c, FV_FAM_Visit_Start_Date__c,
     * FV_FAM_Visit_End_Date__c, FV_Type_of_FAM__c, FV_Description__c,
     * and the related FV_Consultant__r.Name.
     */
    @api famVisits;

    /** Salesforce record Id of the parent supplier record. */
    @api recordId;

    /** Controls whether all visit cards or only the first DEFAULT_SHOW are rendered. */
    expanded = false;

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Formats a from/to date pair into a human-readable range string.
     * Returns a fallback when neither date is supplied.
     * @param  {String|null} fromDateString - ISO date string for the start date.
     * @param  {String|null} toDateString   - ISO date string for the end date.
     * @return {String} Formatted range, e.g. '📅 1 Jan 2025 – 7 Jan 2025'.
     */
    _fmtDateRange(fromDateString, toDateString) {
        const opts = { day: 'numeric', month: 'short', year: 'numeric' };
        const formattedFrom = fromDateString
            ? new Date(fromDateString).toLocaleDateString('en-GB', opts)
            : '';
        const formattedTo = toDateString
            ? new Date(toDateString).toLocaleDateString('en-GB', opts)
            : '';

        if (formattedFrom && formattedTo) {
            return `📅 ${formattedFrom} – ${formattedTo}`;
        }
        return formattedFrom ? `📅 ${formattedFrom}` : '📅 Date unknown';
    }

    // ── Computed properties ───────────────────────────────────────────────

    /**
     * Maps raw FAM Visit records into display-ready row objects,
     * slicing to DEFAULT_SHOW unless the expanded flag is set.
     * Rich text descriptions are left as-is for lightning-formatted-rich-text.
     * @return {Array} Array of plain display objects consumed by the template.
     */
    get visitRows() {
        const rows = (this.famVisits || []).map(visit => ({
            id          : visit.Id,
            consultant  : visit.sugati__FV_Consultant__r?.Name || 'N/A',
            dateRange   : this._fmtDateRange(visit[F_START_DATE], visit[F_END_DATE]),
            type        : visit[F_TYPE]        || '',
            description : visit[F_DESCRIPTION] || ''
        }));

        return this.expanded ? rows : rows.slice(0, DEFAULT_SHOW);
    }

    /**
     * Returns true when there is at least one FAM visit to display.
     * Used by the template to toggle between the visit list and the empty state.
     * @return {Boolean}
     */
    get hasVisits() {
        return (this.famVisits || []).length > 0;
    }

    /**
     * Returns true when the total number of visits exceeds the default show limit,
     * indicating that an expand toggle should be rendered.
     * @return {Boolean}
     */
    get hasMore() {
        return (this.famVisits || []).length > DEFAULT_SHOW;
    }

    /**
     * Returns the label for the expand/collapse toggle button,
     * reflecting the current expanded/collapsed state.
     * @return {String}
     */
    get expandLabel() {
        return this.expanded
            ? 'Show less ↑'
            : `See all ${(this.famVisits || []).length} visits ↓`;
    }

    // ── Event handlers ────────────────────────────────────────────────────

    /**
     * Toggles the expanded flag to show or hide the full list of visit cards.
     */
    toggleExpand() {
        this.expanded = !this.expanded;
    }
    
}