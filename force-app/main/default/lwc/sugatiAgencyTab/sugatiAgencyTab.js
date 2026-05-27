import { LightningElement, api, wire } from 'lwc';
import getSupplier          from '@salesforce/apex/SugatiAgencyPageCtrl.getSupplier';
import getSupplierBookings  from '@salesforce/apex/SugatiAgencyPageCtrl.getSupplierBookings';
import getSupplierContacts  from '@salesforce/apex/SugatiAgencyPageCtrl.getSupplierContacts';
import getRecentActivity    from '@salesforce/apex/SugatiAgencyPageCtrl.getRecentActivity';
import getFamVisits         from '@salesforce/apex/SugatiAgencyPageCtrl.getFamVisits';
import getTopDestinations   from '@salesforce/apex/SugatiAgencyPageCtrl.getTopDestinations';
import getLifetimeStats from '@salesforce/apex/SugatiAgencyPageCtrl.getLifetimeStats';

/**
 * Maps CurrencyIsoCode values to their display symbols.
 * Defined once at module level to avoid duplication across getters.
 */
const CURRENCY_SYMBOL_MAP = {
    'GBP': '£',
    'USD': '$',
    'EUR': '€',
    'INR': '₹',
    'AED': 'AED ',
    'AUD': 'A$',
    'CAD': 'C$'
};

/**
 * Parent container component for the Agency page.
 * Responsible for fetching all data via wired Apex methods and
 * distributing it to child components via @api properties.
 * No data processing occurs in this component — all logic
 * is handled in the relevant child components.
 */
export default class SugatiAgencyTab extends LightningElement {

    /** The Salesforce record Id of the current Supplier page */
    @api recordId;

    /** Supplier record — passed to header, details and partner health components */
    supplier;

    /** Pre-processed destination items from Apex — passed to top destinations component */
    destinations = [];

    /** All Supplier Booking records for this Supplier */
    supplierBookings = [];

    /** All Supplier Contact records for this Supplier */
    supplierContacts = [];

    /** Recent Task activity records for this Supplier */
    recentActivity = [];

    /** FAM Visit records for this Supplier */
    famVisits = [];

    lifetimeStats = null;

    // ── WIRED DATA METHODS ────────────────────────────────────────────────────
    /**
     * Wires the Supplier record to this component.
     * @param {object} data  - The Supplier sObject returned from Apex
     * @param {object} error - Error object if the call fails
     */

    @wire(getLifetimeStats, { supplierId: '$recordId' })
    wiredLifetimeStats({ data, error }) {
        if (data)       { this.lifetimeStats = data; }
        else if (error) { console.error('wiredLifetimeStats error:', JSON.stringify(error)); }
    }

    /**
     * Wires the Supplier record to this component.
     * @param {object} data  - The Supplier sObject returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getSupplier, { supplierId: '$recordId' })
    wiredSupplier({ data, error }) {
        if (data) {
            this.supplier = data;
        } else if (error) {
            console.error('wiredSupplier error:', JSON.stringify(error));
        }
    }

    /**
     * Wires the top destination items for the current year.
     * Data is pre-processed in Apex — no further computation needed.
     * @param {object} data  - List of DestinationItem wrappers returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getTopDestinations, { supplierId: '$recordId' })
    wiredDestinations({ data, error }) {
        if (data) {
            this.destinations = data;
        } else if (error) {
            console.error('wiredDestinations error:', JSON.stringify(error));
        }
    }

    /**
     * Wires all Supplier Booking records for this Supplier.
     * @param {object} data  - List of Supplier Booking sObjects returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getSupplierBookings, { supplierId: '$recordId' })
    wiredBookings({ data, error }) {
        if (data) {
            this.supplierBookings = data;
        } else if (error) {
            console.error('wiredBookings error:', JSON.stringify(error));
        }
    }

    /**
     * Wires all Supplier Contact records for this Supplier.
     * @param {object} data  - List of Supplier Contact sObjects returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getSupplierContacts, { supplierId: '$recordId' })
    wiredContacts({ data, error }) {
        if (data) {
            this.supplierContacts = data;
        } else if (error) {
            console.error('wiredContacts error:', JSON.stringify(error));
        }
    }

    /**
     * Wires recent Task activity records for this Supplier.
     * @param {object} data  - List of Task sObjects returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getRecentActivity, { supplierId: '$recordId' })
    wiredActivity({ data, error }) {
        if (data) {
            this.recentActivity = data;
        } else if (error) {
            console.error('wiredActivity error:', JSON.stringify(error));
        }
    }

    /**
     * Wires FAM Visit records for this Supplier.
     * @param {object} data  - List of FAM Visit sObjects returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getFamVisits, { supplierId: '$recordId' })
    wiredFamVisits({ data, error }) {
        if (data) {
            this.famVisits = data;
        } else if (error) {
            console.error('wiredFamVisits error:', JSON.stringify(error));
        }
    }

    // ── GETTERS ───────────────────────────────────────────────────────────────

    /**
     * Derives the currency symbol from the first Supplier Booking's
     * CurrencyIsoCode. Defaults to '£' if no bookings exist or
     * the currency code is not in the map.
     * @returns {string} Currency symbol e.g. '£', '$', '€'
     */
    get currencySymbolSupplierBookings() {
        const recentIsoCode  = this.supplierBookings[0]?.CurrencyIsoCode;
        const lifetimeIsoCode = this.lifetimeStats?.currencyIsoCode;
        const isoCode = recentIsoCode || lifetimeIsoCode;
        return CURRENCY_SYMBOL_MAP[isoCode] || '£';
    }

    /**
     * Returns true if the Supplier record has been loaded,
     * used to conditionally render the header component.
     * @returns {boolean}
     */
    get hasSupplier() {
        return !!this.supplier;
    }
}