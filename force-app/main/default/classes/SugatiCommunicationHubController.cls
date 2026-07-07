public with sharing class SugatiCommunicationHubController {
    private static final String EMAIL_CHANNEL = 'Email';

    @TestVisible
    private static String lastNativeReplyTo;

    @TestVisible
    private static String getCommHubReplyToForTest(Id orgWideEmailAddressId) {
        return resolveCommHubReplyTo(orgWideEmailAddressId);
    }

    private static String resolveCommHubReplyTo(Id orgWideEmailAddressId) {
        Comm_Hub_Setting__c settings = Comm_Hub_Setting__c.getInstance();
        if (settings != null && String.isNotBlank(settings.Reply_To_Email__c)) {
            return settings.Reply_To_Email__c.trim();
        }
        return resolveFromEmailAddress(orgWideEmailAddressId);
    }

    private static String resolveFromEmailAddress(Id orgWideEmailAddressId) {
        if (orgWideEmailAddressId != null) {
            List<OrgWideEmailAddress> rows = [
                SELECT Address
                FROM OrgWideEmailAddress
                WHERE Id = :orgWideEmailAddressId
                LIMIT 1
            ];
            if (!rows.isEmpty() && String.isNotBlank(rows[0].Address)) {
                return rows[0].Address.trim();
            }
        }
        String userEmail = UserInfo.getUserEmail();
        return String.isNotBlank(userEmail) ? userEmail.trim() : null;
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
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer emailCount;
        @AuraEnabled public Integer whatsAppCount;
        @AuraEnabled public Integer inAppCount;
        @AuraEnabled public Boolean isAgencyBooking;
        @AuraEnabled public String bookingChannelLabel;
        @AuraEnabled public String suggestedRecipientTab;
    }

    public class RecipientDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id supplierId;
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
        @AuraEnabled public List<String> supplierContactTypes;
        @AuraEnabled public Boolean isAgencyLinked;
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
        @AuraEnabled public String fromDisplay;
        @AuraEnabled public Integer recipientCount;
        @AuraEnabled public Integer deliveredCount;
        @AuraEnabled public Integer openedCount;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public String deliveryMode;
        @AuraEnabled public Integer attachmentCount;
        @AuraEnabled public String attachmentSummary;
        @AuraEnabled public Datetime lastModifiedAt;
        @AuraEnabled public Integer logOpenCount;
        @AuraEnabled public Integer logClickCount;
        @AuraEnabled public Datetime deliveredAt;
        @AuraEnabled public Datetime bouncedAt;
        @AuraEnabled public String bounceType;
        @AuraEnabled public String bounceDescription;
        @AuraEnabled public String messageId;
        @AuraEnabled public String trackingSummary;
        @AuraEnabled public String direction;
        @AuraEnabled public Id parentCommLogId;
        @AuraEnabled public Id threadRootId;
        @AuraEnabled public Integer threadMessageCount;
    }

    public class ConversationPartyDTO {
        @AuraEnabled public String name;
        @AuraEnabled public String email;
    }

    public class ConversationThreadDTO {
        @AuraEnabled public Id threadRootId;
        @AuraEnabled public String subject;
        @AuraEnabled public List<ConversationMessageDTO> messages;
        @AuraEnabled public String rootStatus;
        @AuraEnabled public String rootDirection;
        @AuraEnabled public String rootFromDisplay;
        @AuraEnabled public String rootSentBy;
        @AuraEnabled public Datetime rootSentAt;
        @AuraEnabled public String rootSentAtLabel;
        @AuraEnabled public String rootDeliveryMode;
        @AuraEnabled public String rootDeliveryLabel;
        @AuraEnabled public String rootRecipientSummary;
        @AuraEnabled public String rootMessageId;
        @AuraEnabled public ConversationPartyDTO rootFromParty;
        @AuraEnabled public List<ConversationPartyDTO> rootToParties;
        @AuraEnabled public Integer inboundCount;
        @AuraEnabled public Integer outboundCount;
        @AuraEnabled public String threadStartedLabel;
        @AuraEnabled public String threadLastActivityLabel;
        @AuraEnabled public List<String> participants;
    }

    public class ConversationMessageDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String direction;
        @AuraEnabled public Id parentCommLogId;
        @AuraEnabled public String senderName;
        @AuraEnabled public String senderEmail;
        @AuraEnabled public String senderDisplay;
        @AuraEnabled public String senderVia;
        @AuraEnabled public String recipientSummary;
        @AuraEnabled public String subject;
        @AuraEnabled public String snippet;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public Datetime sentAt;
        @AuraEnabled public String sentAtLabel;
        @AuraEnabled public String sentAtFullLabel;
        @AuraEnabled public String relativeLabel;
        @AuraEnabled public Boolean isOutbound;
        @AuraEnabled public Boolean isThreadRoot;
        @AuraEnabled public String status;
        @AuraEnabled public String messageId;
        @AuraEnabled public String deliveryMode;
        @AuraEnabled public Integer attachmentCount;
        @AuraEnabled public String attachmentSummary;
        @AuraEnabled public List<AttachmentDTO> attachments;
    }

    public class AttachmentDTO {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String attachmentRecordId;
        @AuraEnabled public String storageKind;
        @AuraEnabled public String name;
        @AuraEnabled public String meta;
        @AuraEnabled public String fileType;
        @AuraEnabled public Integer sizeBytes;
        @AuraEnabled public Boolean selected;
        @AuraEnabled public Boolean isPendingUpload;
        @AuraEnabled public Boolean autoSuggested;
    }

    public class AttachmentSendBundle {
        public Set<Id> contentDocumentIds = new Set<Id>();
        public List<Attachment> attachmentRecords = new List<Attachment>();
        public List<ContentVersion> contentVersions = new List<ContentVersion>();
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
        @AuraEnabled public String ccRecipientsJson;
        @AuraEnabled public String bccRecipientsJson;
        @AuraEnabled public String subjectTemplate;
        @AuraEnabled public String bodyTemplate;
        @AuraEnabled public String resolvedSubject;
        @AuraEnabled public String resolvedBodyHtml;
        @AuraEnabled public String deliveryMode;
        @AuraEnabled public String channel;
        @AuraEnabled public List<Id> attachmentContentDocumentIds;
        @AuraEnabled public List<String> attachmentRecordIds;
        @AuraEnabled public List<String> newAttachmentFileNames;
        @AuraEnabled public List<String> newAttachmentFileData;
        @AuraEnabled public Id parentCommLogId;
    }

    public class ReplyComposeContextDTO {
        @AuraEnabled public Id parentCommLogId;
        @AuraEnabled public String subject;
        @AuraEnabled public List<RecipientDTO> toRecipients;
        @AuraEnabled public List<String> lockedToEmails;
        @AuraEnabled public Boolean lockFromAddress;
        @AuraEnabled public Boolean replyAll;
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
    public static List<AttachmentDTO> getRecordAttachments(Id parentRecordId, Id opportunityId) {
        Set<Id> parentIds = new Set<Id>();
        if (parentRecordId != null) {
            parentIds.add(parentRecordId);
        }
        if (opportunityId != null) {
            parentIds.add(opportunityId);
        }
        return queryAttachmentLinks(parentIds, null);
    }

    @AuraEnabled
    public static List<String> resolveAutoAttachmentIds(
        Id parentRecordId,
        Id opportunityId,
        List<String> docTypes
    ) {
        return resolveAutoAttachmentRecordIds(parentRecordId, opportunityId, docTypes);
    }

    public static List<String> resolveAutoAttachmentRecordIds(
        Id parentRecordId,
        Id opportunityId,
        List<String> docTypes
    ) {
        Set<Id> parentIds = new Set<Id>();
        if (parentRecordId != null) {
            parentIds.add(parentRecordId);
        }
        if (opportunityId != null) {
            parentIds.add(opportunityId);
        }
        if (parentIds.isEmpty()) {
            return new List<String>();
        }
        List<String> filters = normalizeDocTypeFilters(docTypes);
        List<String> ids = new List<String>();
        for (AttachmentDTO row : queryAttachmentLinks(parentIds, null)) {
            if (row == null || String.isBlank(row.attachmentRecordId)) {
                continue;
            }
            if (!filters.isEmpty() && !matchesAutoAttachmentFilter(row, filters)) {
                continue;
            }
            ids.add(row.attachmentRecordId);
        }
        return ids;
    }

    public static String resolveParentLabel(Id parentRecordId, Id opportunityId) {
        if (parentRecordId == null || parentRecordId == opportunityId) {
            return 'Opportunity';
        }
        try {
            SObjectType sobjectType = parentRecordId.getSObjectType();
            if (sobjectType != null) {
                return sobjectType.getDescribe().getLabel();
            }
        } catch (Exception ex) {
            // fall through to generic label
        }
        return 'Related Record';
    }

    @AuraEnabled(cacheable=true)
    public static HubContextDTO getHubContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Id,
                Name,
                StageName,
                Owner.Name,
                sugati__O_Agent__c
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
        List<AggregateResult> channelStats = [
            SELECT Channel__c channel, COUNT(Id) countRows
            FROM Comm_Log__c
            WHERE Opportunity__c = :opportunityId
            GROUP BY Channel__c
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
        dto.totalCount = 0;
        dto.emailCount = 0;
        dto.whatsAppCount = 0;
        dto.inAppCount = 0;
        dto.isAgencyBooking = opp.sugati__O_Agent__c != null;
        dto.bookingChannelLabel = dto.isAgencyBooking ? 'B2B' : 'B2C';
        dto.suggestedRecipientTab = resolveSuggestedRecipientTab(opp);

        for (AggregateResult row : stats) {
            String status = (String) row.get('status');
            Integer countValue = Integer.valueOf((Decimal) row.get('countRows'));
            dto.totalCount += countValue;
            if (status == 'Draft') {
                dto.draftCount += countValue;
            } else if (status == 'Opened') {
                dto.openedCount += countValue;
            } else if (status == 'Delivered') {
                dto.deliveredCount += countValue;
            } else if (status == 'Sent') {
                dto.sentCount += countValue;
            } else {
                // Bounced, Spam Complaint, Received, Failed, blank — still one log each
                dto.sentCount += countValue;
            }
        }

        for (AggregateResult row : channelStats) {
            String channel = (String) row.get('channel');
            Integer countValue = Integer.valueOf((Decimal) row.get('countRows'));
            if (channel == EMAIL_CHANNEL) {
                dto.emailCount += countValue;
            } else if (channel == 'WhatsApp') {
                dto.whatsAppCount += countValue;
            } else if (channel == 'In-App') {
                dto.inAppCount += countValue;
            } else {
                dto.emailCount += countValue;
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
                sugati__O_Agent__r.Name,
                sugati__O_Agent__r.sugati__S_Email__c,
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

        Id agentSupplierId = opp.sugati__O_Agent__c;
        Id leadGroupMemberId = resolveLeadGroupMemberId(opp.sugati__O_Lead_CG__c);

        if (agentSupplierId == null) {
            // B2C — Individual: travellers + operational suppliers + their contacts
            rows.addAll(buildTravellerRecipients(opportunityId, leadGroupMemberId, false));

            Set<Id> supplierIds = new Set<Id>();
            Set<Id> supplierRowIds = new Set<Id>();
            Set<Id> supplierContactRowIds = new Set<Id>();
            collectOperationalSupplierIds(opportunityId, null, supplierIds, supplierRowIds, rows);
            rows.addAll(
                buildSupplierContactRecipientsForSuppliers(supplierIds, new Set<Id>(), supplierContactRowIds, null)
            );
        } else {
            // B2B — Agency: agency email + agent contact + remaining agency contacts only
            Set<Id> supplierContactRowIds = new Set<Id>();
            rows.addAll(buildAgencyRecipients(opp, supplierContactRowIds));
            rows.addAll(buildSupplierContactRecipients(agentSupplierId, opp.sugati__O_Agent_SC__c, supplierContactRowIds));
        }

        return rows;
    }

    private static String resolveSuggestedRecipientTab(Opportunity opp) {
        if (opp != null && opp.sugati__O_Agent__c != null) {
            return 'agents';
        }
        return 'travellers';
    }

    private static Boolean isAgencyBooking(Id agentSupplierId) {
        return agentSupplierId != null;
    }

    private static Id resolveLeadGroupMemberId(Id leadClientGroupId) {
        if (leadClientGroupId == null) {
            return null;
        }
        List<sugati__Client_Group__c> cgs = [
            SELECT Id, sugati__CG_Lead_Group_Member__c
            FROM sugati__Client_Group__c
            WHERE Id = :leadClientGroupId
            LIMIT 1
        ];
        return cgs.isEmpty() ? null : cgs[0].sugati__CG_Lead_Group_Member__c;
    }

    private static List<RecipientDTO> buildTravellerRecipients(Id opportunityId, Id leadGroupMemberId, Boolean routeToAgency) {
        List<RecipientDTO> rows = new List<RecipientDTO>();
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
            if (String.isBlank(email)) {
                continue;
            }
            String primaryStatus = gm.sugati__GM_Client_Group__r != null
                ? gm.sugati__GM_Client_Group__r.sugati__S_CG_Booking_Status__c
                : null;
            String secondaryStatus = gm.sugati__S_GM_Client_Group_Booking_Status__c;
            String statusLabel = normalizeStatusLabel(primaryStatus, secondaryStatus);
            RecipientDTO dto = new RecipientDTO();
            dto.contactId = gm.sugati__GM_Contact__c;
            dto.id = gm.Id;
            dto.name = displayName;
            dto.email = email;
            dto.initials = buildInitials(displayName);
            dto.role = (gm.Id == leadGroupMemberId || gm.sugati__GM_Non_Travelling_Lead_Booker__c)
                ? 'Lead Booker'
                : 'Traveller';
            dto.roleKey = dto.role == 'Lead Booker' ? 'lead' : 'traveller';
            dto.status = statusLabel;
            dto.statusKey = mapStatusKey(statusLabel);
            dto.selected = !routeToAgency && dto.roleKey == 'lead';
            dto.audience = 'travellers';
            dto.isAgencyLinked = false;
            rows.add(dto);
        }
        return rows;
    }

    private static void collectOperationalSupplierIds(
        Id opportunityId,
        Id agentSupplierId,
        Set<Id> supplierIds,
        Set<Id> supplierRowIds,
        List<RecipientDTO> rows
    ) {
        if (Schema.sObjectType.sugati__Supplier_Cost_Payment__c.isAccessible()) {
            for (sugati__Supplier_Cost_Payment__c scp : [
                SELECT Id,
                    sugati__SCP_Supplier__c,
                    sugati__SCP_Supplier__r.Name,
                    sugati__SCP_Supplier__r.sugati__S_Email__c
                FROM sugati__Supplier_Cost_Payment__c
                WHERE sugati__SCP_Opportunity__c = :opportunityId
                AND   sugati__SCP_Supplier__c    != null
            ]) {
                addOperationalSupplierRow(
                    scp.sugati__SCP_Supplier__c,
                    scp.sugati__SCP_Supplier__r != null ? scp.sugati__SCP_Supplier__r.Name : null,
                    scp.sugati__SCP_Supplier__r != null ? scp.sugati__SCP_Supplier__r.sugati__S_Email__c : null,
                    agentSupplierId,
                    supplierIds,
                    supplierRowIds,
                    rows
                );
            }
        }
    }

    private static void addOperationalSupplierRow(
        Id supplierId,
        String supplierName,
        String supplierEmail,
        Id agentSupplierId,
        Set<Id> supplierIds,
        Set<Id> supplierRowIds,
        List<RecipientDTO> rows
    ) {
        if (supplierId == null) {
            return;
        }
        supplierIds.add(supplierId);
        if (supplierId == agentSupplierId) {
            return;
        }
        if (!supplierRowIds.contains(supplierId) && String.isNotBlank(supplierEmail)) {
            supplierRowIds.add(supplierId);
            rows.add(buildSupplierRecipient(supplierId, supplierName, supplierEmail, 'suppliers'));
        }
    }

    private static List<RecipientDTO> buildAgencyRecipients(
        Opportunity opp,
        Set<Id> supplierContactRowIds
    ) {
        List<RecipientDTO> rows = new List<RecipientDTO>();
        Id agentSupplierId = opp.sugati__O_Agent__c;
        String agencyName = opp.sugati__O_Agent__r != null ? opp.sugati__O_Agent__r.Name : 'Agency';
        String agencyEmail = opp.sugati__O_Agent__r != null ? opp.sugati__O_Agent__r.sugati__S_Email__c : null;

        if (String.isNotBlank(agencyEmail)) {
            RecipientDTO agencyRow = buildSupplierRecipient(
                agentSupplierId,
                agencyName,
                agencyEmail,
                'agents',
                'Agency',
                'agent'
            );
            agencyRow.selected = true;
            rows.add(agencyRow);
        }

        sugati__Supplier_Contact__c agentContact = opp.sugati__O_Agent_SC__r;
        if (opp.sugati__O_Agent_SC__c != null && agentContact != null && String.isNotBlank(agentContact.sugati__SC_Email__c)) {
            supplierContactRowIds.add(agentContact.Id);
            RecipientDTO agentRow = buildSupplierContactRecipient(
                agentContact.Id,
                formatSupplierContactName(agentContact),
                agentContact.sugati__SC_Email__c,
                'Agent Contact',
                buildSupplierContactLinkedLabel(agencyName, true),
                agentSupplierId,
                splitSupplierContactTypes(agentContact.sugati__Type__c),
                true,
                'agents',
                'agent'
            );
            agentRow.selected = true;
            rows.add(agentRow);
        }

        return rows;
    }

    private static List<RecipientDTO> buildSupplierContactRecipients(
        Id agentSupplierId,
        Id agentContactId,
        Set<Id> supplierContactRowIds
    ) {
        Set<Id> exclude = new Set<Id>();
        if (agentContactId != null) {
            exclude.add(agentContactId);
        }
        return buildSupplierContactRecipientsForSuppliers(
            new Set<Id>{ agentSupplierId },
            exclude,
            supplierContactRowIds,
            agentSupplierId
        );
    }

    private static List<RecipientDTO> buildSupplierContactRecipientsForSuppliers(
        Set<Id> supplierIds,
        Set<Id> excludeContactIds,
        Set<Id> supplierContactRowIds,
        Id agencySupplierIdForLinkage
    ) {
        List<RecipientDTO> rows = new List<RecipientDTO>();
        if (
            supplierIds == null ||
            supplierIds.isEmpty() ||
            !Schema.sObjectType.sugati__Supplier_Contact__c.isAccessible()
        ) {
            return rows;
        }

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
            if (
                (excludeContactIds != null && excludeContactIds.contains(sc.Id)) ||
                (supplierContactRowIds != null && supplierContactRowIds.contains(sc.Id))
            ) {
                continue;
            }
            if (supplierContactRowIds != null) {
                supplierContactRowIds.add(sc.Id);
            }
            Boolean isAgency =
                agencySupplierIdForLinkage != null && sc.sugati__SC_Supplier__c == agencySupplierIdForLinkage;
            String supplierName = sc.sugati__SC_Supplier__r != null ? sc.sugati__SC_Supplier__r.Name : null;
            List<String> contactTypes = splitSupplierContactTypes(sc.sugati__Type__c);
            String roleLabel = contactTypes.isEmpty() ? 'Contact' : String.join(contactTypes, ', ');
            rows.add(
                buildSupplierContactRecipient(
                    sc.Id,
                    formatSupplierContactName(sc),
                    sc.sugati__SC_Email__c,
                    roleLabel,
                    buildSupplierContactLinkedLabel(supplierName, isAgency, contactTypes),
                    sc.sugati__SC_Supplier__c,
                    contactTypes,
                    isAgency,
                    'contacts',
                    'contact'
                )
            );
        }
        return rows;
    }

    private static List<String> splitSupplierContactTypes(String rawTypes) {
        List<String> out = new List<String>();
        if (String.isBlank(rawTypes)) {
            return out;
        }
        for (String part : rawTypes.split(';')) {
            if (!String.isBlank(part)) {
                out.add(part.trim());
            }
        }
        return out;
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
        dto.supplierId = supplierId;
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
        return buildSupplierContactRecipient(
            supplierContactId,
            displayName,
            email,
            role,
            linkedToLabel,
            null,
            new List<String>(),
            false,
            'contacts',
            'supplier'
        );
    }

    private static RecipientDTO buildSupplierContactRecipient(
        Id supplierContactId,
        String displayName,
        String email,
        String role,
        String linkedToLabel,
        Id supplierId,
        List<String> supplierContactTypes,
        Boolean isAgencyLinked,
        String audience,
        String roleKey
    ) {
        RecipientDTO dto = new RecipientDTO();
        dto.id = supplierContactId;
        dto.supplierId = supplierId;
        dto.name = displayName;
        dto.email = email;
        dto.initials = buildInitials(displayName);
        dto.role = role;
        dto.roleKey = roleKey;
        dto.status = 'Confirmed';
        dto.statusKey = 'booked';
        dto.selected = false;
        dto.audience = audience;
        dto.linkedToLabel = linkedToLabel;
        dto.supplierContactTypes = supplierContactTypes == null ? new List<String>() : supplierContactTypes;
        dto.isAgencyLinked = isAgencyLinked;
        return dto;
    }

    private static String buildSupplierContactLinkedLabel(String supplierName, Boolean isAgency) {
        return buildSupplierContactLinkedLabel(supplierName, isAgency, new List<String>());
    }

    private static String buildSupplierContactLinkedLabel(
        String supplierName,
        Boolean isAgency,
        List<String> contactTypes
    ) {
        String entity = isAgency ? 'Agency' : 'Supplier';
        String name = String.isBlank(supplierName) ? 'Unknown' : supplierName;
        String label = entity + ': ' + name;
        if (contactTypes != null && !contactTypes.isEmpty()) {
            label = String.join(contactTypes, ', ') + ' · ' + label;
        }
        return label;
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
    public static List<SugatiCommunicationHubEmailService.EmailAddressOptionDTO> getSendEmailBccDefaults() {
        return SugatiCommunicationHubEmailService.getSendEmailBccDefaults();
    }

    @AuraEnabled(cacheable=true)
    public static List<SugatiCommunicationHubEmailService.EmailAddressOptionDTO> getOrgWideFromAddresses() {
        return SugatiCommunicationHubEmailService.getOrgWideFromAddresses();
    }

    @AuraEnabled(cacheable=true)
    public static SugatiCommunicationHubEmailService.TemplateCatalogDTO getSendEmailTemplateCatalog(Id opportunityId) {
        return SugatiCommunicationHubEmailService.getSendEmailTemplateCatalog(opportunityId);
    }

    @AuraEnabled
    public static SugatiCommunicationHubEmailService.EmailTemplateLoadDTO loadDefaultSendEmailTemplate(Id opportunityId) {
        return SugatiCommunicationHubEmailService.loadDefaultSendEmailTemplate(opportunityId);
    }

    @AuraEnabled
    public static SugatiCommunicationHubEmailService.EmailTemplateLoadDTO loadSendEmailTemplate(
        Id opportunityId,
        Id configId,
        Id relatedRecordId,
        Id clientGroupId,
        Id previewAsContactId
    ) {
        return SugatiCommunicationHubEmailService.loadSendEmailTemplate(
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
        String statusGroupFilter,
        Boolean rootOnly
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
            'SELECT Id, Channel__c, Direction__c, Subject__c, Status__c, Sent_At__c, Last_Modified_At__c, CreatedDate, ' +
            'Body_HTML__c, Delivery_Mode__c, From_Address__c, Parent_Comm_Log__c, Sent_By__r.Name, Sent_By__r.Email, ' +
            'Open_Count__c, Click_Count__c, First_Opened_At__c, Last_Opened_At__c, Delivered_At__c, ' +
            'Bounced_At__c, Bounce_Type__c, Bounce_Description__c, Spam_Reported_At__c, Message_Id__c ' +
            'FROM Comm_Log__c WHERE Opportunity__c = :opportunityId';
        if (rootOnly == true) {
            soql +=
                ' AND (Status__c = \'Draft\' OR Parent_Comm_Log__c = NULL)' +
                ' AND (Delivery_Mode__c = NULL OR Delivery_Mode__c != \'mailbox_verification\')';
        }
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
        soql += ' ORDER BY Sent_At__c DESC NULLS LAST, Last_Modified_At__c DESC NULLS LAST, CreatedDate DESC';

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
            SELECT Id, Name, Comm_Log__c, Status__c, Contact__c, Contact__r.Name, Email_Address__c, Message_Id__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c IN :logIds
        ]) {
            if (!recipientsByLog.containsKey(rec.Comm_Log__c)) {
                recipientsByLog.put(rec.Comm_Log__c, new List<Comm_Recipient__c>());
            }
            recipientsByLog.get(rec.Comm_Log__c).add(rec);
        }

        Map<Id, List<AttachmentDTO>> attachmentsByLog = queryAttachmentsByParentIds(logIds);

        Map<Id, Id> parentByLogId = queryParentMapForOpportunity(opportunityId);

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

            Integer logOpenCount = row.Open_Count__c == null ? 0 : Integer.valueOf(row.Open_Count__c);
            Integer logClickCount = row.Click_Count__c == null ? 0 : Integer.valueOf(row.Click_Count__c);
            if (
                delivered == 0 &&
                (row.Delivered_At__c != null ||
                row.Status__c == 'Delivered' ||
                row.Status__c == 'Opened')
            ) {
                delivered = Math.max(1, recs.size());
            }
            if (logOpenCount > opened) {
                opened = logOpenCount;
            } else if (row.Status__c == 'Opened' && opened == 0) {
                opened = Math.max(1, logOpenCount);
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
            dto.fromDisplay = resolveHistoryFromDisplay(
                row.From_Address__c,
                row.Sent_By__r,
                row.Direction__c == 'Inbound' ? recs : null
            );
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
            dto.logOpenCount = logOpenCount;
            dto.logClickCount = logClickCount;
            dto.deliveredAt = row.Delivered_At__c;
            dto.bouncedAt = row.Bounced_At__c;
            dto.bounceType = row.Bounce_Type__c;
            dto.bounceDescription = row.Bounce_Description__c;
            dto.messageId = resolveHistoryMessageId(row.Message_Id__c, recs);
            dto.trackingSummary = buildTrackingSummary(
                row.Status__c,
                row.Delivered_At__c,
                row.First_Opened_At__c,
                row.Last_Opened_At__c,
                logOpenCount,
                logClickCount,
                row.Bounced_At__c,
                row.Bounce_Type__c,
                row.Spam_Reported_At__c
            );
            dto.direction = row.Direction__c;
            dto.parentCommLogId = row.Parent_Comm_Log__c;
            dto.threadRootId = resolveThreadRootIdInMap(row.Id, parentByLogId);
            out.add(dto);
        }

        applyThreadMessageCounts(opportunityId, out);
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static ConversationThreadDTO getConversationThread(Id commLogId) {
        ConversationThreadDTO thread = new ConversationThreadDTO();
        thread.messages = new List<ConversationMessageDTO>();
        if (commLogId == null) {
            return thread;
        }

        Id threadRootId = resolveThreadRootId(commLogId);
        Comm_Log__c rootLog = [
            SELECT
                Id,
                Opportunity__c,
                Subject__c,
                Status__c,
                Direction__c,
                Channel__c,
                Sent_At__c,
                CreatedDate,
                Delivery_Mode__c,
                From_Address__c,
                Message_Id__c,
                Sent_By__r.Name,
                Sent_By__r.Email
            FROM Comm_Log__c
            WHERE Id = :threadRootId
            LIMIT 1
        ];
        thread.threadRootId = rootLog.Id;
        thread.subject = String.isNotBlank(rootLog.Subject__c) ? rootLog.Subject__c : 'Conversation';

        List<Comm_Recipient__c> rootRecipients = [
            SELECT Id, Name, Email_Address__c, Contact__c, Contact__r.Name, Recipient_Type__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :threadRootId
        ];
        populateConversationThreadRoot(thread, rootLog, rootRecipients);

        Set<Id> memberIds = collectThreadMemberIds(rootLog.Opportunity__c, threadRootId);
        if (memberIds.isEmpty()) {
            return thread;
        }

        List<Comm_Log__c> logs = [
            SELECT
                Id,
                Channel__c,
                Direction__c,
                Subject__c,
                Status__c,
                Sent_At__c,
                CreatedDate,
                Body_HTML__c,
                Delivery_Mode__c,
                From_Address__c,
                Parent_Comm_Log__c,
                Message_Id__c,
                Sent_By__r.Name,
                Sent_By__r.Email
            FROM Comm_Log__c
            WHERE Id IN :memberIds
            ORDER BY Sent_At__c ASC NULLS LAST, CreatedDate ASC
        ];

        Map<Id, List<Comm_Recipient__c>> recipientsByLog = new Map<Id, List<Comm_Recipient__c>>();
        for (Comm_Recipient__c rec : [
            SELECT Id, Name, Comm_Log__c, Email_Address__c, Contact__c, Contact__r.Name, Recipient_Type__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c IN :memberIds
        ]) {
            if (!recipientsByLog.containsKey(rec.Comm_Log__c)) {
                recipientsByLog.put(rec.Comm_Log__c, new List<Comm_Recipient__c>());
            }
            recipientsByLog.get(rec.Comm_Log__c).add(rec);
        }
        Map<Id, List<AttachmentDTO>> attachmentsByLog = queryAttachmentsByParentIds(memberIds);

        for (Comm_Log__c row : logs) {
            List<Comm_Recipient__c> recs = recipientsByLog.containsKey(row.Id)
                ? recipientsByLog.get(row.Id)
                : new List<Comm_Recipient__c>();
            List<AttachmentDTO> attachments = attachmentsByLog.containsKey(row.Id)
                ? attachmentsByLog.get(row.Id)
                : new List<AttachmentDTO>();
            thread.messages.add(buildConversationMessage(row, recs, attachments, threadRootId));
        }
        applyConversationThreadStats(thread);
        return thread;
    }

    @AuraEnabled
    public static ReplyComposeContextDTO getReplyComposeContext(Id commLogId, Boolean replyAll) {
        ReplyComposeContextDTO context = new ReplyComposeContextDTO();
        context.toRecipients = new List<RecipientDTO>();
        context.lockedToEmails = new List<String>();
        context.lockFromAddress = true;
        context.replyAll = replyAll == true;
        if (commLogId == null) {
            return context;
        }

        Comm_Log__c targetLog = [
            SELECT
                Id,
                Opportunity__c,
                Direction__c,
                Subject__c,
                From_Address__c,
                Sent_By__r.Name,
                Sent_By__r.Email
            FROM Comm_Log__c
            WHERE Id = :commLogId
            LIMIT 1
        ];
        List<Comm_Recipient__c> targetRecipients = [
            SELECT Id, Name, Email_Address__c, Contact__c, Contact__r.Name, Recipient_Type__c, Email_Send_Type__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :commLogId
        ];

        Id threadRootId = resolveThreadRootId(commLogId);
        Comm_Log__c rootLog = [
            SELECT Id, Subject__c
            FROM Comm_Log__c
            WHERE Id = :threadRootId
            LIMIT 1
        ];

        context.parentCommLogId = commLogId;
        context.subject = buildReplySubject(rootLog.Subject__c);

        Set<String> excludedEmails = collectInternalSenderEmails(targetLog.Opportunity__c);
        List<RecipientDTO> replyTo = new List<RecipientDTO>();
        if (replyAll == true) {
            Set<Id> memberIds = collectThreadMemberIds(targetLog.Opportunity__c, threadRootId);
            replyTo = collectConversationParticipantRecipients(memberIds, excludedEmails);
            context.lockedToEmails = extractRecipientEmails(replyTo);
        } else {
            replyTo = resolveReplyToForMessage(targetLog, targetRecipients, excludedEmails);
            if (!replyTo.isEmpty()) {
                context.lockedToEmails.add(replyTo[0].email);
            }
        }

        context.toRecipients = enrichReplyRecipientsWithCatalog(replyTo, targetLog.Opportunity__c);
        return context;
    }

    private static void populateConversationThreadRoot(
        ConversationThreadDTO thread,
        Comm_Log__c rootLog,
        List<Comm_Recipient__c> rootRecipients
    ) {
        if (thread == null || rootLog == null) {
            return;
        }
        List<String> recipientNames = new List<String>();
        for (Comm_Recipient__c rec : rootRecipients) {
            String who = resolveRecipientDisplayName(rec);
            if (!String.isBlank(who)) {
                recipientNames.add(who);
            }
        }

        thread.rootStatus = rootLog.Status__c;
        thread.rootDirection = rootLog.Direction__c;
        thread.rootSentBy = rootLog.Sent_By__r != null ? rootLog.Sent_By__r.Name : null;
        thread.rootFromDisplay = resolveHistoryFromDisplay(
            rootLog.From_Address__c,
            rootLog.Sent_By__r,
            rootLog.Direction__c == 'Inbound' ? rootRecipients : null
        );
        thread.rootSentAt = rootLog.Sent_At__c != null ? rootLog.Sent_At__c : rootLog.CreatedDate;
        thread.rootSentAtLabel = formatConversationFullTimestamp(thread.rootSentAt);
        thread.rootDeliveryMode = rootLog.Delivery_Mode__c;
        thread.rootDeliveryLabel = resolveConversationDeliveryLabel(rootLog.Delivery_Mode__c);
        thread.rootRecipientSummary = recipientNames.isEmpty() ? null : String.join(recipientNames, ', ');
        thread.rootMessageId = rootLog.Message_Id__c;
        thread.rootFromParty = resolveConversationRootFromParty(rootLog, rootRecipients);
        thread.rootToParties = resolveConversationRootToParties(rootLog, rootRecipients);
    }

    private static ConversationPartyDTO resolveConversationRootFromParty(
        Comm_Log__c rootLog,
        List<Comm_Recipient__c> rootRecipients
    ) {
        ConversationPartyDTO party = new ConversationPartyDTO();
        if (rootLog == null) {
            return party;
        }
        if (rootLog.Direction__c == 'Inbound') {
            if (rootRecipients != null && !rootRecipients.isEmpty()) {
                Comm_Recipient__c sender = rootRecipients[0];
                party.name = resolveRecipientDisplayName(sender);
                party.email = sender == null ? null : sender.Email_Address__c;
            }
            if (String.isBlank(party.email) && !String.isBlank(rootLog.From_Address__c)) {
                party.email = rootLog.From_Address__c.trim();
            }
            return party;
        }

        party.name = rootLog.Sent_By__r != null ? rootLog.Sent_By__r.Name : null;
        party.email = rootLog.Sent_By__r != null ? rootLog.Sent_By__r.Email : null;
        if (!String.isBlank(rootLog.From_Address__c)) {
            String fromAddress = rootLog.From_Address__c.trim();
            if (fromAddress.contains('<') && fromAddress.contains('>')) {
                Integer openIdx = fromAddress.indexOf('<');
                Integer closeIdx = fromAddress.indexOf('>');
                if (openIdx > 0 && closeIdx > openIdx) {
                    party.name = fromAddress.substring(0, openIdx).trim();
                    party.email = fromAddress.substring(openIdx + 1, closeIdx).trim();
                    return party;
                }
            }
            if (String.isBlank(party.email)) {
                party.email = fromAddress;
            }
        }
        return party;
    }

    private static List<ConversationPartyDTO> resolveConversationRootToParties(
        Comm_Log__c rootLog,
        List<Comm_Recipient__c> rootRecipients
    ) {
        List<ConversationPartyDTO> parties = new List<ConversationPartyDTO>();
        if (rootLog == null || rootRecipients == null || rootRecipients.isEmpty()) {
            return parties;
        }
        if (rootLog.Direction__c == 'Inbound') {
            return parties;
        }
        for (Comm_Recipient__c rec : rootRecipients) {
            ConversationPartyDTO party = new ConversationPartyDTO();
            party.name = resolveRecipientDisplayName(rec);
            party.email = rec == null ? null : rec.Email_Address__c;
            parties.add(party);
        }
        return parties;
    }

    private static void applyConversationThreadStats(ConversationThreadDTO thread) {
        if (thread == null || thread.messages == null) {
            return;
        }
        thread.inboundCount = 0;
        thread.outboundCount = 0;
        Set<String> participantKeys = new Set<String>();
        List<String> participants = new List<String>();
        Datetime firstAt;
        Datetime lastAt;

        for (ConversationMessageDTO message : thread.messages) {
            if (message == null) {
                continue;
            }
            if (message.isOutbound == true) {
                thread.outboundCount++;
            } else {
                thread.inboundCount++;
            }
            String participant = String.isNotBlank(message.senderDisplay)
                ? message.senderDisplay
                : message.senderName;
            if (!String.isBlank(participant)) {
                String key = participant.trim().toLowerCase();
                if (!participantKeys.contains(key)) {
                    participantKeys.add(key);
                    participants.add(participant);
                }
            }
            if (message.sentAt != null) {
                if (firstAt == null || message.sentAt < firstAt) {
                    firstAt = message.sentAt;
                }
                if (lastAt == null || message.sentAt > lastAt) {
                    lastAt = message.sentAt;
                }
            }
        }

        thread.participants = participants;
        thread.threadStartedLabel = formatConversationFullTimestamp(firstAt);
        thread.threadLastActivityLabel = formatConversationFullTimestamp(lastAt);
    }

    private static String resolveConversationDeliveryLabel(String deliveryMode) {
        if (String.isBlank(deliveryMode)) {
            return 'Postmark';
        }
        String normalized = deliveryMode.trim().toLowerCase();
        if (normalized == 'native' || normalized.contains('native') || normalized == 'salesforce' || normalized == 'sf') {
            return 'Native';
        }
        if (normalized == 'postmark') {
            return 'Postmark';
        }
        return deliveryMode;
    }

    private static void applyThreadMessageCounts(Id opportunityId, List<HistoryItemDTO> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<Id> rootIds = new Set<Id>();
        for (HistoryItemDTO row : rows) {
            if (row != null && row.threadRootId != null) {
                rootIds.add(row.threadRootId);
            }
        }
        if (rootIds.isEmpty()) {
            return;
        }

        Map<Id, Set<Id>> membersByRoot = new Map<Id, Set<Id>>();
        for (Id rootId : rootIds) {
            membersByRoot.put(rootId, collectThreadMemberIds(opportunityId, rootId));
        }
        for (HistoryItemDTO row : rows) {
            if (row == null || row.threadRootId == null) {
                continue;
            }
            Set<Id> members = membersByRoot.get(row.threadRootId);
            row.threadMessageCount = members == null ? 1 : members.size();
            row.threadRootId = row.threadRootId;
        }
    }

    private static String buildReplySubject(String subject) {
        String base = String.isBlank(subject) ? 'Conversation' : subject.trim();
        if (base.toLowerCase().startsWith('re:')) {
            return base;
        }
        return 'Re: ' + base;
    }

    private static Set<String> collectInternalSenderEmails(Id opportunityId) {
        Set<String> excluded = new Set<String>();
        String currentUserEmail = UserInfo.getUserEmail();
        if (!String.isBlank(currentUserEmail)) {
            excluded.add(currentUserEmail.trim().toLowerCase());
        }
        if (opportunityId == null) {
            return excluded;
        }
        for (Comm_Log__c row : [
            SELECT From_Address__c, Sent_By__r.Email
            FROM Comm_Log__c
            WHERE Opportunity__c = :opportunityId AND Direction__c = 'Outbound'
        ]) {
            if (!String.isBlank(row.From_Address__c)) {
                excluded.add(normalizeEmailKey(row.From_Address__c));
            }
            if (row.Sent_By__r != null && !String.isBlank(row.Sent_By__r.Email)) {
                excluded.add(normalizeEmailKey(row.Sent_By__r.Email));
            }
        }
        return excluded;
    }

    private static String normalizeEmailKey(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String trimmed = value.trim();
        if (trimmed.contains('<') && trimmed.contains('>')) {
            Integer openIdx = trimmed.indexOf('<');
            Integer closeIdx = trimmed.indexOf('>');
            if (openIdx >= 0 && closeIdx > openIdx) {
                trimmed = trimmed.substring(openIdx + 1, closeIdx).trim();
            }
        }
        return trimmed.toLowerCase();
    }

    private static List<RecipientDTO> resolveReplyToForMessage(
        Comm_Log__c targetLog,
        List<Comm_Recipient__c> targetRecipients,
        Set<String> excludedEmails
    ) {
        List<RecipientDTO> rows = new List<RecipientDTO>();
        if (targetLog == null) {
            return rows;
        }
        if (targetLog.Direction__c == 'Inbound') {
            RecipientDTO sender = buildReplyRecipientFromInbound(targetLog, targetRecipients);
            if (sender != null && !isExcludedReplyEmail(sender.email, excludedEmails)) {
                rows.add(sender);
            }
            return rows;
        }

        Integer idx = 0;
        for (Comm_Recipient__c rec : targetRecipients) {
            if (rec == null) {
                continue;
            }
            String emailSendType = rec.Email_Send_Type__c == null ? 'TO' : rec.Email_Send_Type__c.trim().toUpperCase();
            if (emailSendType != 'TO') {
                continue;
            }
            RecipientDTO row = buildReplyRecipientFromCommRecipient(rec, idx++);
            if (row != null && !isExcludedReplyEmail(row.email, excludedEmails)) {
                rows.add(row);
            }
        }
        return rows;
    }

    private static List<RecipientDTO> collectConversationParticipantRecipients(
        Set<Id> memberIds,
        Set<String> excludedEmails
    ) {
        List<RecipientDTO> rows = new List<RecipientDTO>();
        if (memberIds == null || memberIds.isEmpty()) {
            return rows;
        }
        Map<Id, Comm_Log__c> logsById = new Map<Id, Comm_Log__c>(
            [
                SELECT Id, Direction__c, From_Address__c, Sent_By__r.Name, Sent_By__r.Email
                FROM Comm_Log__c
                WHERE Id IN :memberIds
            ]
        );
        Map<Id, List<Comm_Recipient__c>> recipientsByLog = new Map<Id, List<Comm_Recipient__c>>();
        for (Comm_Recipient__c rec : [
            SELECT Id, Name, Email_Address__c, Contact__c, Contact__r.Name, Recipient_Type__c, Email_Send_Type__c, Comm_Log__c
            FROM Comm_Recipient__c
            WHERE Comm_Log__c IN :memberIds
        ]) {
            if (!recipientsByLog.containsKey(rec.Comm_Log__c)) {
                recipientsByLog.put(rec.Comm_Log__c, new List<Comm_Recipient__c>());
            }
            recipientsByLog.get(rec.Comm_Log__c).add(rec);
        }

        Map<String, RecipientDTO> byEmail = new Map<String, RecipientDTO>();
        Integer idx = 0;
        for (Id logId : logsById.keySet()) {
            Comm_Log__c row = logsById.get(logId);
            List<Comm_Recipient__c> recs = recipientsByLog.containsKey(logId)
                ? recipientsByLog.get(logId)
                : new List<Comm_Recipient__c>();
            if (row.Direction__c == 'Inbound') {
                RecipientDTO sender = buildReplyRecipientFromInbound(row, recs);
                addReplyRecipientIfNew(byEmail, sender, excludedEmails, idx++);
                continue;
            }
            for (Comm_Recipient__c rec : recs) {
                RecipientDTO participant = buildReplyRecipientFromCommRecipient(rec, idx++);
                addReplyRecipientIfNew(byEmail, participant, excludedEmails, idx);
            }
        }
        rows.addAll(byEmail.values());
        return rows;
    }

    private static void addReplyRecipientIfNew(
        Map<String, RecipientDTO> byEmail,
        RecipientDTO row,
        Set<String> excludedEmails,
        Integer idx
    ) {
        if (row == null || String.isBlank(row.email) || isExcludedReplyEmail(row.email, excludedEmails)) {
            return;
        }
        String key = normalizeEmailKey(row.email);
        if (!byEmail.containsKey(key)) {
            byEmail.put(key, row);
        }
    }

    private static Boolean isExcludedReplyEmail(String email, Set<String> excludedEmails) {
        if (String.isBlank(email) || excludedEmails == null || excludedEmails.isEmpty()) {
            return false;
        }
        return excludedEmails.contains(normalizeEmailKey(email));
    }

    private static RecipientDTO buildReplyRecipientFromInbound(
        Comm_Log__c inboundLog,
        List<Comm_Recipient__c> inboundRecipients
    ) {
        String name = resolveInboundSenderName(inboundRecipients, inboundLog.From_Address__c);
        String email = resolveInboundSenderEmail(inboundRecipients, inboundLog.From_Address__c);
        if (String.isBlank(email)) {
            return null;
        }
        RecipientDTO row = new RecipientDTO();
        row.name = String.isNotBlank(name) ? name : email;
        row.email = email.trim();
        row.role = 'Traveller';
        row.audience = 'travellers';
        row.initials = buildRecipientInitials(row.name);
        if (!inboundRecipients.isEmpty() && inboundRecipients[0].Contact__c != null) {
            row.contactId = inboundRecipients[0].Contact__c;
        }
        return row;
    }

    private static RecipientDTO buildReplyRecipientFromCommRecipient(Comm_Recipient__c rec, Integer idx) {
        if (rec == null || String.isBlank(rec.Email_Address__c)) {
            return null;
        }
        RecipientDTO row = new RecipientDTO();
        row.name = resolveRecipientDisplayName(rec);
        row.email = rec.Email_Address__c.trim();
        row.role = rec.Recipient_Type__c;
        row.audience = inferAudienceFromRecipientType(rec.Recipient_Type__c);
        row.contactId = rec.Contact__c;
        row.initials = buildRecipientInitials(row.name);
        return row;
    }

    private static String inferAudienceFromRecipientType(String recipientType) {
        String normalized = String.isBlank(recipientType) ? '' : recipientType.trim().toLowerCase();
        if (normalized.contains('supplier') || normalized.contains('agent')) {
            return 'suppliers';
        }
        return 'travellers';
    }

    private static String buildRecipientInitials(String name) {
        if (String.isBlank(name)) {
            return '?';
        }
        List<String> parts = name.trim().split('\\s+');
        if (parts.isEmpty()) {
            return '?';
        }
        if (parts.size() == 1) {
            return parts[0].length() > 1 ? parts[0].substring(0, 2).toUpperCase() : parts[0].toUpperCase();
        }
        return (parts[0].substring(0, 1) + parts[parts.size() - 1].substring(0, 1)).toUpperCase();
    }

    private static List<String> extractRecipientEmails(List<RecipientDTO> rows) {
        List<String> emails = new List<String>();
        if (rows == null) {
            return emails;
        }
        for (RecipientDTO row : rows) {
            if (row != null && !String.isBlank(row.email)) {
                emails.add(row.email.trim());
            }
        }
        return emails;
    }

    private static List<RecipientDTO> enrichReplyRecipientsWithCatalog(
        List<RecipientDTO> rows,
        Id opportunityId
    ) {
        if (rows == null || rows.isEmpty()) {
            return new List<RecipientDTO>();
        }
        Map<String, RecipientDTO> catalogByEmail = new Map<String, RecipientDTO>();
        for (RecipientDTO catalogRow : getRecipients(opportunityId)) {
            if (catalogRow != null && !String.isBlank(catalogRow.email)) {
                catalogByEmail.put(normalizeEmailKey(catalogRow.email), catalogRow);
            }
        }
        List<RecipientDTO> out = new List<RecipientDTO>();
        Integer idx = 0;
        for (RecipientDTO row : rows) {
            if (row == null || String.isBlank(row.email)) {
                continue;
            }
            RecipientDTO match = catalogByEmail.get(normalizeEmailKey(row.email));
            out.add(match != null ? match : row);
            idx++;
        }
        return out;
    }

    private static Map<Id, Id> queryParentMapForOpportunity(Id opportunityId) {
        Map<Id, Id> parentByLogId = new Map<Id, Id>();
        if (opportunityId == null) {
            return parentByLogId;
        }
        for (Comm_Log__c row : [
            SELECT Id, Parent_Comm_Log__c
            FROM Comm_Log__c
            WHERE Opportunity__c = :opportunityId
        ]) {
            parentByLogId.put(row.Id, row.Parent_Comm_Log__c);
        }
        return parentByLogId;
    }

    private static Id resolveThreadRootIdInMap(Id commLogId, Map<Id, Id> parentByLogId) {
        if (commLogId == null) {
            return null;
        }
        if (parentByLogId == null || parentByLogId.isEmpty()) {
            return commLogId;
        }
        Id currentId = commLogId;
        Set<Id> visited = new Set<Id>();
        while (currentId != null) {
            if (visited.contains(currentId)) {
                return commLogId;
            }
            visited.add(currentId);
            if (!parentByLogId.containsKey(currentId)) {
                return currentId;
            }
            Id parentId = parentByLogId.get(currentId);
            if (parentId == null) {
                return currentId;
            }
            currentId = parentId;
        }
        return commLogId;
    }

    private static Id resolveThreadRootId(Id commLogId) {
        if (commLogId == null) {
            return null;
        }
        List<Comm_Log__c> anchors = [
            SELECT Opportunity__c
            FROM Comm_Log__c
            WHERE Id = :commLogId
            LIMIT 1
        ];
        if (anchors.isEmpty()) {
            return commLogId;
        }
        Map<Id, Id> parentByLogId = queryParentMapForOpportunity(anchors[0].Opportunity__c);
        return resolveThreadRootIdInMap(commLogId, parentByLogId);
    }

    private static Set<Id> collectThreadMemberIds(Id opportunityId, Id rootId) {
        Set<Id> memberIds = new Set<Id>{ rootId };
        Boolean growing = true;
        while (growing) {
            growing = false;
            for (Comm_Log__c row : [
                SELECT Id
                FROM Comm_Log__c
                WHERE Opportunity__c = :opportunityId AND Parent_Comm_Log__c IN :memberIds AND Id NOT IN :memberIds
            ]) {
                memberIds.add(row.Id);
                growing = true;
            }
        }
        return memberIds;
    }

    private static ConversationMessageDTO buildConversationMessage(
        Comm_Log__c row,
        List<Comm_Recipient__c> recs,
        List<AttachmentDTO> attachments,
        Id threadRootId
    ) {
        ConversationMessageDTO message = new ConversationMessageDTO();
        message.id = row.Id;
        message.direction = row.Direction__c;
        message.parentCommLogId = row.Parent_Comm_Log__c;
        message.isOutbound = row.Direction__c != 'Inbound';
        message.isThreadRoot = row.Id == threadRootId;
        message.status = row.Status__c;
        message.messageId = row.Message_Id__c;
        message.deliveryMode = row.Delivery_Mode__c;
        message.subject = row.Subject__c;
        message.bodyHtml = row.Body_HTML__c;
        message.snippet = buildConversationSnippet(row.Body_HTML__c);
        message.sentAt = row.Sent_At__c != null ? row.Sent_At__c : row.CreatedDate;
        message.sentAtLabel = formatConversationTimestamp(message.sentAt);
        message.sentAtFullLabel = formatConversationFullTimestamp(message.sentAt);
        message.relativeLabel = formatConversationRelativeTime(message.sentAt);
        message.attachmentCount = attachments == null ? 0 : attachments.size();
        message.attachmentSummary = summarizeAttachmentNames(attachments);
        message.attachments = attachments == null ? new List<AttachmentDTO>() : attachments;

        List<String> recipientNames = new List<String>();
        for (Comm_Recipient__c rec : recs) {
            String who = resolveRecipientDisplayName(rec);
            if (!String.isBlank(who)) {
                recipientNames.add(who);
            }
        }
        message.recipientSummary = recipientNames.isEmpty() ? null : String.join(recipientNames, ', ');

        if (message.isOutbound) {
            message.senderName = row.Sent_By__r != null ? row.Sent_By__r.Name : 'Sugati';
            message.senderEmail = row.Sent_By__r != null ? row.Sent_By__r.Email : row.From_Address__c;
            message.senderDisplay = formatUserFromDisplay(message.senderName, message.senderEmail);
            message.senderVia = resolveConversationSenderVia(row.Delivery_Mode__c);
        } else {
            message.senderName = resolveInboundSenderName(recs, row.From_Address__c);
            message.senderEmail = resolveInboundSenderEmail(recs, row.From_Address__c);
            message.senderDisplay = resolveHistoryFromDisplay(row.From_Address__c, row.Sent_By__r, recs);
            message.senderVia = null;
        }
        return message;
    }

    private static String buildConversationSnippet(String bodyHtml) {
        if (String.isBlank(bodyHtml)) {
            return '';
        }
        String plain = bodyHtml.replaceAll('<[^>]+>', ' ').replaceAll('\\s+', ' ').trim();
        if (plain.length() <= 140) {
            return plain;
        }
        return plain.substring(0, 137) + '...';
    }

    private static String formatConversationTimestamp(Datetime value) {
        if (value == null) {
            return '';
        }
        return value.format('h:mm a');
    }

    private static String formatConversationFullTimestamp(Datetime value) {
        if (value == null) {
            return '';
        }
        return value.format('EEE, d MMM yyyy, h:mm a');
    }

    private static String formatConversationRelativeTime(Datetime value) {
        if (value == null) {
            return '';
        }
        Long diffMs = System.now().getTime() - value.getTime();
        Long diffMinutes = diffMs / (1000 * 60);
        if (diffMinutes < 1) {
            return 'just now';
        }
        if (diffMinutes < 60) {
            return diffMinutes + (diffMinutes == 1 ? ' minute ago' : ' minutes ago');
        }
        Long diffHours = diffMinutes / 60;
        if (diffHours < 24) {
            return diffHours + (diffHours == 1 ? ' hour ago' : ' hours ago');
        }
        Long diffDays = diffHours / 24;
        if (diffDays < 7) {
            return diffDays + (diffDays == 1 ? ' day ago' : ' days ago');
        }
        return value.format('d MMM yyyy');
    }

    private static String resolveConversationSenderVia(String deliveryMode) {
        if (String.isBlank(deliveryMode)) {
            return 'salesforce.com';
        }
        String normalized = deliveryMode.trim().toLowerCase();
        if (normalized == 'postmark') {
            return 'postmark.com';
        }
        if (normalized == 'native' || normalized.contains('native')) {
            return 'salesforce.com';
        }
        return null;
    }

    private static String resolveInboundSenderName(
        List<Comm_Recipient__c> recs,
        String fallbackFromAddress
    ) {
        if (recs != null && !recs.isEmpty() && String.isNotBlank(recs[0].Name)) {
            return recs[0].Name.trim();
        }
        if (!String.isBlank(fallbackFromAddress)) {
            return fallbackFromAddress.trim();
        }
        return 'Unknown sender';
    }

    private static String resolveInboundSenderEmail(
        List<Comm_Recipient__c> recs,
        String fallbackFromAddress
    ) {
        if (recs != null && !recs.isEmpty() && String.isNotBlank(recs[0].Email_Address__c)) {
            return recs[0].Email_Address__c.trim();
        }
        return String.isBlank(fallbackFromAddress) ? null : fallbackFromAddress.trim();
    }

    private static String buildTrackingSummary(
        String status,
        Datetime deliveredAt,
        Datetime firstOpenedAt,
        Datetime lastOpenedAt,
        Integer openCount,
        Integer clickCount,
        Datetime bouncedAt,
        String bounceType,
        Datetime spamReportedAt
    ) {
        List<String> parts = new List<String>();
        if (deliveredAt != null) {
            parts.add('Delivered ' + deliveredAt.format('dd MMM yyyy HH:mm'));
        }
        if (openCount != null && openCount > 0) {
            parts.add(openCount + (openCount == 1 ? ' open' : ' opens'));
        } else if (firstOpenedAt != null) {
            parts.add('Opened ' + firstOpenedAt.format('dd MMM yyyy HH:mm'));
        }
        if (lastOpenedAt != null && firstOpenedAt != null && lastOpenedAt != firstOpenedAt) {
            parts.add('Last open ' + lastOpenedAt.format('dd MMM yyyy HH:mm'));
        }
        if (clickCount != null && clickCount > 0) {
            parts.add(clickCount + (clickCount == 1 ? ' click' : ' clicks'));
        }
        if (bouncedAt != null) {
            String bounceLabel = String.isBlank(bounceType) ? 'Bounced' : 'Bounced (' + bounceType + ')';
            parts.add(bounceLabel + ' ' + bouncedAt.format('dd MMM yyyy HH:mm'));
        } else if (status == 'Bounced') {
            parts.add(String.isBlank(bounceType) ? 'Bounced' : 'Bounced (' + bounceType + ')');
        }
        if (spamReportedAt != null) {
            parts.add('Spam reported ' + spamReportedAt.format('dd MMM yyyy HH:mm'));
        } else if (status == 'Spam Complaint') {
            parts.add('Spam complaint');
        }
        return parts.isEmpty() ? null : String.join(parts, ' · ');
    }

    private static String resolveHistoryMessageId(String logMessageId, List<Comm_Recipient__c> recipients) {
        if (String.isNotBlank(logMessageId)) {
            return logMessageId.trim();
        }
        if (recipients == null) {
            return null;
        }
        for (Comm_Recipient__c rec : recipients) {
            if (rec != null && String.isNotBlank(rec.Message_Id__c)) {
                return rec.Message_Id__c.trim();
            }
        }
        return null;
    }

    private static void applySendMessageIds(
        Comm_Log__c log,
        List<Comm_Recipient__c> recipientRows,
        String messageId
    ) {
        applySendMessageIds(log, recipientRows, messageId, messageId);
    }

    private static void applySendMessageIds(
        Comm_Log__c log,
        List<Comm_Recipient__c> recipientRows,
        String logMessageId,
        String recipientMessageId
    ) {
        String recMessageId = String.isNotBlank(recipientMessageId) ? recipientMessageId : logMessageId;
        if (log != null) {
            log.Message_Id__c = logMessageId;
            log.Status__c = 'Sent';
        }
        if (recipientRows == null) {
            return;
        }
        for (Comm_Recipient__c rec : recipientRows) {
            if (rec == null) {
                continue;
            }
            rec.Message_Id__c = recMessageId;
            rec.Status__c = 'Sent';
            rec.Delivered_At__c = null;
        }
    }

    private class PostmarkSendOutcome {
        public String postmarkUuid;
        public String logMessageId;
    }

    private static void applySendMessageIdsToPersisted(Id commLogId, String messageId) {
        if (commLogId == null || String.isBlank(messageId)) {
            return;
        }
        update new Comm_Log__c(Id = commLogId, Message_Id__c = messageId);
        List<Comm_Recipient__c> recipientRows = [
            SELECT Id
            FROM Comm_Recipient__c
            WHERE Comm_Log__c = :commLogId
        ];
        for (Comm_Recipient__c rec : recipientRows) {
            rec.Message_Id__c = messageId;
        }
        if (!recipientRows.isEmpty()) {
            update recipientRows;
        }
    }

    @future
    private static void scheduleNativeMessageIdBackfill(Id commLogId, Id whatId, Long sentAfterEpoch) {
        if (commLogId == null || whatId == null) {
            return;
        }
        Comm_Log__c existing = [
            SELECT Message_Id__c
            FROM Comm_Log__c
            WHERE Id = :commLogId
            LIMIT 1
        ];
        if (String.isNotBlank(existing.Message_Id__c)) {
            return;
        }
        Datetime sentAfter = Datetime.newInstance(sentAfterEpoch);
        String messageId = resolveSentEmailMessageId(whatId, sentAfter);
        applySendMessageIdsToPersisted(commLogId, messageId);
    }

    private static Id resolveEmailWhatId(SendRequest request) {
        if (request == null) {
            return null;
        }
        if (request.opportunityId != null) {
            return request.opportunityId;
        }
        if (request.relatedRecordId != null) {
            String relatedKey = String.valueOf(request.relatedRecordId);
            if (relatedKey.startsWith('006') && (relatedKey.length() == 15 || relatedKey.length() == 18)) {
                return request.relatedRecordId;
            }
        }
        return null;
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
        for (Comm_Log__c log : [
            SELECT Id
            FROM Comm_Log__c
            WHERE Opportunity__c = :opportunityId AND Status__c IN ('Failed', 'Bounced', 'Spam Complaint')
        ]) {
            logIds.add(log.Id);
        }
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
        List<Id> attachmentContentDocumentIds,
        List<String> newAttachmentFileNames,
        List<String> newAttachmentFileData,
        Id parentCommLogId,
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
                attachmentContentDocumentIds,
                newAttachmentFileNames,
                newAttachmentFileData,
                parentCommLogId,
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
        List<Id> attachmentContentDocumentIds,
        List<String> newAttachmentFileNames,
        List<String> newAttachmentFileData,
        Id parentCommLogId,
        SendRequest request
    ) {
        request = request != null ? request : new SendRequest();
        if (parentCommLogId != null) {
            request.parentCommLogId = parentCommLogId;
        }
        mergeAttachmentParams(request, attachmentContentDocumentIds, newAttachmentFileNames, newAttachmentFileData);
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
        request.deliveryMode = normalizeDeliveryMode(
            String.isNotBlank(deliveryMode) ? deliveryMode : request.deliveryMode
        );
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

        request.resolvedSubject = outboundSubject;
        request.resolvedBodyHtml = outboundBodyHtml;

        Comm_Log__c log = new Comm_Log__c();
        log.Opportunity__c = request.opportunityId;
        log.Channel__c = String.isBlank(request.channel) ? EMAIL_CHANNEL : request.channel;
        log.Direction__c = 'Outbound';
        log.Subject__c = outboundSubject;
        log.Body_HTML__c = outboundBodyHtml;
        log.Sent_At__c = System.now();
        log.Sent_By__c = UserInfo.getUserId();
        log.From_Address__c = resolveFromAddressDisplay(request.orgWideEmailAddressId);
        log.Delivery_Mode__c = request.deliveryMode;
        log.Send_Method__c = request.deliveryMode == 'postmark' ? 'Postmark' : 'Native Salesforce';
        log.Status__c = 'Sent';
        if (request.parentCommLogId != null) {
            log.Parent_Comm_Log__c = request.parentCommLogId;
        }
        Savepoint sendSavepoint;
        try {
            String providerMessageId;
            List<Comm_Recipient__c> recipientRows = new List<Comm_Recipient__c>();
            Set<Id> attachmentDocIds;
            Boolean isPostmark = request.deliveryMode == 'postmark';

            if (isPostmark) {
                // Postmark requires callout before any DML in the transaction.
                attachmentDocIds = buildAttachmentDocumentIdSet(
                    request.attachmentContentDocumentIds,
                    request.attachmentRecordIds,
                    null,
                    null,
                    null,
                    null
                );
                AttachmentSendBundle postmarkBundle = buildAttachmentSendBundle(
                    request.attachmentRecordIds,
                    attachmentDocIds
                );
                PostmarkSendOutcome postmarkOutcome = sendViaPostmark(request, postmarkBundle);
                providerMessageId = postmarkOutcome.logMessageId;
                sendSavepoint = Database.setSavepoint();
                insert log;
                recipientRows = buildCommRecipientsFromSendRequest(log.Id, request);
                applySendMessageIds(
                    log,
                    recipientRows,
                    postmarkOutcome.logMessageId,
                    postmarkOutcome.postmarkUuid
                );
                if (!recipientRows.isEmpty()) {
                    insert recipientRows;
                }
                attachmentDocIds.addAll(
                    createUploadedContentDocuments(
                        request.newAttachmentFileNames,
                        request.newAttachmentFileData,
                        log.Id,
                        null
                    )
                );
                syncCommLogAttachments(log.Id, attachmentDocIds);
                update log;
            } else if (request.deliveryMode == 'native') {
                sendSavepoint = Database.setSavepoint();
                insert log;
                recipientRows = buildCommRecipientsFromSendRequest(log.Id, request);
                if (!recipientRows.isEmpty()) {
                    insert recipientRows;
                }
                attachmentDocIds = buildAttachmentDocumentIdSet(
                    request.attachmentContentDocumentIds,
                    request.attachmentRecordIds,
                    request.newAttachmentFileNames,
                    request.newAttachmentFileData,
                    log.Id,
                    null
                );
                syncCommLogAttachments(log.Id, attachmentDocIds);
                AttachmentSendBundle nativeBundle = buildAttachmentSendBundle(
                    request.attachmentRecordIds,
                    attachmentDocIds
                );
                List<TravellerSendTarget> nativeToTargets = parseTravellerSendTargets(request);
                List<String> nativeCc = cleanEmailList(request.ccEmails);
                List<String> nativeBcc = cleanEmailList(request.bccEmails);
                validateNativeSendTargets(nativeToTargets, nativeCc, nativeBcc, nativeBundle);
                Id emailWhatId = resolveEmailWhatId(request);
                Datetime sentAfter = System.now().addSeconds(-10);
                dispatchNativeEmailMessages(
                    buildOutboundEmailMessages(
                        request,
                        nativeToTargets,
                        nativeCc,
                        nativeBcc,
                        nativeBundle
                    )
                );
                providerMessageId = resolveSentEmailMessageId(emailWhatId, sentAfter);
                applySendMessageIds(log, recipientRows, providerMessageId);
                update log;
                if (!recipientRows.isEmpty()) {
                    update recipientRows;
                }
                if (String.isBlank(providerMessageId) && log.Id != null && emailWhatId != null) {
                    scheduleNativeMessageIdBackfill(log.Id, emailWhatId, sentAfter.getTime());
                }
            } else {
                throw new AuraHandledException('Unsupported delivery mode: ' + request.deliveryMode);
            }

            SendResponse response = new SendResponse();
            response.commLogId = log.Id;
            response.status = log.Status__c;
            response.providerMessageId = providerMessageId;
            response.message =
                'Message sent via ' +
                (request.deliveryMode == 'postmark' ? 'Postmark' : 'Salesforce Email') +
                (String.isNotBlank(providerMessageId) ? ' (' + providerMessageId + ')' : '');
            return response;
        } catch (Exception ex) {
            if (sendSavepoint != null) {
                Database.rollback(sendSavepoint);
            }
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
        List<String> attachmentRecordIds,
        List<String> newAttachmentFileNames,
        List<String> newAttachmentFileData,
        Id orgWideEmailAddressId,
        Id parentCommLogId
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
            log.From_Address__c = resolveFromAddressDisplay(orgWideEmailAddressId);
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
            log.From_Address__c = resolveFromAddressDisplay(orgWideEmailAddressId);
            log.Delivery_Mode__c = deliveryMode;
            log.Status__c = 'Draft';
            if (parentCommLogId != null) {
                log.Parent_Comm_Log__c = parentCommLogId;
            }
            stampDraftLastModified(log);
            insert log;
            insertDraftRecipients(log.Id, recipients == null ? new List<DraftRecipientInput>() : recipients);
        }

        Set<Id> attachmentDocIds = buildAttachmentDocumentIdSet(
            attachmentContentDocumentIds,
            attachmentRecordIds,
            newAttachmentFileNames,
            newAttachmentFileData,
            log.Id,
            null
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

    private static List<Comm_Recipient__c> buildCommRecipientsFromSendRequest(Id commLogId, SendRequest request) {
        List<Comm_Recipient__c> rows = new List<Comm_Recipient__c>();
        rows.addAll(buildCommRecipientRowsFromJson(commLogId, request.toRecipientsJson, 'TO'));
        rows.addAll(buildCommRecipientRowsFromJson(commLogId, request.ccRecipientsJson, 'CC'));
        rows.addAll(buildCommRecipientRowsFromJson(commLogId, request.bccRecipientsJson, 'BCC'));

        if (rows.isEmpty() && request != null) {
            rows.addAll(buildCommRecipientRows(commLogId, request.toEmails, 'TO'));
            rows.addAll(buildCommRecipientRows(commLogId, request.ccEmails, 'CC'));
            rows.addAll(buildCommRecipientRows(commLogId, request.bccEmails, 'BCC'));
        } else {
            Set<String> coveredKeys = new Set<String>();
            for (Comm_Recipient__c rec : rows) {
                coveredKeys.add(recipientDedupeKey(rec.Email_Address__c, rec.Email_Send_Type__c));
            }
            rows.addAll(
                buildCommRecipientRowsMissingFromJson(
                    commLogId,
                    request,
                    coveredKeys
                )
            );
        }
        return rows;
    }

    private static String recipientDedupeKey(String email, String emailSendType) {
        String normalizedEmail = String.isBlank(email) ? '' : email.trim().toLowerCase();
        return normalizedEmail + '|' + normalizeEmailSendType(emailSendType);
    }

    private static List<Comm_Recipient__c> buildCommRecipientRowsMissingFromJson(
        Id commLogId,
        SendRequest request,
        Set<String> coveredKeys
    ) {
        List<Comm_Recipient__c> rows = new List<Comm_Recipient__c>();
        if (request == null) {
            return rows;
        }
        rows.addAll(
            buildCommRecipientRowsNotCovered(commLogId, request.toEmails, 'TO', coveredKeys)
        );
        rows.addAll(
            buildCommRecipientRowsNotCovered(commLogId, request.ccEmails, 'CC', coveredKeys)
        );
        rows.addAll(
            buildCommRecipientRowsNotCovered(commLogId, request.bccEmails, 'BCC', coveredKeys)
        );
        return rows;
    }

    private static List<Comm_Recipient__c> buildCommRecipientRowsNotCovered(
        Id commLogId,
        List<String> emails,
        String emailSendType,
        Set<String> coveredKeys
    ) {
        List<Comm_Recipient__c> rows = new List<Comm_Recipient__c>();
        if (emails == null) {
            return rows;
        }
        String normalizedType = normalizeEmailSendType(emailSendType);
        for (String email : emails) {
            if (String.isBlank(email)) {
                continue;
            }
            String key = recipientDedupeKey(email, normalizedType);
            if (coveredKeys != null && coveredKeys.contains(key)) {
                continue;
            }
            Comm_Recipient__c rec = new Comm_Recipient__c();
            rec.Comm_Log__c = commLogId;
            rec.Email_Address__c = email.trim();
            rec.Name = email.trim();
            rec.Email_Send_Type__c = normalizedType;
            rec.Recipient_Type__c = 'Traveller';
            rec.Status__c = 'Sent';
            rows.add(rec);
            if (coveredKeys != null) {
                coveredKeys.add(key);
            }
        }
        return rows;
    }

    private static List<Comm_Recipient__c> buildCommRecipientRowsFromJson(
        Id commLogId,
        String recipientsJson,
        String emailSendType
    ) {
        List<Comm_Recipient__c> rows = new List<Comm_Recipient__c>();
        if (String.isBlank(recipientsJson)) {
            return rows;
        }
        try {
            List<Object> rawRows = (List<Object>) JSON.deserializeUntyped(recipientsJson);
            Set<String> seen = new Set<String>();
            String normalizedType = normalizeEmailSendType(emailSendType);
            for (Object row : rawRows) {
                if (!(row instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> mapped = (Map<String, Object>) row;
                Object emailRaw = mapped.get('email');
                if (emailRaw == null || String.isBlank(String.valueOf(emailRaw))) {
                    continue;
                }
                String email = String.valueOf(emailRaw).trim();
                String key = recipientDedupeKey(email, normalizedType);
                if (seen.contains(key)) {
                    continue;
                }
                seen.add(key);
                Comm_Recipient__c rec = new Comm_Recipient__c();
                rec.Comm_Log__c = commLogId;
                rec.Email_Address__c = email;
                rec.Contact__c = parseRecipientContactId(mapped.get('contactId'));
                Object nameRaw = mapped.get('name');
                rec.Name = resolveRecipientName(
                    nameRaw != null ? String.valueOf(nameRaw) : null,
                    email
                );
                Object roleRaw = mapped.get('role');
                rec.Recipient_Type__c = normalizeRecipientType(
                    roleRaw != null ? String.valueOf(roleRaw) : null
                );
                rec.Email_Send_Type__c = normalizedType;
                rec.Status__c = 'Sent';
                rows.add(rec);
            }
        } catch (Exception ex) {
            return new List<Comm_Recipient__c>();
        }
        return rows;
    }

    private static Id parseRecipientContactId(Object contactRaw) {
        if (contactRaw == null) {
            return null;
        }
        String contactKey = String.valueOf(contactRaw).trim();
        if (!contactKey.startsWith('003') || (contactKey.length() != 15 && contactKey.length() != 18)) {
            return null;
        }
        return sanitizeContactId((Id) contactKey);
    }

    private static List<Comm_Recipient__c> buildCommRecipientRows(Id commLogId, List<String> emails, String emailSendType) {
        return buildCommRecipientRowsNotCovered(commLogId, emails, emailSendType, new Set<String>());
    }

    private class TravellerSendTarget {
        private String email;
        private Id contactId;
        private Id groupMemberId;
    }

    private static void validateNativeSendTargets(
        List<TravellerSendTarget> toTargets,
        List<String> ccAddresses,
        List<String> bccAddresses,
        AttachmentSendBundle sendBundle
    ) {
        List<String> toAddresses = new List<String>();
        for (TravellerSendTarget target : toTargets) {
            if (target != null && !String.isBlank(target.email)) {
                toAddresses.add(target.email.trim());
            }
        }
        toAddresses = cleanEmailList(toAddresses);
        if (toAddresses.isEmpty() && ccAddresses.isEmpty() && bccAddresses.isEmpty()) {
            throw new AuraHandledException('At least one recipient is required.');
        }
        if (
            sendBundle != null &&
            hasAttachmentPayload(sendBundle) &&
            buildEmailFileAttachments(sendBundle).isEmpty()
        ) {
            throw new AuraHandledException(
                'Selected attachments could not be read. Check file access on the related record or re-upload the files.'
            );
        }
    }

    private static String resolveSentEmailMessageId(Id whatId, Datetime sentAfter) {
        if (whatId == null) {
            return Test.isRunningTest() ? 'NATIVE-TEST' : null;
        }
        if (Test.isRunningTest()) {
            return 'NATIVE-TEST';
        }
        List<EmailMessage> emails = [
            SELECT Id, MessageIdentifier
            FROM EmailMessage
            WHERE (RelatedToId = :whatId OR ParentId = :whatId)
              AND CreatedDate >= :sentAfter
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!emails.isEmpty()) {
            return resolveNativeEmailMessageKey(emails[0]);
        }
        List<Task> tasks = [
            SELECT Id
            FROM Task
            WHERE WhatId = :whatId
              AND CreatedDate >= :sentAfter
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (tasks.isEmpty()) {
            return null;
        }
        emails = [
            SELECT Id, MessageIdentifier
            FROM EmailMessage
            WHERE ActivityId = :tasks[0].Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return emails.isEmpty() ? null : resolveNativeEmailMessageKey(emails[0]);
    }

    private static String resolveNativeEmailMessageKey(EmailMessage email) {
        if (email == null) {
            return null;
        }
        if (String.isNotBlank(email.MessageIdentifier)) {
            return email.MessageIdentifier.trim();
        }
        return email.Id != null ? String.valueOf(email.Id) : null;
    }

    private static String normalizeDeliveryMode(String rawMode) {
        if (String.isBlank(rawMode)) {
            return 'postmark';
        }
        String normalized = rawMode.trim().toLowerCase();
        if (normalized == 'native' || normalized == 'salesforce' || normalized == 'sf') {
            return 'native';
        }
        if (normalized == 'postmark') {
            return 'postmark';
        }
        return 'postmark';
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

    private static List<Messaging.SingleEmailMessage> buildOutboundEmailMessages(
        SendRequest request,
        List<TravellerSendTarget> toTargets,
        List<String> ccAddresses,
        List<String> bccAddresses,
        AttachmentSendBundle sendBundle
    ) {
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        String subjectText = !String.isBlank(request.resolvedSubject)
            ? request.resolvedSubject
            : blankSafe(request.subjectTemplate);
        String bodyHtml = !String.isBlank(request.resolvedBodyHtml)
            ? request.resolvedBodyHtml
            : blankSafe(request.bodyTemplate);

        if (String.isBlank(subjectText)) {
            throw new AuraHandledException('Subject is required.');
        }
        if (String.isBlank(bodyHtml)) {
            throw new AuraHandledException('Email body is required.');
        }

        List<String> toAddresses = new List<String>();
        for (TravellerSendTarget target : toTargets) {
            if (target != null && !String.isBlank(target.email)) {
                toAddresses.add(target.email.trim());
            }
        }
        toAddresses = cleanEmailList(toAddresses);

        Boolean hasAnyRecipients =
            !toAddresses.isEmpty() || !ccAddresses.isEmpty() || !bccAddresses.isEmpty();
        if (!hasAnyRecipients) {
            throw new AuraHandledException('At least one recipient is required.');
        }

        messages.add(
            buildNativeEmailMessage(
                toAddresses,
                ccAddresses,
                bccAddresses,
                subjectText,
                bodyHtml,
                resolveEmailWhatId(request),
                request.orgWideEmailAddressId,
                sendBundle
            )
        );
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
        AttachmentSendBundle sendBundle
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
        String replyTo = resolveCommHubReplyTo(orgWideEmailAddressId);
        if (String.isNotBlank(replyTo)) {
            mail.setReplyTo(replyTo);
        }
        if (Test.isRunningTest()) {
            lastNativeReplyTo = replyTo;
        }
        mail.setSaveAsActivity(true);

        List<Messaging.EmailFileAttachment> fileAttachments = buildEmailFileAttachments(
            sendBundle
        );
        if (!fileAttachments.isEmpty()) {
            mail.setFileAttachments(fileAttachments);
        }
        return mail;
    }

    private static Boolean hasAttachmentPayload(AttachmentSendBundle sendBundle) {
        if (sendBundle == null) {
            return false;
        }
        return !sendBundle.contentDocumentIds.isEmpty() ||
            (sendBundle.attachmentRecords != null && !sendBundle.attachmentRecords.isEmpty()) ||
            (sendBundle.contentVersions != null && !sendBundle.contentVersions.isEmpty());
    }

    private static AttachmentSendBundle buildSendBundle(List<String> attachmentRecordIds) {
        AttachmentSendBundle bundle = new AttachmentSendBundle();
        if (attachmentRecordIds == null || attachmentRecordIds.isEmpty()) {
            return bundle;
        }
        Set<Id> docIds = new Set<Id>();
        Set<Id> attachmentObjectIds = new Set<Id>();
        for (String rawId : attachmentRecordIds) {
            if (String.isBlank(rawId)) {
                continue;
            }
            String key = rawId.trim();
            if (key.length() != 15 && key.length() != 18) {
                continue;
            }
            if (key.startsWith('069')) {
                docIds.add((Id) key);
            } else if (key.startsWith('00P')) {
                attachmentObjectIds.add((Id) key);
            }
        }
        if (!docIds.isEmpty()) {
            bundle.contentDocumentIds.addAll(docIds);
            bundle.contentVersions = loadContentVersionsForSend(docIds);
        }
        if (!attachmentObjectIds.isEmpty() && Schema.sObjectType.Attachment.isAccessible()) {
            bundle.attachmentRecords = [
                SELECT Id, Name, Body, ContentType
                FROM Attachment
                WHERE Id IN :attachmentObjectIds
            ];
        }
        return bundle;
    }

    private static List<Messaging.EmailFileAttachment> buildEmailFileAttachments(AttachmentSendBundle sendBundle) {
        List<Messaging.EmailFileAttachment> out = new List<Messaging.EmailFileAttachment>();
        if (sendBundle == null) {
            return out;
        }
        if (sendBundle.contentVersions != null) {
            for (ContentVersion cv : sendBundle.contentVersions) {
                if (cv == null || cv.VersionData == null || cv.VersionData.size() == 0) {
                    continue;
                }
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setBody(cv.VersionData);
                efa.setFileName(resolveAttachmentFileName(cv));
                out.add(efa);
            }
        }
        if (sendBundle.attachmentRecords != null) {
            for (Attachment att : sendBundle.attachmentRecords) {
                if (att == null || att.Body == null || att.Body.size() == 0) {
                    continue;
                }
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setBody(att.Body);
                efa.setFileName(String.isNotBlank(att.Name) ? att.Name : 'attachment');
                out.add(efa);
            }
        }
        return out;
    }

    private static String resolveAttachmentFileName(ContentVersion cv) {
        if (cv == null) {
            return 'attachment';
        }
        if (String.isNotBlank(cv.PathOnClient)) {
            return cv.PathOnClient;
        }
        return String.isNotBlank(cv.Title) ? cv.Title : 'attachment';
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

    private static List<Map<String, Object>> buildPostmarkAttachments(
        AttachmentSendBundle sendBundle
    ) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (sendBundle == null || sendBundle.contentVersions == null || sendBundle.contentVersions.isEmpty()) {
            return out;
        }
        for (ContentVersion cv : sendBundle.contentVersions) {
            if (cv == null || cv.VersionData == null || cv.VersionData.size() == 0) {
                continue;
            }
            out.add(new Map<String, Object>{
                'Name' => resolveAttachmentFileName(cv),
                'Content' => EncodingUtil.base64Encode(cv.VersionData),
                'ContentType' => mimeTypeForFileName(resolveAttachmentFileName(cv))
            });
        }
        return out;
    }

    private static List<Map<String, Object>> buildPostmarkAttachmentsFromBase64(
        List<String> fileNames,
        List<String> fileDataBase64
    ) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        Integer count = fileNames == null ? 0 : fileNames.size();
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
            out.add(new Map<String, Object>{
                'Name' => fileName,
                'Content' => EncodingUtil.base64Encode(body),
                'ContentType' => mimeTypeForFileName(fileName)
            });
        }
        return out;
    }

    private static String mimeTypeForFileName(String fileName) {
        if (String.isBlank(fileName)) {
            return 'application/octet-stream';
        }
        String lower = fileName.toLowerCase();
        if (lower.endsWith('.pdf')) {
            return 'application/pdf';
        }
        if (lower.endsWith('.png')) {
            return 'image/png';
        }
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
            return 'image/jpeg';
        }
        if (lower.endsWith('.gif')) {
            return 'image/gif';
        }
        if (lower.endsWith('.doc')) {
            return 'application/msword';
        }
        if (lower.endsWith('.docx')) {
            return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        }
        if (lower.endsWith('.xls')) {
            return 'application/vnd.ms-excel';
        }
        if (lower.endsWith('.xlsx')) {
            return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        }
        if (lower.endsWith('.txt')) {
            return 'text/plain';
        }
        if (lower.endsWith('.html') || lower.endsWith('.htm')) {
            return 'text/html';
        }
        if (lower.endsWith('.csv')) {
            return 'text/csv';
        }
        return 'application/octet-stream';
    }

    private static List<ContentVersion> loadContentVersionsForSend(Set<Id> attachmentDocIds) {
        if (attachmentDocIds == null || attachmentDocIds.isEmpty()) {
            return new List<ContentVersion>();
        }
        return new ContentFileService().loadLatestByDocumentIds(attachmentDocIds);
    }

    private static List<String> normalizeDocTypeFilters(List<String> docTypes) {
        List<String> out = new List<String>();
        if (docTypes == null) {
            return out;
        }
        for (String raw : docTypes) {
            if (String.isBlank(raw)) {
                continue;
            }
            out.add(raw.trim().toLowerCase());
        }
        return out;
    }

    private static Boolean matchesAutoAttachmentFilter(AttachmentDTO row, List<String> filters) {
        if (filters == null || filters.isEmpty()) {
            return true;
        }
        String name = row == null || String.isBlank(row.name) ? '' : row.name.toLowerCase();
        String fileType = row == null || String.isBlank(row.fileType) ? '' : row.fileType.toLowerCase();
        for (String token : filters) {
            if (String.isBlank(token)) {
                continue;
            }
            if (name.contains(token) || fileType == token) {
                return true;
            }
        }
        return false;
    }

    private static void mergeAttachmentParams(
        SendRequest request,
        List<Id> attachmentContentDocumentIds,
        List<String> newAttachmentFileNames,
        List<String> newAttachmentFileData
    ) {
        if (request == null) {
            return;
        }
        Set<Id> docIds = normalizeContentDocumentIds(attachmentContentDocumentIds);
        if (docIds.isEmpty()) {
            docIds = normalizeContentDocumentIds(request.attachmentContentDocumentIds);
        }
        request.attachmentContentDocumentIds = new List<Id>(docIds);
        if (request.attachmentRecordIds == null) {
            request.attachmentRecordIds = new List<String>();
        }
        request.attachmentRecordIds = mergeAttachmentRecordIds(request.attachmentRecordIds, request.attachmentContentDocumentIds);

        if (newAttachmentFileNames != null && !newAttachmentFileNames.isEmpty()) {
            request.newAttachmentFileNames = newAttachmentFileNames;
        }
        if (newAttachmentFileData != null && !newAttachmentFileData.isEmpty()) {
            request.newAttachmentFileData = newAttachmentFileData;
        }
    }

    private static List<String> mergeAttachmentRecordIds(List<String> recordIds, List<Id> contentDocumentIds) {
        Set<String> merged = new Set<String>();
        if (recordIds != null) {
            for (String recordId : recordIds) {
                if (!String.isBlank(recordId)) {
                    merged.add(recordId.trim());
                }
            }
        }
        if (contentDocumentIds != null) {
            for (Id docId : contentDocumentIds) {
                if (docId != null) {
                    merged.add(String.valueOf(docId));
                }
            }
        }
        return new List<String>(merged);
    }

    private static AttachmentSendBundle buildAttachmentSendBundle(
        List<String> attachmentRecordIds,
        Set<Id> uploadedContentDocumentIds
    ) {
        List<String> mergedIds = mergeAttachmentRecordIds(attachmentRecordIds, new List<Id>(uploadedContentDocumentIds));
        return buildSendBundle(mergedIds);
    }

    private static String extractExtension(String fileName) {
        if (String.isBlank(fileName)) {
            return '';
        }
        Integer dotIndex = fileName.lastIndexOf('.');
        if (dotIndex < 0 || dotIndex >= fileName.length() - 1) {
            return '';
        }
        return fileName.substring(dotIndex + 1);
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

    private static PostmarkSendOutcome sendViaPostmark(
        SendRequest request,
        AttachmentSendBundle sendBundle
    ) {
        PostmarkSendOutcome outcome = new PostmarkSendOutcome();
        if (Test.isRunningTest()) {
            outcome.postmarkUuid = 'POSTMARK-TEST';
            outcome.logMessageId = '<POSTMARK-TEST@mtasv.net>';
            return outcome;
        }

        List<TravellerSendTarget> toTargets = parseTravellerSendTargets(request);
        List<String> ccAddresses = cleanEmailList(request.ccEmails);
        List<String> bccAddresses = cleanEmailList(request.bccEmails);
        if (toTargets.isEmpty() && ccAddresses.isEmpty() && bccAddresses.isEmpty()) {
            throw new AuraHandledException('At least one recipient is required.');
        }

        List<Messaging.SingleEmailMessage> messages = buildOutboundEmailMessages(
            request,
            toTargets,
            ccAddresses,
            bccAddresses,
            sendBundle
        );
        String fromAddress = resolvePostmarkFromAddress(request.orgWideEmailAddressId);
        List<Map<String, Object>> postmarkAttachments = buildPostmarkAttachments(sendBundle);
        postmarkAttachments.addAll(
            buildPostmarkAttachmentsFromBase64(request.newAttachmentFileNames, request.newAttachmentFileData)
        );
        try {
            for (Messaging.SingleEmailMessage mail : messages) {
                SugatiCommunicationPostmarkEmailService.PostmarkEmailRequest payload = new SugatiCommunicationPostmarkEmailService.PostmarkEmailRequest();
                payload.fromAddress = fromAddress;
                payload.ReplyTo = resolveCommHubReplyTo(request.orgWideEmailAddressId);
                payload.To = String.join(mail.getToAddresses(), ',');
                payload.Subject = mail.getSubject();
                payload.HtmlBody = mail.getHtmlBody();
                List<String> ccList = mail.getCcAddresses();
                if (ccList != null && !ccList.isEmpty()) {
                    payload.Cc = String.join(ccList, ',');
                }
                List<String> bccList = mail.getBccAddresses();
                if (bccList != null && !bccList.isEmpty()) {
                    payload.Bcc = String.join(bccList, ',');
                }
                if (!postmarkAttachments.isEmpty()) {
                    payload.Attachments = toPostmarkAttachmentPayload(postmarkAttachments);
                }
                SugatiCommunicationPostmarkEmailService.PostmarkEmailResponse response = SugatiCommunicationPostmarkEmailService.sendEmail(payload);
                if (response != null && String.isNotBlank(response.MessageID)) {
                    outcome.postmarkUuid = response.MessageID;
                    outcome.logMessageId = SugatiCommunicationPostmarkEmailService.resolveOutboundRfcMessageId(response.MessageID);
                }
            }
            if (String.isBlank(outcome.logMessageId)) {
                outcome.logMessageId = 'POSTMARK-SENT';
            }
            if (String.isBlank(outcome.postmarkUuid)) {
                outcome.postmarkUuid = outcome.logMessageId;
            }
            return outcome;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Postmark is not available (' +
                    toUserFacingExceptionMessage(ex) +
                    '). Configure the Postmark named credential or choose Native Salesforce Email.'
            );
        }
    }

    private static List<SugatiCommunicationPostmarkEmailService.PostmarkAttachment> toPostmarkAttachmentPayload(
        List<Map<String, Object>> rawAttachments
    ) {
        List<SugatiCommunicationPostmarkEmailService.PostmarkAttachment> out = new List<SugatiCommunicationPostmarkEmailService.PostmarkAttachment>();
        if (rawAttachments == null || rawAttachments.isEmpty()) {
            return out;
        }
        for (Map<String, Object> row : rawAttachments) {
            if (row == null) {
                continue;
            }
            SugatiCommunicationPostmarkEmailService.PostmarkAttachment att = new SugatiCommunicationPostmarkEmailService.PostmarkAttachment();
            att.Name = row.containsKey('Name') ? String.valueOf(row.get('Name')) : null;
            att.Content = row.containsKey('Content') ? String.valueOf(row.get('Content')) : null;
            att.ContentType = row.containsKey('ContentType') ? String.valueOf(row.get('ContentType')) : null;
            if (String.isBlank(att.Name) || String.isBlank(att.Content)) {
                continue;
            }
            out.add(att);
        }
        return out;
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
        Set<String> seen = new Set<String>();
        for (Id parentId : parentIds) {
            for (AttachmentDTO row : queryRecordAttachments(parentId, selected)) {
                String key = row.attachmentRecordId;
                if (seen.contains(key)) {
                    continue;
                }
                seen.add(key);
                out.add(row);
            }
        }
        return out;
    }

    private static List<AttachmentDTO> queryRecordAttachments(Id parentId, Set<Id> selectedDocIds) {
        List<AttachmentDTO> out = new List<AttachmentDTO>();
        if (parentId == null) {
            return out;
        }
        Set<Id> selected = selectedDocIds == null ? new Set<Id>() : selectedDocIds;
        Set<String> seen = new Set<String>();
        for (ContentDocumentLink link : [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileExtension,
                ContentDocument.ContentSize,
                ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :parentId
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            if (link.ContentDocumentId == null) {
                continue;
            }
            String recordKey = String.valueOf(link.ContentDocumentId);
            if (seen.contains(recordKey)) {
                continue;
            }
            seen.add(recordKey);
            AttachmentDTO dto = mapContentDocumentToAttachment(
                link.ContentDocument,
                selected.contains(link.ContentDocumentId)
            );
            if (dto != null) {
                out.add(dto);
            }
        }

        if (Schema.sObjectType.Attachment.isAccessible()) {
            for (Attachment att : [
                SELECT Id, Name, Body, ContentType
                FROM Attachment
                WHERE ParentId = :parentId
                ORDER BY CreatedDate DESC
            ]) {
                String recordKey = String.valueOf(att.Id);
                if (seen.contains(recordKey)) {
                    continue;
                }
                seen.add(recordKey);
                AttachmentDTO dto = mapAttachmentRecordToDto(att, selected.contains(att.Id));
                if (dto != null) {
                    out.add(dto);
                }
            }
        }
        return out;
    }

    private static Map<Id, List<AttachmentDTO>> queryAttachmentsByParentIds(Set<Id> parentIds) {
        Map<Id, List<AttachmentDTO>> out = new Map<Id, List<AttachmentDTO>>();
        if (parentIds == null || parentIds.isEmpty()) {
            return out;
        }
        Set<String> seenByParent = new Set<String>();
        for (Id parentId : parentIds) {
            out.put(parentId, new List<AttachmentDTO>());
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
            String dedupeKey = String.valueOf(link.LinkedEntityId) + ':' + String.valueOf(link.ContentDocumentId);
            if (seenByParent.contains(dedupeKey)) {
                continue;
            }
            seenByParent.add(dedupeKey);
            AttachmentDTO dto = mapContentDocumentToAttachment(link.ContentDocument, true);
            if (dto != null) {
                out.get(link.LinkedEntityId).add(dto);
            }
        }
        if (Schema.sObjectType.Attachment.isAccessible()) {
            for (Attachment att : [
                SELECT Id, Name, Body, ContentType, ParentId
                FROM Attachment
                WHERE ParentId IN :parentIds
                ORDER BY CreatedDate DESC
            ]) {
                if (att.ParentId == null) {
                    continue;
                }
                String dedupeKey = String.valueOf(att.ParentId) + ':' + String.valueOf(att.Id);
                if (seenByParent.contains(dedupeKey)) {
                    continue;
                }
                seenByParent.add(dedupeKey);
                AttachmentDTO dto = mapAttachmentRecordToDto(att, true);
                if (dto != null && out.containsKey(att.ParentId)) {
                    out.get(att.ParentId).add(dto);
                }
            }
        }
        return out;
    }

    private static AttachmentDTO mapContentVersionToAttachment(ContentVersion latest, Boolean selected) {
        if (latest == null || latest.ContentDocumentId == null) {
            return null;
        }
        String fileName = resolveAttachmentFileName(latest);
        AttachmentDTO dto = new AttachmentDTO();
        dto.contentDocumentId = latest.ContentDocumentId;
        dto.attachmentRecordId = String.valueOf(latest.ContentDocumentId);
        dto.storageKind = 'ContentDocument';
        dto.name = fileName;
        dto.meta = formatAttachmentMeta(latest.VersionData == null ? 0 : latest.VersionData.size());
        dto.fileType = inferAttachmentFileType(extractExtension(fileName));
        dto.sizeBytes = latest.VersionData == null ? 0 : latest.VersionData.size();
        dto.selected = selected == true;
        dto.isPendingUpload = false;
        dto.autoSuggested = false;
        return dto;
    }

    private static AttachmentDTO mapContentDocumentToAttachment(ContentDocument doc, Boolean selected) {
        if (doc == null) {
            return null;
        }
        AttachmentDTO dto = new AttachmentDTO();
        dto.contentDocumentId = doc.Id;
        dto.attachmentRecordId = String.valueOf(doc.Id);
        dto.storageKind = 'ContentDocument';
        dto.name = buildFileDisplayName(doc.Title, doc.FileExtension);
        dto.meta = formatAttachmentMeta(doc.ContentSize);
        dto.fileType = inferAttachmentFileType(doc.FileExtension);
        dto.sizeBytes = doc.ContentSize == null ? 0 : Integer.valueOf(doc.ContentSize);
        dto.selected = selected == true;
        dto.isPendingUpload = false;
        dto.autoSuggested = false;
        return dto;
    }

    private static AttachmentDTO mapAttachmentRecordToDto(Attachment att, Boolean selected) {
        if (att == null) {
            return null;
        }
        AttachmentDTO dto = new AttachmentDTO();
        dto.attachmentRecordId = String.valueOf(att.Id);
        dto.storageKind = 'Attachment';
        dto.name = String.isNotBlank(att.Name) ? att.Name : 'Attachment';
        dto.meta = formatAttachmentMeta(att.Body == null ? 0 : att.Body.size());
        dto.fileType = inferAttachmentFileType(extractExtension(dto.name));
        dto.sizeBytes = att.Body == null ? 0 : att.Body.size();
        dto.selected = selected == true;
        dto.isPendingUpload = false;
        dto.autoSuggested = false;
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
        List<String> attachmentRecordIds,
        List<String> newFileNames,
        List<String> newFileDataBase64,
        Id commLogId,
        Id opportunityId
    ) {
        Set<Id> docIds = normalizeContentDocumentIds(existingDocumentIds);
        docIds.addAll(extractContentDocumentIdsFromRecordIds(attachmentRecordIds));
        docIds.addAll(createUploadedContentDocuments(newFileNames, newFileDataBase64, commLogId, opportunityId));
        docIds.addAll(copyAttachmentRecordsToContentDocuments(attachmentRecordIds, commLogId, opportunityId));
        return docIds;
    }

    private static Set<Id> extractContentDocumentIdsFromRecordIds(List<String> attachmentRecordIds) {
        Set<Id> docIds = new Set<Id>();
        if (attachmentRecordIds == null || attachmentRecordIds.isEmpty()) {
            return docIds;
        }
        AttachmentSendBundle bundle = buildSendBundle(
            attachmentRecordIds
        );
        docIds.addAll(bundle.contentDocumentIds);
        return docIds;
    }

    private static Set<Id> copyAttachmentRecordsToContentDocuments(
        List<String> attachmentRecordIds,
        Id publishParentId,
        Id opportunityId
    ) {
        Set<Id> createdDocIds = new Set<Id>();
        if (attachmentRecordIds == null || attachmentRecordIds.isEmpty() || publishParentId == null) {
            return createdDocIds;
        }
        AttachmentSendBundle bundle = buildSendBundle(
            attachmentRecordIds
        );
        if (bundle.attachmentRecords == null || bundle.attachmentRecords.isEmpty()) {
            return createdDocIds;
        }
        ContentFileService fileService = new ContentFileService();
        Set<Id> additionalParents = new Set<Id>();
        for (Attachment att : bundle.attachmentRecords) {
            if (att == null || att.Body == null || att.Body.size() == 0) {
                continue;
            }
            String fileName = String.isNotBlank(att.Name) ? att.Name : 'attachment.bin';
            createdDocIds.addAll(
                fileService.createFiles(
                    new List<String>{ fileName },
                    new List<String>{ EncodingUtil.base64Encode(att.Body) },
                    publishParentId,
                    additionalParents
                )
            );
        }
        return createdDocIds;
    }

    private static Set<Id> normalizeContentDocumentIds(List<Id> existingDocumentIds) {
        Set<Id> docIds = new Set<Id>();
        if (existingDocumentIds == null) {
            return docIds;
        }
        for (Id docId : existingDocumentIds) {
            if (docId == null) {
                continue;
            }
            String key = String.valueOf(docId);
            if (!key.startsWith('069')) {
                continue;
            }
            docIds.add(docId);
        }
        return docIds;
    }

    private without sharing class ContentFileService {
        public Set<Id> createFiles(
            List<String> fileNames,
            List<String> fileDataBase64,
            Id opportunityId,
            Set<Id> additionalParentIds
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
                if (opportunityId != null) {
                    version.FirstPublishLocationId = opportunityId;
                }
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

            Set<Id> parents = new Set<Id>();
            if (opportunityId != null) {
                parents.add(opportunityId);
            }
            if (additionalParentIds != null) {
                parents.addAll(additionalParentIds);
            }
            linkDocumentsToParents(createdDocIds, parents);
            return createdDocIds;
        }

        public List<ContentVersion> loadLatestByDocumentIds(Set<Id> attachmentDocIds) {
            List<ContentVersion> docuLinks = new List<ContentVersion>();
            if (attachmentDocIds == null || attachmentDocIds.isEmpty()) {
                return docuLinks;
            }
            for (ContentVersion cv : [
                SELECT Id, VersionData, Title, PathOnClient, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :attachmentDocIds AND IsLatest = true
            ]) {
                docuLinks.add(cv);
            }
            return docuLinks;
        }

        public void linkDocumentsToParents(Set<Id> contentDocumentIds, Set<Id> parentIds) {
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
                Database.insert(toInsert, false);
            }
        }
    }

    private static Set<Id> createUploadedContentDocuments(
        List<String> fileNames,
        List<String> fileDataBase64,
        Id commLogId,
        Id opportunityId
    ) {
        if (commLogId == null) {
            return new Set<Id>();
        }
        return new ContentFileService().createFiles(fileNames, fileDataBase64, commLogId, null);
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
        new ContentFileService().linkDocumentsToParents(toLink, new Set<Id>{ commLogId });
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

    private static String resolveFromAddressDisplay(Id orgWideEmailAddressId) {
        if (orgWideEmailAddressId != null) {
            List<OrgWideEmailAddress> rows = [
                SELECT Address, DisplayName
                FROM OrgWideEmailAddress
                WHERE Id = :orgWideEmailAddressId
                LIMIT 1
            ];
            if (!rows.isEmpty() && !String.isBlank(rows[0].Address)) {
                return formatUserFromDisplay(rows[0].DisplayName, rows[0].Address);
            }
        }
        throw new AuraHandledException(
            'A From address is required. Please select an org-wide email address in the composer.'
        );
    }

    private static String resolvePostmarkFromAddress(Id orgWideEmailAddressId) {
        if (orgWideEmailAddressId != null) {
            List<OrgWideEmailAddress> rows = [
                SELECT Address, DisplayName
                FROM OrgWideEmailAddress
                WHERE Id = :orgWideEmailAddressId
                LIMIT 1
            ];
            if (!rows.isEmpty() && !String.isBlank(rows[0].Address)) {
                return formatPostmarkFrom(rows[0].DisplayName, rows[0].Address);
            }
        }
        throw new AuraHandledException(
            'A From address is required. Select an org-wide email in the composer.'
        );
    }

    private static String formatPostmarkFrom(String displayName, String email) {
        String trimmedEmail = String.isNotBlank(email) ? email.trim() : '';
        if (String.isBlank(trimmedEmail)) {
            throw new AuraHandledException('The selected From address is invalid.');
        }
        String trimmedName = String.isNotBlank(displayName) ? displayName.trim() : '';
        if (String.isNotBlank(trimmedName)) {
            return trimmedName + ' <' + trimmedEmail + '>';
        }
        return trimmedEmail;
    }

    private static String resolveHistoryFromDisplay(
        String fromAddress,
        User sentBy,
        List<Comm_Recipient__c> inboundRecipients
    ) {
        if (!String.isBlank(fromAddress)) {
            return fromAddress.trim();
        }
        if (inboundRecipients != null && !inboundRecipients.isEmpty()) {
            Comm_Recipient__c sender = inboundRecipients[0];
            String senderName = resolveRecipientDisplayName(sender);
            String senderEmail = sender == null ? null : sender.Email_Address__c;
            if (String.isNotBlank(senderName) && String.isNotBlank(senderEmail)) {
                return senderName + ' <' + senderEmail.trim() + '>';
            }
            if (String.isNotBlank(senderEmail)) {
                return senderEmail.trim();
            }
            if (String.isNotBlank(senderName)) {
                return senderName;
            }
        }
        if (sentBy == null) {
            return 'Unknown sender';
        }
        return formatUserFromDisplay(sentBy.Name, sentBy.Email);
    }

    private static String formatUserFromDisplay(String name, String email) {
        String trimmedName = String.isNotBlank(name) ? name.trim() : '';
        String trimmedEmail = String.isNotBlank(email) ? email.trim() : '';
        if (String.isNotBlank(trimmedName) && String.isNotBlank(trimmedEmail)) {
            return trimmedName + ' <' + trimmedEmail + '>';
        }
        if (String.isNotBlank(trimmedEmail)) {
            return trimmedEmail;
        }
        if (String.isNotBlank(trimmedName)) {
            return trimmedName;
        }
        return 'Unknown sender';
    }
}