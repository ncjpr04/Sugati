public class PostmarkEmailService {

    private static final String POSTMARK_ENDPOINT =
        'callout:Postmark/email';
    private static final String POSTMARK_OUTBOUND_ENDPOINT =
        'callout:Postmark/messages/outbound/';

    public class PostmarkEmailRequest {
        public String fromAddress;
        public String To;
        public String Cc;
        public String Bcc;
        public String ReplyTo;
        public String Subject;
        public String HtmlBody;
        public String TextBody;
        public String MessageStream = 'outbound';
        public String Tag;
        public Map<String, String> Metadata;
        public List<PostmarkAttachment> Attachments;
    }

    public class PostmarkAttachment {
        public String Name;
        public String Content;
        public String ContentType;
    }

    public class PostmarkEmailResponse {
        public String To;
        public String SubmittedAt;
        public String MessageID;
        public Integer ErrorCode;
        public String Message;
    }

    public static PostmarkEmailResponse sendEmail(
        PostmarkEmailRequest req
    ) {
        Http http = new Http();
        HttpRequest httpReq = new HttpRequest();

        httpReq.setEndpoint(POSTMARK_ENDPOINT);
        httpReq.setMethod('POST');

        httpReq.setHeader('Accept', 'application/json');
        httpReq.setHeader('Content-Type', 'application/json');

        // NO TOKEN HEADER HERE

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('From', req.fromAddress);
        payload.put('To', req.To);
        payload.put('Subject', req.Subject);
        payload.put('HtmlBody', req.HtmlBody);
        if (String.isNotBlank(req.Cc)) {
            payload.put('Cc', req.Cc);
        }
        if (String.isNotBlank(req.Bcc)) {
            payload.put('Bcc', req.Bcc);
        }
        if (String.isNotBlank(req.ReplyTo)) {
            payload.put('ReplyTo', req.ReplyTo);
        }
        if (String.isNotBlank(req.TextBody)) {
            payload.put('TextBody', req.TextBody);
        }
        if (String.isNotBlank(req.MessageStream)) {
            payload.put('MessageStream', req.MessageStream);
        }
        if (String.isNotBlank(req.Tag)) {
            payload.put('Tag', req.Tag);
        }
        if (req.Metadata != null && !req.Metadata.isEmpty()) {
            payload.put('Metadata', req.Metadata);
        }
        if (req.Attachments != null && !req.Attachments.isEmpty()) {
            payload.put('Attachments', req.Attachments);
        }

        httpReq.setBody(JSON.serialize(payload));
        httpReq.setTimeout(30000);

        HttpResponse res = http.send(httpReq);

        System.debug('Status Code: ' + res.getStatusCode());
        System.debug('Response: ' + res.getBody());

        if (res.getStatusCode() == 200) {
            return (PostmarkEmailResponse)JSON.deserialize(
                res.getBody(),
                PostmarkEmailResponse.class
            );
        }

        throw new CalloutException(
            'Postmark Error (' +
            res.getStatusCode() +
            '): ' +
            res.getBody()
        );
    }

    public static String resolveOutboundRfcMessageId(String postmarkMessageId) {
        if (String.isBlank(postmarkMessageId)) {
            return null;
        }
        String uuid = postmarkMessageId.trim();
        if (isRfcMessageId(uuid)) {
            return uuid;
        }
        if (!Test.isRunningTest()) {
            try {
                String body = fetchOutboundMessageBody(uuid);
                String extracted = extractRfcMessageIdFromBody(body);
                if (String.isNotBlank(extracted)) {
                    return extracted;
                }
            } catch (Exception ex) {
                System.debug(
                    LoggingLevel.WARN,
                    'Postmark outbound lookup failed, deriving RFC Message-Id: ' + ex.getMessage()
                );
            }
        }
        return buildPostmarkRfcMessageId(uuid);
    }

    public static String buildPostmarkRfcMessageId(String postmarkUuid) {
        if (String.isBlank(postmarkUuid)) {
            return null;
        }
        String value = postmarkUuid.trim();
        if (isRfcMessageId(value)) {
            return value;
        }
        return '<' + value + '@mtasv.net>';
    }

    private static Boolean isRfcMessageId(String value) {
        return String.isNotBlank(value) && value.startsWith('<') && value.contains('@') && value.endsWith('>');
    }

    @TestVisible
    private static String fetchOutboundMessageBody(String postmarkMessageId) {
        Http http = new Http();
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(POSTMARK_OUTBOUND_ENDPOINT + EncodingUtil.urlEncode(postmarkMessageId, 'UTF-8'));
        httpReq.setMethod('GET');
        httpReq.setHeader('Accept', 'application/json');
        httpReq.setTimeout(30000);
        HttpResponse res = http.send(httpReq);
        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'Postmark outbound lookup failed (' + res.getStatusCode() + '): ' + res.getBody()
            );
        }
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object bodyRaw = payload.get('Body');
        return bodyRaw == null ? null : String.valueOf(bodyRaw);
    }

    @TestVisible
    private static String extractRfcMessageIdFromBody(String body) {
        if (String.isBlank(body)) {
            return null;
        }
        String normalized = body.replace('\r\n', '\n');
        for (String line : normalized.split('\n')) {
            if (String.isBlank(line)) {
                continue;
            }
            String trimmed = line.trim();
            if (!trimmed.toLowerCase().startsWith('message-id:')) {
                continue;
            }
            String value = trimmed.substring('message-id:'.length()).trim();
            return String.isBlank(value) ? null : value;
        }
        Matcher matcher = Pattern.compile('(?i)Message-Id:\\s*(<[^>]+>)').matcher(body);
        return matcher.find() ? matcher.group(1).trim() : null;
    }
}