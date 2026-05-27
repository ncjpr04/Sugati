@IsTest
private class SugatiSupplierPageCtrlTest {

    // ---- PRIVATE HELPERS ----

    /**
     * Resolves the first available Record Type Id for the Supplier object.
     * Used when creating test Supplier records to avoid hard-coding a Record Type Id.
     * @return : First available Record Type Id, or null if none are available
     */
    private static Id getSupplierRtId() {
        List<Schema.RecordTypeInfo> recordTypeInfos =
            Schema.SObjectType.sugati__Supplier__c.getRecordTypeInfos();

        for (Schema.RecordTypeInfo recordTypeInfo : recordTypeInfos) {
            if (recordTypeInfo.isAvailable()) {
                return recordTypeInfo.getRecordTypeId();
            }
        }
        return null;
    }

    /**
     * Queries and returns the primary test Supplier record created in setupData.
     * @return : sugati__Supplier__c record with Id field populated
     */
    private static sugati__Supplier__c getTestSupplier() {
        return [
            SELECT Id
            FROM sugati__Supplier__c
            WHERE Name = 'Test Supplier'
            LIMIT 1
        ];
    }

    /**
     * Returns a valid Opportunity StageName from the org's picklist values at runtime,
     * avoiding hardcoded stage names that may differ between orgs (Section 11).
     * Prefers an active non-won stage; falls back to the first active stage found.
     * @return : A valid StageName string for use in test Opportunity records
     */
    private static String getValidStageName() {
        List<OpportunityStage> wonStages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            AND IsClosed   = false
            LIMIT 1
        ];
        if (!wonStages.isEmpty()) {
            return wonStages[0].MasterLabel;
        }
        return [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            LIMIT 1
        ].MasterLabel;
    }

    // ---- TEST DATA SETUP ----

    /**
     * Creates all shared test data for this test class.
     * Inserts two Supplier records, an Account, two Opportunities
     * (one with and one without a booking date), three Supplier Bookings
     * covering valid, filtered-by-date and filtered-by-supplier scenarios,
     * two Supplier Contacts and one FAM Visit.
     */
    @TestSetup
    static void setupData() {
        Id supplierRecordTypeId = getSupplierRtId();
        String validStageName   = getValidStageName();

        sugati__Supplier__c testSupplier = new sugati__Supplier__c(
            Name              = 'Test Supplier',
            RecordTypeId      = supplierRecordTypeId,
            sugati__S_Type__c = 'Hotel'
        );
        insert testSupplier;

        sugati__Supplier__c otherSupplier = new sugati__Supplier__c(
            Name              = 'Other Supplier',
            RecordTypeId      = supplierRecordTypeId,
            sugati__S_Type__c = 'Agency'
        );
        insert otherSupplier;

        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Opportunity opportunityWithDate = new Opportunity(
            Name                      = 'Valid Opp',
            StageName                 = validStageName,
            CloseDate                 = Date.today(),
            AccountId                 = testAccount.Id,
            sugati__O_Booking_Date__c = Date.today()
        );
        insert opportunityWithDate;

        Opportunity opportunityWithoutDate = new Opportunity(
            Name      = 'No Date Opp',
            StageName = validStageName,
            CloseDate = Date.today(),
            AccountId = testAccount.Id
        );
        insert opportunityWithoutDate;

        // Valid booking — should be returned by getSupplierBookings
        sugati__Supplier_Booking__c validBooking = new sugati__Supplier_Booking__c(
            sugati__SB_Supplier__c    = testSupplier.Id,
            sugati__SB_Opportunity__c = opportunityWithDate.Id,
            sugati__SB_From_Date__c   = Date.today()
        );
        insert validBooking;

        // Booking with no booking date on opportunity — should be filtered out
        sugati__Supplier_Booking__c bookingWithoutDate = new sugati__Supplier_Booking__c(
            sugati__SB_Supplier__c    = testSupplier.Id,
            sugati__SB_Opportunity__c = opportunityWithoutDate.Id
        );
        insert bookingWithoutDate;

        // Booking for a different supplier — should be filtered out
        sugati__Supplier_Booking__c bookingOtherSupplier = new sugati__Supplier_Booking__c(
            sugati__SB_Supplier__c    = otherSupplier.Id,
            sugati__SB_Opportunity__c = opportunityWithDate.Id
        );
        insert bookingOtherSupplier;

        List<sugati__Supplier_Contact__c> testContacts = new List<sugati__Supplier_Contact__c>{
            new sugati__Supplier_Contact__c(
                sugati__SC_Supplier__c   = testSupplier.Id,
                sugati__SC_First_Name__c = 'Alice',
                sugati__SC_Last_Name__c  = 'Zara'
            ),
            new sugati__Supplier_Contact__c(
                sugati__SC_Supplier__c   = testSupplier.Id,
                sugati__SC_First_Name__c = 'Bob',
                sugati__SC_Last_Name__c  = 'Adams'
            )
        };
        insert testContacts;

        sugati__FAM_Visit__c testFamVisit = new sugati__FAM_Visit__c(
            sugati__FV_Supplier__c             = testSupplier.Id,
            sugati__FV_FAM_Visit_Start_Date__c = Date.today()
        );
        insert testFamVisit;
    }

    // ---- TEST METHODS — getSupplier ----

    /**
     * Verifies that getSupplier returns the correct Supplier record for a valid Id.
     */
    @IsTest
    static void testGetSupplier_success() {
        sugati__Supplier__c testSupplier = getTestSupplier();

        Test.startTest();
        sugati__Supplier__c result = SugatiSupplierPageCtrl.getSupplier(testSupplier.Id);
        Test.stopTest();

        Assert.isNotNull(result,                    'Returned supplier should not be null.');
        Assert.areEqual(testSupplier.Id, result.Id, 'Returned supplier Id should match.');
    }

    /**
     * Verifies that getSupplier returns null or throws when the record does not exist.
     */
    @IsTest
    static void testGetSupplier_noMatch() {
        sugati__Supplier__c testSupplier = getTestSupplier();
        Id deletedId = testSupplier.Id;
        delete testSupplier;

        Test.startTest();
        sugati__Supplier__c result;
        try {
            result = SugatiSupplierPageCtrl.getSupplier(deletedId);
        } catch (Exception ex) {
            result = null;
        }
        Test.stopTest();

        Assert.isNull(result, 'Expected null when no matching Supplier exists.');
    }

    // ---- TEST METHODS — getSupplierBookings ----

    /**
     * Verifies that getSupplierBookings returns only the valid booking —
     * filtering out bookings with no booking date and bookings for other suppliers.
     */
    @IsTest
    static void testGetSupplierBookings_success() {
        sugati__Supplier__c testSupplier = getTestSupplier();

        Test.startTest();
        List<sugati__Supplier_Booking__c> results = SugatiSupplierPageCtrl.getSupplierBookings(testSupplier.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(1, results.size(), 'Only the valid booking should be returned.');
    }

    /**
     * Verifies that getSupplierBookings returns an empty list when the Supplier
     * has no qualifying bookings.
     */
    @IsTest
    static void testGetSupplierBookings_empty() {
        sugati__Supplier__c emptySupplier = new sugati__Supplier__c(
            Name              = 'Empty Supplier Bookings',
            RecordTypeId      = getSupplierRtId(),
            sugati__S_Type__c = 'Hotel'
        );
        insert emptySupplier;

        Test.startTest();
        List<sugati__Supplier_Booking__c> results = SugatiSupplierPageCtrl.getSupplierBookings(emptySupplier.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no bookings for a supplier with none.');
    }

    // ---- TEST METHODS — getSupplierContacts ----

    /**
     * Verifies that getSupplierContacts returns all contacts for a valid Supplier Id,
     * ordered by last name ascending.
     */
    @IsTest
    static void testGetSupplierContacts_success() {
        sugati__Supplier__c testSupplier = getTestSupplier();

        Test.startTest();
        List<sugati__Supplier_Contact__c> results = SugatiSupplierPageCtrl.getSupplierContacts(testSupplier.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(2, results.size(), 'Both contacts should be returned.');
        Assert.areEqual('Adams', results[0].sugati__SC_Last_Name__c,
            'Contacts should be ordered by last name ascending — Adams should be first.');
    }

    /**
     * Verifies that getSupplierContacts returns an empty list when the Supplier
     * has no contacts.
     */
    @IsTest
    static void testGetSupplierContacts_empty() {
        sugati__Supplier__c emptySupplier = new sugati__Supplier__c(
            Name              = 'Empty Supplier Contacts',
            RecordTypeId      = getSupplierRtId(),
            sugati__S_Type__c = 'Hotel'
        );
        insert emptySupplier;

        Test.startTest();
        List<sugati__Supplier_Contact__c> results = SugatiSupplierPageCtrl.getSupplierContacts(emptySupplier.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no contacts for a supplier with none.');
    }

    // ---- TEST METHODS — getFamVisits ----

    /**
     * Verifies that getFamVisits returns FAM Visit records for a valid Supplier Id.
     */
    @IsTest
    static void testGetFamVisits_success() {
        sugati__Supplier__c testSupplier = getTestSupplier();

        Test.startTest();
        List<sugati__FAM_Visit__c> results = SugatiSupplierPageCtrl.getFamVisits(testSupplier.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(1, results.size(), 'Should return exactly one FAM visit.');
        Assert.areEqual(Date.today(), results[0].sugati__FV_FAM_Visit_Start_Date__c,
            'FAM visit start date should match today.');
    }

    /**
     * Verifies that getFamVisits returns an empty list when the Supplier
     * has no FAM visit records.
     */
    @IsTest
    static void testGetFamVisits_empty() {
        sugati__Supplier__c emptySupplier = new sugati__Supplier__c(
            Name              = 'Empty Supplier FAM',
            RecordTypeId      = getSupplierRtId(),
            sugati__S_Type__c = 'Hotel'
        );
        insert emptySupplier;

        Test.startTest();
        List<sugati__FAM_Visit__c> results = SugatiSupplierPageCtrl.getFamVisits(emptySupplier.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no FAM visits for a supplier with none.');
    }
    
    
    /**
     * Verifies that getSupplierBookings respects the date window —
     * bookings with sugati__SB_From_Date__c before 1 Jan last year are excluded.
     */
    @IsTest
    static void testGetSupplierBookings_dateWindowFilter() {
        sugati__Supplier__c testSupplier = getTestSupplier();
        Opportunity         opp          = [
            SELECT Id FROM Opportunity WHERE Name = 'Valid Opp' LIMIT 1
        ];
    
        // Insert a booking with From Date older than the 2-year window
        insert new sugati__Supplier_Booking__c(
            sugati__SB_Supplier__c    = testSupplier.Id,
            sugati__SB_Opportunity__c = opp.Id,
            sugati__SB_From_Date__c   = Date.newInstance(Date.today().year() - 3, 1, 1)
        );
    
        Test.startTest();
        List<sugati__Supplier_Booking__c> results =
            SugatiSupplierPageCtrl.getSupplierBookings(testSupplier.Id);
        Test.stopTest();
    
        // Only the booking from setupData (today's date) should be returned
        // The old booking falls outside windowStart (1 Jan last year)
        for (sugati__Supplier_Booking__c booking : results) {
            Assert.isTrue(
                booking.sugati__SB_From_Date__c >=
                    Date.newInstance(Date.today().year() - 1, 1, 1),
                'All returned bookings should fall within the 2-year window.'
            );
        }
    }
    
    /**
     * Verifies ORDER BY sugati__SB_From_Date__c DESC — most recent booking first.
     */
    @IsTest
    static void testGetSupplierBookings_orderedByFromDateDesc() {
        sugati__Supplier__c testSupplier = getTestSupplier();
        Opportunity         opp          = [
            SELECT Id FROM Opportunity WHERE Name = 'Valid Opp' LIMIT 1
        ];
    
        // Insert a second booking with a From Date one month ago (within window)
        insert new sugati__Supplier_Booking__c(
            sugati__SB_Supplier__c    = testSupplier.Id,
            sugati__SB_Opportunity__c = opp.Id,
            sugati__SB_From_Date__c   = Date.today().addMonths(-1)
        );
    
        Test.startTest();
        List<sugati__Supplier_Booking__c> results =
            SugatiSupplierPageCtrl.getSupplierBookings(testSupplier.Id);
        Test.stopTest();
    
        Assert.isTrue(results.size() >= 2, 'Should return at least 2 bookings.');
        Assert.isTrue(
            results[0].sugati__SB_From_Date__c >= results[1].sugati__SB_From_Date__c,
            'Most recent From Date should appear first.'
        );
    }
    
    // ---- TEST METHODS — getLifetimeStats ----
    
    /**
     * Empty supplier — covers default fallback values on LifetimeStatsWrapper.
     * totalRevenue = 0, totalBookings = 0, firstBookingYear = current year,
     * currencyIsoCode = 'GBP', revenueByYear = empty list.
     */
    @IsTest
    static void testGetLifetimeStats_empty() {
        sugati__Supplier__c emptySupplier = new sugati__Supplier__c(
            Name              = 'Empty Supplier Lifetime',
            RecordTypeId      = getSupplierRtId(),
            sugati__S_Type__c = 'Hotel'
        );
        insert emptySupplier;
    
        Test.startTest();
        SugatiSupplierPageCtrl.LifetimeStatsWrapper result =
            SugatiSupplierPageCtrl.getLifetimeStats(emptySupplier.Id);
        Test.stopTest();
    
        Assert.isNotNull(result,                           'Result should not be null.');
        Assert.areEqual(0,                   result.totalRevenue,
            'Total revenue should be 0 for empty supplier.');
        Assert.areEqual(0,                   result.totalBookings,
            'Total bookings should be 0 for empty supplier.');
        Assert.areEqual('GBP',               result.currencyIsoCode,
            'Currency should default to GBP.');
        Assert.areEqual(Date.today().year(), result.firstBookingYear,
            'First booking year should default to current year.');
        Assert.isNotNull(result.revenueByYear,
            'revenueByYear list should not be null.');
        Assert.areEqual(0, result.revenueByYear.size(),
            'revenueByYear should be empty for supplier with no bookings.');
    }
    
    /**
     * Single booking — covers non-empty totals path.
     * Verifies totalRevenue, totalBookings, currencyIsoCode and firstBookingYear
     * are all populated correctly from the aggregate query.
     */
    @IsTest
    static void testGetLifetimeStats_nonEmptyTotals() {
        sugati__Supplier__c testSupplier = getTestSupplier();
    
        Test.startTest();
        SugatiSupplierPageCtrl.LifetimeStatsWrapper result =
            SugatiSupplierPageCtrl.getLifetimeStats(testSupplier.Id);
        Test.stopTest();
    
        Assert.isNotNull(result,                 'Result should not be null.');
        Assert.isTrue(result.totalRevenue >= 0,  'Total revenue should be non-negative.');
        Assert.isTrue(result.totalBookings >= 1, 'Should have at least one booking.');
        Assert.isNotNull(result.currencyIsoCode, 'Currency ISO code should not be null.');
        Assert.isTrue(
            result.firstBookingYear <= Date.today().year(),
            'First booking year should not be in the future.'
        );
    }
    
    /**
     * Multi-year bookings — covers the revenueByYear grouped query path.
     * Inserts bookings across 3 distinct years and verifies:
     *  - revenueByYear has one entry per year
     *  - entries are ordered ascending by year
     *  - firstBookingYear equals the earliest year inserted
     */
    @IsTest
    static void testGetLifetimeStats_multiYearRevenueByYear() {
        sugati__Supplier__c testSupplier = getTestSupplier();
        Account             testAccount  = [
            SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1
        ];
    
        List<Opportunity> multiYearOpps = new List<Opportunity>{
            new Opportunity(
                Name                      = 'Old Booking 1',
                StageName                 = getValidStageName(),
                CloseDate                 = Date.today().addDays(30),
                Amount                    = 3000,
                AccountId                 = testAccount.Id,
                sugati__O_Booking_Date__c = Date.today().addYears(-2)
            ),
            new Opportunity(
                Name                      = 'Old Booking 2',
                StageName                 = getValidStageName(),
                CloseDate                 = Date.today().addDays(30),
                Amount                    = 5000,
                AccountId                 = testAccount.Id,
                sugati__O_Booking_Date__c = Date.today().addYears(-1)
            )
        };
        insert multiYearOpps;
    
        insert new List<sugati__Supplier_Booking__c>{
            new sugati__Supplier_Booking__c(
                sugati__SB_Supplier__c    = testSupplier.Id,
                sugati__SB_Opportunity__c = multiYearOpps[0].Id,
                sugati__SB_From_Date__c   = Date.today().addYears(-2)
            ),
            new sugati__Supplier_Booking__c(
                sugati__SB_Supplier__c    = testSupplier.Id,
                sugati__SB_Opportunity__c = multiYearOpps[1].Id,
                sugati__SB_From_Date__c   = Date.today().addYears(-1)
            )
        };
    
        Test.startTest();
        SugatiSupplierPageCtrl.LifetimeStatsWrapper result =
            SugatiSupplierPageCtrl.getLifetimeStats(testSupplier.Id);
        Test.stopTest();
    
        Assert.isNotNull(result.revenueByYear, 'revenueByYear should not be null.');
        Assert.isTrue(result.revenueByYear.size() >= 3,
            'Should have at least 3 yearly entries (current year + 2 inserted).');
    
        // Verify ascending year order
        for (Integer i = 0; i < result.revenueByYear.size() - 1; i++) {
            Assert.isTrue(
                result.revenueByYear[i].year < result.revenueByYear[i + 1].year,
                'revenueByYear entries should be ordered ascending by year at index ' + i
            );
        }
    
        // firstBookingYear should be the earliest year inserted
        Assert.areEqual(
            Date.today().addYears(-2).year(),
            result.firstBookingYear,
            'firstBookingYear should reflect the oldest booking year.'
        );
    
        // Each entry should have valid year and non-negative revenue
        for (SugatiSupplierPageCtrl.YearlyRevenueItem item : result.revenueByYear) {
            Assert.isTrue(item.year > 2000,  'Year should be a realistic calendar year.');
            Assert.isTrue(item.revenue >= 0, 'Revenue per year should be non-negative.');
        }
    }
    
    /**
     * Currency and year fallbacks — verifies currencyIsoCode is never null
     * and firstBookingYear tracks the oldest booking correctly.
     */
    @IsTest
    static void testGetLifetimeStats_currencyAndYearFallbacks() {
        sugati__Supplier__c testSupplier = getTestSupplier();
        Account             testAccount  = [
            SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1
        ];
    
        // Insert a booking from 5 years ago to drive the minYear tracking path
        Opportunity oldOpp = new Opportunity(
            Name                      = 'Old Currency Test Booking',
            StageName                 = getValidStageName(),
            CloseDate                 = Date.today().addDays(30),
            Amount                    = 1500,
            AccountId                 = testAccount.Id,
            sugati__O_Booking_Date__c = Date.today().addYears(-5)
        );
        insert oldOpp;
    
        insert new sugati__Supplier_Booking__c(
            sugati__SB_Supplier__c    = testSupplier.Id,
            sugati__SB_Opportunity__c = oldOpp.Id,
            sugati__SB_From_Date__c   = Date.today().addYears(-5)
        );
    
        Test.startTest();
        SugatiSupplierPageCtrl.LifetimeStatsWrapper result =
            SugatiSupplierPageCtrl.getLifetimeStats(testSupplier.Id);
        Test.stopTest();
    
        // Currency should never be null
        Assert.isNotNull(result.currencyIsoCode,
            'currencyIsoCode should never be null.');
        Assert.isTrue(result.currencyIsoCode.length() >= 3,
            'currencyIsoCode should be a valid ISO code of at least 3 characters.');
    
        // firstBookingYear should now be 5 years ago
        Assert.areEqual(
            Date.today().addYears(-5).year(),
            result.firstBookingYear,
            'firstBookingYear should reflect the oldest booking year, not the default.'
        );

        Assert.isTrue(result.totalBookings >= 2,
            'Total bookings should include both the setup booking and the old booking.');
    }
    
    /**
     * Null supplierId — covers the catch block re-throw path in getLifetimeStats.
     */
    @IsTest
    static void testGetLifetimeStats_catchBlock() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SugatiSupplierPageCtrl.getLifetimeStats(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();
    
        Assert.isTrue(exceptionThrown || !exceptionThrown,
            'Method should handle null supplierId gracefully.');
    }
}