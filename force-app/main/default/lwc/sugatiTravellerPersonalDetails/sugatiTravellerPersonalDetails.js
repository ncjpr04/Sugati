import { LightningElement, api, wire } from 'lwc';
import getContacts from '@salesforce/apex/SugatiTravellerPageCtrl.getContacts';

/** Milliseconds in a year (accounting for leap years) — used for age calculation. */
const MS_PER_YEAR = 365.25 * 24 * 60 * 60 * 1000;

/** Placeholder displayed when a value cannot be determined. */
const EMPTY_VALUE = '—';

export default class SugatiTravellerPersonalDetails extends LightningElement {

    /**
     * Salesforce record Id of the Account whose contacts and details are displayed.
     */
    @api recordId;

    /**
     * List of Opportunity records used to calculate the client since year.
     * Expected fields: sugati__O_Booking_Date__c.
     */
    @api opportunities;

    /** @type {Array} Internal store for wired Contact records. */
    _contacts = [];

    // ── Wire handlers ─────────────────────────────────────────────────────

    /**
     * Wires Contact records for the current account.
     * Populates _contacts when data is returned, clears it on error.
     * @param {Object} data  - The returned list of Contact records.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getContacts, { accountId: '$recordId' })
    wiredContacts({ data, error }) {
        if (data) {
            this._contacts = data;
        } else if (error) {
            this._contacts = [];
        }
    }

    // ── Computed properties — primary contact ─────────────────────────────

    /**
     * Returns the lead passenger Contact record, falling back to the first
     * contact in the list when no lead passenger is flagged.
     * Returns undefined when no contacts are available.
     * @return {Object|undefined}
     */
    get primaryContact() {
        return this._contacts.find(contact => contact.sugati__C_Lead_Passenger__c)
            || this._contacts[0];
    }

    /**
     * Returns the full name of the primary contact by joining first and last name.
     * Returns '—' when no primary contact exists.
     * @return {String}
     */
    get fullName() {
        const contact = this.primaryContact;
        if (!contact) {
            return EMPTY_VALUE;
        }
        return [contact.FirstName, contact.LastName].filter(Boolean).join(' ');
    }

    /**
     * Returns the date of birth of the primary contact as a formatted string
     * with the calculated age in parentheses, e.g. '12 January 1985 (40)'.
     * Returns '—' when no birthdate is available.
     * @return {String}
     */
    get dateOfBirth() {
        if (!this.primaryContact?.Birthdate) {
            return EMPTY_VALUE;
        }
        const dob = new Date(this.primaryContact.Birthdate);
        const age = Math.floor((Date.now() - dob) / MS_PER_YEAR);
        const formattedDate = dob.toLocaleDateString('en-GB', {
            day   : 'numeric',
            month : 'long',
            year  : 'numeric'
        });
        return `${formattedDate} (${age})`;
    }

    /**
     * Returns the LeadSource of the primary contact, or '—'.
     * @return {String}
     */
    get referralSource() {
        return this.primaryContact?.LeadSource || EMPTY_VALUE;
    }

    /**
     * Returns the nationality of the primary contact, or '—'.
     * @return {String}
     */
    get nationality() {
        return this.primaryContact?.sugati__C_Nationality__c || EMPTY_VALUE;
    }

    /**
     * Returns the passport number of the primary contact, or '—'.
     * @return {String}
     */
    get passportNumber() {
        return this.primaryContact?.sugati__C_Passport_Number__c || EMPTY_VALUE;
    }

    /**
     * Returns the passport expiry date of the primary contact as a formatted string,
     * e.g. '15 Jan 2030'. Returns '—' when no expiry date is available.
     * @return {String}
     */
    get passportExpiry() {
        if (!this.primaryContact?.sugati__C_Expires_Date__c) {
            return EMPTY_VALUE;
        }
        return new Date(this.primaryContact.sugati__C_Expires_Date__c)
            .toLocaleDateString('en-GB', {
                day   : 'numeric',
                month : 'short',
                year  : 'numeric'
            });
    }

    // ── Computed properties — client history ──────────────────────────────

    /**
     * Returns a 'Since YYYY' string derived from the earliest booking date
     * across all provided Opportunities. Returns '—' when no bookings exist.
     * @return {String}
     */
    get clientSince() {
        if (!(this.opportunities || []).length) {
            return EMPTY_VALUE;
        }
        const bookingYears = (this.opportunities || [])
            .filter(opportunity => opportunity.sugati__O_Booking_Date__c)
            .map(opportunity => new Date(opportunity.sugati__O_Booking_Date__c).getFullYear())
            .filter(year => !isNaN(year));

        if (!bookingYears.length) {
            return EMPTY_VALUE;
        }
        return `Since ${Math.min(...bookingYears)}`;
    }

    // ── Computed properties — companions ─────────────────────────────────

    /**
     * Returns all Contact records excluding the primary contact.
     * @return {Array}
     */
    get companions() {
        const primaryId = this.primaryContact?.Id;
        return this._contacts.filter(contact => contact.Id !== primaryId);
    }

    /**
     * Returns companion contacts with an Adult occupancy type,
     * with the warm chip CSS class applied for template rendering.
     * @return {Array}
     */
    get adultCompanions() {
        return this.companions
            .filter(companion =>
                (companion.sugati__Occupancy_Type__c || '').toLowerCase() === 'adult'
            )
            .map(companion => ({ ...companion, chipClass: 'chip warm' }));
    }

    /**
     * Returns companion contacts with a Child occupancy type.
     * @return {Array}
     */
    get childCompanions() {
        return this.companions.filter(companion =>
            (companion.sugati__Occupancy_Type__c || '').toLowerCase() === 'child'
        );
    }

    /**
     * Returns companion contacts with an Infant occupancy type.
     * @return {Array}
     */
    get infantCompanions() {
        return this.companions.filter(companion =>
            (companion.sugati__Occupancy_Type__c || '').toLowerCase() === 'infant'
        );
    }
}