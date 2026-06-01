public with sharing class ClientTemplateScriptsController {
    
    public List<Email_Template_Script_Setting__mdt> lstTemplateScriptSettings { get; set; }
    
    public ClientTemplateScriptsController() {
        lstTemplateScriptSettings = new List<Email_Template_Script_Setting__mdt>();
        if (Utility.canAccessObj('Email_Template_Script_Setting__mdt')) {
            lstTemplateScriptSettings = [
                SELECT 
                    Label, 
                    DeveloperName, 
                    Substitute_Term__c, 
                    Static_Resource_URL__c, 
                    Callback_Function_Name__c, 
                    Apex_Class_Name__c,
                    On_Send_Email_Function_Name__c
                 FROM 
                     Email_Template_Script_Setting__mdt 
                 WHERE 
                     Active__c = True 
             ];
        }
    } 
    
    public String getClientTemplateScriptSettings() {
        return JSON.serialize( lstTemplateScriptSettings );
    }
    
    public String getNamespace() {
        return Utility.getNameSpacePrefix().remove('__');
    }

    
    @RemoteAction 
    public static String getTemplateContentDetails( String myClassName, String paramJSON ) {
        String namespacePrefix = '';
        Map<String, String> params = (Map<String, String>) JSON.deserialize( paramJSON, Map<String, String>.class );
        SugatiCustomScript cs;
        Type myType = Type.forName(namespacePrefix, myClassName );  // Instantiate the class 
        
        if ( null != myType ) {
            
            try {
                cs = (SugatiCustomScript) myType.newInstance();
                return cs.getTemplateContentDetails( params );
            } catch( Exception e ) {
                System.debug( e.getLineNumber() + ':' + e.getMessage() );
                if(!Test.isRunningTest()) {
                    System.assert(false, e.getLineNumber() + ' : ' + e.getMessage() );
                }
            }
            
        }
        return 'Unable to instantiate ' + myClassName;
    }
    
    @RemoteAction 
    public static String onSendEmailAction( String myClassName, String paramJSON ) {
        String namespacePrefix = '';
        Map<String, String> params = (Map<String, String>) JSON.deserialize( paramJSON, Map<String, String>.class );
        SugatiCustomScriptV1 cs;
        
        Type myType = Type.forName(namespacePrefix, myClassName );  // Instantiate the class 
        
        if ( null != myType ) {
            
            try {
                cs = (SugatiCustomScriptV1) myType.newInstance();
                return cs.onSendEmailAction( params );
            } catch( Exception e ) {
                System.debug( e.getLineNumber() + ':' + e.getMessage() );
                if(!Test.isRunningTest()) {
                    System.assert(false, e.getLineNumber() + ' : ' + e.getMessage() );
                }
            }
            
        }
        return 'Unable to instantiate ' + myClassName;
    }
}