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

        if (g.containsKey('sugati__Supplier__c')) {
            SObject supplier = g.get('sugati__Supplier__c').newSObject();
            supplier.put('Name', 'Sample Supplier');
            supplier.put('sugati__S_Email__c', 'supplier@example.com');
            insert supplier;

            if (g.containsKey('sugati__Supplier_Booking__c')) {
                SObject booking = g.get('sugati__Supplier_Booking__c').newSObject();
                booking.put('sugati__SB_Opportunity__c', opp.Id);
                booking.put('sugati__SB_Supplier__c', supplier.get('Id'));
                insert booking;
            } else if (g.containsKey('sugati__Opportunity_Supplier__c')) {
                SObject os = g.get('sugati__Opportunity_Supplier__c').newSObject();
                os.put('sugati__OS_Opportunity__c', opp.Id);
                os.put('sugati__OS_Supplier__c', supplier.get('Id'));
                insert os;
            }

            if (g.containsKey('sugati__Supplier_Contact__c')) {
                SObject supplierContact = g.get('sugati__Supplier_Contact__c').newSObject();
                supplierContact.put('sugati__SC_Supplier__c', supplier.get('Id'));
                supplierContact.put('sugati__SC_Email__c', 'supplier.contact@example.com');
                supplierContact.put('sugati__SC_First_Name__c', 'Supplier');
                supplierContact.put('sugati__SC_Last_Name__c', 'Desk');
                insert supplierContact;
            }
        }

    }

    @IsTest
    static void testReadMethodsAndPreview() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact ORDER BY LastName ASC];

        Test.startTest();
        SugatiCommunicationHubController.HubContextDTO ctx = SugatiCommunicationHubController.getHubContext(opp.Id);
        List<SugatiCommunicationHubController.RecipientDTO> recipients = SugatiCommunicationHubController.getRecipients(opp.Id);
        List<SugatiCommunicationHubController.TemplateDTO> templates =
            SugatiCommunicationHubController.getTemplates(opp.Id, null, null, 'Email');
        SugatiLegacyEmailService.LegacyEmailLoadDTO loaded =
            SugatiLegacyEmailService.loadDefaultSendEmailTemplate(opp.Id);
        SugatiCommunicationHubController.PreviewRequest req = new SugatiCommunicationHubController.PreviewRequest();
        req.opportunityId = opp.Id;
        req.recipientIds = new List<Id>{ contacts[0].Id };
        req.subjectTemplate = 'Trip {{Opportunity.Name}}';
        req.bodyTemplate = '<p>{{Owner.Name}}</p><p>{{Opportunity.StageName}}</p>';
        SugatiCommunicationHubController.PreviewResponse preview = SugatiCommunicationHubController.previewMessage(req);
        Test.stopTest();

        System.assertEquals(opp.Id, ctx.opportunityId);
        System.assert(recipients.size() >= 1, 'Expected recipients');
        Boolean hasTraveller = false;
        for (SugatiCommunicationHubController.RecipientDTO row : recipients) {
            if (row.audience == 'travellers' && String.isNotBlank(row.email)) {
                hasTraveller = true;
                System.assertNotEquals(null, row.id, 'Traveller row id should be group member id');
                if (row.contactId != null) {
                    System.assertNotEquals(row.contactId, row.id, 'Traveller row id should not duplicate contact id');
                }
            }
        }
        System.assert(hasTraveller, 'Expected at least one traveller with email');
        System.assertNotEquals(null, loaded);
        System.assertNotEquals(null, preview.subject, 'Preview should return rendered subject');
        System.assertNotEquals(null, preview.bodyHtml, 'Preview should return rendered HTML from legacy template load');
    }

    @IsTest
    static void testSendMessageNativeModeCreatesLogs() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email FROM Contact ORDER BY CreatedDate ASC];

        SugatiCommunicationHubController.SendRequest req = new SugatiCommunicationHubController.SendRequest();
        req.opportunityId = opp.Id;
        req.toEmails = new List<String>{ contacts[0].Email };
        req.ccEmails = new List<String>{ contacts[1].Email };
        req.bccEmails = new List<String>{ UserInfo.getUserEmail() };
        req.subjectTemplate = 'Trip Test';
        req.bodyTemplate = '<p>Body</p>';
        req.resolvedSubject = 'Trip Test';
        req.resolvedBodyHtml = '<p>Body</p>';
        req.deliveryMode = 'native';
        req.channel = 'Email';

        Test.startTest();
        List<Object> toRecipientRows = new List<Object>{
            new Map<String, Object>{ 'email' => contacts[0].Email, 'contactId' => contacts[0].Id }
        };
        req.sugatiEmailTemplateConfigId = null;
        SugatiCommunicationHubController.SendResponse res = SugatiCommunicationHubController.sendMessage(
            opp.Id,
            req.toEmails,
            req.ccEmails,
            req.bccEmails,
            JSON.serialize(req.toEmails),
            JSON.serialize(req.ccEmails),
            JSON.serialize(req.bccEmails),
            JSON.serialize(toRecipientRows),
            req.deliveryMode,
            req.orgWideEmailAddressId,
            null,
            opp.Id,
            req.resolvedSubject,
            req.resolvedBodyHtml,
            req
        );
        Test.stopTest();

        System.assertNotEquals(null, res.commLogId);
        System.assertEquals('Delivered', res.status);

        Comm_Log__c log = [
            SELECT Id, Status__c, Opportunity__c, Subject__c, Body_HTML__c, Sent_By__c, Sent_By__r.Email
            FROM Comm_Log__c
            WHERE Id = :res.commLogId
            LIMIT 1
        ];
        System.assertEquals('Delivered', log.Status__c);
        System.assertEquals(opp.Id, log.Opportunity__c);
        System.assertEquals('Trip Test', log.Subject__c);
        System.assert(log.Body_HTML__c != null && log.Body_HTML__c.contains('Body'), 'Body should be saved on Comm_Log__c');
        System.assertEquals(UserInfo.getUserId(), log.Sent_By__c, 'Sent_By should be the running user');
        System.assertEquals(UserInfo.getUserEmail(), log.Sent_By__r.Email, 'From address comes from Sent_By user email');

        Integer recCount = [SELECT COUNT() FROM Comm_Recipient__c WHERE Comm_Log__c = :log.Id];
        System.assertEquals(3, recCount, 'Expected To, Cc, and Bcc recipient rows');
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
            new List<String>{ 'TO' },
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
            SELECT Id, Status__c, Subject__c, Body_HTML__c, Sent_At__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id = :res.commLogId
            LIMIT 1
        ];
        System.assertEquals('Draft', log.Status__c);
        System.assertEquals('Draft subject {{Opportunity.Name}}', log.Subject__c);
        System.assertEquals(null, log.Sent_At__c);
        System.assertNotEquals(null, log.Last_Modified_At__c, 'Draft save should stamp Last_Modified_At__c');

        List<SugatiCommunicationHubController.HistoryItemDTO> history =
            SugatiCommunicationHubController.getHistory(opp.Id, null, 'Draft', null, null);
        System.assertEquals(1, history.size());
        System.assertNotEquals(null, history[0].lastModifiedAt, 'History should expose last modified for drafts');
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
            new List<String>{ 'TO' },
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
            new List<String>{ 'TO', 'CC' },
            'Draft updated',
            '<p>Updated body</p>',
            'native',
            'Email',
            null,
            null,
            null
        );
        Test.stopTest();

        Comm_Log__c log = [
            SELECT Subject__c, Delivery_Mode__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id = :created.commLogId
            LIMIT 1
        ];
        System.assertNotEquals(null, log.Last_Modified_At__c, 'Draft update should refresh Last_Modified_At__c');
        System.assertEquals('Draft updated', log.Subject__c);
        System.assertEquals('native', log.Delivery_Mode__c);

        List<Comm_Recipient__c> recs = [
            SELECT Id, Contact__c, Email_Send_Type__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :created.commLogId
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, recs.size(), 'Expected one kept and one new recipient');
        System.assertEquals(keptRecipientId, recs[0].Id, 'Expected original recipient row to remain');
        System.assertEquals('TO', recs[0].Email_Send_Type__c);
        System.assertEquals('CC', recs[1].Email_Send_Type__c);

        SugatiCommunicationHubController.DraftEditDTO reloaded =
            SugatiCommunicationHubController.getDraftForEdit(created.commLogId);
        System.assertEquals(2, reloaded.recipients.size());
        System.assertEquals('TO', reloaded.recipients[0].emailSendType);
        System.assertEquals('CC', reloaded.recipients[1].emailSendType);
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
            new List<String>{ 'TO' },
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
            new List<String>{ 'TO' },
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
