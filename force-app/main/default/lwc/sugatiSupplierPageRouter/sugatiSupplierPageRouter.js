import { LightningElement, api, wire } from 'lwc';
import getSupplier from '@salesforce/apex/SugatiSupplierPageCtrl.getSupplier';

/**
 * Set of Supplier record type developer names that should render
 * the Agency page rather than the standard Supplier page.
 */
const AGENCY_RECORD_TYPES = new Set(['Agency', 'Agent']);

/**
 * Router component for the Supplier/Agency page.
 * Resolves the RecordType of the current Supplier record and
 * conditionally renders either the Agency tab or the Supplier page.
 * Displays a loading spinner until the RecordType is resolved.
 */
export default class SugatiSupplierPageRouter extends LightningElement {

    /** The Salesforce record Id of the current Supplier page */
    @api recordId;

    // ---- PRIVATE MEMBER VARIABLES ----

    /** Whether the RecordType lookup has completed (success or error) */
    _recordTypeResolved = false;

    /** Whether the current record is an Agency or Agent type */
    _isAgency = false;

    /** Whether an error occurred during RecordType resolution */
    _hasError = false;

    // ---- WIRED DATA METHODS ----

    /**
     * Wires the Supplier record to resolve its RecordType DeveloperName.
     * Sets _isAgency based on whether the DeveloperName is in AGENCY_RECORD_TYPES.
     * Always sets _recordTypeResolved to true on completion to stop the spinner.
     * @param {object} data  - The Supplier sObject returned from Apex
     * @param {object} error - Error object if the call fails
     */
    @wire(getSupplier, { supplierId: '$recordId' })
    wiredSupplier({ data, error }) {
        if (data) {
            const developerName      = data.RecordType?.DeveloperName ?? '';
            this._isAgency           = AGENCY_RECORD_TYPES.has(developerName);
            this._recordTypeResolved = true;
        }
        if (error) {
            console.error('wiredSupplier error:', JSON.stringify(error));
            this._recordTypeResolved = true;
            this._hasError           = true;
        }
    }

    // ---- PUBLIC GETTERS ----

    /**
     * Returns true if the record is resolved and is an Agency or Agent type.
     * Used to conditionally render the Agency tab component.
     * @returns {boolean}
     */
    get isAgency() {
        return this._recordTypeResolved && this._isAgency && !this._hasError;
    }

    /**
     * Returns true if the record is resolved and is a standard Supplier type.
     * Used to conditionally render the Supplier page component.
     * @returns {boolean}
     */
    get isSupplier() {
        return this._recordTypeResolved && !this._isAgency && !this._hasError;
    }

    /**
     * Returns true while the RecordType is still being resolved.
     * Used to show the loading spinner.
     * @returns {boolean}
     */
    get isLoading() {
        return !this._recordTypeResolved;
    }

    /**
     * Returns true if an error occurred during RecordType resolution.
     * Used to render a user-facing error message instead of blank content.
     * @returns {boolean}
     */
    get hasError() {
        return this._hasError;
    }
}