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

        Map<String, Object> payload = new Map<String, Object>{
            'color' => color,
            'files' => filesPayload,
            'senderOrg' => UserInfo.getOrganizationId()
        };
        System.System.debug(UserInfo.getOrganizationId());
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:BrandingAPI/services/apexrest/createcase');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed to call target org: ' + res.getBody());
        }

        Branding__c ft = new Branding__c (Name = 'Case' + (String)payload.get('color') , Color__c = (String)payload.get('color'), Banner__c = (String)payload.get('files'));
        insert ft;
    }
    
}