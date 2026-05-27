import { LightningElement, api } from 'lwc';

/**
 * Revenue Metrics Strip component for the Supplier page.
 * Displays five KPI stat cards: Revenue, Bed Nights, Stays,
 * Average Booking Value and Lifetime Revenue.
 * All metrics are derived from supplierBookings passed from the parent.
 */
export default class SugatiSupplierRevenueMetrics extends LightningElement {

    /** Supplier sObject — reserved for future metric calculations */
    @api supplier;

    /** All Supplier Booking records for this Supplier, passed from parent */
    @api supplierBookings = [];

    /** Currency symbol derived from the first booking's CurrencyIsoCode */
    @api currencySymbol = '£';

    currentYear = new Date().getFullYear();
    // currentYear = 2027;

    @api lifetimeStats = null;


    // ---- PRIVATE METHODS ----

    /**
     * Filters supplier bookings to those whose related Opportunity
     * has a booking date falling within the specified calendar year.
     * @param {number} year - The calendar year to filter by
     * @returns {Array} Filtered array of Supplier Booking records
     */
    bookingsForYear(year) {
        return (this.supplierBookings || []).filter(supplierBooking => {
            const bookingDate = supplierBooking.sugati__SB_Opportunity__r
                ?.sugati__O_Booking_Date__c;
            return bookingDate && new Date(bookingDate).getFullYear() === year;
        });
    }

    /**
     * Returns the count of unique Opportunity Ids within a given
     * array of Supplier Bookings.
     * @param {Array} bookings - Array of Supplier Booking records
     * @returns {number} Count of unique Opportunities
     */
    uniqueOpps(bookings) {
        return new Set(
            bookings.map(supplierBooking => supplierBooking.sugati__SB_Opportunity__c)
        ).size;
    }

    /**
     * Formats a numeric value into a human-readable string
     * with B/M/K suffix. No currency symbol is prepended —
     * it is applied in the template via {currencySymbol}.
     * @param {number} numericValue - The raw numeric value to format
     * @returns {string} Formatted string e.g. '284K', '1.2M', or '—' if null
     */
    formatValue(numericValue) {
        if (!numericValue && numericValue !== 0) {
            return '—';
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
     * @returns {number} Total revenue as a raw numeric value
     */
    get revenueThisYearRaw() {
        return this.bookingsForYear(this.currentYear)
            .reduce((accumulator, supplierBooking) => {
                const value = parseFloat(
                    supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c
                );
                return accumulator + (isNaN(value) ? 0 : value);
            }, 0);
    }

    /**
     * Returns the raw total revenue for the previous year.
     * @returns {number} Prior year total revenue as a raw numeric value
     */
    get revenueLastYear() {
        return this.bookingsForYear(this.currentYear - 1)
            .reduce((accumulator, supplierBooking) => {
                const value = parseFloat(
                    supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c
                );
                return accumulator + (isNaN(value) ? 0 : value);
            }, 0);
    }


    /**
     * Returns the formatted revenue for the current year.
     * @returns {string} Formatted revenue string e.g. '284K'
     */
    get revenueThisYear() {
        return this.formatValue(this.revenueThisYearRaw);
    }

    /**
     * Returns true if prior year revenue data exists.
     * @returns {boolean}
     */
    get showRevenueDelta() {
        return this.revenueLastYear > 0;
    }

    /**
     * Returns a formatted year-on-year revenue delta string.
     * @returns {string} e.g. '▲ 23% vs 2024' or empty string if no prior data
     */
    get revenueDelta() {
        if (!this.revenueLastYear) {
            return '';
        }
        const difference      = this.revenueThisYearRaw - this.revenueLastYear;
        const percentChange   = Math.round((difference / this.revenueLastYear) * 100);
        const directionArrow  = difference >= 0 ? '▲' : '▼';
        return `${directionArrow} ${Math.abs(percentChange)}% vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the revenue delta indicator.
     * @returns {string} CSS class string
     */
    get revenueDeltaClass() {
        return this.revenueThisYearRaw >= this.revenueLastYear
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
            .reduce((accumulator, supplierBooking) => {
                const value = parseFloat(supplierBooking.sugati__SB_Night__c);
                return accumulator + (isNaN(value) ? 0 : value);
            }, 0);
    }


    /**
     * Returns the raw total bed nights for the previous year.
     * @returns {number} Prior year bed nights as a raw numeric value
     */
    get bedNightsLastYear() {
        return this.bookingsForYear(this.currentYear - 1)
            .reduce((accumulator, supplierBooking) => {
                const value = parseFloat(supplierBooking.sugati__SB_Night__c);
                return accumulator + (isNaN(value) ? 0 : value);
            }, 0);
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
        return this.bedNightsLastYear > 0;
    }

    /**
     * Returns a formatted year-on-year bed nights delta string.
     * @returns {string} e.g. '▲ 142 vs 2024' or empty string if no prior data
     */
    get nightsDelta() {
        if (!this.bedNightsLastYear) {
            return '';
        }
        const difference     = this.bedNightsThisYearRaw - this.bedNightsLastYear;
        const directionArrow = difference >= 0 ? '▲' : '▼';
        return `${directionArrow} ${Math.abs(difference).toLocaleString('en-GB')} vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the bed nights delta indicator.
     * @returns {string} CSS class string
     */
    get nightsDeltaClass() {
        return this.bedNightsThisYearRaw >= this.bedNightsLastYear
            ? 'stat-delta delta-up'
            : 'stat-delta delta-down';
    }

    // ---- STAYS GETTERS ----

    /**
     * Returns the count of unique stays (Opportunities) for the current year.
     * @returns {number} Unique stay count
     */
    get staysThisYear() {
        return this.uniqueOpps(this.bookingsForYear(this.currentYear));
    }

    /**
     * Returns the count of unique stays for the previous year.
     * @returns {number} Prior year unique stay count
     */
    get staysLastYear() {
        return this.uniqueOpps(this.bookingsForYear(this.currentYear - 1));
    }

    /**
     * Returns true if prior year stay data exists.
     * @returns {boolean}
     */
    get showStaysDelta() {
        return this.staysLastYear > 0;
    }

    /**
     * Returns a formatted year-on-year stays delta string.
     * @returns {string} e.g. '▲ 5 vs 2024' or empty string if no prior data
     */
    get staysDelta() {
        if (!this.staysLastYear) {
            return '';
        }
        const difference     = this.staysThisYear - this.staysLastYear;
        const directionArrow = difference >= 0 ? '▲' : '▼';
        return `${directionArrow} ${Math.abs(difference)} vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the stays delta indicator.
     * @returns {string} CSS class string
     */
    get staysDeltaClass() {
        return this.staysThisYear >= this.staysLastYear
            ? 'stat-delta delta-up'
            : 'stat-delta delta-down';
    }

    // ---- AVG BOOKING VALUE GETTERS ----

    /**
     * Returns the formatted average booking value for the current year.
     * Calculated as total revenue divided by unique stay count.
     * @returns {string} Formatted value e.g. '9.1K' or '—' if no stays
     */
    get avgBookingValue() {
        const staysThisYear = this.staysThisYear;
        if (!staysThisYear) {
            return '—';
        }
        return this.formatValue(this.revenueThisYearRaw / staysThisYear);
    }

    /**
     * Returns the raw average booking value for the previous year.
     * @returns {number} Prior year average or 0 if no stays
     */
    get avgLastYear() {
        const staysLastYear = this.staysLastYear;
        if (!staysLastYear) {
            return 0;
        }
        return this.revenueLastYear / staysLastYear;
    }

    /**
     * Returns the raw average booking value for the current year.
     * @returns {number} Current year average or 0 if no stays
     */
    get avgThisYearRaw() {
        const staysThisYear = this.staysThisYear;
        if (!staysThisYear) {
            return 0;
        }
        return this.revenueThisYearRaw / staysThisYear;
    }

    /**
     * Returns true if prior year average booking data exists.
     * @returns {boolean}
     */
    get showAvgDelta() {
        return this.staysLastYear > 0 && this.revenueLastYear > 0;
    }

    /**
     * Returns a formatted year-on-year average booking value delta string.
     * @returns {string} e.g. '▲ 15% vs 2024' or empty string if no prior data
     */
    get avgDelta() {
        if (!this.avgLastYear) {
            return '';
        }
        const difference     = this.avgThisYearRaw - this.avgLastYear;
        const percentChange  = Math.round((difference / this.avgLastYear) * 100);
        const directionArrow = difference >= 0 ? '▲' : '▼';
        return `${directionArrow} ${Math.abs(percentChange)}% vs ${this.currentYear - 1}`;
    }

    /**
     * Returns the CSS class for the average booking value delta indicator.
     * @returns {string} CSS class string
     */
    get avgDeltaClass() {
        return this.avgThisYearRaw >= this.avgLastYear
            ? 'stat-delta delta-up'
            : 'stat-delta delta-down';
    }

    // ---- LIFETIME GETTERS ----

    /**
     * Returns the formatted lifetime revenue total across all bookings.
     * @returns {string} Formatted revenue string e.g. '3.07M'
     */
    get lifetimeRevenueRaw() {
        const value = parseFloat(this.lifetimeStats?.totalRevenue);
        return isNaN(value) ? 0 : value;
    }

    get lifetimeRevenue() {
        return this.formatValue(this.lifetimeRevenueRaw);
    }
    
    /**
     * Returns the earliest booking year across all Supplier Bookings.
     * Used to display the 'Since YYYY' lifetime subtext.
     * @returns {number|null} Earliest year or null if no bookings exist
     */
    get lifetimeSince() {
        return this.lifetimeStats?.firstBookingYear ?? null;
    }


    /**
     * Returns the number of years since the first booking.
     * @returns {number} Number of years or 0 if no bookings exist
     */
    get lifetimeYears() {
        return this.lifetimeSince ? this.currentYear - this.lifetimeSince : 0;
    }

}