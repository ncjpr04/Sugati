@IsTest
private class SugatiLegacyEmailServiceTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Send Email Test Opp',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Contact c1 = new Contact(
            FirstName = 'Lead',
            LastName = 'Booker',
            Email = 'lead@example.com',
            AccountId = acc.Id
        );
        insert c1;

        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        if (g.containsKey('sugati__Client_Group__c') && g.containsKey('sugati__Group_Member__c')) {
            SObject clientGroup = g.get('sugati__Client_Group__c').newSObject();
            clientGroup.put('sugati__CG_Opportunity__c', opp.Id);
            insert clientGroup;

            SObject gm = g.get('sugati__Group_Member__c').newSObject();
            gm.put('sugati__GM_Opportunity__c', opp.Id);
            gm.put('sugati__GM_Contact__c', c1.Id);
            gm.put('sugati__GM_Client_Group__c', clientGroup.get('Id'));
            gm.put('sugati__GM_Lead_Passenger__c', true);
            insert gm;

            clientGroup.put('sugati__CG_Lead_Group_Member__c', gm.get('Id'));
            update clientGroup;
            opp.put('sugati__O_Lead_CG__c', clientGroup.get('Id'));
            update opp;
        }
    }

    @IsTest
    static void testCatalogAndDefaultLoad() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        SugatiLegacyEmailService.LegacyTemplateCatalogDTO catalog =
            SugatiLegacyEmailService.getSendEmailTemplateCatalog(opp.Id);
        SugatiLegacyEmailService.LegacyEmailLoadDTO loaded =
            SugatiLegacyEmailService.loadDefaultSendEmailTemplate(opp.Id);
        List<SugatiLegacyEmailService.EmailAddressOptionDTO> book =
            SugatiLegacyEmailService.getEmailAddressBook(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, catalog);
        System.assertNotEquals(null, catalog.opportunityStageOrder);
        System.assert(!catalog.opportunityStageOrder.isEmpty(), 'Expected opportunity stage sort order');
        System.assertNotEquals(null, catalog.relatedRecords);
        System.assert(!catalog.relatedRecords.isEmpty(), 'Expected related record options');
        System.assertNotEquals(null, loaded);
        System.assertNotEquals(null, loaded.bodyHtml);
        System.assertNotEquals(null, book);
    }

    @IsTest
    static void testResolveSalesforceEmailTemplateCandidates() {
        List<String> candidates = SugatiLegacyEmailService.buildTemplateNameCandidatesForTest('Send Email');
        System.assert(candidates.contains('SendEmail'), 'Expected SendEmail alias');
    }

    @IsTest
    static void testResolveLeadContact() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id contactId = SugatiLegacyEmailService.resolveLeadContactIdForSend(opp.Id);
        System.assertNotEquals(null, contactId, 'Expected lead contact when group member exists');
    }

    @IsTest
    static void testTemplateVisibilityByStageAndUser() {
        Id currentUserId = UserInfo.getUserId();
        System.assertEquals(
            true,
            SugatiLegacyEmailService.templateVisibleForSendContextForTest(null, null, 'Booked', currentUserId),
            'Blank stage and user should be visible to everyone'
        );
        System.assertEquals(
            true,
            SugatiLegacyEmailService.templateVisibleForSendContextForTest(null, 'Booked', 'Booked', currentUserId),
            'Matching stage should be visible'
        );
        System.assertEquals(
            false,
            SugatiLegacyEmailService.templateVisibleForSendContextForTest(null, 'Booked', 'Enquiry', currentUserId),
            'Mismatched stage should be hidden'
        );
        System.assertEquals(
            false,
            SugatiLegacyEmailService.templateVisibleForSendContextForTest(
                Id.valueOf('005000000000001AAA'),
                null,
                'Booked',
                currentUserId
            ),
            'Other user assignment should be hidden'
        );
        System.assertEquals(
            true,
            SugatiLegacyEmailService.templateVisibleForSendContextForTest(currentUserId, null, 'Booked', currentUserId),
            'Assigned user should see their template'
        );
    }
}
