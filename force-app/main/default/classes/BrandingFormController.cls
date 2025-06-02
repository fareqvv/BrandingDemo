global with sharing class BrandingFormController {
    
    @AuraEnabled
    public static void sendToExternalApi(List<Id> fileIds, String color) {
        List<ContentVersion> versions = [SELECT Id, Title, VersionData, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :fileIds];

        List<Map<String, Object>> filesPayload = new List<Map<String, Object>>();
        for (ContentVersion cv : versions) {
            filesPayload.add(new Map<String, Object>{
                'fileName' => cv.Title,
                'base64Data' => EncodingUtil.base64Encode(cv.VersionData)
            });
        }

        BrandingRequest request = new BrandingRequest();
        request.color = color;
        request.files = filesPayload;
        request.senderOrg = UserInfo.getOrganizationId();

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:BrandingAPI/services/apexrest/createcase/');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(request));

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to call target org: ' + res.getBody());
        }
        ResponseBody response = (ResponseBody) JSON.deserialize(res.getBody(), ResponseBody.class);
        Branding__c setting = new Branding__c();
        setting.Name = response.caseId;
        setting.Case_Id__c = response.caseId;
        setting.Subject__c = response.subject;
        setting.Sender_Org__c = response.senderOrg;
        setting.Color__c = response.color;
        setting.Description__c = response.description;
        setting.Logo__c = response.links[0].ContentDocumentId;
        setting.Banner__c = response.links[1].ContentDocumentId;
        upsert setting;
    }

    @AuraEnabled
    public static CaseData fetchCase(String caseId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('BrandingAPI/services/apexrest/createcase/' + caseId);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to get case: ' + res.getBody());
        }

        return (CaseData) JSON.deserialize(res.getBody(), CaseData.class);
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
    }

    public class ResponseBody{
        public Id caseId;
        public String subject;
        public String senderOrg;
  		public String color;
        public String description;
        public List<ContentDocumentLink> links;
    }
}