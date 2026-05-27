import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SugatiTravellerProfileHeader extends NavigationMixin(LightningElement) {

    // ── Props from parent (sugatiAccountPage) ──
    // @api account;          // Full Account record
    @api opportunities = []; // All related Opps — used for Client Since calc

    // ─────────────────────────────────────────
    // AVATAR INITIALS
    // FirstName + LastName → first char of each, uppercased
    // e.g. "Sarah Harrington" → "SH"
    // ─────────────────────────────────────────
    _account;

    @api
    set account(value) {
        this._account = value;
        console.log('ACCOUNT RECEIVED:', JSON.stringify(value));
    }

    get account() {
        return this._account;
    }
    get initials() {
        if (!this._account) return '';
        const f = (this._account.sugati__A_First_Name__c || '').trim();
        const l = (this._account.sugati__A_Last_Name__c || '').trim();
        console.log('First Name:', f, 'Last Name:', l);
        return `${f.charAt(0)}${l.charAt(0)}`.toUpperCase();
    }
    // ─────────────────────────────────────────
    // FULL NAME
    // FirstName + " " + LastName
    // ─────────────────────────────────────────
    get fullName() {
        if (!this._account) return '';
        const f = this._account.sugati__A_First_Name__c || '';
        const l = this._account.sugati__A_Last_Name__c || '';
        return `${f} ${l}`.trim();
    }

    // ─────────────────────────────────────────
    // CONTACT DETAILS
    // ─────────────────────────────────────────
    get email() {
        return this._account?.sugati__A_Email__c || '';
    }

    get phone() {
        return this._account?.Phone || '';
    }

    // BillingCity + BillingCountry → "London, UK"
    // Hidden if both are empty
    get address() {
        if (!this._account) return '';
        const city    = (this._account.BillingCity    || '').trim();
        const country = (this._account.BillingCountry || '').trim();
        if (!city && !country) return '';
        return [city, country].filter(Boolean).join(', ');
    }

    // ─────────────────────────────────────────
    // BADGES
    // ─────────────────────────────────────────

    // Rating field → badge label e.g. "Platinum"
    // Hidden if Rating is empty
    get tierLabel() {
        return this._account?.Rating || '';
    }
    get hasTier() {
        return !!this.tierLabel;
    }

    // Active__c checkbox → show green "Active" badge if true
    // TODO: confirm exact API name with V Singh
    get isActive() {
        return !!this._account?.Active__c;
    }

    // Status field → show blue "Repeat Traveller" badge
    // Meeting notes say "Status" field on Account — confirm picklist value
    // TODO: confirm exact API name and value with V Singh
    get isRepeatTraveller() {
        return this._account?.sugati__A_Status__c === 'Repeat Traveller';
    }

    get statusLabel() {
        return this._account?.sugati__A_Status__c || '';
    }

    get hasStatus() {
        return !!this.statusLabel;
    }
    // ─────────────────────────────────────────
    // CLIENT SINCE
    // Find MIN(Booking_Date__c) across all related Opps
    // where Booking_Date__c is not null/empty
    // Display year only e.g. "2016"
    // Hidden if no Opps have a Booking_Date__c
    // TODO: confirm exact API name for Booking_Date__c with V Singh
    // ─────────────────────────────────────────
    get clientSince() {
        if (!this.opportunities?.length) return '';

        const years = this.opportunities
            .filter(o => o.sugati__O_Booking_Date__c)
            .map(o => new Date(o.sugati__O_Booking_Date__c).getFullYear());

        if (!years.length) return '';

        return String(Math.min(...years));
    }

    // ─────────────────────────────────────────
    // PROFILE NOTE
    // Account.Description field
    // Same gold left-border callout style
    // Section not rendered if field is empty
    // ─────────────────────────────────────────
    get profileNote() {
        return this._account?.Description || '';
    }
    get hasNote() {
        return !!this.profileNote;
    }
}