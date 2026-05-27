import { LightningElement, api, wire, track } from 'lwc';
import getSupplier         from '@salesforce/apex/SugatiSupplierPageCtrl.getSupplier';
import getSupplierBookings from '@salesforce/apex/SugatiSupplierPageCtrl.getSupplierBookings';
import getSupplierContacts from '@salesforce/apex/SugatiSupplierPageCtrl.getSupplierContacts';
import getFamVisits        from '@salesforce/apex/SugatiSupplierPageCtrl.getFamVisits';
import getLifetimeStats from '@salesforce/apex/SugatiSupplierPageCtrl.getLifetimeStats';

/**
 * Maps CurrencyIsoCode values to their display symbols.
 * Defined at module level to avoid duplication across getters.
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
 * Parent container component for the Supplier page.
 * Responsible for fetching all data via wired Apex methods and
 * distributing it to child components via @api properties.
 * No data processing occurs in this component — all logic
 * is handled in the relevant child components.
 */
export default class SugatiSupplierPage extends LightningElement {

    @api recordId;

    /** Supplier record — passed to profile header, details and metrics components */
    supplier;

    /** All Supplier Booking records for this Supplier */
    supplierBookings = [];

    /** All Supplier Contact records for this Supplier */
    supplierContacts = [];

    /** FAM Visit records for this Supplier */
    famVisits = [];

    lifetimeStats = null;

    // ---- WIRED DATA METHODS ----

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
     * Wires all Supplier Booking records for this Supplier.
     * @param {object} data  - List of Supplier Booking sObjects returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getSupplierBookings, { supplierId: '$recordId' })
    wiredBookings({ data, error }) {
        if (data) {
            this.supplierBookings = data;
            console.log('wiredBookings data:', data);
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

    // ---- PUBLIC GETTERS ----

    /**
     * Derives the currency symbol from the first Supplier Booking's
     * CurrencyIsoCode. Defaults to '£' if no bookings exist or
     * the currency code is not in the map.
     * @returns {string} Currency symbol e.g. '£', '$', '€'
     */
    get currencySymbolSupplierBookings() {
        const recentIsoCode   = this.supplierBookings[0]?.CurrencyIsoCode;
        const lifetimeIsoCode = this.lifetimeStats?.currencyIsoCode;
        const supplierIsoCode = this.supplier?.CurrencyIsoCode;
        const isoCode = recentIsoCode || lifetimeIsoCode || supplierIsoCode;
        return CURRENCY_SYMBOL_MAP[isoCode] || '£';
    }

}