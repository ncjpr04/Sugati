import { LightningElement, api } from 'lwc';

/**
 * Bed Nights by Type component for the Agency page.
 * Displays a scrollable progress bar list showing the breakdown
 * of bed nights across different room types, derived from
 * Supplier Booking records passed in from the parent component.
 * Only bookings with a room type and a linked booked Opportunity are included.
 */
export default class SugatiAgencyBedNights extends LightningElement {

    /** All Supplier Booking records for this Supplier, passed from parent */
    @api supplierBookings = [];

    // ---- PUBLIC GETTERS ----

    /**
     * Aggregates bed nights by room type from all Supplier Bookings,
     * then returns a sorted list of display objects for the progress bars.
     * Filters out bookings with no room type, no linked Opportunity,
     * or no booking date on the Opportunity.
     * Each entry includes the room type label, percentage of total nights
     * and a width style string for the progress bar fill.
     * @returns {Array} Array of room type display objects sorted by nights descending
     */
    get topRoomTypes() {
        const nightsByRoomType = {};

        (this.supplierBookings || []).forEach(supplierBooking => {
            if (!supplierBooking.sugati__SB_Opportunity__c
                || !supplierBooking.sugati__SB_Opportunity__r?.sugati__O_Booking_Date__c) {
                return;
            }
            if (!supplierBooking.sugati__SB_Room_Type__c) {
                return;
            }

            const roomType    = supplierBooking.sugati__SB_Room_Type__c;
            const nightsCount = supplierBooking.sugati__SB_Night__c || 0;
            nightsByRoomType[roomType] = (nightsByRoomType[roomType] || 0) + nightsCount;
        });

        const sortedRoomTypeEntries = Object.entries(nightsByRoomType)
            .sort((firstEntry, secondEntry) => secondEntry[1] - firstEntry[1]);

        const totalNightsAcrossAllTypes = sortedRoomTypeEntries
            .reduce((accumulator, [, nightsValue]) => accumulator + Math.max(nightsValue, 0), 0)
            || 1;

        return sortedRoomTypeEntries.map(([roomType, totalNights], index) => {
            const percentage = Math.max(
                Math.round((totalNights / totalNightsAcrossAllTypes) * 100),
                0
            );
            return {
                id:         `${roomType}-${index}`,
                label:      roomType,
                pct:        percentage,
                widthStyle: `width:${percentage}%`
            };
        });
    }

    /**
     * Returns true if there is at least one room type to display.
     * Used to toggle between the progress list and empty state.
     * @returns {boolean}
     */
    get hasData() {
        return this.topRoomTypes.length > 0;
    }
}