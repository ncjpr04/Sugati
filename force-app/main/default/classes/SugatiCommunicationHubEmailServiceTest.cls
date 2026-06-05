@IsTest
private class SugatiCommunicationHubEmailServiceTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Comm Hub Email Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Comm Hub Email Test Opp',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Contact lead = new Contact(
            FirstName = 'Lead',
            LastName = 'Booker',
            Email = 'lead@example.com',
            AccountId = acc.Id
        );
        insert lead;

        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        if (g.containsKey('sugati__Client_Group__c') && g.containsKey('sugati__Group_Member__c')) {
            SObject clientGroup = g.get('sugati__Client_Group__c').newSObject();
            clientGroup.put('sugati__CG_Opportunity__c', opp.Id);
            insert clientGroup;

            SObject leadGm = g.get('sugati__Group_Member__c').newSObject();
            leadGm.put('sugati__GM_Opportunity__c', opp.Id);
            leadGm.put('sugati__GM_Contact__c', lead.Id);
            leadGm.put('sugati__GM_Client_Group__c', clientGroup.get('Id'));
            leadGm.put('sugati__GM_Lead_Passenger__c', true);
            insert leadGm;

            clientGroup.put('sugati__CG_Lead_Group_Member__c', leadGm.get('Id'));
            update clientGroup;
            opp.put('sugati__O_Lead_CG__c', clientGroup.get('Id'));
            update opp;
        }
    }

    @IsTest
    static void testLoadTemplateSetsRecipients() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        SugatiCommunicationHubEmailService.LegacyEmailLoadDTO loaded =
            SugatiCommunicationHubEmailService.loadDefaultSendEmailTemplate(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, loaded);
        System.assertEquals(1, loaded.toAddresses.size(), 'B2C TO should be lead traveller');
        System.assertEquals('lead@example.com', loaded.toAddresses[0].email);
        System.assertEquals(0, loaded.ccAddresses.size());
        System.assert(loaded.bccAddresses.size() >= 1, 'BCC should include current user');
    }

    @IsTest
    static void testCatalogAndBccDefaults() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        SugatiCommunicationHubEmailService.LegacyTemplateCatalogDTO catalog =
            SugatiCommunicationHubEmailService.getSendEmailTemplateCatalog(opp.Id);
        List<SugatiCommunicationHubEmailService.EmailAddressOptionDTO> bcc =
            SugatiCommunicationHubEmailService.getSendEmailBccDefaults();
        Test.stopTest();

        System.assertNotEquals(null, catalog);
        System.assertNotEquals(null, catalog.relatedRecords);
        System.assert(!catalog.relatedRecords.isEmpty());
        System.assert(bcc.size() >= 1);
    }

    @IsTest
    static void testTemplateVisibilityByStageAndUser() {
        Id currentUserId = UserInfo.getUserId();
        System.assertEquals(
            true,
            SugatiCommunicationHubEmailService.templateVisibleForSendContextForTest(null, null, 'Booked', currentUserId)
        );
        System.assertEquals(
            false,
            SugatiCommunicationHubEmailService.templateVisibleForSendContextForTest(null, 'Booked', 'Enquiry', currentUserId)
        );
    }
}
