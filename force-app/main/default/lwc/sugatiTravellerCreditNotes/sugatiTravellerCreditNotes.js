import { LightningElement, api } from 'lwc';

/** SVG circle circumference for the credit dial (2 * π * r where r = 40). */
const DIAL_CIRCUMFERENCE = 251;

/** Number of days at or below which the expiry warning is shown as urgent. */
const EXPIRY_URGENT_DAYS = 60;

/** Milliseconds in one day — used for expiry date calculations. */
const MS_PER_DAY = 86400000;

export default class SugatiTravellerCreditNotes extends LightningElement {

    /**
     * List of Credit Memo SObject records to display.
     * Expected fields: sugati__CM_Is_Expired__c, sugati__CM_Amount__c,
     * sugati__CM_Credit_Memo_Date__c, sugati__O_Credit_Expiry_Date_c__c,
     * sugati__CM_Opportunity__r.Name, Name, Id.
     */
    @api creditMemos;

    /**
     * Currency symbol prepended to formatted monetary values.
     * Provided by the parent component based on the account's CurrencyIsoCode.
     */
    @api currencySymbol;

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Formats a numeric value as a localised integer string.
     * Returns '—' when the value is null or undefined.
     * @param  {Number|null} value - The raw numeric amount.
     * @return {String} Formatted string, e.g. '1,250', or '—'.
     */
    formatAmount(value) {
        const parsed = parseFloat(value);
        if (isNaN(parsed)) {
            return '—';
        }
        return Math.round(parsed).toLocaleString('en-GB', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        });
    }

    /**
     * Formats an ISO date string into a short localised date, e.g. '12 Jan 2025'.
     * Returns an empty string when no date is supplied.
     * @param  {String|null} dateValue - ISO date string to format.
     * @return {String} Formatted date string, or ''.
     */
    formatDate(dateValue) {
        if (!dateValue) {
            return '';
        }
        return new Date(dateValue).toLocaleDateString('en-GB', {
            day   : 'numeric',
            month : 'short',
            year  : 'numeric'
        });
    }

    /**
     * Enriches a raw Credit Memo record with pre-formatted display fields.
     * @param  {Object} creditMemo - Raw Credit Memo SObject record.
     * @return {Object} Enriched plain object with formatted amount and date fields.
     */
    enrichCreditMemo(creditMemo) {
        return {
            ...creditMemo,
            amountFormatted      : this.formatAmount(creditMemo.sugati__CM_Amount__c),
            issueDateFormatted   : this.formatDate(creditMemo.sugati__CM_Credit_Memo_Date__c),
            expiryDateFormatted  : this.formatDate(creditMemo.sugati__O_Credit_Expiry_Date_c__c)
        };
    }

    // ── Computed properties — note lists ──────────────────────────────────

    /**
     * Returns active (non-expired) Credit Memo records enriched with display fields.
     * @return {Array}
     */
    get activeNotes() {
        return (this.creditMemos || [])
            .filter(creditMemo => !creditMemo.sugati__CM_Is_Expired__c)
            .map(creditMemo => this.enrichCreditMemo(creditMemo));
    }

    /**
     * Returns expired Credit Memo records enriched with display fields.
     * @return {Array}
     */
    get expiredNotes() {
        return (this.creditMemos || [])
            .filter(creditMemo => creditMemo.sugati__CM_Is_Expired__c)
            .map(creditMemo => this.enrichCreditMemo(creditMemo));
    }

    // ── Computed properties — visibility flags ────────────────────────────

    /**
     * Returns true when at least one Credit Memo record exists.
     * @return {Boolean}
     */
    get hasMemos() {
        return (this.creditMemos || []).length > 0;
    }

    /**
     * Returns true when there is at least one active Credit Memo.
     * @return {Boolean}
     */
    get hasActive() {
        return this.activeNotes.length > 0;
    }

    /**
     * Returns true when there is at least one expired Credit Memo.
     * @return {Boolean}
     */
    get hasExpired() {
        return this.expiredNotes.length > 0;
    }

    /**
     * Returns the count of active Credit Memo records.
     * @return {Number}
     */
    get activeCount() {
        return this.activeNotes.length;
    }

    // ── Computed properties — totals ──────────────────────────────────────

    /**
     * Returns the total available credit across all active notes as a formatted string.
     * @return {String}
     */
    get totalAvailable() {
        const total = this.activeNotes
            .reduce((sum, creditMemo) => {
                const value = parseFloat(creditMemo.sugati__CM_Amount__c);
                return sum + (isNaN(value) ? 0 : value);
            }, 0);

        return this.formatAmount(total);
    }

    /**
     * Returns the total issued credit across all memos (active and expired) as a formatted string.
     * @return {String}
     */
    get totalIssued() {
        const total = (this.creditMemos || [])
            .reduce((sum, creditMemo) => {
                const value = parseFloat(creditMemo.sugati__CM_Amount__c);
                return sum + (isNaN(value) ? 0 : value);
            }, 0);

        return this.formatAmount(total);
    }

    // ── Computed properties — dial ────────────────────────────────────────

    /**
     * Returns the percentage of total credit that remains active (0–100).
     * Returns 0 when total issued is zero to avoid division by zero.
     * @return {Number}
     */
    get remainingPct() {
        const activeTotalAmount = this.activeNotes
            .reduce((sum, creditMemo) => {
                const value = parseFloat(creditMemo.sugati__CM_Amount__c);
                return sum + (isNaN(value) ? 0 : value);
            }, 0);
        const issuedTotalAmount = (this.creditMemos || [])
            .reduce((sum, creditMemo) => {
                const value = parseFloat(creditMemo.sugati__CM_Amount__c);
                return sum + (isNaN(value) ? 0 : value);
            }, 0);

        if (!issuedTotalAmount) {
            return 0;
        }
        return Math.round((activeTotalAmount / issuedTotalAmount) * 100);
    }

    /**
     * Returns the SVG stroke-dashoffset value for the credit dial arc,
     * based on the remaining percentage and the circle circumference.
     * @return {Number}
     */
    get dialOffset() {
        const remainingFraction = this.remainingPct / 100;
        return Math.round(DIAL_CIRCUMFERENCE * (1 - remainingFraction));
    }

    // ── Computed properties — expiry ──────────────────────────────────────

    /**
     * Returns the nearest expiry Date object among active notes that have an expiry date.
     * Returns null when no expiry dates exist.
     * @return {Date|null}
     */
    get nearestExpiry() {
        const expiryDates = this.activeNotes
            .filter(creditMemo => creditMemo.sugati__O_Credit_Expiry_Date_c__c)
            .map(creditMemo => new Date(creditMemo.sugati__O_Credit_Expiry_Date_c__c))
            .sort((dateA, dateB) => dateA - dateB);

        return expiryDates.length ? expiryDates[0] : null;
    }

    /**
     * Returns the nearest expiry date as a long localised string, e.g. '12 January 2025'.
     * Returns an empty string when no expiry date exists.
     * @return {String}
     */
    get nearestExpiryFormatted() {
        if (!this.nearestExpiry) {
            return '';
        }
        return this.nearestExpiry.toLocaleDateString('en-GB', {
            day   : 'numeric',
            month : 'long',
            year  : 'numeric'
        });
    }

    /**
     * Returns the number of days until the nearest credit expiry.
     * Returns 0 when there is no expiry or the date has already passed.
     * @return {Number}
     */
    get daysToExpiry() {
        if (!this.nearestExpiry) {
            return 0;
        }
        return Math.max(0, Math.ceil((this.nearestExpiry - Date.now()) / MS_PER_DAY));
    }

    /**
     * Returns the CSS class for the expiry warning row, applying an urgent
     * modifier when the expiry is within EXPIRY_URGENT_DAYS days.
     * @return {String}
     */
    get expiryClass() {
        return this.daysToExpiry <= EXPIRY_URGENT_DAYS
            ? 'credit-expiry expiry-urgent'
            : 'credit-expiry expiry-ok';
    }
}