import { LightningElement, api } from 'lwc';

/**
 * Bed Nights by Room Type component for the Supplier page.
 * Displays a scrollable progress bar list showing the breakdown
 * of bed nights across different room types, derived from
 * Supplier Booking records passed in from the parent component.
 */
export default class SugatiSupplierBedNights extends LightningElement {

    /** All Supplier Booking records for this Supplier, passed from parent */
    @api supplierBookings = [];

    // ---- PUBLIC GETTERS ----

    /**
     * Aggregates bed nights by room type from all Supplier Bookings,
     * then returns a sorted list of display objects for the progress bars.
     * Each entry includes the room type label, percentage of total nights
     * and a width style string for the progress bar fill.
     * Entries with no room type are grouped under an empty string label.
     * @returns {Array} Array of room type display objects sorted by nights descending
     */
    get roomTypeRows() {
        const nightsByRoomType = {};

        (this.supplierBookings || []).forEach(supplierBooking => {
            // const roomType    = supplierBooking.sugati__SB_Room_Type__c || '';
            const roomType = supplierBooking.sugati__SB_Selected_Room_Type__r?.sugati__RT_Name__c || supplierBooking.sugati__SB_Room_Type__c || '';
            const nightsCount = supplierBooking.sugati__SB_Night__c     || 0;
            nightsByRoomType[roomType] = (nightsByRoomType[roomType] || 0) + nightsCount;
        });

        const sortedRoomTypeEntries = Object.entries(nightsByRoomType)
            .sort((firstEntry, secondEntry) => secondEntry[1] - firstEntry[1]);

        const totalNightsAcrossAllTypes = sortedRoomTypeEntries
            .reduce((accumulator, [, nightsValue]) =>
                accumulator + Math.max(nightsValue, 0), 0)
            || 1;

        return sortedRoomTypeEntries.map(([roomType, totalNights]) => {
            const percentage = Math.max(
                Math.round((Math.max(totalNights, 0) / totalNightsAcrossAllTypes) * 100),
                0
            );
            return {
                roomType: roomType,
                nights:   totalNights,
                pct:      percentage,
                barStyle: `width:${percentage}%`
            };
        });
    }

    /**
     * Returns true if there is at least one room type entry to display.
     * Used to toggle between the progress list and the empty state.
     * @returns {boolean}
     */
    get hasData() {
        return this.roomTypeRows.length > 0;
    }
}