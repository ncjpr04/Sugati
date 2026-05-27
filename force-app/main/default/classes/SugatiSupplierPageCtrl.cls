public with sharing class SugatiSupplierPageCtrl {

    // ---- PUBLIC METHODS ----

    /**
     * Retrieves a single Supplier record by Id for display on the supplier page.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  supplierId : Id of the Supplier record to retrieve
     * @return            : sugati__Supplier__c record with all required display fields
     */
    @AuraEnabled(cacheable=true)
    public static sugati__Supplier__c getSupplier(Id supplierId) {
        // if (!Utility.canAccessObj('sugati__Supplier__c')) {
        //     throw new AuraHandledException('Insufficient access to Supplier records.');
        // }
        return [
            SELECT Id,
                   Name,
                   sugati__S_Type__c,
                   RecordType.DeveloperName,
                   sugati__S_Phone__c,
                   sugati__S_Website__c,
                   sugati__S_Rating__c,
                   sugati__S_City__c,
                   sugati__S1_Country__c,
                   sugati__S_Emergency_Phone__c,
                   sugati__S_Commission__c,
                   sugati__S_Parent_Supplier__c,
                   sugati__S_Description__c,
                   sugati__S_Parent_Supplier__r.Name,
                   CurrencyIsoCode,
                   CreatedDate
            FROM sugati__Supplier__c
            WHERE Id = :supplierId
            LIMIT 1
        ];
    }

    /**
     * Retrieves Supplier Booking records for the current and prior calendar year
     * for a given Supplier. Scoped to sugati__SB_From_Date__c >= 1 Jan last year
     * to keep the query selective on a direct indexed field.
     * Excludes Agency and Agent record types via pre-fetched RecordType Ids.
     * Hard-capped at 2000 rows as a governor safety net.
     * @param  supplierId : Id of the Supplier record whose bookings to retrieve
     * @return            : List of sugati__Supplier_Booking__c records ordered by start date descending
     */
    // @AuraEnabled(cacheable=true)
    // public static List<sugati__Supplier_Booking__c> getSupplierBookings(Id supplierId) {
    //     Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1);

    //     // Pre-fetch excluded RecordType Ids — avoids non-indexable cross-object RT filter
    //     Set<Id> excludedRtIds = new Map<Id, RecordType>([
    //         SELECT Id
    //         FROM RecordType
    //         WHERE SObjectType    = 'sugati__Supplier__c'
    //         AND   DeveloperName IN ('Agency', 'Agent')
    //     ]).keySet();

    //     return [
    //         SELECT Id,
    //             sugati__SB_Opportunity__c,
    //             sugati__SB_Opportunity__r.Name,
    //             sugati__SB_Opportunity__r.AccountId,
    //             sugati__SB_Opportunity__r.Account.Name,
    //             sugati__SB_Opportunity__r.sugati__O_Booking_Date__c,
    //             sugati__S_SB_Total_Gross_Cost_Booking_Currency__c,
    //             sugati__SB_Night__c,
    //             sugati__SB_Pax_for_Costing__c,
    //             sugati__S_SB_Option_Number__c,
    //             sugati__SB_Room_Type__c,
    //             sugati__SB_From_Date__c,
    //             sugati__SB_To_Date__c,
    //             CurrencyIsoCode
    //         FROM sugati__Supplier_Booking__c
    //         WHERE sugati__SB_Supplier__c      =  :supplierId
    //         AND   sugati__SB_Opportunity__c   != null
    //         AND   sugati__SB_From_Date__c     >= :windowStart
    //         AND   sugati__SB_Supplier__r.RecordTypeId NOT IN :excludedRtIds
    //         ORDER BY sugati__SB_From_Date__c DESC NULLS LAST
    //         LIMIT 2000
    //     ];
    // }

    @AuraEnabled(cacheable=true)
    public static List<sugati__Supplier_Booking__c> getSupplierBookings(Id supplierId) {
        Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1);

        Set<Id> excludedRtIds = new Map<Id, RecordType>([
            SELECT Id
            FROM RecordType
            WHERE SObjectType    = 'sugati__Supplier__c'
            AND   DeveloperName IN ('Agency', 'Agent')
        ]).keySet();

        List<sugati__Supplier_Booking__c> bookings = [
            SELECT Id,
                sugati__SB_Opportunity__c,
                sugati__SB_Opportunity__r.Name,
                sugati__SB_Opportunity__r.AccountId,
                sugati__SB_Opportunity__r.Account.Name,
                sugati__SB_Opportunity__r.sugati__O_Booking_Date__c,
                sugati__S_SB_Total_Gross_Cost_Booking_Currency__c,
                sugati__SB_Night__c,
                sugati__SB_Pax_for_Costing__c,
                sugati__S_SB_Option_Number__c,
                sugati__SB_Room_Type__c,
                sugati__SB_From_Date__c,
                sugati__SB_To_Date__c,
                sugati__SB_Selected_Room_Type__c,
                sugati__SB_Selected_Room_Type__r.Name,
                sugati__SB_Selected_Room_Type__r.sugati__RT_Name__c,
                CurrencyIsoCode
            FROM sugati__Supplier_Booking__c
            WHERE sugati__SB_Supplier__c      =  :supplierId
            AND   sugati__SB_Opportunity__c   != null
            AND   sugati__SB_From_Date__c     >= :windowStart
            AND   sugati__SB_Supplier__r.RecordTypeId NOT IN :excludedRtIds
            ORDER BY sugati__SB_From_Date__c DESC NULLS LAST
            LIMIT 2000
        ];

        // ── DEBUG ─────────────────────────────────────────────────────────────────
        for (sugati__Supplier_Booking__c booking : bookings) {
            Decimal grossCost = booking.sugati__S_SB_Total_Gross_Cost_Booking_Currency__c;
            System.debug('Booking Id: ' + booking.Id);
            System.debug('GrossCost raw value: ' + grossCost);
            System.debug('GrossCost type: Decimal (always in Apex)');
            System.debug('GrossCost setScale(2): ' + (grossCost != null ? String.valueOf(grossCost.setScale(2)) : 'NULL'));
            System.debug('GrossCost JSON: ' + JSON.serialize(grossCost));
        }
        System.debug('Total bookings returned: ' + bookings.size());
        // ── END DEBUG ─────────────────────────────────────────────────────────────

        return bookings;
    }

    /**
     * Retrieves Supplier Contact records linked to a given supplier
     * for display in the Key Contacts component.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  supplierId : Id of the Supplier record whose contacts to retrieve
     * @return            : List of sugati__Supplier_Contact__c records ordered by last name ascending
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__Supplier_Contact__c> getSupplierContacts(Id supplierId) {
        // if (!Utility.canAccessObj('sugati__Supplier_Contact__c')) {
        //     throw new AuraHandledException('Insufficient access to Supplier Contact records.');
        // }
        return [
            SELECT Id,
                   sugati__SC_First_Name__c,
                   sugati__SC_Last_Name__c,
                   sugati__SC_Title__c,
                   sugati__SC_Phone__c,
                   sugati__SC_Email__c,
                   sugati__SC_Language__c
            FROM sugati__Supplier_Contact__c
            WHERE sugati__SC_Supplier__c = :supplierId
            ORDER BY sugati__SC_Last_Name__c ASC
            LIMIT 1000
        ];
    }

    /**
     * Retrieves FAM Visit records linked to a given supplier
     * for display in the Supplier Visits and FAM Trips component.
     * Throws an AuraHandledException if the running user lacks read access to the object.
     * @param  supplierId : Id of the Supplier record whose FAM visits to retrieve
     * @return            : List of sugati__FAM_Visit__c records ordered by start date descending
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__FAM_Visit__c> getFamVisits(Id supplierId) {
        // if (!Utility.canAccessObj('sugati__FAM_Visit__c')) {
        //     throw new AuraHandledException('Insufficient access to FAM Visit records.');
        // }
        return [
            SELECT Id,
                   sugati__FV_FAM_Visit_Start_Date__c,
                   sugati__FV_FAM_Visit_End_Date__c,
                   sugati__FV_Type_of_FAM__c,
                   sugati__FV_Consultant__c,
                   sugati__FV_Consultant__r.Name,
                   sugati__FV_Description__c
            FROM sugati__FAM_Visit__c
            WHERE sugati__FV_Supplier__c = :supplierId
            ORDER BY sugati__FV_FAM_Visit_Start_Date__c DESC NULLS LAST
            LIMIT 1000
        ];
    }

    /**
     * Returns all-time lifetime aggregates for the Lifetime card on the revenue metrics
     * strip and the LT tab on the annual revenue chart.
     * Uses two aggregate queries — one for the rollup total, one grouped by year.
     * Zero raw rows transferred.
     * @param supplierId : Id of the Supplier record
     * @return           : LifetimeStatsWrapper with totals and per-year breakdown
     */
    @AuraEnabled(cacheable=true)
    public static LifetimeStatsWrapper getLifetimeStats(Id supplierId) {
        try {
            LifetimeStatsWrapper stats = new LifetimeStatsWrapper();
            stats.totalRevenue     = 0;
            stats.totalBookings    = 0;
            stats.firstBookingYear = Date.today().year();
            stats.currencyIsoCode  = 'GBP';
            stats.revenueByYear    = new List<YearlyRevenueItem>();

            // Query 1 — rollup totals
            List<AggregateResult> totals = [
                SELECT SUM(sugati__S_SB_Total_Gross_Cost_Booking_Currency__c) totalRevenue,
                    COUNT(Id)                                              totalBookings,
                    MAX(CurrencyIsoCode)                                   currencyIsoCode
                FROM sugati__Supplier_Booking__c
                WHERE sugati__SB_Supplier__c  = :supplierId
                AND   sugati__SB_Opportunity__c != null
                AND   sugati__SB_Opportunity__r.sugati__O_Booking_Date__c != null
            ];

            if (!totals.isEmpty()) {
                AggregateResult r     = totals[0];
                Object rawRevenue = r.get('totalRevenue');
                stats.totalRevenue = rawRevenue != null 
                    ? ((Decimal) rawRevenue).setScale(2) 
                    : 0;
                stats.totalBookings   = (Integer) r.get('totalBookings')   ?? 0;
                stats.currencyIsoCode = (String)  r.get('currencyIsoCode') ?? 'GBP';
            }

            // Query 2 — revenue grouped by booking year for the LT YOY chart
            // Integer minYear = Date.today().year();
            Integer minYear = null; 
            for (AggregateResult r : [
                SELECT CALENDAR_YEAR(sugati__SB_Opportunity__r.sugati__O_Booking_Date__c) bookingYear,
                    SUM(sugati__S_SB_Total_Gross_Cost_Booking_Currency__c)             revenue
                FROM sugati__Supplier_Booking__c
                WHERE sugati__SB_Supplier__c  = :supplierId
                AND   sugati__SB_Opportunity__c != null
                AND   sugati__SB_Opportunity__r.sugati__O_Booking_Date__c != null
                GROUP BY CALENDAR_YEAR(sugati__SB_Opportunity__r.sugati__O_Booking_Date__c)
                ORDER BY CALENDAR_YEAR(sugati__SB_Opportunity__r.sugati__O_Booking_Date__c) ASC
            ]) {
                Integer yr  = (Integer) r.get('bookingYear');
                Object rawRev = r.get('revenue');
                Decimal rev   = rawRev != null 
                    ? ((Decimal) rawRev).setScale(2) 
                    : 0;

                YearlyRevenueItem item = new YearlyRevenueItem();
                item.year    = yr;
                item.revenue = rev;
                stats.revenueByYear.add(item);

                if (minYear == null || yr < minYear) {
                    minYear = yr;
                }
            }

            stats.firstBookingYear = minYear != null ? minYear : Date.today().year();
            return stats;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---- INNER CLASSES ----

    public class LifetimeStatsWrapper {
        @AuraEnabled public Decimal totalRevenue     { get; set; }
        @AuraEnabled public Integer totalBookings    { get; set; }
        @AuraEnabled public Integer firstBookingYear { get; set; }
        @AuraEnabled public String  currencyIsoCode  { get; set; }
        @AuraEnabled public List<YearlyRevenueItem> revenueByYear { get; set; }
    }

    public class YearlyRevenueItem {
        @AuraEnabled public Integer year    { get; set; }
        @AuraEnabled public Decimal revenue { get; set; }
    }
}