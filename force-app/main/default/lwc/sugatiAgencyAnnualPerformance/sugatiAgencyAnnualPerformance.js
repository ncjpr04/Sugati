import { LightningElement, api } from 'lwc';

/** Abbreviated month labels used for the monthly bar chart x-axis. */
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** Maximum bar height in pixels for the monthly revenue chart. */
const MAX_BAR_HEIGHT_PX = 80;

/** Maximum bar height in pixels for the year-over-year chart. */
const MAX_YOY_BAR_HEIGHT_PX = 60;

/** Number of prior years to show alongside the selected year. */
const YEAR_RANGE = 4;

/** Maximum number of years to display in Lifetime view. */
const MAX_LIFETIME_YEARS = 20;

/**
 * Annual Performance component for the Agency page.
 * Displays a monthly revenue bar chart for the selected year
 * and a year-over-year comparison chart.
 * Data is derived from supplierBookings passed in from the parent.
 */
export default class SugatiAgencyAnnualPerformance extends LightningElement {

    /**
     * All Supplier Booking records for this Supplier, passed from the parent component.
     * Expected fields: sugati__SB_From_Date__c,
     * sugati__S_SB_Total_Gross_Cost_Booking_Currency__c.
     */
    @api supplierBookings;

    /** Controls the currently selected year tab — either a numeric year or 'LT' for Lifetime. */
    selectedYear = new Date().getFullYear();

    @api lifetimeStats = null;

    // ---- COMPUTED PROPERTIES ----

    /**
     * Builds the list of year tab objects for the tab selector.
     * Includes the last YEAR_RANGE + 1 years plus a Lifetime (LT) tab.
     * @return {Array} Array of tab descriptor objects with label, value and cssClass.
     */
    get yearTabs() {
        const currentYear = new Date().getFullYear();
        const tabs        = [];

        for (let yearIndex = currentYear; yearIndex >= currentYear - YEAR_RANGE; yearIndex--) {
            tabs.push({
                label    : String(yearIndex),
                value    : yearIndex,
                cssClass : this.selectedYear === yearIndex ? 'year-tab active' : 'year-tab'
            });
        }

        tabs.push({
            label    : 'LT',
            value    : 'LT',
            cssClass : this.selectedYear === 'LT'
                ? 'year-tab lt-tab active'
                : 'year-tab lt-tab'
        });

        return tabs;
    }

    /**
     * Returns true when a specific year (not Lifetime) is selected.
     * Used to conditionally render the monthly chart section.
     * @return {Boolean}
     */
    get showMonthly() {
        return this.selectedYear !== 'LT';
    }

    /**
     * Returns a display label for the currently selected year.
     * Returns 'Lifetime' when the LT tab is active.
     * @return {String|Number}
     */
    get selectedYearLabel() {
        return this.selectedYear === 'LT' ? 'Lifetime' : this.selectedYear;
    }

    /**
     * Aggregates total revenue per calendar year from all Supplier Bookings.
     * Uses sugati__SB_From_Date__c to determine the year of each booking.
     * @return {Object} Plain object mapping year (number) to total revenue (number).
     */

    get revenueByYear() {
        if (this.selectedYear === 'LT' && this.lifetimeStats?.revenueByYear) {
            // Use the server-aggregated all-time breakdown for the LT tab
            const map = {};
            this.lifetimeStats.revenueByYear.forEach(item => {
                map[item.year] = parseFloat(item.revenue) || 0;
            });
            return map;
        }

        // For year tabs — derive from the scoped 2-year raw rows as before
        const revenueByYearMap = {};
        (this.supplierBookings || []).forEach(supplierBooking => {
            const dateString = supplierBooking.sugati__SB_From_Date__c;
            if (!dateString) return;
            const year = new Date(dateString).getFullYear();
            revenueByYearMap[year] = (revenueByYearMap[year] || 0)
                    + (parseFloat(supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c) || 0);
        });
        return revenueByYearMap;
    }

    /**
     * Builds the monthly bar chart data for the currently selected year.
     * Each bar represents one month's total revenue, scaled relative to
     * the highest month value.
     * Returns an empty array when Lifetime view is active.
     * @return {Array} Array of bar descriptor objects for the monthly chart.
     */
    get monthlyBars() {
        if (this.selectedYear === 'LT') {
            return [];
        }

        const monthlyRevenueTotals = Array(12).fill(0);

        (this.supplierBookings || []).forEach(supplierBooking => {
            const dateString = supplierBooking.sugati__SB_From_Date__c;
            if (!dateString) {
                return;
            }
            const bookingDate = new Date(dateString);
            if (bookingDate.getFullYear() === this.selectedYear) {
                monthlyRevenueTotals[bookingDate.getMonth()] +=
                        parseFloat(supplierBooking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c) || 0;
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
                month      : index,
                monthLabel : monthLabel,
                barClass   : 'bar',
                barStyle   : `height:${heightInPx}px`,
                tooltip    : `${monthLabel}: ${this.formatRevenue(monthlyRevenueTotals[index])}`
            };
        });
    }

    /**
     * Builds the year-over-year bar chart data.
     * In year view: shows selected year + prior YEAR_RANGE years.
     * In Lifetime view: shows up to MAX_LIFETIME_YEARS years with data.
     * @return {Array} Array of bar descriptor objects for the YOY chart.
     */
    get yoyBars() {
        const revenueByYearMap = this.revenueByYear;
        let yearsToDisplay;

        if (this.selectedYear === 'LT') {
            const currentYear = new Date().getFullYear();
            const dataYears   = Object.keys(revenueByYearMap).map(Number);

            // Always include the last YEAR_RANGE + 1 years so the chart is never empty,
            // then merge in any additional years that have actual booking data beyond that range.
            const baseYears = [];
            for (let yearIndex = currentYear - YEAR_RANGE; yearIndex <= currentYear; yearIndex++) {
                baseYears.push(yearIndex);
            }

            const allYears = [...new Set([...baseYears, ...dataYears])].sort();
            yearsToDisplay = allYears.slice(-MAX_LIFETIME_YEARS);
        } else {
            yearsToDisplay = [];
            for (let yearIndex = this.selectedYear - YEAR_RANGE; yearIndex <= this.selectedYear; yearIndex++) {
                yearsToDisplay.push(yearIndex);
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
                year     : String(year),
                barClass : isActiveYear ? 'bar' : 'bar secondary',
                barStyle : `height:${heightInPx}px`,
                tooltip  : `${year}: ${this.formatRevenue(yearRevenue)}`
            };
        });
    }

    // ---- EVENT HANDLERS ----

    /**
     * Handles year tab selection. Updates the selectedYear property
     * and dispatches a 'yearselect' custom event to the parent.
     * @param {Event} event - The click event from the year tab element.
     */
    handleYearSelect(event) {
        const selectedValue = event.currentTarget.dataset.year;
        this.selectedYear   = selectedValue === 'LT' ? 'LT' : parseInt(selectedValue, 10);
        this.dispatchEvent(new CustomEvent('yearselect', { detail: this.selectedYear }));
    }

    /**
     * Handles bar click events for future drill-down functionality.
     * @param {Event} event - The click event from the bar element.
     */
    handleChartClick(event) {
        // TODO: implement drill-down on bar click
    }

    // ---- PRIVATE HELPERS ----

    /**
     * Formats a numeric revenue value into a human-readable string with K/M suffix.
     * No currency symbol is prepended.
     * Returns '—' when the value is zero or falsy.
     * @param  {Number} numericValue - The raw numeric value to format.
     * @return {String} Formatted string e.g. '284K', '1.2M', or '—'.
     */
    formatRevenue(numericValue) {
        if (!numericValue || isNaN(numericValue)) {
            return '—';
        }
        if (numericValue >= 1000000) {
            const millionValue = numericValue / 1000000;
            const formatted    = millionValue % 1 === 0
                ? `${Math.round(millionValue)}M`
                : `${millionValue.toFixed(1)}M`;
            return formatted;
        }
        if (numericValue >= 1000) {
            return `${Math.round(numericValue / 1000)}K`;
        }
        return String(Math.round(numericValue));
    }

}