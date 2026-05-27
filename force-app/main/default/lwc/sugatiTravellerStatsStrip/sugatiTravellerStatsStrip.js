import { LightningElement, api } from 'lwc';

/**
 * Maps Salesforce CurrencyIsoCode values to their BCP 47 locale strings
 * for use with toLocaleString number formatting.
 */
const CURRENCY_LOCALE_MAP = {
    GBP : 'en-GB',
    USD : 'en-US',
    EUR : 'en-GB',
    INR : 'hi-IN',
    AUD : 'en-AU',
    CAD : 'en-CA',
    AED : 'en-GB'
};

/** Fallback locale used when the account currency code is not in the map. */
const DEFAULT_LOCALE = 'en-GB';

/** Placeholder displayed when a stat value cannot be calculated. */
const EMPTY_VALUE = '—';

export default class SugatiTravellerStatsStrip extends LightningElement {

    /**
     * Account SObject record providing revenue and booking summary fields.
     * Expected fields: CurrencyIsoCode, sugati__Total_Revenue__c, sugati__A_Total_Bookings__c.
     */
    @api account;

    /**
     * List of Opportunity records used to calculate nights travelled.
     * Expected fields: sugati__O_Booking_Date__c, sugati__O_No_of_Nights__c.
     */
    @api opportunities;

    /**
     * Currency symbol prepended to formatted monetary stat values.
     * Provided by the parent component based on the account's CurrencyIsoCode.
     */
    @api currencySymbol;

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Formats a numeric value as a localised integer string using the locale
     * derived from the account's CurrencyIsoCode.
     * Returns EMPTY_VALUE when the value is null or undefined.
     * @param  {Number|null} value - The raw numeric value to format.
     * @return {String} Localised integer string, e.g. '186,400', or '—'.
     */
    formatNumber(value) {
        if (value === null || value === undefined) {
            return EMPTY_VALUE;
        }
        const numeric = parseFloat(value);
        if (isNaN(numeric)) {
            return EMPTY_VALUE;
        }
        const currencyCode = this.account?.CurrencyIsoCode;
        const locale = CURRENCY_LOCALE_MAP[currencyCode] || DEFAULT_LOCALE;
        return Math.round(numeric).toLocaleString(locale, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        });
    }


    // ── Computed properties ───────────────────────────────────────────────

    /**
     * Returns the account's total lifetime revenue formatted as a localised integer.
     * Sourced from sugati__Total_Revenue__c on the Account.
     * @return {String} Formatted revenue string, e.g. '186,400', or '—'.
     */
    get lifetimeValue() {
        return this.formatNumber(this.account?.sugati__Total_Revenue__c);
    }

    /**
     * Returns the account's total number of booked trips formatted as a localised integer.
     * Sourced from sugati__A_Total_Bookings__c on the Account.
     * @return {String} Formatted booking count string, or '—'.
     */
    get totalTrips() {
        return this.formatNumber(this.account?.sugati__A_Total_Bookings__c);
    }

    /**
     * Returns the average trip value calculated as total revenue divided by total bookings,
     * formatted as a localised integer.
     * Returns '—' when either value is missing or trips is zero.
     * @return {String} Formatted average value string, or '—'.
     */
    get avgTripValue() {
        const revenue = parseFloat(this.account?.sugati__Total_Revenue__c);
        const trips   = parseFloat(this.account?.sugati__A_Total_Bookings__c);

        if (!revenue || !trips || isNaN(revenue) || isNaN(trips) || trips === 0) {
            return EMPTY_VALUE;
        }
        return this.formatNumber(Math.round(revenue / trips));
    }


    /**
     * Returns the total number of nights travelled across all booked Opportunities,
     * summing sugati__O_No_of_Nights__c where sugati__O_Booking_Date__c is populated.
     * Returns '—' when no qualifying opportunities exist or the total is zero.
     * @return {String} Localised integer string, e.g. '142', or '—'.
     */
    get nightsTravelled() {
        if (!(this.opportunities || []).length) {
            return EMPTY_VALUE;
        }
        const totalNights = (this.opportunities || [])
            .filter(opportunity => opportunity.sugati__O_Booking_Date__c)
            .reduce((sum, opportunity) => {
                const nights = parseFloat(opportunity.sugati__O_No_of_Nights__c);
                return sum + (isNaN(nights) ? 0 : nights);
            }, 0);


        return totalNights > 0
            ? totalNights.toLocaleString(DEFAULT_LOCALE)
            : EMPTY_VALUE;
    }
}