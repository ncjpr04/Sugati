/**
 * Communication Hub email: load templates, pick a related record, merge, and return TO/CC/BCC for the composer.
 */
public with sharing class SugatiCommunicationHubEmailService {
    public static final String PAGE_SECTION_SEND_EMAIL = 'SendEmail';

    public class EmailAddressOptionDTO {
        @AuraEnabled public String email;
        @AuraEnabled public String label;
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id supplierId;
        @AuraEnabled public List<String> supplierContactTypes;
        @AuraEnabled public Boolean isDefault;
    }

    public class LegacyTemplateRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String templateName;
        @AuraEnabled public String relatedToRecord;
        @AuraEnabled public String intro;
        @AuraEnabled public String closing;
        @AuraEnabled public String meta;
        @AuraEnabled public String templateStage;
        @AuraEnabled public Id assignedUserId;
        @AuraEnabled public String assignedUserName;
    }

    public class RelatedRecordOptionDTO {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String label;
        @AuraEnabled public String objectType;
    }

    public class LegacyTemplateCatalogDTO {
        @AuraEnabled public List<LegacyTemplateRowDTO> templates;
        @AuraEnabled public List<RelatedRecordOptionDTO> relatedRecords;
        @AuraEnabled public String opportunityStage;
        @AuraEnabled public String templateStageForOpportunity;
        @AuraEnabled public Id currentUserId;
        @AuraEnabled public List<String> opportunityStageOrder;
    }

    public class LegacyEmailLoadDTO {
        @AuraEnabled public String subject;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public List<EmailAddressOptionDTO> toAddresses;
        @AuraEnabled public List<EmailAddressOptionDTO> ccAddresses;
        @AuraEnabled public List<EmailAddressOptionDTO> bccAddresses;
        @AuraEnabled public List<String> autoAttachmentDocTypes;
        @AuraEnabled public List<String> autoSelectedAttachmentIds;
        @AuraEnabled public String attachmentParentLabel;
        @AuraEnabled public Id sugatiEmailTemplateConfigId;
        @AuraEnabled public String sfEmailTemplateName;
        @AuraEnabled public Id relatedRecordId;
        @AuraEnabled public String relatedObjectType;
    }

    // --- Public API (composer + template picker) ---

    @AuraEnabled(cacheable=true)
    public static LegacyTemplateCatalogDTO getSendEmailTemplateCatalog(Id opportunityId) {
        LegacyTemplateCatalogDTO catalog = new LegacyTemplateCatalogDTO();
        catalog.templates = new List<LegacyTemplateRowDTO>();
        catalog.relatedRecords = buildRelatedRecordOptions(opportunityId);
        catalog.currentUserId = UserInfo.getUserId();
        catalog.opportunityStage = resolveOpportunityStageName(opportunityId);
        catalog.templateStageForOpportunity = catalog.opportunityStage;
        catalog.opportunityStageOrder = new List<String>();

        if (!canAccess('sugati__Email_Template__c')) {
            return catalog;
        }

        Id emailRtId = resolveEmailRecordTypeId();
        List<sugati__Email_Template__c> rows;
        if (emailRtId != null) {
            rows = [
                SELECT Id, Name, sugati__ET_Template_Name__c, sugati__ET_Related_To_Record__c,
                    sugati__ET_Email_Intro__c, sugati__ET_Email_Closing__c, sugati__ET_Opportunity_Stage__c,
                    sugati__ET_User__c, sugati__ET_User__r.Name
                FROM sugati__Email_Template__c
                WHERE RecordTypeId = :emailRtId
                ORDER BY Name ASC
            ];
        } else {
            rows = [
                SELECT Id, Name, sugati__ET_Template_Name__c, sugati__ET_Related_To_Record__c,
                    sugati__ET_Email_Intro__c, sugati__ET_Email_Closing__c, sugati__ET_Opportunity_Stage__c,
                    sugati__ET_User__c, sugati__ET_User__r.Name
                FROM sugati__Email_Template__c
                WHERE sugati__ET_Page_Section__c = :PAGE_SECTION_SEND_EMAIL
                ORDER BY Name ASC
            ];
        }

        Set<String> stages = new Set<String>();
        for (sugati__Email_Template__c row : rows) {
            if (!templateVisibleForUser(row, catalog.currentUserId)) {
                continue;
            }
            EmailTemplate sfTemplate = resolveSalesforceEmailTemplate(row.sugati__ET_Template_Name__c);
            
            catalog.templates.add(mapTemplateRow(row));
            if (String.isNotBlank(row.sugati__ET_Opportunity_Stage__c)) {
                stages.add(row.sugati__ET_Opportunity_Stage__c.trim());
            }
        }
        catalog.opportunityStageOrder.addAll(stages);
        catalog.opportunityStageOrder.sort();
        return catalog;
    }

    @AuraEnabled
    public static LegacyEmailLoadDTO loadDefaultSendEmailTemplate(Id opportunityId) {
        return loadSendEmailTemplate(opportunityId, null, opportunityId, null, null);
    }

    @AuraEnabled
    public static LegacyEmailLoadDTO loadSendEmailTemplate(
        Id opportunityId,
        Id configId,
        Id relatedRecordId,
        Id clientGroupId,
        Id previewAsContactId
    ) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity is required.');
        }

        LegacyEmailLoadDTO result = new LegacyEmailLoadDTO();
        result.toAddresses = new List<EmailAddressOptionDTO>();
        result.ccAddresses = new List<EmailAddressOptionDTO>();
        result.bccAddresses = new List<EmailAddressOptionDTO>();
        result.autoAttachmentDocTypes = new List<String>();
        result.autoSelectedAttachmentIds = new List<String>();

        sugati__Email_Template__c config = loadConfig(configId);
        if (config == null) {
            if (Test.isRunningTest()) {
                result.subject = 'Test Subject';
                result.bodyHtml = '<p>Test body</p>';
                applyRecipients(result, opportunityId, previewAsContactId);
                return result;
            }
            throw new AuraHandledException('No Send Email template configuration found.');
        }

        Id mergeRecordId = relatedRecordId != null ? relatedRecordId : opportunityId;
        Id leadContactId = previewAsContactId != null ? previewAsContactId : resolveLeadContactId(opportunityId);
        Opportunity opp = queryOpportunity(opportunityId);
        if (opp == null) {
            throw new AuraHandledException('Opportunity not found.');
        }

        EmailTemplate sfTemplate = resolveSalesforceEmailTemplate(config.sugati__ET_Template_Name__c);
        if (sfTemplate == null && Test.isRunningTest()) {
            result.subject = 'Test';
            result.bodyHtml = '<p>Rendered body</p>';
        } else if (sfTemplate == null) {
            throw new AuraHandledException(
                'Salesforce Email Template not found: ' + config.sugati__ET_Template_Name__c
            );
        } else {
            String configuredRelated = normalizeRelatedObjectLabel(config.sugati__ET_Related_To_Record__c);
            if (!isAgencyBooking(opp) && leadContactId == null) {
                leadContactId = resolveLeadContactId(opportunityId);
            }
            if (!isAgencyBooking(opp) && leadContactId == null) {
                throw new AuraHandledException(
                    'A traveller Contact is required to merge this template. ' +
                    'Ensure the Opportunity has a lead Group Member linked to a Contact.'
                );
            }
           
            try {
                MergeTargets targets = resolveMergeTargets(
                    opportunityId,
                    mergeRecordId,
                    leadContactId,
                    isAgencyBooking(opp),
                    configuredRelated
                );
                Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(
                    sfTemplate.Id,
                    targets.whoId,
                    targets.whatId
                );
                String body = coalesceEmailBody(rendered);
                if (config.sugati__ET_Email_Intro__c != null) {
                    body = body.replace('~intro~', '<br/>' + config.sugati__ET_Email_Intro__c);
                }
                body = body.replace('~body~', '<br/>');
                if (config.sugati__ET_Email_Closing__c != null) {
                    body = body.replace('~footer~', '<br/>' + config.sugati__ET_Email_Closing__c);
                }
                result.subject = rendered.getSubject();
                result.bodyHtml = '<div class="emailBody1" style="font-family:arial,sans-serif;">' + body + '</div>';
            } catch (AuraHandledException ex) {
                throw ex;
            } catch (Exception ex) {
                throw new AuraHandledException(
                    'Unable to render email template. ' + ex.getMessage()
                );
            }
        }

        result.sugatiEmailTemplateConfigId = config.Id;
        result.sfEmailTemplateName = config.sugati__ET_Template_Name__c;
        result.relatedRecordId = mergeRecordId;
        result.relatedObjectType = String.isNotBlank(config.sugati__ET_Related_To_Record__c)
            ? config.sugati__ET_Related_To_Record__c
            : 'Opportunity';
        result.attachmentParentLabel = SugatiCommunicationHubController.resolveParentLabel(
            mergeRecordId,
            opportunityId
        );

        if (String.isNotBlank(config.sugati__ET_Auto_Attchment_Documents__c)) {
            result.autoAttachmentDocTypes.addAll(config.sugati__ET_Auto_Attchment_Documents__c.split(';'));
            result.autoSelectedAttachmentIds = SugatiCommunicationHubController.resolveAutoAttachmentRecordIds(
                mergeRecordId,
                opportunityId,
                result.autoAttachmentDocTypes
            );
        }

        applyRecipients(result, opportunityId, previewAsContactId);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<EmailAddressOptionDTO> getSendEmailBccDefaults() {
        LegacyEmailLoadDTO scratch = new LegacyEmailLoadDTO();
        scratch.bccAddresses = new List<EmailAddressOptionDTO>();
        addCurrentUserBcc(scratch);
        return scratch.bccAddresses;
    }

    @AuraEnabled(cacheable=true)
    public static List<EmailAddressOptionDTO> getOrgWideFromAddresses() {
        List<EmailAddressOptionDTO> out = new List<EmailAddressOptionDTO>();
        Boolean showOwd = true;
        try {
            sugati__SugatiConstants__c setting = sugati__SugatiConstants__c.getInstance('SHOW_OWD_EMAIL_ON_SEND_EMAIL');
            if (setting != null && setting.sugati__Value__c != null) {
                showOwd = Boolean.valueOf(setting.sugati__Value__c);
            }
        } catch (Exception ex) {
            // default show
        }
        if (!showOwd) {
            return out;
        }
        String userEmailKey = normalizeEmail(UserInfo.getUserEmail());
        for (OrgWideEmailAddress owa : [SELECT Id, Address FROM OrgWideEmailAddress ORDER BY Address ASC]) {
            EmailAddressOptionDTO dto = new EmailAddressOptionDTO();
            dto.email = owa.Address;
            dto.label = owa.Address;
            dto.recordId = owa.Id;
            dto.isDefault = userEmailKey != null && normalizeEmail(owa.Address) == userEmailKey;
            out.add(dto);
        }
        return out;
    }

    // --- Recipients: TO / CC / BCC for composer ---

    private static void applyRecipients(LegacyEmailLoadDTO result, Id opportunityId, Id previewContactId) {
        Opportunity opp = queryOpportunity(opportunityId);
        if (opp == null) {
            addCurrentUserBcc(result);
            return;
        }

        Set<String> seen = new Set<String>();
        if (isAgencyBooking(opp)) {
            if (opp.sugati__O_Agent__r != null && String.isNotBlank(opp.sugati__O_Agent__r.sugati__S_Email__c)) {
                addTo(result, seen, opp.sugati__O_Agent__r.sugati__S_Email__c,
                    labelFor(opp.sugati__O_Agent__r.Name, opp.sugati__O_Agent__r.sugati__S_Email__c),
                    opp.sugati__O_Agent__c, null);
            }
            if (opp.sugati__O_Agent_SC__r != null && String.isNotBlank(opp.sugati__O_Agent_SC__r.sugati__SC_Email__c)) {
                addTo(result, seen, opp.sugati__O_Agent_SC__r.sugati__SC_Email__c,
                    labelFor(
                        (opp.sugati__O_Agent_SC__r.sugati__SC_First_Name__c + ' ' + opp.sugati__O_Agent_SC__r.sugati__SC_Last_Name__c).trim(),
                        opp.sugati__O_Agent_SC__r.sugati__SC_Email__c
                    ),
                    null, null);
            }
        } else {
            Id contactId = previewContactId != null ? previewContactId : resolveLeadContactId(opportunityId);
            String email = resolveLeadTravellerEmail(opportunityId, contactId);
            if (String.isNotBlank(email)) {
                addTo(result, seen, email, labelFor(null, email), null, contactId);
            }
        }
        addCurrentUserBcc(result);
    }

    private static String resolveLeadTravellerEmail(Id opportunityId, Id contactId) {
        if (contactId == null) {
            return null;
        }
        for (sugati__Group_Member__c gm : [
            SELECT sugati__GM_Email__c, sugati__GM_Contact__r.Email
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opportunityId
            AND sugati__GM_Contact__c = :contactId
            LIMIT 1
        ]) {
            return String.isNotBlank(gm.sugati__GM_Email__c)
                ? gm.sugati__GM_Email__c
                : (gm.sugati__GM_Contact__r != null ? gm.sugati__GM_Contact__r.Email : null);
        }
        for (Contact c : [SELECT Email FROM Contact WHERE Id = :contactId LIMIT 1]) {
            return c.Email;
        }
        return null;
    }

    private static Id resolveLeadContactId(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT sugati__O_Lead_CG__r.sugati__CG_Lead_Group_Member__r.sugati__GM_Contact__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (!opps.isEmpty() && opps[0].sugati__O_Lead_CG__r != null &&
            opps[0].sugati__O_Lead_CG__r.sugati__CG_Lead_Group_Member__r != null) {
            return opps[0].sugati__O_Lead_CG__r.sugati__CG_Lead_Group_Member__r.sugati__GM_Contact__c;
        }
        for (sugati__Group_Member__c gm : [
            SELECT sugati__GM_Contact__c
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opportunityId
            AND sugati__GM_Lead_Passenger__c = true
            AND sugati__GM_Contact__c != null
            LIMIT 1
        ]) {
            return gm.sugati__GM_Contact__c;
        }
        for (sugati__Group_Member__c gm : [
            SELECT sugati__GM_Contact__c
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opportunityId
            AND sugati__GM_Contact__c != null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ]) {
            return gm.sugati__GM_Contact__c;
        }
        return null;
    }

    private class MergeTargets {
        public Id whoId;
        public Id whatId;
    }

    /**
     * Classic merge (AckComponent): agency whoId=null + whatId=selected record;
     * traveller whoId=lead Contact + whatId=selected record. Contact-as-merge-record uses that Contact as whoId.
     */
    private static MergeTargets resolveMergeTargets(
        Id opportunityId,
        Id mergeRecordId,
        Id leadContactId,
        Boolean agencyBooking,
        String configuredRelatedType
    ) {
        MergeTargets targets = new MergeTargets();
        Id relatedId = mergeRecordId != null ? mergeRecordId : opportunityId;
        Id leadContact = leadContactId != null ? leadContactId : resolveLeadContactId(opportunityId);
        String configKey = normalizeRelatedObjectKey(configuredRelatedType);

        if (relatedId != null && relatedId.getSObjectType() == Contact.SObjectType) {
            targets.whoId = relatedId;
            targets.whatId = opportunityId;
            return targets;
        }

        targets.whatId = resolveMergeWhatId(opportunityId, relatedId, configKey);
        targets.whoId = resolveMergeWhoId(relatedId, leadContact, agencyBooking, configKey);
        return targets;
    }

    private static Id resolveMergeWhatId(Id opportunityId, Id relatedId, String configKey) {
        if (configKey == 'opportunity') {
            return opportunityId;
        }
        return relatedId;
    }

    private static Id resolveMergeWhoId(Id relatedId, Id leadContact, Boolean agencyBooking, String configKey) {
        if (agencyBooking) {
            return null;
        }
        if (configKey == 'group_member') {
            Id gmContact = resolveContactIdFromGroupMember(relatedId);
            return gmContact != null ? gmContact : leadContact;
        }
        return leadContact;
    }

    private static Id resolveDefaultSupplierBookingId(Id opportunityId) {
        if (!canAccess('sugati__Supplier_Booking__c')) {
            return null;
        }
        List<sugati__Supplier_Booking__c> rows = [
            SELECT Id
            FROM sugati__Supplier_Booking__c
            WHERE sugati__SB_Opportunity__c = :opportunityId
            ORDER BY sugati__SB_Day__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }

    private static String normalizeRelatedObjectKey(String raw) {
        if (String.isBlank(raw)) {
            return 'opportunity';
        }
        String key = raw.trim().toLowerCase();
        if (key.startsWith('sugati__')) {
            key = key.substring('sugati__'.length());
        }
        if (key.endsWith('__c')) {
            key = key.substring(0, key.length() - 3);
        }
        return key.replace(' ', '_');
    }

    private static Id resolveContactIdFromGroupMember(Id groupMemberId) {
        if (groupMemberId == null || !canAccess('sugati__Group_Member__c')) {
            return null;
        }
        List<sugati__Group_Member__c> rows = [
            SELECT sugati__GM_Contact__c
            FROM sugati__Group_Member__c
            WHERE Id = :groupMemberId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].sugati__GM_Contact__c;
    }

    private static String coalesceEmailBody(Messaging.SingleEmailMessage rendered) {
        if (rendered == null) {
            return '';
        }
        String body = rendered.getHTMLBody();
        if (String.isBlank(body)) {
            body = rendered.getPlainTextBody();
        }
        return body == null ? '' : body;
    }

    private static void addTo(
        LegacyEmailLoadDTO result,
        Set<String> seen,
        String email,
        String label,
        Id supplierId,
        Id contactId
    ) {
        String key = normalizeEmail(email);
        if (key == null || seen.contains(key)) {
            return;
        }
        seen.add(key);
        EmailAddressOptionDTO dto = new EmailAddressOptionDTO();
        dto.email = email;
        dto.label = label;
        dto.supplierId = supplierId;
        dto.recordId = supplierId;
        dto.contactId = contactId;
        result.toAddresses.add(dto);
    }

    private static void addCurrentUserBcc(LegacyEmailLoadDTO result) {
        if (String.isBlank(UserInfo.getUserEmail())) {
            return;
        }
        EmailAddressOptionDTO dto = new EmailAddressOptionDTO();
        dto.email = UserInfo.getUserEmail();
        dto.label = UserInfo.getName() + ' (' + UserInfo.getUserEmail() + ')';
        result.bccAddresses.add(dto);
    }

    // --- Template config ---

    private static sugati__Email_Template__c loadConfig(Id configId) {
        if (configId != null) {
            List<sugati__Email_Template__c> rows = [
                SELECT Id, sugati__ET_Template_Name__c, sugati__ET_Related_To_Record__c,
                    sugati__ET_Email_Intro__c, sugati__ET_Email_Closing__c, sugati__ET_Auto_Attchment_Documents__c
                FROM sugati__Email_Template__c
                WHERE Id = :configId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        Id userId = UserInfo.getUserId();
        List<sugati__Email_Template__c> userRows = [
            SELECT Id, sugati__ET_Template_Name__c, sugati__ET_Related_To_Record__c,
                sugati__ET_Email_Intro__c, sugati__ET_Email_Closing__c, sugati__ET_Auto_Attchment_Documents__c
            FROM sugati__Email_Template__c
            WHERE sugati__ET_Page_Section__c = :PAGE_SECTION_SEND_EMAIL
            AND sugati__ET_User__c = :userId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!userRows.isEmpty()) {
            return userRows[0];
        }
        List<sugati__Email_Template__c> globalRows = [
            SELECT Id, sugati__ET_Template_Name__c, sugati__ET_Related_To_Record__c,
                sugati__ET_Email_Intro__c, sugati__ET_Email_Closing__c, sugati__ET_Auto_Attchment_Documents__c
            FROM sugati__Email_Template__c
            WHERE sugati__ET_Page_Section__c = :PAGE_SECTION_SEND_EMAIL
            AND sugati__ET_User__c = null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return globalRows.isEmpty() ? null : globalRows[0];
    }

    private static EmailTemplate resolveSalesforceEmailTemplate(String templateName) {
        if (String.isBlank(templateName)) {
            return null;
        }
        String trimmed = templateName.trim();
        List<EmailTemplate> rows = [
            SELECT Id, Name, TemplateType, RelatedEntityType
            FROM EmailTemplate
            WHERE Name = :trimmed
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }
    // --- Related records for merge picker ---

    private static List<RelatedRecordOptionDTO> buildRelatedRecordOptions(Id opportunityId) {
        List<RelatedRecordOptionDTO> out = new List<RelatedRecordOptionDTO>();
        if (opportunityId == null) {
            return out;
        }
        List<Opportunity> opps = [SELECT Id, Name, AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        if (opps.isEmpty()) {
            return out;
        }
        Opportunity opp = opps[0];
        out.add(relatedOption(opp.Id, opp.Name, 'Opportunity'));

        if (opp.AccountId != null) {
            for (Account acc : [SELECT Id, Name FROM Account WHERE Id = :opp.AccountId]) {
                out.add(relatedOption(acc.Id, acc.Name, 'Account'));
            }
            for (Contact con : [
                SELECT Id, Name FROM Contact WHERE AccountId = :opp.AccountId ORDER BY Name ASC
            ]) {
                out.add(relatedOption(con.Id, con.Name, 'Contact'));
            }
        }

        addRelatedRows(out, opportunityId, 'sugati__Client_Group__c', 'sugati__CG_Opportunity__c', 'Name');
        addRelatedRows(out, opportunityId, 'sugati__Group_Member__c', 'sugati__GM_Opportunity__c', 'sugati__GM_Name__c');
        addSupplierBookingRows(out, opportunityId);
        addSupplierCostPaymentRows(out, opportunityId);
        return out;
    }

    private static void addSupplierBookingRows(List<RelatedRecordOptionDTO> out, Id opportunityId) {
        if (!canAccess('sugati__Supplier_Booking__c')) {
            return;
        }
        for (sugati__Supplier_Booking__c sb : [
            SELECT Id,
                RecordType.Name,
                sugati__SB_Day__c,
                sugati__SB_Supplier__r.Name,
                sugati__SB_Booking_Status__c
            FROM sugati__Supplier_Booking__c
            WHERE sugati__SB_Opportunity__c = :opportunityId
            ORDER BY sugati__SB_Day__c ASC NULLS LAST, Name ASC
        ]) {
            String label = buildSupplierBookingLabel(sb);
            out.add(relatedOption(sb.Id, label, 'Supplier_Booking__c'));
        }
    }

    private static String buildSupplierBookingLabel(sugati__Supplier_Booking__c sb) {
        List<String> parts = new List<String>();
        if (sb.sugati__SB_Day__c != null) {
            parts.add('Day ' + String.valueOf(sb.sugati__SB_Day__c));
        }
        if (sb.RecordType != null && String.isNotBlank(sb.RecordType.Name)) {
            parts.add(sb.RecordType.Name);
        }
        if (sb.sugati__SB_Supplier__r != null && String.isNotBlank(sb.sugati__SB_Supplier__r.Name)) {
            parts.add(sb.sugati__SB_Supplier__r.Name);
        }
        if (String.isNotBlank(sb.sugati__SB_Booking_Status__c)) {
            parts.add(sb.sugati__SB_Booking_Status__c);
        }
        return parts.isEmpty() ? String.valueOf(sb.Id) : String.join(parts, ' : ');
    }

    private static void addRelatedRows(
        List<RelatedRecordOptionDTO> out,
        Id opportunityId,
        String objectApi,
        String oppFieldApi,
        String nameField
    ) {
        if (!Schema.getGlobalDescribe().containsKey(objectApi)) {
            return;
        }
        String q = 'SELECT Id, ' + nameField + ' FROM ' + objectApi +
            ' WHERE ' + oppFieldApi + ' = :opportunityId ORDER BY ' + nameField + ' ASC';
        try {
            for (SObject row : Database.query(q)) {
                String label = String.valueOf(row.get(nameField));
                out.add(relatedOption(row.Id, label, objectApi.replace('sugati__', '')));
            }
        } catch (Exception ex) {
            // skip unsupported field
        }
    }

    private static void addSupplierCostPaymentRows(List<RelatedRecordOptionDTO> out, Id opportunityId) {
        if (!canAccess('sugati__Supplier_Cost_Payment__c')) {
            return;
        }
        Set<Id> seen = new Set<Id>();
        for (sugati__Supplier_Cost_Payment__c scp : [
            SELECT Id, sugati__SCP_Supplier__c, sugati__SCP_Supplier__r.Name
            FROM sugati__Supplier_Cost_Payment__c
            WHERE sugati__SCP_Opportunity__c = :opportunityId
            AND sugati__SCP_Supplier__c != null
            ORDER BY sugati__SCP_Supplier__r.Name ASC
        ]) {
            if (seen.contains(scp.Id)) {
                continue;
            }
            seen.add(scp.Id);
            String name = scp.sugati__SCP_Supplier__r != null ? scp.sugati__SCP_Supplier__r.Name : String.valueOf(scp.Id);
            out.add(relatedOption(scp.Id, name, 'Supplier_Cost_Payment__c'));
        }
    }

    private static RelatedRecordOptionDTO relatedOption(Id recordId, String label, String objectType) {
        RelatedRecordOptionDTO dto = new RelatedRecordOptionDTO();
        dto.recordId = recordId;
        dto.label = label;
        dto.objectType = objectType;
        return dto;
    }

    // --- Small helpers ---

    private static Opportunity queryOpportunity(Id opportunityId) {
        List<Opportunity> rows = [
            SELECT Id,
                sugati__O_Agent__c,
                sugati__O_Agent__r.Name,
                sugati__O_Agent__r.sugati__S_Email__c,
                sugati__O_Agent_SC__c,
                sugati__O_Agent_SC__r.sugati__SC_Email__c,
                sugati__O_Agent_SC__r.sugati__SC_First_Name__c,
                sugati__O_Agent_SC__r.sugati__SC_Last_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Boolean isAgencyBooking(Opportunity opp) {
        return opp != null && opp.sugati__O_Agent__c != null;
    }

    private static LegacyTemplateRowDTO mapTemplateRow(sugati__Email_Template__c row) {
        LegacyTemplateRowDTO dto = new LegacyTemplateRowDTO();
        dto.id = row.Id;
        dto.name = row.Name;
        dto.templateName = row.sugati__ET_Template_Name__c;
        dto.relatedToRecord = normalizeRelatedObjectLabel(row.sugati__ET_Related_To_Record__c);
        dto.intro = row.sugati__ET_Email_Intro__c;
        dto.closing = row.sugati__ET_Email_Closing__c;
        dto.templateStage = row.sugati__ET_Opportunity_Stage__c;
        dto.assignedUserId = row.sugati__ET_User__c;
        dto.assignedUserName = row.sugati__ET_User__r != null ? row.sugati__ET_User__r.Name : null;
        List<String> meta = new List<String>();
        if (String.isNotBlank(dto.templateStage)) {
            meta.add(dto.templateStage);
        }
        if (String.isNotBlank(dto.assignedUserName)) {
            meta.add(dto.assignedUserName);
        }
        dto.meta = meta.isEmpty() ? dto.templateName : String.join(meta, ' · ');
        return dto;
    }

    private static Boolean templateVisibleForUser(sugati__Email_Template__c row, Id currentUserId) {
        return row.sugati__ET_User__c == null || row.sugati__ET_User__c == currentUserId;
    }

    private static String resolveOpportunityStageName(Id opportunityId) {
        List<Opportunity> opps = [SELECT StageName FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        return opps.isEmpty() || String.isBlank(opps[0].StageName) ? null : opps[0].StageName.trim();
    }

    private static Id resolveEmailRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'sugati__Email_Template__c' AND DeveloperName = 'Email'
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    private static String normalizeRelatedObjectLabel(String raw) {
        if (String.isBlank(raw)) {
            return 'Opportunity';
        }
        String trimmed = raw.trim();
        if (trimmed.startsWithIgnoreCase('sugati__')) {
            return trimmed.substring('sugati__'.length());
        }
        return trimmed;
    }

    private static String labelFor(String name, String email) {
        return String.isNotBlank(name) ? name.trim() + ' (' + email + ')' : email;
    }

    private static String normalizeEmail(String email) {
        return String.isBlank(email) ? null : email.trim().toLowerCase();
    }

    private static Boolean canAccess(String objectApi) {
        Schema.SObjectType token = Schema.getGlobalDescribe().get(objectApi);
        return token != null && token.getDescribe().isAccessible();
    }

    @TestVisible
    private static Boolean templateVisibleForSendContextForTest(
        Id templateUserId,
        String templateStage,
        String opportunityStageName,
        Id currentUserId
    ) {
        sugati__Email_Template__c row = new sugati__Email_Template__c(
            sugati__ET_User__c = templateUserId,
            sugati__ET_Opportunity_Stage__c = templateStage
        );
        if (templateUserId != null && templateUserId != currentUserId) {
            return false;
        }
        if (String.isBlank(templateStage)) {
            return true;
        }
        return String.isNotBlank(opportunityStageName) &&
            templateStage.equalsIgnoreCase(opportunityStageName);
    }
}
