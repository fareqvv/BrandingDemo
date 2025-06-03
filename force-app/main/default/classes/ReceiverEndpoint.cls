@RestResource(urlMapping='/createcase/*')
global with sharing class ReceiverEndpoint {
    @HttpPost
    global static void createCase() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);

        String color = (String) payload.get('color');
        String senderOrg = (String) payload.get('senderOrg');
        List<Object> files = (List<Object>) payload.get('files');

        Case c = new Case(Subject='Created via API', Description='Color: ' + color + '\nSenderOrg: ' + senderOrg, Origin = 'Email');
        insert c;

        List<ContentVersion> contentVersions = new List<ContentVersion>();
        for (Object fObj : files) {
            Map<String, Object> f = (Map<String, Object>) fObj;
            ContentVersion cv = new ContentVersion();
            cv.Title = (String) f.get('fileName');
            cv.PathOnClient = (String) f.get('fileName');
            cv.VersionData = EncodingUtil.base64Decode((String) f.get('base64Data'));
            contentVersions.add(cv);
        }
        insert contentVersions;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : contentVersions) {
            ContentDocument cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id LIMIT 1];
            links.add(new ContentDocumentLink(
                LinkedEntityId = c.Id,
                ContentDocumentId = cd.Id,
                ShareType = 'V'
            ));
        }
        insert links;
        ResponseBody responseBody = new ResponseBody();
        responseBody.caseId = c.Id;
        responseBody.subject = c.Subject;
        responseBody.contents = links;
        responseBody.color = color;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
    }
    
    @HttpPatch
	global static void updateCase() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
    
        String caseId = (String) payload.get('caseId');
        System.debug(caseId);
        if (caseId == null) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"error":"caseId is required"}');
            return;
        }
    
        Case c = [SELECT Id, Subject, Description FROM Case WHERE Id = :caseId LIMIT 1];
        if (c == null) {
            RestContext.response.statusCode = 404;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Case not found"}');
            return;
        }
    
        String color = (String) payload.get('color');
        String senderOrg = (String) payload.get('senderOrg');
        if (color != null || senderOrg != null) {
            c.Description = 'Color: ' + (color != null ? color : '') + '\nSenderOrg: ' + (senderOrg != null ? senderOrg : '');
            update c;
        }
    
        List<Object> files = (List<Object>) payload.get('files');
    
        if (files != null && !files.isEmpty()) {
            List<ContentVersion> contentVersions = new List<ContentVersion>();
            for (Object fObj : files) {
                Map<String, Object> f = (Map<String, Object>) fObj;
                ContentVersion cv = new ContentVersion();
                cv.Title = (String) f.get('fileName');
                cv.PathOnClient = (String) f.get('fileName');
                cv.VersionData = EncodingUtil.base64Decode((String) f.get('base64Data'));
                contentVersions.add(cv);
            }
            insert contentVersions;
    
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (ContentVersion cv : contentVersions) {
                ContentDocument cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id LIMIT 1];
                links.add(new ContentDocumentLink(
                    LinkedEntityId = c.Id,
                    ContentDocumentId = cd.Id,
                    ShareType = 'V'
                ));
            }
            insert links;
        }
    
        ResponseBody responseBody = new ResponseBody();
        responseBody.caseId = c.Id;
        responseBody.subject = c.Subject;
        responseBody.contents = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id];
        responseBody.color = color;
    
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
	}

    @HttpGet
    global static GetCaseResponse getCase() {
        RestRequest req = RestContext.request;
        String caseId = req.requestURI.substringAfterLast('/');

        List<Case> cases = [SELECT Id, Subject, Description, Status FROM Case WHERE Id = :caseId LIMIT 1];

        if (!cases.isEmpty()) {
            Case c = cases[0];
            return new GetCaseResponse(c.Id, c.Subject, c.Description, c.Status);
        } else {
            return null;
        }
    }

    global class GetCaseResponse {
        public String caseId;
        public String subject;
        public String description;
        public String status;

        public GetCaseResponse(String id, String subj, String des, String statValue) {
            caseId = id;
            subject = subj;
            description = des;
            status = statValue;
        }
    }
    public class ResponseBody{
        public Id caseId;
        public String subject;
  		public String color;
        public List<ContentDocumentLink> contents;
    }
}