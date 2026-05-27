import { LightningElement, api } from 'lwc';

/**
 * Stat Strip component for the Agency page.
 * Displays five KPI cards: Revenue, Bed Nights, Bookings,
 * Average Booking Value and Lifetime Revenue.
 * All metrics are derived from the supplierBookings array
 * passed in from the parent SugatiAgencyTab component.
 */
export default class SugatiAgencyStatStrip extends LightningElement {

    /** Supplier sObject — used for lifetime subtext via CreatedDate */
    @api supplier;

    /** All Supplier Booking records for this Supplier, passed from parent */
    @api supplierBookings = [];

    /** Currency symbol derived from the first booking's CurrencyIsoCode */
    @api currencySymbol = '£';

    currentYear = new Date().getFullYear();

    @api lifetimeStats = null;

    // ---- PRIVATE METHODS ----

    /**
     * Filters supplier bookings to those whose related Opportunity
     * has a booking date falling within the specified calendar year.
     * Only bookings where the Opportunity lookup is populated and
     * the booking date is not empty are included.
     * @param {number} year - The calendar year to filter by
     * @returns {Array} Filtered array of Supplier Booking records
     */
    bookingsForYear(year) {
        return (this.supplierBookings || []).filter(supplierBooking => {
            const bookingDate = supplierBooking.sugati__SB_Opportunity__r
                ?.sugati__O_Booking_Date__c;
            return supplierBooking.sugati__SB_Opportunity__c
                && bookingDate
                && new Date(bookingDate).getFullYear() === year;
        });
    }

    /**
     * Returns the count of unique Opportunity Ids within a given
     * array of Supplier Bookings. Each Opportunity is only counted once
     * regardless of how many Supplier Bookings are linked to it.
     * @param {Array} bookings - Array of Supplier Booking records to count
     * @returns {number} Count of unique Opportunities
     */
    uniqueBookings(bookings) {
        const uniqueOppIds = new Set();
        bookings.forEach(supplierBooking => {
            const bookingDate = supplierBooking.sugati__SB_Opportunity__r
                ?.sugati__O_Booking_Date__c;
            if (bookingDate && supplierBooking.sugati__SB_Opportunity__c) {
                uniqueOppIds.add(supplierBooking.sugati__SB_Opportunity__c);
            }
        });
        return uniqueOppIds.size;
    }

    /**
     * Formats a numeric value into a human-readable string
     * with B/M/K suffix where appropriate. No currency symbol is prepended —
     * the symbol is applied in the template via {currencySymbol}.
     * @param {number} numericValue - The raw numeric value to format
     * @returns {string} Formatted string e.g. '284K', '1.2M', '750'
     */
    formatValue(numericValue) {
        if (!numericValue && numericValue !== 0) {
            return '0';
        }
        if (numericValue >= 1_000_000_000) {
            return (numericValue / 1_000_000_000).toFixed(1).replace(/\.0$/, '') + 'B';
        }
        if (numericValue >= 1_000_000) {
            return (numericValue / 1_000_000).toFixed(1).replace(/\.0$/, '') + 'M';
        }
        if (numericValue >= 1_000) {
            return (numericValue / 1_000).toFixed(1).replace(/\.0$/, '') + 'K';
        }
        return Math.round(numericValue).toString();
    }

    // ---- REVENUE GETTERS ----

    /**
     * Returns the raw total revenue for the current year.
     * Sums the gross cost field across all filtered bookings.
     * @returns {number} Total revenue as a raw numeric value
     */
    get revenueThisYearRaw() {
        return this.bookingsForYear(this.currentYear)
            .reduce((accumulator, supplierBooking) =>
                accumulator + (supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c || 0),
            0);
    }

    /**
     * Returns the raw total revenue for the previous year.
     * @returns {number} Prior year total revenue as a raw numeric value
     */
    get revenueLastYearRaw() {
        return this.bookingsForYear(this.currentYear - 1)
            .reduce((accumulator, supplierBooking) =>
                accumulator + (supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c || 0),
            0);
    }

    /**
     * Returns the formatted revenue for the current year.
     * @returns {string} Formatted revenue string e.g. '284K'
     */
    get revenueThisYear() {
        return this.formatValue(this.revenueThisYearRaw);
    }

    /**
     * Returns true if prior year revenue data exists,
     * used to conditionally render the revenue delta indicator.
     * @returns {boolean}
     */
    get showRevenueDelta() {
        return this.revenueLastYearRaw > 0;
    }

    /**
     * Returns a formatted year-on-year revenue delta string
     * with directional arrow and percentage change.
     * @returns {string} e.g. '▲ 23% vs 2024'
     */
    get revenueDelta() {
        const difference = this.revenueThisYearRaw - this.revenueLastYearRaw;
        const percentChange = Math.round((difference / this.revenueLastYearRaw) * 100);
        return (difference >= 0 ? '▲' : '▼')
            + ` ${Math.abs(percentChange)}% vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the revenue delta indicator.
     * @returns {string} CSS class string
     */
    get revenueDeltaClass() {
        return this.revenueThisYearRaw >= this.revenueLastYearRaw
            ? 'stat-delta delta-up'
            : 'stat-delta delta-down';
    }

    // ---- BED NIGHTS GETTERS ----

    /**
     * Returns the raw total bed nights for the current year.
     * @returns {number} Total bed nights as a raw numeric value
     */
    get bedNightsThisYearRaw() {
        return this.bookingsForYear(this.currentYear)
            .reduce((accumulator, supplierBooking) =>
                accumulator + (supplierBooking.sugati__SB_Night__c || 0),
            0);
    }

    /**
     * Returns the raw total bed nights for the previous year.
     * @returns {number} Prior year bed nights as a raw numeric value
     */
    get bedNightsLastYearRaw() {
        return this.bookingsForYear(this.currentYear - 1)
            .reduce((accumulator, supplierBooking) =>
                accumulator + (supplierBooking.sugati__SB_Night__c || 0),
            0);
    }

    /**
     * Returns the formatted bed nights total for the current year.
     * @returns {string} Localised number string e.g. '3,284'
     */
    get bedNightsThisYear() {
        return this.bedNightsThisYearRaw.toLocaleString('en-GB');
    }

    /**
     * Returns true if prior year bed nights data exists.
     * @returns {boolean}
     */
    get showNightsDelta() {
        return this.bedNightsLastYearRaw > 0;
    }

    /**
     * Returns a formatted year-on-year bed nights delta string.
     * @returns {string} e.g. '▲ 142 vs 2024'
     */
    get nightsDelta() {
        const difference = this.bedNightsThisYearRaw - this.bedNightsLastYearRaw;
        return (difference >= 0 ? '▲' : '▼')
            + ` ${Math.abs(difference).toLocaleString('en-GB')} vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the bed nights delta indicator.
     * @returns {string} CSS class string
     */
    get nightsDeltaClass() {
        return this.bedNightsThisYearRaw >= this.bedNightsLastYearRaw
            ? 'stat-delta delta-up'
            : 'stat-delta delta-down';
    }

    // ---- BOOKINGS GETTERS ----

    /**
     * Returns the count of unique booked Opportunities for the current year.
     * @returns {number} Unique booking count
     */
    get bookingsThisYear() {
        return this.uniqueBookings(this.bookingsForYear(this.currentYear));
    }

    /**
     * Returns the count of unique booked Opportunities for the previous year.
     * @returns {number} Prior year unique booking count
     */
    get bookingsLastYear() {
        return this.uniqueBookings(this.bookingsForYear(this.currentYear - 1));
    }

    /**
     * Returns true if prior year booking data exists.
     * @returns {boolean}
     */
    get showBookingsDelta() {
        return this.bookingsLastYear > 0;
    }

    /**
     * Returns a formatted year-on-year bookings delta string.
     * @returns {string} e.g. '▲ 12 vs 2024'
     */
    get bookingsDelta() {
        const difference = this.bookingsThisYear - this.bookingsLastYear;
        return (difference >= 0 ? '▲' : '▼')
            + ` ${Math.abs(difference)} vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the bookings delta indicator.
     * @returns {string} CSS class string
     */
    get bookingsDeltaClass() {
        return this.bookingsThisYear >= this.bookingsLastYear
            ? 'stat-delta delta-up'
            : 'stat-delta delta-down';
    }

    // ---- AVG BOOKING VALUE GETTERS ----

    /**
     * Returns the raw average booking value for the current year.
     * Calculated as total revenue divided by unique booking count.
     * @returns {number} Average booking value or 0 if no bookings
     */
    get avgThisYearRaw() {
        return this.bookingsThisYear
            ? this.revenueThisYearRaw / this.bookingsThisYear
            : 0;
    }

    /**
     * Returns the raw average booking value for the previous year.
     * @returns {number} Prior year average booking value or 0 if no bookings
     */
    get avgLastYearRaw() {
        return this.bookingsLastYear
            ? this.revenueLastYearRaw / this.bookingsLastYear
            : 0;
    }

    /**
     * Returns the formatted average booking value for the current year.
     * @returns {string} Formatted value e.g. '9.1K' or '—' if no bookings
     */
    get avgBookingValue() {
        return this.bookingsThisYear
            ? this.formatValue(this.avgThisYearRaw)
            : '—';
    }

    /**
     * Returns true if prior year average booking data exists.
     * @returns {boolean}
     */
    get showAvgDelta() {
        return this.bookingsLastYear > 0 && this.revenueLastYearRaw > 0;
    }

    /**
     * Returns a formatted year-on-year average booking value delta string.
     * @returns {string} e.g. '▲ 15% vs 2024'
     */
    get avgDelta() {
        const difference    = this.avgThisYearRaw - this.avgLastYearRaw;
        const percentChange = Math.round((difference / this.avgLastYearRaw) * 100);
        return (difference >= 0 ? '▲' : '▼')
            + ` ${Math.abs(percentChange)}% vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the average booking value delta indicator.
     * @returns {string} CSS class string
     */
    get avgDeltaClass() {
        return this.avgThisYearRaw >= this.avgLastYearRaw
            ? 'stat-delta delta-up'
            : 'stat-delta delta-down';
    }

    // ---- LIFETIME GETTERS ----

    /**
     * Returns the raw lifetime revenue total across all booked Opportunities.
     * Only includes bookings where the Opportunity and booking date are populated.
     * @returns {number} Total lifetime revenue as a raw numeric value
     */
    get lifetimeRevenueRaw() {
        // return (this.supplierBookings || [])
        //     .filter(supplierBooking =>
        //         supplierBooking.sugati__SB_Opportunity__c
        //         && supplierBooking.sugati__SB_Opportunity__r?.sugati__O_Booking_Date__c)
        //     .reduce((accumulator, supplierBooking) =>
        //         accumulator + (supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c || 0),
        //     0);
        return this.lifetimeStats?.totalRevenue ?? 0;

    }

    /**
     * Returns the formatted lifetime revenue total.
     * @returns {string} Formatted revenue string e.g. '3.07M'
     */
    get lifetimeRevenue() {
        return this.formatValue(this.lifetimeRevenueRaw);
    }

    /**
     * Returns the earliest booking year across all Supplier Bookings,
     * used to display the 'Since YYYY' lifetime subtext.
     * @returns {number|null} Earliest year or null if no bookings exist
     */
    get lifetimeSince() {
        // const bookingYears = (this.supplierBookings || [])
        //     .filter(supplierBooking =>
        //         supplierBooking.sugati__SB_Opportunity__c
        //         && supplierBooking.sugati__SB_Opportunity__r?.sugati__O_Booking_Date__c)
        //     .map(supplierBooking =>
        //         new Date(supplierBooking.sugati__SB_Opportunity__r
        //             .sugati__O_Booking_Date__c).getFullYear());
        // return bookingYears.length ? Math.min(...bookingYears) : null;
        return this.lifetimeStats?.firstBookingYear ?? null;

    }

    /**
     * Returns the number of years since the first booking,
     * used in the lifetime subtext display.
     * @returns {number} Number of years or 0 if no bookings exist
     */
    get lifetimeYears() {
        return this.lifetimeSince ? this.currentYear - this.lifetimeSince : 0;
    }
}