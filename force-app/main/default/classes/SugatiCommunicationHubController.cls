public with sharing class SugatiCommunicationHubController {
    private static final String EMAIL_CHANNEL = 'Email';
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
        @AuraEnabled public Id contactId;
        @AuraEnabled public String initials;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String role;
        @AuraEnabled public String roleKey;
        @AuraEnabled public String status;
        @AuraEnabled public String statusKey;
        @AuraEnabled public Boolean selected;
        @AuraEnabled public String audience;
        @AuraEnabled public String linkedToLabel;
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

    public class HistoryItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String channel;
        @AuraEnabled public String subject;
        @AuraEnabled public String who;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime sentAt;
        @AuraEnabled public String sentBy;
        @AuraEnabled public String fromEmail;
        @AuraEnabled public Integer recipientCount;
        @AuraEnabled public Integer deliveredCount;
        @AuraEnabled public Integer openedCount;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public String deliveryMode;
        @AuraEnabled public Integer attachmentCount;
        @AuraEnabled public String attachmentSummary;
        @AuraEnabled public Datetime lastModifiedAt;
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
        @AuraEnabled public Id sugatiEmailTemplateConfigId;
        @AuraEnabled public Id relatedRecordId;
        @AuraEnabled public List<Id> recipientIds;
        @AuraEnabled public List<String> recipientEmails;
        @AuraEnabled public List<String> recipientNames;
        @AuraEnabled public String subjectTemplate;
        @AuraEnabled public String bodyTemplate;
    }

    public class PreviewResponse {
        @AuraEnabled public String subject;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public List<RecipientDTO> recipients;
    }

    public class SendRequest {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id templateId;
        @AuraEnabled public Id sugatiEmailTemplateConfigId;
        @AuraEnabled public Id relatedRecordId;
        @AuraEnabled public Id orgWideEmailAddressId;
        @AuraEnabled public List<Id> recipientIds;
        @AuraEnabled public List<String> recipientEmails;
        @AuraEnabled public List<String> recipientNames;
        @AuraEnabled public List<String> toEmails;
        @AuraEnabled public List<String> ccEmails;
        @AuraEnabled public List<String> bccEmails;
        @AuraEnabled public String toRecipientsJson;
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
        @AuraEnabled public String emailSendType;
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
            SELECT Id,
                sugati__O_Lead_CG__c,
                sugati__O_Booking_Contact__c,
                sugati__O_Agent__c,
                sugati__O_Agent_SC__c,
                sugati__O_Agent_SC__r.Id,
                sugati__O_Agent_SC__r.Name,
                sugati__O_Agent_SC__r.sugati__SC_Name__c,
                sugati__O_Agent_SC__r.sugati__SC_First_Name__c,
                sugati__O_Agent_SC__r.sugati__SC_Last_Name__c,
                sugati__O_Agent_SC__r.sugati__SC_Email__c,
                sugati__O_Agent_SC__r.sugati__Type__c
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
            String email = resolveTravellerEmail(gm);
            String primaryStatus = gm.sugati__GM_Client_Group__r != null ? gm.sugati__GM_Client_Group__r.sugati__S_CG_Booking_Status__c : null;
            String secondaryStatus = gm.sugati__S_GM_Client_Group_Booking_Status__c;
            String statusLabel = normalizeStatusLabel(primaryStatus, secondaryStatus);
            RecipientDTO dto = new RecipientDTO();
            dto.contactId = gm.sugati__GM_Contact__c;
            dto.id = gm.Id;
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

        Id agentSupplierId = opp.sugati__O_Agent__c;
        Set<Id> supplierIds = new Set<Id>();
        Set<Id> supplierRowIds = new Set<Id>();
        Set<Id> supplierContactRowIds = new Set<Id>();

        if (Schema.sObjectType.sugati__Supplier_Booking__c.isAccessible()) {
            for (sugati__Supplier_Booking__c sb : [
                SELECT
                    sugati__SB_Supplier__c,
                    sugati__SB_Supplier__r.Name,
                    sugati__SB_Supplier__r.sugati__S_Email__c
                FROM sugati__Supplier_Booking__c
                WHERE sugati__SB_Opportunity__c = :opportunityId
                AND sugati__SB_Supplier__c != null
            ]) {
                supplierIds.add(sb.sugati__SB_Supplier__c);
                if (sb.sugati__SB_Supplier__c == agentSupplierId) {
                    continue;
                }
                if (
                    !supplierRowIds.contains(sb.sugati__SB_Supplier__c) &&
                    sb.sugati__SB_Supplier__r != null &&
                    String.isNotBlank(sb.sugati__SB_Supplier__r.sugati__S_Email__c)
                ) {
                    supplierRowIds.add(sb.sugati__SB_Supplier__c);
                    rows.add(
                        buildSupplierRecipient(
                            sb.sugati__SB_Supplier__c,
                            sb.sugati__SB_Supplier__r.Name,
                            sb.sugati__SB_Supplier__r.sugati__S_Email__c,
                            'suppliers'
                        )
                    );
                }
            }
        }

        if (Schema.sObjectType.sugati__Opportunity_Supplier__c.isAccessible()) {
            for (sugati__Opportunity_Supplier__c os : [
                SELECT Id, sugati__OS_Supplier__c, sugati__OS_Supplier__r.Name, sugati__OS_Supplier__r.sugati__S_Email__c
                FROM sugati__Opportunity_Supplier__c
                WHERE sugati__OS_Opportunity__c = :opportunityId
                AND sugati__OS_Supplier__c != null
            ]) {
                supplierIds.add(os.sugati__OS_Supplier__c);
                if (os.sugati__OS_Supplier__c == agentSupplierId) {
                    continue;
                }
                if (
                    !supplierRowIds.contains(os.sugati__OS_Supplier__c) &&
                    os.sugati__OS_Supplier__r != null &&
                    String.isNotBlank(os.sugati__OS_Supplier__r.sugati__S_Email__c)
                ) {
                    supplierRowIds.add(os.sugati__OS_Supplier__c);
                    rows.add(
                        buildSupplierRecipient(
                            os.sugati__OS_Supplier__c,
                            os.sugati__OS_Supplier__r.Name,
                            os.sugati__OS_Supplier__r.sugati__S_Email__c,
                            'suppliers'
                        )
                    );
                }
            }
        }

        if (agentSupplierId != null) {
            supplierIds.add(agentSupplierId);
            List<sugati__Supplier__c> agents = [
                SELECT Id, Name, sugati__S_Email__c
                FROM sugati__Supplier__c
                WHERE Id = :agentSupplierId
                LIMIT 1
            ];
            if (!agents.isEmpty() && String.isNotBlank(agents[0].sugati__S_Email__c)) {
                rows.add(buildSupplierRecipient(agents[0].Id, agents[0].Name, agents[0].sugati__S_Email__c, 'agents', 'Agency', 'agent'));
            }
        }

        if (!supplierIds.isEmpty() && Schema.sObjectType.sugati__Supplier_Contact__c.isAccessible()) {
            for (sugati__Supplier_Contact__c sc : [
                SELECT
                    Id,
                    Name,
                    sugati__SC_Name__c,
                    sugati__SC_First_Name__c,
                    sugati__SC_Last_Name__c,
                    sugati__SC_Email__c,
                    sugati__SC_Supplier__c,
                    sugati__SC_Supplier__r.Name,
                    sugati__Type__c
                FROM sugati__Supplier_Contact__c
                WHERE sugati__SC_Supplier__c IN :supplierIds
                AND sugati__SC_Email__c != null
                ORDER BY sugati__SC_Supplier__r.Name, Name
            ]) {
                if (supplierContactRowIds.contains(sc.Id)) {
                    continue;
                }
                supplierContactRowIds.add(sc.Id);
                String displayName = formatSupplierContactName(sc);
                Boolean isAgency = sc.sugati__SC_Supplier__c == agentSupplierId;
                String supplierName = sc.sugati__SC_Supplier__r != null ? sc.sugati__SC_Supplier__r.Name : null;
                String roleLabel = String.isBlank(sc.sugati__Type__c) ? 'Contact' : sc.sugati__Type__c;
                rows.add(
                    buildSupplierContactRecipient(
                        sc.Id,
                        displayName,
                        sc.sugati__SC_Email__c,
                        roleLabel,
                        buildSupplierContactLinkedLabel(supplierName, isAgency)
                    )
                );
            }
        }
        return rows;
    }

    private static RecipientDTO buildSupplierRecipient(Id supplierId, String supplierName, String email, String audience) {
        return buildSupplierRecipient(supplierId, supplierName, email, audience, 'Supplier', 'supplier');
    }

    private static RecipientDTO buildSupplierRecipient(
        Id supplierId,
        String supplierName,
        String email,
        String audience,
        String role,
        String roleKey
    ) {
        RecipientDTO dto = new RecipientDTO();
        dto.id = supplierId;
        dto.name = String.isBlank(supplierName) ? 'Supplier' : supplierName;
        dto.email = email;
        dto.initials = buildInitials(dto.name);
        dto.role = role;
        dto.roleKey = roleKey;
        dto.status = 'Confirmed';
        dto.statusKey = 'booked';
        dto.selected = false;
        dto.audience = audience;
        return dto;
    }

    private static RecipientDTO buildSupplierContactRecipient(
        Id supplierContactId,
        String displayName,
        String email,
        String role,
        String linkedToLabel
    ) {
        RecipientDTO dto = new RecipientDTO();
        dto.id = supplierContactId;
        dto.name = displayName;
        dto.email = email;
        dto.initials = buildInitials(displayName);
        dto.role = role;
        dto.roleKey = 'supplier';
        dto.status = 'Confirmed';
        dto.statusKey = 'booked';
        dto.selected = false;
        dto.audience = 'contacts';
        dto.linkedToLabel = linkedToLabel;
        return dto;
    }

    private static String buildSupplierContactLinkedLabel(String supplierName, Boolean isAgency) {
        String entity = isAgency ? 'Agency' : 'Supplier';
        String name = String.isBlank(supplierName) ? 'Unknown' : supplierName;
        return entity + ': ' + name;
    }

    private static String resolveTravellerEmail(sugati__Group_Member__c gm) {
        if (gm == null) {
            return null;
        }
        if (String.isNotBlank(gm.sugati__GM_Email__c)) {
            return gm.sugati__GM_Email__c;
        }
        if (gm.sugati__GM_Contact__r != null && String.isNotBlank(gm.sugati__GM_Contact__r.Email)) {
            return gm.sugati__GM_Contact__r.Email;
        }
        return null;
    }

    private static String formatSupplierContactName(sugati__Supplier_Contact__c sc) {
        if (!String.isBlank(sc.sugati__SC_Name__c)) {
            return sc.sugati__SC_Name__c;
        }
        if (!String.isBlank(sc.Name)) {
            return sc.Name;
        }
        return ((sc.sugati__SC_First_Name__c == null ? '' : sc.sugati__SC_First_Name__c) +
            ' ' +
            (sc.sugati__SC_Last_Name__c == null ? '' : sc.sugati__SC_Last_Name__c))
            .trim();
    }

    @AuraEnabled(cacheable=true)
    public static List<TemplateDTO> getTemplates(Id opportunityId, String stage, String recipientType, String channel) {
        List<TemplateDTO> out = new List<TemplateDTO>();
        SugatiLegacyEmailService.LegacyTemplateCatalogDTO catalog = SugatiLegacyEmailService.getSendEmailTemplateCatalog(
            opportunityId
        );
        if (catalog == null || catalog.templates == null) {
            return out;
        }
        for (SugatiLegacyEmailService.LegacyTemplateRowDTO row : catalog.templates) {
            if (!String.isBlank(stage) && !stageMatches(row.templateStage, stage)) {
                continue;
            }
            TemplateDTO dto = new TemplateDTO();
            dto.id = row.id;
            dto.name = row.name;
            dto.subject = '';
            dto.body = '';
            dto.stage = String.isNotBlank(row.templateStage) ? row.templateStage : '';
            dto.type = row.relatedToRecord;
            dto.channel = String.isBlank(channel) ? EMAIL_CHANNEL : channel;
            dto.meta = row.meta;
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<SugatiLegacyEmailService.EmailAddressOptionDTO> getEmailAddressBook(Id opportunityId) {
        return SugatiLegacyEmailService.getEmailAddressBook(opportunityId);
    }

    @AuraEnabled(cacheable=true)
    public static List<SugatiLegacyEmailService.EmailAddressOptionDTO> getOrgWideFromAddresses() {
        return SugatiLegacyEmailService.getOrgWideFromAddresses();
    }

    @AuraEnabled(cacheable=true)
    public static SugatiLegacyEmailService.LegacyTemplateCatalogDTO getSendEmailTemplateCatalog(Id opportunityId) {
        return SugatiLegacyEmailService.getSendEmailTemplateCatalog(opportunityId);
    }

    @AuraEnabled
    public static SugatiLegacyEmailService.LegacyEmailLoadDTO loadDefaultSendEmailTemplate(Id opportunityId) {
        return SugatiLegacyEmailService.loadDefaultSendEmailTemplate(opportunityId);
    }

    @AuraEnabled
    public static SugatiLegacyEmailService.LegacyEmailLoadDTO loadSendEmailTemplate(
        Id opportunityId,
        Id configId,
        Id relatedRecordId,
        Id clientGroupId,
        Id previewAsContactId
    ) {
        return SugatiLegacyEmailService.loadSendEmailTemplate(
            opportunityId,
            configId,
            relatedRecordId,
            clientGroupId,
            previewAsContactId
        );
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
            'SELECT Id, Channel__c, Subject__c, Status__c, Sent_At__c, Last_Modified_At__c, CreatedDate, ' +
            'Body_HTML__c, Delivery_Mode__c, Sent_By__r.Name, Sent_By__r.Email ' +
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
        soql += ' ORDER BY Last_Modified_At__c DESC NULLS LAST, Sent_At__c DESC NULLS LAST, CreatedDate DESC';

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
            dto.lastModifiedAt = row.Last_Modified_At__c != null ? row.Last_Modified_At__c : row.CreatedDate;
            dto.sentBy = row.Sent_By__r != null ? row.Sent_By__r.Name : null;
            dto.fromEmail = row.Sent_By__r != null ? row.Sent_By__r.Email : null;
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
        PreviewResponse response = new PreviewResponse();
        response.recipients = recipientsByInputs(request.recipientIds, request.recipientEmails, request.recipientNames);

        Id configId = request.sugatiEmailTemplateConfigId != null
            ? request.sugatiEmailTemplateConfigId
            : request.templateId;
        Id relatedId = request.relatedRecordId != null ? request.relatedRecordId : request.opportunityId;
        SugatiLegacyEmailService.LegacyEmailLoadDTO loaded = SugatiLegacyEmailService.loadSendEmailTemplate(
            request.opportunityId,
            configId,
            relatedId,
            null,
            null
        );
        response.subject = blankSafe(loaded.subject);
        response.bodyHtml = blankSafe(loaded.bodyHtml);
        return response;
    }

    @AuraEnabled
    public static PreviewResponse previewMessageDirect(
        Id opportunityId,
        Id templateId,
        Id sugatiEmailTemplateConfigId,
        Id relatedRecordId,
        List<Id> recipientIds,
        List<String> recipientEmails,
        List<String> recipientNames,
        String subjectTemplate,
        String bodyTemplate
    ) {
        PreviewRequest request = new PreviewRequest();
        request.opportunityId = opportunityId;
        request.templateId = templateId;
        request.sugatiEmailTemplateConfigId = sugatiEmailTemplateConfigId;
        request.relatedRecordId = relatedRecordId;
        request.recipientIds = recipientIds == null ? new List<Id>() : recipientIds;
        request.recipientEmails = recipientEmails == null ? new List<String>() : recipientEmails;
        request.recipientNames = recipientNames == null ? new List<String>() : recipientNames;
        request.subjectTemplate = subjectTemplate;
        request.bodyTemplate = bodyTemplate;
        return previewMessage(request);
    }

    @AuraEnabled
    public static SendResponse sendMessage(
        Id opportunityId,
        List<String> toEmails,
        List<String> ccEmails,
        List<String> bccEmails,
        String toEmailsJson,
        String ccEmailsJson,
        String bccEmailsJson,
        String toRecipientsJson,
        String deliveryMode,
        Id orgWideEmailAddressId,
        Id sugatiEmailTemplateConfigId,
        Id relatedRecordId,
        String resolvedSubject,
        String resolvedBodyHtml,
        SendRequest request
    ) {
        try {
            return sendMessageInternal(
                opportunityId,
                toEmails,
                ccEmails,
                bccEmails,
                toEmailsJson,
                ccEmailsJson,
                bccEmailsJson,
                toRecipientsJson,
                deliveryMode,
                orgWideEmailAddressId,
                sugatiEmailTemplateConfigId,
                relatedRecordId,
                resolvedSubject,
                resolvedBodyHtml,
                request
            );
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException(toUserFacingExceptionMessage(ex));
        }
    }

    private static SendResponse sendMessageInternal(
        Id opportunityId,
        List<String> toEmails,
        List<String> ccEmails,
        List<String> bccEmails,
        String toEmailsJson,
        String ccEmailsJson,
        String bccEmailsJson,
        String toRecipientsJson,
        String deliveryMode,
        Id orgWideEmailAddressId,
        Id sugatiEmailTemplateConfigId,
        Id relatedRecordId,
        String resolvedSubject,
        String resolvedBodyHtml,
        SendRequest request
    ) {
        request = request != null ? request : new SendRequest();
        if (String.isNotBlank(toRecipientsJson)) {
            request.toRecipientsJson = toRecipientsJson;
        }
        if (opportunityId != null) {
            request.opportunityId = opportunityId;
        }
        if (String.isNotBlank(deliveryMode)) {
            request.deliveryMode = deliveryMode;
        }
        if (orgWideEmailAddressId != null) {
            request.orgWideEmailAddressId = orgWideEmailAddressId;
        }
        if (sugatiEmailTemplateConfigId != null) {
            request.sugatiEmailTemplateConfigId = sugatiEmailTemplateConfigId;
        }
        if (relatedRecordId != null) {
            request.relatedRecordId = relatedRecordId;
        }
        if (String.isBlank(request.deliveryMode)) {
            request.deliveryMode = 'native';
        }
        mergeSendContent(request, resolvedSubject, resolvedBodyHtml);
        mergeSendEmailLists(request, toEmails, ccEmails, bccEmails, toEmailsJson, ccEmailsJson, bccEmailsJson);
        applySendRequestOpportunityFallbacks(request);
        validateSendRequest(request);
        String outboundSubject = !String.isBlank(request.resolvedSubject)
            ? request.resolvedSubject
            : blankSafe(request.subjectTemplate);
        String outboundBodyHtml = !String.isBlank(request.resolvedBodyHtml)
            ? request.resolvedBodyHtml
            : blankSafe(request.bodyTemplate);
        if (String.isBlank(outboundSubject)) {
            throw new AuraHandledException('Subject is required.');
        }
        if (String.isBlank(outboundBodyHtml)) {
            throw new AuraHandledException('Email body is required.');
        }

        Id templateConfigId = request.sugatiEmailTemplateConfigId != null
            ? request.sugatiEmailTemplateConfigId
            : request.templateId;
        Id renderRelatedRecordId = request.relatedRecordId != null ? request.relatedRecordId : request.opportunityId;
        if (templateConfigId != null) {
            Id generalWhoId = SugatiLegacyEmailService.resolveLeadContactIdForSend(request.opportunityId);
            SugatiLegacyEmailService.RenderedEmailDTO generalRendered = SugatiLegacyEmailService.renderSendEmailContent(
                request.opportunityId,
                templateConfigId,
                renderRelatedRecordId,
                generalWhoId,
                renderRelatedRecordId == request.opportunityId
            );
            if (!String.isBlank(generalRendered.subject)) {
                outboundSubject = generalRendered.subject;
            }
            if (!String.isBlank(generalRendered.bodyHtml)) {
                outboundBodyHtml = generalRendered.bodyHtml;
            }
        }

        Comm_Log__c log = new Comm_Log__c();
        log.Opportunity__c = request.opportunityId;
        log.Channel__c = String.isBlank(request.channel) ? EMAIL_CHANNEL : request.channel;
        log.Direction__c = 'Outbound';
        log.Subject__c = outboundSubject;
        log.Body_HTML__c = outboundBodyHtml;
        log.Sent_At__c = System.now();
        log.Sent_By__c = UserInfo.getUserId();
        log.Delivery_Mode__c = request.deliveryMode;
        log.Status__c = 'Sent';
        Savepoint sendSavepoint = Database.setSavepoint();
        try {
            insert log;

            List<Comm_Recipient__c> recRows = buildCommRecipientsFromSendRequest(log.Id, request);
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

            String providerMessageId;
            if (request.deliveryMode == 'native') {
                providerMessageId = sendViaNativeSalesforce(request, attachmentDocIds);
            } else {
                try {
                    providerMessageId = sendViaPostmark(request, attachmentDocIds);
                } catch (Exception postmarkEx) {
                    if (!isPostmarkInfrastructureError(postmarkEx)) {
                        throw postmarkEx;
                    }
                    providerMessageId = sendViaNativeSalesforce(request, attachmentDocIds);
                    log.Delivery_Mode__c = 'native';
                    request.deliveryMode = 'native';
                }
            }

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

            SendResponse response = new SendResponse();
            response.commLogId = log.Id;
            response.status = log.Status__c;
            response.providerMessageId = providerMessageId;
            response.message = 'Message logged and sent';
            return response;
        } catch (Exception ex) {
            Database.rollback(sendSavepoint);
            throw new AuraHandledException(toUserFacingExceptionMessage(ex));
        }
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
            SELECT Id,
                Name,
                Contact__c,
                Contact__r.Name,
                Contact__r.Email,
                Email_Address__c,
                Recipient_Type__c,
                Email_Send_Type__c
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
            row.emailSendType = resolveEmailSendType(rec.Email_Send_Type__c, rec.Recipient_Type__c);
            row.role = resolveAudienceRole(rec.Recipient_Type__c, row.emailSendType);
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
        List<String> recipientEmailSendTypes,
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
            recipientRoles,
            recipientEmailSendTypes
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
            stampDraftLastModified(log);
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
            stampDraftLastModified(log);
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
        rec.Email_Send_Type__c = normalizeEmailSendType(input.emailSendType);
        rec.Status__c = 'Queued';
        return rec;
    }

    private static List<DraftRecipientInput> buildDraftRecipientInputs(
        List<Id> recipientRowIds,
        List<Id> recipientContactIds,
        List<String> recipientEmails,
        List<String> recipientNames,
        List<String> recipientRoles,
        List<String> recipientEmailSendTypes
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
            String rawSendType = listStringAt(recipientEmailSendTypes, i);
            if (!String.isBlank(rawSendType)) {
                input.emailSendType = normalizeEmailSendType(rawSendType);
            } else {
                input.emailSendType = inferEmailSendTypeFromRole(input.role);
            }
            input.role = resolveAudienceRole(input.role, input.emailSendType);
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
            req.sugatiEmailTemplateConfigId = source.sugatiEmailTemplateConfigId;
            req.relatedRecordId = source.relatedRecordId;
            req.recipientIds = source.recipientIds;
            req.recipientEmails = source.recipientEmails;
            req.recipientNames = source.recipientNames;
            req.subjectTemplate = source.subjectTemplate;
            req.bodyTemplate = source.bodyTemplate;
            return req;
        }
    }

    private static List<Comm_Recipient__c> buildCommRecipientsFromSendRequest(Id commLogId, SendRequest request) {
        List<Comm_Recipient__c> rows = new List<Comm_Recipient__c>();
        rows.addAll(buildCommRecipientRows(commLogId, request.toEmails, 'TO'));
        rows.addAll(buildCommRecipientRows(commLogId, request.ccEmails, 'CC'));
        rows.addAll(buildCommRecipientRows(commLogId, request.bccEmails, 'BCC'));

        return rows;
    }

    private static List<Comm_Recipient__c> buildCommRecipientRows(Id commLogId, List<String> emails, String emailSendType) {
        List<Comm_Recipient__c> rows = new List<Comm_Recipient__c>();
        if (emails == null) {
            return rows;
        }
        Set<String> seen = new Set<String>();
        for (String email : emails) {
            if (String.isBlank(email)) {
                continue;
            }
            String normalized = email.trim().toLowerCase();
            if (seen.contains(normalized)) {
                continue;
            }
            seen.add(normalized);
            Comm_Recipient__c rec = new Comm_Recipient__c();
            rec.Comm_Log__c = commLogId;
            rec.Email_Address__c = email.trim();
            rec.Name = email.trim();
            rec.Email_Send_Type__c = normalizeEmailSendType(emailSendType);
            rec.Recipient_Type__c = 'Traveller';
            rec.Status__c = 'Sent';
            rows.add(rec);
        }
        return rows;
    }

    private class TravellerSendTarget {
        private String email;
        private Id contactId;
        private Id groupMemberId;
    }

    private static String sendViaNativeSalesforce(SendRequest request, Set<Id> attachmentDocIds) {
        List<TravellerSendTarget> toTargets = parseTravellerSendTargets(request);
        List<String> ccAddresses = cleanEmailList(request.ccEmails);
        List<String> bccAddresses = cleanEmailList(request.bccEmails);
        if (toTargets.isEmpty() && ccAddresses.isEmpty() && bccAddresses.isEmpty()) {
            throw new AuraHandledException('At least one recipient is required.');
        }

        List<ContentVersion> docuLinks = loadContentVersionsForSend(attachmentDocIds);
        List<Messaging.SingleEmailMessage> messages = buildOutboundEmailMessages(request, toTargets, ccAddresses, bccAddresses, docuLinks);

        if (Test.isRunningTest()) {
            return 'NATIVE-TEST';
        }

        dispatchNativeEmailMessages(messages);
        return 'NATIVE-' + String.valueOf(Crypto.getRandomLong()).replace('-', '');
    }

    private static List<TravellerSendTarget> parseTravellerSendTargets(SendRequest request) {
        List<TravellerSendTarget> targets = new List<TravellerSendTarget>();
        if (request == null) {
            return targets;
        }
        if (!String.isBlank(request.toRecipientsJson)) {
            try {
                List<Object> rows = (List<Object>) JSON.deserializeUntyped(request.toRecipientsJson);
                for (Object row : rows) {
                    if (!(row instanceof Map<String, Object>)) {
                        continue;
                    }
                    Map<String, Object> mapped = (Map<String, Object>) row;
                    Object emailRaw = mapped.get('email');
                    if (emailRaw == null || String.isBlank(String.valueOf(emailRaw))) {
                        continue;
                    }
                    TravellerSendTarget target = new TravellerSendTarget();
                    target.email = String.valueOf(emailRaw).trim();
                    Object contactRaw = mapped.get('contactId');
                    if (contactRaw != null) {
                        String contactKey = String.valueOf(contactRaw);
                        if (contactKey.startsWith('003') && (contactKey.length() == 15 || contactKey.length() == 18)) {
                            target.contactId = (Id) contactKey;
                        }
                    }
                    Object groupMemberRaw = mapped.get('groupMemberId');
                    if (groupMemberRaw != null) {
                        String gmKey = String.valueOf(groupMemberRaw);
                        if (gmKey.length() == 15 || gmKey.length() == 18) {
                            target.groupMemberId = (Id) gmKey;
                        }
                    }
                    targets.add(target);
                }
            } catch (Exception ex) {
                // fall through to email-only targets
            }
        }
        if (!targets.isEmpty()) {
            return dedupeTravellerTargets(targets);
        }
        for (String email : cleanEmailList(request.toEmails)) {
            TravellerSendTarget target = new TravellerSendTarget();
            target.email = email;
            targets.add(target);
        }
        return dedupeTravellerTargets(targets);
    }

    private static List<TravellerSendTarget> dedupeTravellerTargets(List<TravellerSendTarget> targets) {
        List<TravellerSendTarget> out = new List<TravellerSendTarget>();
        Set<String> seen = new Set<String>();
        for (TravellerSendTarget target : targets) {
            if (target == null || String.isBlank(target.email)) {
                continue;
            }
            String key = target.email.trim().toLowerCase();
            if (seen.contains(key)) {
                continue;
            }
            seen.add(key);
            out.add(target);
        }
        return out;
    }

    private static Map<String, Id> resolveTravellerContactIdsByEmail(Id opportunityId, Set<String> emails) {
        Map<String, Id> out = new Map<String, Id>();
        if (opportunityId == null || emails == null || emails.isEmpty()) {
            return out;
        }
        for (sugati__Group_Member__c gm : [
            SELECT sugati__GM_Contact__c, sugati__GM_Email__c, sugati__GM_Contact__r.Email
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opportunityId
        ]) {
            if (gm.sugati__GM_Contact__c != null) {
                if (gm.sugati__GM_Contact__r != null && !String.isBlank(gm.sugati__GM_Contact__r.Email)) {
                    out.put(gm.sugati__GM_Contact__r.Email.trim().toLowerCase(), gm.sugati__GM_Contact__c);
                }
            }
            if (!String.isBlank(gm.sugati__GM_Email__c)) {
                Id contactId = gm.sugati__GM_Contact__c;
                if (contactId != null) {
                    out.put(gm.sugati__GM_Email__c.trim().toLowerCase(), contactId);
                }
            }
        }
        return out;
    }

    private static Map<Id, Id> resolveTravellerContactIdsByGroupMemberIds(Set<Id> groupMemberIds) {
        Map<Id, Id> out = new Map<Id, Id>();
        if (groupMemberIds == null || groupMemberIds.isEmpty()) {
            return out;
        }
        for (sugati__Group_Member__c gm : [
            SELECT Id, sugati__GM_Contact__c
            FROM sugati__Group_Member__c
            WHERE Id IN :groupMemberIds
        ]) {
            if (gm.sugati__GM_Contact__c != null) {
                out.put(gm.Id, gm.sugati__GM_Contact__c);
            }
        }
        return out;
    }

    private static Id resolveTemplateConfigIdForSend(SendRequest request) {
        if (request == null) {
            return null;
        }
        if (request.sugatiEmailTemplateConfigId != null) {
            return request.sugatiEmailTemplateConfigId;
        }
        return request.templateId;
    }

    private static Id resolveRenderContactIdForTarget(
        TravellerSendTarget target,
        Map<String, Id> contactByEmail,
        Map<Id, Id> contactByGroupMemberId
    ) {
        if (target == null) {
            return null;
        }
        if (target.contactId != null) {
            return target.contactId;
        }
        if (!String.isBlank(target.email) && contactByEmail != null) {
            Id byEmail = contactByEmail.get(target.email.trim().toLowerCase());
            if (byEmail != null) {
                return byEmail;
            }
        }
        if (target.groupMemberId != null && contactByGroupMemberId != null) {
            return contactByGroupMemberId.get(target.groupMemberId);
        }
        return null;
    }

    private static List<Messaging.SingleEmailMessage> buildOutboundEmailMessages(
        SendRequest request,
        List<TravellerSendTarget> toTargets,
        List<String> ccAddresses,
        List<String> bccAddresses,
        List<ContentVersion> docuLinks
    ) {
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        Id templateConfigId = resolveTemplateConfigIdForSend(request);
        Id relatedRecordId = request.relatedRecordId != null ? request.relatedRecordId : request.opportunityId;
        Boolean useOpportunityAsWhat = relatedRecordId == request.opportunityId;
        Boolean hasAnyRecipients = !toTargets.isEmpty() || !ccAddresses.isEmpty() || !bccAddresses.isEmpty();

        if (templateConfigId == null && hasAnyRecipients && !Test.isRunningTest()) {
            throw new AuraHandledException(
                'Email template configuration is required to send personalized emails to travellers.'
            );
        }

        if (templateConfigId == null && Test.isRunningTest()) {
            String subjectText = !String.isBlank(request.resolvedSubject)
                ? request.resolvedSubject
                : blankSafe(request.subjectTemplate);
            String bodyHtml = !String.isBlank(request.resolvedBodyHtml)
                ? request.resolvedBodyHtml
                : blankSafe(request.bodyTemplate);
            for (TravellerSendTarget target : toTargets) {
                messages.add(
                    buildNativeEmailMessage(
                        new List<String>{ target.email },
                        new List<String>(),
                        new List<String>(),
                        subjectText,
                        bodyHtml,
                        request.opportunityId,
                        request.orgWideEmailAddressId,
                        docuLinks
                    )
                );
            }
            if (!ccAddresses.isEmpty() || !bccAddresses.isEmpty()) {
                messages.add(
                    buildNativeEmailMessage(
                        ccAddresses,
                        new List<String>(),
                        bccAddresses,
                        subjectText,
                        bodyHtml,
                        request.opportunityId,
                        request.orgWideEmailAddressId,
                        docuLinks
                    )
                );
            }
            return messages;
        }

        SugatiLegacyEmailService.RenderedEmailDTO generalRendered;
        Id generalWhoId = SugatiLegacyEmailService.resolveLeadContactIdForSend(request.opportunityId);
        generalRendered = SugatiLegacyEmailService.renderSendEmailContent(
            request.opportunityId,
            templateConfigId,
            relatedRecordId,
            generalWhoId,
            useOpportunityAsWhat
        );

        Set<String> emailLookupKeys = new Set<String>();
        Set<Id> groupMemberIds = new Set<Id>();
        for (TravellerSendTarget target : toTargets) {
            emailLookupKeys.add(target.email.trim().toLowerCase());
            if (target.groupMemberId != null) {
                groupMemberIds.add(target.groupMemberId);
            }
        }
        Map<String, Id> contactByEmail = resolveTravellerContactIdsByEmail(request.opportunityId, emailLookupKeys);
        Map<Id, Id> contactByGroupMemberId = resolveTravellerContactIdsByGroupMemberIds(groupMemberIds);

        for (TravellerSendTarget target : toTargets) {
            Id renderWhoId = resolveRenderContactIdForTarget(target, contactByEmail, contactByGroupMemberId);
            if (renderWhoId == null) {
                throw new AuraHandledException(
                    'Could not resolve a Contact for To recipient ' +
                        target.email +
                        '. Link the traveller to a Contact with a valid email.'
                );
            }
            SugatiLegacyEmailService.RenderedEmailDTO personalRendered = SugatiLegacyEmailService.renderSendEmailContent(
                request.opportunityId,
                templateConfigId,
                relatedRecordId,
                renderWhoId,
                useOpportunityAsWhat
            );
            String subjectText = personalRendered.subject;
            String bodyHtml = personalRendered.bodyHtml;
            messages.add(
                buildNativeEmailMessage(
                    new List<String>{ target.email },
                    new List<String>(),
                    new List<String>(),
                    subjectText,
                    bodyHtml,
                    request.opportunityId,
                    request.orgWideEmailAddressId,
                    docuLinks
                )
            );
        }

        if (!ccAddresses.isEmpty() || !bccAddresses.isEmpty()) {
            messages.add(
                buildNativeEmailMessage(
                    ccAddresses,
                    new List<String>(),
                    bccAddresses,
                    generalRendered.subject,
                    generalRendered.bodyHtml,
                    request.opportunityId,
                    request.orgWideEmailAddressId,
                    docuLinks
                )
            );
        }

        return messages;
    }

    private static Messaging.SingleEmailMessage buildNativeEmailMessage(
        List<String> toAddresses,
        List<String> ccAddresses,
        List<String> bccAddresses,
        String subject,
        String bodyHtml,
        Id opportunityId,
        Id orgWideEmailAddressId,
        List<ContentVersion> docuLinks
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject(subject);
        mail.setHtmlBody(bodyHtml);
        if (orgWideEmailAddressId != null) {
            mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }
        mail.setToAddresses(toAddresses);
        if (!ccAddresses.isEmpty()) {
            mail.setCcAddresses(ccAddresses);
        }
        if (!bccAddresses.isEmpty()) {
            mail.setBccAddresses(bccAddresses);
        }
        if (opportunityId != null) {
            mail.setWhatId(opportunityId);
        }
        mail.setSaveAsActivity(false);

        List<Messaging.EmailFileAttachment> fileAttachments = new List<Messaging.EmailFileAttachment>();
        for (ContentVersion cv : docuLinks) {
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(cv.PathOnClient != null ? cv.PathOnClient : cv.Title);
            efa.setBody(cv.VersionData);
            fileAttachments.add(efa);
        }
        if (!fileAttachments.isEmpty()) {
            mail.setFileAttachments(fileAttachments);
        }
        return mail;
    }

    private static void dispatchNativeEmailMessages(List<Messaging.SingleEmailMessage> messages) {
        if (messages == null || messages.isEmpty()) {
            throw new AuraHandledException('No email messages were prepared for send.');
        }
        Integer batchSize = 100;
        for (Integer offset = 0; offset < messages.size(); offset += batchSize) {
            Integer endIndex = Math.min(offset + batchSize, messages.size());
            List<Messaging.SingleEmailMessage> batch = new List<Messaging.SingleEmailMessage>();
            for (Integer i = offset; i < endIndex; i++) {
                batch.add(messages[i]);
            }
            Messaging.SendEmailResult[] results = Messaging.sendEmail(batch);
            if (results == null || results.isEmpty()) {
                throw new AuraHandledException('Salesforce did not return an email send result.');
            }
            List<String> errors = new List<String>();
            for (Messaging.SendEmailResult result : results) {
                if (result == null || result.isSuccess()) {
                    continue;
                }
                List<Messaging.SendEmailError> errs = result.getErrors();
                if (errs != null && !errs.isEmpty()) {
                    errors.add(errs[0].getMessage());
                } else {
                    errors.add('Salesforce email send failed.');
                }
            }
            if (!errors.isEmpty()) {
                throw new AuraHandledException(String.join(errors, '; '));
            }
        }
    }

    private static List<ContentVersion> loadContentVersionsForSend(Set<Id> attachmentDocIds) {
        List<ContentVersion> docuLinks = new List<ContentVersion>();
        if (attachmentDocIds == null || attachmentDocIds.isEmpty()) {
            return docuLinks;
        }
        for (ContentVersion cv : [
            SELECT Id, VersionData, Title, PathOnClient
            FROM ContentVersion
            WHERE ContentDocumentId IN :attachmentDocIds AND IsLatest = true
        ]) {
            docuLinks.add(cv);
        }
        return docuLinks;
    }

    private static List<String> cleanEmailList(List<String> emails) {
        List<String> out = new List<String>();
        if (emails == null) {
            return out;
        }
        Set<String> seen = new Set<String>();
        for (String email : emails) {
            if (String.isBlank(email)) {
                continue;
            }
            String trimmed = email.trim();
            String key = trimmed.toLowerCase();
            if (!seen.contains(key)) {
                seen.add(key);
                out.add(trimmed);
            }
        }
        return out;
    }

    private static String sendViaPostmark(SendRequest request, Set<Id> attachmentDocIds) {
        if (Test.isRunningTest()) {
            return 'POSTMARK-TEST';
        }

        List<TravellerSendTarget> toTargets = parseTravellerSendTargets(request);
        List<String> ccAddresses = cleanEmailList(request.ccEmails);
        List<String> bccAddresses = cleanEmailList(request.bccEmails);
        if (toTargets.isEmpty() && ccAddresses.isEmpty() && bccAddresses.isEmpty()) {
            throw new AuraHandledException('At least one recipient is required.');
        }

        List<ContentVersion> docuLinks = loadContentVersionsForSend(attachmentDocIds);
        List<Messaging.SingleEmailMessage> messages = buildOutboundEmailMessages(
            request,
            toTargets,
            ccAddresses,
            bccAddresses,
            docuLinks
        );
        String lastMessageId = 'POSTMARK-SENT';
        String fromAddress = SugatiLegacyEmailService.resolveFromEmailAddress(request.orgWideEmailAddressId);
        try {
            for (Messaging.SingleEmailMessage mail : messages) {
                Map<String, Object> payload = new Map<String, Object>{
                    'From' => fromAddress,
                    'To' => String.join(mail.getToAddresses(), ','),
                    'Subject' => mail.getSubject(),
                    'HtmlBody' => mail.getHtmlBody()
                };
                List<String> ccList = mail.getCcAddresses();
                if (ccList != null && !ccList.isEmpty()) {
                    payload.put('Cc', String.join(ccList, ','));
                }
                List<String> bccList = mail.getBccAddresses();
                if (bccList != null && !bccList.isEmpty()) {
                    payload.put('Bcc', String.join(bccList, ','));
                }

                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:Postmark_NC/email');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(payload));

                Http http = new Http();
                HttpResponse res = http.send(req);
                if (res.getStatusCode() < 200 || res.getStatusCode() > 299) {
                    throw new AuraHandledException('Postmark send failed: ' + res.getStatusCode() + ' ' + res.getBody());
                }
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (body != null && body.containsKey('MessageID')) {
                    lastMessageId = String.valueOf(body.get('MessageID'));
                }
            }
            return lastMessageId;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Postmark is not available (' +
                    toUserFacingExceptionMessage(ex) +
                    '). Configure the Postmark_NC named credential or choose Native Salesforce Email.'
            );
        }
    }

    private static Boolean isPostmarkInfrastructureError(Exception ex) {
        String message = toUserFacingExceptionMessage(ex).toLowerCase();
        return message.contains('postmark') ||
            message.contains('named credential') ||
            message.contains('callout') ||
            message.contains('unauthorized endpoint') ||
            message.contains('could not find');
    }

    private static String toUserFacingExceptionMessage(Exception ex) {
        if (ex == null) {
            return 'Unknown error';
        }
        if (ex instanceof AuraHandledException) {
            return ex.getMessage();
        }
        return String.isNotBlank(ex.getMessage()) ? ex.getMessage() : ex.getTypeName();
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

    private static Boolean stageMatches(String templateStage, String filterStage) {
        if (String.isBlank(filterStage)) {
            return true;
        }
        if (String.isBlank(templateStage)) {
            return true;
        }
        return templateStage.trim().equalsIgnoreCase(filterStage.trim());
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

    private static void stampDraftLastModified(Comm_Log__c log) {
        if (log == null) {
            return;
        }
        log.Last_Modified_At__c = System.now();
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
        if (r == 'cc' || r == 'bcc' || r == 'to') {
            return 'Traveller';
        }
        if (r.contains('supplier')) {
            return 'Supplier';
        }
        if (r.contains('agent')) {
            return 'Agent';
        }
        if (r.contains('lead')) {
            return 'Traveller';
        }
        return 'Traveller';
    }

    private static String normalizeEmailSendType(String sendType) {
        String value = String.isBlank(sendType) ? '' : sendType.trim().toUpperCase();
        if (value == 'CC') {
            return 'CC';
        }
        if (value == 'BCC') {
            return 'BCC';
        }
        return 'TO';
    }

    private static String inferEmailSendTypeFromRole(String role) {
        String r = String.isBlank(role) ? '' : role.toLowerCase();
        if (r == 'cc') {
            return 'CC';
        }
        if (r == 'bcc') {
            return 'BCC';
        }
        return 'TO';
    }

    private static String resolveEmailSendType(String emailSendType, String recipientType) {
        if (!String.isBlank(emailSendType)) {
            return normalizeEmailSendType(emailSendType);
        }
        return inferEmailSendTypeFromRole(recipientType);
    }

    private static String resolveAudienceRole(String role, String emailSendType) {
        String normalizedRole = normalizeRecipientType(role);
        String send = String.isBlank(emailSendType) ? 'TO' : emailSendType.toUpperCase();
        if (send == 'CC' || send == 'BCC' || send == 'TO') {
            String r = String.isBlank(role) ? '' : role.toLowerCase();
            if (r.contains('supplier')) {
                return 'Supplier';
            }
            if (r.contains('agent')) {
                return 'Agent';
            }
            if (r == 'cc' || r == 'bcc' || r == 'to') {
                return 'Traveller';
            }
            return normalizedRole;
        }
        return normalizedRole;
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

    private static void applySendRequestOpportunityFallbacks(SendRequest request) {
        if (request == null || request.opportunityId != null) {
            return;
        }
        if (request.relatedRecordId != null && String.valueOf(request.relatedRecordId).startsWith('006')) {
            request.opportunityId = request.relatedRecordId;
        }
    }

    private static void mergeSendContent(SendRequest request, String resolvedSubject, String resolvedBodyHtml) {
        if (request == null) {
            return;
        }
        if (String.isNotBlank(resolvedSubject)) {
            request.resolvedSubject = resolvedSubject.trim();
        }
        if (String.isNotBlank(resolvedBodyHtml)) {
            request.resolvedBodyHtml = resolvedBodyHtml;
        }
    }

    private static void mergeSendEmailLists(
        SendRequest request,
        List<String> toEmails,
        List<String> ccEmails,
        List<String> bccEmails,
        String toEmailsJson,
        String ccEmailsJson,
        String bccEmailsJson
    ) {
        if (request == null) {
            return;
        }
        request.toEmails = resolveEmailListParam(toEmails, toEmailsJson, request.toEmails);
        request.ccEmails = resolveEmailListParam(ccEmails, ccEmailsJson, request.ccEmails);
        request.bccEmails = resolveEmailListParam(bccEmails, bccEmailsJson, request.bccEmails);
    }

    private static List<String> resolveEmailListParam(
        List<String> directList,
        String jsonList,
        List<String> requestList
    ) {
        List<String> fromJson = parseEmailJsonList(jsonList);
        if (!fromJson.isEmpty()) {
            return fromJson;
        }
        List<String> fromDirect = cleanEmailList(directList);
        if (!fromDirect.isEmpty()) {
            return fromDirect;
        }
        return cleanEmailList(requestList);
    }

    private static List<String> parseEmailJsonList(String jsonList) {
        if (String.isBlank(jsonList)) {
            return new List<String>();
        }
        try {
            List<Object> raw = (List<Object>) JSON.deserializeUntyped(jsonList);
            List<String> emails = new List<String>();
            for (Object row : raw) {
                if (row != null && !String.isBlank(String.valueOf(row))) {
                    emails.add(String.valueOf(row));
                }
            }
            return cleanEmailList(emails);
        } catch (Exception ex) {
            return new List<String>();
        }
    }

    private static void validateSendRequest(SendRequest request) {
        if (request == null || request.opportunityId == null) {
            throw new AuraHandledException('Opportunity is required for send.');
        }
        Boolean hasTo = request.toEmails != null && !request.toEmails.isEmpty();
        if (!hasTo) {
            throw new AuraHandledException('At least one To recipient is required.');
        }
    }
}
