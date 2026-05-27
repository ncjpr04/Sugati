/**
 * Controller class for the Sugati Agency Page LWC components.
 * Provides data retrieval methods for supplier, contacts, bookings,
 * recent activity, FAM visits and top destinations.
 */
public with sharing class SugatiAgencyPageCtrl {

    // ---- PUBLIC METHODS ----

    /**
     * Retrieves a single Supplier record by Id with all fields
     * required by the Agency page header and detail components.
     * @param supplierId : Id of the Supplier record to retrieve
     * @return           : Supplier sObject with all required fields, or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static sugati__Supplier__c getSupplier(Id supplierId) {
        try {
            // if (!Utility.canAccessObj('sugati__Supplier__c')) {
            //     throw new AuraHandledException(
            //         'Insufficient access to Supplier object.'
            //     );
            // }

            return [
                SELECT Id,
                       Name,
                       Owner.Name,
                       CreatedDate,
                       sugati__S_Website__c,
                       sugati__S_City__c,
                       sugati__S1_Country__c,
                       sugati__S_Street__c,
                       sugati__S_Postcode__c,
                       sugati__S_Rating__c,
                       sugati__S_Description__c,
                       sugati__S_Type__c,
                       sugati__S_Emergency_Phone__c,
                       sugati__S_ABTA_Number__c,
                       sugati__ATOL_Number__c,
                       sugati__S_Commission__c,
                       sugati__S_Total_Commission_Value__c,
                       sugati__S_Total_Bed_Nights__c
                FROM sugati__Supplier__c
                WHERE Id = :supplierId
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Retrieves all Supplier Contact records for a given Supplier,
     * ordered alphabetically by last name.
     * @param supplierId : Id of the parent Supplier record
     * @return           : List of Supplier Contact sObjects
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__Supplier_Contact__c> getSupplierContacts(Id supplierId) {
        try {
            // if (!Utility.canAccessObj('sugati__Supplier_Contact__c')) {
            //     throw new AuraHandledException(
            //         'Insufficient access to Supplier Contact object.'
            //     );
            // }

            return [
                SELECT Id,
                       sugati__SC_First_Name__c,
                       sugati__SC_Last_Name__c,
                       sugati__SC_Title__c,
                       sugati__SC_Email__c,
                       sugati__SC_Name__c
                FROM sugati__Supplier_Contact__c
                WHERE sugati__SC_Supplier__c = :supplierId
                ORDER BY sugati__SC_Last_Name__c ASC NULLS LAST
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

   /**
     * Retrieves Supplier Booking records for the current and prior calendar year
     * for a given Supplier. Scoped to sugati__SB_From_Date__c >= 1 Jan last year
     * to keep the query selective on a direct indexed field.
     * Hard-capped at 5000 rows as a governor safety net.
     * @param supplierId : Id of the parent Supplier record
     * @return           : List of Supplier Booking sObjects ordered by From Date descending
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__Supplier_Booking__c> getSupplierBookings(Id supplierId) {
        try {
            // if (!Utility.canAccessObj('sugati__Supplier_Booking__c')) {
            //     throw new AuraHandledException(
            //         'Insufficient access to Supplier Booking object.'
            //     );
            // }
            Date windowStart = Date.newInstance(Date.today().year() - 1, 1, 1); // 1 Jan last year

            return [
                SELECT Id,
                       CurrencyIsoCode,
                       sugati__SB_Opportunity__c,
                       sugati__SB_Opportunity__r.Name,
                       sugati__SB_Opportunity__r.Amount,
                       sugati__SB_Opportunity__r.sugati__O_No_of_Nights__c,
                       sugati__SB_Opportunity__r.sugati__O_Booking_Date__c,
                       sugati__SB_Opportunity__r.sugati__O_Agent_SC__c,
                       sugati__SB_Opportunity__r.sugati__O_Agent_SC__r.sugati__SC_First_Name__c,
                       sugati__SB_Opportunity__r.sugati__O_Agent_SC__r.sugati__SC_Last_Name__c,
                       sugati__SB_Opportunity__r.sugati__O_Agent_SC__r.sugati__SC_Title__c,
                       sugati__SB_Opportunity__r.sugati__Agent_Name__c,
                       sugati__S_SB_Total_Gross_Cost_Booking_Currency__c,
                       sugati__SB_Night__c,
                       sugati__SB_Room_Type__c,
                       sugati__SB_Total_Agent_Commission__c,
                       sugati__SB_From_Date__c,
                       sugati__SB_To_Place__c,
                       sugati__SB_Opportunity__r.sugati__O_Destination__c
                FROM sugati__Supplier_Booking__c
                WHERE sugati__SB_Supplier__c = :supplierId
                AND sugati__SB_From_Date__c >= :windowStart
                ORDER BY sugati__SB_From_Date__c DESC NULLS LAST
                LIMIT 5000
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    /**
     * Returns all-time lifetime aggregates for the Lifetime card on the stat strip
     * and the LT tab on the annual performance chart.
     * Uses two aggregate queries — one for the rollup total, one grouped by year.
     * Zero raw rows transferred.
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
                WHERE sugati__SB_Supplier__c = :supplierId
                AND sugati__SB_Opportunity__c != null
                AND sugati__SB_Opportunity__r.sugati__O_Booking_Date__c != null
            ];

            if (!totals.isEmpty()) {
                AggregateResult r    = totals[0];
                stats.totalRevenue   = (Decimal) r.get('totalRevenue')   ?? 0;
                stats.totalBookings  = (Integer) r.get('totalBookings')  ?? 0;
                stats.currencyIsoCode = (String) r.get('currencyIsoCode') ?? 'GBP';
            }

            // Query 2 — revenue grouped by booking year for the LT YOY chart
            Integer minYear = Date.today().year();

            for (AggregateResult r : [
                SELECT CALENDAR_YEAR(sugati__SB_Opportunity__r.sugati__O_Booking_Date__c) bookingYear,
                    SUM(sugati__S_SB_Total_Gross_Cost_Booking_Currency__c)             revenue
                FROM sugati__Supplier_Booking__c
                WHERE sugati__SB_Supplier__c = :supplierId
                AND sugati__SB_Opportunity__c != null
                AND sugati__SB_Opportunity__r.sugati__O_Booking_Date__c != null
                GROUP BY CALENDAR_YEAR(sugati__SB_Opportunity__r.sugati__O_Booking_Date__c)
                ORDER BY CALENDAR_YEAR(sugati__SB_Opportunity__r.sugati__O_Booking_Date__c) ASC
            ]) {
                Integer yr  = (Integer) r.get('bookingYear');
                Decimal rev = (Decimal) r.get('revenue') ?? 0;

                YearlyRevenueItem item = new YearlyRevenueItem();
                item.year    = yr;
                item.revenue = rev;
                stats.revenueByYear.add(item);

                if (yr < minYear) {
                    minYear = yr;
                }
            }

            stats.firstBookingYear = minYear;
            return stats;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Retrieves the 10 most recent Task records logged against a Supplier,
     * ordered by Activity Date descending.
     * @param supplierId : Id of the Supplier record (WhatId on Task)
     * @return           : List of Task sObjects, max 10 records
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getRecentActivity(Id supplierId) {
        try {
            // if (!Utility.canAccessObj('Task')) {
            //     throw new AuraHandledException(
            //         'Insufficient access to Task object.'
            //     );
            // }

            return [
                SELECT Id,
                       Subject,
                       ActivityDate,
                       sugati__Type__c,
                       Description,
                       TaskSubtype
                FROM Task
                WHERE WhatId = :supplierId
                ORDER BY ActivityDate DESC NULLS LAST
                LIMIT 10
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Retrieves all FAM Visit records for a given Supplier,
     * ordered by visit start date descending.
     * @param supplierId : Id of the parent Supplier record
     * @return           : List of FAM Visit sObjects
     */
    @AuraEnabled(cacheable=true)
    public static List<sugati__FAM_Visit__c> getFamVisits(Id supplierId) {
        try {
            // if (!Utility.canAccessObj('sugati__FAM_Visit__c')) {
            //     throw new AuraHandledException(
            //         'Insufficient access to FAM Visit object.'
            //     );
            // }

            return [
                SELECT Id,
                       sugati__FV_FAM_Visit_Start_Date__c,
                       sugati__FV_FAM_Visit_End_Date__c,
                       sugati__FV_Type_of_FAM__c,
                       sugati__FV_Consultant__c,
                       sugati__FV_Consultant__r.Name,
                       sugati__FV_Description__c,
                       sugati__FV_Supplier__r.sugati__S_City__c

                FROM sugati__FAM_Visit__c
                WHERE sugati__FV_Supplier__c = :supplierId
                ORDER BY sugati__FV_FAM_Visit_Start_Date__c DESC NULLS LAST
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Returns the top 10 travel destinations for a given Supplier
     * based on Supplier Bookings in the current calendar year.
     *
     * Approach:
     *  - Query 1: Aggregate SOQL grouped by Opportunity — eliminates the
     *    manual dedupe loop entirely. Scoped to sugati__SB_From_Date__c
     *    (direct indexed field) rather than a cross-object booking date.
     *    Capped at 1000 aggregate groups (i.e. unique Opportunities).
     *  - Query 2: Travelling Countries for those Opportunities — unchanged.
     *  - Accumulation: same full-value-per-country logic as before.
     *  - Sort: List.sort() via Comparable — replaces O(n²) bubble sort.
     *
     * @param supplierId : Id of the parent Supplier record
     * @return           : List of up to 10 DestinationItem wrappers, revenue descending
     */
    @AuraEnabled(cacheable=true)
    public static List<DestinationItem> getTopDestinations(Id supplierId) {
        try {
            // Year window on the direct field — indexable, no cross-object scan
            Date yearStart = Date.newInstance(Date.today().year(), 1, 1);
            Date yearEnd   = Date.newInstance(Date.today().year(), 12, 31);

            // ── QUERY 1 ───────────────────────────────────────────────────────────
            // Aggregate by Opportunity — one row per unique Opp, no manual dedupe needed.
            // MAX(Amount) and MAX(nights) are safe here because Amount and nights are
            // fixed on the Opportunity; every Supplier Booking row for the same Opp
            // carries the same value, so MAX == the actual value.
            Map<Id, Decimal> revenueByOppId = new Map<Id, Decimal>();
            Map<Id, Decimal> nightsByOppId  = new Map<Id, Decimal>();

            for (AggregateResult ar : [
                SELECT sugati__SB_Opportunity__c                              oppId,
                    MAX(sugati__SB_Opportunity__r.Amount)                  oppRevenue,
                    MAX(sugati__SB_Opportunity__r.sugati__O_No_of_Nights__c) oppNights
                FROM   sugati__Supplier_Booking__c
                WHERE  sugati__SB_Supplier__c     =  :supplierId
                AND    sugati__SB_Opportunity__c  != null
                AND    sugati__SB_Opportunity__r.sugati__O_Booking_Date__c >= :yearStart
                AND    sugati__SB_Opportunity__r.sugati__O_Booking_Date__c <= :yearEnd
                GROUP  BY sugati__SB_Opportunity__c
                LIMIT  1000
            ]) {
                Id      oppId   = (Id)      ar.get('oppId');
                Decimal revenue = (Decimal) ar.get('oppRevenue') ?? 0;
                Decimal nights  = (Decimal) ar.get('oppNights')  ?? 0;
                revenueByOppId.put(oppId, revenue);
                nightsByOppId.put(oppId, nights);
            }

            if (revenueByOppId.isEmpty()) {
                return new List<DestinationItem>();
            }

            Set<Id> uniqueOppIds = revenueByOppId.keySet();

            // ── QUERY 2 ───────────────────────────────────────────────────────────
            // Travelling Countries for those Opportunities — unchanged from before.
            Map<Id, Set<String>> countryNamesByOppId = new Map<Id, Set<String>>();

            for (sugati__Travelling_Country__c tc : [
                SELECT sugati__TC_Opportunity__c,
                    sugati__TC_Country__r.Name
                FROM   sugati__Travelling_Country__c
                WHERE  sugati__TC_Opportunity__c IN :uniqueOppIds
                AND    sugati__TC_Country__c     != null
            ]) {
                String countryName = tc.sugati__TC_Country__r?.Name;
                if (String.isBlank(countryName)) continue;

                Id oppId = tc.sugati__TC_Opportunity__c;
                if (!countryNamesByOppId.containsKey(oppId)) {
                    countryNamesByOppId.put(oppId, new Set<String>());
                }
                countryNamesByOppId.get(oppId).add(countryName); // Set prevents duplicate countries per Opp
            }

            // ── ACCUMULATE ────────────────────────────────────────────────────────
            Map<String, DestinationItem> destinationsByCountry = new Map<String, DestinationItem>();

            for (Id oppId : countryNamesByOppId.keySet()) {
                Decimal oppRevenue = revenueByOppId.get(oppId) ?? 0;
                Decimal oppNights  = nightsByOppId.get(oppId)  ?? 0;

                for (String countryName : countryNamesByOppId.get(oppId)) {
                    if (!destinationsByCountry.containsKey(countryName)) {
                        DestinationItem item = new DestinationItem();
                        item.country      = countryName;
                        item.bookingCount = 0;
                        item.totalNights  = 0;
                        item.totalRevenue = 0;
                        destinationsByCountry.put(countryName, item);
                    }
                    DestinationItem item = destinationsByCountry.get(countryName);
                    item.bookingCount++;
                    item.totalNights  += oppNights;
                    item.totalRevenue += oppRevenue;
                }
            }

            // ── SORT + TRIM ───────────────────────────────────────────────────────
            List<DestinationItem> sorted = destinationsByCountry.values();
            sorted.sort(); // Comparable.compareTo handles revenue descending

            List<DestinationItem> topDestinations = new List<DestinationItem>();
            for (Integer i = 0; i < Math.min(10, sorted.size()); i++) {
                topDestinations.add(sorted[i]);
            }
            return topDestinations;


        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    // ---- INNER CLASSES ----

    /**
     * Wrapper class representing aggregated booking data for a single
     * travel destination. Used by the Top Destinations LWC component.
     */
    public class DestinationItem implements Comparable {
        @AuraEnabled public String  country      { get; set; }
        @AuraEnabled public Integer bookingCount { get; set; }
        @AuraEnabled public Decimal totalNights  { get; set; }
        @AuraEnabled public Decimal totalRevenue { get; set; }

        /**
         * Compares this DestinationItem to another by totalRevenue descending.
         * Returns negative if this > other (sorts this first),
         * positive if this < other, zero if equal.
         */
        public Integer compareTo(Object other) {
            DestinationItem otherItem = (DestinationItem) other;
            if (this.totalRevenue > otherItem.totalRevenue) return -1;
            if (this.totalRevenue < otherItem.totalRevenue) return  1;
            return 0;
        }
    }


    /**
     * Wrapper for all-time lifetime aggregate — used by StatStrip (lifetime card)
     * and AnnualPerformance (LT tab YOY bars).
     */
    public class LifetimeStatsWrapper {
        @AuraEnabled public Decimal totalRevenue    { get; set; }
        @AuraEnabled public Integer totalBookings   { get; set; }
        @AuraEnabled public Integer firstBookingYear { get; set; }
        @AuraEnabled public String  currencyIsoCode  { get; set; }
        /** One entry per year: { year, revenue } — for the LT YOY chart */
        @AuraEnabled public List<YearlyRevenueItem> revenueByYear { get; set; }
    }

    public class YearlyRevenueItem {
        @AuraEnabled public Integer year    { get; set; }
        @AuraEnabled public Decimal revenue { get; set; }
    }
}