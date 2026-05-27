import { LightningElement, api } from 'lwc';

/** Number of trip rows shown before the expand toggle is activated. */
const PREVIEW_COUNT = 5;

/** Placeholder displayed when a value cannot be determined. */
const EMPTY_VALUE = '—';

export default class SugatiTravellerBookingHistory extends LightningElement {

    /**
     * List of Opportunity records representing the traveller's booking history.
     * Expected fields: sugati__O_Booking_Date__c, sugati__O_Status__c,
     * sugati__O_Country__c, sugati__O_No_of_Nights__c, Amount, Name, Id.
     */
    @api opportunities;

    /**
     * Currency symbol prepended to formatted monetary values.
     * Provided by the parent component based on the account's CurrencyIsoCode.
     */
    @api currencySymbol;

    /** Controls whether all rows or only the first PREVIEW_COUNT are shown. */
    _expanded = false;

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Formats a date value as a short month and year string, e.g. 'Jan 2025'.
     * Returns '—' when no date is supplied.
     * @param  {String|null} dateValue - ISO date string to format.
     * @return {String} Formatted month/year string, or '—'.
     */
    fmtMonthYear(dateValue) {
        if (!dateValue) {
            return EMPTY_VALUE;
        }
        return new Date(dateValue).toLocaleDateString('en-GB', {
            month : 'short',
            year  : 'numeric'
        });
    }

    /**
     * Derives the appropriate badge CSS class for a given opportunity status value.
     * Statuses are grouped into colour bands: green (completed), blue (active),
     * amber (limited/pending), red (unavailable), neutral (unknown).
     * @param  {String|null} statusValue - The raw sugati__O_Status__c value.
     * @return {String} CSS class string, e.g. 'badge badge-green'.
     */
    statusClass(statusValue) {
        if (!statusValue) {
            return 'badge badge-neutral';
        }
        const normalisedStatus = statusValue.toLowerCase().trim();

        if (['complete', 'departed', 'guaranteed'].includes(normalisedStatus)) {
            return 'badge badge-green';
        }
        if (['build', 'built', 'on sale'].includes(normalisedStatus)) {
            return 'badge badge-blue';
        }
        if (['waiting list', 'on request'].includes(normalisedStatus)) {
            return 'badge badge-sunset';
        }
        if (['sold out', 'suspended', 'cancelled'].includes(normalisedStatus)) {
            return 'badge badge-red';
        }
        return 'badge badge-neutral';
    }

    // ── Computed properties ───────────────────────────────────────────────

    /**
     * Filters opportunities to those with a booking date and maps each to a
     * display-ready object with formatted date, amount and status badge class.
     * @return {Array} Array of enriched Opportunity display objects.
     */
    get bookedTrips() {
        const symbol = this.currencySymbol || '£';
        return (this.opportunities || [])
            .filter(opportunity => opportunity.sugati__O_Booking_Date__c)
            .map(opportunity => {
                const parsedAmount = parseFloat(opportunity.Amount);
                return {
                    ...opportunity,
                    bookingDateFormatted: this.fmtMonthYear(opportunity.sugati__O_Booking_Date__c),
                    amountFormatted: !isNaN(parsedAmount)
                        ? `${symbol}${Math.round(parsedAmount).toLocaleString('en-GB')}`
                        : EMPTY_VALUE,
                    statusClass: this.statusClass(opportunity.sugati__O_Status__c)
                };
            });
    }

    /**
     * Returns the subset of booked trips visible in the table,
     * respecting the expanded toggle.
     * @return {Array}
     */
    get visibleTrips() {
        return this._expanded
            ? this.bookedTrips
            : this.bookedTrips.slice(0, PREVIEW_COUNT);
    }

    /**
     * Returns true when the total number of booked trips exceeds the preview limit.
     * @return {Boolean}
     */
    get hasMore() {
        return this.bookedTrips.length > PREVIEW_COUNT;
    }

    /**
     * Returns the label for the expand/collapse toggle link.
     * @return {String}
     */
    get toggleLabel() {
        return this._expanded
            ? 'View less ↑'
            : `View all ${this.bookedTrips.length} trips →`;
    }

    /**
     * Returns the CSS class string for the table wrapper, adding the
     * 'expanded' modifier when all rows are shown.
     * @return {String}
     */
    get tableWrapClass() {
        return this._expanded ? 'table-wrap expanded' : 'table-wrap';
    }

    /**
     * Returns a summary string showing the total trip count and combined
     * value across all booked trips, e.g. '5 trips · £12,400 total'.
     * @return {String}
     */
    get tripSummary() {
        const symbol      = this.currencySymbol || '£';
        const tripCount   = this.bookedTrips.length;
        const totalAmount = this.bookedTrips.reduce((sum, trip) => {
            const value = parseFloat(trip.Amount);
            return sum + (isNaN(value) ? 0 : value);
        }, 0);
        const pluralSuffix = tripCount !== 1 ? 's' : '';
        return `${tripCount} trip${pluralSuffix} · ${symbol}${Math.round(totalAmount).toLocaleString('en-GB')} total`;
    }


    // ── Event handlers ────────────────────────────────────────────────────

    /**
     * Toggles the expanded flag to show or hide the full list of booked trips.
     */
    toggle() {
        this._expanded = !this._expanded;
    }
}