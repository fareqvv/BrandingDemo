global with sharing class BrandingFormController {
    
    @AuraEnabled
    public static void sendToExternalApi(List<Id> fileIds, String color, Boolean forUpdate) {
        List<ContentVersion> versions = [SELECT Id, Title, VersionData, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :fileIds];
        List<Map<String, Object>> filesPayload = new List<Map<String, Object>>();
        for (ContentVersion cv : versions) {
            filesPayload.add(new Map<String, Object>{
                'fileName' => cv.Title,
                'base64Data' => EncodingUtil.base64Encode(cv.VersionData)
            });
        }
        String methodType = 'POST';
        BrandingRequest request = new BrandingRequest();
        request.color = color;
        request.files = filesPayload;
        request.senderOrg = UserInfo.getOrganizationId();
        if(forUpdate){
            methodType = 'PATCH';
            request.caseId = [SELECT Case_Id__c FROM Branding_Setting__c ORDER BY Created_Date__c DESC LIMIT 1].Case_Id__c;
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:BrandingAPI/services/apexrest/createcase/');
        req.setMethod(methodType);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(request));

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to call target org: ' + res.getBody());
        }
        ResponseBody response = (ResponseBody) JSON.deserialize(res.getBody(), ResponseBody.class);
        try{
            Branding_Setting__c setting = new Branding_Setting__c();
        if (setting == null) {
            setting = new Branding_Setting__c();
        }
        setting.Name = response.caseId;
        setting.Case_Id__c = response.caseId;
        setting.Subject__c = response.subject;
        setting.Color__c = response.color;
        setting.Description__c = response.description;
        setting.Logo__c = response.contents[0].ContentDocumentId;
        setting.Banner__c = response.contents[1].ContentDocumentId;
        setting.Created_Date__c = System.Now();
        upsert setting;}
        catch(Exception e){
            System.debug(e.getMessage());
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
        public String senderOrg;
  		public String color;
        public String description;
        public List<ContentDocumentLink> contents;
    }
}