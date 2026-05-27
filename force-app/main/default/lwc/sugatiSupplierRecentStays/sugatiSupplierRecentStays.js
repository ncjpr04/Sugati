import { LightningElement, api } from 'lwc';

import SB_FROM_DATE_FIELD         from '@salesforce/schema/sugati__Supplier_Booking__c.sugati__SB_From_Date__c';
import SB_TO_DATE_FIELD           from '@salesforce/schema/sugati__Supplier_Booking__c.sugati__SB_To_Date__c';
import SB_NIGHT_FIELD             from '@salesforce/schema/sugati__Supplier_Booking__c.sugati__SB_Night__c';
import SB_PAX_COSTING_FIELD       from '@salesforce/schema/sugati__Supplier_Booking__c.sugati__SB_Pax_for_Costing__c';
import SB_ROOM_TYPE_FIELD         from '@salesforce/schema/sugati__Supplier_Booking__c.sugati__SB_Room_Type__c';
import SB_TOTAL_GROSS_COST_FIELD  from '@salesforce/schema/sugati__Supplier_Booking__c.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c';

// Cache field API name strings once so getters do not re-evaluate them on every render.
const F_FROM_DATE        = SB_FROM_DATE_FIELD.fieldApiName;
const F_TO_DATE          = SB_TO_DATE_FIELD.fieldApiName;
const F_NIGHT            = SB_NIGHT_FIELD.fieldApiName;
const F_PAX_COSTING      = SB_PAX_COSTING_FIELD.fieldApiName;
const F_ROOM_TYPE        = SB_ROOM_TYPE_FIELD.fieldApiName;
const F_TOTAL_GROSS_COST = SB_TOTAL_GROSS_COST_FIELD.fieldApiName;

/** Number of rows shown before the "View all" toggle is activated. */
const DEFAULT_ROWS = 5;

export default class SugatiSupplierRecentStays extends LightningElement {

    /**
     * Array of Supplier Booking SObject records passed in by the parent component.
     * Expected fields: SB_From_Date__c, SB_To_Date__c, SB_Night__c,
     * SB_Pax_for_Costing__c, SB_Room_Type__c, S_SB_Total_Gross_Cost_Booking_Currency__c,
     * and the related SB_Opportunity__r.Account.Name / SB_Opportunity__r.Name.
     */
    @api supplierBookings;

    /**
     * Currency symbol prepended to formatted monetary values.
     * Defaults to '£' when not provided by the parent.
     */
    @api currencySymbol;

    /** Controls whether all rows or only the first DEFAULT_ROWS are shown. */
    showAll = false;

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Formats a monetary value as a localised string prefixed with the currency symbol.
     * Returns 'N/A' when the value is null or undefined.
     * @param  {Number|null} value - Raw numeric cost value.
     * @return {String} Formatted currency string, e.g. '£1,234'.
     */
    _fmtCurrency(value) {
        const symbol = this.currencySymbol || '£';
        if (value == null) {
            return 'N/A';
        }
        return `${symbol}${Number(value).toLocaleString('en-GB', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }

    /**
     * Formats a from/to date pair into a human-readable range string.
     * Returns 'N/A' when neither date is supplied.
     * @param  {String|null} fromDateString - ISO date string for the start date.
     * @param  {String|null} toDateString   - ISO date string for the end date.
     * @return {String} Formatted range, e.g. '1 Jan 2025 – 7 Jan 2025'.
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
            return `${formattedFrom} – ${formattedTo}`;
        }
        return formattedFrom || formattedTo || 'N/A';
    }

    /**
     * Escapes a single value for safe inclusion in a CSV cell.
     * Wraps the value in double-quotes and escapes any internal double-quotes.
     * @param  {*} value - The raw cell value to escape.
     * @return {String} CSV-safe quoted string.
     */
    _csvEsc(value) {
        if (value == null) {
            return '';
        }
        return `"${String(value).replace(/"/g, '""')}"`;
    }

    // ── Computed properties ───────────────────────────────────────────────

    /**
     * Filters supplier bookings to the current calendar year and maps each
     * record to a display-ready row object. Rows are sorted with upcoming
     * stays first, then by date descending within each group.
     * @return {Array} Sorted array of display row objects for the current year.
     */
    get currentYearRows() {
        const currentYear = new Date().getFullYear();
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const rows = (this.supplierBookings || [])
            .filter(booking => {
                const fromDate = booking[F_FROM_DATE];
                return fromDate && new Date(fromDate).getFullYear() === currentYear;
            })
            .map(booking => {
                const fromDate   = new Date(booking[F_FROM_DATE]);
                const isUpcoming = fromDate >= today;
                const nights     = booking[F_NIGHT] || 0;
                const pax        = booking[F_PAX_COSTING] || 1;

                return {
                    id          : booking.Id,
                    guestName   : booking.sugati__SB_Opportunity__r?.Account?.Name || 'N/A',
                    opptyName   : booking.sugati__SB_Opportunity__r?.Name || '',
                    agency      : 'N/A', // Agency field not in current Apex; extend when available
                    roomType    : booking[F_ROOM_TYPE] || 'N/A',
                    dateRange   : this._fmtDateRange(booking[F_FROM_DATE], booking[F_TO_DATE]),
                    nights      : nights * pax,
                    displayNights: nights,
                    value       : this._fmtCurrency(booking[F_TOTAL_GROSS_COST]),
                    status      : isUpcoming ? 'Upcoming' : 'Completed',
                    statusClass : isUpcoming ? 'status-badge badge-blue' : 'status-badge badge-green',
                    isUpcoming,
                    _sortKey    : isUpcoming ? 0 : 1,
                    _fromDate   : fromDate
                };
            });

        // Upcoming stays first, then descending by date within each group.
        rows.sort((rowA, rowB) => {
            if (rowA._sortKey !== rowB._sortKey) {
                return rowA._sortKey - rowB._sortKey;
            }
            return rowB._fromDate - rowA._fromDate;
        });

        return rows;
    }

    /**
     * Returns the subset of current-year rows visible in the table,
     * respecting the showAll toggle.
     * @return {Array} Sliced or full array of row objects.
     */
    get displayedRows() {
        return this.showAll
            ? this.currentYearRows
            : this.currentYearRows.slice(0, DEFAULT_ROWS);
    }

    /**
     * Returns true when there is at least one current-year stay to display.
     * Used by the template to toggle between the table and the empty state.
     * @return {Boolean}
     */
    get hasStays() {
        return this.currentYearRows.length > 0;
    }

    /**
     * Returns true when the total number of stays exceeds the default row limit,
     * indicating that a "View all" toggle should be shown.
     * @return {Boolean}
     */
    get hasMore() {
        return this.currentYearRows.length > DEFAULT_ROWS;
    }

    /**
     * Returns the label for the view-all toggle link,
     * reflecting the current expanded/collapsed state.
     * @return {String}
     */
    get viewAllLabel() {
        return this.showAll
            ? 'Show less ↑'
            : `View all ${this.currentYearRows.length} stays →`;
    }

    /**
     * Returns the CSS class string for the table wrapper element,
     * adding the 'expanded' modifier when all rows are shown.
     * @return {String}
     */
    get tableWrapClass() {
        return this.showAll ? 'table-wrap expanded' : 'table-wrap';
    }

    /**
     * Returns the number of unique opportunities represented in the current-year stays.
     * Used in the card header summary.
     * @return {Number}
     */
    get uniqueOpptyCount() {
        const opptyNames = new Set(this.currentYearRows.map(row => row.opptyName));
        return opptyNames.size;
    }

    /**
     * Returns the total nights (nights × pax) across all current-year stays,
     * formatted as a localised string.
     * @return {String} Localised number string, e.g. '1,234'.
     */
    get totalNights() {
        return this.currentYearRows
            .reduce((sum, row) => sum + (row.nights || 0), 0)
            .toLocaleString('en-GB');
    }

    // ── Event handlers ────────────────────────────────────────────────────

    /**
     * Toggles the showAll flag to expand or collapse the stays table.
     */
    toggleViewAll() {
        this.showAll = !this.showAll;
    }

    /**
     * Builds a CSV string from the current-year rows and triggers a file download.
     * Uses a data URI to remain compatible with LWC's Content Security Policy.
     */
    handleExport() {
        const rows = this.currentYearRows;

        if (!rows.length) {
            return;
        }

        const headers = [
            'Guest/Client', 'Opportunity', 'Agency',
            'Room Type', 'Dates', 'Nights', 'Value', 'Status'
        ];

        const csvRows = [
            headers.join(','),
            ...rows.map(row => [
                this._csvEsc(row.guestName),
                this._csvEsc(row.opptyName),
                this._csvEsc(row.agency),
                this._csvEsc(row.roomType),
                this._csvEsc(row.dateRange),
                row.nights,
                this._csvEsc(row.value),
                row.status
            ].join(','))
        ];

        const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvRows.join('\n'));
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', `supplier-stays-${new Date().getFullYear()}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }
}