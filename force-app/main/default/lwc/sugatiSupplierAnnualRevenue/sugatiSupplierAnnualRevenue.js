import { LightningElement, api, track } from 'lwc';

/** Abbreviated month labels used for the monthly bar chart x-axis */
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** Maximum bar height in pixels for the monthly revenue chart */
const MAX_BAR_HEIGHT_PX = 80;

/** Maximum bar height in pixels for the year-over-year chart */
const MAX_YOY_BAR_HEIGHT_PX = 60;

/** Number of prior years shown alongside the selected year */
const YEAR_RANGE = 4;

/** Maximum number of years displayed in Lifetime view */
const MAX_LIFETIME_YEARS = 20;


/**
 * Annual Revenue component for the Supplier page.
 * Displays a monthly revenue bar chart for the selected year
 * and a year-over-year comparison chart.
 * Data is derived from supplierBookings passed in from the parent.
 */
export default class SugatiSupplierAnnualRevenue extends LightningElement {

    /** All Supplier Booking records for this Supplier, passed from parent */
    @api supplierBookings = [];

    /** Currently selected year tab — either a numeric year or 'LT' for Lifetime */
    selectedYear = new Date().getFullYear();

    @api lifetimeStats = null;

    // ---- PUBLIC GETTERS ----

    /**
     * Builds the list of year tab objects for the tab selector.
     * Includes the last YEAR_RANGE + 1 years plus a Lifetime (LT) tab.
     * @returns {Array} Array of tab descriptor objects with label, value and cssClass
     */
    get yearTabs() {
        const currentYear = new Date().getFullYear();
        const tabs = [];

        for (let i = currentYear; i >= currentYear - YEAR_RANGE; i--) {
            tabs.push({
                label:    String(i),
                value:    i,
                cssClass: this.selectedYear === i ? 'year-tab active' : 'year-tab'
            });
        }

        tabs.push({
            label:    'LT',
            value:    'LT',
            cssClass: this.selectedYear === 'LT'
                ? 'year-tab lt-tab active'
                : 'year-tab lt-tab'
        });

        return tabs;
    }

    /**
     * Returns true if a specific year (not Lifetime) is selected.
     * Used to conditionally render the monthly chart section.
     * @returns {boolean}
     */
    get showMonthly() {
        return this.selectedYear !== 'LT';
    }

    /**
     * Aggregates total revenue per calendar year from all Supplier Bookings.
     * Uses sugati__SB_From_Date__c to determine the year of each booking.
     * @returns {object} Map of year (number) to total revenue (number)
     */
    get revenueByYear() {
        // LT tab — use server-aggregated all-time breakdown
        if (this.selectedYear === 'LT' && this.lifetimeStats?.revenueByYear) {
            const map = {};
            this.lifetimeStats.revenueByYear.forEach(item => {
                map[item.year] = parseFloat(item.revenue) || 0;
            });
            return map;
        }

        // Year tabs — derive from scoped 2-year raw rows as before
        const revenueByYearMap = {};
        (this.supplierBookings || []).forEach(supplierBooking => {
            const fromDate = supplierBooking.sugati__SB_From_Date__c;
            if (!fromDate) return;
            const year = new Date(fromDate).getFullYear();
            revenueByYearMap[year] = (revenueByYearMap[year] || 0)
                    + parseFloat(supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c || 0);
        });
        return revenueByYearMap;
    }


    /**
     * Builds the monthly bar chart data for the currently selected year.
     * Each bar represents one month's total revenue, scaled relative to
     * the highest month value. Returns empty array for Lifetime view.
     * @returns {Array} Array of bar descriptor objects for the monthly chart
     */
    get monthlyBars() {
        if (this.selectedYear === 'LT') {
            return [];
        }

        const monthlyRevenueTotals = Array(12).fill(0);

        (this.supplierBookings || []).forEach(supplierBooking => {
            const fromDate = supplierBooking.sugati__SB_From_Date__c;
            if (!fromDate) {
                return;
            }
            const bookingDate = new Date(fromDate);
            if (bookingDate.getFullYear() === this.selectedYear) {
                // CURRENT — same string risk
                monthlyRevenueTotals[bookingDate.getMonth()] +=
                    parseFloat(supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c || 0);
            }
        });

        const maxMonthlyRevenue = Math.max(...monthlyRevenueTotals, 1);

        return MONTHS.map((monthLabel, index) => {
            const percentage = monthlyRevenueTotals[index] / maxMonthlyRevenue;
            const heightInPx = Math.max(
                Math.round(percentage * MAX_BAR_HEIGHT_PX),
                monthlyRevenueTotals[index] > 0 ? 3 : 0
            );
            return {
                month:      index,
                monthLabel: monthLabel,
                barClass:   'bar',
                barStyle:   `height:${heightInPx}px`,
                tooltip:    `${monthLabel}: ${this.formatRevenue(monthlyRevenueTotals[index])}`
            };
        });
    }

    /**
     * Builds the year-over-year bar chart data.
     * In year view: shows selected year + prior YEAR_RANGE years.
     * In Lifetime view: shows up to MAX_LIFETIME_YEARS years with data.
     * @returns {Array} Array of bar descriptor objects for the YOY chart
     */
    get yoyBars() {
        const revenueByYearMap = this.revenueByYear;
        const currentYear      = new Date().getFullYear();
        let yearsToDisplay;

        if (this.selectedYear === 'LT') {
            const dataYears = Object.keys(revenueByYearMap).map(Number).sort();
            if (dataYears.length === 0) {
                return [];
            }
            yearsToDisplay = dataYears.slice(-MAX_LIFETIME_YEARS);
        } else {
            yearsToDisplay = [];
            for (let i = this.selectedYear - YEAR_RANGE; i <= this.selectedYear; i++) {
                yearsToDisplay.push(i);
            }
        }

        const revenueValues    = yearsToDisplay.map(year => revenueByYearMap[year] || 0);
        const maxYearlyRevenue = Math.max(...revenueValues, 1);

        return yearsToDisplay.map(year => {
            const yearRevenue  = revenueByYearMap[year] || 0;
            const percentage   = yearRevenue / maxYearlyRevenue;
            const heightInPx   = Math.max(
                Math.round(percentage * MAX_YOY_BAR_HEIGHT_PX),
                yearRevenue > 0 ? 3 : 0
            );
            const isActiveYear = year === this.selectedYear || this.selectedYear === 'LT';

            return {
                year:     String(year),
                barClass: isActiveYear ? 'bar' : 'bar secondary',
                barStyle: `height:${heightInPx}px`,
                tooltip:  `${year}: ${this.formatRevenue(yearRevenue)}`
            };
        });
    }

    // ---- EVENT HANDLERS ----

    /**
     * Handles year tab selection. Updates selectedYear to the clicked value.
     * @param {Event} event - Click event from the year tab element
     */
    handleYearSelect(event) {
        const selectedValue = event.currentTarget.dataset.year;
        this.selectedYear   = selectedValue === 'LT' ? 'LT' : parseInt(selectedValue, 10);
    }

    // ---- PRIVATE METHODS ----

    /**
     * Formats a numeric revenue value into a human-readable string
     * with K/M suffix. No currency symbol is prepended.
     * @param {number} numericValue - The raw numeric value to format
     * @returns {string} Formatted string e.g. '284K', '1.2M', or '—' if zero
     */
    formatRevenue(numericValue) {
        if (!numericValue || isNaN(numericValue)) {
            return '—';
        }
        if (numericValue >= 1000000) {
            return `${(numericValue / 1000000).toFixed(1)}M`;
        }
        if (numericValue >= 1000) {
            return `${Math.round(numericValue / 1000)}K`;
        }
        return String(Math.round(numericValue));
    }
}