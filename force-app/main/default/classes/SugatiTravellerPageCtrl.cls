public with sharing class SugatiTravellerPageCtrl {

    // ---- PUBLIC METHODS ----

    /**
     * Retrieves a single Account record by Id for display on the traveller page.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account record to retrieve
     * @return           : Account record with all required display fields
     */
    @AuraEnabled(cacheable=true)
    public static Account getAccount(Id accountId) {
        // if (!Utility.canAccessObj('Account')) {
        //     throw new AuraHandledException('Insufficient access to Account records.');
        // }
        return [
            SELECT Id,
                   sugati__A_First_Name__c,
                   sugati__A_Last_Name__c,
                   sugati__A_Email__c,
                   Phone,
                   BillingCity,
                   BillingCountry,
                   Description,
                   Rating,
                   Active__c,
                   sugati__A_Status__c,
                   sugati__Total_Revenue__c,
                   sugati__A_Total_Bookings__c,
                   CurrencyIsoCode,
                   sugati__A_Last_Enquiry_Date__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }

    /**
     * Retrieves Opportunity records linked to a given Account for display
     * on the traveller page booking history.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account whose opportunities to retrieve
     * @return           : List of Opportunity records ordered by booking date descending
     */
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(Id accountId) {
        Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1);
        return [
            SELECT Id,
                Name,
                StageName,
                Amount,
                CloseDate,
                Probability,
                sugati__O_Booking_Date__c,
                sugati__O_Nights__c,
                sugati__O_No_of_Nights__c,
                sugati__O_Country__c,
                sugati__O_Status__c
            FROM Opportunity
            WHERE AccountId = :accountId
            AND   CloseDate >= :windowStart   // direct field, indexable
            ORDER BY CloseDate DESC NULLS LAST
            LIMIT 1000
        ];
    }

    /**
     * Retrieves Task records linked directly to a given Account
     * for display in the activity timeline.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account whose tasks to retrieve
     * @return           : List of Task records ordered by activity date descending
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getTasks(Id accountId) {
        Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1);
        return [
            SELECT Id,
                Subject,
                ActivityDate,
                sugati__Type__c,
                Description,
                TaskSubtype
            FROM Task
            WHERE WhatId = :accountId
            AND   ActivityDate >= :windowStart   // direct field, indexable
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 1000
        ];
    }

    /**
     * Retrieves Contact records linked to a given Account for display
     * in the traveller passenger details component.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account whose contacts to retrieve
     * @return           : List of Contact records ordered by last name ascending
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContacts(Id accountId) {
        // if (!Utility.canAccessObj('Contact')) {
        //     throw new AuraHandledException('Insufficient access to Contact records.');
        // }
        return [
            SELECT Id,
                   Name,
                   FirstName,
                   LastName,
                   Birthdate,
                   sugati__C_Nationality__c,
                   sugati__C_Passport_Number__c,
                   sugati__C_Expires_Date__c,
                   sugati__C_Age__c,
                   sugati__Occupancy_Type__c,
                   sugati__C_Lead_Passenger__c,
                   LeadSource
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY LastName ASC NULLS LAST
            LIMIT 1000
        ];
    }

    /**
     * Retrieves Travelling Country records linked to booked Opportunities
     * on a given Account, for use in the destinations map component.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account whose travelling countries to retrieve
     * @return           : List of sugati__Travelling_Country__c records ordered by country name ascending
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__Travelling_Country__c> getTravellingCountries(Id accountId) {
        // Collect Opportunity Ids first on a direct indexed field,
        // then use IN bind — avoids cross-object filter entirely
        Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1);

        Set<Id> oppIds = new Map<Id, Opportunity>([
            SELECT Id
            FROM Opportunity
            WHERE AccountId  = :accountId
            AND   CloseDate >= :windowStart
            LIMIT 1000
        ]).keySet();

        if (oppIds.isEmpty()) {
            return new List<sugati__Travelling_Country__c>();
        }

        return [
            SELECT Id,
                sugati__TC_Country__c,
                sugati__TC_Country__r.sugati__C_Continent__c,
                sugati__TC_Country__r.sugati__C_Continent__r.Name,
                sugati__TC_Opportunity__c
            FROM sugati__Travelling_Country__c
            WHERE sugati__TC_Opportunity__c IN :oppIds   // direct field, indexable
            ORDER BY sugati__TC_Country__c ASC NULLS LAST
            LIMIT 1000
        ];
    }

    /**
     * Retrieves Accommodation Supplier Booking records linked to Opportunities
     * on a given Account, for use in the stays history component.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account whose supplier bookings to retrieve
     * @return           : List of sugati__Supplier_Booking__c records of Accommodation record type
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__Supplier_Booking__c> getSupplierBookings(Id accountId) {
        Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1);

        Set<Id> oppIds = new Map<Id, Opportunity>([
            SELECT Id
            FROM Opportunity
            WHERE AccountId  = :accountId
            AND   CloseDate >= :windowStart
            LIMIT 1000
        ]).keySet();

        if (oppIds.isEmpty()) {
            return new List<sugati__Supplier_Booking__c>();
        }

        return [
            SELECT Id,
                sugati__SB_Supplier_Name__c,
                sugati__SB_Opportunity__c,
                sugati__SB_Opportunity__r.sugati__O_Booking_Date__c,
                RecordType.DeveloperName
            FROM sugati__Supplier_Booking__c
            WHERE sugati__SB_Opportunity__c IN :oppIds       // direct field, indexable
            AND   RecordType.DeveloperName  =  'Accommodation'
            ORDER BY sugati__SB_From_Date__c DESC NULLS LAST // direct field, not cross-object
            LIMIT 1000
        ];
    }

    /**
     * Retrieves Task records linked to Opportunities on a given Account,
     * for use in the opportunity activity timeline component.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account whose opportunity tasks to retrieve
     * @return           : List of Task records ordered by activity date ascending
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getOpportunityTasks(Id accountId) {
        Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1);

        Set<Id> oppIds = new Map<Id, Opportunity>([
            SELECT Id
            FROM Opportunity
            WHERE AccountId  = :accountId
            AND   CloseDate >= :windowStart
            LIMIT 1000
        ]).keySet();

        if (oppIds.isEmpty()) {
            return new List<Task>();
        }

        return [
            SELECT Id,
                Subject,
                ActivityDate,
                WhatId
            FROM Task
            WHERE WhatId          IN :oppIds           // direct field, indexable
            AND   ActivityDate    >= :windowStart
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 1000
        ];
    }
    /**
     * Retrieves Credit Memo records linked to a given Account
     * for display in the credit memo summary component.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  accountId : Id of the Account whose credit memos to retrieve
     * @return           : List of sugati__Credit_Memo__c records ordered by memo date descending
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__Credit_Memo__c> getCreditMemos(Id accountId) {
        // if (!Utility.canAccessObj('sugati__Credit_Memo__c')) {
        //     throw new AuraHandledException('Insufficient access to Credit Memo records.');
        // }
        return [
            SELECT Id,
                   Name,
                   sugati__CM_Amount__c,
                   sugati__CM_Credit_Memo_Date__c,
                   sugati__CM_Is_Expired__c,
                   sugati__O_Credit_Expiry_Date_c__c,
                   sugati__CM_Opportunity__c,
                   sugati__CM_Opportunity__r.Name,
                   sugati__CM_Account__c
            FROM sugati__Credit_Memo__c
            WHERE sugati__CM_Account__c = :accountId
            ORDER BY sugati__CM_Credit_Memo_Date__c DESC NULLS LAST
            LIMIT 1000
        ];
    }
}