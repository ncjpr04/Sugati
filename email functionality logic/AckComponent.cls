/**
 * @File Name          : AckComponent.cls
 * @Description        : 
 * @Author             : ????@sugatitravel.com
 * @Group              : 
 * @Last Modified By   : andy@sugatitravel.com
 * @Last Modified On   : 2026-03-25
 * @Modification Log   : 
 * Ver       Date            Author                 Modification
 * 1.0    ??/??/????   ????@sugatitravel.com     Initial Version
 * 1.01   20/05/2020   james@sugatitravel.com    be able to handle ContentVersionId in attachments
**/
public with sharing Class AckComponent{    
    public Opportunity opp {get;set;}
    public String emailAddresses {get;set;}
    public String emailW {get;set;}
    public String emailBody {get;set;}
    public EmailTemplate emailTemp {get;set;}
    public String getEmailW {get;set;}
    public String pageName {get;set;}
    public String oppRecords {get;set;}
    public transient String autoSuggestTime {get;set;}
    public String nameSpacePrefix {get;set;}
    public Static List<String> lstOfAttchments {get;set;}
    public String dateFormat {get;set;}
    public Boolean isPartnerUser {get;set;}
    public String communityURLPrefix {get;set;}
    public String communityURL {get;set;}
    public String communityTemplateName {get;set;}
    public Boolean useNewDataModel {get;set;}
    
    String oppId;
    List<PicklistValue> mapEmail = new List<PicklistValue>();
    public AckComponent() {
        oppId = ApexPages.CurrentPage().getParameters().get('Id');
        pageName = '';
        nameSpacePrefix = Utility.getNamespacePrefix();
        dateFormat = Utility.getUserDateFormat().split(' ')[0]; 
        if (oppId != null && oppId.startsWith('006') && Utility.canAccessObj('Opportunity')) {
            List<Opportunity> oppList = [
                SELECT Id, Name, O_Departure_Date__c, AccountId 
                FROM Opportunity 
                WHERE Id =: oppId
            ];
            if (!oppList.isEmpty()) {
                opp = oppList[0];
            }
            if (opp != null) {
                if (opp.O_Departure_Date__c != null) {
                    Integer year = opp.O_Departure_Date__c.year();
                    Integer month = opp.O_Departure_Date__c.month();
                    List<Opportunity> lstOpp =  [
                        SELECT Id, Name, O_Holiday_Type__c, Pipeline__c, CreatedDate, StageName, O_Departure_Date__c, O_Return_Date__c 
                        FROM Opportunity 
                        WHERE Id !=: opp.Id 
                        AND CALENDAR_YEAR(O_Departure_Date__c) =: year 
                        AND CALENDAR_MONTH(O_Departure_Date__c) =: month 
                        AND AccountId =: opp.AccountId 
                        ORDER BY createdDate DESC
                    ];
                    oppRecords = JSON.serialize(lstOpp);
                } else {
                    oppRecords = '[]'; 
                }
            }
        }
        pageName = getVFPageName();
        String nameSpacePrefix = Utility.getNameSpacePrefix();
        if (nameSpacePrefix.length() > 0) {
            pageName = pageName.remove(nameSpacePrefix);
        }
        
        getEmailW = JSON.serialize(new EmailWrapper(''));    
        List<PicklistValue> lstTime = new List<PicklistValue>();
        String strTimes = '';
        for (integer i = 0 ; i < 24; i ++) {
            for (integer j = 0 ; j < 60; j++) {
                if (i < 10) {
                    if (j < 10) {
                        if (strTimes == '') {
                            strTimes = '0'+i +':'+ '0'+ j;
                        } else {
                            strTimes += ',' + '0'+i +':'+ '0'+ j;
                        }
                    } else {
                        strTimes += ',' + '0'+i +':'+  j;
                    }
                } else {
                    if (j < 10) {
                        strTimes += ',' + i +':'+ '0'+ j;
                    } else {
                        strTimes += ',' + i +':' + j;
                    }
                }
            }
        }
        
        for (String sb : strTimes.split(',')) {
            lstTime.add(new PicklistValue(sb,sb));
        }
        autoSuggestTime  = JSON.serialize(lstTime);
        
        isPartnerUser = Utility.isPartnerUser();
        communityURLPrefix = '';
        communityTemplateName = '';
        communityURL = '';
        
        if (isPartnerUser) {
            Map<String, String> mapProperties =  Utility.getCommunityProperties();
            communityTemplateName = mapProperties.get('communityTemplateName');
            communityURLPrefix = mapProperties.get('communityURLPrefix');
            communityURL = mapProperties.get('communityURL');
        }

        useNewDataModel = false;
        if (SugatiConstants__c.getInstance('TRIGGER_NEW_FRAMEWORK') != null) {
            useNewDataModel = Boolean.valueOf(SugatiConstants__c.getInstance('TRIGGER_NEW_FRAMEWORK').Value__c);
        }
    }
    
    public string getVFPageName()  {
        String nameSpacePrefix = Utility.getNameSpacePrefix();
        if (pageName == null || pageName == '')  {
            // THIS IS THE CLOSEST YOU CAN GET SO FAR
            String pageName = ApexPages.CurrentPage().getUrl();  
            // IT ALWAYS STARTS WITH /APEX/ SO REMOVE IT
            pageName = pageName.replaceFirst('/apex/',''); 
            if (pageName.startsWith('/')) {
                pageName = pageName.replaceFirst('/', '');
            }        
            pageName = EncodingUtil.urlEncode(pageName, 'UTF-8');  
            // %3F IS THE VALUE OF THE QUESTION MARK IN UTF-8 
            string[] pageNameExtra = pageName.split('%3F',0);   
            // SO YOU MAY SPLIT THE STRING AT THAT POINT
              // FOR THIS PURPOSE YOU ONLY NEED THE FIRST
            // IN THE RESULTING ARRAY
            pageName = pageNameExtra[0]; 
            // HERE IS YOUR PRODUCT  
            //system.debug('pageName-->'+pageName);
            
        } else if (nameSpacePrefix.length() > 0 && pageName.contains(nameSpacePrefix)) {
            pageName = pageName.replaceAll(nameSpacePrefix, '');
        } 
        return pageName;                                         
    }
    
    //Fetch all the Page Messages
    @remoteAction
    public static Map<string, String> getErrorMessages(String pagename) {
        pageName = pageName.replaceAll('Legacy', '');
        return ErrorMessageController.getErrorMessage(pagename);
    }
    
    @remoteAction
    public static List<Opportunity> getOppRecords(String oppId) {
        if (oppId != '' && oppId.startsWith('006') && Utility.canAccessObj('Opportunity')) {
            Opportunity opp;
            List<Opportunity> oppList = [
                SELECT Id, O_Departure_Date__c, AccountId 
                FROM Opportunity 
                WHERE Id =: oppId
            ];
            if (!oppList.isEmpty()) {
                opp = oppList[0];
            }
            List<Opportunity> lstOpp = new List<Opportunity>();
            if (opp != null) {
                Integer year = opp.O_Departure_Date__c.year();
                Integer month = opp.O_Departure_Date__c.month();
                lstOpp = [
                    SELECT Id, Name, Pipeline__c, CreatedDate, StageName, O_Departure_Date__c, O_Return_Date__c 
                    FROM Opportunity 
                    WHERE Id =: opp.Id 
                    AND CALENDAR_YEAR(O_Departure_Date__c) =: year 
                    AND CALENDAR_MONTH(O_Departure_Date__c) =: month 
                    AND AccountId =: opp.AccountId 
                    ORDER BY CreatedDate DESC
                ];
            }
            return lstOpp;
        } else {
            return null;    
        }
    }
    
    @remoteAction
    public static List<PicklistValue> getContact(String oppId) {
        if (oppId != null && oppId != '' && oppId.startsWith('006') && Utility.canAccessObj(new List<String>{
            'Opportunity', 
            'Group_Member__c', 
            'User', 
            'Supplier_Booking__c', 
            'UserPackageLicense', 
            'Supplier_Contact__c'
        })) {
            Opportunity opp;
            List<Opportunity> oppList = [
                SELECT Id, AccountId 
                FROM Opportunity 
                WHERE Id =: oppId
            ];
            if (!oppList.isEmpty()) {
                opp = oppList[0];
            }
            List<PicklistValue> mapEmail = new List<PicklistValue>();
            for (Group_Member__c gm : [
                SELECT Id, GM_Contact__r.FirstName, GM_Contact__r.LastName, GM_Contact__r.Email 
                FROM Group_Member__c 
                WHERE GM_Opportunity__c =: oppId 
                AND GM_Contact__r.Email != null
            ]) {
                mapEmail.add(new PicklistValue(gm.GM_Contact__r.Email, gm.GM_Contact__r.FirstName + ' (' + gm.GM_Contact__r.Email + ')'));
            }
            Set<Id> lstSugatiUsers = new Set<Id>();
            for (UserPackageLicense usl : [
                SELECT Id, UserId 
                FROM UserPackageLicense 
                WHERE PackageLicense.NamespacePrefix = 'sugati'
            ]) {
                lstSugatiUsers.add(usl.UserId);
            }
            
            for (User us : [
                SELECT Id, Email, Name 
                FROM User 
                WHERE IsActive = true 
                AND Id IN :lstSugatiUsers
            ]) {
                mapEmail.add(new PicklistValue(us.Email, us.Name + ' (' + us.Email + ')'));
            }
            Set<Id> supplierIdSet = new set<Id>();
            for (Supplier_Booking__c sb : [
                SELECT Id, SB_Supplier__c, SB_Supplier__r.Name, SB_Supplier__r.S_Email__c 
                FROM Supplier_Booking__c 
                WHERE SB_Opportunity__c =: oppId 
                AND SB_Supplier__r.S_Email__c != null
            ]) {
                PicklistValue plv = new PicklistValue(sb.SB_Supplier__r.S_Email__c, sb.SB_Supplier__r.Name + ' (' + sb.SB_Supplier__r.S_Email__c + ')', sb.SB_Supplier__c);
                plv.isSupplier = true;
                mapEmail.add(plv);
                supplierIdSet.add(sb.SB_Supplier__c);
            }

            for (Supplier_Contact__c sc : [
                SELECT Id, SC_Name__c, SC_Email__c, SC_Supplier__c, Type__c 
                FROM Supplier_Contact__c 
                WHERE SC_Supplier__c IN: supplierIdSet 
                AND SC_Email__c != null
            ]) {
                PicklistValue plv = new PicklistValue(sc.SC_Email__c, sc.SC_Name__c + ' (' + sc.SC_Email__c + ')', sc.SC_Supplier__c);
                if (sc.Type__c != null) {
                    for (String scType : sc.Type__c.split(';')) {
                        plv.supplierContactTypes.add(scType);
                    }
                }
                mapEmail.add(plv);
            }
            return mapEmail;
        } else {
            return new List<PicklistValue>();
        }
    }

    @remoteAction
    public static EmailWrapper getTemplate(String oppId, String cgId, String templateName, String pageName) {
        try {
            Site__c site = Site__c.getInstance();
            pageName = pageName.replaceAll('Legacy', '');
            if (oppId != null && oppId.startsWith('006') && Utility.canAccessObj(new List<String>{
                'Opportunity', 
                'Contact', 
                'Group_Member__c', 
                'Email_Template__c', 
                'CSS_Styler__c', 
                'Supplier__c', 
                'Account', 
                'Contact'
            })) {
                EmailWrapper ew;
                Group_Member__c leadGM;
                Group_Member__c bookingLeadGM;
                List<Group_Member__c> otherGMs = new List<Group_Member__c>();
                String contactId;
                List<Group_Member__c> gmCCList = new List<Group_Member__c >();
                List<Opportunity> lstOpp = [
                    SELECT Id, AccountId, Description, O_Holiday_Type__c, O_Document_Communication__c, O_Agent__r.S_Email__c, O_Agent__r.Name, 
                           O_Agent_SC__r.SC_Email__c, O_Agent_SC__r.SC_First_Name__c, O_Agent_SC__r.SC_Last_Name__c, O_Lead_CG__r.CG_Lead_Group_Member__c 
                    FROM Opportunity 
                    WHERE Id =: oppId
                ];
                List<Group_Member__c> gmList = null;
                if (String.isNotBlank(cgId)) {
                    gmList = [
                        SELECT Id, GM_Contact__c, GM_Contact__r.Account.Name, GM_Contact__r.Account.A_First_Name__c, GM_Contact__r.Account.A_Last_Name__c, 
                               GM_Contact__r.FirstName, GM_Contact__r.LastName, GM_Contact__r.Email, GM_Lead_Passenger__c, GM_Email__c 
                        FROM Group_Member__c 
                        WHERE GM_Client_Group__c =: cgId
                    ];
                } else {
                    gmList = [
                        SELECT Id, GM_Contact__c, GM_Contact__r.Account.Name, GM_Contact__r.Account.A_First_Name__c, GM_Contact__r.Account.A_Last_Name__c, 
                               GM_Contact__r.FirstName, GM_Contact__r.LastName, GM_Contact__r.Email,GM_Lead_Passenger__c, GM_Email__c 
                        FROM Group_Member__c 
                        WHERE GM_Opportunity__c =: oppId
                    ];
                }
                for (Group_Member__c gm : gmList) { 
                    if (gm.GM_Lead_Passenger__c) {
                        if ((templateName == 'SendInvoicePDF' || templateName == 'SendItineraryPDF' || templateName == 'Send Invoice And Itinerary PDF') && (gm.GM_Email__c != null || gm.GM_Contact__r.Email != null)) {
                            leadGM = gm;
                            contactId = gm.GM_Contact__c;
                            System.debug('Invoice GM: ' + JSON.serialize(leadGM));
                        } else if (gm.GM_Contact__r.Account != null && gm.GM_Contact__r.Account.A_First_Name__c != null && gm.GM_Contact__r.FirstName != null && gm.GM_Contact__r.Account.A_First_Name__c.trim() == gm.GM_Contact__r.FirstName.trim() && gm.GM_Contact__r.Account.A_Last_Name__c != null && gm.GM_Contact__r.Account.A_Last_Name__c.trim() == gm.GM_Contact__r.LastName.trim()) {
                            leadGM = gm;
                            contactId = gm.GM_Contact__c;
                        } else if ( gm.GM_Contact__r.Account != null && gm.GM_Contact__r.Account.A_First_Name__c == null && gm.GM_Contact__r.Account.A_Last_Name__c == null && gm.GM_Contact__r.Account.Name != null && gm.GM_Contact__r.FirstName != null && gm.GM_Contact__r.Account.Name.contains(gm.GM_Contact__r.FirstName) && gm.GM_Contact__r.Account.Name.contains(gm.GM_Contact__r.LastName) ) {
                            leadGM = gm;
                            contactId = gm.GM_Contact__c;
                        }                         
                        if (leadGM  == null && gm.GM_Contact__r.Email != null) {
                            leadGM = gm;
                            contactId = gm.GM_Contact__c;
                        }
                        //set the bookingLeadGM if group member is booking's lead
                        if (leadGM != null && !lstOpp.isEmpty() && leadGM.Id == lstOpp[0].O_Lead_CG__r.CG_Lead_Group_Member__c) {
                            bookingLeadGM = leadGM;
                            System.debug('Invoice Booking GM : ' + JSON.serialize(leadGM));
                        } else {
                            otherGMs.add(gm);
                        }
                    } else {
                        if (gm.GM_Contact__r.Email != null) {
                            gmCCList.add(gm);
                        }
                    }
                }
                if (bookingLeadGM != null) {
                    leadGM = bookingLeadGM;
                    contactId = bookingLeadGM.GM_Contact__c;
                    if (!otherGMs.isEmpty()) {
                        gmCCList.addAll(otherGMs);
                    }
                }
                List<Email_Template__c> et = [
                    SELECT Id, ET_Email_Closing__c, ET_Auto_Attchment_Documents__c, ET_Email_Intro__c, 
                    ET_Template_Name__c, ET_Page_Section__c, To_Address_Filter__c, S_ET_Auto_CC_Supplier_Contacts__c
                    FROM Email_Template__c 
                    WHERE ET_Page_Section__c =: templateName 
                    AND ET_User__c =: UserInfo.getUserId()
                ];
                
                if (et.size() == 0) {
                    et = [
                        SELECT Id, ET_Email_Intro__c, ET_Auto_Attchment_Documents__c, ET_Email_Closing__c, 
                        ET_Template_Name__c, ET_Page_Section__c, To_Address_Filter__c, S_ET_Auto_CC_Supplier_Contacts__c
                        FROM Email_Template__c 
                        WHERE ET_Page_Section__c =: templateName 
                        AND ET_User__c = null
                    ];
                }

                if (et.size() > 0 && leadGM != null ) {
                    List<EmailTemplate>  emailTemp = [
                        SELECT Id, Subject 
                        FROM EmailTemplate 
                        WHERE Name =: et[0].ET_Template_Name__c
                    ];
                    if (emailTemp.size() > 0 ) {
                        String emailIdStr = emailTemp[0].Id;
                        String contactIdStr = contactId;
                        String mailTextBody;
                        String emailBody;
                        String subjectText;
                        if (lstOpp[0].O_Document_Communication__c == 'Agency' ||  lstOpp[0].O_Document_Communication__c == 'Agent') {
                            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(emailIdStr,'',oppId);
                            mailTextBody = email.getPlainTextBody();
                            emailBody = email.getHTMLBody();
                            subjectText = email.getSubject();
                        } else if (contactId != null) {
                            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(emailIdStr,contactIdStr,oppId);
                            System.debug('****** email ***** : ' + email);
                            System.debug('****** emailBody ***** : ' + email.getHTMLBody());
                            System.debug('****** mailTextBody ***** : ' + email.getPlainTextBody());
                            mailTextBody = email.getPlainTextBody();
                            emailBody = email.getHTMLBody();
                            subjectText = email.getSubject();
                        }
                        String compileCSS = '';
                        for (CSS_Styler__c cssdata : [
                            SELECT Id, Email__c, Typography__c, Table__c, Button__c, Name, Email_Font_Family__c, Email_Font_Size__c, 
                                   Email_Font_Style__c, Email_Font_Color__c, CSS__c, CS_Button_JSON__c, Button_CSS__c, Is_Active__c,Backgroundcolor__c, 
                                   Font_Family__c, Font_Size__c, Font_Style__c, H1color__c, H2color__c, H3color__c, H4color__c, Header_Color__c, 
                                   Header_Font_size__c, Header_Font_Style__c, Hr_Background__c, Hr_Height__c, CS_Itinerary_Page_Marker__c, 
                                   CS_Travelling_Country_Marker__c, CS_Address_Marker__c 
                            FROM CSS_Styler__c 
                            WHERE Name =: pageName 
                            AND Is_Active__c = true
                        ]) {
                            compileCSS = 'style="';
                            if (cssdata.Email__c) {
                                if (cssdata.Email_Font_Family__c != null && cssdata.Email_Font_Family__c != '') {
                                    compileCSS += 'font-family: ' + cssdata.Email_Font_Family__c + ' !important;\n';
                                }
                                if (cssdata.Email_Font_Size__c != null && cssdata.Email_Font_Size__c != '') {
                                    compileCSS += 'font-size: ' + cssdata.Email_Font_Size__c + 'px !important;\n';
                                }
                                if (cssdata.Email_Font_Style__c != null && cssdata.Email_Font_Style__c != '') {
                                    compileCSS += 'font-style: ' + cssdata.Email_Font_Style__c + ' !important;\n';
                                }
                                if (cssdata.Email_Font_Color__c != null && cssdata.Email_Font_Color__c != '') {
                                    compileCSS += 'color: ' + cssdata.Email_Font_Color__c + ' !important;\n';
                                }
                            }
                            compileCSS += '"';
                        }
                        if (compileCSS != '') {
                            emailBody = '<div ' + compileCSS + '>' + emailBody + '</div>';
                        } else {
                            emailBody = '<div class="emailBody1" style="font-family: arial,sans-serif;">' + emailBody + '</div>';
                        }
                         
                        //Get Body from Utility Class
                        String bodyStr = Utility.getEmailBody(templateName, lstOpp[0], et[0].ET_Template_Name__c);
                        if (et[0].ET_Email_Intro__c != null) {
                            emailBody = emailBody.replace('~intro~','<br/>'+et[0].ET_Email_Intro__c);
                        }
                        emailBody = emailBody.replace('~body~','<br/>'+bodyStr);
                        if (et[0].ET_Email_Closing__c != null) {
                            emailBody = emailBody.replace('~footer~','<br/>'+et[0].ET_Email_Closing__c);
                        }
                        ew = new EmailWrapper(JSON.serialize(emailBody));
                        ew.subject = subjectText;
                        if (et[0].ET_Auto_Attchment_Documents__c != null) {
                            ew.selectedAttchment.addAll(et[0].ET_Auto_Attchment_Documents__c.split(';'));
                        }
                        PicklistValue leadEmailContact;
                        
                        if (lstOpp[0].O_Document_Communication__c != 'Agency' &&  lstOpp[0].O_Document_Communication__c != 'Agent') {
                            //using GM_Email__C if any
                             String leadName = genrateName(leadGM.GM_Contact__r.FirstName,leadGM.GM_Contact__r.LastName, (templateName == 'SendInvoicePDF' || templateName == 'SendItineraryPDF' || templateName == 'Send Invoice And Itinerary PDF') && String.isNotBlank(leadGM.GM_Email__c) ? leadGM.GM_Email__c :  leadGM.GM_Contact__r.Email);
                             leadEmailContact = new PicklistValue(((templateName == 'SendInvoicePDF' || templateName == 'SendItineraryPDF' || templateName == 'Send Invoice And Itinerary PDF') && String.isNotBlank(leadGM.GM_Email__c) ? leadGM.GM_Email__c : leadGM.GM_Contact__r.Email), leadName);   
                        } else {
                            if (lstOpp[0].O_Document_Communication__c == 'Agency' && lstOpp[0].O_Agent__r.S_Email__c != null) {
                                String leadEmailContactName = genrateName(lstOpp[0].O_Agent__r.Name,'',lstOpp[0].O_Agent__r.S_Email__c);
                                leadEmailContact = new PicklistValue(lstOpp[0].O_Agent__r.S_Email__c,leadEmailContactName);   
                            } else if (lstOpp[0].O_Document_Communication__c == 'Agent' && lstOpp[0].O_Agent_SC__r.SC_Email__c != null) {
                                 String leadEmailContactName = genrateName(lstOpp[0].O_Agent_SC__r.SC_First_Name__c,lstOpp[0].O_Agent_SC__r.SC_Last_Name__c,lstOpp[0].O_Agent_SC__r.SC_Email__c);
                                 leadEmailContact = new PicklistValue(lstOpp[0].O_Agent_SC__r.SC_Email__c,leadEmailContactName);   
                            }
                        }
                        if (templateName.indexOf('SupplierPayments') == -1  && et[0].ET_Page_Section__c != 'SupplierPayments') {
                            ew.selectedTo.add(leadEmailContact);
                        }
                        for (Group_Member__c gmCC : gmCCList) {
                            String leadEmailContactCCName = genrateName(gmCC.GM_Contact__r.FirstName,gmCC.GM_Contact__r.LastName,gmCC.GM_Contact__r.Email);
                            PicklistValue leadEmailContactCC = new PicklistValue(gmCC.GM_Contact__r.Email,leadEmailContactCCName);
                            if (templateName.indexOf('SupplierPayments') == -1  && et[0].ET_Page_Section__c != 'SupplierPayments') {
                                if (site.Dont_auto_cc_client__c == false) {
                                    ew.selectedCc.add(leadEmailContactCC);
                                }
                            }
                        }
                        if (SugatiConstants__c.getInstance('DO_NOT_ADD_USER_AS_BCC_ON_EMAIL') == null || Boolean.valueOf(SugatiConstants__c.getInstance('DO_NOT_ADD_USER_AS_BCC_ON_EMAIL').Value__c)) {
                            ew.selectedBcc.add(new PicklistValue(UserInfo.getUserEmail(),UserInfo.getName()+' ('+UserInfo.getUserEmail()+')'));
                        }
                        if (SugatiConstants__c.getInstance('DEFAULT_BCC_ADD_ON_SEND_EMAIL') != null && SugatiConstants__c.getInstance('DEFAULT_BCC_ADD_ON_SEND_EMAIL').Value__c != null) {
                            ew.selectedBcc.add(new PicklistValue(SugatiConstants__c.getInstance('DEFAULT_BCC_ADD_ON_SEND_EMAIL').Value__c, 'Default (' + SugatiConstants__c.getInstance('DEFAULT_BCC_ADD_ON_SEND_EMAIL').Value__c + ')') );
                        }
                        if (ContactId != null) {
                            ew.leadpassenger = [Select id,Salutation,firstname,lastname,C_Middle_Name__c,C_Prefered_Name__c,Languages__c,HomePhone,MobilePhone,OtherPhone,MailingCity,MailingStreet,MailingCountry,MailingPostalCode,Description, email,phone,Birthdate,Occupancy_Type__c ,C_Lead_Passenger__c , Adult__c,C_Child__c,C_Infant__c from Contact where id =: ContactId];
                        }
                        return ew;
                    }
                }  
            } else {
                System.assert(false,'Please create email template for this page.');    
            }   
        } catch(Exception e) {
            System.assert(false,e.getMessage() + '       ' +e.getstacktraceString());
        }
        return null;
    }
    
    @remoteAction
    public static boolean saveBroucheRequestContact(String jsoncon) {
        Contact con = (Contact)JSON.deserialize(jsoncon,Contact.class);
        if (Utility.canaccessObj('RecordType')) {
            RecordType rt;
            List<RecordType> rtList = [
                SELECT Id, Name 
                FROM RecordType 
                WHERE SObjectType = 'Task' 
                AND Name = 'Brochure Request' 
                LIMIT 1
            ];
            if (!rtList.isEmpty()) {
                rt = rtList[0];
            }
            if (true) {
                Task task = new Task();
                task.Status = 'Not Started';
                task.Subject = 'Brochure Request';
                if (rt != null) {
                    task.RecordTypeId = rt.id;
                }
                task.ActivityDate = System.Today();
                task.WhatId = con.Account.id;
                task.whoId = con.id;
                if (Utility.canInsertObj('Task')) {
                    insert Task;  
                }
                if (Task.id != null) {
                    return true;
                } else {
                    return false;
                }
            } else {
                return false;
            }
        }
        return false;
    }
     
    @remoteAction
    public static String sendEmail(EmailWrapper wrapper, String emailBody, String oppId, String templateName, String pageName, List<String> attachmentIds, String EmailTemplateName, String oppStage, String selectedId) {
        try {
            pageName = pageName.replaceAll('Legacy', '');
            String conId;
            List<Client_Group__c> cglst = new  List<Client_Group__c>();
            if (Utility.canAccessObj(new List<String>{'Group_Member__c', 'Account', 'Contact'})) {
                for (Group_Member__c gm : [
                    SELECT Id, GM_Contact__c, GM_Contact__r.Account.A_First_Name__c, GM_Contact__r.Account.A_Last_Name__c, 
                           GM_Contact__r.FirstName,GM_Contact__r.LastName 
                    FROM Group_Member__c 
                    WHERE GM_Opportunity__c =: oppId 
                    AND GM_Lead_Passenger__c = true
                ]) {
                    if (gm.GM_Contact__r.Account.A_First_Name__c == gm.GM_Contact__r.FirstName && gm.GM_Contact__r.Account.A_Last_Name__c == gm.GM_Contact__r.LastName) {
                        conId = gm.GM_Contact__c;
                    }                            
                    if (conId == null) {
                        conId = gm.GM_Contact__c;
                    }    
                }
            }
            
            List<String> toAddresses = new List<String>();
            List<String> bccAddresses = new List<String>();
            List<String> ccAddresses = new List<String>();
            for (PicklistValue pl : wrapper.selectedTo) {
                toAddresses.add(pl.value);
            }
            for (PicklistValue pl : wrapper.selectedCc) {
                ccAddresses.add(pl.value);
            }
            for (PicklistValue pl : wrapper.selectedBcc) {
                bccAddresses.add(pl.value);
            }
            Id orgWideAddressId = null;
            if (wrapper.selectedFrom != null && wrapper.selectedFrom != '')
                orgWideAddressId = wrapper.selectedFrom;
            
            String compileCSS = '';
            
            if (Utility.canAccessObj('CSS_Styler__c')) {
                for (CSS_Styler__c cssdata : [
                    SELECT Id, Email__c, Typography__c, Table__c, Button__c, Name, Email_Font_Family__c, Email_Font_Size__c, 
                           Email_Font_Style__c, Email_Font_Color__c, CSS__c, CS_Button_JSON__c, Button_CSS__c, Is_Active__c,Backgroundcolor__c, 
                           Font_Family__c, Font_Size__c, Font_Style__c, H1color__c, H2color__c, H3color__c, H4color__c, Header_Color__c, 
                           Header_Font_size__c, Header_Font_Style__c, Hr_Background__c, Hr_Height__c, CS_Itinerary_Page_Marker__c, 
                           CS_Travelling_Country_Marker__c, CS_Address_Marker__c 
                    FROM CSS_Styler__c 
                    WHERE Name =: pageName 
                    AND Is_Active__c = true
                ]) {
                    compileCSS = 'style="';
                    if (cssdata.Email__c) {
                        if (cssdata.Email_Font_Family__c != null && cssdata.Email_Font_Family__c != '') {
                            compileCSS += 'font-family: ' + cssdata.Email_Font_Family__c + ' !important;\n';
                        }
                        if (cssdata.Email_Font_Size__c != null && cssdata.Email_Font_Size__c != '') {
                            compileCSS += 'font-size: ' + cssdata.Email_Font_Size__c + ' !important;\n';
                        }
                        if (cssdata.Email_Font_Style__c != null && cssdata.Email_Font_Style__c != '') {
                            compileCSS += 'font-style: ' + cssdata.Email_Font_Style__c + ' !important;\n';
                        }
                        if (cssdata.Email_Font_Color__c != null && cssdata.Email_Font_Color__c != '') {
                            compileCSS += 'color: ' + cssdata.Email_Font_Color__c + ' !important;\n';
                        }
                    }
                    compileCSS += '"';
                }
            }
            
            if (compileCSS != '') {
                emailBody = '<div class="emailBody" ' + compileCSS + '>' + emailBody + '</div>';
            } else {
                emailBody = '<div style="font-family: arial,sans-serif;">' + emailBody + '</div>';
            }

            List<Attachment> attachedFiles = new List<Attachment>();
            if (attachmentIds.size() > 0) {
                if (Utility.canAccessObj('Attachment')) {
                    attachedFiles = [
                        SELECT Id, Name, Body 
                        FROM Attachment 
                        WHERE Id IN: attachmentIds
                    ];
                }
            }

            List<ContentVersion> docuLinks = new List<ContentVersion>();
            if (Utility.canAccessObj('ContentVersion')) {
                docuLinks = [
                    SELECT Id, VersionData, Title, PathOnClient
                    FROM ContentVersion 
                    WHERE Id In :attachmentIds
                ];
            }
            
            //emailBody
            Utility.sendTemplatedEmail(toAddresses,ccAddresses,bccAddresses,null,emailBody,conId,oppId,orgWideAddressId,true,null,wrapper.subject, attachedFiles, docuLinks);
            List<HE_Question_Categories__c> lstQC = new List<HE_Question_Categories__c>();
            if (Utility.canAccessObj('HE_Question_Categories__c')) {
                for (HE_Question_Categories__c qc: [
                    SELECT Id, Name, QC_No_Of_Questions__c 
                    FROM HE_Question_Categories__c 
                    WHERE QC_Active__c = true 
                    ORDER BY QC_Order__c
                ]) {
                    if (qc.QC_No_Of_Questions__c > 0) {
                        lstQC.add(qc);
                    }
                }
            }
            Integer currentStage = lstQC.size();   
            if (templateName == 'Acknowledgement') {
                currentStage = currentStage;
            }
            if (templateName == 'Holiday Suggestions') {
                currentStage = currentStage+1;
            }
            Opportunity opp = new Opportunity();
            if (Utility.canAccessObj('Opportunity')) {
                List<Opportunity> oppList = [
                    SELECT Id, StageName, O_Holiday_Enquiry_Stage__c, Type 
                    FROM Opportunity 
                    WHERE Id =: oppId
                ];
                if (!oppList.isEmpty()) {
                    opp = oppList[0];
                }
            }
            
            opp.O_Holiday_Enquiry_Stage__c  = currentStage;
            
            if (wrapper.followUpD != '' && wrapper.followUpD != null) {
                List<String> lstDate = wrapper.followUpD.split('/');
                if (wrapper.followUpTime != '' && wrapper.followUpTime != null) {
                    List<String> lstTIme = wrapper.followUpTime.split(':');
                    if (lstDate.size()>=3 && lstTIme.size() > 1) {
                        opp.O_Follow_Up_Time__c = datetime.newInstance(Integer.valueOf(lstDate [2]), Integer.valueOf(lstDate [1]), Integer.valueOf(lstDate [0]),Integer.valueOf(lstTIme[0]),Integer.valueOf(lstTIme[1]),0);
                    }
                } else {
                    opp.O_Follow_Up_Time__c = datetime.newInstance(Integer.valueOf(lstDate [2]), Integer.valueOf(lstDate [1]), Integer.valueOf(lstDate [0]),Integer.valueOf('00'),Integer.valueOf('00'),0);
                }
            }
            String CurrentOppStage = opp.StageName;
            opp = Utility.UpdateOppStage(opp, templateName, EmailTemplateName, oppStage);
            if (selectedId != null && opp.type == 'Group booking') {
                cglst = Utility.UpdateClientGroupStage(opp, templateName, EmailTemplateName, selectedId);
            }
            if (Utility.canUpdateObj('Client_Group__c')) {
                update cglst;
            }
            
            if (opp.O_Follow_Up_Time__c != null) {
                Task task = new Task();
                task.Status = 'Not Started';
                task.Subject = 'Follow Up Call';
                task.ActivityDate = Date.valueOf(opp.O_Follow_Up_Time__c);
                task.WhatId = Opp.id;
                task.description =  'Follow Up Call';
                
                if (Utility.canInsertObj('Task')) {
                    insert Task;  
                }
                if (Utility.canUpdateObj('Opportunity')) {
                    update opp;
                }
            } else if (opp.StageName != CurrentOppStage ) {
                if (Utility.canUpdateObj('Opportunity')) {
                    update opp;
                }
            }
            return 'Sucess';
        } catch(Exception e) {
            return e.getMessage()+e.getStackTraceString();
        }
    }
    
    @remoteAction
    public static EmailWrapper getSelectedTemplate(String oppId, String templateName, String selectedTemplate, String objName, String selectedId, List<String> selectedOpps) {
        try {
            if (oppId != null && Utility.canAccessObj(new List<String>{
                'Opportunity', 
                'Group_Member__c', 
                'Email_Template__c', 
                'CSS_Styler__c', 
                'Supplier_Contact__c', 
                'Supplier_Payment__c', 
                'Supplier_Booking__c', 
                'Contact', 
                'Supplier__c', 
                'Account', 
                'Contact'
            })) {
                EmailWrapper ew;
                Group_Member__c leadGM ;
                String contactId;
                List<Group_Member__c> gmccList = new List<Group_Member__c>(); 
                List<Opportunity> lstOpp = [
                    SELECT Id, AccountId, Description, O_Holiday_Type__c, Type, O_Document_Communication__c, 
                           O_Agent__r.S_Email__c, O_Agent__r.Name, O_Agent_SC__r.SC_Email__c, 
                           O_Agent_SC__r.SC_First_Name__c, O_Agent_SC__r.SC_Last_Name__c 
                    FROM Opportunity 
                    WHERE Id =: oppId
                ];
                for (Group_Member__c gm : [
                    SELECT Id, GM_Contact__c, GM_Contact__r.Account.A_First_Name__c, GM_Contact__r.Account.A_Last_Name__c, GM_Contact__r.Account.Name, 
                           GM_Contact__r.FirstName, GM_Contact__r.LastName, GM_Contact__r.Email, GM_Lead_Passenger__c 
                    FROM Group_Member__c 
                    WHERE GM_Opportunity__c = :oppId
                ]) {
                    if (gm.GM_Lead_Passenger__c) {
                        System.debug('gm: ' + gm);
                        System.debug('gm.GM_Contact__r: ' + gm.GM_Contact__r);
                        System.debug('gm.GM_Contact__r.Account: ' + gm.GM_Contact__r.Account);
                        if (gm.GM_Contact__r.Account.A_First_Name__c != null && gm.GM_Contact__r.FirstName != null && gm.GM_Contact__r.Account.A_First_Name__c.trim() == gm.GM_Contact__r.FirstName.trim() && gm.GM_Contact__r.Account.A_Last_Name__c != null && gm.GM_Contact__r.Account.A_Last_Name__c.trim() == gm.GM_Contact__r.LastName.trim()) {
                            leadGM = gm;
                            contactId = gm.GM_Contact__c; 
                        } else if (gm.GM_Contact__r.Account.Name != null && gm.GM_Contact__r.FirstName != null && gm.GM_Contact__r.Account.Name.containsIgnoreCase(gm.GM_Contact__r.FirstName) && gm.GM_Contact__r.Account.Name.containsIgnoreCase(gm.GM_Contact__r.LastName)) {
                            leadGM = gm;
                            contactId = gm.GM_Contact__c; 
                        }                         
                        if (leadGM  == null && gm.GM_Contact__r.Email != null) {
                            leadGM = gm;
                            contactId = gm.GM_Contact__c;
                        }    
                    } else {
                       if (gm.GM_Contact__r.Email != null) {
                           gmccList.add(gm);
                       }
                    }
                }
                  
                if (leadGM == null) {
                   leadGM  = new Group_Member__c();
                }   
                List<Email_Template__c> et = [
                    SELECT Id, ET_Email_Closing__c, ET_Auto_Attchment_Documents__c, ET_Related_To_Record__c, ET_Opportunity_Stage__c, ET_Email_Intro__c, 
                           ET_Template_Name__c, ET_Page_Section__c, To_Address_Filter__c, S_ET_Auto_CC_Supplier_Contacts__c
                    FROM Email_Template__c 
                    WHERE Id =: selectedTemplate
                ];
                if (et.size() > 0 ) {
                    List<EmailTemplate> emailTemp = [
                        SELECT Id, Subject 
                        FROM EmailTemplate 
                        WHERE Name =: et[0].ET_Template_Name__c
                    ];
                    if (emailTemp.size() > 0) {
                        String emailIdStr = emailTemp[0].Id;
                        String contactIdStr = contactId;
                        String emailBody;
                        String subjectTxt;
                        if (lstOpp[0].O_Document_Communication__c == 'Agency' || lstOpp[0].O_Document_Communication__c == 'Agent') {
                            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(emailIdStr, null, selectedId);
                            emailBody = email.getHTMLBody();
                            subjectTxt = email.getSubject();
                        } else if (contactId != null) {
                            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(emailIdStr,contactIdStr,selectedId);
                            emailBody = email.getHTMLBody();
                            subjectTxt = email.getSubject();
                        }
                        String compileCSS = '';
            
                        for (CSS_Styler__c cssdata : [
                            SELECT Id, Email__c, Typography__c, Table__c, Button__c, Name, Email_Font_Family__c, Email_Font_Size__c, 
                                   Email_Font_Style__c, Email_Font_Color__c, CSS__c, CS_Button_JSON__c, Button_CSS__c, Is_Active__c, Backgroundcolor__c, 
                                   Font_Family__c, Font_Size__c, Font_Style__c, H1color__c, H2color__c, H3color__c, H4color__c, Header_Color__c, 
                                   Header_Font_size__c, Header_Font_Style__c, Hr_Background__c, Hr_Height__c, CS_Itinerary_Page_Marker__c, 
                                   CS_Travelling_Country_Marker__c, CS_Address_Marker__c 
                            FROM CSS_Styler__c 
                            WHERE Name = 'SendEmail' 
                            AND Is_Active__c = true
                        ]) {
                            compileCSS = 'style="';
                            if (cssdata.Email__c) {
                                if (cssdata.Email_Font_Family__c != null && cssdata.Email_Font_Family__c != '') {
                                    compileCSS += 'font-family: ' + cssdata.Email_Font_Family__c + ' !important;\n';
                                }
                                if (cssdata.Email_Font_Size__c != null && cssdata.Email_Font_Size__c != '') {
                                    compileCSS += 'font-size: ' + cssdata.Email_Font_Size__c + ' !important;\n';
                                }
                                if (cssdata.Email_Font_Style__c != null && cssdata.Email_Font_Style__c != '') {
                                    compileCSS += 'font-style: ' + cssdata.Email_Font_Style__c + ' !important;\n';
                                }
                                if (cssdata.Email_Font_Color__c != null && cssdata.Email_Font_Color__c != '') {
                                    compileCSS += 'color: ' + cssdata.Email_Font_Color__c + ' !important;\n';
                                }
                            }
                            compileCSS += '"';
                        }
                        
                        if (compileCSS != '') {
                            emailBody = '<div class="emailBody" '+compileCSS+'>'+emailBody+'</div>';
                        } else {
                            emailBody = '<div class="emailBody1" Style="font-family: arial,sans-serif;">'+emailBody+'</div>';
                        }
                        
                        //Get Body from Utility Class
                        String bodyStr = Utility.getEmailBody(templateName, lstOpp[0],et[0].ET_Template_Name__c);
                        if (et[0].ET_Email_Intro__c != null) {
                            emailBody = emailBody.replace('~intro~','<br/>'+et[0].ET_Email_Intro__c);
                        }
                        emailBody = emailBody.replace('~body~','<br/>'+bodyStr);
                        if (et[0].ET_Email_Closing__c != null) {
                            emailBody = emailBody.replace('~footer~','<br/>'+et[0].ET_Email_Closing__c);
                        }
                        Site__c site = Site__c.getInstance();
                        if (emailBody.indexOf('~OtherPDF~') != -1) {
                            String otherPdf = '';
                            for (Opportunity opp : [
                                SELECT Id, Name 
                                FROM Opportunity 
                                WHERE Id IN: selectedOpps
                            ]) {
                                otherPdf += '<a href="'+site.SiteURLAdmin__c+'/apex/'+Custom_Button_URL__c.getInstance().Itinerary_Pdf__c+'?id='+opp.id+'">'+opp.Name+'</a><br />';
                            }
                            emailBody = emailBody.replace('~OtherPDF~',otherPdf);
                        }
                        ew = new EmailWrapper(JSON.serialize(emailBody));
                        ew.selectedTemplateName = et[0].ET_Template_Name__c;
                        if (et[0].ET_Auto_Attchment_Documents__c != null) {
                            ew.selectedAttchment.addAll(et[0].ET_Auto_Attchment_Documents__c.split(';'));
                        }
                        ew.subject = subjectTxt;
                        String leadEmailContactName1 = genrateName(leadGM.GM_Contact__r.FirstName,leadGM.GM_Contact__r.LastName,leadGM.GM_Contact__r.Email);
                        PicklistValue leadEmailContact = new PicklistValue(leadGM.GM_Contact__r.Email,leadEmailContactName1);
                        
                        if (objName != 'Supplier_Cost_Payment__c') {
                            if (lstOpp[0].O_Document_Communication__c != 'Agency' &&  lstOpp[0].O_Document_Communication__c != 'Agent') {
                                String leadEmailContactName = genrateName(leadGM.GM_Contact__r.FirstName,leadGM.GM_Contact__r.LastName,leadGM.GM_Contact__r.Email);
                                leadEmailContact = new PicklistValue(leadGM.GM_Contact__r.Email,leadEmailContactName);   
                            } else {
                                if (lstOpp[0].O_Document_Communication__c == 'Agency' && lstOpp[0].O_Agent__r.S_Email__c != null) {
                                    String leadEmailContactName = genrateName(lstOpp[0].O_Agent__r.Name,'',lstOpp[0].O_Agent__r.S_Email__c);
                                    leadEmailContact = new PicklistValue(lstOpp[0].O_Agent__r.S_Email__c,leadEmailContactName );   
                                } else if (lstOpp[0].O_Document_Communication__c == 'Agent' && lstOpp[0].O_Agent_SC__r.SC_Email__c != null) {
                                    String leadEmailContactName = genrateName(lstOpp[0].O_Agent_SC__r.SC_First_Name__c,lstOpp[0].O_Agent_SC__r.SC_Last_Name__c,lstOpp[0].O_Agent_SC__r.SC_Email__c);
                                    leadEmailContact = new PicklistValue(lstOpp[0].O_Agent_SC__r.SC_Email__c,leadEmailContactName );   
                                }
                                String selectedSupplierId = lstOpp[0].O_Agent__c;
                                if(et[0].S_ET_Auto_CC_Supplier_Contacts__c == true) {
                                    for (Supplier_Contact__c sc : Database.query('SELECT Id, SC_Email__c, SC_First_Name__c, SC_Last_Name__c, Type__c FROM Supplier_Contact__c WHERE SC_Supplier__c =: selectedSupplierId AND SC_Email__c != null')) {                                    
                                        String pickname = getSupplierContactName(sc);
                                        ew.selectedCc.add(new PicklistValue(sc.SC_Email__c, pickname));
                                    }
                                }
                            }
                        }
                        
                        if (templateName.indexOf('SupplierPayments') == -1  && et[0].ET_Page_Section__c != 'SupplierPayments' && objName != 'Supplier_Booking__c' && objName != 'Supplier_Cost_Payment__c') {
                            if (objName != 'Supplier__c' && objName != Utility.getNamespacePrefix() + 'Supplier__c') {
                                ew.selectedTo.add(leadEmailContact);
                            }
                        }

                        if (objName == 'Supplier_Booking__c') {
                            Supplier_Booking__c supplierBooking;
                            List<Supplier_Booking__c> sbList = [
                                SELECT Id, SB_Supplier__c , SB_Supplier__r.S_Email__c, SB_Supplier__r.Name 
                                FROM Supplier_Booking__c 
                                WHERE Id =: selectedId
                            ];
                            if (!sbList.isEmpty()) {
                                supplierBooking = sbList[0];
                            }
                            
                            if (supplierBooking != null && supplierBooking.SB_Supplier__c != null && supplierBooking.SB_Supplier__r.S_Email__c != null) {
                                ew.selectedTo.add(new PicklistValue(supplierBooking.SB_Supplier__r.S_Email__c, supplierBooking.SB_Supplier__r.Name + '(' + supplierBooking.SB_Supplier__r.S_Email__c + ')'));
                            }

                            if (et[0].To_Address_Filter__c != null) {
                                String availableTypes = '';
                                for (String str : et[0].To_Address_Filter__c.split(';')) {
                                    availableTypes += '\''+String.escapeSingleQuotes(str)+'\',';
                                }
                                availableTypes = availableTypes.removeEnd(',');
                                String soql = 'SELECT Id, SC_Email__c, SC_First_Name__c, SC_Last_Name__c, Type__c FROM Supplier_Contact__c WHERE SC_Supplier__c = \'' + supplierBooking.SB_Supplier__c + '\' AND SC_Email__c != null AND Type__c INCLUDES (' + availableTypes + ')';
                                for (Supplier_Contact__c sc : Database.query(soql)) {
                                    String pickname = getSupplierContactName(sc);
                                    ew.selectedTo.add(new PicklistValue(sc.SC_Email__c,pickname));
                                }
                            }
                        }

                        if (et[0].ET_Template_Name__c.indexOf('Supplier') != -1 && et[0].To_Address_Filter__c != null && selectedId != null) { //For Supplier Email Templates
                            String availableTypes = '';
                            for (String str : et[0].To_Address_Filter__c.split(';')) {
                                availableTypes += '\''+String.escapeSingleQuotes(str)+'\',';
                            }
                            availableTypes = availableTypes.removeEnd(',');
                            if (objName == 'Supplier__c') { 
                                List<Supplier__c> supplierList = [
                                    SELECT Id, Name, S_Email__c 
                                    FROM Supplier__c 
                                    WHERE Id = :selectedId
                                ];
                                List<Supplier_Contact__c> scList = Database.query('SELECT Id, SC_Email__c, SC_First_Name__c, SC_Last_Name__c, Type__c FROM Supplier_Contact__c WHERE SC_Supplier__c =: selectedId AND SC_Email__c != null AND Type__c includes ('+availableTypes+')');
                                if (!scList.isEmpty()) {
                                    for (Supplier_Contact__c sc : scList) {
                                        String pickname = getSupplierContactName(sc);
                                        ew.selectedTo.add(new PicklistValue(sc.SC_Email__c,pickname));
                                    }
                                } else {
                                    if (String.isNotBlank(supplierList[0].S_Email__c)) {
                                        ew.selectedTo.add(new PicklistValue(supplierList[0].S_Email__c, supplierList[0].Name));
                                    }
                                }
                            }
                            if (objName == 'Supplier_Payment__c') {
                                List<Supplier_Payment__c> lstSP = [
                                    SELECT SP_Supplier__c, SBP_Supplier_Cost_Currency_Value__r.SCP_Supplier__r.Name, SBP_Supplier_Cost_Currency_Value__r.SCP_Supplier__r.S_Email__c 
                                    FROM Supplier_Payment__c 
                                    WHERE Id =:selectedId
                                ];
                                if (lstSP.size() > 0) {
                                    String selectedSupplierId = lstSP[0].SP_Supplier__c;
                                    List<Supplier_Contact__c> scList = Database.query('SELECT Id, SC_Email__c, SC_First_Name__c, SC_Last_Name__c, Type__c FROM Supplier_Contact__c WHERE SC_Supplier__c =: selectedSupplierId AND SC_Email__c != null AND Type__c includes ('+availableTypes+')');
                                    if (!scList.isEmpty()) {
                                        for (Supplier_Contact__c sc : scList) {
                                            String pickname = getSupplierContactName(sc);
                                            ew.selectedTo.add(new PicklistValue(sc.SC_Email__c,pickname) );
                                        }
                                    } else {
                                        if (String.isNotBlank(lstSP[0].SBP_Supplier_Cost_Currency_Value__r.SCP_Supplier__r.S_Email__c)) {
                                            ew.selectedTo.add(new PicklistValue(lstSP[0].SBP_Supplier_Cost_Currency_Value__r.SCP_Supplier__r.S_Email__c, lstSP[0].SBP_Supplier_Cost_Currency_Value__r.SCP_Supplier__r.Name));
                                        }
                                    }
                                }
                            }
                            if (objName == 'Supplier_Cost_Payment__c') {
                                List<Supplier_Cost_Payment__c> scpList = [
                                    SELECT Id, SCP_Supplier__c, SCP_Supplier__r.Name, SCP_Supplier__r.S_Email__c 
                                    FROM Supplier_Cost_Payment__c 
                                    WHERE Id = :selectedId
                                ];
                                if (!scpList.isEmpty()) {
                                    String selectedSupplierId = scpList[0].SCP_Supplier__c;
                                    List<Supplier_Contact__c> scList = Database.query('SELECT Id, SC_Email__c, SC_First_Name__c, SC_Last_Name__c, Type__c FROM Supplier_Contact__c WHERE SC_Supplier__c =: selectedSupplierId AND SC_Email__c != null AND Type__c includes ('+availableTypes+')');
                                    if (!scList.isEmpty()) {
                                        for (Supplier_Contact__c sc : scList) {
                                            String pickname = getSupplierContactName(sc);
                                            ew.selectedTo.add(new PicklistValue(sc.SC_Email__c,pickname) );
                                        }
                                    } else {
                                        if (String.isNotBlank(scpList[0].SCP_Supplier__r.S_Email__c)) {
                                            ew.selectedTo.add(new PicklistValue(scpList[0].SCP_Supplier__r.S_Email__c, scpList[0].SCP_Supplier__r.Name + ' (' + scpList[0].SCP_Supplier__r.S_Email__c + ')'));
                                        }
                                    }
                                }
                            }
                        }
                        ew.selectedBcc.add(new PicklistValue(UserInfo.getUserEmail(),UserInfo.getName()+' ('+UserInfo.getUserEmail()+')'));
                        if (ContactId != null) {
                            List<Contact> contactList = [
                                SELECT Id, Salutation, firstname, lastname, C_Middle_Name__c, C_Prefered_Name__c, Languages__c, HomePhone, MobilePhone, OtherPhone, 
                                       MailingCity, MailingStreet, MailingCountry, MailingPostalCode, Description, email, phone, Birthdate, Occupancy_Type__c, 
                                       C_Lead_Passenger__c, Adult__c, C_Child__c, C_Infant__c 
                                FROM Contact 
                                WHERE Id =: ContactId
                            ];
                            if (!contactList.isEmpty()) {
                                ew.leadpassenger = contactList[0];
                            }
                        }
                        if (et[0].ET_Related_To_Record__c == 'Opportunity' || et[0].ET_Related_To_Record__c == 'Client_Group__c') {
                            ew.opportunityStage = et[0].ET_Opportunity_Stage__c;
                        }else{
                            ew.opportunityStage = '';
                        }
                        return ew;
                    }
                }  
            }   
        } catch(Exception e) {
            System.assert(false,e.getMessage() + '       ' +e.getstacktraceString()+ '       ' +e.getLineNumber());
        }
        return null;
    }

    @remoteAction
    public static TemplateWrapper getFolderReports(String pageName, String oppID) {
        pageName = pageName.replaceAll(Utility.getNameSpacePrefix(),'');
        pageName = pageName.replaceAll('Legacy', '');
        Map<Id,String> emailTemplateMap = new Map<Id,String>();
        if (Utility.canAccessObj('Email_Template__c')) {
            List<Email_Template__c> et = [
                SELECT Id, ET_Opportunity_Stage__c, ET_Email_Closing__c, ET_Email_Intro__c, ET_Template_Name__c, ET_Related_To_Record__c 
                FROM Email_Template__c 
                WHERE ET_Page_Section__c =: pageName 
                AND ET_User__c =: UserInfo.getUserId()
            ];
            if (et.size() == 0 ) {
                et = [
                    SELECT Id, ET_Email_Closing__c, ET_Opportunity_Stage__c, ET_Email_Intro__c, ET_Template_Name__c, ET_Related_To_Record__c 
                    FROM Email_Template__c 
                    WHERE ET_Page_Section__c LIKE: '%' + pageName + '%' 
                    ORDER BY ET_Template_Name__c
                ];
            }
            if (pageName.indexOf('SendEmail') != -1) {
                et = [
                    SELECT Id, ET_Email_Closing__c, ET_Opportunity_Stage__c, ET_Email_Intro__c, ET_Template_Name__c, ET_Related_To_Record__c 
                    FROM Email_Template__c 
                    WHERE RecordType.DeveloperName = 'Email' 
                    ORDER BY ET_Template_Name__c
                ];
            }
            
            TemplateWrapper tw = new TemplateWrapper(oppID);
            tw.lstTemplate = et;
            for (Email_Template__c e: et ) {
                emailTemplateMap.put(e.Id,e.ET_Related_To_Record__c);
            }
            tw.mapEmailTemplate = emailTemplateMap;
            return tw;
        } else {
            return null;
        }
    }
    
    public Class TemplateWrapper{
        public List<Folder> lstFolder{get;set;}
        public List<Email_Template__c> lstTemplate{get;set;}
        public Map<String,List<PicklistValue>> mapRecords{get;set;}
        public Map<Id,String> mapEmailTemplate{get;set;}
        
        public TemplateWrapper(String OppID) {
            lstFolder = new List<Folder>();
            lstTemplate = new List<Email_Template__c>();
            mapRecords = new Map<String,List<PicklistValue>>();
            if (Utility.canAccessObj(new List<String>{
                'Opportunity', 
                'Account', 
                'Contact', 
                'Client_Payment__c', 
                'Client_Invoice__c', 
                'Supplier_Payment__c', 
                'Client_Group__c', 
                'Supplier_Booking__c', 
                'Supplier__c', 
                'Group_Member__c',
                'Supplier_Cost_Payment__c'
            })) {
                List<Opportunity> lstOpportunity = [
                    SELECT Id, AccountId, Name 
                    FROM Opportunity 
                    WHERE Id =: OppID
                ];
                if (lstOpportunity.size() > 0) {
                    for (Opportunity opp : lstOpportunity) {
                        if (!mapRecords.containsKey('Opportunity')) {
                            mapRecords.put('Opportunity', new List<PicklistValue>());
                        }
                        mapRecords.get('Opportunity').add(new PicklistValue(opp.Id, opp.Name));
                    }
                    for (Account acc : [
                        SELECT Id, Name 
                        FROM Account 
                        WHERE Id =: lstOpportunity[0].AccountId
                    ]) {
                        if (!mapRecords.containsKey('Account')) {
                            mapRecords.put('Account', new List<PicklistValue>());
                        }
                        mapRecords.get('Account').add(new PicklistValue(acc.Id, acc.Name));
                    }
                    for (Contact con : [
                        SELECT Id, Name 
                        FROM Contact 
                        WHERE AccountId =: lstOpportunity[0].AccountId
                    ]) {
                        if (!mapRecords.containsKey('Contact')) {
                            mapRecords.put('Contact', new List<PicklistValue>());
                        }
                        mapRecords.get('Contact').add(new PicklistValue(con.Id, con.Name));
                    }
                    for (Client_Payment__c cp : [
                        SELECT Id, Name 
                        FROM Client_Payment__c 
                        WHERE CP_Opportunity__c  =: lstOpportunity[0].Id
                    ]) {
                        if (!mapRecords.containsKey('Client_Payment__c')) {
                            mapRecords.put('Client_Payment__c', new List<PicklistValue>());
                        }
                        mapRecords.get('Client_Payment__c').add(new PicklistValue(cp.Id, cp.Name));
                    }
                    for (Client_Invoice__c ci : [
                        SELECT Id, Name 
                        FROM Client_Invoice__c 
                        WHERE I_Opportunity__c =: lstOpportunity[0].Id
                    ]) {
                        if (!mapRecords.containsKey('Client_Invoice__c')) {
                            mapRecords.put('Client_Invoice__c', new List<PicklistValue>());
                        }
                        mapRecords.get('Client_Invoice__c').add(new PicklistValue(ci.Id, ci.Name));
                    }
                    for (Supplier_Payment__c sp : [
                        SELECT Id, Name, SBP_Supplier_Cost_Currency_Value__r.SCP_Supplier__r.Name 
                        FROM Supplier_Payment__c 
                        WHERE SBP_Supplier_Cost_Currency_Value__r.SCP_Opportunity__c =: lstOpportunity[0].Id
                    ]) {
                        if (!mapRecords.containsKey('Supplier_Payment__c')) {
                            mapRecords.put('Supplier_Payment__c', new List<PicklistValue>());
                        }
                        mapRecords.get('Supplier_Payment__c').add(new PicklistValue(sp.Id, sp.Name +' - '+sp.SBP_Supplier_Cost_Currency_Value__r.SCP_Supplier__r.Name));
                    }
                    for (Client_Group__c cg: [
                        SELECT Id, Name 
                        FROM Client_Group__c 
                        WHERE CG_Opportunity__c =: lstOpportunity[0].Id
                    ]) {
                        if (!mapRecords.containsKey('Client_Group__c')) {
                            mapRecords.put('Client_Group__c', new List<PicklistValue>());
                        }
                        mapRecords.get('Client_Group__c').add(new PicklistValue(cg.Id, cg.Name));
                    }
                    for (Group_Member__c gm : [
                        SELECT Id, GM_Name__c 
                        FROM Group_Member__c 
                        WHERE GM_Opportunity__c =: lstOpportunity[0].Id
                    ]) {
                        if (!mapRecords.containsKey('Group_Member__c')) {
                            mapRecords.put('Group_Member__c', new List<PicklistValue>());
                        }
                        mapRecords.get('Group_Member__c').add(new PicklistValue(gm.id, gm.GM_Name__c));
                    }
                    for (Supplier_Booking__c sb : [
                        SELECT Id, Name, RecordType.Name, SB_Day__c, SB_Supplier__c, SB_Supplier__r.Name, SB_Booking_Status__c 
                        FROM Supplier_Booking__c 
                        WHERE SB_Opportunity__c =: lstOpportunity[0].Id
                    ]) {
                        if (!mapRecords.containsKey('Supplier_Booking__c')) {
                            mapRecords.put('Supplier_Booking__c', new List<PicklistValue>());
                        }
                        String picklistText = 'Day ' + sb.SB_Day__c + ' : ' + sb.RecordType.Name;
                        if (sb.SB_Supplier__c != null) {
                            picklistText += ' : ' + sb.SB_Supplier__r.Name;
                        }
                        if (sb.SB_Booking_Status__c != null) {
                            picklistText += ' : ' + sb.SB_Booking_Status__c;
                        }
                        mapRecords.get('Supplier_Booking__c').add(new PicklistValue(sb.Id, picklistText));
                    }
                    
                    Set<String> setOfSupplier = new Set<String>();
                    for (Supplier_Booking__c sb : [
                        SELECT Id, Name, SB_Supplier__c, SB_Supplier__r.Name 
                        FROM Supplier_Booking__c 
                        WHERE SB_Opportunity__c =: lstOpportunity[0].Id 
                        AND SB_Supplier__c != null
                    ]) {
                        if (!setOfSupplier.contains(sb.SB_Supplier__c)) {
                            if (!mapRecords.containsKey('Supplier__c')) {
                                mapRecords.put('Supplier__c', new List<PicklistValue>());
                            }
                            mapRecords.get('Supplier__c').add(new PicklistValue(sb.SB_Supplier__c, sb.SB_Supplier__r.Name));
                            setOfSupplier.add(sb.SB_Supplier__c);
                        }
                    }
                    setOfSupplier = new Set<String>();
                    List<Supplier_Cost_Payment__c> scpList = [
                        SELECT Id, Name, SCP_Supplier__c, SCP_Supplier__r.Name, 
                               (SELECT Id, SC_Supplier_Booking__r.SB_Show_In_Itinerary__c 
                                FROM Supplier_Costs__r) 
                        FROM Supplier_Cost_Payment__c 
                        WHERE SCP_Opportunity__c = :lstOpportunity[0].Id 
                        AND SCP_Supplier__c != null 
                        ORDER BY SCP_Supplier__r.Name ASC
                    ];
                    for (Supplier_Cost_Payment__c scp : scpList) {
                        if (!setOfSupplier.contains(scp.SCP_Supplier__c)) {
                            if (!mapRecords.containsKey('Supplier_Cost_Payment__c')) {
                                mapRecords.put('Supplier_Cost_Payment__c', new List<PicklistValue>());
                            }
                            mapRecords.get('Supplier_Cost_Payment__c').add(new PicklistValue(scp.Id, scp.SCP_Supplier__r.Name));
                            setOfSupplier.add(scp.SCP_Supplier__c);
                        }
                    }
                }
            }
        }
    }
    
    public Class EmailWrapper{
        public List<PicklistValue> selectedTo {get;set;}
        public List<PicklistValue> selectedCc {get;set;}
        public List<PicklistValue> selectedBcc {get;set;}
        public List<String> selectedAttchment {get;set;}
        public String subject {get;set;}
        public String emailBody {get;set;}
        public Contact leadpassenger {get;set;}
        public String selectedTemplateName {get;set;}
        public String opportunityStage {get;set;}
        public String followUpD {get;set;}
        public String followUpTime {get;set;}
        public String selectedFrom {get;set;}
        
        public EmailWrapper(String emailBody) {
            this.selectedTo = new List<PicklistValue>();    
            this.selectedCc = new List<PicklistValue>();    
            this.selectedBcc = new List<PicklistValue>();
            this.selectedAttchment = new List<String>();    
            this.subject = 'Recap Email';
            this.emailBody = emailBody;  
            this.opportunityStage = '';  
            this.selectedFrom = '';    
        }
    }
    
    @remoteAction
    public static List<PicklistValue> getFromAddress() {
        try{
            List<PicklistValue> mapEmail = new List<PicklistValue>();
            if (SugatiConstants__c.getInstance('SHOW_OWD_EMAIL_ON_SEND_EMAIL') == NULL || Boolean.valueOf( SugatiConstants__c.getInstance('SHOW_OWD_EMAIL_ON_SEND_EMAIL').Value__c )) { 
                // Can't do a CRUD check here as it will return false on OrgWideEmailAddress for community users
                for (OrgWideEmailAddress owa : [
                    SELECT Id, Address 
                    FROM OrgWideEmailAddress 
                    WHERE Id != null
                ]) {
                    mapEmail.add(new PicklistValue(owa.id,owa.Address));
                } 
            }
            return mapEmail;
        } catch(Exception e) {
            System.assert(false, 'Error - Line: ' + e.getLineNumber() + '<br/> Message : ' +e.getMessage());
            return new List<PicklistValue>();
        }
    }
    
    public Static  String getSupplierContactName(Supplier_Contact__c sc) {
        String name = '';
        if (sc.SC_First_Name__c != null && sc.SC_First_Name__c != '') {
            name += sc.SC_First_Name__c + ' ';
        }
        if (sc.SC_Last_Name__c!= null && sc.SC_Last_Name__c!= '') {
            name += sc.SC_Last_Name__c+ ' ';
        }
        if (name != '' && sc.Type__c != null && sc.Type__c != '') {
            name += + '- '+sc.Type__c + ' ';
        } else if (sc.Type__c != null && sc.Type__c != '') {
             name += sc.Type__c + ' ';
        }

        if (sc.SC_Email__c != null) {
             name += + '(' + sc.SC_Email__c + ')';
        }
        return name;
    }
    
    public Static String genrateName(String firstname, String lastname, String email) {
        String name = '';
        if (firstname!= null && firstname != '') {
            name += firstname + ' ';
        }
        if (lastname != null && lastname!= '') {
            name += lastname+ ' ';
        }      
        if (email != null) {
             name += +'('+email+')';
        }
        return name;
    }

    public class PicklistValue {
        public String value         {get;set;}
        public String label         {get;set;} 
        public String supplierId    {get;set;}
        public Boolean isSupplier   {get;set;}
        public Boolean bumpToTop    {get;set;}
        public List<String> supplierContactTypes {get;set;}
        
        public PicklistValue(String value, String label) {
            this.value = Utility.escapeHtml4( value );
            this.label = Utility.escapeHtml4( label );
            this.supplierId = '';
            this.isSupplier = false;
            this.bumpToTop = false;
            this.supplierContactTypes = new List<String>();
        }

        public PicklistValue(String value, String label, String supplierId) {
            this.value = Utility.escapeHtml4( value );
            this.label = Utility.escapeHtml4( label );
            this.supplierId = supplierId;
            this.isSupplier = false;
            this.bumpToTop = false;
            this.supplierContactTypes = new List<String>();
        }
    }
}