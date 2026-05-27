import { LightningElement, api, wire } from 'lwc';
import getAccount      from '@salesforce/apex/SugatiTravellerPageCtrl.getAccount';
import getOpportunities from '@salesforce/apex/SugatiTravellerPageCtrl.getOpportunities';
import getTasks         from '@salesforce/apex/SugatiTravellerPageCtrl.getTasks';
import getCreditMemos   from '@salesforce/apex/SugatiTravellerPageCtrl.getCreditMemos';

/** Maps Salesforce CurrencyIsoCode values to their display symbols. */
const CURRENCY_SYMBOL_MAP = {
    GBP : '£',
    USD : '$',
    EUR : '€',
    INR : '₹',
    AED : 'AED '
};

/** Default currency symbol used when the account currency is not in the map. */
const DEFAULT_CURRENCY_SYMBOL = '£';

export default class SugatiAccountPage extends LightningElement {

    /** Salesforce record Id of the Account being displayed. */
    @api recordId;

    /** Account SObject record populated by the wired getAccount call. */
    account;

    /** List of Opportunity records linked to the account. */
    opportunities = [];

    /** List of Task records linked directly to the account. */
    tasks = [];

    /** List of Credit Memo records linked to the account. */
    creditMemos = [];

    /** Currently active tab identifier. Defaults to 'b2c'. */
    activeTab = 'b2c';

    // ── Wire handlers ─────────────────────────────────────────────────────

    /**
     * Wires the Account record for the current recordId.
     * Populates the account property when data is returned.
     * @param {Object} data  - The returned Account record.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getAccount, { accountId: '$recordId' })
    wiredAccount({ data, error }) {
        if (data) {
            this.account = data;
        } else if (error) {
            this.account = undefined;
        }
    }

    /**
     * Wires Opportunity records linked to the current account.
     * Populates the opportunities list when data is returned.
     * @param {Object} data  - The returned list of Opportunity records.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getOpportunities, { accountId: '$recordId' })
    wiredOpportunities({ data, error }) {
        if (data) {
            this.opportunities = data;
        } else if (error) {
            this.opportunities = [];
        }
    }

    /**
     * Wires Task records linked directly to the current account.
     * Populates the tasks list when data is returned.
     * @param {Object} data  - The returned list of Task records.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getTasks, { accountId: '$recordId' })
    wiredTasks({ data, error }) {
        if (data) {
            this.tasks = data;
        } else if (error) {
            this.tasks = [];
        }
    }

    /**
     * Wires Credit Memo records linked to the current account.
     * Populates the creditMemos list when data is returned.
     * @param {Object} data  - The returned list of Credit Memo records.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getCreditMemos, { accountId: '$recordId' })
    wiredCreditMemos({ data, error }) {
        if (data) {
            this.creditMemos = data;
        } else if (error) {
            this.creditMemos = [];
        }
    }

    // ── Event handlers ────────────────────────────────────────────────────

    /**
     * Handles tab change events dispatched by child components.
     * Updates the activeTab property to the value provided in the event detail.
     * @param {CustomEvent} event - Event carrying the new tab identifier in event.detail.
     */
    handleTabChange(event) {
        this.activeTab = event.detail;
    }

    // ── Computed properties ───────────────────────────────────────────────

    /**
     * Returns true when the active tab is 'b2c'.
     * @return {Boolean}
     */
    get isB2C() {
        return this.activeTab === 'b2c';
    }

    /**
     * Returns true when the active tab is 'b2b'.
     * @return {Boolean}
     */
    get isB2B() {
        return this.activeTab === 'b2b';
    }

    /**
     * Returns true when the active tab is 'supplier'.
     * @return {Boolean}
     */
    get isSupplier() {
        return this.activeTab === 'supplier';
    }

    /**
     * Returns the currency symbol corresponding to the account's CurrencyIsoCode.
     * Falls back to '£' when the currency code is not in the map or the account is not yet loaded.
     * @return {String} Currency symbol string, e.g. '£', '$', '€'.
     */
    get currencySymbol() {
        return CURRENCY_SYMBOL_MAP[this.account?.CurrencyIsoCode] ?? DEFAULT_CURRENCY_SYMBOL;
    }
}