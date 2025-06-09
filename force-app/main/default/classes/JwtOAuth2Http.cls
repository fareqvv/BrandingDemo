public with sharing class JwtOAuth2Http {

    public class JWT_Config {
        public String clientId;
        public String audience;
        public String username;
        public String tokenEndpoint;
        public String apiEndpoint;
    }

    public static String getAccessToken(JWT_Config cfg) {
        Long now = DateTime.now().getTime();
        Long expiry = now + 300000;

        Map<String, Object> jwt = new Map<String, Object>{
            'iss' => cfg.clientId,
            'sub' => cfg.username,
            'aud' => cfg.audience,
            'exp' => expiry / 1000
        };

        String header = EncodingUtil.base64Encode(Blob.valueOf('{"alg":"RS256"}'));
        String body = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(jwt)));
        String signatureInput = header + '.' + body;

        Blob signature = Crypto.signWithCertificate('My_Integration_Cert', Blob.valueOf(signatureInput), Crypto.SIGNATURE_ALGORITHM_RSA_SHA256);
        String encodedSig = EncodingUtil.base64Encode(signature).replace('+', '-').replace('/', '_').replace('=', '');

        String jwtFull = signatureInput + '.' + encodedSig;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(cfg.tokenEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwtFull);

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('JWT Token request failed: ' + res.getBody());
        }

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) result.get('access_token');
    }

    public static HttpRequest buildApiRequest(String method, String endpoint, String accessToken, String jsonBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        return req;
    }
}
