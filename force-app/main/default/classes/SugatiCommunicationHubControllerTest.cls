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

            if (g.containsKey('sugati__Supplier_Cost_Payment__c')) {
                SObject scp = g.get('sugati__Supplier_Cost_Payment__c').newSObject();
                scp.put('sugati__SCP_Opportunity__c', opp.Id);
                scp.put('sugati__SCP_Supplier__c', supplier.get('Id'));
                insert scp;
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

        Test.startTest();
        SugatiCommunicationHubController.HubContextDTO ctx = SugatiCommunicationHubController.getHubContext(opp.Id);
        List<SugatiCommunicationHubController.RecipientDTO> recipients = SugatiCommunicationHubController.getRecipients(opp.Id);
        SugatiCommunicationHubEmailService.TemplateCatalogDTO catalog =
            SugatiCommunicationHubController.getSendEmailTemplateCatalog(opp.Id);
        SugatiCommunicationHubEmailService.EmailTemplateLoadDTO loaded =
            SugatiCommunicationHubController.loadDefaultSendEmailTemplate(opp.Id);
        Test.stopTest();

        System.assertEquals(opp.Id, ctx.opportunityId);
        System.assertEquals('B2C', ctx.bookingChannelLabel);
        System.assertEquals(false, ctx.isAgencyBooking);
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
        Boolean hasSupplierContact = false;
        for (SugatiCommunicationHubController.RecipientDTO row : recipients) {
            if (row.audience == 'contacts' && row.email == 'supplier.contact@example.com') {
                hasSupplierContact = true;
            }
        }
        System.assert(hasSupplierContact, 'Expected operational supplier contacts on B2C bookings');
        System.assertNotEquals(null, catalog);
        System.assertNotEquals(null, loaded);
        System.assertNotEquals(null, loaded.subject, 'Default template should return a subject');
        System.assertNotEquals(null, loaded.bodyHtml, 'Default template should return rendered HTML');
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
            null,
            null,
            null,
            null,
            req
        );
        Test.stopTest();

        System.assertNotEquals(null, res.commLogId);
        System.assertEquals('Sent', res.status);
        System.assertEquals('NATIVE-TEST', res.providerMessageId);

        Comm_Log__c log = [
            SELECT Id, Status__c, Opportunity__c, Subject__c, Body_HTML__c, Sent_By__c, Sent_By__r.Email, Message_Id__c
            FROM Comm_Log__c
            WHERE Id = :res.commLogId
            LIMIT 1
        ];
        System.assertEquals('NATIVE-TEST', log.Message_Id__c);
        System.assertEquals('Sent', log.Status__c);
        System.assertEquals(opp.Id, log.Opportunity__c);
        System.assertEquals('Trip Test', log.Subject__c);
        System.assert(log.Body_HTML__c != null && log.Body_HTML__c.contains('Body'), 'Body should be saved on Comm_Log__c');
        System.assertEquals(UserInfo.getUserId(), log.Sent_By__c, 'Sent_By should be the running user');
        log = [
            SELECT From_Address__c
            FROM Comm_Log__c
            WHERE Id = :res.commLogId
            LIMIT 1
        ];
        System.assertNotEquals(null, log.From_Address__c, 'From_Address__c should be set on send');

        List<Comm_Recipient__c> recs = [
            SELECT Message_Id__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :log.Id
        ];
        System.assertEquals(3, recs.size(), 'Expected To, Cc, and Bcc recipient rows');
        for (Comm_Recipient__c rec : recs) {
            System.assertEquals('NATIVE-TEST', rec.Message_Id__c);
        }
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
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, res.commLogId);
        System.assertEquals('Draft', res.status);

        Comm_Log__c log = [
            SELECT Id, Status__c, Subject__c, Body_HTML__c, Sent_At__c, Last_Modified_At__c, From_Address__c
            FROM Comm_Log__c
            WHERE Id = :res.commLogId
            LIMIT 1
        ];
        System.assertNotEquals(null, log.From_Address__c);
        System.assertEquals('Draft', log.Status__c);
        System.assertEquals('Draft subject {{Opportunity.Name}}', log.Subject__c);
        System.assertEquals(null, log.Sent_At__c);
        System.assertNotEquals(null, log.Last_Modified_At__c, 'Draft save should stamp Last_Modified_At__c');

        List<SugatiCommunicationHubController.HistoryItemDTO> history =
            SugatiCommunicationHubController.getHistory(opp.Id, null, 'Draft', null, null, false);
        System.assertEquals(1, history.size());
        System.assertNotEquals(null, history[0].lastModifiedAt, 'History should expose last modified for drafts');
        System.assertNotEquals(null, history[0].fromDisplay, 'History should expose from display for drafts');
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
            null,
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
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        Comm_Log__c log = [
            SELECT Subject__c, Delivery_Mode__c, Last_Modified_At__c, From_Address__c
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
    static void testSendUsesComposerContentWhenTemplateConfigPresent() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email FROM Contact ORDER BY CreatedDate ASC];

        SugatiCommunicationHubController.SendRequest req = new SugatiCommunicationHubController.SendRequest();
        req.opportunityId = opp.Id;
        req.toEmails = new List<String>{ contacts[0].Email };
        req.subjectTemplate = 'Edited subject line';
        req.bodyTemplate = '<p>Edited body only for this send</p>';
        req.resolvedSubject = 'Edited subject line';
        req.resolvedBodyHtml = '<p>Edited body only for this send</p>';
        req.deliveryMode = 'native';
        req.channel = 'Email';
        req.sugatiEmailTemplateConfigId = (Id) 'a00000000000001AAA';

        Test.startTest();
        SugatiCommunicationHubController.SendResponse res = SugatiCommunicationHubController.sendMessage(
            opp.Id,
            req.toEmails,
            new List<String>(),
            new List<String>(),
            JSON.serialize(req.toEmails),
            null,
            null,
            JSON.serialize(
                new List<Object>{
                    new Map<String, Object>{ 'email' => contacts[0].Email, 'contactId' => contacts[0].Id }
                }
            ),
            req.deliveryMode,
            null,
            req.sugatiEmailTemplateConfigId,
            opp.Id,
            req.resolvedSubject,
            req.resolvedBodyHtml,
            null,
            null,
            null,
            null,
            req
        );
        Test.stopTest();

        Comm_Log__c log = [
            SELECT Subject__c, Body_HTML__c
            FROM Comm_Log__c
            WHERE Id = :res.commLogId
            LIMIT 1
        ];
        System.assertEquals('Edited subject line', log.Subject__c);
        System.assertEquals('<p>Edited body only for this send</p>', log.Body_HTML__c);

        Comm_Recipient__c recipient = [
            SELECT Contact__c, Email_Address__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :res.commLogId
            LIMIT 1
        ];
        System.assertEquals(contacts[0].Id, recipient.Contact__c);
        System.assertEquals(contacts[0].Email, recipient.Email_Address__c);
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
            null,
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
    static void testSendMessageWithAttachments() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        SugatiCommunicationHubController.SendRequest req = new SugatiCommunicationHubController.SendRequest();
        req.opportunityId = opp.Id;
        req.toEmails = new List<String>{ contacts[0].Email };
        req.subjectTemplate = 'With attachment';
        req.bodyTemplate = '<p>See attached</p>';
        req.resolvedSubject = 'With attachment';
        req.resolvedBodyHtml = '<p>See attached</p>';
        req.deliveryMode = 'native';
        req.channel = 'Email';
        req.newAttachmentFileNames = new List<String>{ 'notes.txt' };
        req.newAttachmentFileData = new List<String>{
            EncodingUtil.base64Encode(Blob.valueOf('Attachment body'))
        };

        Test.startTest();
        SugatiCommunicationHubController.SendResponse res = SugatiCommunicationHubController.sendMessage(
            opp.Id,
            req.toEmails,
            null,
            null,
            JSON.serialize(req.toEmails),
            '[]',
            '[]',
            JSON.serialize(
                new List<Object>{
                    new Map<String, Object>{ 'email' => contacts[0].Email, 'contactId' => contacts[0].Id }
                }
            ),
            req.deliveryMode,
            null,
            null,
            opp.Id,
            req.resolvedSubject,
            req.resolvedBodyHtml,
            null,
            req.newAttachmentFileNames,
            req.newAttachmentFileData,
            null,
            req
        );
        Test.stopTest();

        System.assertNotEquals(null, res.commLogId);
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :res.commLogId
        ];
        System.assertEquals(1, links.size(), 'Uploaded file should be linked to the sent Comm_Log__c');
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :opp.Id AND ContentDocumentId = :links[0].ContentDocumentId
            ],
            'Uploaded file should also be linked to the Opportunity'
        );
    }

    @IsTest
    static void testGetRecordAttachmentsIncludesFilesAndAttachments() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'Invoice Pack',
            PathOnClient = 'invoice.pdf',
            VersionData = Blob.valueOf('invoice')
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = docId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Attachment attachmentRecord = new Attachment(
            ParentId = opp.Id,
            Name = 'ATOL.pdf',
            Body = Blob.valueOf('atol'),
            ContentType = 'application/pdf'
        );
        insert attachmentRecord;

        List<SugatiCommunicationHubController.AttachmentDTO> rows = SugatiCommunicationHubController.getRecordAttachments(
            opp.Id,
            opp.Id
        );
        System.assert(rows.size() >= 2, 'Expected both Salesforce Files and Attachment records');
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
            new List<String>{ String.valueOf(oppDocId) },
            new List<String>{ 'welcome.txt' },
            new List<String>{ EncodingUtil.base64Encode(Blob.valueOf('Hello attachment')) },
            null,
            null
        );
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :res.commLogId
        ];
        System.assertEquals(2, links.size(), 'Expected opportunity file and uploaded file on draft');
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :opp.Id AND ContentDocument.Title = 'welcome'
            ],
            'New uploads should be linked to Comm Log only, not Opportunity'
        );

        List<SugatiCommunicationHubController.HistoryItemDTO> history =
            SugatiCommunicationHubController.getHistory(opp.Id, null, null, null, null, false);
        System.assert(!history.isEmpty());
        System.assert(history[0].attachmentCount >= 2);
    }

    @IsTest
    static void testConversationThreadAndRootOnlyHistory() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact traveller = [SELECT Id, Name, Email FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Acknowledgement Email',
            Body_HTML__c = '<p>Thank you for your enquiry.</p>',
            Status__c = 'Sent',
            Sent_At__c = System.now().addMinutes(-30),
            Message_Id__c = '<parent@mtasv.net>',
            From_Address__c = 'agent@example.com',
            Delivery_Mode__c = 'postmark'
        );
        insert parentLog;

        insert new Comm_Recipient__c(
            Comm_Log__c = parentLog.Id,
            Contact__c = traveller.Id,
            Name = traveller.Name,
            Email_Address__c = traveller.Email,
            Recipient_Type__c = 'Traveller',
            Status__c = 'Sent'
        );

        Comm_Log__c inboundLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Inbound',
            Subject__c = 'Re: Acknowledgement Email',
            Body_HTML__c = '<p>Thanks, looks good.</p>',
            Status__c = 'Received',
            Sent_At__c = System.now().addMinutes(-10),
            Parent_Comm_Log__c = parentLog.Id,
            From_Address__c = traveller.Email,
            Delivery_Mode__c = 'postmark'
        );
        insert inboundLog;

        insert new Comm_Recipient__c(
            Comm_Log__c = inboundLog.Id,
            Contact__c = traveller.Id,
            Name = traveller.Name,
            Email_Address__c = traveller.Email,
            Recipient_Type__c = 'Traveller',
            Status__c = 'Inbound'
        );

        insert new ContentVersion(
            Title = 'Outbound itinerary',
            PathOnClient = 'outbound-itinerary.pdf',
            VersionData = Blob.valueOf('outbound attachment'),
            FirstPublishLocationId = parentLog.Id
        );
        insert new ContentVersion(
            Title = 'Inbound reply file',
            PathOnClient = 'inbound-reply.pdf',
            VersionData = Blob.valueOf('inbound attachment'),
            FirstPublishLocationId = inboundLog.Id
        );

        Test.startTest();
        List<SugatiCommunicationHubController.HistoryItemDTO> allHistory =
            SugatiCommunicationHubController.getHistory(opp.Id, null, null, null, null, false);
        List<SugatiCommunicationHubController.HistoryItemDTO> rootHistory =
            SugatiCommunicationHubController.getHistory(opp.Id, null, null, null, null, true);
        SugatiCommunicationHubController.ConversationThreadDTO thread =
            SugatiCommunicationHubController.getConversationThread(inboundLog.Id);
        Test.stopTest();

        System.assertEquals(2, allHistory.size(), 'History should include outbound and inbound rows');
        System.assertEquals(1, rootHistory.size(), 'Hub root filter should return parent outbound only');
        System.assertEquals(parentLog.Id, rootHistory[0].id);
        System.assertEquals(2, rootHistory[0].threadMessageCount);

        System.assertEquals(parentLog.Id, thread.threadRootId);
        System.assertEquals('Acknowledgement Email', thread.subject);
        System.assertEquals('Sent', thread.rootStatus);
        System.assertEquals(1, thread.outboundCount);
        System.assertEquals(1, thread.inboundCount);
        System.assertEquals('<parent@mtasv.net>', thread.rootMessageId);
        System.assertNotEquals(null, thread.rootFromParty);
        System.assertEquals(1, thread.rootToParties.size());
        System.assertEquals(traveller.Email, thread.rootToParties[0].email);
        System.assertEquals(2, thread.messages.size());
        System.assertEquals(true, thread.messages[0].isThreadRoot);
        System.assertEquals('Outbound', thread.messages[0].direction);
        System.assertEquals('Inbound', thread.messages[1].direction);
        System.assert(thread.messages[0].snippet.contains('Thank you'));
        System.assert(thread.messages[1].snippet.contains('Thanks'));
        System.assertEquals(1, thread.messages[0].attachments.size());
        System.assertEquals(1, thread.messages[1].attachments.size());
        System.assertNotEquals(null, thread.messages[0].attachments[0].contentDocumentId);
        System.assertNotEquals(null, thread.messages[1].attachments[0].contentDocumentId);
    }

    @IsTest
    static void testReplyComposeContextAndParentOnSend() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact traveller = [SELECT Id, Name, Email FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Trip update',
            Body_HTML__c = '<p>Your itinerary is ready.</p>',
            Status__c = 'Sent',
            Sent_At__c = System.now().addHours(-2),
            From_Address__c = 'agent@example.com',
            Delivery_Mode__c = 'postmark'
        );
        insert parentLog;

        insert new Comm_Recipient__c(
            Comm_Log__c = parentLog.Id,
            Contact__c = traveller.Id,
            Name = traveller.Name,
            Email_Address__c = traveller.Email,
            Recipient_Type__c = 'Traveller',
            Email_Send_Type__c = 'TO',
            Status__c = 'Sent'
        );

        Comm_Log__c inboundLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Inbound',
            Subject__c = 'Re: Trip update',
            Body_HTML__c = '<p>Can we add an extra night?</p>',
            Status__c = 'Received',
            Sent_At__c = System.now().addHours(-1),
            Parent_Comm_Log__c = parentLog.Id,
            From_Address__c = traveller.Email,
            Delivery_Mode__c = 'postmark'
        );
        insert inboundLog;

        insert new Comm_Recipient__c(
            Comm_Log__c = inboundLog.Id,
            Contact__c = traveller.Id,
            Name = traveller.Name,
            Email_Address__c = traveller.Email,
            Recipient_Type__c = 'Traveller',
            Status__c = 'Inbound'
        );

        Test.startTest();
        SugatiCommunicationHubController.ReplyComposeContextDTO replyContext =
            SugatiCommunicationHubController.getReplyComposeContext(inboundLog.Id, false);
        SugatiCommunicationHubController.ReplyComposeContextDTO replyAllContext =
            SugatiCommunicationHubController.getReplyComposeContext(inboundLog.Id, true);

        SugatiCommunicationHubController.SendRequest request = new SugatiCommunicationHubController.SendRequest();
        request.opportunityId = opp.Id;
        request.channel = 'Email';
        request.deliveryMode = 'native';
        request.toEmails = new List<String>{ traveller.Email };
        request.resolvedSubject = 'Re: Trip update';
        request.resolvedBodyHtml = '<p>Yes, we can arrange that.</p>';
        request.parentCommLogId = inboundLog.Id;

        SugatiCommunicationHubController.SendResponse response = SugatiCommunicationHubController.sendMessage(
            opp.Id,
            request.toEmails,
            null,
            null,
            null,
            null,
            null,
            null,
            request.deliveryMode,
            null,
            null,
            opp.Id,
            request.resolvedSubject,
            request.resolvedBodyHtml,
            null,
            null,
            null,
            inboundLog.Id,
            request
        );
        Test.stopTest();

        System.assertEquals(inboundLog.Id, replyContext.parentCommLogId);
        System.assertEquals('Re: Trip update', replyContext.subject);
        System.assertEquals(true, replyContext.lockFromAddress);
        System.assertEquals(1, replyContext.toRecipients.size());
        System.assertEquals(traveller.Email, replyContext.toRecipients[0].email);
        System.assertEquals(1, replyContext.lockedToEmails.size());
        System.assertEquals(traveller.Email, replyContext.lockedToEmails[0]);

        System.assertEquals(true, replyAllContext.replyAll);
        System.assert(!replyAllContext.toRecipients.isEmpty());
        System.assert(!replyAllContext.lockedToEmails.isEmpty());

        Comm_Log__c replyLog = [
            SELECT Id, Parent_Comm_Log__c, Subject__c, Direction__c
            FROM Comm_Log__c
            WHERE Id = :response.commLogId
        ];
        System.assertEquals(inboundLog.Id, replyLog.Parent_Comm_Log__c);
        System.assertEquals('Outbound', replyLog.Direction__c);
        System.assertEquals('Re: Trip update', replyLog.Subject__c);
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
            SugatiCommunicationHubController.getHistory(opp.Id, null, 'Draft', null, null, false);
        System.assertEquals(1, drafts.size(), 'Draft filter should return draft log');

        List<SugatiCommunicationHubController.HistoryItemDTO> travellers =
            SugatiCommunicationHubController.getHistory(opp.Id, null, null, 'travellers', null, false);
        System.assert(!travellers.isEmpty(), 'Traveller audience filter should match draft log');
    }

    @IsTest
    static void testPostmarkRfcMessageIdExtraction() {
        String body =
            'From: Shivam Mittal <shivamm@aptclouds.com>\r\n' +
            'Date: Fri, 05 Jun 2026 06:18:37 +0000\r\n' +
            'Subject: Test Email\r\n' +
            'Message-Id: <7ff56b58-2ea7-4eb6-a170-41ead2c9c965@mtasv.net>\r\n' +
            'To: nitinc@aptclouds.com\r\n';
        System.assertEquals(
            '<7ff56b58-2ea7-4eb6-a170-41ead2c9c965@mtasv.net>',
            SugatiCommunicationPostmarkEmailService.extractRfcMessageIdFromBody(body)
        );
        System.assertEquals(
            '<7ff56b58-2ea7-4eb6-a170-41ead2c9c965@mtasv.net>',
            SugatiCommunicationPostmarkEmailService.buildPostmarkRfcMessageId('7ff56b58-2ea7-4eb6-a170-41ead2c9c965')
        );
        System.assertEquals(
            '<POSTMARK-TEST@mtasv.net>',
            SugatiCommunicationPostmarkEmailService.resolveOutboundRfcMessageId('POSTMARK-TEST')
        );
    }

    @IsTest
    static void testCommHubReplyToFallsBackToUserEmailWhenSettingBlank() {
        Comm_Hub_Setting__c settings = new Comm_Hub_Setting__c(
            SetupOwnerId = UserInfo.getUserId()
        );
        settings.Reply_To_Email__c = null;
        upsert settings;

        System.assertEquals(
            UserInfo.getUserEmail(),
            SugatiCommunicationHubController.getCommHubReplyToForTest(null)
        );
    }

    @IsTest
    static void testCommHubReplyToUsesHierarchySetting() {
        Comm_Hub_Setting__c settings = new Comm_Hub_Setting__c(
            SetupOwnerId = UserInfo.getUserId()
        );
        settings.Reply_To_Email__c = 'inbound@example.com';
        upsert settings;

        System.assertEquals(
            'inbound@example.com',
            SugatiCommunicationHubController.getCommHubReplyToForTest(null)
        );
    }

    @IsTest
    static void testNativeSendSetsReplyTo() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email FROM Contact ORDER BY CreatedDate ASC LIMIT 1];

        upsertCommHubReplyToSetting('inbound@example.com');
        SugatiCommunicationHubController.lastNativeReplyTo = null;

        Test.startTest();
        SugatiCommunicationHubController.sendMessage(
            opp.Id,
            new List<String>{ contacts[0].Email },
            null,
            null,
            JSON.serialize(new List<String>{ contacts[0].Email }),
            null,
            null,
            JSON.serialize(
                new List<Object>{
                    new Map<String, Object>{ 'email' => contacts[0].Email, 'contactId' => contacts[0].Id }
                }
            ),
            'native',
            null,
            null,
            opp.Id,
            'Reply-To test',
            '<p>Body</p>',
            null,
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(
            'inbound@example.com',
            SugatiCommunicationHubController.lastNativeReplyTo,
            'Native send should set Reply-To on the outbound email'
        );
    }

    private static String capturedPostmarkBody;

    @IsTest
    static void testPostmarkPayloadIncludesReplyTo() {
        capturedPostmarkBody = null;
        upsertCommHubReplyToSetting('inbound@example.com');
        Test.setMock(HttpCalloutMock.class, new PostmarkReplyToCaptureMock());

        SugatiCommunicationPostmarkEmailService.PostmarkEmailRequest req = new SugatiCommunicationPostmarkEmailService.PostmarkEmailRequest();
        req.fromAddress = 'sender@example.com';
        req.To = 'recipient@example.com';
        req.Subject = 'Reply-To payload test';
        req.HtmlBody = '<p>Body</p>';
        req.ReplyTo = SugatiCommunicationHubController.getCommHubReplyToForTest(null);

        Test.startTest();
        SugatiCommunicationPostmarkEmailService.sendEmail(req);
        Test.stopTest();

        System.assert(
            capturedPostmarkBody != null && capturedPostmarkBody.contains('inbound@example.com'),
            'Postmark payload should include the Communication Hub Reply-To address'
        );
    }

    private static void upsertCommHubReplyToSetting(String replyToEmail) {
        Comm_Hub_Setting__c settings = new Comm_Hub_Setting__c(
            SetupOwnerId = UserInfo.getUserId()
        );
        settings.Reply_To_Email__c = replyToEmail;
        upsert settings;
    }

    private class PostmarkReplyToCaptureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            capturedPostmarkBody = req.getBody();
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"MessageID":"reply-to-test-uuid","To":"recipient@example.com","SubmittedAt":"2026-06-05T00:00:00Z"}');
            return res;
        }
    }
}
