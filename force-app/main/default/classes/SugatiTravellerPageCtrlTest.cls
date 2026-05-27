@IsTest
private class SugatiTravellerPageCtrlTest {

    // ---- PRIVATE HELPERS ----

    /**
     * Queries and returns the primary test Account record created in makeData.
     * @return : Account record with Id field populated
     */
    private static Account getTestAccount() {
        return [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Traveller Account'
            LIMIT 1
        ];
    }

    /**
     * Returns a valid Opportunity StageName from the org's picklist values at runtime,
     * avoiding hardcoded stage names that may differ between orgs (Section 11).
     * Prefers 'Closed Won' if available, otherwise returns the first active stage found.
     * @return : A valid StageName string for use in test Opportunity records
     */
    private static String getValidStageName() {
        List<OpportunityStage> stages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            AND IsClosed = true
            AND IsWon = true
            LIMIT 1
        ];
        if (!stages.isEmpty()) {
            return stages[0].MasterLabel;
        }
        return [SELECT MasterLabel FROM OpportunityStage WHERE IsActive = true LIMIT 1].MasterLabel;
    }

    /**
     * Creates and inserts an empty Account with no related records.
     * Used across empty/negative scenario tests.
     * @param  accountName : Name to assign to the empty Account
     * @return             : Inserted Account record
     */
    private static Account createEmptyAccount(String accountName) {
        Account emptyAccount = new Account(Name = accountName);
        insert emptyAccount;
        return emptyAccount;
    }

    // ---- TEST DATA SETUP ----

    /**
     * Creates all shared test data for this test class.
     * Inserts an Account, Contact, Opportunity, two Tasks (one on Account,
     * one on Opportunity), an Accommodation Supplier Booking and a Credit Memo.
     */
    @TestSetup
    static void makeData() {
        Account testAccount = new Account(
            Name                    = 'Test Traveller Account',
            sugati__A_First_Name__c = 'John',
            sugati__A_Last_Name__c  = 'Doe',
            sugati__A_Email__c      = 'john.doe@test.com',
            Phone                   = '+44 7000 000000',
            BillingCity             = 'London',
            BillingCountry          = 'United Kingdom',
            Description             = 'Test account description',
            Rating                  = 'Hot',
            Active__c               = 'Yes'
        );
        insert testAccount;

        Contact testContact = new Contact(
            AccountId                    = testAccount.Id,
            FirstName                    = 'Jane',
            LastName                     = 'Doe',
            Birthdate                    = Date.newInstance(1990, 6, 15),
            sugati__C_Nationality__c     = 'British',
            sugati__C_Passport_Number__c = 'AB123456',
            sugati__C_Expires_Date__c    = Date.newInstance(2030, 6, 15),
            sugati__Occupancy_Type__c    = 'Adult',
            sugati__C_Lead_Passenger__c  = true,
            LeadSource                   = 'Web'
        );
        insert testContact;

        Opportunity testOpportunity = new Opportunity(
            AccountId                 = testAccount.Id,
            Name                     = 'Test Booking',
            StageName                = getValidStageName(),
            CloseDate                = Date.today().addDays(30),
            Amount                   = 5000,
            Probability              = 100,
            sugati__O_Booking_Date__c = Date.today(),
            sugati__O_Country__c     = 'France',
            sugati__O_Status__c      = 'Guaranteed'
        );
        insert testOpportunity;

        insert new Task(
            Subject      = 'Follow Up Call',
            WhatId       = testAccount.Id,
            ActivityDate = Date.today(),
            Description  = 'Call the traveller'
        );

        insert new Task(
            Subject      = 'Send Itinerary',
            WhatId       = testOpportunity.Id,
            ActivityDate = Date.today().addDays(1)
        );

        Id accommodationRecordTypeId = Schema.SObjectType.sugati__Supplier_Booking__c
            .getRecordTypeInfosByDeveloperName()
            .get('Accommodation')
            .getRecordTypeId();

        insert new sugati__Supplier_Booking__c(
            RecordTypeId              = accommodationRecordTypeId,
            sugati__SB_Opportunity__c = testOpportunity.Id
        );

        insert new sugati__Credit_Memo__c(
            sugati__CM_Account__c             = testAccount.Id,
            sugati__CM_Opportunity__c         = testOpportunity.Id,
            sugati__CM_Amount__c              = 500,
            sugati__CM_Credit_Memo_Date__c    = Date.today(),
            sugati__CM_Is_Expired__c          = false,
            sugati__O_Credit_Expiry_Date_c__c = Date.today().addDays(365)
        );
    }

    // ---- TEST METHODS — getAccount ----

    /**
     * Verifies that getAccount returns the correct Account record for a valid Id,
     * including all key display fields.
     */
    @IsTest
    static void testGetAccount_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        Account result = SugatiTravellerPageCtrl.getAccount(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(result,                              'Returned account should not be null.');
        Assert.areEqual(testAccount.Id,   result.Id,         'Account Id should match.');
        Assert.areEqual('John',           result.sugati__A_First_Name__c, 'First name should match.');
        Assert.areEqual('Doe',            result.sugati__A_Last_Name__c,  'Last name should match.');
        Assert.areEqual('London',         result.BillingCity,             'Billing city should match.');
        Assert.areEqual('United Kingdom', result.BillingCountry,          'Billing country should match.');
    }

    /**
     * Verifies that getAccount returns null or throws when the record does not exist.
     */
    @IsTest
    static void testGetAccount_noMatch() {
        Account testAccount = getTestAccount();
        Id deletedId = testAccount.Id;

        // Delete linked Opportunities first — Salesforce prevents deleting an Account
        // that has Closed Won Opportunities associated with it.
        delete [SELECT Id FROM Opportunity WHERE AccountId = :deletedId];
        delete testAccount;

        Test.startTest();
        Account result;
        try {
            result = SugatiTravellerPageCtrl.getAccount(deletedId);
        } catch (Exception ex) {
            result = null;
        }
        Test.stopTest();

        Assert.isNull(result, 'Expected null when no matching Account exists.');
    }

    // ---- TEST METHODS — getOpportunities ----

    /**
     * Verifies that getOpportunities returns the correct Opportunity records
     * for a valid Account Id, including key field values.
     */
    @IsTest
    static void testGetOpportunities_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        List<Opportunity> results = SugatiTravellerPageCtrl.getOpportunities(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(1, results.size(), 'Should return exactly one Opportunity.');
        Assert.areEqual('Test Booking',                                        results[0].Name,                'Opportunity name should match.');
        Assert.areEqual(getValidStageName(),  results[0].StageName,        'Stage name should match.');
        Assert.areEqual('Guaranteed',                                          results[0].sugati__O_Status__c, 'Status should match.');
        Assert.areEqual('France',                                              results[0].sugati__O_Country__c,'Country should match.');
    }

    /**
     * Verifies that getOpportunities returns an empty list when the Account
     * has no Opportunity records.
     */
    @IsTest
    static void testGetOpportunities_empty() {
        Account emptyAccount = createEmptyAccount('Empty Traveller Opportunities');

        Test.startTest();
        List<Opportunity> results = SugatiTravellerPageCtrl.getOpportunities(emptyAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Opportunities for an Account with none.');
    }

    // ---- TEST METHODS — getTasks ----

    /**
     * Verifies that getTasks returns Task records linked directly to the Account.
     */
    @IsTest
    static void testGetTasks_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        List<Task> results = SugatiTravellerPageCtrl.getTasks(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,                  'Result list should not be null.');
        Assert.isTrue(results.size() >= 1,         'Should return at least one Task.');
        Assert.areEqual('Follow Up Call', results[0].Subject, 'First task subject should match.');
    }

    /**
     * Verifies that getTasks returns an empty list when the Account has no tasks.
     */
    @IsTest
    static void testGetTasks_empty() {
        Account emptyAccount = createEmptyAccount('Empty Traveller Tasks');

        Test.startTest();
        List<Task> results = SugatiTravellerPageCtrl.getTasks(emptyAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Tasks for an Account with none.');
    }

    // ---- TEST METHODS — getContacts ----

    /**
     * Verifies that getContacts returns Contact records linked to the Account,
     * including all key passenger detail fields.
     */
    @IsTest
    static void testGetContacts_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        List<Contact> results = SugatiTravellerPageCtrl.getContacts(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(1, results.size(), 'Should return exactly one Contact.');
        Assert.areEqual('Jane',     results[0].FirstName,                    'First name should match.');
        Assert.areEqual('Doe',      results[0].LastName,                     'Last name should match.');
        Assert.areEqual('British',  results[0].sugati__C_Nationality__c,     'Nationality should match.');
        Assert.areEqual('AB123456', results[0].sugati__C_Passport_Number__c, 'Passport number should match.');
        Assert.areEqual('Adult',    results[0].sugati__Occupancy_Type__c,    'Occupancy type should match.');
        Assert.areEqual(true,       results[0].sugati__C_Lead_Passenger__c,  'Lead passenger flag should match.');
    }

    /**
     * Verifies that getContacts returns an empty list when the Account has no contacts.
     */
    @IsTest
    static void testGetContacts_empty() {
        Account emptyAccount = createEmptyAccount('Empty Traveller Contacts');

        Test.startTest();
        List<Contact> results = SugatiTravellerPageCtrl.getContacts(emptyAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Contacts for an Account with none.');
    }

    // ---- TEST METHODS — getTravellingCountries ----

    /**
     * Verifies that getTravellingCountries returns a non-null list for a valid Account Id.
     * No travelling countries are inserted in makeData so an empty list is the expected result.
     */
    @IsTest
    static void testGetTravellingCountries_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        List<sugati__Travelling_Country__c> results = SugatiTravellerPageCtrl.getTravellingCountries(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results, 'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Travelling Country records as none were inserted.');
    }

    /**
     * Verifies that getTravellingCountries returns an empty list when the Account
     * has no linked travelling countries.
     */
    @IsTest
    static void testGetTravellingCountries_empty() {
        Account emptyAccount = createEmptyAccount('Empty Traveller Countries');

        Test.startTest();
        List<sugati__Travelling_Country__c> results = SugatiTravellerPageCtrl.getTravellingCountries(emptyAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Travelling Countries for an Account with none.');
    }

    // ---- TEST METHODS — getSupplierBookings ----

    /**
     * Verifies that getSupplierBookings returns only Accommodation record type bookings
     * linked to Opportunities on the Account.
     */
    @IsTest
    static void testGetSupplierBookings_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        List<sugati__Supplier_Booking__c> results = SugatiTravellerPageCtrl.getSupplierBookings(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(1, results.size(), 'Should return exactly one Supplier Booking.');
        Assert.areEqual('Accommodation', results[0].RecordType.DeveloperName,
            'Returned booking should have the Accommodation record type.');
    }

    /**
     * Verifies that getSupplierBookings returns an empty list when the Account
     * has no accommodation bookings.
     */
    @IsTest
    static void testGetSupplierBookings_empty() {
        Account emptyAccount = createEmptyAccount('Empty Traveller Bookings');

        Test.startTest();
        List<sugati__Supplier_Booking__c> results = SugatiTravellerPageCtrl.getSupplierBookings(emptyAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Supplier Bookings for an Account with none.');
    }

    // ---- TEST METHODS — getOpportunityTasks ----

    /**
     * Verifies that getOpportunityTasks returns Task records linked to Opportunities
     * on the Account.
     */
    @IsTest
    static void testGetOpportunityTasks_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        List<Task> results = SugatiTravellerPageCtrl.getOpportunityTasks(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(1, results.size(), 'Should return exactly one Opportunity Task.');
        Assert.areEqual('Send Itinerary', results[0].Subject, 'Task subject should match.');
    }

    /**
     * Verifies that getOpportunityTasks returns an empty list when the Account's
     * Opportunities have no tasks.
     */
    @IsTest
    static void testGetOpportunityTasks_empty() {
        Account emptyAccount = createEmptyAccount('Empty Traveller Opportunity Tasks');

        Test.startTest();
        List<Task> results = SugatiTravellerPageCtrl.getOpportunityTasks(emptyAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Opportunity Tasks for an Account with none.');
    }

    // ---- TEST METHODS — getCreditMemos ----

    /**
     * Verifies that getCreditMemos returns Credit Memo records for a valid Account Id,
     * including all key amount and expiry fields.
     */
    @IsTest
    static void testGetCreditMemos_success() {
        Account testAccount = getTestAccount();

        Test.startTest();
        List<sugati__Credit_Memo__c> results = SugatiTravellerPageCtrl.getCreditMemos(testAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(1, results.size(), 'Should return exactly one Credit Memo.');
        Assert.areEqual(500,   results[0].sugati__CM_Amount__c,              'Amount should match.');
        Assert.areEqual(false, results[0].sugati__CM_Is_Expired__c,          'Expiry flag should be false.');
        Assert.areEqual(
            Date.today().addDays(365),
            results[0].sugati__O_Credit_Expiry_Date_c__c,
            'Expiry date should match.'
        );
    }

    /**
     * Verifies that getCreditMemos returns an empty list when the Account
     * has no credit memo records.
     */
    @IsTest
    static void testGetCreditMemos_empty() {
        Account emptyAccount = createEmptyAccount('Empty Traveller Credit Memos');

        Test.startTest();
        List<sugati__Credit_Memo__c> results = SugatiTravellerPageCtrl.getCreditMemos(emptyAccount.Id);
        Test.stopTest();

        Assert.isNotNull(results,          'Result list should not be null.');
        Assert.areEqual(0, results.size(), 'Expected no Credit Memos for an Account with none.');
    }
}