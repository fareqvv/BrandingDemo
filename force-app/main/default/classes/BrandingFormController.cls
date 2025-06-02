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
        req.setEndpoint('callout:BrandingAPI/services/apexrest/createcase');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(request));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to call target org: ' + res.getBody());
        }
    }
    public class BrandingRequest {
        public String color;
        public List<Object> files;
        public String senderOrg;
    }
}