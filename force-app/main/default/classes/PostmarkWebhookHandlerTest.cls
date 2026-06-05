@IsTest
private class PostmarkWebhookHandlerTest {
    @IsTest
    static void testDeliveryWebhookUpdatesRecipientAndLog() {
        Comm_Log__c log = new Comm_Log__c(
            Name = 'Webhook Log Delivery',
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Subject',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Delivery_Mode__c = 'postmark'
        );
        insert log;

        Comm_Recipient__c rec = new Comm_Recipient__c(
            Name = 'Recipient Delivery',
            Comm_Log__c = log.Id,
            Email_Address__c = 'delivery@example.com',
            Status__c = 'Sent',
            Postmark_Id__c = 'pm-msg-delivery-001'
        );
        insert rec;

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/postmark/webhook/';
        req.requestBody = Blob.valueOf('{"RecordType":"Delivery","MessageID":"pm-msg-delivery-001"}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        PostmarkWebhookHandler.handleWebhook();

        Comm_Recipient__c updatedRec = [
            SELECT Status__c, Delivered_At__c
            FROM Comm_Recipient__c
            WHERE Id = :rec.Id
        ];
        System.assertEquals('Delivered', updatedRec.Status__c);
        System.assertNotEquals(null, updatedRec.Delivered_At__c);

        Comm_Log__c updatedLog = [
            SELECT Status__c, Delivered_At__c, Postmark_Message_Id__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id = :log.Id
        ];
        System.assertEquals('Delivered', updatedLog.Status__c);
        System.assertNotEquals(null, updatedLog.Delivered_At__c);
        System.assertEquals('pm-msg-delivery-001', updatedLog.Postmark_Message_Id__c);
        System.assertNotEquals(null, updatedLog.Last_Modified_At__c);
        System.assertEquals(200, RestContext.response.statusCode);
    }

    @IsTest
    static void testDeliveryWebhookMatchesLogPostmarkMessageId() {
        Comm_Log__c log = new Comm_Log__c(
            Name = 'Webhook Log Message Id Fallback',
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Subject',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Delivery_Mode__c = 'postmark',
            Postmark_Message_Id__c = 'pm-msg-log-only-001'
        );
        insert log;

        Comm_Recipient__c rec = new Comm_Recipient__c(
            Name = 'Recipient Log Only',
            Comm_Log__c = log.Id,
            Email_Address__c = 'logonly@example.com',
            Status__c = 'Sent'
        );
        insert rec;

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/postmark/webhook/';
        req.requestBody = Blob.valueOf('{"RecordType":"Delivery","MessageID":"pm-msg-log-only-001"}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        PostmarkWebhookHandler.handleWebhook();

        Comm_Recipient__c updatedRec = [
            SELECT Status__c, Delivered_At__c
            FROM Comm_Recipient__c
            WHERE Id = :rec.Id
        ];
        System.assertEquals('Delivered', updatedRec.Status__c);
        System.assertNotEquals(null, updatedRec.Delivered_At__c);
    }

    @IsTest
    static void testOpenAndBounceWebhookTracking() {
        Comm_Log__c log = new Comm_Log__c(
            Name = 'Webhook Log Open Bounce',
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Subject 2',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Delivery_Mode__c = 'postmark'
        );
        insert log;

        Comm_Recipient__c rec = new Comm_Recipient__c(
            Name = 'Recipient Open Bounce',
            Comm_Log__c = log.Id,
            Email_Address__c = 'openbounce@example.com',
            Status__c = 'Sent',
            Postmark_Id__c = 'pm-msg-openbounce-001'
        );
        insert rec;

        RestRequest openReq = new RestRequest();
        openReq.httpMethod = 'POST';
        openReq.requestUri = '/services/apexrest/postmark/webhook/';
        openReq.requestBody = Blob.valueOf('{"RecordType":"Open","MessageID":"pm-msg-openbounce-001"}');
        RestResponse openRes = new RestResponse();
        RestContext.request = openReq;
        RestContext.response = openRes;

        PostmarkWebhookHandler.handleWebhook();

        Comm_Log__c afterOpen = [
            SELECT Status__c, Open_Count__c, First_Opened_At__c, Last_Opened_At__c
            FROM Comm_Log__c
            WHERE Id = :log.Id
        ];
        System.assertEquals('Opened', afterOpen.Status__c);
        System.assertEquals(1, Integer.valueOf(afterOpen.Open_Count__c));
        System.assertNotEquals(null, afterOpen.First_Opened_At__c);
        System.assertNotEquals(null, afterOpen.Last_Opened_At__c);

        RestRequest bounceReq = new RestRequest();
        bounceReq.httpMethod = 'POST';
        bounceReq.requestUri = '/services/apexrest/postmark/webhook/';
        bounceReq.requestBody = Blob.valueOf(
            '{"RecordType":"Bounce","MessageID":"pm-msg-openbounce-001","Type":"HardBounce","Description":"Mailbox unavailable"}'
        );
        RestResponse bounceRes = new RestResponse();
        RestContext.request = bounceReq;
        RestContext.response = bounceRes;

        Test.startTest();
        PostmarkWebhookHandler.handleWebhook();
        Test.stopTest();

        Comm_Log__c afterBounce = [
            SELECT Status__c, Bounce_Type__c, Bounce_Description__c, Bounced_At__c
            FROM Comm_Log__c
            WHERE Id = :log.Id
        ];
        System.assertEquals('Bounced', afterBounce.Status__c);
        System.assertEquals('HardBounce', afterBounce.Bounce_Type__c);
        System.assertEquals('Mailbox unavailable', afterBounce.Bounce_Description__c);
        System.assertNotEquals(null, afterBounce.Bounced_At__c);
    }

    @IsTest
    static void testSpamAndClickWebhooks() {
        Comm_Log__c log = new Comm_Log__c(
            Name = 'Webhook Log Spam Click',
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Subject',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Delivery_Mode__c = 'postmark',
            Postmark_Message_Id__c = 'pm-msg-spam-click-001'
        );
        insert log;

        Comm_Recipient__c rec = new Comm_Recipient__c(
            Name = 'Recipient Spam Click',
            Comm_Log__c = log.Id,
            Email_Address__c = 'spamclick@example.com',
            Status__c = 'Sent',
            Postmark_Id__c = 'pm-msg-spam-click-001'
        );
        insert rec;

        RestRequest spamReq = new RestRequest();
        spamReq.httpMethod = 'POST';
        spamReq.requestUri = '/services/apexrest/postmark/webhook/';
        spamReq.requestBody = Blob.valueOf(
            '{"RecordType":"SpamComplaint","MessageID":"pm-msg-spam-click-001","Email":"spamclick@example.com"}'
        );
        RestResponse spamRes = new RestResponse();
        RestContext.request = spamReq;
        RestContext.response = spamRes;
        PostmarkWebhookHandler.handleWebhook();

        Comm_Log__c afterSpam = [
            SELECT Status__c, Spam_Reported_At__c
            FROM Comm_Log__c
            WHERE Id = :log.Id
        ];
        System.assertEquals('Spam Complaint', afterSpam.Status__c);
        System.assertNotEquals(null, afterSpam.Spam_Reported_At__c);

        RestRequest clickReq = new RestRequest();
        clickReq.httpMethod = 'POST';
        clickReq.requestUri = '/services/apexrest/postmark/webhook/';
        clickReq.requestBody = Blob.valueOf(
            '{"RecordType":"Click","MessageID":"pm-msg-spam-click-001","ReceivedAt":"2026-06-02T10:15:30.0000000Z"}'
        );
        RestResponse clickRes = new RestResponse();
        RestContext.request = clickReq;
        RestContext.response = clickRes;
        PostmarkWebhookHandler.handleWebhook();

        Comm_Log__c afterClick = [
            SELECT Click_Count__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id = :log.Id
        ];
        System.assertEquals(1, Integer.valueOf(afterClick.Click_Count__c));
        System.assertNotEquals(null, afterClick.Last_Modified_At__c);
    }

    @IsTest
    static void testOpenWebhookFiltersRecipientByEmail() {
        Comm_Log__c log = new Comm_Log__c(
            Name = 'Webhook Log Open Filter',
            Channel__c = 'Email',
            Direction__c = 'Outbound',
            Subject__c = 'Subject',
            Body_HTML__c = '<p>Body</p>',
            Status__c = 'Sent',
            Delivery_Mode__c = 'postmark'
        );
        insert log;

        Comm_Recipient__c recA = new Comm_Recipient__c(
            Name = 'Recipient A',
            Comm_Log__c = log.Id,
            Email_Address__c = 'opena@example.com',
            Status__c = 'Sent',
            Postmark_Id__c = 'pm-msg-open-filter-001'
        );
        Comm_Recipient__c recB = new Comm_Recipient__c(
            Name = 'Recipient B',
            Comm_Log__c = log.Id,
            Email_Address__c = 'openb@example.com',
            Status__c = 'Sent',
            Postmark_Id__c = 'pm-msg-open-filter-001'
        );
        insert new List<Comm_Recipient__c>{ recA, recB };

        RestRequest openReq = new RestRequest();
        openReq.httpMethod = 'POST';
        openReq.requestUri = '/services/apexrest/postmark/webhook/';
        openReq.requestBody = Blob.valueOf(
            '{"RecordType":"Open","MessageID":"pm-msg-open-filter-001","Recipient":"openb@example.com","ReceivedAt":"2026-06-02T11:00:00.0000000Z"}'
        );
        RestResponse openRes = new RestResponse();
        RestContext.request = openReq;
        RestContext.response = openRes;
        PostmarkWebhookHandler.handleWebhook();

        Comm_Recipient__c updatedA = [
            SELECT Status__c, Open_Count__c
            FROM Comm_Recipient__c
            WHERE Id = :recA.Id
        ];
        Comm_Recipient__c updatedB = [
            SELECT Status__c, Open_Count__c
            FROM Comm_Recipient__c
            WHERE Id = :recB.Id
        ];
        System.assertEquals('Sent', updatedA.Status__c);
        System.assertEquals('Opened', updatedB.Status__c);
        System.assertEquals(1, Integer.valueOf(updatedB.Open_Count__c));
    }

    @IsTest
    static void testInvalidPayloadReturnsBadRequest() {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/postmark/webhook/';
        req.requestBody = Blob.valueOf('{"RecordType":"Delivery"}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        PostmarkWebhookHandler.handleWebhook();

        System.assertEquals(400, RestContext.response.statusCode);
    }
}
