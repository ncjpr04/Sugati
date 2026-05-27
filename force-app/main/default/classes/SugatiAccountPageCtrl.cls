public with sharing class SugatiAccountPageCtrl {

    @AuraEnabled(cacheable=true)
    public static Account getAccount(Id accountId) {
        return [
            SELECT Id, sugati__A_First_Name__c, sugati__A_Last_Name__c,
                   sugati__A_Email__c, Phone, // BillingAddress address type
                   BillingCity, BillingCountry,
                   Description,
                   Rating,
                   Active__c,
                   sugati__A_Status__c,
                   sugati__Total_Revenue__c,
                   sugati__A_Total_Bookings__c,
                   CurrencyIsoCode
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(Id accountId) {
        return [
            SELECT Id, Name, StageName,
                   Amount, CloseDate,
                   Probability,
                   sugati__O_Booking_Date__c,
                   sugati__O_Nights__c,
                   sugati__O_No_of_Nights__c,
                   sugati__O_Country__c
            FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY sugati__O_Booking_Date__c DESC NULLS LAST
        ];
    }
}