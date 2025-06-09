global with sharing class BrandingFormController {
    
    @AuraEnabled
public static void sendToExternalApi(List<Id> fileIds, String color, Boolean forUpdate, Map<String, Object> fileType) {
    // --- Load JWT metadata config
    JWT_Config__mdt config = [
        SELECT Client_Id__c, Audience__c, User__c, Token_Endpoint__c, Endpoint__c
        FROM JWT_Config__mdt
        LIMIT 1
    ];

    JwtOAuth2Http.JWT_Config cfg = new JwtOAuth2Http.JWT_Config();
    cfg.clientId = config.Client_Id__c;
    cfg.username = config.User__c;
    cfg.audience = config.Audience__c;
    cfg.tokenEndpoint = config.Token_Endpoint__c;
    cfg.apiEndpoint = config.Endpoint__c;

    // --- Build file payload
    List<ContentVersion> versions = [SELECT Id, Title, VersionData, ContentDocumentId, FileExtension FROM ContentVersion WHERE ContentDocumentId IN :fileType.values()];
    Map<Id, String> idToTypeMap = new Map<Id, String>();
for (String typeKey : fileType.keySet()) {
    idToTypeMap.put(fileType.get(typeKey), typeKey);
}
    List<Map<String, Object>> filesPayload = new List<Map<String, Object>>();
    for (ContentVersion cv : versions) {
        String type = idToTypeMap.get(cv.ContentDocumentId);
        filesPayload.add(new Map<String, Object>{
            'fileName' => type + '_' + cv.Title + '.' + cv.FileExtension,
            'base64Data' => EncodingUtil.base64Encode(cv.VersionData)
        });
    }

    // --- Build branding request object
    String methodType = 'POST';
    BrandingRequest request = new BrandingRequest();
    request.color = color;
    request.files = filesPayload;
    request.senderOrg = UserInfo.getOrganizationId();

    if (forUpdate) {
        methodType = 'PATCH';
        request.caseId = [SELECT Case_Id__c FROM Branding_Setting__c ORDER BY Created_Date__c DESC LIMIT 1].Case_Id__c;
    }

    // --- Get access token via JWT
    String accessToken = JwtOAuth2Http.getAccessToken(cfg);

    // --- Prepare and send HTTP request
    String payload = JSON.serialize(request);
    HttpRequest req = JwtOAuth2Http.buildApiRequest(methodType, cfg.apiEndpoint, accessToken, payload);

    Http http = new Http();
    HttpResponse res = http.send(req);
    if (res.getStatusCode() != 200) {
        throw new CalloutException('Failed to call target org: ' + res.getBody());
    }

    // --- Deserialize response and update/insert settings
    ResponseBody response = (ResponseBody) JSON.deserialize(res.getBody(), ResponseBody.class);
    try {
        Branding_Setting__c setting = [
            SELECT Id 
            FROM Branding_Setting__c 
            WHERE Name = :response.caseId 
            LIMIT 1
        ];
        setting.Case_Id__c = response.caseId;
        setting.Color__c = response.color;
        if (response.contents != null && !response.contents.isEmpty()) {
            setting.Logo__c = response.contents[0].ContentDocumentId;
        }
        if (response.contents != null && response.contents.size() >= 2) {
            setting.Banner__c = response.contents[1].ContentDocumentId;
        }
        setting.Created_Date__c = System.now();
        update setting;
    } catch (QueryException qe) {
        Branding_Setting__c newSetting = new Branding_Setting__c();
        newSetting.Name = response.caseId;
        newSetting.Case_Id__c = response.caseId;
        newSetting.Color__c = response.color;
        if (response.contents != null && !response.contents.isEmpty()) {
            newSetting.Logo__c = response.contents[0].ContentDocumentId;
        }
        if (response.contents != null && response.contents.size() >= 2) {
            newSetting.Banner__c = response.contents[1].ContentDocumentId;
        }
        newSetting.Created_Date__c = System.now();
        insert newSetting;
    } catch (Exception ex) {
        System.debug('Unexpected error: ' + ex.getMessage());
    }
}


    @AuraEnabled
    public static CaseDataLWC fetchCase() {
        Branding_Setting__c setting = [
                                SELECT Case_Id__c, Color__c FROM Branding_Setting__c
                                ORDER BY Created_Date__c DESC
                                LIMIT 1
                              ];
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:BrandingAPI/services/apexrest/createcase/' + setting.Case_Id__c);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to get case: ' + res.getBody());
        }
        system.debug(res.getStatusCode());
        CaseData response = (CaseData) JSON.deserialize(res.getBody(), CaseData.class);
        CaseDataLWC  data = new CaseDataLWC();
        data.color = setting.Color__c;
        data.status = response.status;
        if(response.caseId == setting.Case_Id__c) {
            return data;
        }else{
            return null;
        }
    }

    public class CaseDataLWC {
        @AuraEnabled public String color;
        @AuraEnabled public String status;
    }

    public class CaseData {
        @AuraEnabled public String caseId;
        @AuraEnabled public String subject;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
    }

    public class BrandingRequest {
        public String color;
        public List<Object> files;
        public String senderOrg;
        public String caseId;
    }

    public class ResponseBody{
        public Id caseId;
        public String subject;
  		public String color;
        public List<ContentDocumentLink> contents;
    }
}