@IsTest
private class SugatiCommInboundEmailHandlerTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Inbound Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Inbound Test Booking',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Contact traveller = new Contact(
            FirstName = 'Traveller',
            LastName = 'One',
            Email = 'traveller@example.com',
            AccountId = acc.Id
        );
        insert traveller;
    }

    @IsTest
    static void testHappyPathCreatesInboundLogAndRecipient() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact traveller = [SELECT Id FROM Contact WHERE Email = 'traveller@example.com' LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Original outbound',
            Body_HTML__c = '<p>Outbound body</p>',
            Status__c = 'Sent',
            Message_Id__c = '<abc@mtasv.net>',
            From_Address__c = 'agent@example.com',
            Delivery_Mode__c = 'postmark'
        );
        insert parentLog;

        Comm_Recipient__c parentRecipient = new Comm_Recipient__c(
            Name = 'Traveller One',
            Comm_Log__c = parentLog.Id,
            Email_Address__c = 'traveller@example.com',
            Contact__c = traveller.Id,
            Recipient_Type__c = 'Traveller',
            Email_Send_Type__c = 'TO',
            Status__c = 'Sent'
        );
        insert parentRecipient;

        Messaging.InboundEmail inbound = buildInboundEmail(
            'traveller@example.com',
            'Traveller One',
            'Re: Original outbound',
            '<p>Thanks for the update</p>',
            '<inbound-001@example.com>',
            '<abc@mtasv.net>',
            null
        );
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'traveller@example.com';
        envelope.toAddress = 'commhubinbound@example.salesforce.com';

        Test.startTest();
        Messaging.InboundEmailResult result = processInbound(
            inbound,
            envelope
        );
        Test.stopTest();

        System.assertEquals(true, result.success);

        Comm_Log__c inboundLog = [
            SELECT
                Id,
                Direction__c,
                Status__c,
                Parent_Comm_Log__c,
                Opportunity__c,
                Subject__c,
                Body_HTML__c,
                Message_Id__c,
                Channel__c,
                Delivery_Mode__c
            FROM Comm_Log__c
            WHERE Direction__c = 'Inbound'
            LIMIT 1
        ];
        System.assertEquals('Inbound', inboundLog.Direction__c);
        System.assertEquals('Received', inboundLog.Status__c);
        System.assertEquals(parentLog.Id, inboundLog.Parent_Comm_Log__c);
        System.assertEquals(opp.Id, inboundLog.Opportunity__c);
        System.assertEquals('Re: Original outbound', inboundLog.Subject__c);
        System.assert(inboundLog.Body_HTML__c.contains('Thanks for the update'));
        System.assertEquals('<inbound-001@example.com>', inboundLog.Message_Id__c);
        System.assertEquals('Email', inboundLog.Channel__c);
        System.assertEquals('postmark', inboundLog.Delivery_Mode__c);

        Comm_Recipient__c inboundRecipient = [
            SELECT Email_Address__c, Contact__c, Recipient_Type__c, Name, Status__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :inboundLog.Id
            LIMIT 1
        ];
        System.assertEquals('traveller@example.com', inboundRecipient.Email_Address__c);
        System.assertEquals(traveller.Id, inboundRecipient.Contact__c);
        System.assertEquals('Traveller', inboundRecipient.Recipient_Type__c);
        System.assertEquals('Traveller One', inboundRecipient.Name);
        System.assertEquals('Inbound', inboundRecipient.Status__c);
    }

    @IsTest
    static void testReferencesFallbackResolvesParent() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'References parent',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Message_Id__c = '<parent-ref@mtasv.net>'
        );
        insert parentLog;

        Messaging.InboundEmail inbound = buildInboundEmail(
            'unknown@example.com',
            'Unknown Sender',
            'Re: References parent',
            null,
            '<inbound-ref@example.com>',
            null,
            '<parent-ref@mtasv.net> <other@example.com>'
        );

        Test.startTest();
        Messaging.InboundEmailResult result = processInbound(
            inbound,
            new Messaging.InboundEnvelope()
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        Comm_Log__c inboundLog = [
            SELECT Parent_Comm_Log__c
            FROM Comm_Log__c
            WHERE Direction__c = 'Inbound'
            LIMIT 1
        ];
        System.assertEquals(parentLog.Id, inboundLog.Parent_Comm_Log__c);
    }

    @IsTest
    static void testPostmarkUuidInReplyToMatchesRfcParentMessageId() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Postmark parent',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Message_Id__c = '<postmark-uuid-123@mtasv.net>'
        );
        insert parentLog;

        Messaging.InboundEmail inbound = buildInboundEmail(
            'sender@example.com',
            'Sender',
            'Re: Postmark parent',
            'Plain reply',
            '<inbound-uuid@example.com>',
            'postmark-uuid-123',
            null
        );

        Test.startTest();
        processInbound(inbound, new Messaging.InboundEnvelope());
        Test.stopTest();

        Comm_Log__c inboundLog = [
            SELECT Parent_Comm_Log__c
            FROM Comm_Log__c
            WHERE Direction__c = 'Inbound'
            LIMIT 1
        ];
        System.assertEquals(parentLog.Id, inboundLog.Parent_Comm_Log__c);
    }

    @IsTest
    static void testDuplicateInboundIsIgnored() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Duplicate parent',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Message_Id__c = '<dup-parent@mtasv.net>'
        );
        insert parentLog;

        Messaging.InboundEmail inbound = buildInboundEmail(
            'sender@example.com',
            'Sender',
            'Re: Duplicate parent',
            '<p>Duplicate</p>',
            '<dup-inbound@example.com>',
            '<dup-parent@mtasv.net>',
            null
        );

        Test.startTest();
        processInbound(inbound, new Messaging.InboundEnvelope());
        processInbound(inbound, new Messaging.InboundEnvelope());
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Comm_Log__c WHERE Direction__c = 'Inbound'],
            'Duplicate inbound Message-Id should not create a second log'
        );
    }

    @IsTest
    static void testNoParentMatchCreatesNoInboundLog() {
        Messaging.InboundEmail inbound = buildInboundEmail(
            'sender@example.com',
            'Sender',
            'Unmatched subject',
            '<p>No parent</p>',
            '<orphan@example.com>',
            '<missing-parent@mtasv.net>',
            null
        );

        Test.startTest();
        Messaging.InboundEmailResult result = processInbound(
            inbound,
            new Messaging.InboundEnvelope()
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Comm_Log__c WHERE Direction__c = 'Inbound'],
            'Unmatched inbound email should not create a Comm Log'
        );
    }

    @IsTest
    static void testInboundAttachmentIsLinkedToCommLog() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Attachment parent',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Message_Id__c = '<attach-parent@mtasv.net>'
        );
        insert parentLog;

        Messaging.InboundEmail inbound = buildInboundEmail(
            'sender@example.com',
            'Sender',
            'Re: Attachment parent',
            '<p>See attached</p>',
            '<inbound-attach@example.com>',
            '<attach-parent@mtasv.net>',
            null
        );
        Messaging.InboundEmail.BinaryAttachment attachment = new Messaging.InboundEmail.BinaryAttachment();
        attachment.fileName = 'reply.txt';
        attachment.body = Blob.valueOf('attachment body');
        inbound.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{ attachment };

        Test.startTest();
        processInbound(inbound, new Messaging.InboundEnvelope());
        Test.stopTest();

        Comm_Log__c inboundLog = [
            SELECT Id
            FROM Comm_Log__c
            WHERE Direction__c = 'Inbound'
            LIMIT 1
        ];
        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :inboundLog.Id],
            'Inbound attachment should be linked to the inbound Comm Log'
        );
    }

    @IsTest
    static void testSubjectOnlyDoesNotCreateInboundWithoutMessageIdMatch() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Trip update',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent'
        );
        insert parentLog;

        Messaging.InboundEmail inbound = buildInboundEmail(
            'traveller@example.com',
            'Traveller One',
            'Re: Trip update',
            '<p>No threading headers</p>',
            '<inbound-subject@example.com>',
            null,
            null
        );

        Test.startTest();
        processInbound(inbound, new Messaging.InboundEnvelope());
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Comm_Log__c WHERE Direction__c = 'Inbound'],
            'Inbound should only be created when In-Reply-To matches a Comm_Log Message_Id__c'
        );
    }

    @IsTest
    static void testGoogleWorkspaceForwardingSubjectIsCaptured() {
        String verificationUrl =
            'https://mail-settings.google.com/mail/vf-workspace/verify?param=1';
        Messaging.InboundEmail inbound = buildInboundEmail(
            'forwarding-noreply@google.com',
            'Swami Keshvanand Institute',
            '(Swami Keshvanand Institute Forwarding Confirmation - Receive Mail from b221519@skit.ac.in)',
            'Confirm forwarding: ' + verificationUrl,
            '<gmail-workspace-verify@google.com>',
            null,
            null
        );

        Test.startTest();
        Messaging.InboundEmailResult result = processInbound(
            inbound,
            new Messaging.InboundEnvelope()
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Comm_Log__c
                WHERE Delivery_Mode__c = 'mailbox_verification'
            ]
        );
        Comm_Log__c verificationLog = [
            SELECT Body_HTML__c
            FROM Comm_Log__c
            WHERE Delivery_Mode__c = 'mailbox_verification'
            LIMIT 1
        ];
        System.assert(verificationLog.Body_HTML__c.contains(verificationUrl));
    }

    @IsTest
    static void testMailboxForwardingVerificationCreatesSetupLog() {
        String verificationUrl =
            'https://mail-settings.google.com/mail/vf-abc123/verify?param=1';
        Messaging.InboundEmail inbound = buildInboundEmail(
            'forwarding-noreply@google.com',
            'Gmail Team',
            '(Gmail Forwarding Confirmation - Receive Mail from b221519@skit.ac.in)',
            '<p>Please click <a href="' +
                verificationUrl +
                '">this link</a> to confirm forwarding.</p>',
            '<gmail-verify@google.com>',
            null,
            null
        );
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'forwarding-noreply@google.com';
        envelope.toAddress = 'commhubinbound@example.salesforce.com';

        Test.startTest();
        Messaging.InboundEmailResult result = processInbound(
            inbound,
            envelope
        );
        Test.stopTest();

        System.assertEquals(true, result.success);

        Comm_Log__c verificationLog = [
            SELECT Id, Direction__c, Status__c, Delivery_Mode__c, Body_HTML__c, Subject__c
            FROM Comm_Log__c
            WHERE Delivery_Mode__c = 'mailbox_verification'
            LIMIT 1
        ];
        System.assertEquals('Inbound', verificationLog.Direction__c);
        System.assertEquals('Received', verificationLog.Status__c);
        System.assert(verificationLog.Body_HTML__c.contains(verificationUrl));
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Comm_Recipient__c WHERE Comm_Log__c = :verificationLog.Id]
        );
    }

    @IsTest
    static void testHandleInboundEmail() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Comm_Log__c parentLog = new Comm_Log__c(
            Opportunity__c = opp.Id,
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Handler parent',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Message_Id__c = '<handler-parent@mtasv.net>'
        );
        insert parentLog;

        Messaging.InboundEmail inbound = buildInboundEmail(
            'sender@example.com',
            'Sender',
            'Re: Handler parent',
            '<p>Handler path</p>',
            '<handler-inbound@example.com>',
            '<handler-parent@mtasv.net>',
            null
        );

        Test.startTest();
        Messaging.InboundEmailResult result = new SugatiCommunicationInboundEmailHandler()
            .handleInboundEmail(inbound, new Messaging.InboundEnvelope());
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(1, [SELECT COUNT() FROM Comm_Log__c WHERE Direction__c = 'Inbound']);
    }

    private static Messaging.InboundEmailResult processInbound(
        Messaging.InboundEmail inbound,
        Messaging.InboundEnvelope envelope
    ) {
        return new SugatiCommunicationInboundEmailHandler()
            .handleInboundEmail(inbound, envelope);
    }

    private static Messaging.InboundEmail buildInboundEmail(
        String fromAddress,
        String fromName,
        String subject,
        String htmlBody,
        String messageId,
        String inReplyTo,
        String references
    ) {
        Messaging.InboundEmail inbound = new Messaging.InboundEmail();
        inbound.fromAddress = fromAddress;
        inbound.fromName = fromName;
        inbound.subject = subject;
        if (String.isNotBlank(htmlBody) && htmlBody.contains('<')) {
            inbound.htmlBody = htmlBody;
        } else if (String.isNotBlank(htmlBody)) {
            inbound.plainTextBody = htmlBody;
        }
        List<Messaging.InboundEmail.Header> headers = new List<Messaging.InboundEmail.Header>();
        if (String.isNotBlank(messageId)) {
            headers.add(buildHeader('Message-Id', messageId));
        }
        if (String.isNotBlank(inReplyTo)) {
            headers.add(buildHeader('In-Reply-To', inReplyTo));
        }
        if (String.isNotBlank(references)) {
            headers.add(buildHeader('References', references));
        }
        if (!headers.isEmpty()) {
            inbound.headers = headers;
        }
        return inbound;
    }

    private static Messaging.InboundEmail.Header buildHeader(String name, String value) {
        Messaging.InboundEmail.Header header = new Messaging.InboundEmail.Header();
        header.name = name;
        header.value = value;
        return header;
    }
}


