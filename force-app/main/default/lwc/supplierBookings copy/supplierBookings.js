import { LightningElement, wire } from 'lwc';
import getSupplierBookings from '@salesforce/apex/SupplierBookingTabCtrl.getSupplierBookings';

export default class SupplierBookings extends LightningElement {
    data = [];

    @wire(getSupplierBookings)
    wiredBookings({ error, data }) {
        if (data) {
            this.data = data.map(item => {
                const b = item.booking || {};
                const passengers = item.passengers || [];
                
                // Calculate the total number of physical rows this booking needs
                // 1 (Main) + 1 (Header) + N (Passengers)
                const totalHeight = 2 + passengers.length;

                return {
                    Id: b.Id,
                    BookingName: b.Name || '',
                    OpportunityName: b.sugati__SB_Opportunity__r?.Name || '',
                    AgencyName: b.sugati__SB_Opportunity__r?.sugati__O_Agent__r?.Name || '',
                    StageName: b.sugati__SB_Opportunity__r?.StageName || '',
                    Notes: b.sugati__SB_Notes__c || '',
                    SupplierName: b.sugati__SB_Supplier__r?.Name || '',
                    RoomType: b.sugati__SB_Room_Type__c || '',
                    BedConfig: b.sugati__SB_Bed_Configuration__c || '',
                    OccupancyType: b.sugati__GM_Occupancy_Type__c || '',
                    ArrivalDate: b.sugati__SB_From_Date__c || '',
                    DepartureDate: b.sugati__SB_To_Date__c || '',
                    
                    passengers: passengers,
                    totalSpan: totalHeight
                };
            });
        }
    }
}