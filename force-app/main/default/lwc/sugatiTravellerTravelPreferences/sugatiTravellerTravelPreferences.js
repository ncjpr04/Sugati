import { LightningElement, api, wire } from 'lwc';
import getTravellingCountries from '@salesforce/apex/SugatiTravellerPageCtrl.getTravellingCountries';
import getSupplierBookings    from '@salesforce/apex/SugatiTravellerPageCtrl.getSupplierBookings';

export default class SugatiTravellerTravelPreferences extends LightningElement {

    /**
     * Salesforce record Id of the Account whose travel preferences are displayed.
     */
    @api recordId;

    /**
     * List of Opportunity records used to determine which supplier bookings
     * originated from a booked opportunity.
     * Expected fields: sugati__O_Booking_Date__c, Id.
     */
    @api opportunities;

    /** @type {Array} Internal store for wired Travelling Country records. */
    _countries = [];

    /** @type {Array} Internal store for wired Supplier Booking records. */
    _supplierBookings = [];

    // ── Wire handlers ─────────────────────────────────────────────────────

    /**
     * Wires Travelling Country records for the current account.
     * Populates _countries when data is returned, clears it on error.
     * @param {Object} data  - The returned list of Travelling Country records.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getTravellingCountries, { accountId: '$recordId' })
    wiredCountries({ data, error }) {
        if (data) {
            this._countries = data;
        } else if (error) {
            this._countries = [];
        }
    }

    /**
     * Wires Accommodation Supplier Booking records for the current account.
     * Populates _supplierBookings when data is returned, clears it on error.
     * @param {Object} data  - The returned list of Supplier Booking records.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getSupplierBookings, { accountId: '$recordId' })
    wiredBookings({ data, error }) {
        if (data) {
            this._supplierBookings = data;
        } else if (error) {
            this._supplierBookings = [];
        }
    }

    // ── Computed properties ───────────────────────────────────────────────

    /**
     * Builds a set of Opportunity Ids that have a booking date,
     * used to determine whether a supplier booking is from a confirmed trip.
     * @return {Set<String>} Set of booked Opportunity Ids.
     */
    get bookedOpportunityIds() {
        return new Set(
            (this.opportunities || [])
                .filter(opportunity => opportunity.sugati__O_Booking_Date__c)
                .map(opportunity => opportunity.Id)
        );
    }

    /**
     * Aggregates Travelling Country records by continent and returns an array
     * of display objects sorted by frequency descending, each with a calculated
     * percentage and an inline width style for the progress bar.
     * Returns an empty array when no country records are available.
     * @return {Array} Array of { name, pct, style } objects.
     */
    get continentBars() {
        if (!this._countries.length) {
            return [];
        }
        const countsByContinent = {};

        this._countries.forEach(country => {
            const continentName = country.sugati__TC_Country__r?.sugati__C_Continent__r?.Name || 'Unknown';
            countsByContinent[continentName] = (countsByContinent[continentName] || 0) + 1;
        });

        const totalCountries = this._countries.length;

        return Object.entries(countsByContinent)
            .sort((entryA, entryB) => entryB[1] - entryA[1])
            .map(([name, count]) => {
                const pct = Math.round((count / totalCountries) * 100);
                return {
                    name,
                    pct,
                    style : `width:${pct}%`
                };
            });
    }

    /**
     * Derives unique accommodation supplier chips from the wired supplier bookings.
     * Each chip is marked as warm (golden) when its opportunity is a confirmed booking,
     * and once a supplier is flagged as booked it retains that status.
     * Returns an empty array when no supplier bookings are available.
     * @return {Array} Array of { name, cls } objects for template rendering.
     */
    get accommodationChips() {
        if (!this._supplierBookings.length) {
            return [];
        }
        const bookedOpportunityIds = this.bookedOpportunityIds;

        // Map of supplierName → isBooked; once marked booked it stays booked.
        const supplierBookedMap = new Map();

        this._supplierBookings.forEach(supplierBooking => {
            const supplierName = supplierBooking.sugati__SB_Supplier_Name__c;
            if (!supplierName) {
                return;
            }
            const isBooked = bookedOpportunityIds.has(supplierBooking.sugati__SB_Opportunity__c);
            if (!supplierBookedMap.has(supplierName) || isBooked) {
                supplierBookedMap.set(supplierName, isBooked);
            }
        });

        return Array.from(supplierBookedMap.entries()).map(([name, isBooked]) => ({
            name,
            cls : isBooked ? 'chip warm' : 'chip'
        }));
    }
}