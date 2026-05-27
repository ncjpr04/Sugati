public with sharing class SupplierBookingTabCtrl {
    
    // Wrapper class to hold Booking + its related Passengers
    public class BookingWrapper {
        @AuraEnabled public sugati__Supplier_Booking__c booking {get;set;}
        @AuraEnabled public List<sugati__Group_Member__c> passengers {get;set;}
        
        public BookingWrapper(sugati__Supplier_Booking__c b, List<sugati__Group_Member__c> psgs) {
            this.booking = b;
            this.passengers = psgs;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<BookingWrapper> getSupplierBookings() {
        // 1. Fetch the Bookings
        List<sugati__Supplier_Booking__c> bookings = [SELECT 
                Id, Name, 
                sugati__SB_Opportunity__c,
                sugati__SB_Opportunity__r.Name,
                sugati__SB_Opportunity__r.sugati__O_Lock__c,
                sugati__SB_Opportunity__r.sugati__O_Agent__r.Name, 
                sugati__SB_Opportunity__r.StageName, 
                sugati__SB_No_of_Rooms__c, 
                sugati__SB_From_Date__c,
                sugati__SB_To_Date__c,
                sugati__SB_Notes__c,
                sugati__SB_Supplier__r.Name,
                sugati__SB_Room_Type__c
            FROM sugati__Supplier_Booking__c 
            WHERE sugati__SB_Supplier__r.sugati__S_own_property__c = true  
            AND sugati__S_SB_Record_Type_Name__c = 'Accommodation'];

        // 2. Collect Opportunity IDs
        Set<Id> oppIds = new Set<Id>();
        for(sugati__Supplier_Booking__c sb : bookings) {
            if(sb.sugati__SB_Opportunity__c != null) oppIds.add(sb.sugati__SB_Opportunity__c);
        }

        // 3. Fetch Group Members for those Opportunities and Map them
        Map<Id, List<sugati__Group_Member__c>> oppToMembersMap = new Map<Id, List<sugati__Group_Member__c>>();
        for(sugati__Group_Member__c gm : [SELECT Id, Name, sugati__GM_First_Name__c, sugati__GM_Last_Name__c, 
                                            sugati__GM_Salutation__c, sugati__GM_Occupancy_Type__c, sugati__GM_DOB__c,
                                            sugati__GM_Opportunity__c 
                                          FROM sugati__Group_Member__c 
                                          WHERE sugati__GM_Opportunity__c IN :oppIds]) {
            if(!oppToMembersMap.containsKey(gm.sugati__GM_Opportunity__c)) {
                oppToMembersMap.put(gm.sugati__GM_Opportunity__c, new List<sugati__Group_Member__c>());
            }
            oppToMembersMap.get(gm.sugati__GM_Opportunity__c).add(gm);
        }

        // 4. Wrap the data
        List<BookingWrapper> response = new List<BookingWrapper>();
        for(sugati__Supplier_Booking__c sb : bookings) {
            List<sugati__Group_Member__c> psgs = oppToMembersMap.containsKey(sb.sugati__SB_Opportunity__c) ? 
                                                 oppToMembersMap.get(sb.sugati__SB_Opportunity__c) : 
                                                 new List<sugati__Group_Member__c>();
            response.add(new BookingWrapper(sb, psgs));
        }

        return response;
    }
}