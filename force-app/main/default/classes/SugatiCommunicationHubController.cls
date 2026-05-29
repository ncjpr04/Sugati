public with sharing class SugatiCommunicationHubController {
    private static final Set<String> ALLOWED_ROOTS = new Set<String>{
        'Opportunity',
        'Owner',
        'Traveller',
        'LeadBooker',
        'ClientGroup',
        'Supplier',
        'SupplierContact',
        'SupplierBooking',
        'ClientPayment',
        'SupplierCostPayment'
    };
    private static final String EMAIL_CHANNEL = 'Email';
    private static final Integer MAX_TOKEN_FIELDS_PER_GROUP = 120;

    private class TokenRootConfig {
        String groupId;
        String groupLabel;
        String rootName;
        String sobjectApi;
        TokenRootConfig(String groupId, String groupLabel, String rootName, String sobjectApi) {
            this.groupId = groupId;
            this.groupLabel = groupLabel;
            this.rootName = rootName;
            this.sobjectApi = sobjectApi;
        }
    }

    public class HubContextDTO {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String stageLabel;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Integer sentCount;
        @AuraEnabled public Integer deliveredCount;
        @AuraEnabled public Integer openedCount;
        @AuraEnabled public Integer draftCount;
    }

    public class RecipientDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String initials;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String role;
        @AuraEnabled public String roleKey;
        @AuraEnabled public String status;
        @AuraEnabled public String statusKey;
        @AuraEnabled public Boolean selected;
        @AuraEnabled public String audience;
    }

    public class TemplateDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String subject;
        @AuraEnabled public String body;
        @AuraEnabled public String stage;
        @AuraEnabled public String type;
        @AuraEnabled public String channel;
        @AuraEnabled public String meta;
    }

    public class TokenGroupDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
    }

    public class TokenFieldDTO {
        @AuraEnabled public String name;
        @AuraEnabled public String api;
        @AuraEnabled public Boolean highlight;
    }

    public class TokenCatalogDTO {
        @AuraEnabled public List<TokenGroupDTO> groups;
        @AuraEnabled public Map<String, List<TokenFieldDTO>> fieldsByGroup;
    }

    public class HistoryItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String channel;
        @AuraEnabled public String subject;
        @AuraEnabled public String who;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime sentAt;
        @AuraEnabled public String sentBy;
        @AuraEnabled public Integer recipientCount;
        @AuraEnabled public Integer deliveredCount;
        @AuraEnabled public Integer openedCount;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public String deliveryMode;
        @AuraEnabled public Integer attachmentCount;
        @AuraEnabled public String attachmentSummary;
    }

    public class AttachmentDTO {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String name;
        @AuraEnabled public String meta;
        @AuraEnabled public String fileType;
        @AuraEnabled public Integer sizeBytes;
        @AuraEnabled public Boolean selected;
        @AuraEnabled public Boolean isPendingUpload;
    }

    public class PreviewRequest {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id templateId;
        @AuraEnabled public List<Id> recipientIds;
        @AuraEnabled public List<String> recipientEmails;
        @AuraEnabled public List<String> recipientNames;
        @AuraEnabled public String subjectTemplate;
        @AuraEnabled public String bodyTemplate;
    }

    public class PreviewResponse {
        @AuraEnabled public String subject;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public List<String> unresolvedTokens;
        @AuraEnabled public List<RecipientDTO> recipients;
        @AuraEnabled public Map<String, String> tokenValues;
    }

    public class SendRequest {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id templateId;
        @AuraEnabled public List<Id> recipientIds;
        @AuraEnabled public List<String> recipientEmails;
        @AuraEnabled public List<String> recipientNames;
        @AuraEnabled public String subjectTemplate;
        @AuraEnabled public String bodyTemplate;
        @AuraEnabled public String resolvedSubject;
        @AuraEnabled public String resolvedBodyHtml;
        @AuraEnabled public String deliveryMode;
        @AuraEnabled public String channel;
        @AuraEnabled public List<Id> attachmentContentDocumentIds;
        @AuraEnabled public List<String> newAttachmentFileNames;
        @AuraEnabled public List<String> newAttachmentFileData;
    }

    public class SendResponse {
        @AuraEnabled public Id commLogId;
        @AuraEnabled public String status;
        @AuraEnabled public String providerMessageId;
        @AuraEnabled public String message;
    }

    public class DraftRecipientInput {
        @AuraEnabled public Id commRecipientId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String email;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
    }

    public class DraftEditDTO {
        @AuraEnabled public Id commLogId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String subject;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public String deliveryMode;
        @AuraEnabled public List<DraftRecipientInput> recipients;
        @AuraEnabled public List<AttachmentDTO> attachments;
    }

    @AuraEnabled(cacheable=true)
    public static List<AttachmentDTO> getOpportunityAttachments(Id opportunityId) {
        if (opportunityId == null) {
            return new List<AttachmentDTO>();
        }
        return queryAttachmentLinks(new Set<Id>{ opportunityId }, null);
    }

    @AuraEnabled(cacheable=true)
    public static HubContextDTO getHubContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, StageName, Owner.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<AggregateResult> stats = [
            SELECT Status__c status, COUNT(Id) countRows
            FROM Comm_Log__c
            WHERE Opportunity__c = :opportunityId
            GROUP BY Status__c
        ];

        HubContextDTO dto = new HubContextDTO();
        dto.opportunityId = opp.Id;
        dto.opportunityName = opp.Name;
        dto.stageLabel = opp.StageName;
        dto.ownerName = opp.Owner != null ? opp.Owner.Name : null;
        dto.sentCount = 0;
        dto.deliveredCount = 0;
        dto.openedCount = 0;
        dto.draftCount = 0;

        for (AggregateResult row : stats) {
            String status = (String) row.get('status');
            Integer countValue = Integer.valueOf((Decimal) row.get('countRows'));
            if (status == 'Draft') {
                dto.draftCount += countValue;
            } else if (status == 'Sent') {
                dto.sentCount += countValue;
            } else if (status == 'Delivered') {
                dto.deliveredCount += countValue;
            } else if (status == 'Opened') {
                dto.openedCount += countValue;
            }
        }
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecipientDTO> getRecipients(Id opportunityId) {
        List<RecipientDTO> rows = new List<RecipientDTO>();
        Opportunity opp = [
            SELECT Id, sugati__O_Lead_CG__c, sugati__O_Booking_Contact__c, sugati__O_Agent__c, sugati__O_Agent_SC__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Id leadGroupMemberId;
        if (opp.sugati__O_Lead_CG__c != null) {
            List<sugati__Client_Group__c> cgs = [
                SELECT Id, sugati__CG_Lead_Group_Member__c
                FROM sugati__Client_Group__c
                WHERE Id = :opp.sugati__O_Lead_CG__c
                LIMIT 1
            ];
            if (!cgs.isEmpty()) {
                leadGroupMemberId = cgs[0].sugati__CG_Lead_Group_Member__c;
            }
        }

        List<sugati__Group_Member__c> travellers = [
            SELECT Id, Name, sugati__GM_Contact__c, sugati__GM_Contact__r.Name, sugati__GM_Contact__r.Email,
                sugati__GM_Email__c, sugati__GM_Phone__c, sugati__S_GM_Client_Group_Booking_Status__c,
                sugati__GM_Non_Travelling_Lead_Booker__c, sugati__GM_Client_Group__r.sugati__S_CG_Booking_Status__c
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opportunityId
            ORDER BY CreatedDate ASC
        ];
        for (sugati__Group_Member__c gm : travellers) {
            String displayName = gm.sugati__GM_Contact__r != null ? gm.sugati__GM_Contact__r.Name : gm.Name;
            String email = gm.sugati__GM_Contact__r != null ? gm.sugati__GM_Contact__r.Email : gm.sugati__GM_Email__c;
            String primaryStatus = gm.sugati__GM_Client_Group__r != null ? gm.sugati__GM_Client_Group__r.sugati__S_CG_Booking_Status__c : null;
            String secondaryStatus = gm.sugati__S_GM_Client_Group_Booking_Status__c;
            String statusLabel = normalizeStatusLabel(primaryStatus, secondaryStatus);
            RecipientDTO dto = new RecipientDTO();
            dto.id = gm.sugati__GM_Contact__c != null ? gm.sugati__GM_Contact__c : gm.Id;
            dto.name = displayName;
            dto.email = email;
            dto.initials = buildInitials(displayName);
            dto.role = (gm.Id == leadGroupMemberId || gm.sugati__GM_Non_Travelling_Lead_Booker__c) ? 'Lead Booker' : 'Traveller';
            dto.roleKey = dto.role == 'Lead Booker' ? 'lead' : 'traveller';
            dto.status = statusLabel;
            dto.statusKey = mapStatusKey(statusLabel);
            dto.selected = dto.roleKey == 'lead';
            dto.audience = 'travellers';
            rows.add(dto);
        }

        Set<Id> supplierIds = new Set<Id>();
        for (sugati__Opportunity_Supplier__c os : [
            SELECT Id, sugati__OS_Supplier__c, sugati__OS_Supplier__r.Name, sugati__OS_Supplier__r.sugati__S_Email__c
            FROM sugati__Opportunity_Supplier__c
            WHERE sugati__OS_Opportunity__c = :opportunityId
        ]) {
            if (os.sugati__OS_Supplier__c == null) {
                continue;
            }
            supplierIds.add(os.sugati__OS_Supplier__c);
            RecipientDTO dto = new RecipientDTO();
            dto.id = os.sugati__OS_Supplier__c;
            dto.name = os.sugati__OS_Supplier__r != null ? os.sugati__OS_Supplier__r.Name : 'Supplier';
            dto.email = os.sugati__OS_Supplier__r != null ? os.sugati__OS_Supplier__r.sugati__S_Email__c : null;
            dto.initials = buildInitials(dto.name);
            dto.role = 'Supplier';
            dto.roleKey = 'supplier';
            dto.status = 'Confirmed';
            dto.statusKey = 'booked';
            dto.selected = false;
            dto.audience = 'suppliers';
            rows.add(dto);
        }

        if (!supplierIds.isEmpty()) {
            for (sugati__Supplier_Contact__c sc : [
                SELECT Id, Name, sugati__SC_Name__c, sugati__SC_First_Name__c, sugati__SC_Last_Name__c,
                    sugati__SC_Email__c, sugati__SC_Supplier__r.Name, sugati__Type__c
                FROM sugati__Supplier_Contact__c
                WHERE sugati__SC_Supplier__c IN :supplierIds
                ORDER BY sugati__SC_Supplier__r.Name, Name
            ]) {
                String displayName = !String.isBlank(sc.sugati__SC_Name__c)
                    ? sc.sugati__SC_Name__c
                    : (!String.isBlank(sc.Name) ? sc.Name : ((sc.sugati__SC_First_Name__c == null ? '' : sc.sugati__SC_First_Name__c) + ' ' + (sc.sugati__SC_Last_Name__c == null ? '' : sc.sugati__SC_Last_Name__c)).trim());
                RecipientDTO dto = new RecipientDTO();
                dto.id = sc.Id;
                dto.name = displayName;
                dto.email = sc.sugati__SC_Email__c;
                dto.initials = buildInitials(displayName);
                dto.role = String.isBlank(sc.sugati__Type__c) ? 'Supplier Contact' : sc.sugati__Type__c;
                dto.roleKey = 'supplier';
                dto.status = 'Confirmed';
                dto.statusKey = 'booked';
                dto.selected = false;
                dto.audience = 'contacts';
                rows.add(dto);
            }
        }

        if (opp.sugati__O_Agent__c != null) {
            List<sugati__Supplier__c> agents = [
                SELECT Id, Name, sugati__S_Email__c
                FROM sugati__Supplier__c
                WHERE Id = :opp.sugati__O_Agent__c
                LIMIT 1
            ];
            if (!agents.isEmpty()) {
                RecipientDTO dto = new RecipientDTO();
                dto.id = agents[0].Id;
                dto.name = agents[0].Name;
                dto.email = agents[0].sugati__S_Email__c;
                dto.initials = buildInitials(dto.name);
                dto.role = 'Agent';
                dto.roleKey = 'agent';
                dto.status = 'Booked';
                dto.statusKey = 'booked';
                dto.selected = false;
                dto.audience = 'agents';
                rows.add(dto);
            }
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<TemplateDTO> getTemplates(Id opportunityId, String stage, String recipientType, String channel) {
        String useChannel = String.isBlank(channel) ? EMAIL_CHANNEL : channel;
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Comm_Template__c.fields.getMap();
        String activeFilter = buildTemplateActiveFilter(fieldsMap);

        String soql =
            'SELECT Id, Name, Subject__c, Body__c, Stage__c, Type__c, Channel__c ' +
            'FROM Comm_Template__c ' +
            'WHERE Channel__c = :useChannel ' +
            activeFilter;
        if (!String.isBlank(stage)) {
            soql += ' AND Stage__c = :stage';
        }
        if (!String.isBlank(recipientType)) {
            soql += ' AND Type__c = :recipientType';
        }
        soql += ' ORDER BY Name ASC';

        List<Comm_Template__c> rows = Database.query(soql);
        List<TemplateDTO> out = new List<TemplateDTO>();
        for (Comm_Template__c rec : rows) {
            TemplateDTO dto = new TemplateDTO();
            dto.id = rec.Id;
            dto.name = rec.Name;
            dto.subject = rec.Subject__c;
            dto.body = rec.Body__c;
            dto.stage = rec.Stage__c;
            dto.type = rec.Type__c;
            dto.channel = rec.Channel__c;
            dto.meta = String.join(new List<String>{ blankToDash(rec.Type__c), 'B2C', blankToDash(rec.Stage__c) }, ' · ');
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static TokenCatalogDTO getMergeTokens(Id opportunityId) {
        TokenCatalogDTO dto = new TokenCatalogDTO();
        dto.groups = new List<TokenGroupDTO>();
        dto.fieldsByGroup = new Map<String, List<TokenFieldDTO>>();
        for (TokenRootConfig cfg : tokenRootConfigs()) {
            addGroup(dto, cfg.groupId, cfg.groupLabel, buildFieldsForRoot(cfg.rootName, cfg.sobjectApi));
        }
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<HistoryItemDTO> getHistory(
        Id opportunityId,
        String channelFilter,
        String statusFilter,
        String audienceFilter,
        String statusGroupFilter
    ) {
        Set<Id> audienceLogIds = resolveAudienceLogIds(opportunityId, audienceFilter);
        if (audienceLogIds != null && audienceLogIds.isEmpty()) {
            return new List<HistoryItemDTO>();
        }

        Set<Id> issueLogIds = resolveIssueRecipientLogIds(opportunityId, statusGroupFilter);
        if (issueLogIds != null && issueLogIds.isEmpty()) {
            return new List<HistoryItemDTO>();
        }

        String soql =
            'SELECT Id, Channel__c, Subject__c, Status__c, Sent_At__c, Body_HTML__c, Delivery_Mode__c, Sent_By__r.Name ' +
            'FROM Comm_Log__c WHERE Opportunity__c = :opportunityId';
        if (!String.isBlank(channelFilter)) {
            soql += ' AND Channel__c = :channelFilter';
        }
        if (!String.isBlank(statusFilter)) {
            soql += ' AND Status__c = :statusFilter';
        }
        if (statusGroupFilter == 'delivered_opened') {
            soql += ' AND Status__c IN (\'Delivered\', \'Opened\')';
        }
        if (audienceLogIds != null) {
            soql += ' AND Id IN :audienceLogIds';
        }
        if (issueLogIds != null) {
            soql += ' AND Id IN :issueLogIds';
        }
        soql += ' ORDER BY Sent_At__c DESC NULLS LAST, CreatedDate DESC';

        List<Comm_Log__c> logs = Database.query(soql);
        if (logs.isEmpty()) {
            return new List<HistoryItemDTO>();
        }

        Set<Id> logIds = new Set<Id>();
        for (Comm_Log__c row : logs) {
            logIds.add(row.Id);
        }

        Map<Id, List<Comm_Recipient__c>> recipientsByLog = new Map<Id, List<Comm_Recipient__c>>();
        for (Comm_Recipient__c rec : [
            SELECT Id, Name, Comm_Log__c, Status__c, Contact__c, Contact__r.Name, Email_Address__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c IN :logIds
        ]) {
            if (!recipientsByLog.containsKey(rec.Comm_Log__c)) {
                recipientsByLog.put(rec.Comm_Log__c, new List<Comm_Recipient__c>());
            }
            recipientsByLog.get(rec.Comm_Log__c).add(rec);
        }

        Map<Id, List<AttachmentDTO>> attachmentsByLog = queryAttachmentsByParentIds(logIds);

        List<HistoryItemDTO> out = new List<HistoryItemDTO>();
        for (Comm_Log__c row : logs) {
            List<Comm_Recipient__c> recs = recipientsByLog.containsKey(row.Id) ? recipientsByLog.get(row.Id) : new List<Comm_Recipient__c>();
            Integer delivered = 0;
            Integer opened = 0;
            List<String> whoBits = new List<String>();
            for (Comm_Recipient__c rec : recs) {
                if (rec.Status__c == 'Delivered' || rec.Status__c == 'Opened') {
                    delivered++;
                }
                if (rec.Status__c == 'Opened') {
                    opened++;
                }
                String who = resolveRecipientDisplayName(rec);
                if (!String.isBlank(who)) {
                    whoBits.add(who);
                }
            }

            HistoryItemDTO dto = new HistoryItemDTO();
            dto.id = row.Id;
            dto.channel = row.Channel__c;
            dto.subject = row.Subject__c;
            dto.status = row.Status__c;
            dto.sentAt = row.Sent_At__c;
            dto.sentBy = row.Sent_By__r != null ? row.Sent_By__r.Name : null;
            dto.bodyHtml = row.Body_HTML__c;
            dto.deliveryMode = row.Delivery_Mode__c;
            dto.recipientCount = recs.size();
            dto.deliveredCount = delivered;
            dto.openedCount = opened;
            dto.who = whoBits.isEmpty() ? 'No recipients' : String.join(whoBits, '\n');
            List<AttachmentDTO> attachments = attachmentsByLog.containsKey(row.Id)
                ? attachmentsByLog.get(row.Id)
                : new List<AttachmentDTO>();
            dto.attachmentCount = attachments.size();
            dto.attachmentSummary = summarizeAttachmentNames(attachments);
            out.add(dto);
        }
        return out;
    }

    private static Set<Id> resolveAudienceLogIds(Id opportunityId, String audienceFilter) {
        if (String.isBlank(audienceFilter)) {
            return null;
        }
        Set<String> types = new Set<String>();
        if (audienceFilter == 'travellers') {
            types.add('Traveller');
        } else if (audienceFilter == 'suppliers') {
            types.add('Supplier');
            types.add('Agent');
        } else {
            return null;
        }
        Set<Id> logIds = new Set<Id>();
        for (Comm_Recipient__c rec : [
            SELECT Comm_Log__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__r.Opportunity__c = :opportunityId AND Recipient_Type__c IN :types
        ]) {
            logIds.add(rec.Comm_Log__c);
        }
        return logIds;
    }

    private static Set<Id> resolveIssueRecipientLogIds(Id opportunityId, String statusGroupFilter) {
        if (statusGroupFilter != 'failed_bounced') {
            return null;
        }
        Set<Id> logIds = new Set<Id>();
        for (Comm_Recipient__c rec : [
            SELECT Comm_Log__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__r.Opportunity__c = :opportunityId AND Status__c IN ('Failed', 'Bounced')
        ]) {
            logIds.add(rec.Comm_Log__c);
        }
        return logIds;
    }

    @AuraEnabled
    public static PreviewResponse previewMessage(PreviewRequest request) {
        validatePreviewRequest(request);
        Comm_Template__c template = request.templateId != null
            ? [SELECT Id, Subject__c, Body__c FROM Comm_Template__c WHERE Id = :request.templateId LIMIT 1]
            : null;

        String subjectTemplate = String.isBlank(request.subjectTemplate) && template != null ? template.Subject__c : request.subjectTemplate;
        String bodyTemplate = String.isBlank(request.bodyTemplate) && template != null ? template.Body__c : request.bodyTemplate;

        PreviewResponse response = new PreviewResponse();
        response.unresolvedTokens = new List<String>();
        response.recipients = recipientsByInputs(request.recipientIds, request.recipientEmails, request.recipientNames);
        Set<String> requestedTokens = extractTokenPaths(new List<String>{ subjectTemplate, bodyTemplate });
        Map<String, Set<String>> fieldsByRoot = fieldsByRoot(requestedTokens);
        SObject oppRow = queryOpportunityForPreview(request.opportunityId, fieldsByRoot.containsKey('Opportunity') ? fieldsByRoot.get('Opportunity') : new Set<String>());
        Map<String, String> tokenValues = buildTokenValues(request.opportunityId, oppRow, response.recipients, requestedTokens, fieldsByRoot);
        response.tokenValues = tokenValues;
        response.subject = resolveTemplate(subjectTemplate, tokenValues, response.unresolvedTokens);
        response.bodyHtml = resolveTemplate(bodyTemplate, tokenValues, response.unresolvedTokens);
        return response;
    }

    @AuraEnabled
    public static PreviewResponse previewMessageDirect(
        Id opportunityId,
        Id templateId,
        List<Id> recipientIds,
        List<String> recipientEmails,
        List<String> recipientNames,
        String subjectTemplate,
        String bodyTemplate
    ) {
        PreviewRequest request = new PreviewRequest();
        request.opportunityId = opportunityId;
        request.templateId = templateId;
        request.recipientIds = recipientIds == null ? new List<Id>() : recipientIds;
        request.recipientEmails = recipientEmails == null ? new List<String>() : recipientEmails;
        request.recipientNames = recipientNames == null ? new List<String>() : recipientNames;
        request.subjectTemplate = subjectTemplate;
        request.bodyTemplate = bodyTemplate;
        return previewMessage(request);
    }

    @AuraEnabled
    public static SendResponse sendMessage(SendRequest request) {
        validateSendRequest(request);
        PreviewResponse preview = previewMessage(new PreviewRequestBuilder(request).build());

        Comm_Log__c log = new Comm_Log__c();
        log.Opportunity__c = request.opportunityId;
        log.Channel__c = String.isBlank(request.channel) ? EMAIL_CHANNEL : request.channel;
        log.Direction__c = 'Outbound';
        log.Subject__c = preview.subject;
        log.Body_HTML__c = preview.bodyHtml;
        log.Sent_At__c = System.now();
        log.Sent_By__c = UserInfo.getUserId();
        log.Delivery_Mode__c = request.deliveryMode;
        log.Status__c = 'Sent';
        insert log;

        List<Comm_Recipient__c> recRows = new List<Comm_Recipient__c>();
        for (RecipientDTO recipient : preview.recipients) {
            Comm_Recipient__c rec = new Comm_Recipient__c();
            rec.Comm_Log__c = log.Id;
            rec.Contact__c = sanitizeContactId(recipient.id);
            rec.Name = resolveRecipientName(recipient.name, recipient.email);
            rec.Email_Address__c = recipient.email;
            rec.Recipient_Type__c = normalizeRecipientType(recipient.role);
            rec.Status__c = 'Sent';
            recRows.add(rec);
        }
        if (!recRows.isEmpty()) {
            insert recRows;
        }

        Set<Id> attachmentDocIds = buildAttachmentDocumentIdSet(
            request.attachmentContentDocumentIds,
            request.newAttachmentFileNames,
            request.newAttachmentFileData,
            log.Id,
            request.opportunityId
        );
        syncCommLogAttachments(log.Id, attachmentDocIds);

        String providerMessageId = 'LOCAL-' + String.valueOf(log.Id).right(10);
        Boolean providerOk = false;
        try {
            providerMessageId = sendViaPostmark(preview, recRows, request.deliveryMode);
            providerOk = true;
        } catch (Exception ex) {
            log.Status__c = 'Failed';
            update log;
            for (Comm_Recipient__c rec : recRows) {
                rec.Status__c = 'Failed';
            }
            if (!recRows.isEmpty()) {
                update recRows;
            }
            SendResponse failed = new SendResponse();
            failed.commLogId = log.Id;
            failed.status = 'Failed';
            failed.providerMessageId = null;
            failed.message = ex.getMessage();
            return failed;
        }

        if (providerOk) {
            for (Comm_Recipient__c rec : recRows) {
                rec.Status__c = 'Delivered';
                rec.Delivered_At__c = System.now();
                rec.Postmark_Id__c = providerMessageId;
            }
            if (!recRows.isEmpty()) {
                update recRows;
            }
            log.Status__c = 'Delivered';
            update log;
        }

        SendResponse response = new SendResponse();
        response.commLogId = log.Id;
        response.status = log.Status__c;
        response.providerMessageId = providerMessageId;
        response.message = 'Message logged and sent';
        return response;
    }

    @AuraEnabled
    public static DraftEditDTO getDraftForEdit(Id commLogId) {
        if (commLogId == null) {
            throw new AuraHandledException('Draft id is required.');
        }

        Comm_Log__c log = [
            SELECT Id, Opportunity__c, Subject__c, Body_HTML__c, Delivery_Mode__c, Status__c
            FROM Comm_Log__c
            WHERE Id = :commLogId
            LIMIT 1
        ];
        if (log.Status__c != 'Draft') {
            throw new AuraHandledException('Only draft messages can be edited.');
        }

        DraftEditDTO dto = new DraftEditDTO();
        dto.commLogId = log.Id;
        dto.opportunityId = log.Opportunity__c;
        dto.subject = log.Subject__c;
        dto.bodyHtml = log.Body_HTML__c;
        dto.deliveryMode = log.Delivery_Mode__c;
        dto.recipients = new List<DraftRecipientInput>();

        for (Comm_Recipient__c rec : [
            SELECT Id, Name, Contact__c, Contact__r.Name, Contact__r.Email, Email_Address__c, Recipient_Type__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :commLogId
            ORDER BY CreatedDate ASC
        ]) {
            DraftRecipientInput row = new DraftRecipientInput();
            row.commRecipientId = rec.Id;
            row.contactId = rec.Contact__c;
            row.email = rec.Contact__r != null && !String.isBlank(rec.Contact__r.Email)
                ? rec.Contact__r.Email
                : rec.Email_Address__c;
            row.name = resolveRecipientDisplayName(rec);
            row.role = rec.Recipient_Type__c;
            dto.recipients.add(row);
        }

        Set<Id> selectedDocIds = new Set<Id>();
        for (AttachmentDTO attachment : queryAttachmentLinks(new Set<Id>{ commLogId }, null)) {
            if (attachment.contentDocumentId != null) {
                selectedDocIds.add(attachment.contentDocumentId);
            }
        }
        List<AttachmentDTO> attachments = queryAttachmentLinks(
            new Set<Id>{ log.Opportunity__c },
            selectedDocIds
        );
        Set<Id> includedDocIds = new Set<Id>();
        for (AttachmentDTO row : attachments) {
            if (row.contentDocumentId != null) {
                includedDocIds.add(row.contentDocumentId);
            }
        }
        for (AttachmentDTO commLogFile : queryAttachmentLinks(new Set<Id>{ commLogId }, selectedDocIds)) {
            if (commLogFile.contentDocumentId != null && !includedDocIds.contains(commLogFile.contentDocumentId)) {
                commLogFile.selected = true;
                attachments.add(commLogFile);
                includedDocIds.add(commLogFile.contentDocumentId);
            }
        }
        dto.attachments = attachments;
        return dto;
    }

    @AuraEnabled
    public static void discardDraftDirect(Id commLogId) {
        if (commLogId == null) {
            throw new AuraHandledException('Draft id is required.');
        }

        Comm_Log__c log = [
            SELECT Id, Status__c
            FROM Comm_Log__c
            WHERE Id = :commLogId
            LIMIT 1
        ];
        if (log.Status__c != 'Draft') {
            throw new AuraHandledException('Only draft messages can be discarded.');
        }

        List<Comm_Recipient__c> recipients = [
            SELECT Id
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :commLogId
        ];
        if (!recipients.isEmpty()) {
            delete recipients;
        }
        deleteContentDocumentLinksForParents(new Set<Id>{ commLogId });
        delete log;
    }

    @AuraEnabled
    public static SendResponse saveDraftDirect(
        Id commLogId,
        Id opportunityId,
        Id templateId,
        List<Id> recipientRowIds,
        List<Id> recipientContactIds,
        List<String> recipientEmails,
        List<String> recipientNames,
        List<String> recipientRoles,
        String subjectTemplate,
        String bodyTemplate,
        String deliveryMode,
        String channel,
        List<Id> attachmentContentDocumentIds,
        List<String> newAttachmentFileNames,
        List<String> newAttachmentFileData
    ) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity is required to save a draft.');
        }

        List<DraftRecipientInput> recipients = buildDraftRecipientInputs(
            recipientRowIds,
            recipientContactIds,
            recipientEmails,
            recipientNames,
            recipientRoles
        );

        Comm_Log__c log;
        if (commLogId != null) {
            log = [
                SELECT Id, Status__c
                FROM Comm_Log__c
                WHERE Id = :commLogId
                LIMIT 1
            ];
            if (log.Status__c != 'Draft') {
                throw new AuraHandledException('Only draft messages can be updated.');
            }
            log.Subject__c = subjectTemplate;
            log.Body_HTML__c = bodyTemplate;
            log.Delivery_Mode__c = deliveryMode;
            log.Sent_By__c = UserInfo.getUserId();
            update log;
            syncDraftRecipients(log.Id, recipients == null ? new List<DraftRecipientInput>() : recipients);
        } else {
            log = new Comm_Log__c();
            log.Opportunity__c = opportunityId;
            log.Channel__c = String.isBlank(channel) ? EMAIL_CHANNEL : channel;
            log.Direction__c = 'Outbound';
            log.Subject__c = subjectTemplate;
            log.Body_HTML__c = bodyTemplate;
            log.Sent_By__c = UserInfo.getUserId();
            log.Delivery_Mode__c = deliveryMode;
            log.Status__c = 'Draft';
            insert log;
            insertDraftRecipients(log.Id, recipients == null ? new List<DraftRecipientInput>() : recipients);
        }

        Set<Id> attachmentDocIds = buildAttachmentDocumentIdSet(
            attachmentContentDocumentIds,
            newAttachmentFileNames,
            newAttachmentFileData,
            log.Id,
            opportunityId
        );
        syncCommLogAttachments(log.Id, attachmentDocIds);

        SendResponse response = new SendResponse();
        response.commLogId = log.Id;
        response.status = 'Draft';
        response.message = 'Draft saved';
        return response;
    }

    private static void syncDraftRecipients(Id commLogId, List<DraftRecipientInput> recipients) {
        List<Comm_Recipient__c> existing = [
            SELECT Id
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :commLogId
        ];
        Set<Id> keepIds = new Set<Id>();
        List<Comm_Recipient__c> toInsert = new List<Comm_Recipient__c>();
        List<Comm_Recipient__c> toUpdate = new List<Comm_Recipient__c>();

        for (DraftRecipientInput input : recipients) {
            if (input == null) {
                continue;
            }
            if (input.commRecipientId != null) {
                keepIds.add(input.commRecipientId);
                Comm_Recipient__c updated = buildDraftRecipientRow(commLogId, input);
                if (updated != null) {
                    updated.Id = input.commRecipientId;
                    toUpdate.add(updated);
                }
                continue;
            }
            Comm_Recipient__c rec = buildDraftRecipientRow(commLogId, input);
            if (rec != null) {
                toInsert.add(rec);
            }
        }

        List<Comm_Recipient__c> toDelete = new List<Comm_Recipient__c>();
        for (Comm_Recipient__c row : existing) {
            if (!keepIds.contains(row.Id)) {
                toDelete.add(row);
            }
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    private static void insertDraftRecipients(Id commLogId, List<DraftRecipientInput> recipients) {
        List<Comm_Recipient__c> toInsert = new List<Comm_Recipient__c>();
        for (DraftRecipientInput input : recipients) {
            if (input == null) {
                continue;
            }
            Comm_Recipient__c rec = buildDraftRecipientRow(commLogId, input);
            if (rec != null) {
                toInsert.add(rec);
            }
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    private static Comm_Recipient__c buildDraftRecipientRow(Id commLogId, DraftRecipientInput input) {
        if (String.isBlank(input.email) && input.contactId == null) {
            return null;
        }
        Comm_Recipient__c rec = new Comm_Recipient__c();
        rec.Comm_Log__c = commLogId;
        rec.Contact__c = sanitizeContactId(input.contactId);
        rec.Name = resolveRecipientName(input.name, input.email);
        rec.Email_Address__c = input.email;
        rec.Recipient_Type__c = normalizeRecipientType(input.role);
        rec.Status__c = 'Queued';
        return rec;
    }

    private static List<DraftRecipientInput> buildDraftRecipientInputs(
        List<Id> recipientRowIds,
        List<Id> recipientContactIds,
        List<String> recipientEmails,
        List<String> recipientNames,
        List<String> recipientRoles
    ) {
        List<DraftRecipientInput> out = new List<DraftRecipientInput>();
        Integer count = recipientEmails == null ? 0 : recipientEmails.size();
        for (Integer i = 0; i < count; i++) {
            String email = listStringAt(recipientEmails, i);
            if (String.isBlank(email) && listIdAt(recipientContactIds, i) == null) {
                continue;
            }
            DraftRecipientInput input = new DraftRecipientInput();
            input.commRecipientId = listIdAt(recipientRowIds, i);
            input.contactId = sanitizeContactId(listIdAt(recipientContactIds, i));
            input.email = email;
            input.name = listStringAt(recipientNames, i);
            input.role = listStringAt(recipientRoles, i);
            out.add(input);
        }
        return out;
    }

    private static Id listIdAt(List<Id> values, Integer index) {
        if (values == null || index < 0 || index >= values.size()) {
            return null;
        }
        return values[index];
    }

    private static String listStringAt(List<String> values, Integer index) {
        if (values == null || index < 0 || index >= values.size()) {
            return '';
        }
        return values[index] == null ? '' : values[index];
    }

    private static Id sanitizeContactId(Id recordId) {
        if (recordId == null) {
            return null;
        }
        try {
            if (recordId.getSObjectType() == Contact.SObjectType) {
                return recordId;
            }
        } catch (Exception ex) {
            return null;
        }
        return null;
    }

    private static String resolveRecipientName(String name, String email) {
        if (!String.isBlank(name)) {
            return name.trim();
        }
        return email;
    }

    private static String resolveRecipientDisplayName(Comm_Recipient__c rec) {
        if (rec == null) {
            return '';
        }
        if (!String.isBlank(rec.Name)) {
            return rec.Name.trim();
        }
        if (rec.Contact__c != null && rec.Contact__r != null && !String.isBlank(rec.Contact__r.Name)) {
            return rec.Contact__r.Name;
        }
        return rec.Email_Address__c;
    }

    private class PreviewRequestBuilder {
        private SendRequest source;
        PreviewRequestBuilder(SendRequest req) {
            source = req;
        }
        PreviewRequest build() {
            PreviewRequest req = new PreviewRequest();
            req.opportunityId = source.opportunityId;
            req.templateId = source.templateId;
            req.recipientIds = source.recipientIds;
            req.recipientEmails = source.recipientEmails;
            req.recipientNames = source.recipientNames;
            req.subjectTemplate = source.subjectTemplate;
            req.bodyTemplate = source.bodyTemplate;
            return req;
        }
    }

    private static String sendViaPostmark(PreviewResponse preview, List<Comm_Recipient__c> recipients, String deliveryMode) {
        if (deliveryMode == 'native') {
            return 'NATIVE-' + String.valueOf(Crypto.getRandomLong()).replace('-', '');
        }
        if (recipients.isEmpty()) {
            return 'NO-RECIPIENTS';
        }

        List<String> toEmails = new List<String>();
        for (Comm_Recipient__c rec : recipients) {
            if (!String.isBlank(rec.Email_Address__c)) {
                toEmails.add(rec.Email_Address__c);
            }
        }
        if (toEmails.isEmpty()) {
            return 'NO-EMAIL';
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Postmark_NC/email');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        Map<String, Object> payload = new Map<String, Object>{
            'From' => UserInfo.getUserEmail(),
            'To' => String.join(toEmails, ','),
            'Subject' => preview.subject,
            'HtmlBody' => preview.bodyHtml
        };
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() > 299) {
            throw new AuraHandledException('Postmark send failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return body != null && body.containsKey('MessageID') ? String.valueOf(body.get('MessageID')) : 'POSTMARK-SENT';
    }

    private static Map<String, String> buildTokenValues(
        Id opportunityId,
        SObject oppRow,
        List<RecipientDTO> selectedRecipients,
        Set<String> requestedTokens,
        Map<String, Set<String>> requestedByRoot
    ) {
        Map<String, String> values = new Map<String, String>();
        if (requestedTokens == null || requestedTokens.isEmpty()) {
            return values;
        }

        Set<Id> selectedIds = new Set<Id>();
        if (selectedRecipients != null) {
            for (RecipientDTO rec : selectedRecipients) {
                if (rec != null && rec.id != null) {
                    selectedIds.add(rec.id);
                }
            }
        }

        Map<String, SObject> rootRows = new Map<String, SObject>();
        rootRows.put('Opportunity', oppRow);

        if (requestedByRoot.containsKey('Owner') && oppRow != null) {
            Id ownerId = (Id) oppRow.get('OwnerId');
            if (ownerId != null) {
                SObject ownerRow = queryOneById('User', ownerId, requestedByRoot.get('Owner'));
                if (ownerRow != null) {
                    rootRows.put('Owner', ownerRow);
                }
            }
        }

        if (requestedByRoot.containsKey('Traveller')) {
            rootRows.put('Traveller', queryTraveller(opportunityId, selectedIds, requestedByRoot.get('Traveller')));
        }

        Id leadCgId = oppRow != null ? (Id) oppRow.get('sugati__O_Lead_CG__c') : null;
        SObject clientGroup = null;
        if (leadCgId != null && (requestedByRoot.containsKey('ClientGroup') || requestedByRoot.containsKey('LeadBooker'))) {
            Set<String> cgFields = new Set<String>();
            if (requestedByRoot.containsKey('ClientGroup')) {
                cgFields.addAll(requestedByRoot.get('ClientGroup'));
            }
            cgFields.add('sugati__CG_Lead_Group_Member__c');
            clientGroup = queryOneById('sugati__Client_Group__c', leadCgId, cgFields);
            if (clientGroup != null && requestedByRoot.containsKey('ClientGroup')) {
                rootRows.put('ClientGroup', clientGroup);
            }
        }

        if (requestedByRoot.containsKey('LeadBooker') && clientGroup != null) {
            Id leadGmId = (Id) clientGroup.get('sugati__CG_Lead_Group_Member__c');
            if (leadGmId != null) {
                rootRows.put('LeadBooker', queryOneById('sugati__Group_Member__c', leadGmId, requestedByRoot.get('LeadBooker')));
            }
        }

        Id supplierId = queryPrimarySupplierId(opportunityId);
        if (supplierId != null && requestedByRoot.containsKey('Supplier')) {
            rootRows.put('Supplier', queryOneById('sugati__Supplier__c', supplierId, requestedByRoot.get('Supplier')));
        }
        if (supplierId != null && requestedByRoot.containsKey('SupplierContact')) {
            rootRows.put('SupplierContact', querySupplierContact(supplierId, requestedByRoot.get('SupplierContact')));
        }
        if (requestedByRoot.containsKey('SupplierBooking')) {
            rootRows.put('SupplierBooking', queryByOpportunity('sugati__Supplier_Booking__c', 'sugati__SB_Opportunity__c', opportunityId, requestedByRoot.get('SupplierBooking')));
        }
        if (requestedByRoot.containsKey('ClientPayment')) {
            rootRows.put('ClientPayment', queryByOpportunity('sugati__Client_Payment__c', 'sugati__CP_Opportunity__c', opportunityId, requestedByRoot.get('ClientPayment')));
        }
        if (requestedByRoot.containsKey('SupplierCostPayment')) {
            rootRows.put('SupplierCostPayment', queryByOpportunity('sugati__Supplier_Cost_Payment__c', 'sugati__SCP_Opportunity__c', opportunityId, requestedByRoot.get('SupplierCostPayment')));
        }

        for (String tokenPath : requestedTokens) {
            if (!isAllowedToken(tokenPath)) {
                continue;
            }
            List<String> bits = tokenPath.split('\\.');
            if (bits.size() < 2) {
                continue;
            }
            String root = bits[0];
            SObject row = rootRows.get(root);
            values.put(tokenPath, resolveValueFromRow(row, tokenPath));
        }
        return values;
    }

    private static SObject queryOpportunityForPreview(Id opportunityId, Set<String> requestedFields) {
        Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
        Set<String> wanted = new Set<String>{
            'Id',
            'OwnerId',
            'sugati__O_Lead_CG__c'
        };
        if (requestedFields != null) {
            wanted.addAll(requestedFields);
        }

        List<String> selectFields = new List<String>();
        for (String candidate : wanted) {
            if (oppFields.containsKey(candidate)) {
                selectFields.add(candidate);
            }
        }

        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM Opportunity WHERE Id = :opportunityId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static String resolveValueFromRow(SObject row, String tokenPath) {
        if (row == null || String.isBlank(tokenPath)) {
            return '';
        }
        List<String> bits = tokenPath.split('\\.');
        if (bits.isEmpty()) {
            return '';
        }

        SObject cursor = row;
        for (Integer i = 1; i < bits.size(); i++) {
            String bit = bits[i];
            Boolean isLeaf = i == bits.size() - 1;
            if (isLeaf) {
                Map<String, Schema.SObjectField> fields = cursor.getSObjectType().getDescribe().fields.getMap();
                if (!fields.containsKey(bit)) {
                    return '';
                }
                try {
                    Object val = cursor.get(bit);
                    return val == null ? '' : String.valueOf(val);
                } catch (Exception ex) {
                    return '';
                }
            }
            try {
                SObject related = cursor.getSObject(bit);
                if (related == null) {
                    return '';
                }
                cursor = related;
            } catch (Exception ex) {
                return '';
            }
        }
        return '';
    }

    private static String resolveTemplate(String input, Map<String, String> tokenValues, List<String> unresolved) {
        if (String.isBlank(input)) {
            return '';
        }
        List<String> chunks = new List<String>();
        Set<String> seenUnresolved = new Set<String>();
        Integer pos = 0;
        while (pos < input.length()) {
            Integer openIdx = input.indexOf('{{', pos);
            if (openIdx < 0) {
                chunks.add(input.substring(pos));
                break;
            }
            Integer closeIdx = input.indexOf('}}', openIdx + 2);
            if (closeIdx < 0) {
                chunks.add(input.substring(pos));
                break;
            }
            chunks.add(input.substring(pos, openIdx));
            String rawToken = input.substring(openIdx + 2, closeIdx);
            String tokenPath = normalizeTokenPath(rawToken);
            if (!isAllowedToken(tokenPath)) {
                if (!seenUnresolved.contains(tokenPath)) {
                    unresolved.add(tokenPath);
                    seenUnresolved.add(tokenPath);
                }
                pos = closeIdx + 2;
                continue;
            }
            String replacement = '';
            if (tokenValues.containsKey(tokenPath)) {
                replacement = tokenValues.get(tokenPath);
            }
            if (String.isBlank(replacement) && !seenUnresolved.contains(tokenPath)) {
                unresolved.add(tokenPath);
                seenUnresolved.add(tokenPath);
            }
            chunks.add(replacement == null ? '' : replacement);
            pos = closeIdx + 2;
        }
        return String.join(chunks, '');
    }

    private static Boolean isAllowedToken(String tokenPath) {
        if (String.isBlank(tokenPath)) {
            return false;
        }
        List<String> bits = tokenPath.split('\\.');
        if (bits.isEmpty()) {
            return false;
        }
        return ALLOWED_ROOTS.contains(bits[0]);
    }

    private static String normalizeTokenPath(String tokenPath) {
        if (String.isBlank(tokenPath)) {
            return '';
        }
        String compact = tokenPath.replaceAll('\\s+', '');
        return compact.replaceAll('[^A-Za-z0-9_\\.]', '');
    }

    private static List<RecipientDTO> recipientsByInputs(List<Id> ids, List<String> emails, List<String> names) {
        List<RecipientDTO> out = new List<RecipientDTO>();
        Map<Id, Contact> contactsById = new Map<Id, Contact>();
        if (ids != null && !ids.isEmpty()) {
            contactsById = new Map<Id, Contact>([
                SELECT Id, Name, Email
                FROM Contact
                WHERE Id IN :ids
            ]);
            for (Id idValue : ids) {
                if (!contactsById.containsKey(idValue)) {
                    continue;
                }
                Contact c = contactsById.get(idValue);
                RecipientDTO dto = new RecipientDTO();
                dto.id = c.Id;
                dto.name = c.Name;
                dto.email = c.Email;
                dto.initials = buildInitials(c.Name);
                dto.role = 'Traveller';
                dto.roleKey = 'traveller';
                dto.status = 'Booked';
                dto.statusKey = 'booked';
                dto.selected = true;
                dto.audience = 'travellers';
                out.add(dto);
            }
        }

        Set<String> existingEmails = new Set<String>();
        for (RecipientDTO dto : out) {
            if (!String.isBlank(dto.email)) {
                existingEmails.add(dto.email.toLowerCase());
            }
        }

        if (emails != null) {
            for (Integer i = 0; i < emails.size(); i++) {
                String email = emails[i];
                if (String.isBlank(email)) {
                    continue;
                }
                String normalized = email.toLowerCase();
                if (existingEmails.contains(normalized)) {
                    continue;
                }
                RecipientDTO dto = new RecipientDTO();
                dto.id = null;
                dto.email = email;
                dto.name = (names != null && i < names.size()) ? names[i] : email;
                dto.initials = buildInitials(dto.name);
                dto.role = 'External';
                dto.roleKey = 'traveller';
                dto.status = 'Booked';
                dto.statusKey = 'booked';
                dto.selected = true;
                dto.audience = 'travellers';
                out.add(dto);
                existingEmails.add(normalized);
            }
        }
        return out;
    }

    private static List<TokenRootConfig> tokenRootConfigs() {
        return new List<TokenRootConfig>{
            new TokenRootConfig('opportunity', 'Opportunity', 'Opportunity', 'Opportunity'),
            new TokenRootConfig('owner', 'Owner', 'Owner', 'User'),
            new TokenRootConfig('traveller', 'Traveller', 'Traveller', 'sugati__Group_Member__c'),
            new TokenRootConfig('lead', 'Lead Booker', 'LeadBooker', 'sugati__Group_Member__c'),
            new TokenRootConfig('client', 'Client Group', 'ClientGroup', 'sugati__Client_Group__c'),
            new TokenRootConfig('supplier', 'Supplier', 'Supplier', 'sugati__Supplier__c'),
            new TokenRootConfig('supcontact', 'Supplier Contact', 'SupplierContact', 'sugati__Supplier_Contact__c'),
            new TokenRootConfig('supbooking', 'Supplier Booking', 'SupplierBooking', 'sugati__Supplier_Booking__c'),
            new TokenRootConfig('clientpayment', 'Client Payment', 'ClientPayment', 'sugati__Client_Payment__c'),
            new TokenRootConfig('suppliercost', 'Supplier Cost Payment', 'SupplierCostPayment', 'sugati__Supplier_Cost_Payment__c')
        };
    }

    private static List<TokenFieldDTO> buildFieldsForRoot(String rootName, String sobjectApi) {
        Map<String, Schema.SObjectType> allTypes = Schema.getGlobalDescribe();
        if (!allTypes.containsKey(sobjectApi)) {
            return new List<TokenFieldDTO>();
        }
        Map<String, Schema.SObjectField> fields = allTypes.get(sobjectApi).getDescribe().fields.getMap();
        List<String> apiNames = new List<String>(fields.keySet());
        apiNames.sort();

        List<TokenFieldDTO> out = new List<TokenFieldDTO>();
        for (String apiName : apiNames) {
            Schema.DescribeFieldResult dfr = fields.get(apiName).getDescribe();
            if (!dfr.isAccessible() || !isSupportedTokenType(dfr.getType())) {
                continue;
            }
            String exactApiName = dfr.getName();
            out.add(new TokenFieldDTO());
            out[out.size() - 1].name = dfr.getLabel();
            out[out.size() - 1].api = rootName + '.' + exactApiName;
            out[out.size() - 1].highlight = dfr.isNameField();
            if (out.size() >= MAX_TOKEN_FIELDS_PER_GROUP) {
                break;
            }
        }
        return out;
    }

    private static Boolean isSupportedTokenType(Schema.DisplayType dt) {
        return dt == Schema.DisplayType.String
            || dt == Schema.DisplayType.TextArea
            || dt == Schema.DisplayType.Email
            || dt == Schema.DisplayType.Phone
            || dt == Schema.DisplayType.Url
            || dt == Schema.DisplayType.Currency
            || dt == Schema.DisplayType.Double
            || dt == Schema.DisplayType.Integer
            || dt == Schema.DisplayType.Percent
            || dt == Schema.DisplayType.Date
            || dt == Schema.DisplayType.DateTime
            || dt == Schema.DisplayType.Boolean
            || dt == Schema.DisplayType.Picklist
            || dt == Schema.DisplayType.MultiPicklist
            || dt == Schema.DisplayType.Reference
            || dt == Schema.DisplayType.Id;
    }

    private static Set<String> extractTokenPaths(List<String> templates) {
        Set<String> out = new Set<String>();
        if (templates == null) {
            return out;
        }
        for (String input : templates) {
            if (String.isBlank(input)) {
                continue;
            }
            Integer pos = 0;
            while (pos < input.length()) {
                Integer openIdx = input.indexOf('{{', pos);
                if (openIdx < 0) {
                    break;
                }
                Integer closeIdx = input.indexOf('}}', openIdx + 2);
                if (closeIdx < 0) {
                    break;
                }
                String token = normalizeTokenPath(input.substring(openIdx + 2, closeIdx));
                out.add(token);
                pos = closeIdx + 2;
            }
        }
        return out;
    }

    private static Map<String, Set<String>> fieldsByRoot(Set<String> tokenPaths) {
        Map<String, Set<String>> out = new Map<String, Set<String>>();
        if (tokenPaths == null) {
            return out;
        }
        for (String tokenPath : tokenPaths) {
            if (!isAllowedToken(tokenPath)) {
                continue;
            }
            List<String> bits = tokenPath.split('\\.');
            if (bits.size() < 2) {
                continue;
            }
            String root = bits[0];
            if (!out.containsKey(root)) {
                out.put(root, new Set<String>());
            }
            out.get(root).add(bits[1]);
        }
        return out;
    }

    private static SObject queryOneById(String sobjectApi, Id recordId, Set<String> requestedFields) {
        if (recordId == null) {
            return null;
        }
        List<String> selectFields = buildSelectFields(sobjectApi, requestedFields, new Set<String>{ 'Id' });
        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM ' + sobjectApi + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static SObject queryByOpportunity(String sobjectApi, String opportunityFieldApi, Id opportunityId, Set<String> requestedFields) {
        List<String> selectFields = buildSelectFields(sobjectApi, requestedFields, new Set<String>{ 'Id' });
        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM ' + sobjectApi +
            ' WHERE ' + opportunityFieldApi + ' = :opportunityId ORDER BY CreatedDate ASC LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static SObject queryTraveller(Id opportunityId, Set<Id> selectedIds, Set<String> requestedFields) {
        List<String> required = new List<String>{ 'Id', 'sugati__GM_Opportunity__c', 'sugati__GM_Contact__c' };
        List<String> selectFields = buildSelectFields('sugati__Group_Member__c', requestedFields, new Set<String>(required));
        String soql = 'SELECT ' + String.join(selectFields, ',') +
            ' FROM sugati__Group_Member__c WHERE sugati__GM_Opportunity__c = :opportunityId';
        if (selectedIds != null && !selectedIds.isEmpty()) {
            soql += ' AND (Id IN :selectedIds OR sugati__GM_Contact__c IN :selectedIds)';
        }
        soql += ' ORDER BY CreatedDate ASC LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static Id queryPrimarySupplierId(Id opportunityId) {
        List<sugati__Opportunity_Supplier__c> rows = [
            SELECT sugati__OS_Supplier__c
            FROM sugati__Opportunity_Supplier__c
            WHERE sugati__OS_Opportunity__c = :opportunityId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].sugati__OS_Supplier__c;
    }

    private static SObject querySupplierContact(Id supplierId, Set<String> requestedFields) {
        List<String> selectFields = buildSelectFields('sugati__Supplier_Contact__c', requestedFields, new Set<String>{ 'Id' });
        String soql = 'SELECT ' + String.join(selectFields, ',') +
            ' FROM sugati__Supplier_Contact__c WHERE sugati__SC_Supplier__c = :supplierId ORDER BY CreatedDate ASC LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<String> buildSelectFields(String sobjectApi, Set<String> requestedFields, Set<String> requiredFields) {
        Map<String, Schema.SObjectType> allTypes = Schema.getGlobalDescribe();
        if (!allTypes.containsKey(sobjectApi)) {
            return new List<String>{ 'Id' };
        }
        Map<String, Schema.SObjectField> fields = allTypes.get(sobjectApi).getDescribe().fields.getMap();
        Set<String> selected = new Set<String>();
        if (requiredFields != null) {
            selected.addAll(requiredFields);
        }
        if (requestedFields != null) {
            for (String api : requestedFields) {
                if (fields.containsKey(api)) {
                    selected.add(api);
                }
            }
        }
        if (!selected.contains('Id')) {
            selected.add('Id');
        }
        List<String> out = new List<String>();
        out.addAll(selected);
        out.sort();
        return out;
    }

    private static void addGroup(TokenCatalogDTO dto, String idValue, String labelValue, List<TokenFieldDTO> fields) {
        TokenGroupDTO tokenGroup = new TokenGroupDTO();
        tokenGroup.id = idValue;
        tokenGroup.label = labelValue;
        tokenGroup.count = fields.size();
        dto.groups.add(tokenGroup);
        dto.fieldsByGroup.put(idValue, fields);
    }

    private static String buildTemplateActiveFilter(Map<String, Schema.SObjectField> fieldsMap) {
        if (fieldsMap.containsKey('Is_Active__c')) {
            return ' AND Is_Active__c = true';
        }
        if (fieldsMap.containsKey('Template_Status__c')) {
            return ' AND Template_Status__c = \'Active\'';
        }
        return '';
    }

    private static String blankToDash(String value) {
        return String.isBlank(value) ? '-' : value;
    }

    private static String blankSafe(String value) {
        return String.isBlank(value) ? '' : value;
    }

    private static String normalizeStatusLabel(String primaryStatus, String secondaryStatus) {
        String pick = !String.isBlank(primaryStatus) ? primaryStatus : secondaryStatus;
        if (String.isBlank(pick)) {
            return 'Booked';
        }
        String s = pick.trim().toLowerCase();
        if (s.contains('on request') || s.contains('requested')) {
            return 'On Request';
        }
        if (s.contains('waiting')) {
            return 'Waiting List';
        }
        if (s.contains('cancel')) {
            return 'Cancelled';
        }
        if (s.contains('enquiry')) {
            return 'Enquiry';
        }
        if (s.contains('book')) {
            return 'Booked';
        }
        return pick;
    }

    private static String mapStatusKey(String label) {
        String s = String.isBlank(label) ? '' : label.toLowerCase();
        if (s.contains('on request') || s.contains('requested')) {
            return 'request';
        }
        if (s.contains('waiting')) {
            return 'waiting';
        }
        if (s.contains('cancel')) {
            return 'cancelled';
        }
        if (s.contains('book')) {
            return 'booked';
        }
        return 'booked';
    }

    private static final Integer MAX_ATTACHMENT_BYTES = 4500000;

    private static List<AttachmentDTO> queryAttachmentLinks(Set<Id> parentIds, Set<Id> selectedDocIds) {
        List<AttachmentDTO> out = new List<AttachmentDTO>();
        if (parentIds == null || parentIds.isEmpty()) {
            return out;
        }
        Set<Id> selected = selectedDocIds == null ? new Set<Id>() : selectedDocIds;
        for (ContentDocumentLink link : [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileExtension,
                ContentDocument.ContentSize,
                ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :parentIds
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            if (link.ContentDocumentId == null) {
                continue;
            }
            AttachmentDTO dto = mapContentDocumentToAttachment(link.ContentDocument, selected.contains(link.ContentDocumentId));
            if (dto != null) {
                out.add(dto);
            }
        }
        return out;
    }

    private static Map<Id, List<AttachmentDTO>> queryAttachmentsByParentIds(Set<Id> parentIds) {
        Map<Id, List<AttachmentDTO>> out = new Map<Id, List<AttachmentDTO>>();
        if (parentIds == null || parentIds.isEmpty()) {
            return out;
        }
        for (ContentDocumentLink link : [
            SELECT
                LinkedEntityId,
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileExtension,
                ContentDocument.ContentSize
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :parentIds
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            if (link.LinkedEntityId == null || link.ContentDocumentId == null) {
                continue;
            }
            if (!out.containsKey(link.LinkedEntityId)) {
                out.put(link.LinkedEntityId, new List<AttachmentDTO>());
            }
            AttachmentDTO dto = mapContentDocumentToAttachment(link.ContentDocument, true);
            if (dto != null) {
                out.get(link.LinkedEntityId).add(dto);
            }
        }
        return out;
    }

    private static AttachmentDTO mapContentDocumentToAttachment(ContentDocument doc, Boolean selected) {
        if (doc == null) {
            return null;
        }
        AttachmentDTO dto = new AttachmentDTO();
        dto.contentDocumentId = doc.Id;
        dto.name = buildFileDisplayName(doc.Title, doc.FileExtension);
        dto.meta = formatAttachmentMeta(doc.ContentSize);
        dto.fileType = inferAttachmentFileType(doc.FileExtension);
        dto.sizeBytes = doc.ContentSize == null ? 0 : Integer.valueOf(doc.ContentSize);
        dto.selected = selected == true;
        dto.isPendingUpload = false;
        return dto;
    }

    private static String buildFileDisplayName(String title, String extension) {
        String base = String.isBlank(title) ? 'File' : title.trim();
        if (String.isBlank(extension)) {
            return base;
        }
        String ext = extension.trim().toLowerCase();
        if (base.toLowerCase().endsWith('.' + ext)) {
            return base;
        }
        return base + '.' + ext;
    }

    private static String formatAttachmentMeta(Integer contentSize) {
        if (contentSize == null) {
            return 'File';
        }
        Integer bytes = contentSize;
        if (bytes < 1024) {
            return bytes + ' B';
        }
        if (bytes < 1024 * 1024) {
            return String.valueOf(bytes / 1024) + ' KB';
        }
        return String.valueOf(bytes / (1024 * 1024)) + ' MB';
    }

    private static String inferAttachmentFileType(String extension) {
        String ext = String.isBlank(extension) ? '' : extension.trim().toLowerCase();
        if (ext == 'pdf') {
            return 'pdf';
        }
        return 'gen';
    }

    private static String summarizeAttachmentNames(List<AttachmentDTO> attachments) {
        if (attachments == null || attachments.isEmpty()) {
            return 'None';
        }
        List<String> names = new List<String>();
        for (AttachmentDTO row : attachments) {
            if (!String.isBlank(row.name)) {
                names.add(row.name);
            }
        }
        return names.isEmpty() ? 'None' : String.join(names, ', ');
    }

    private static Set<Id> buildAttachmentDocumentIdSet(
        List<Id> existingDocumentIds,
        List<String> newFileNames,
        List<String> newFileDataBase64,
        Id commLogId,
        Id opportunityId
    ) {
        Set<Id> docIds = new Set<Id>();
        if (existingDocumentIds != null) {
            for (Id docId : existingDocumentIds) {
                if (docId != null) {
                    docIds.add(docId);
                }
            }
        }
        docIds.addAll(createUploadedContentDocuments(newFileNames, newFileDataBase64, commLogId, opportunityId));
        return docIds;
    }

    private static Set<Id> createUploadedContentDocuments(
        List<String> fileNames,
        List<String> fileDataBase64,
        Id commLogId,
        Id opportunityId
    ) {
        Set<Id> createdDocIds = new Set<Id>();
        Integer count = fileNames == null ? 0 : fileNames.size();
        if (count == 0) {
            return createdDocIds;
        }
        List<ContentVersion> versions = new List<ContentVersion>();
        for (Integer i = 0; i < count; i++) {
            String fileName = listStringAt(fileNames, i);
            String encoded = listStringAt(fileDataBase64, i);
            if (String.isBlank(fileName) || String.isBlank(encoded)) {
                continue;
            }
            Blob body = decodeBase64File(encoded);
            if (body == null || body.size() == 0) {
                continue;
            }
            if (body.size() > MAX_ATTACHMENT_BYTES) {
                throw new AuraHandledException('Attachment "' + fileName + '" exceeds the 4.5 MB limit.');
            }
            ContentVersion version = new ContentVersion();
            version.Title = stripFileExtension(fileName);
            version.PathOnClient = fileName;
            version.VersionData = body;
            versions.add(version);
        }
        if (versions.isEmpty()) {
            return createdDocIds;
        }
        insert versions;

        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion version : versions) {
            versionIds.add(version.Id);
        }
        for (ContentVersion inserted : [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versionIds
        ]) {
            if (inserted.ContentDocumentId != null) {
                createdDocIds.add(inserted.ContentDocumentId);
            }
        }
        linkContentDocumentsToParents(createdDocIds, new Set<Id>{ commLogId, opportunityId });
        return createdDocIds;
    }

    private static Blob decodeBase64File(String encoded) {
        if (String.isBlank(encoded)) {
            return null;
        }
        String payload = encoded.trim();
        Integer commaIndex = payload.indexOf(',');
        if (commaIndex > -1) {
            payload = payload.substring(commaIndex + 1);
        }
        try {
            return EncodingUtil.base64Decode(payload);
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to read uploaded file data.');
        }
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

    private static void syncCommLogAttachments(Id commLogId, Set<Id> contentDocumentIds) {
        if (commLogId == null) {
            return;
        }
        Set<Id> wanted = contentDocumentIds == null ? new Set<Id>() : contentDocumentIds;
        List<ContentDocumentLink> existing = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :commLogId
        ];
        Set<Id> existingDocIds = new Set<Id>();
        List<ContentDocumentLink> toDelete = new List<ContentDocumentLink>();
        for (ContentDocumentLink link : existing) {
            existingDocIds.add(link.ContentDocumentId);
            if (!wanted.contains(link.ContentDocumentId)) {
                toDelete.add(link);
            }
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        Set<Id> toLink = new Set<Id>();
        for (Id docId : wanted) {
            if (docId != null && !existingDocIds.contains(docId)) {
                toLink.add(docId);
            }
        }
        linkContentDocumentsToParents(toLink, new Set<Id>{ commLogId });
    }

    private static void linkContentDocumentsToParents(Set<Id> contentDocumentIds, Set<Id> parentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty() || parentIds == null || parentIds.isEmpty()) {
            return;
        }
        Set<Id> parents = new Set<Id>();
        for (Id parentId : parentIds) {
            if (parentId != null) {
                parents.add(parentId);
            }
        }
        if (parents.isEmpty()) {
            return;
        }
        Map<String, ContentDocumentLink> dedupe = new Map<String, ContentDocumentLink>();
        for (ContentDocumentLink existing : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :parents AND ContentDocumentId IN :contentDocumentIds
        ]) {
            dedupe.put(existing.LinkedEntityId + ':' + existing.ContentDocumentId, existing);
        }
        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        for (Id parentId : parents) {
            for (Id docId : contentDocumentIds) {
                String key = parentId + ':' + docId;
                if (!dedupe.containsKey(key)) {
                    ContentDocumentLink link = new ContentDocumentLink();
                    link.LinkedEntityId = parentId;
                    link.ContentDocumentId = docId;
                    link.ShareType = 'V';
                    link.Visibility = 'AllUsers';
                    toInsert.add(link);
                }
            }
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    private static void deleteContentDocumentLinksForParents(Set<Id> parentIds) {
        if (parentIds == null || parentIds.isEmpty()) {
            return;
        }
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :parentIds
        ];
        if (!links.isEmpty()) {
            delete links;
        }
    }

    private static String normalizeRecipientType(String role) {
        String r = String.isBlank(role) ? '' : role.toLowerCase();
        if (r.contains('supplier')) {
            return 'Supplier';
        }
        if (r.contains('agent')) {
            return 'Agent';
        }
        return 'Traveller';
    }

    private static String buildInitials(String fullName) {
        if (String.isBlank(fullName)) {
            return '--';
        }
        List<String> parts = fullName.trim().split('\\s+');
        if (parts.isEmpty()) {
            return '--';
        }
        String first = parts[0].substring(0, 1).toUpperCase();
        String second = parts.size() > 1 ? parts[1].substring(0, 1).toUpperCase() : first;
        return first + second;
    }

    private static void validatePreviewRequest(PreviewRequest request) {
        if (request == null || request.opportunityId == null) {
            throw new AuraHandledException('Opportunity is required for preview.');
        }
    }

    private static void validateSendRequest(SendRequest request) {
        if (request == null || request.opportunityId == null) {
            throw new AuraHandledException('Opportunity is required for send.');
        }
        Boolean hasIds = request.recipientIds != null && !request.recipientIds.isEmpty();
        Boolean hasEmails = request.recipientEmails != null && !request.recipientEmails.isEmpty();
        if (!hasIds && !hasEmails) {
            throw new AuraHandledException('At least one recipient is required.');
        }
    }
}
