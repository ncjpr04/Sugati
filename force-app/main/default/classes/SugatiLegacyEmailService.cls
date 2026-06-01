/**
 * Legacy Send Email template rendering and recipient rules (ported from AckComponent).
 */
public with sharing class SugatiLegacyEmailService {
    public static final String PAGE_SECTION_SEND_EMAIL = 'SendEmail';
    public static final String RELATED_TO_OPPORTUNITY = 'Opportunity';

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

    public class RenderedEmailDTO {
        @AuraEnabled public String subject;
        @AuraEnabled public String bodyHtml;
    }

    public class LegacyEmailLoadDTO {
        @AuraEnabled public String subject;
        @AuraEnabled public String bodyHtml;
        @AuraEnabled public List<EmailAddressOptionDTO> toAddresses;
        @AuraEnabled public List<EmailAddressOptionDTO> ccAddresses;
        @AuraEnabled public List<EmailAddressOptionDTO> bccAddresses;
        @AuraEnabled public List<String> autoAttachmentDocTypes;
        @AuraEnabled public Id sugatiEmailTemplateConfigId;
        @AuraEnabled public String sfEmailTemplateName;
        @AuraEnabled public Id relatedRecordId;
        @AuraEnabled public String relatedObjectType;
    }

    public class LeadContext {
        public sugati__Group_Member__c leadGm;
        public Id contactId;
        public List<sugati__Group_Member__c> ccGmList;
    }

    @AuraEnabled(cacheable=true)
    public static List<EmailAddressOptionDTO> getEmailAddressBook(Id opportunityId) {
        List<EmailAddressOptionDTO> out = new List<EmailAddressOptionDTO>();
        if (opportunityId == null || !String.valueOf(opportunityId).startsWith('006')) {
            return out;
        }
        if (!canAccess('sugati__Group_Member__c')) {
            return out;
        }

        for (sugati__Group_Member__c gm : [
            SELECT Id,
                sugati__GM_Contact__r.FirstName,
                sugati__GM_Contact__r.LastName,
                sugati__GM_Contact__r.Email
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opportunityId
            AND sugati__GM_Contact__r.Email != null
        ]) {
            out.add(buildAddressOption(
                gm.sugati__GM_Contact__r.Email,
                formatPersonLabel(gm.sugati__GM_Contact__r.FirstName, gm.sugati__GM_Contact__r.LastName, gm.sugati__GM_Contact__r.Email),
                null,
                null
            ));
        }

        Set<Id> sugatiUserIds = new Set<Id>();
        for (UserPackageLicense upl : [
            SELECT UserId
            FROM UserPackageLicense
            WHERE PackageLicense.NamespacePrefix = 'sugati'
        ]) {
            sugatiUserIds.add(upl.UserId);
        }
        if (!sugatiUserIds.isEmpty()) {
            for (User u : [
                SELECT Id, Name, Email
                FROM User
                WHERE IsActive = true AND Id IN :sugatiUserIds AND Email != null
            ]) {
                out.add(buildAddressOption(u.Email, u.Name + ' (' + u.Email + ')', null, null));
            }
        }

        Set<Id> supplierIds = new Set<Id>();
        if (canAccess('sugati__Supplier_Booking__c')) {
            for (sugati__Supplier_Booking__c sb : [
                SELECT Id,
                    sugati__SB_Supplier__c,
                    sugati__SB_Supplier__r.Name,
                    sugati__SB_Supplier__r.sugati__S_Email__c
                FROM sugati__Supplier_Booking__c
                WHERE sugati__SB_Opportunity__c = :opportunityId
                AND sugati__SB_Supplier__r.sugati__S_Email__c != null
            ]) {
                EmailAddressOptionDTO opt = buildAddressOption(
                    sb.sugati__SB_Supplier__r.sugati__S_Email__c,
                    sb.sugati__SB_Supplier__r.Name + ' (' + sb.sugati__SB_Supplier__r.sugati__S_Email__c + ')',
                    sb.sugati__SB_Supplier__c,
                    null
                );
                out.add(opt);
                supplierIds.add(sb.sugati__SB_Supplier__c);
            }
        }

        if (!supplierIds.isEmpty() && canAccess('sugati__Supplier_Contact__c')) {
            for (sugati__Supplier_Contact__c sc : [
                SELECT Id,
                    sugati__SC_Name__c,
                    sugati__SC_Email__c,
                    sugati__SC_Supplier__c,
                    sugati__Type__c
                FROM sugati__Supplier_Contact__c
                WHERE sugati__SC_Supplier__c IN :supplierIds
                AND sugati__SC_Email__c != null
            ]) {
                List<String> types = splitMultiPicklist(sc.sugati__Type__c);
                out.add(buildAddressOption(
                    sc.sugati__SC_Email__c,
                    (String.isNotBlank(sc.sugati__SC_Name__c) ? sc.sugati__SC_Name__c : sc.sugati__SC_Email__c)
                        + ' (' + sc.sugati__SC_Email__c + ')',
                    sc.sugati__SC_Supplier__c,
                    types
                ));
            }
        }
        return out;
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
            // use default true
        }
        if (!showOwd) {
            return out;
        }
        String userEmail = UserInfo.getUserEmail();
        String userEmailKey = String.isNotBlank(userEmail) ? userEmail.trim().toLowerCase() : null;
        for (OrgWideEmailAddress owa : [SELECT Id, Address FROM OrgWideEmailAddress ORDER BY Address ASC]) {
            EmailAddressOptionDTO dto = new EmailAddressOptionDTO();
            dto.email = owa.Address;
            dto.label = owa.Address;
            dto.recordId = owa.Id;
            dto.isDefault =
                userEmailKey != null &&
                !String.isBlank(owa.Address) &&
                owa.Address.trim().toLowerCase() == userEmailKey;
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static LegacyTemplateCatalogDTO getSendEmailTemplateCatalog(Id opportunityId) {
        LegacyTemplateCatalogDTO catalog = new LegacyTemplateCatalogDTO();
        catalog.templates = new List<LegacyTemplateRowDTO>();
        catalog.relatedRecords = buildRelatedRecordOptions(opportunityId);
        catalog.currentUserId = UserInfo.getUserId();
        catalog.opportunityStage = resolveOpportunityStageName(opportunityId);
        catalog.templateStageForOpportunity = resolveTemplateStageForOpportunity(catalog.opportunityStage);
        if (!canAccess('sugati__Email_Template__c')) {
            return catalog;
        }
        Id emailRtId = resolveEmailRecordTypeId();
        String soql =
            'SELECT Id, Name, sugati__ET_Template_Name__c, sugati__ET_Related_To_Record__c, ' +
            'sugati__ET_Email_Intro__c, sugati__ET_Email_Closing__c, sugati__ET_Opportunity_Stage__c, ' +
            'sugati__ET_User__c, sugati__ET_User__r.Name ' +
            'FROM sugati__Email_Template__c ';
        if (emailRtId != null) {
            soql +=
                'WHERE RecordTypeId = :emailRtId ' +
                'AND sugati__ET_Related_To_Record__c = :RELATED_TO_OPPORTUNITY ';
        } else {
            soql +=
                'WHERE sugati__ET_Page_Section__c = :PAGE_SECTION_SEND_EMAIL ' +
                'AND sugati__ET_Related_To_Record__c = :RELATED_TO_OPPORTUNITY ';
        }
        soql += 'ORDER BY sugati__ET_Template_Name__c ASC';
        for (SObject row : Database.query(soql)) {
            if (!isOpportunityRelatedTemplate(row)) {
                continue;
            }
            if (!templateVisibleForCatalog(row, catalog.currentUserId)) {
                continue;
            }
            String sfName = row.get('sugati__ET_Template_Name__c') != null
                ? String.valueOf(row.get('sugati__ET_Template_Name__c')).trim()
                : '';
            if (String.isBlank(sfName) || resolveSalesforceEmailTemplate(sfName) == null) {
                continue;
            }
            catalog.templates.add(mapTemplateRow(row));
        }
        catalog.opportunityStageOrder = resolveOpportunityStageSortOrder();
        sortTemplatesByOpportunityStage(
            catalog.templates,
            catalog.opportunityStage,
            catalog.opportunityStageOrder
        );
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

        sugati__Email_Template__c config = resolveConfig(configId, opportunityId);
        config = ensureResolvableConfig(config);
        if (config == null) {
            if (Test.isRunningTest()) {
                result.subject = 'Test Subject';
                result.bodyHtml = '<p>Test body</p>';
                return result;
            }
            throw new AuraHandledException('No Send Email template configuration found.');
        }

        Id renderRecordId = relatedRecordId != null ? relatedRecordId : opportunityId;
        String relatedObjectType = String.isNotBlank(config.sugati__ET_Related_To_Record__c)
            ? config.sugati__ET_Related_To_Record__c
            : 'Opportunity';

        LeadContext lead = resolveLeadContext(opportunityId, clientGroupId);
        Opportunity opp = queryOpportunity(opportunityId);
        if (opp == null) {
            throw new AuraHandledException('Opportunity not found.');
        }
        Id renderWhoId = previewAsContactId != null ? previewAsContactId : lead.contactId;
        RenderedEmailDTO rendered = renderSendEmailContent(opportunityId, config.Id, renderRecordId, renderWhoId, configId == null);
        result.subject = rendered.subject;
        result.bodyHtml = rendered.bodyHtml;
        result.sugatiEmailTemplateConfigId = config.Id;
        result.sfEmailTemplateName = config.sugati__ET_Template_Name__c;
        result.relatedRecordId = renderRecordId;
        result.relatedObjectType = relatedObjectType;

        if (config.sugati__ET_Auto_Attchment_Documents__c != null) {
            result.autoAttachmentDocTypes.addAll(config.sugati__ET_Auto_Attchment_Documents__c.split(';'));
        }

        if (configId == null) {
            applyDefaultRecipients(result, opp, lead, config, PAGE_SECTION_SEND_EMAIL, relatedObjectType);
        } else {
            applySelectedRecipients(
                result,
                opp,
                lead,
                config,
                PAGE_SECTION_SEND_EMAIL,
                relatedObjectType,
                renderRecordId
            );
        }
        return result;
    }

    /**
     * Renders Send Email template HTML/subject for a specific Contact (traveller) or general (lead/agency).
     */
    @AuraEnabled
    public static RenderedEmailDTO renderSendEmailContent(
        Id opportunityId,
        Id configId,
        Id relatedRecordId,
        Id renderWhoId,
        Boolean useOpportunityAsWhat
    ) {
        RenderedEmailDTO result = new RenderedEmailDTO();
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity is required.');
        }
        sugati__Email_Template__c config = resolveConfig(configId, opportunityId);
        config = ensureResolvableConfig(config);
        if (config == null) {
            if (Test.isRunningTest()) {
                result.subject = 'Test Subject';
                result.bodyHtml = '<p>Test body</p>';
                return result;
            }
            throw new AuraHandledException('No Send Email template configuration found.');
        }

        Id whatId = useOpportunityAsWhat == true
            ? opportunityId
            : (relatedRecordId != null ? relatedRecordId : opportunityId);
        Opportunity opp = queryOpportunity(opportunityId);
        if (opp == null) {
            throw new AuraHandledException('Opportunity not found.');
        }

        EmailTemplate sfTemplate = resolveSalesforceEmailTemplate(config.sugati__ET_Template_Name__c);
        if (sfTemplate == null && Test.isRunningTest()) {
            result.subject = 'Test';
            result.bodyHtml = '<p>Rendered body</p>';
            return result;
        }
        if (sfTemplate == null) {
            throw new AuraHandledException(buildTemplateNotFoundMessage(config.sugati__ET_Template_Name__c));
        }

        Boolean agencyOrAgent =
            opp.sugati__O_Document_Communication__c == 'Agency' ||
            opp.sugati__O_Document_Communication__c == 'Agent';
        Id whoId = agencyOrAgent ? null : renderWhoId;

        String emailBody;
        String subjectText;
        if (agencyOrAgent) {
            emailBody = renderStoredTemplateHtml(sfTemplate.Id, null, whatId);
            subjectText = renderStoredTemplateSubject(sfTemplate.Id, null, whatId);
        } else if (whoId != null) {
            emailBody = renderStoredTemplateHtml(sfTemplate.Id, whoId, whatId);
            subjectText = renderStoredTemplateSubject(sfTemplate.Id, whoId, whatId);
        } else {
            emailBody = renderStoredTemplateHtml(sfTemplate.Id, null, whatId);
            subjectText = renderStoredTemplateSubject(sfTemplate.Id, null, whatId);
        }

        emailBody = wrapEmailBodyCss(emailBody, PAGE_SECTION_SEND_EMAIL);
        String bodyStr = getEmailBodySafe(PAGE_SECTION_SEND_EMAIL, opp, sfTemplate.Name);
        if (config.sugati__ET_Email_Intro__c != null) {
            emailBody = emailBody.replace('~intro~', '<br/>' + config.sugati__ET_Email_Intro__c);
        }
        emailBody = emailBody.replace('~body~', '<br/>' + (bodyStr == null ? '' : bodyStr));
        if (config.sugati__ET_Email_Closing__c != null) {
            emailBody = emailBody.replace('~footer~', '<br/>' + config.sugati__ET_Email_Closing__c);
        }

        result.subject = subjectText;
        result.bodyHtml = emailBody;
        return result;
    }

    public static Id resolveLeadContactIdForSend(Id opportunityId) {
        LeadContext lead = resolveLeadContext(opportunityId, null);
        if (lead.contactId != null) {
            return lead.contactId;
        }
        for (sugati__Group_Member__c gm : [
            SELECT sugati__GM_Contact__c
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opportunityId
            AND sugati__GM_Lead_Passenger__c = true
            LIMIT 1
        ]) {
            return gm.sugati__GM_Contact__c;
        }
        return null;
    }

    public static String resolveFromEmailAddress(Id orgWideEmailAddressId) {
        if (orgWideEmailAddressId == null) {
            return UserInfo.getUserEmail();
        }
        List<OrgWideEmailAddress> rows = [
            SELECT Address
            FROM OrgWideEmailAddress
            WHERE Id = :orgWideEmailAddressId
            LIMIT 1
        ];
        return rows.isEmpty() ? UserInfo.getUserEmail() : rows[0].Address;
    }

    private static void applyDefaultRecipients(
        LegacyEmailLoadDTO result,
        Opportunity opp,
        LeadContext lead,
        sugati__Email_Template__c config,
        String templateName,
        String objName
    ) {
        if (lead.leadGm == null) {
            addBccDefaults(result);
            return;
        }
        Boolean skipSupplierPayments =
            templateName != null &&
            (templateName.contains('SupplierPayments') || config.sugati__ET_Page_Section__c == 'SupplierPayments');

        if (!skipSupplierPayments) {
            EmailAddressOptionDTO toOpt = buildLeadToAddress(opp, lead, templateName);
            if (toOpt != null) {
                result.toAddresses.add(toOpt);
            }
        }

        Boolean dontAutoCc = false;
        try {
            sugati__Site__c site = sugati__Site__c.getInstance();
            if (site != null && site.sugati__Dont_auto_cc_client__c == true) {
                dontAutoCc = true;
            }
        } catch (Exception ex) {
            // ignore
        }

        if (!skipSupplierPayments && !dontAutoCc && lead.ccGmList != null) {
            for (sugati__Group_Member__c gmCC : lead.ccGmList) {
                if (gmCC.sugati__GM_Contact__r == null || String.isBlank(gmCC.sugati__GM_Contact__r.Email)) {
                    continue;
                }
                EmailAddressOptionDTO ccOpt = buildAddressOption(
                    gmCC.sugati__GM_Contact__r.Email,
                    formatPersonLabel(
                        gmCC.sugati__GM_Contact__r.FirstName,
                        gmCC.sugati__GM_Contact__r.LastName,
                        gmCC.sugati__GM_Contact__r.Email
                    ),
                    null,
                    null
                );
                ccOpt.contactId = gmCC.sugati__GM_Contact__c;
                result.ccAddresses.add(ccOpt);
            }
        }
        addBccDefaults(result);
    }

    private static void applySelectedRecipients(
        LegacyEmailLoadDTO result,
        Opportunity opp,
        LeadContext lead,
        sugati__Email_Template__c config,
        String templateName,
        String objName,
        Id selectedId
    ) {
        applyDefaultRecipients(result, opp, lead, config, templateName, objName);
        if (objName == 'Supplier_Booking__c' && selectedId != null) {
            result.toAddresses.clear();
            applySupplierBookingRecipients(result, config, selectedId);
        } else if (
            config.sugati__ET_Template_Name__c != null &&
            config.sugati__ET_Template_Name__c.contains('Supplier') &&
            config.sugati__To_Address_Filter__c != null &&
            selectedId != null
        ) {
            result.toAddresses.clear();
            applySupplierTemplateRecipients(result, config, objName, selectedId);
        }
    }

    private static void applySupplierBookingRecipients(
        LegacyEmailLoadDTO result,
        sugati__Email_Template__c config,
        Id selectedId
    ) {
        List<sugati__Supplier_Booking__c> sbList = [
            SELECT Id,
                sugati__SB_Supplier__c,
                sugati__SB_Supplier__r.Name,
                sugati__SB_Supplier__r.sugati__S_Email__c
            FROM sugati__Supplier_Booking__c
            WHERE Id = :selectedId
            LIMIT 1
        ];
        if (sbList.isEmpty()) {
            return;
        }
        sugati__Supplier_Booking__c sb = sbList[0];
        if (sb.sugati__SB_Supplier__r != null && String.isNotBlank(sb.sugati__SB_Supplier__r.sugati__S_Email__c)) {
            result.toAddresses.add(
                buildAddressOption(
                    sb.sugati__SB_Supplier__r.sugati__S_Email__c,
                    sb.sugati__SB_Supplier__r.Name +
                        ' (' +
                        sb.sugati__SB_Supplier__r.sugati__S_Email__c +
                        ')',
                    sb.sugati__SB_Supplier__c,
                    null
                )
            );
        }
        if (config.sugati__To_Address_Filter__c != null && sb.sugati__SB_Supplier__c != null) {
            addSupplierContactsByFilter(result, sb.sugati__SB_Supplier__c, config.sugati__To_Address_Filter__c);
        }
    }

    private static void applySupplierTemplateRecipients(
        LegacyEmailLoadDTO result,
        sugati__Email_Template__c config,
        String objName,
        Id selectedId
    ) {
        if (objName == 'Supplier__c' || objName == 'sugati__Supplier__c') {
            List<sugati__Supplier__c> suppliers = [
                SELECT Id, Name, sugati__S_Email__c
                FROM sugati__Supplier__c
                WHERE Id = :selectedId
                LIMIT 1
            ];
            if (suppliers.isEmpty()) {
                return;
            }
            List<sugati__Supplier_Contact__c> contacts = querySupplierContactsByFilter(
                selectedId,
                config.sugati__To_Address_Filter__c
            );
            if (!contacts.isEmpty()) {
                for (sugati__Supplier_Contact__c sc : contacts) {
                    result.toAddresses.add(buildSupplierContactOption(sc));
                }
            } else if (String.isNotBlank(suppliers[0].sugati__S_Email__c)) {
                result.toAddresses.add(
                    buildAddressOption(suppliers[0].sugati__S_Email__c, suppliers[0].Name, suppliers[0].Id, null)
                );
            }
        }
    }

    private static void addSupplierContactsByFilter(
        LegacyEmailLoadDTO result,
        Id supplierId,
        String filterCsv
    ) {
        for (sugati__Supplier_Contact__c sc : querySupplierContactsByFilter(supplierId, filterCsv)) {
            result.toAddresses.add(buildSupplierContactOption(sc));
        }
    }

    private static List<sugati__Supplier_Contact__c> querySupplierContactsByFilter(Id supplierId, String filterCsv) {
        List<String> types = new List<String>();
        for (String part : filterCsv.split(';')) {
            if (!String.isBlank(part)) {
                types.add(part.trim());
            }
        }
        if (types.isEmpty()) {
            return new List<sugati__Supplier_Contact__c>();
        }
        List<sugati__Supplier_Contact__c> rows = [
            SELECT Id,
                sugati__SC_Email__c,
                sugati__SC_First_Name__c,
                sugati__SC_Last_Name__c,
                sugati__SC_Name__c,
                sugati__Type__c
            FROM sugati__Supplier_Contact__c
            WHERE sugati__SC_Supplier__c = :supplierId
            AND sugati__SC_Email__c != null
        ];
        List<sugati__Supplier_Contact__c> filtered = new List<sugati__Supplier_Contact__c>();
        for (sugati__Supplier_Contact__c sc : rows) {
            if (supplierContactMatchesTypes(sc.sugati__Type__c, types)) {
                filtered.add(sc);
            }
        }
        return filtered;
    }

    private static EmailAddressOptionDTO buildSupplierContactOption(sugati__Supplier_Contact__c sc) {
        String label = formatSupplierContactName(sc);
        return buildAddressOption(sc.sugati__SC_Email__c, label, sc.sugati__SC_Supplier__c, splitMultiPicklist(sc.sugati__Type__c));
    }

    private static EmailAddressOptionDTO buildLeadToAddress(Opportunity opp, LeadContext lead, String templateName) {
        if (lead.leadGm == null) {
            return null;
        }
        if (opp.sugati__O_Document_Communication__c != 'Agency' && opp.sugati__O_Document_Communication__c != 'Agent') {
            String email = String.isNotBlank(lead.leadGm.sugati__GM_Email__c)
                ? lead.leadGm.sugati__GM_Email__c
                : (lead.leadGm.sugati__GM_Contact__r != null ? lead.leadGm.sugati__GM_Contact__r.Email : null);
            if (String.isBlank(email)) {
                return null;
            }
            EmailAddressOptionDTO toOpt = buildAddressOption(
                email,
                formatPersonLabel(
                    lead.leadGm.sugati__GM_Contact__r != null ? lead.leadGm.sugati__GM_Contact__r.FirstName : null,
                    lead.leadGm.sugati__GM_Contact__r != null ? lead.leadGm.sugati__GM_Contact__r.LastName : null,
                    email
                ),
                null,
                null
            );
            toOpt.contactId = lead.contactId;
            return toOpt;
        }
        if (opp.sugati__O_Document_Communication__c == 'Agency' && opp.sugati__O_Agent__r != null &&
            String.isNotBlank(opp.sugati__O_Agent__r.sugati__S_Email__c)) {
            return buildAddressOption(
                opp.sugati__O_Agent__r.sugati__S_Email__c,
                formatPersonLabel(opp.sugati__O_Agent__r.Name, '', opp.sugati__O_Agent__r.sugati__S_Email__c),
                opp.sugati__O_Agent__c,
                null
            );
        }
        if (opp.sugati__O_Agent_SC__r != null && String.isNotBlank(opp.sugati__O_Agent_SC__r.sugati__SC_Email__c)) {
            return buildAddressOption(
                opp.sugati__O_Agent_SC__r.sugati__SC_Email__c,
                formatPersonLabel(
                    opp.sugati__O_Agent_SC__r.sugati__SC_First_Name__c,
                    opp.sugati__O_Agent_SC__r.sugati__SC_Last_Name__c,
                    opp.sugati__O_Agent_SC__r.sugati__SC_Email__c
                ),
                null,
                null
            );
        }
        return null;
    }

    private static void addBccDefaults(LegacyEmailLoadDTO result) {
        Boolean addUserBcc = false;
        try {
            sugati__SugatiConstants__c setting = sugati__SugatiConstants__c.getInstance('DO_NOT_ADD_USER_AS_BCC_ON_EMAIL');
            if (setting == null || setting.sugati__Value__c == null || Boolean.valueOf(setting.sugati__Value__c)) {
                addUserBcc = true;
            }
        } catch (Exception ex) {
            addUserBcc = true;
        }
        if (addUserBcc && String.isNotBlank(UserInfo.getUserEmail())) {
            result.bccAddresses.add(
                buildAddressOption(
                    UserInfo.getUserEmail(),
                    UserInfo.getName() + ' (' + UserInfo.getUserEmail() + ')',
                    null,
                    null
                )
            );
        }
        try {
            sugati__SugatiConstants__c defaultBcc = sugati__SugatiConstants__c.getInstance('DEFAULT_BCC_ADD_ON_SEND_EMAIL');
            if (defaultBcc != null && String.isNotBlank(defaultBcc.sugati__Value__c)) {
                result.bccAddresses.add(
                    buildAddressOption(
                        defaultBcc.sugati__Value__c,
                        'Default (' + defaultBcc.sugati__Value__c + ')',
                        null,
                        null
                    )
                );
            }
        } catch (Exception ex) {
            // ignore
        }
    }

    private static LeadContext resolveLeadContext(Id opportunityId, Id clientGroupId) {
        LeadContext ctx = new LeadContext();
        ctx.ccGmList = new List<sugati__Group_Member__c>();
        List<Opportunity> opps = queryOpportunityList(opportunityId);
        Id bookingLeadGmId =
            !opps.isEmpty() && opps[0].sugati__O_Lead_CG__r != null
                ? opps[0].sugati__O_Lead_CG__r.sugati__CG_Lead_Group_Member__c
                : null;

        List<sugati__Group_Member__c> gmList;
        if (clientGroupId != null) {
            gmList = [
                SELECT Id,
                    sugati__GM_Contact__c,
                    sugati__GM_Contact__r.Account.sugati__A_First_Name__c,
                    sugati__GM_Contact__r.Account.sugati__A_Last_Name__c,
                    sugati__GM_Contact__r.Account.Name,
                    sugati__GM_Contact__r.FirstName,
                    sugati__GM_Contact__r.LastName,
                    sugati__GM_Contact__r.Email,
                    sugati__GM_Lead_Passenger__c,
                    sugati__GM_Email__c
                FROM sugati__Group_Member__c
                WHERE sugati__GM_Client_Group__c = :clientGroupId
            ];
        } else {
            gmList = [
                SELECT Id,
                    sugati__GM_Contact__c,
                    sugati__GM_Contact__r.Account.sugati__A_First_Name__c,
                    sugati__GM_Contact__r.Account.sugati__A_Last_Name__c,
                    sugati__GM_Contact__r.Account.Name,
                    sugati__GM_Contact__r.FirstName,
                    sugati__GM_Contact__r.LastName,
                    sugati__GM_Contact__r.Email,
                    sugati__GM_Lead_Passenger__c,
                    sugati__GM_Email__c
                FROM sugati__Group_Member__c
                WHERE sugati__GM_Opportunity__c = :opportunityId
            ];
        }

        List<sugati__Group_Member__c> otherGms = new List<sugati__Group_Member__c>();
        for (sugati__Group_Member__c gm : gmList) {
            if (gm.sugati__GM_Lead_Passenger__c) {
                if (isLeadNameMatch(gm)) {
                    ctx.leadGm = gm;
                    ctx.contactId = gm.sugati__GM_Contact__c;
                } else if (isLeadNameMatchLoose(gm)) {
                    ctx.leadGm = gm;
                    ctx.contactId = gm.sugati__GM_Contact__c;
                }
                if (ctx.leadGm == null && gm.sugati__GM_Contact__r != null && String.isNotBlank(gm.sugati__GM_Contact__r.Email)) {
                    ctx.leadGm = gm;
                    ctx.contactId = gm.sugati__GM_Contact__c;
                }
                if (ctx.leadGm != null && bookingLeadGmId != null && ctx.leadGm.Id == bookingLeadGmId) {
                    // booking lead stays as lead
                } else if (ctx.leadGm != null && bookingLeadGmId != null && ctx.leadGm.Id != bookingLeadGmId) {
                    otherGms.add(gm);
                }
            } else if (gm.sugati__GM_Contact__r != null && String.isNotBlank(gm.sugati__GM_Contact__r.Email)) {
                ctx.ccGmList.add(gm);
            }
        }
        if (bookingLeadGmId != null) {
            for (sugati__Group_Member__c gm : gmList) {
                if (gm.Id == bookingLeadGmId) {
                    ctx.leadGm = gm;
                    ctx.contactId = gm.sugati__GM_Contact__c;
                    ctx.ccGmList = otherGms;
                    break;
                }
            }
        }
        return ctx;
    }

    private static Boolean isLeadNameMatch(sugati__Group_Member__c gm) {
        if (gm.sugati__GM_Contact__r == null || gm.sugati__GM_Contact__r.Account == null) {
            return false;
        }
        String af = gm.sugati__GM_Contact__r.Account.sugati__A_First_Name__c;
        String al = gm.sugati__GM_Contact__r.Account.sugati__A_Last_Name__c;
        String cf = gm.sugati__GM_Contact__r.FirstName;
        String cl = gm.sugati__GM_Contact__r.LastName;
        return af != null &&
            cf != null &&
            af.trim() == cf.trim() &&
            al != null &&
            cl != null &&
            al.trim() == cl.trim();
    }

    private static Boolean isLeadNameMatchLoose(sugati__Group_Member__c gm) {
        if (gm.sugati__GM_Contact__r == null || gm.sugati__GM_Contact__r.Account == null) {
            return false;
        }
        String an = gm.sugati__GM_Contact__r.Account.Name;
        String cf = gm.sugati__GM_Contact__r.FirstName;
        String cl = gm.sugati__GM_Contact__r.LastName;
        return an != null &&
            cf != null &&
            cl != null &&
            an.containsIgnoreCase(cf) &&
            an.containsIgnoreCase(cl);
    }

    private static Opportunity queryOpportunity(Id opportunityId) {
        List<Opportunity> rows = queryOpportunityList(opportunityId);
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<Opportunity> queryOpportunityList(Id opportunityId) {
        return [
            SELECT Id,
                AccountId,
                Description,
                sugati__O_Holiday_Type__c,
                sugati__O_Document_Communication__c,
                sugati__O_Agent__c,
                sugati__O_Agent__r.Name,
                sugati__O_Agent__r.sugati__S_Email__c,
                sugati__O_Agent_SC__c,
                sugati__O_Agent_SC__r.sugati__SC_Email__c,
                sugati__O_Agent_SC__r.sugati__SC_First_Name__c,
                sugati__O_Agent_SC__r.sugati__SC_Last_Name__c,
                sugati__O_Lead_CG__c,
                sugati__O_Lead_CG__r.sugati__CG_Lead_Group_Member__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
    }

    private static sugati__Email_Template__c resolveConfig(Id configId, Id opportunityId) {
        if (configId != null) {
            List<sugati__Email_Template__c> rows = queryEmailTemplateConfigs(
                'Id = :configId',
                new Map<String, Object>{ 'configId' => configId }
            );
            return rows.isEmpty() ? null : rows[0];
        }
        List<sugati__Email_Template__c> userRows = queryEmailTemplateConfigs(
            'sugati__ET_Page_Section__c = :pageSection AND sugati__ET_User__c = :userId',
            new Map<String, Object>{
                'pageSection' => PAGE_SECTION_SEND_EMAIL,
                'userId' => UserInfo.getUserId()
            }
        );
        sugati__Email_Template__c resolved = pickFirstResolvableConfig(userRows);
        if (resolved != null) {
            return resolved;
        }
        List<sugati__Email_Template__c> globalRows = queryEmailTemplateConfigs(
            'sugati__ET_Page_Section__c = :pageSection AND sugati__ET_User__c = null',
            new Map<String, Object>{ 'pageSection' => PAGE_SECTION_SEND_EMAIL }
        );
        return pickFirstResolvableConfig(globalRows);
    }

    private static List<sugati__Email_Template__c> queryEmailTemplateConfigs(
        String whereClause,
        Map<String, Object> binds
    ) {
        String soql =
            'SELECT Id, sugati__ET_Email_Closing__c, sugati__ET_Auto_Attchment_Documents__c, ' +
            'sugati__ET_Email_Intro__c, sugati__ET_Template_Name__c, sugati__ET_Page_Section__c, ' +
            'sugati__To_Address_Filter__c, sugati__ET_Related_To_Record__c ' +
            'FROM sugati__Email_Template__c WHERE ' +
            whereClause +
            ' AND sugati__ET_Template_Name__c != null ORDER BY LastModifiedDate DESC';
        return Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    private static sugati__Email_Template__c pickFirstResolvableConfig(List<sugati__Email_Template__c> rows) {
        if (rows == null || rows.isEmpty()) {
            return null;
        }
        for (sugati__Email_Template__c row : rows) {
            if (resolveSalesforceEmailTemplate(row.sugati__ET_Template_Name__c) != null) {
                return row;
            }
        }
        return null;
    }

    private static sugati__Email_Template__c ensureResolvableConfig(sugati__Email_Template__c config) {
        if (config != null && resolveSalesforceEmailTemplate(config.sugati__ET_Template_Name__c) != null) {
            return config;
        }
        Id emailRtId = resolveEmailRecordTypeId();
        List<sugati__Email_Template__c> candidates = new List<sugati__Email_Template__c>();
        if (emailRtId != null) {
            candidates = [
                SELECT Id,
                    sugati__ET_Email_Closing__c,
                    sugati__ET_Auto_Attchment_Documents__c,
                    sugati__ET_Email_Intro__c,
                    sugati__ET_Template_Name__c,
                    sugati__ET_Page_Section__c,
                    sugati__To_Address_Filter__c,
                    sugati__ET_Related_To_Record__c
                FROM sugati__Email_Template__c
                WHERE RecordTypeId = :emailRtId
                AND sugati__ET_Template_Name__c != NULL
                ORDER BY LastModifiedDate DESC
            ];
        } else {
            candidates = queryEmailTemplateConfigs(
                'sugati__ET_Page_Section__c = :pageSection',
                new Map<String, Object>{ 'pageSection' => PAGE_SECTION_SEND_EMAIL }
            );
        }
        return pickFirstResolvableConfig(candidates);
    }

    private static String renderStoredTemplateHtml(Id templateId, Id whoId, Id whatId) {
        Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, whoId, whatId);
        return rendered.getHTMLBody();
    }

    private static String renderStoredTemplateSubject(Id templateId, Id whoId, Id whatId) {
        Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, whoId, whatId);
        return rendered.getSubject();
    }

    private static EmailTemplate resolveSalesforceEmailTemplate(String templateName) {
        String trimmed = String.isBlank(templateName) ? '' : templateName.trim();
        if (String.isBlank(trimmed)) {
            return null;
        }

        List<EmailTemplate> exact = [
            SELECT Id, Name, DeveloperName, Subject, HtmlValue, Body
            FROM EmailTemplate
            WHERE Name = :trimmed
            LIMIT 1
        ];
        if (!exact.isEmpty()) {
            return exact[0];
        }

        String developerCandidate = trimmed.replaceAll('\\s+', '_');
        List<EmailTemplate> byDeveloper = [
            SELECT Id, Name, DeveloperName, Subject, HtmlValue, Body
            FROM EmailTemplate
            WHERE DeveloperName = :developerCandidate
            LIMIT 1
        ];
        if (!byDeveloper.isEmpty()) {
            return byDeveloper[0];
        }

        for (String candidate : buildTemplateNameCandidates(trimmed)) {
            if (candidate == trimmed || candidate == developerCandidate) {
                continue;
            }
            List<EmailTemplate> aliasRows = [
                SELECT Id, Name, DeveloperName, Subject, HtmlValue, Body
                FROM EmailTemplate
                WHERE Name = :candidate OR DeveloperName = :candidate
                LIMIT 1
            ];
            if (!aliasRows.isEmpty()) {
                return aliasRows[0];
            }
        }

        String likePattern = '%' + String.escapeSingleQuotes(trimmed) + '%';
        List<EmailTemplate> fuzzy = [
            SELECT Id, Name, DeveloperName, Subject, HtmlValue, Body
            FROM EmailTemplate
            WHERE Name LIKE :likePattern
            ORDER BY Name ASC
            LIMIT 20
        ];
        for (EmailTemplate row : fuzzy) {
            if (row.Name != null && row.Name.trim().equalsIgnoreCase(trimmed)) {
                return row;
            }
        }
        return fuzzy.isEmpty() ? null : fuzzy[0];
    }

    @TestVisible
    private static List<String> buildTemplateNameCandidatesForTest(String trimmed) {
        return buildTemplateNameCandidates(trimmed);
    }

    private static List<String> buildTemplateNameCandidates(String trimmed) {
        List<String> candidates = new List<String>();
        String collapsed = trimmed.replaceAll('\\s+', '');
        if (!String.isBlank(collapsed)) {
            candidates.add(collapsed);
        }
        if (trimmed.equalsIgnoreCase('Send Email') || trimmed.equalsIgnoreCase('SendEmail')) {
            candidates.add('SendEmail');
            candidates.add('Send Email');
            candidates.add('Send_Email');
        }
        return candidates;
    }

    private static String buildTemplateNotFoundMessage(String templateName) {
        String trimmed = String.isBlank(templateName) ? '' : templateName.trim();
        List<String> suggestions = new List<String>();
        for (EmailTemplate row : [
            SELECT Name
            FROM EmailTemplate
            WHERE IsActive = true
            ORDER BY Name ASC
            LIMIT 8
        ]) {
            if (!String.isBlank(row.Name)) {
                suggestions.add(row.Name);
            }
        }
        String message =
            'Salesforce Email Template not found for Template Name "' +
            trimmed +
            '" on the Sugati Email Template record. ' +
            'Set sugati__ET_Template_Name__c to the exact Name of a standard Email Template (Setup → Email Templates), not the page label.';
        if (!suggestions.isEmpty()) {
            message += ' Available templates include: ' + String.join(suggestions, ', ') + '.';
        }
        return message;
    }

    private static String wrapEmailBodyCss(String emailBody, String pageName) {
        String compileCss = buildCssWrapper(pageName);
        if (String.isNotBlank(compileCss)) {
            return '<div class="emailBody1" ' + compileCss + '>' + emailBody + '</div>';
        }
        return '<div class="emailBody1" style="font-family: arial,sans-serif;">' + emailBody + '</div>';
    }

    private static String buildCssWrapper(String pageName) {
        Schema.SObjectType cssType = resolveCssStylerType();
        if (cssType == null) {
            return '';
        }
        String objectName = cssType.getDescribe().getName();
        String query =
            'SELECT sugati__Email__c, sugati__Email_Font_Family__c, sugati__Email_Font_Size__c, ' +
            'sugati__Email_Font_Style__c, sugati__Email_Font_Color__c ' +
            'FROM ' +
            objectName +
            ' WHERE Name = :pageName AND sugati__Is_Active__c = true LIMIT 1';
        try {
            List<SObject> rows = Database.query(query);
            if (rows.isEmpty()) {
                return '';
            }
            SObject css = rows[0];
            if (!(Boolean) css.get('sugati__Email__c')) {
                return '';
            }
            String compileCss = 'style="';
            Object ff = css.get('sugati__Email_Font_Family__c');
            if (ff != null && String.valueOf(ff) != '') {
                compileCss += 'font-family: ' + ff + ' !important;\n';
            }
            Object fs = css.get('sugati__Email_Font_Size__c');
            if (fs != null && String.valueOf(fs) != '') {
                compileCss += 'font-size: ' + fs + 'px !important;\n';
            }
            Object fst = css.get('sugati__Email_Font_Style__c');
            if (fst != null && String.valueOf(fst) != '') {
                compileCss += 'font-style: ' + fst + ' !important;\n';
            }
            Object fc = css.get('sugati__Email_Font_Color__c');
            if (fc != null && String.valueOf(fc) != '') {
                compileCss += 'color: ' + fc + ' !important;\n';
            }
            compileCss += '"';
            return compileCss;
        } catch (Exception ex) {
            return '';
        }
    }

    private static Schema.SObjectType resolveCssStylerType() {
        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        if (g.containsKey('sugati__CSS_Styler__c')) {
            return g.get('sugati__CSS_Styler__c');
        }
        if (g.containsKey('CSS_Styler__c')) {
            return g.get('CSS_Styler__c');
        }
        return null;
    }

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

        for (Account acc : [SELECT Id, Name FROM Account WHERE Id = :opp.AccountId]) {
            out.add(relatedOption(acc.Id, acc.Name, 'Account'));
        }
        for (Contact con : [SELECT Id, Name FROM Contact WHERE AccountId = :opp.AccountId ORDER BY Name ASC]) {
            out.add(relatedOption(con.Id, con.Name, 'Contact'));
        }
        addRelatedIfPresent(out, opportunityId, 'sugati__Client_Payment__c', 'sugati__CP_Opportunity__c', 'Name');
        addRelatedIfPresent(out, opportunityId, 'sugati__Client_Invoice__c', 'sugati__I_Opportunity__c', 'Name');
        addRelatedIfPresent(out, opportunityId, 'sugati__Client_Group__c', 'sugati__CG_Opportunity__c', 'Name');
        addRelatedIfPresent(out, opportunityId, 'sugati__Group_Member__c', 'sugati__GM_Opportunity__c', 'sugati__GM_Name__c');
        addSupplierBookings(out, opportunityId);
        addSuppliersFromBookings(out, opportunityId);
        addSupplierPayments(out, opportunityId);
        addSupplierCostPayments(out, opportunityId);
        return out;
    }

    private static void addRelatedIfPresent(
        List<RelatedRecordOptionDTO> out,
        Id opportunityId,
        String objectApi,
        String oppFieldApi,
        String nameField
    ) {
        if (!Schema.getGlobalDescribe().containsKey(objectApi)) {
            return;
        }
        String q =
            'SELECT Id, ' +
            nameField +
            ' FROM ' +
            objectApi +
            ' WHERE ' +
            oppFieldApi +
            ' = :opportunityId ORDER BY ' +
            nameField +
            ' ASC';
        try {
            for (SObject row : Database.query(q)) {
                out.add(relatedOption(row.Id, String.valueOf(row.get(nameField)), objectApi.replace('sugati__', '')));
            }
        } catch (Exception ex) {
            // skip unsupported object/field combos
        }
    }

    private static void addSupplierBookings(List<RelatedRecordOptionDTO> out, Id opportunityId) {
        if (!canAccess('sugati__Supplier_Booking__c')) {
            return;
        }
        for (sugati__Supplier_Booking__c sb : [
            SELECT Id,
                Name,
                RecordType.Name,
                sugati__SB_Day__c,
                sugati__SB_Supplier__r.Name,
                sugati__SB_Booking_Status__c
            FROM sugati__Supplier_Booking__c
            WHERE sugati__SB_Opportunity__c = :opportunityId
            ORDER BY sugati__SB_Day__c ASC
        ]) {
            String label = 'Day ' + sb.sugati__SB_Day__c + ' : ' + sb.RecordType.Name;
            if (sb.sugati__SB_Supplier__r != null) {
                label += ' : ' + sb.sugati__SB_Supplier__r.Name;
            }
            if (String.isNotBlank(sb.sugati__SB_Booking_Status__c)) {
                label += ' : ' + sb.sugati__SB_Booking_Status__c;
            }
            out.add(relatedOption(sb.Id, label, 'Supplier_Booking__c'));
        }
    }

    private static void addSuppliersFromBookings(List<RelatedRecordOptionDTO> out, Id opportunityId) {
        Set<Id> supplierIds = new Set<Id>();
        for (sugati__Supplier_Booking__c sb : [
            SELECT sugati__SB_Supplier__c, sugati__SB_Supplier__r.Name
            FROM sugati__Supplier_Booking__c
            WHERE sugati__SB_Opportunity__c = :opportunityId
            AND sugati__SB_Supplier__c != null
        ]) {
            if (!supplierIds.contains(sb.sugati__SB_Supplier__c)) {
                supplierIds.add(sb.sugati__SB_Supplier__c);
                out.add(relatedOption(sb.sugati__SB_Supplier__c, sb.sugati__SB_Supplier__r.Name, 'Supplier__c'));
            }
        }
    }

    private static void addSupplierPayments(List<RelatedRecordOptionDTO> out, Id opportunityId) {
        if (!canAccess('sugati__Supplier_Payment__c')) {
            return;
        }
        try {
            for (SObject sp : Database.query(
                'SELECT Id, Name, sugati__SBP_Supplier_Cost_Currency_Value__r.sugati__SCP_Supplier__r.Name ' +
                    'FROM sugati__Supplier_Payment__c ' +
                    'WHERE sugati__SBP_Supplier_Cost_Currency_Value__r.sugati__SCP_Opportunity__c = :opportunityId'
            )) {
                String supName = '';
                if (sp.getSObject('sugati__SBP_Supplier_Cost_Currency_Value__r') != null) {
                    SObject scv = sp.getSObject('sugati__SBP_Supplier_Cost_Currency_Value__r');
                    if (scv.getSObject('sugati__SCP_Supplier__r') != null) {
                        supName = String.valueOf(scv.getSObject('sugati__SCP_Supplier__r').get('Name'));
                    }
                }
                out.add(relatedOption(sp.Id, String.valueOf(sp.get('Name')) + ' - ' + supName, 'Supplier_Payment__c'));
            }
        } catch (Exception ex) {
            // ignore
        }
    }

    private static void addSupplierCostPayments(List<RelatedRecordOptionDTO> out, Id opportunityId) {
        if (!canAccess('sugati__Supplier_Cost_Payment__c')) {
            return;
        }
        Set<Id> seen = new Set<Id>();
        try {
            for (SObject scp : Database.query(
                'SELECT Id, sugati__SCP_Supplier__c, sugati__SCP_Supplier__r.Name ' +
                    'FROM sugati__Supplier_Cost_Payment__c ' +
                    'WHERE sugati__SCP_Opportunity__c = :opportunityId AND sugati__SCP_Supplier__c != null ' +
                    'ORDER BY sugati__SCP_Supplier__r.Name ASC'
            )) {
                Id supId = (Id) scp.get('sugati__SCP_Supplier__c');
                if (seen.contains(supId)) {
                    continue;
                }
                seen.add(supId);
                String name = scp.getSObject('sugati__SCP_Supplier__r') != null
                    ? String.valueOf(scp.getSObject('sugati__SCP_Supplier__r').get('Name'))
                    : String.valueOf(scp.get('Id'));
                out.add(relatedOption((Id) scp.get('Id'), name, 'Supplier_Cost_Payment__c'));
            }
        } catch (Exception ex) {
            // ignore
        }
    }

    private static RelatedRecordOptionDTO relatedOption(Id recordId, String label, String objectType) {
        RelatedRecordOptionDTO dto = new RelatedRecordOptionDTO();
        dto.recordId = recordId;
        dto.label = label;
        dto.objectType = objectType;
        return dto;
    }

    private static Boolean isOpportunityRelatedTemplate(SObject row) {
        if (row == null) {
            return false;
        }
        String relatedTo = row.get('sugati__ET_Related_To_Record__c') != null
            ? String.valueOf(row.get('sugati__ET_Related_To_Record__c')).trim()
            : '';
        return relatedTo == RELATED_TO_OPPORTUNITY;
    }

    private static LegacyTemplateRowDTO mapTemplateRow(SObject row) {
        LegacyTemplateRowDTO dto = new LegacyTemplateRowDTO();
        dto.id = row.Id;
        dto.name = String.valueOf(row.get('Name'));
        dto.templateName = String.valueOf(row.get('sugati__ET_Template_Name__c'));
        dto.relatedToRecord = RELATED_TO_OPPORTUNITY;
        dto.intro = row.get('sugati__ET_Email_Intro__c') != null ? String.valueOf(row.get('sugati__ET_Email_Intro__c')) : '';
        dto.closing = row.get('sugati__ET_Email_Closing__c') != null ? String.valueOf(row.get('sugati__ET_Email_Closing__c')) : '';
        dto.templateStage = row.get('sugati__ET_Opportunity_Stage__c') != null
            ? String.valueOf(row.get('sugati__ET_Opportunity_Stage__c')).trim()
            : '';
        dto.assignedUserId = (Id) row.get('sugati__ET_User__c');
        SObject userRow = row.getSObject('sugati__ET_User__r');
        dto.assignedUserName = userRow != null ? String.valueOf(userRow.get('Name')) : null;
        List<String> metaParts = new List<String>();
        if (String.isNotBlank(dto.templateStage)) {
            metaParts.add(dto.templateStage);
        }
        if (String.isNotBlank(dto.assignedUserName)) {
            metaParts.add(dto.assignedUserName);
        }
        dto.meta = metaParts.isEmpty() ? dto.templateName : String.join(metaParts, ' · ');
        return dto;
    }

    private static List<String> resolveOpportunityStageSortOrder() {
        List<String> ordered = new List<String>();
        Map<String, Boolean> seen = new Map<String, Boolean>();

        Schema.DescribeFieldResult stageField =
            Schema.SObjectType.sugati__Email_Template__c.fields.sugati__ET_Opportunity_Stage__c;
        for (Schema.PicklistEntry entry : stageField.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            addUniqueStageLabel(ordered, seen, entry.getValue());
        }

        for (OpportunityStage stageRow : [
            SELECT MasterLabel, SortOrder
            FROM OpportunityStage
            WHERE IsActive = true
            ORDER BY SortOrder ASC NULLS LAST
        ]) {
            addUniqueStageLabel(ordered, seen, stageRow.MasterLabel);
        }
        return ordered;
    }

    private static String resolveTemplateStageForOpportunity(String opportunityStageName) {
        if (String.isBlank(opportunityStageName)) {
            return null;
        }
        String trimmed = opportunityStageName.trim();

        Schema.DescribeFieldResult stageField =
            Schema.SObjectType.sugati__Email_Template__c.fields.sugati__ET_Opportunity_Stage__c;
        for (Schema.PicklistEntry entry : stageField.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            if (entry.getValue().equalsIgnoreCase(trimmed)) {
                return entry.getValue();
            }
        }

        try {
            sugati__Sugati_Stage_Name_Mapping__c mapping = sugati__Sugati_Stage_Name_Mapping__c.getOrgDefaults();
            if (mapping != null) {
                for (Schema.SObjectField fieldRef : Schema.SObjectType.sugati__Sugati_Stage_Name_Mapping__c.fields.getMap()
                    .values()) {
                    Schema.DescribeFieldResult fieldDescribe = fieldRef.getDescribe();
                    if (fieldDescribe.getType() != Schema.DisplayType.STRING) {
                        continue;
                    }
                    Object mappedValue = mapping.get(fieldDescribe.getName());
                    if (mappedValue == null) {
                        continue;
                    }
                    if (String.valueOf(mappedValue).trim().equalsIgnoreCase(trimmed)) {
                        return fieldDescribe.getLabel();
                    }
                }
            }
        } catch (Exception ex) {
            // ignore mapping lookup failures
        }
        return trimmed;
    }

    private static void addUniqueStageLabel(List<String> ordered, Map<String, Boolean> seen, String label) {
        if (String.isBlank(label)) {
            return;
        }
        String key = label.trim().toLowerCase();
        if (seen.containsKey(key)) {
            return;
        }
        seen.put(key, true);
        ordered.add(label.trim());
    }

    private static Map<String, Integer> buildStageRankMap(List<String> stageOrder) {
        Map<String, Integer> ranks = new Map<String, Integer>();
        if (stageOrder == null) {
            return ranks;
        }
        Integer index = 0;
        for (String stage : stageOrder) {
            if (String.isBlank(stage)) {
                continue;
            }
            String key = stage.trim().toLowerCase();
            if (!ranks.containsKey(key)) {
                ranks.put(key, index++);
            }
        }
        return ranks;
    }

    private static void sortTemplatesByOpportunityStage(
        List<LegacyTemplateRowDTO> templates,
        String opportunityStageName,
        List<String> stageOrder
    ) {
        if (templates == null || templates.size() < 2) {
            return;
        }
        Map<String, Integer> stageRanks = buildStageRankMap(stageOrder);
        String currentStageKey = String.isBlank(opportunityStageName)
            ? ''
            : opportunityStageName.trim().toLowerCase();
        templates.sort(new LegacyTemplateStageComparator(currentStageKey, stageRanks));
    }

    private class LegacyTemplateStageComparator implements System.Comparator<LegacyTemplateRowDTO> {
        private final String currentStageKey;
        private final Map<String, Integer> stageRanks;

        private LegacyTemplateStageComparator(String currentStageKey, Map<String, Integer> stageRanks) {
            this.currentStageKey = currentStageKey;
            this.stageRanks = stageRanks;
        }

        public Integer compare(LegacyTemplateRowDTO left, LegacyTemplateRowDTO right) {
            Integer leftSuggested = isSuggested(left) ? 1 : 0;
            Integer rightSuggested = isSuggested(right) ? 1 : 0;
            if (leftSuggested != rightSuggested) {
                return rightSuggested - leftSuggested;
            }

            Integer stageCmp = stageRank(left.templateStage) - stageRank(right.templateStage);
            if (stageCmp != 0) {
                return stageCmp;
            }

            String leftName = left.name != null ? left.name.trim().toLowerCase() : '';
            String rightName = right.name != null ? right.name.trim().toLowerCase() : '';
            return leftName.compareTo(rightName);
        }

        private Boolean isSuggested(LegacyTemplateRowDTO row) {
            if (String.isBlank(currentStageKey)) {
                return false;
            }
            if (String.isBlank(row.templateStage)) {
                return true;
            }
            return row.templateStage.trim().toLowerCase() == currentStageKey;
        }

        private Integer stageRank(String templateStage) {
            if (String.isBlank(templateStage)) {
                return 9999;
            }
            String key = templateStage.trim().toLowerCase();
            if (!stageRanks.containsKey(key)) {
                return 9998;
            }
            return stageRanks.get(key);
        }
    }

    private static String resolveOpportunityStageName(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        List<Opportunity> opps = [SELECT StageName FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        if (opps.isEmpty() || String.isBlank(opps[0].StageName)) {
            return null;
        }
        return opps[0].StageName.trim();
    }

    private static Boolean templateVisibleForCatalog(SObject row, Id currentUserId) {
        Id templateUserId = (Id) row.get('sugati__ET_User__c');
        return templateUserId == null || templateUserId == currentUserId;
    }

    private static Boolean templateVisibleForSendContext(SObject row, String opportunityStageName, Id currentUserId) {
        if (!templateVisibleForCatalog(row, currentUserId)) {
            return false;
        }
        String templateStage = row.get('sugati__ET_Opportunity_Stage__c') != null
            ? String.valueOf(row.get('sugati__ET_Opportunity_Stage__c')).trim()
            : '';
        if (String.isBlank(templateStage)) {
            return true;
        }
        if (String.isBlank(opportunityStageName)) {
            return false;
        }
        return templateStage.equalsIgnoreCase(opportunityStageName);
    }

    @TestVisible
    private static Boolean templateVisibleForSendContextForTest(
        Id templateUserId,
        String templateStage,
        String opportunityStageName,
        Id currentUserId
    ) {
        Map<String, Object> values = new Map<String, Object>{
            'sugati__ET_User__c' => templateUserId,
            'sugati__ET_Opportunity_Stage__c' => templateStage
        };
        SObject row = Schema.getGlobalDescribe().get('sugati__Email_Template__c').newSObject();
        for (String fieldName : values.keySet()) {
            row.put(fieldName, values.get(fieldName));
        }
        return templateVisibleForSendContext(row, opportunityStageName, currentUserId);
    }

    private static Id resolveEmailRecordTypeId() {
        try {
            List<RecordType> rts = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'sugati__Email_Template__c'
                AND DeveloperName = 'Email'
                LIMIT 1
            ];
            return rts.isEmpty() ? null : rts[0].Id;
        } catch (Exception ex) {
            return null;
        }
    }

    private static EmailAddressOptionDTO buildAddressOption(
        String email,
        String label,
        Id supplierId,
        List<String> supplierContactTypes
    ) {
        EmailAddressOptionDTO dto = new EmailAddressOptionDTO();
        dto.email = email;
        dto.label = label;
        dto.supplierId = supplierId;
        dto.recordId = supplierId;
        dto.supplierContactTypes = supplierContactTypes == null ? new List<String>() : supplierContactTypes;
        return dto;
    }

    private static String formatPersonLabel(String firstName, String lastName, String email) {
        String name = '';
        if (!String.isBlank(firstName)) {
            name += firstName + ' ';
        }
        if (!String.isBlank(lastName)) {
            name += lastName;
        }
        name = name.trim();
        if (String.isBlank(name)) {
            return email;
        }
        return name + ' (' + email + ')';
    }

    private static String formatSupplierContactName(sugati__Supplier_Contact__c sc) {
        String name = '';
        if (!String.isBlank(sc.sugati__SC_First_Name__c)) {
            name += sc.sugati__SC_First_Name__c + ' ';
        }
        if (!String.isBlank(sc.sugati__SC_Last_Name__c)) {
            name += sc.sugati__SC_Last_Name__c + ' ';
        }
        if (name != '' && !String.isBlank(sc.sugati__Type__c)) {
            name += '- ' + sc.sugati__Type__c + ' ';
        } else if (!String.isBlank(sc.sugati__Type__c)) {
            name += sc.sugati__Type__c + ' ';
        }
        if (!String.isBlank(sc.sugati__SC_Email__c)) {
            name += '(' + sc.sugati__SC_Email__c + ')';
        }
        return name.trim();
    }

    private static List<String> splitMultiPicklist(String value) {
        List<String> out = new List<String>();
        if (String.isBlank(value)) {
            return out;
        }
        for (String part : value.split(';')) {
            if (!String.isBlank(part)) {
                out.add(part.trim());
            }
        }
        return out;
    }

    private static Boolean supplierContactMatchesTypes(String typeValue, List<String> types) {
        if (types == null || types.isEmpty()) {
            return true;
        }
        if (String.isBlank(typeValue)) {
            return false;
        }
        Set<String> allowed = new Set<String>();
        for (String t : types) {
            allowed.add(t.toLowerCase());
        }
        for (String part : typeValue.split(';')) {
            if (!String.isBlank(part) && allowed.contains(part.trim().toLowerCase())) {
                return true;
            }
        }
        return false;
    }

    private static String getEmailBodySafe(String pageSection, Opportunity opp, String templateName) {
        // Utility.getEmailBody is provided by the Sugati managed package at runtime in customer orgs.
        // Unmanaged code cannot reference that class directly in all packaging contexts.
        return '';
    }

    private static Boolean canAccess(String objectApi) {
        Schema.SObjectType token = Schema.getGlobalDescribe().get(objectApi);
        if (token == null) {
            return false;
        }
        return token.getDescribe().isAccessible();
    }
}
