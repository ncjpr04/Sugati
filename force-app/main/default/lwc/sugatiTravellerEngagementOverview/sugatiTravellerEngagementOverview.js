import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

/** Milliseconds in one day — used for date difference calculations. */
const MS_PER_DAY = 86400000;

/** Placeholder displayed when a value cannot be calculated. */
const EMPTY_VALUE = '—';

export default class SugatiTravelEngagement extends NavigationMixin(LightningElement) {

    /**
     * Account SObject record providing name, Id and last enquiry date.
     * Expected fields: sugati__A_First_Name__c, sugati__A_Last_Enquiry_Date__c,
     * Id, CurrencyIsoCode.
     */
    @api account;

    /**
     * List of Opportunity records used across all booking-related getters.
     * Expected fields: sugati__O_Booking_Date__c, sugati__O_Country__c,
     * sugati__O_No_of_Nights__c, Amount, StageName, Name.
     */
    @api opportunities;

    /**
     * List of Task records linked to the account, used for last engagement calculations.
     * Expected fields: ActivityDate, Subject, TaskSubtype.
     */
    @api tasks;

    /**
     * Currency symbol prepended to formatted monetary values.
     * Provided by the parent component based on the account's CurrencyIsoCode.
     */
    @api currencySymbol;

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Formats a date value into a localised display string.
     * Returns an empty string when no date is supplied.
     * @param  {String|null} dateValue - ISO date string to format.
     * @return {String} Formatted date, e.g. '1 Jan 2025', or ''.
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
     * Returns the count of Opportunities whose booking date falls within a given year.
     * @param  {Number} year - The calendar year to count bookings for.
     * @return {Number} Count of matching opportunities.
     */
    countByYear(year) {
        return (this.opportunities || []).filter(opportunity => {
            if (!opportunity.sugati__O_Booking_Date__c) {
                return false;
            }
            return new Date(opportunity.sugati__O_Booking_Date__c).getFullYear() === year;
        }).length;
    }

    // ── Computed properties — current year references ─────────────────────

    /**
     * Returns the current calendar year, computed fresh on each access.
     * @return {Number}
     */
    get currentYear() {
        return new Date().getFullYear();
    }

    /**
     * Returns the previous calendar year.
     * @return {Number}
     */
    get lastYear() {
        return this.currentYear - 1;
    }

    /**
     * Returns the calendar year two years prior to the current year.
     * @return {Number}
     */
    get prevYear() {
        return this.currentYear - 2;
    }

    // ── Computed properties — tasks / last engagement ─────────────────────

    /**
     * Returns the most recent past Task record based on ActivityDate.
     * Filters out future-dated tasks and sorts descending by date.
     * Returns null when no qualifying tasks exist.
     * @return {Object|null}
     */
    get lastActivity() {
        if (!this.tasks?.length) {
            return null;
        }
        const today = new Date();
        return [...(this.tasks || [])]
            .filter(task => task.ActivityDate && new Date(task.ActivityDate) <= today)
            .sort((taskA, taskB) =>
                new Date(taskB.ActivityDate) - new Date(taskA.ActivityDate)
            )[0] || null;
    }

    /**
     * Returns a human-readable string describing how long ago the last activity occurred,
     * e.g. 'Today', 'Yesterday', '5 days ago'.
     * Returns '—' when no last activity exists.
     * @return {String}
     */
    get lastActivityDate() {
        if (!this.lastActivity?.ActivityDate) {
            return EMPTY_VALUE;
        }
        const diff = Date.now() - new Date(this.lastActivity.ActivityDate);

        if (diff < 0) {
            return 'Upcoming';
        }
        const days = Math.floor(diff / MS_PER_DAY);

        if (days === 0) { return 'Today'; }
        if (days === 1) { return 'Yesterday'; }
        return `${days} days ago`;
    }

    /**
     * Returns the Subject of the last activity task, or '—' if none exists.
     * @return {String}
     */
    get lastActivitySubject() {
        return this.lastActivity?.Subject || EMPTY_VALUE;
    }

    /**
     * Returns the TaskSubtype of the last activity task, or an empty string if none exists.
     * @return {String}
     */
    get lastActivityType() {
        return this.lastActivity?.TaskSubtype || '';
    }

    // ── Computed properties — opportunities / bookings ────────────────────

    /**
     * Returns Opportunities that have a booking date, sorted by booking date descending.
     * @return {Array}
     */
    get sortedOpportunities() {
        return [...(this.opportunities || [])]
            .filter(opportunity => opportunity.sugati__O_Booking_Date__c)
            .sort((opportunityA, opportunityB) =>
                new Date(opportunityB.sugati__O_Booking_Date__c) -
                new Date(opportunityA.sugati__O_Booking_Date__c)
            );
    }

    /**
     * Returns the most recent past booking Opportunity based on booking date.
     * Returns undefined when no qualifying opportunities exist.
     * @return {Object|undefined}
     */
    get lastBooking() {
        const today = new Date();
        return (this.opportunities || [])
            .filter(opportunity =>
                opportunity.sugati__O_Booking_Date__c &&
                new Date(opportunity.sugati__O_Booking_Date__c) <= today
            )
            .sort((opportunityA, opportunityB) =>
                new Date(opportunityB.sugati__O_Booking_Date__c) -
                new Date(opportunityA.sugati__O_Booking_Date__c)
            )[0];
    }

    /**
     * Returns the formatted booking date of the last booking, or '—'.
     * @return {String}
     */
    get lastBookingDate() {
        return this.formatDate(this.lastBooking?.sugati__O_Booking_Date__c) || EMPTY_VALUE;
    }

    /**
     * Returns the country of the last booking, or an empty string.
     * @return {String}
     */
    get lastBookingCountry() {
        return this.lastBooking?.sugati__O_Country__c || '';
    }

    /**
     * Returns the Amount of the last booking formatted as a localised currency string.
     * Uses the currencySymbol prop provided by the parent. Returns an empty string if no amount.
     * @return {String}
     */
    get lastBookingAmount() {
        if (!this.lastBooking?.Amount) {
            return '';
        }
        const symbol = this.currencySymbol || '£';
        return `${symbol}${Number(this.lastBooking.Amount).toLocaleString('en-GB')}`;
    }

    /**
     * Returns the month and year of the last booking formatted as 'Jan 2025', or '—'.
     * @return {String}
     */
    get lastBookingMonthYear() {
        if (!this.lastBooking?.sugati__O_Booking_Date__c) {
            return EMPTY_VALUE;
        }
        return new Date(this.lastBooking.sugati__O_Booking_Date__c)
            .toLocaleString('en-GB', { month: 'short', year: 'numeric' });
    }

    /**
     * Returns the calendar day number of the last booking for the calendar icon display.
     * Returns '—' when no last booking exists.
     * @return {String|Number}
     */
    get lastBookingDay() {
        if (!this.lastBooking?.sugati__O_Booking_Date__c) {
            return EMPTY_VALUE;
        }
        return new Date(this.lastBooking.sugati__O_Booking_Date__c).getDate();
    }

    /**
     * Returns the abbreviated month name of the last booking in uppercase, e.g. 'JAN'.
     * Returns an empty string when no last booking exists.
     * @return {String}
     */
    get lastBookingMonth() {
        if (!this.lastBooking?.sugati__O_Booking_Date__c) {
            return '';
        }
        return new Date(this.lastBooking.sugati__O_Booking_Date__c)
            .toLocaleString('en-GB', { month: 'short' })
            .toUpperCase();
    }

    /**
     * Returns the number of days elapsed since the last booking date.
     * Returns '—' when no last booking exists.
     * @return {String|Number}
     */
    get daysSinceBooking() {
        if (!this.lastBooking?.sugati__O_Booking_Date__c) {
            return EMPTY_VALUE;
        }
        const bookingDate = new Date(this.lastBooking.sugati__O_Booking_Date__c);
        const today       = new Date();

        bookingDate.setHours(0, 0, 0, 0);
        today.setHours(0, 0, 0, 0);

        return Math.floor((today - bookingDate) / MS_PER_DAY);
    }

    /**
     * Returns the name of the most recently booked Opportunity, or an empty string.
     * @return {String}
     */
    get lastOpportunityName() {
        return this.sortedOpportunities[0]?.Name || '';
    }

    // ── Computed properties — booking counts ─────────────────────────────

    /** @return {Number} Count of bookings in the current year. */
    get thisYearCount() { return this.countByYear(this.currentYear); }

    /** @return {Number} Count of bookings in the previous year. */
    get lastYearCount() { return this.countByYear(this.currentYear - 1); }

    /** @return {Number} Count of bookings two years ago. */
    get prevYearCount() { return this.countByYear(this.currentYear - 2); }

    /**
     * Returns true when the traveller has at least one booking in the current year.
     * @return {Boolean}
     */
    get hasBookingsThisYear() {
        return this.thisYearCount > 0;
    }

    /**
     * Returns 's' when there are multiple bookings this year, otherwise an empty string.
     * Used to pluralise the booking count badge label.
     * @return {String}
     */
    get bookingLabel() {
        return this.thisYearCount === 1 ? '' : 's';
    }

    // ── Computed properties — risk indicators ────────────────────────────

    /**
     * Returns true when there is no booking in the current year but there was
     * activity in the previous or the year before, indicating an at-risk traveller.
     * @return {Boolean}
     */
    get showRiskBadge() {
        return !this.hasBookingsThisYear && (this.lastYearCount > 0 || this.prevYearCount > 0);
    }

    /**
     * Returns the text for the risk badge, describing which year the last booking occurred.
     * Returns an empty string when no risk condition applies.
     * @return {String}
     */
    get riskBadgeText() {
        if (this.lastYearCount > 0) {
            return `⚠ Booked ${this.currentYear - 1} · No booking in ${this.currentYear}`;
        }
        if (this.prevYearCount > 0) {
            return `⚠ Last booked ${this.currentYear - 2}`;
        }
        return '';
    }

    /**
     * Returns a dynamic at-risk message summarising the traveller's booking history
     * and including a call to action based on any active pipeline enquiries.
     * @return {String}
     */
    get dynamicMessage() {
        const firstName = this.account?.sugati__A_First_Name__c || 'Client';

        let bookingYearsText = '';
        if (this.lastYearCount > 0 && this.prevYearCount > 0) {
            bookingYearsText = `${this.currentYear - 2}, ${this.currentYear - 1}`;
        } else if (this.lastYearCount > 0) {
            bookingYearsText = `${this.currentYear - 1}`;
        } else if (this.prevYearCount > 0) {
            bookingYearsText = `${this.currentYear - 2}`;
        }

        const activeEnquiry = (this.opportunities || [])
            .filter(opportunity =>
                opportunity.StageName !== OpportunityStageMapper.getCustomStageLabel('Closed Won') &&
                opportunity.StageName !== OpportunityStageMapper.getCustomStageLabel('Closed Lost')
            )[0];

        const enquiryText = activeEnquiry
            ? ` Active ${activeEnquiry.sugati__O_Country__c || ''} enquiry in pipeline — prioritise follow-up this week.`
            : ' Prioritise follow-up this week.';

        if (bookingYearsText) {
            return `${firstName} placed bookings in ${bookingYearsText} but has no confirmed booking for ${this.currentYear}.${enquiryText}`;
        }
        return `No recent booking history found for ${firstName}. High churn risk — immediate outreach recommended.`;
    }

    // ── Computed properties — next trip ──────────────────────────────────

    /**
     * Returns the next upcoming Opportunity whose booking date is in the future,
     * sorted ascending so the soonest trip is returned first.
     * Returns undefined when no upcoming trips exist.
     * @return {Object|undefined}
     */
    get nextTrip() {
        const today = new Date();
        return (this.opportunities || [])
            .filter(opportunity =>
                opportunity.sugati__O_Booking_Date__c &&
                new Date(opportunity.sugati__O_Booking_Date__c) > today
            )
            .sort((opportunityA, opportunityB) =>
                new Date(opportunityA.sugati__O_Booking_Date__c) -
                new Date(opportunityB.sugati__O_Booking_Date__c)
            )[0];
    }

    /** @return {Boolean} True when there is at least one upcoming trip. */
    get hasNextTrip() { return !!this.nextTrip; }

    /** @return {String} Formatted date of the next trip, or '—'. */
    get nextTripDate() { return this.formatDate(this.nextTrip?.sugati__O_Booking_Date__c) || EMPTY_VALUE; }

    /** @return {String} Country of the next trip, or an empty string. */
    get nextTripCountry() { return this.nextTrip?.sugati__O_Country__c || ''; }

    /** @return {String} StageName of the next trip opportunity, or an empty string. */
    get nextTripStage() { return this.nextTrip?.StageName || ''; }

    // ── Computed properties — enquiry ─────────────────────────────────────

    /**
     * Returns the formatted last enquiry date from the account record, or '—'.
     * @return {String}
     */
    get lastEnquiryDate() {
        return this.formatDate(this.account?.sugati__A_Last_Enquiry_Date__c) || EMPTY_VALUE;
    }

    // ── Event handlers ────────────────────────────────────────────────────

    /**
     * Navigates to the Log a Call quick action for the current account.
     */
    handleLogFollowUp() {
        this[NavigationMixin.Navigate]({
            type       : 'standard__quickAction',
            attributes : { apiName: 'Account.LogACall' },
            state      : { recordId: this.account?.Id }
        });
    }

    /**
     * Navigates to the standard record view page for the current account.
     */
    handleViewHistory() {
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId      : this.account?.Id,
                objectApiName : 'Account',
                actionName    : 'view'
            }
        });
    }
}