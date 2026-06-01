@IsTest
private class SugatiCommunicationHubControllerTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Tokyo Honeymoon 2026',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Contact c1 = new Contact(FirstName = 'Hiroshi', LastName = 'Yamamura', Email = 'hiroshi@example.com', AccountId = acc.Id);
        Contact c2 = new Contact(FirstName = 'Akemi', LastName = 'Yamamura', Email = 'akemi@example.com', AccountId = acc.Id);
        insert new List<Contact>{ c1, c2 };

        insert new OpportunityContactRole(OpportunityId = opp.Id, ContactId = c1.Id, Role = 'Lead Booker', IsPrimary = true);
        insert new OpportunityContactRole(OpportunityId = opp.Id, ContactId = c2.Id, Role = 'Traveller', IsPrimary = false);

        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        if (g.containsKey('sugati__Client_Group__c') && g.containsKey('sugati__Group_Member__c')) {
            SObject clientGroup = g.get('sugati__Client_Group__c').newSObject();
            clientGroup.put('sugati__CG_Opportunity__c', opp.Id);
            insert clientGroup;

            SObject gm = g.get('sugati__Group_Member__c').newSObject();
            gm.put('sugati__GM_Opportunity__c', opp.Id);
            gm.put('sugati__GM_Contact__c', c1.Id);
            gm.put('sugati__GM_Client_Group__c', clientGroup.get('Id'));
            gm.put('sugati__S_GM_Client_Group_Booking_Status__c', 'Booked');
            insert gm;

            clientGroup.put('sugati__CG_Lead_Group_Member__c', gm.get('Id'));
            update clientGroup;
            opp.put('sugati__O_Lead_CG__c', clientGroup.get('Id'));
            update opp;
        }

        if (g.containsKey('sugati__Supplier__c') && g.containsKey('sugati__Opportunity_Supplier__c')) {
            SObject supplier = g.get('sugati__Supplier__c').newSObject();
            supplier.put('Name', 'Sample Supplier');
            supplier.put('sugati__S_Email__c', 'supplier@example.com');
            insert supplier;

            SObject os = g.get('sugati__Opportunity_Supplier__c').newSObject();
            os.put('sugati__OS_Opportunity__c', opp.Id);
            os.put('sugati__OS_Supplier__c', supplier.get('Id'));
            insert os;
        }

        SObject t = Schema.getGlobalDescribe().get('Comm_Template__c').newSObject();
        t.put('Name', 'Pre-trip Welcome Pack');
        t.put('Channel__c', 'Email');
        t.put('Stage__c', 'Pre-Departure');
        t.put('Type__c', 'Traveller');
        t.put('Subject__c', 'Hello {{Opportunity.Name}}');
        t.put('Body__c', '<p>Owner: {{Owner.Name}}</p>');

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Comm_Template__c.fields.getMap();
        if (fieldMap.containsKey('Is_Active__c')) {
            t.put('Is_Active__c', true);
        }
        if (fieldMap.containsKey('Template_Status__c')) {
            t.put('Template_Status__c', 'Active');
        }
        insert t;
    }

    @IsTest
    static void testReadMethodsAndPreview() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact ORDER BY LastName ASC];
        Id templateId = (Id) Database.query('SELECT Id FROM Comm_Template__c LIMIT 1')[0].get('Id');

        Test.startTest();
        SugatiCommunicationHubController.HubContextDTO ctx = SugatiCommunicationHubController.getHubContext(opp.Id);
        List<SugatiCommunicationHubController.RecipientDTO> recipients = SugatiCommunicationHubController.getRecipients(opp.Id);
        List<SugatiCommunicationHubController.TemplateDTO> templates =
            SugatiCommunicationHubController.getTemplates(opp.Id, null, null, 'Email');
        SugatiCommunicationHubController.PreviewRequest req = new SugatiCommunicationHubController.PreviewRequest();
        req.opportunityId = opp.Id;
        req.templateId = templateId;
        req.recipientIds = new List<Id>{ contacts[0].Id };
        req.subjectTemplate = 'Trip {{Opportunity.Name}}';
        req.bodyTemplate = '<p>{{Owner.Name}}</p><p>{{Opportunity.StageName}}</p>';
        SugatiCommunicationHubController.PreviewResponse preview = SugatiCommunicationHubController.previewMessage(req);
        Test.stopTest();

        System.assertEquals(opp.Id, ctx.opportunityId);
        System.assert(recipients.size() >= 1, 'Expected recipients');
        System.assert(templates.size() >= 1, 'Expected active templates');
        System.assertEquals('Trip {{Opportunity.Name}}', preview.subject, 'Expected subject passthrough');
        System.assert(preview.bodyHtml.contains('{{Owner.Name}}'), 'Expected body passthrough');
    }

    @IsTest
    static void testSendMessageNativeModeCreatesLogs() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact ORDER BY CreatedDate ASC];
        Id templateId = (Id) Database.query('SELECT Id FROM Comm_Template__c LIMIT 1')[0].get('Id');

        SugatiCommunicationHubController.SendRequest req = new SugatiCommunicationHubController.SendRequest();
        req.opportunityId = opp.Id;
        req.templateId = templateId;
        req.recipientIds = new List<Id>{ contacts[0].Id, contacts[1].Id };
        req.subjectTemplate = 'Trip {{Opportunity.Name}}';
        req.bodyTemplate = '<p>Body {{Owner.Name}}</p>';
        req.deliveryMode = 'native';
        req.channel = 'Email';

        Test.startTest();
        SugatiCommunicationHubController.SendResponse res = SugatiCommunicationHubController.sendMessage(req);
        Test.stopTest();

        System.assertNotEquals(null, res.commLogId);
        System.assertEquals('Delivered', res.status);

        Comm_Log__c log = [SELECT Id, Status__c, Opportunity__c FROM Comm_Log__c WHERE Id = :res.commLogId LIMIT 1];
        System.assertEquals('Delivered', log.Status__c);
        System.assertEquals(opp.Id, log.Opportunity__c);

        Integer recCount = [SELECT COUNT() FROM Comm_Recipient__c WHERE Comm_Log__c = :log.Id];
        System.assertEquals(2, recCount, 'Expected child recipient rows');
    }

    @IsTest
    static void testSaveDraftDirectCreatesDraftLog() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email, Name FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        Test.startTest();
        SugatiCommunicationHubController.SendResponse res = SugatiCommunicationHubController.saveDraftDirect(
            null,
            opp.Id,
            null,
            new List<Id>{ null },
            new List<Id>{ contacts[0].Id },
            new List<String>{ contacts[0].Email },
            new List<String>{ contacts[0].Name },
            new List<String>{ 'Traveller' },
            'Draft subject {{Opportunity.Name}}',
            '<p>Draft body</p>',
            'postmark',
            'Email',
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, res.commLogId);
        System.assertEquals('Draft', res.status);

        Comm_Log__c log = [
            SELECT Id, Status__c, Subject__c, Body_HTML__c, Sent_At__c
            FROM Comm_Log__c
            WHERE Id = :res.commLogId
            LIMIT 1
        ];
        System.assertEquals('Draft', log.Status__c);
        System.assertEquals('Draft subject {{Opportunity.Name}}', log.Subject__c);
        System.assertEquals(null, log.Sent_At__c);
    }

    @IsTest
    static void testGetDraftForEditAndSyncRecipients() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email, Name FROM Contact ORDER BY CreatedDate ASC];

        SugatiCommunicationHubController.SendResponse created = SugatiCommunicationHubController.saveDraftDirect(
            null,
            opp.Id,
            null,
            new List<Id>{ null },
            new List<Id>{ contacts[0].Id },
            new List<String>{ contacts[0].Email },
            new List<String>{ contacts[0].Name },
            new List<String>{ 'Traveller' },
            'Draft to edit',
            '<p>Body</p>',
            'postmark',
            'Email',
            null,
            null,
            null
        );

        SugatiCommunicationHubController.DraftEditDTO loaded =
            SugatiCommunicationHubController.getDraftForEdit(created.commLogId);
        System.assertEquals('Draft to edit', loaded.subject);
        System.assertEquals(1, loaded.recipients.size());

        Id keptRecipientId = loaded.recipients[0].commRecipientId;

        Test.startTest();
        SugatiCommunicationHubController.saveDraftDirect(
            created.commLogId,
            opp.Id,
            null,
            new List<Id>{ keptRecipientId, null },
            new List<Id>{ contacts[0].Id, contacts[1].Id },
            new List<String>{ contacts[0].Email, contacts[1].Email },
            new List<String>{ contacts[0].Name, contacts[1].Name },
            new List<String>{ 'Traveller', 'Traveller' },
            'Draft updated',
            '<p>Updated body</p>',
            'native',
            'Email',
            null,
            null,
            null
        );
        Test.stopTest();

        Comm_Log__c log = [SELECT Subject__c, Delivery_Mode__c FROM Comm_Log__c WHERE Id = :created.commLogId LIMIT 1];
        System.assertEquals('Draft updated', log.Subject__c);
        System.assertEquals('native', log.Delivery_Mode__c);

        List<Comm_Recipient__c> recs = [
            SELECT Id, Contact__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :created.commLogId
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, recs.size(), 'Expected one kept and one new recipient');
        System.assertEquals(keptRecipientId, recs[0].Id, 'Expected original recipient row to remain');
    }

    @IsTest
    static void testDiscardDraftDirectDeletesDraft() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email, Name FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        SugatiCommunicationHubController.SendResponse created = SugatiCommunicationHubController.saveDraftDirect(
            null,
            opp.Id,
            null,
            new List<Id>{ null },
            new List<Id>{ contacts[0].Id },
            new List<String>{ contacts[0].Email },
            new List<String>{ contacts[0].Name },
            new List<String>{ 'Traveller' },
            'Draft to discard',
            '<p>Body</p>',
            'postmark',
            'Email',
            null,
            null,
            null
        );

        Test.startTest();
        SugatiCommunicationHubController.discardDraftDirect(created.commLogId);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Comm_Log__c WHERE Id = :created.commLogId],
            'Draft log should be deleted'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Comm_Recipient__c WHERE Comm_Log__c = :created.commLogId],
            'Draft recipients should be deleted'
        );
    }

    @IsTest
    static void testSaveDraftWithAttachments() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email, Name FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        ContentVersion oppFile = new ContentVersion(
            Title = 'Itinerary',
            PathOnClient = 'itinerary.pdf',
            VersionData = Blob.valueOf('Sample itinerary PDF')
        );
        insert oppFile;
        Id oppDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :oppFile.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = oppDocId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        SugatiCommunicationHubController.SendResponse res = SugatiCommunicationHubController.saveDraftDirect(
            null,
            opp.Id,
            null,
            new List<Id>{ null },
            new List<Id>{ contacts[0].Id },
            new List<String>{ contacts[0].Email },
            new List<String>{ contacts[0].Name },
            new List<String>{ 'Traveller' },
            'Draft with files',
            '<p>Body</p>',
            'postmark',
            'Email',
            new List<Id>{ oppDocId },
            new List<String>{ 'welcome.txt' },
            new List<String>{ EncodingUtil.base64Encode(Blob.valueOf('Hello attachment')) }
        );
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :res.commLogId
        ];
        System.assertEquals(2, links.size(), 'Expected opportunity file and uploaded file on draft');

        List<SugatiCommunicationHubController.HistoryItemDTO> history =
            SugatiCommunicationHubController.getHistory(opp.Id, null, null, null, null);
        System.assert(!history.isEmpty());
        System.assert(history[0].attachmentCount >= 2);
    }

    @IsTest
    static void testGetHistorySidebarFilters() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email, Name FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        Comm_Log__c draftLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Status__c = 'Draft',
            Subject__c = 'Sidebar draft',
            Body_HTML__c = '<p>Draft</p>'
        );
        insert draftLog;
        insert new Comm_Recipient__c(
            Comm_Log__c = draftLog.Id,
            Contact__c = contacts[0].Id,
            Name = contacts[0].Name,
            Email_Address__c = contacts[0].Email,
            Recipient_Type__c = 'Traveller',
            Status__c = 'Queued'
        );

        List<SugatiCommunicationHubController.HistoryItemDTO> drafts =
            SugatiCommunicationHubController.getHistory(opp.Id, null, 'Draft', null, null);
        System.assertEquals(1, drafts.size(), 'Draft filter should return draft log');

        List<SugatiCommunicationHubController.HistoryItemDTO> travellers =
            SugatiCommunicationHubController.getHistory(opp.Id, null, null, 'travellers', null);
        System.assert(!travellers.isEmpty(), 'Traveller audience filter should match draft log');
    }
}
