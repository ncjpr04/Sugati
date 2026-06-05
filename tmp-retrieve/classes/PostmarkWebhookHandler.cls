@RestResource(urlMapping='/postmark/webhook/*')
global without sharing class PostmarkWebhookHandler {
    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            if (payload == null) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Invalid payload');
                return;
            }

            String recordType = asString(payload.get('RecordType'));
            String messageId = normalizeMessageId(payload);
            if (String.isBlank(recordType) || String.isBlank(messageId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('RecordType and MessageID are required');
                return;
            }

            if (recordType == 'Delivery') {
                handleDelivery(payload, messageId);
            } else if (recordType == 'Open') {
                handleOpen(payload, messageId);
            } else if (recordType == 'Bounce') {
                handleBounce(payload, messageId);
            } else if (recordType == 'SpamComplaint') {
                handleSpam(payload, messageId);
            } else if (recordType == 'Click') {
                handleClick(payload, messageId);
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('OK');
        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + ex.getMessage());
        }
    }

    private static void handleDelivery(Map<String, Object> payload, String messageId) {
        Datetime eventAt = extractEventTimestamp(payload);
        List<Comm_Recipient__c> recipients = findRecipientsByPostmarkId(messageId, payload);
        if (recipients.isEmpty()) {
            return;
        }
        Set<Id> commLogIds = new Set<Id>();
        for (Comm_Recipient__c rec : recipients) {
            rec.Status__c = 'Delivered';
            rec.Delivered_At__c = eventAt;
            if (rec.Comm_Log__c != null) {
                commLogIds.add(rec.Comm_Log__c);
            }
        }
        update recipients;
        updateCommLogsForDelivery(commLogIds, messageId, eventAt);
    }

    private static void handleOpen(Map<String, Object> payload, String messageId) {
        Datetime eventAt = extractEventTimestamp(payload);
        List<Comm_Recipient__c> recipients = findRecipientsByPostmarkId(messageId, payload);
        if (recipients.isEmpty()) {
            return;
        }
        Set<Id> commLogIds = new Set<Id>();
        for (Comm_Recipient__c rec : recipients) {
            Integer openCount = rec.Open_Count__c == null ? 0 : Integer.valueOf(rec.Open_Count__c);
            rec.Open_Count__c = openCount + 1;
            rec.Opened_At__c = eventAt;
            rec.Status__c = 'Opened';
            if (rec.Comm_Log__c != null) {
                commLogIds.add(rec.Comm_Log__c);
            }
        }
        update recipients;
        updateCommLogsForOpen(commLogIds, messageId, eventAt);
    }

    private static void handleClick(Map<String, Object> payload, String messageId) {
        Datetime eventAt = extractEventTimestamp(payload);
        Set<Id> commLogIds = extractCommLogIds(findRecipientsByPostmarkId(messageId, payload));
        if (commLogIds.isEmpty()) {
            return;
        }
        List<Comm_Log__c> logs = [
            SELECT Id, Click_Count__c, Postmark_Message_Id__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id IN :commLogIds
        ];
        for (Comm_Log__c log : logs) {
            Integer clickCount = log.Click_Count__c == null ? 0 : Integer.valueOf(log.Click_Count__c);
            log.Click_Count__c = clickCount + 1;
            log.Last_Modified_At__c = eventAt;
            if (String.isBlank(log.Postmark_Message_Id__c)) {
                log.Postmark_Message_Id__c = messageId;
            }
        }
        if (!logs.isEmpty()) {
            update logs;
        }
    }

    private static void handleBounce(Map<String, Object> payload, String messageId) {
        String bounceType = asString(payload.get('Type'));
        if (String.isBlank(bounceType)) {
            bounceType = asString(payload.get('BounceType'));
        }
        String description = asString(payload.get('Description'));
        Datetime eventAt = extractEventTimestamp(payload);
        List<Comm_Recipient__c> recipients = findRecipientsByPostmarkId(messageId, payload);
        Set<Id> commLogIds = extractCommLogIds(recipients);
        if (commLogIds.isEmpty()) {
            return;
        }
        List<Comm_Log__c> logs = [
            SELECT Id, Status__c, Bounce_Type__c, Bounce_Description__c, Bounced_At__c, Postmark_Message_Id__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id IN :commLogIds
        ];
        for (Comm_Log__c log : logs) {
            log.Status__c = 'Bounced';
            log.Bounce_Type__c = bounceType;
            log.Bounce_Description__c = description;
            log.Bounced_At__c = eventAt;
            log.Last_Modified_At__c = eventAt;
            if (String.isBlank(log.Postmark_Message_Id__c)) {
                log.Postmark_Message_Id__c = messageId;
            }
        }
        if (!logs.isEmpty()) {
            update logs;
        }
        updateRecipientsStatus(messageId, 'Bounced');
    }

    private static void handleSpam(Map<String, Object> payload, String messageId) {
        Datetime eventAt = extractEventTimestamp(payload);
        List<Comm_Recipient__c> recipients = findRecipientsByPostmarkId(messageId, payload);
        Set<Id> commLogIds = extractCommLogIds(recipients);
        if (commLogIds.isEmpty()) {
            return;
        }
        List<Comm_Log__c> logs = [
            SELECT Id, Status__c, Spam_Reported_At__c, Postmark_Message_Id__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id IN :commLogIds
        ];
        for (Comm_Log__c log : logs) {
            log.Status__c = 'Spam Complaint';
            log.Spam_Reported_At__c = eventAt;
            log.Last_Modified_At__c = eventAt;
            if (String.isBlank(log.Postmark_Message_Id__c)) {
                log.Postmark_Message_Id__c = messageId;
            }
        }
        if (!logs.isEmpty()) {
            update logs;
        }
        for (Comm_Recipient__c rec : recipients) {
            rec.Status__c = 'Failed';
        }
        if (!recipients.isEmpty()) {
            update recipients;
        }
    }

    private static void updateCommLogsForDelivery(Set<Id> commLogIds, String messageId, Datetime eventAt) {
        if (commLogIds.isEmpty()) {
            return;
        }
        List<Comm_Log__c> logs = [
            SELECT Id, Status__c, Delivered_At__c, Postmark_Message_Id__c, Last_Modified_At__c
            FROM Comm_Log__c
            WHERE Id IN :commLogIds
        ];
        for (Comm_Log__c log : logs) {
            if (log.Status__c != 'Opened' && log.Status__c != 'Spam Complaint' && log.Status__c != 'Bounced') {
                log.Status__c = 'Delivered';
            }
            log.Delivered_At__c = eventAt;
            log.Last_Modified_At__c = eventAt;
            if (String.isBlank(log.Postmark_Message_Id__c)) {
                log.Postmark_Message_Id__c = messageId;
            }
        }
        if (!logs.isEmpty()) {
            update logs;
        }
    }

    private static void updateCommLogsForOpen(Set<Id> commLogIds, String messageId, Datetime eventAt) {
        if (commLogIds.isEmpty()) {
            return;
        }
        List<Comm_Log__c> logs = [
            SELECT Id, Status__c, Open_Count__c, First_Opened_At__c, Last_Opened_At__c, Postmark_Message_Id__c, Last_Modified_At__c, Delivered_At__c
            FROM Comm_Log__c
            WHERE Id IN :commLogIds
        ];
        for (Comm_Log__c log : logs) {
            Integer openCount = log.Open_Count__c == null ? 0 : Integer.valueOf(log.Open_Count__c);
            log.Open_Count__c = openCount + 1;
            if (log.First_Opened_At__c == null) {
                log.First_Opened_At__c = eventAt;
            }
            log.Last_Opened_At__c = eventAt;
            log.Last_Modified_At__c = eventAt;
            log.Status__c = 'Opened';
            if (log.Delivered_At__c == null) {
                log.Delivered_At__c = eventAt;
            }
            if (String.isBlank(log.Postmark_Message_Id__c)) {
                log.Postmark_Message_Id__c = messageId;
            }
        }
        if (!logs.isEmpty()) {
            update logs;
        }
    }

    private static void updateRecipientsStatus(String messageId, String statusValue) {
        List<Comm_Recipient__c> recipients = [
            SELECT Id, Status__c
            FROM Comm_Recipient__c
            WHERE Postmark_Id__c = :messageId
        ];
        for (Comm_Recipient__c rec : recipients) {
            rec.Status__c = statusValue;
        }
        if (!recipients.isEmpty()) {
            update recipients;
        }
    }

    private static List<Comm_Recipient__c> findRecipientsByPostmarkId(String messageId, Map<String, Object> payload) {
        String recipientEmail = extractRecipientEmail(payload);
        List<Comm_Recipient__c> recipients = [
            SELECT Id, Comm_Log__c, Status__c, Delivered_At__c, Open_Count__c, Opened_At__c, Email_Address__c
            FROM Comm_Recipient__c
            WHERE Postmark_Id__c = :messageId
        ];
        if (!recipients.isEmpty() && String.isNotBlank(recipientEmail)) {
            List<Comm_Recipient__c> filtered = new List<Comm_Recipient__c>();
            String emailKey = recipientEmail.trim().toLowerCase();
            for (Comm_Recipient__c rec : recipients) {
                if (
                    rec.Email_Address__c != null &&
                    rec.Email_Address__c.trim().toLowerCase() == emailKey
                ) {
                    filtered.add(rec);
                }
            }
            if (!filtered.isEmpty()) {
                return filtered;
            }
        }
        if (!recipients.isEmpty()) {
            return recipients;
        }
        Set<Id> logIds = new Set<Id>();
        for (Comm_Log__c log : [
            SELECT Id
            FROM Comm_Log__c
            WHERE Postmark_Message_Id__c = :messageId
            LIMIT 50
        ]) {
            logIds.add(log.Id);
        }
        if (logIds.isEmpty()) {
            return recipients;
        }
        return [
            SELECT Id, Comm_Log__c, Status__c, Delivered_At__c, Open_Count__c, Opened_At__c, Email_Address__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c IN :logIds
        ];
    }

    private static String extractRecipientEmail(Map<String, Object> payload) {
        if (payload == null) {
            return null;
        }
        String email = asString(payload.get('Recipient'));
        if (String.isBlank(email)) {
            email = asString(payload.get('Email'));
        }
        return email;
    }

    private static Set<Id> extractCommLogIds(List<Comm_Recipient__c> recipients) {
        Set<Id> out = new Set<Id>();
        for (Comm_Recipient__c rec : recipients) {
            if (rec.Comm_Log__c != null) {
                out.add(rec.Comm_Log__c);
            }
        }
        return out;
    }

    private static Datetime extractEventTimestamp(Map<String, Object> payload) {
        List<String> candidateKeys = new List<String>{
            'DeliveredAt',
            'ReceivedAt',
            'BouncedAt',
            'FirstOpen',
            'OccurredAt'
        };
        for (String key : candidateKeys) {
            String raw = asString(payload.get(key));
            if (String.isBlank(raw)) {
                continue;
            }
            Datetime parsed = parsePostmarkDatetime(raw);
            if (parsed != null) {
                return parsed;
            }
        }
        return System.now();
    }

    private static Datetime parsePostmarkDatetime(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String normalized = raw.trim();
        if (normalized.endsWith('Z')) {
            normalized = normalized.substring(0, normalized.length() - 1) + '+0000';
        }
        try {
            return (Datetime) JSON.deserialize('"' + normalized + '"', Datetime.class);
        } catch (Exception ex) {
            // Fall through to manual parsing.
        }
        try {
            String gmtReady = normalized.replace('T', ' ');
            Integer dotIndex = gmtReady.indexOf('.');
            if (dotIndex > 0) {
                gmtReady = gmtReady.substring(0, dotIndex);
            }
            Integer plusIndex = gmtReady.indexOf('+');
            if (plusIndex > 0) {
                gmtReady = gmtReady.substring(0, plusIndex);
            }
            return Datetime.valueOfGmt(gmtReady);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String normalizeMessageId(Map<String, Object> payload) {
        if (payload == null) {
            return null;
        }
        String messageId = asString(payload.get('MessageID'));
        if (String.isBlank(messageId)) {
            messageId = asString(payload.get('MessageId'));
        }
        if (String.isBlank(messageId)) {
            messageId = asString(payload.get('messageID'));
        }
        return String.isBlank(messageId) ? null : messageId.trim();
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }
}