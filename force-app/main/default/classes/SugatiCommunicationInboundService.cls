public without sharing class SugatiCommunicationInboundService {
    private static final String EMAIL_CHANNEL = 'Email';
    private static final String INBOUND_DELIVERY_MODE = 'inbound';

    public static Messaging.InboundEmailResult processInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        if (email == null) {
            result.success = true;
            return result;
        }

        try {
            String inboundMessageId = normalizeMessageId(resolveHeaderValue(email, 'Message-Id'));
            if (String.isNotBlank(inboundMessageId) && inboundLogExists(inboundMessageId)) {
                result.success = true;
                result.message = 'Duplicate inbound ignored: ' + inboundMessageId;
                return result;
            }

            if (isMailboxForwardingVerification(email)) {
                return processMailboxForwardingVerification(email, envelope);
            }

            Comm_Log__c parentLog = resolveParentCommLog(email);
            if (parentLog == null) {
                logInboundDebug(
                    'No parent Comm_Log match',
                    email,
                    envelope
                );
                result.success = true;
                result.message = 'No parent Comm_Log match';
                return result;
            }

            Comm_Log__c inboundLog = new Comm_Log__c();
            inboundLog.Direction__c = 'Inbound';
            inboundLog.Status__c = 'Received';
            inboundLog.Channel__c = EMAIL_CHANNEL;
            inboundLog.Parent_Comm_Log__c = parentLog.Id;
            inboundLog.Opportunity__c = parentLog.Opportunity__c;
            inboundLog.Subject__c = truncate(email.subject, 255);
            inboundLog.Body_HTML__c = resolveInboundBody(email);
            inboundLog.Message_Id__c = inboundMessageId;
            inboundLog.Sent_At__c = System.now();
            inboundLog.Delivery_Mode__c = INBOUND_DELIVERY_MODE;
            insert inboundLog;

            Comm_Recipient__c matchedParentRecipient = findMatchingParentRecipient(
                parentLog.Id,
                email.fromAddress
            );
            Comm_Recipient__c inboundRecipient = buildInboundRecipient(
                inboundLog.Id,
                email,
                matchedParentRecipient
            );
            insert inboundRecipient;

            saveInboundAttachments(email, inboundLog.Id);

            result.success = true;
            result.message = 'Inbound Comm Log created: ' + inboundLog.Id;
            return result;
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.ERROR,
                'Inbound email processing failed: ' +
                    ex.getMessage() +
                    ' | ' +
                    ex.getStackTraceString()
            );
            result.success = false;
            result.message = ex.getMessage();
            return result;
        }
    }

    private static Boolean isMailboxForwardingVerification(Messaging.InboundEmail email) {
        if (email == null) {
            return false;
        }
        String fromKey = normalizeEmailKey(email.fromAddress);
        if (fromKey == 'forwarding-noreply@google.com') {
            return true;
        }
        String subject = email.subject == null ? '' : email.subject.toLowerCase();
        Boolean fromMailboxProvider =
            fromKey.contains('@google.com') ||
            fromKey.contains('@gmail.com') ||
            fromKey.contains('@outlook.com') ||
            fromKey.contains('@microsoft.com');
        Boolean subjectLooksLikeVerification =
            subject.contains('forwarding confirmation') ||
            subject.contains('verify forwarding') ||
            subject.contains('forwarding verification') ||
            subject.contains('receive mail from');
        return fromMailboxProvider && subjectLooksLikeVerification;
    }

    private static Messaging.InboundEmailResult processMailboxForwardingVerification(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        String verificationUrl = extractForwardingVerificationUrl(email);
        String verificationCode = extractForwardingVerificationCode(email);
        String inboundMessageId = normalizeMessageId(resolveHeaderValue(email, 'Message-Id'));

        Comm_Log__c verificationLog = new Comm_Log__c();
        verificationLog.Direction__c = 'Inbound';
        verificationLog.Status__c = 'Received';
        verificationLog.Channel__c = EMAIL_CHANNEL;
        verificationLog.Subject__c = truncate(email.subject, 255);
        verificationLog.Body_HTML__c = buildMailboxVerificationBody(
            email,
            verificationUrl,
            verificationCode
        );
        verificationLog.Message_Id__c = inboundMessageId;
        verificationLog.Sent_At__c = System.now();
        verificationLog.Delivery_Mode__c = 'mailbox_verification';
        insert verificationLog;

        Comm_Recipient__c verificationRecipient = new Comm_Recipient__c();
        verificationRecipient.Comm_Log__c = verificationLog.Id;
        verificationRecipient.Status__c = 'Inbound';
        verificationRecipient.Email_Address__c = normalizeEmail(email.fromAddress);
        verificationRecipient.Name = resolveRecipientName(email);
        verificationRecipient.Recipient_Type__c = 'Traveller';
        insert verificationRecipient;

        saveInboundAttachments(email, verificationLog.Id);
        notifyRunAsUserOfForwardingVerification(
            email,
            verificationUrl,
            verificationCode,
            verificationLog.Id
        );

        System.debug(
            LoggingLevel.ERROR,
            'MAILBOX_FORWARDING_VERIFICATION captured' +
                ' | verificationUrl=' +
                verificationUrl +
                ' | verificationCode=' +
                verificationCode +
                ' | commLogId=' +
                verificationLog.Id
        );

        result.success = true;
        result.message =
            'Mailbox forwarding verification captured in Comm_Log__c: ' +
            verificationLog.Id +
            (String.isNotBlank(verificationUrl)
                ? ' | verificationUrl=' + verificationUrl
                : '') +
            (String.isNotBlank(verificationCode)
                ? ' | verificationCode=' + verificationCode
                : '');
        return result;
    }

    private static String buildMailboxVerificationBody(
        Messaging.InboundEmail email,
        String verificationUrl,
        String verificationCode
    ) {
        List<String> sections = new List<String>();
        sections.add('<p><strong>Mailbox forwarding verification received.</strong></p>');
        if (String.isNotBlank(verificationUrl)) {
            sections.add(
                '<p><a href="' +
                    escapeHtml(verificationUrl) +
                    '">Open verification link</a></p>'
            );
            sections.add('<p>' + escapeHtml(verificationUrl) + '</p>');
        }
        if (String.isNotBlank(verificationCode)) {
            sections.add(
                '<p>Confirmation code: <strong>' +
                    escapeHtml(verificationCode) +
                    '</strong></p>'
            );
        }
        String originalBody = resolveInboundBody(email);
        if (String.isNotBlank(originalBody)) {
            sections.add('<hr/>' + originalBody);
        }
        return String.join(sections, '');
    }

    private static String extractForwardingVerificationUrl(Messaging.InboundEmail email) {
        List<String> bodies = new List<String>();
        if (email != null && String.isNotBlank(email.htmlBody)) {
            bodies.add(email.htmlBody);
        }
        if (email != null && String.isNotBlank(email.plainTextBody)) {
            bodies.add(email.plainTextBody);
        }
        Pattern urlPattern = Pattern.compile(
            '(?i)https?://(?:mail-settings\\.google\\.com/mail/[^\\s\"\'<>]+|[^\\s\"\'<>]*google\\.com[^\\s\"\'<>]*vf[^\\s\"\'<>]*)'
        );
        for (String body : bodies) {
            Matcher matcher = urlPattern.matcher(body);
            if (matcher.find()) {
                return matcher.group().replaceAll('[).,;]+$', '');
            }
        }
        return null;
    }

    private static String extractForwardingVerificationCode(Messaging.InboundEmail email) {
        List<String> bodies = new List<String>();
        if (email != null && String.isNotBlank(email.plainTextBody)) {
            bodies.add(email.plainTextBody);
        }
        if (email != null && String.isNotBlank(email.htmlBody)) {
            bodies.add(email.htmlBody.replaceAll('<[^>]+>', ' '));
        }
        Pattern codePattern = Pattern.compile('(?i)confirmation\\s+code[:\\s]+([A-Za-z0-9-]+)');
        for (String body : bodies) {
            Matcher matcher = codePattern.matcher(body);
            if (matcher.find()) {
                return matcher.group(1);
            }
        }
        return null;
    }

    private static void notifyRunAsUserOfForwardingVerification(
        Messaging.InboundEmail email,
        String verificationUrl,
        String verificationCode,
        Id verificationLogId
    ) {
        if (String.isBlank(verificationUrl) && String.isBlank(verificationCode)) {
            return;
        }
        String notifyEmail = resolveRunAsUserEmail();
        if (String.isBlank(notifyEmail)) {
            return;
        }

        List<String> bodyLines = new List<String>();
        bodyLines.add('A mailbox forwarding verification email was received by Comm Hub inbound.');
        bodyLines.add('Mailbox: ' + (email == null ? null : email.subject));
        bodyLines.add('Comm Log Id: ' + verificationLogId);
        if (String.isNotBlank(verificationUrl)) {
            bodyLines.add('Verification link: ' + verificationUrl);
        }
        if (String.isNotBlank(verificationCode)) {
            bodyLines.add('Confirmation code: ' + verificationCode);
        }
        bodyLines.add(
            'Open the Comm Log record in Salesforce to complete Gmail forwarding setup.'
        );

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ notifyEmail });
        mail.setSubject('Comm Hub: Gmail forwarding verification link');
        mail.setPlainTextBody(String.join(bodyLines, '\n'));
        if (String.isNotBlank(verificationUrl)) {
            mail.setHtmlBody(
                '<p>A mailbox forwarding verification email was received by Comm Hub inbound.</p>' +
                    '<p><a href="' +
                    escapeHtml(verificationUrl) +
                    '">Click here to verify Gmail forwarding</a></p>' +
                    '<p>Comm Log Id: ' +
                    escapeHtml(String.valueOf(verificationLogId)) +
                    '</p>'
            );
        }
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.WARN,
                'Could not email forwarding verification link: ' + ex.getMessage()
            );
        }
    }

    private static String resolveRunAsUserEmail() {
        List<User> users = [
            SELECT Email
            FROM User
            WHERE Id = :UserInfo.getUserId() AND IsActive = TRUE
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0].Email;
    }

    private static void logInboundDebug(
        String message,
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        System.debug(
            LoggingLevel.WARN,
            message +
                ' | from=' +
                (email == null ? null : email.fromAddress) +
                ' | subject=' +
                (email == null ? null : email.subject) +
                ' | to=' +
                (envelope == null ? null : envelope.toAddress) +
                ' | inReplyTo=' +
                resolveHeaderValue(email, 'In-Reply-To') +
                ' | references=' +
                resolveHeaderValue(email, 'References')
        );
    }

    private static Comm_Recipient__c buildInboundRecipient(
        Id inboundLogId,
        Messaging.InboundEmail email,
        Comm_Recipient__c matchedParentRecipient
    ) {
        Comm_Recipient__c rec = new Comm_Recipient__c();
        rec.Comm_Log__c = inboundLogId;
        rec.Status__c = 'Inbound';

        if (matchedParentRecipient != null) {
            rec.Email_Address__c = matchedParentRecipient.Email_Address__c;
            rec.Contact__c = matchedParentRecipient.Contact__c;
            rec.Phone_Number__c = matchedParentRecipient.Phone_Number__c;
            rec.Name = matchedParentRecipient.Name;
            rec.Recipient_Type__c = matchedParentRecipient.Recipient_Type__c;
        } else {
            rec.Email_Address__c = normalizeEmail(email.fromAddress);
            rec.Name = resolveRecipientName(email);
            rec.Recipient_Type__c = 'Traveller';
        }
        return rec;
    }

    private static String resolveRecipientName(Messaging.InboundEmail email) {
        if (email == null) {
            return 'Unknown sender';
        }
        if (String.isNotBlank(email.fromName)) {
            return email.fromName.trim();
        }
        return String.isNotBlank(email.fromAddress) ? email.fromAddress.trim() : 'Unknown sender';
    }

    private static Comm_Recipient__c findMatchingParentRecipient(Id parentLogId, String fromAddress) {
        String senderKey = normalizeEmailKey(fromAddress);
        if (parentLogId == null || String.isBlank(senderKey)) {
            return null;
        }
        for (Comm_Recipient__c rec : [
            SELECT Id, Email_Address__c, Contact__c, Phone_Number__c, Recipient_Type__c, Name
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :parentLogId
        ]) {
            if (normalizeEmailKey(rec.Email_Address__c) == senderKey) {
                return rec;
            }
        }
        return null;
    }

    private static Comm_Log__c resolveParentCommLog(Messaging.InboundEmail email) {
        List<String> candidates = collectReplyMessageIdCandidates(email);
        for (String candidate : candidates) {
            Comm_Log__c parent = findParentByMessageId(candidate);
            if (parent != null) {
                return parent;
            }
        }
        return null;
    }

    private static List<String> collectReplyMessageIdCandidates(Messaging.InboundEmail email) {
        List<String> candidates = new List<String>();
        Set<String> seen = new Set<String>();
        addMessageIdCandidates(candidates, seen, resolveHeaderValue(email, 'In-Reply-To'));
        addMessageIdCandidates(candidates, seen, resolveHeaderValue(email, 'References'));
        addMessageIdCandidates(candidates, seen, extractHeaderFromBodies(email, 'In-Reply-To'));
        addMessageIdCandidates(candidates, seen, extractHeaderFromBodies(email, 'References'));
        return candidates;
    }

    private static void addMessageIdCandidates(
        List<String> candidates,
        Set<String> seen,
        String rawHeader
    ) {
        if (String.isBlank(rawHeader)) {
            return;
        }
        Matcher matcher = Pattern.compile('<[^>]+>').matcher(rawHeader);
        while (matcher.find()) {
            addCandidate(candidates, seen, matcher.group());
        }
        for (String token : rawHeader.split('\\s+')) {
            addCandidate(candidates, seen, token);
        }
    }

    private static void addCandidate(List<String> candidates, Set<String> seen, String rawValue) {
        String normalized = normalizeMessageId(rawValue);
        if (String.isBlank(normalized) || seen.contains(normalized)) {
            return;
        }
        seen.add(normalized);
        candidates.add(normalized);
    }

    private static Comm_Log__c findParentByMessageId(String candidate) {
        if (String.isBlank(candidate)) {
            return null;
        }
        List<Comm_Log__c> exactMatches = [
            SELECT Id, Opportunity__c, Message_Id__c
            FROM Comm_Log__c
            WHERE Message_Id__c = :candidate
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!exactMatches.isEmpty()) {
            return exactMatches[0];
        }

        String strippedUuid = stripMessageIdDecorations(candidate);
        if (String.isBlank(strippedUuid)) {
            return null;
        }
        String likePattern = '%' + strippedUuid + '%';
        List<Comm_Log__c> fuzzyMatches = [
            SELECT Id, Opportunity__c, Message_Id__c
            FROM Comm_Log__c
            WHERE Message_Id__c LIKE :likePattern
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return fuzzyMatches.isEmpty() ? null : fuzzyMatches[0];
    }

    private static Boolean inboundLogExists(String inboundMessageId) {
        return [
            SELECT COUNT()
            FROM Comm_Log__c
            WHERE Direction__c = 'Inbound' AND Message_Id__c = :inboundMessageId
        ] > 0;
    }

    private static String resolveInboundBody(Messaging.InboundEmail email) {
        if (email == null) {
            return null;
        }
        if (String.isNotBlank(email.htmlBody)) {
            return email.htmlBody;
        }
        if (String.isNotBlank(email.plainTextBody)) {
            return '<pre>' + escapeHtml(email.plainTextBody) + '</pre>';
        }
        return null;
    }

    private static void saveInboundAttachments(Messaging.InboundEmail email, Id commLogId) {
        if (email == null || commLogId == null) {
            return;
        }
        List<ContentVersion> versions = new List<ContentVersion>();
        if (email.binaryAttachments != null) {
            for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                if (attachment == null || attachment.body == null || attachment.body.size() == 0) {
                    continue;
                }
                ContentVersion version = new ContentVersion();
                version.Title = stripFileExtension(resolveAttachmentName(attachment.fileName, 'attachment'));
                version.PathOnClient = resolveAttachmentName(attachment.fileName, 'attachment.bin');
                version.VersionData = attachment.body;
                version.FirstPublishLocationId = commLogId;
                versions.add(version);
            }
        }
        if (email.textAttachments != null) {
            for (Messaging.InboundEmail.TextAttachment attachment : email.textAttachments) {
                if (attachment == null || String.isBlank(attachment.body)) {
                    continue;
                }
                ContentVersion version = new ContentVersion();
                version.Title = stripFileExtension(resolveAttachmentName(attachment.fileName, 'attachment'));
                version.PathOnClient = resolveAttachmentName(attachment.fileName, 'attachment.txt');
                version.VersionData = Blob.valueOf(attachment.body);
                version.FirstPublishLocationId = commLogId;
                versions.add(version);
            }
        }
        if (!versions.isEmpty()) {
            insert versions;
        }
    }

    private static String resolveAttachmentName(String fileName, String fallback) {
        return String.isNotBlank(fileName) ? fileName.trim() : fallback;
    }

    private static String stripFileExtension(String fileName) {
        if (String.isBlank(fileName)) {
            return 'File';
        }
        Integer dotIndex = fileName.lastIndexOf('.');
        if (dotIndex <= 0) {
            return fileName;
        }
        return fileName.substring(0, dotIndex);
    }

    private static String resolveHeaderValue(Messaging.InboundEmail email, String headerName) {
        String fromHeaders = headerValue(email, headerName);
        if (String.isNotBlank(fromHeaders)) {
            return fromHeaders;
        }
        return extractHeaderFromBodies(email, headerName);
    }

    private static String headerValue(Messaging.InboundEmail email, String headerName) {
        if (email == null || email.headers == null || String.isBlank(headerName)) {
            return null;
        }
        for (Messaging.InboundEmail.Header header : email.headers) {
            if (header != null && header.name != null && header.name.equalsIgnoreCase(headerName)) {
                return header.value;
            }
        }
        return null;
    }

    private static String extractHeaderFromBodies(Messaging.InboundEmail email, String headerName) {
        if (email == null || String.isBlank(headerName)) {
            return null;
        }
        List<String> bodies = new List<String>();
        if (String.isNotBlank(email.plainTextBody)) {
            bodies.add(email.plainTextBody);
        }
        if (String.isNotBlank(email.htmlBody)) {
            bodies.add(email.htmlBody.replaceAll('<[^>]+>', ' '));
        }
        String headerPattern = '(?im)^\\s*' + Pattern.quote(headerName) + '\\s*:\\s*(.+)$';
        for (String body : bodies) {
            Matcher matcher = Pattern.compile(headerPattern).matcher(body);
            if (matcher.find()) {
                return matcher.group(1).trim();
            }
        }
        return null;
    }

    private static String normalizeMessageId(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String trimmed = rawValue.trim().replaceAll('[\\r\\n]+', '');
        if (trimmed.startsWith('<') && trimmed.endsWith('>')) {
            return trimmed;
        }
        if (trimmed.contains('@')) {
            return '<' + trimmed + '>';
        }
        return trimmed;
    }

    private static String stripMessageIdDecorations(String messageId) {
        if (String.isBlank(messageId)) {
            return null;
        }
        String trimmed = messageId.trim();
        if (trimmed.startsWith('<')) {
            trimmed = trimmed.substring(1);
        }
        if (trimmed.endsWith('>')) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        Integer atIndex = trimmed.indexOf('@');
        if (atIndex > 0) {
            return trimmed.substring(0, atIndex);
        }
        return trimmed;
    }

    private static String normalizeEmail(String email) {
        return String.isBlank(email) ? null : email.trim();
    }

    private static String normalizeEmailKey(String email) {
        if (String.isBlank(email)) {
            return '';
        }
        String normalized = email.trim().toLowerCase();
        Integer ltIndex = normalized.indexOf('<');
        Integer gtIndex = normalized.lastIndexOf('>');
        if (ltIndex > -1 && gtIndex > ltIndex) {
            normalized = normalized.substring(ltIndex + 1, gtIndex).trim();
        }
        return normalized;
    }

    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value) || maxLength == null || maxLength <= 0) {
            return value;
        }
        String trimmed = value.trim();
        return trimmed.length() <= maxLength ? trimmed : trimmed.substring(0, maxLength);
    }

    private static String escapeHtml(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;');
    }
}
