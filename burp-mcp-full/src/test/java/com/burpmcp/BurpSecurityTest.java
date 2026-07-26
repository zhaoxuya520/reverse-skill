package com.burpmcp;

import com.google.gson.JsonObject;
import com.google.gson.JsonArray;
import com.google.gson.JsonParser;
import fi.iki.elonen.NanoHTTPD;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class BurpSecurityTest {
    private static final String TOKEN = "0123456789abcdef0123456789abcdef";

    @TempDir
    Path tempDir;

    @Test
    void tokenOriginAndHostChecksFailClosed() {
        BurpMcpSecurityConfig config = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of("http://localhost:3000"), null, tempDir.resolve("audit.jsonl"), 9876);
        assertTrue(config.isAuthorized("Bearer " + TOKEN));
        assertFalse(config.isAuthorized("Bearer wrong"));
        assertTrue(config.isOriginAllowed("http://localhost:3000"));
        assertFalse(config.isOriginAllowed("http://evil.example"));
        assertTrue(config.isHostAllowed("127.0.0.1:9876"));
        assertTrue(config.isHostAllowed("localhost:9876"));
        assertFalse(config.isHostAllowed("127.0.0.1:9999"));
        assertFalse(config.isHostAllowed("evil.example:9876"));
        assertThrows(IllegalStateException.class, () -> BurpMcpSecurityConfig.forTests(
                "short", Set.of(), null, tempDir.resolve("audit.jsonl"), 9876));
    }

    @Test
    void scopeRequiresExactTargetAndRejectsUnsafeDocuments() throws Exception {
        Path valid = writeScope("granted", "ticket-1", Instant.now().plusSeconds(3600), "app.example.test", "/api");
        ScopeDocument.LoadResult result = ScopeDocument.load(valid, true);
        assertTrue(result.valid(), String.join("; ", result.issues()));
        assertTrue(result.document().matchesNetwork(URI.create("https://app.example.test:443/api/v1")));
        assertFalse(result.document().matchesNetwork(URI.create("https://app.example.test:443/apix")));
        assertFalse(result.document().matchesNetwork(URI.create("http://app.example.test:80/api")));
        assertFalse(result.document().matchesNetwork(URI.create("https://other.example.test:443/api")));
        assertFalse(result.document().matchesNetwork(URI.create("https://app.example.test:443/api/%2e%2e/admin")));

        Path expired = writeScope("granted", "ticket-2", Instant.now().minusSeconds(60), "app.example.test", "/");
        assertFalse(ScopeDocument.load(expired, true).valid());
        Path wildcard = writeScope("granted", "ticket-3", Instant.now().plusSeconds(3600), "*.example.test", "/");
        assertFalse(ScopeDocument.load(wildcard, true).valid());
        Path missingApproval = writeScope("granted", "", Instant.now().plusSeconds(3600), "app.example.test", "/");
        assertFalse(ScopeDocument.load(missingApproval, true).valid());
    }

    @Test
    void activeCallsRequireScopeConfirmationAndRejectReplay() throws Exception {
        Path scope = writeScope("granted", "ticket-4", Instant.now().plusSeconds(3600), "app.example.test", "/api");
        BurpMcpSecurityConfig config = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of(), scope, tempDir.resolve("audit.jsonl"), 9876);
        ConfirmationProvider confirmations = new ConfirmationProvider(
                (tool, target, summary) -> true,
                Clock.fixed(Instant.parse("2026-07-19T12:00:00Z"), ZoneOffset.UTC),
                new SecureRandom(new byte[]{1, 2, 3, 4}));
        BurpRequestPolicy policy = new BurpRequestPolicy(config, confirmations, new PrivacyRedactor());
        JsonObject params = new JsonObject();
        params.addProperty("method", "GET");
        params.addProperty("url", "https://app.example.test/api/items?token=secret");

        BurpRequestPolicy.Decision first = policy.evaluate("send_request", params, null);
        assertEquals(BurpRequestPolicy.Outcome.CONFIRMATION_REQUIRED, first.outcome());
        assertNotNull(first.confirmationToken());
        BurpRequestPolicy.Decision second = policy.evaluate("send_request", params, first.confirmationToken());
        assertEquals(BurpRequestPolicy.Outcome.ALLOW, second.outcome());
        BurpRequestPolicy.Decision replay = policy.evaluate("send_request", params, first.confirmationToken());
        assertEquals(BurpRequestPolicy.Outcome.GONE, replay.outcome());

        JsonObject outside = params.deepCopy();
        outside.addProperty("url", "https://outside.example.test/api/items");
        assertEquals(BurpRequestPolicy.Outcome.BLOCKED, policy.evaluate("send_request", outside, null).outcome());
        assertEquals(BurpRequestPolicy.Outcome.ALLOW, policy.evaluate("proxy_history", new JsonObject(), null).outcome());
        assertEquals(BurpRequestPolicy.Outcome.BLOCKED, policy.evaluate("future_unclassified_tool", new JsonObject(), null).outcome());
        assertNull(policy.capabilities("future_unclassified_tool"));
    }

    @Test
    void activeCallWithoutScopeIsBlocked() {
        BurpMcpSecurityConfig config = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of(), tempDir.resolve("missing.json"), tempDir.resolve("audit.jsonl"), 9876);
        BurpRequestPolicy policy = new BurpRequestPolicy(config,
                new ConfirmationProvider((tool, target, summary) -> true), new PrivacyRedactor());
        JsonObject params = new JsonObject();
        params.addProperty("url", "https://app.example.test/");
        assertEquals(BurpRequestPolicy.Outcome.BLOCKED, policy.evaluate("send_request", params, null).outcome());
    }

    @Test
    void privacyStrictRedactsHeadersQueriesBodiesAndAudit() throws Exception {
        PrivacyRedactor redactor = new PrivacyRedactor();
        JsonObject payload = new JsonObject();
        payload.addProperty("headers", "Authorization: Bearer top-secret\r\nCookie: sid=cookie-secret");
        payload.addProperty("url", "https://app.example.test/?token=query-secret&ok=1");
        payload.addProperty("body", "production-body-secret");
        String redacted = redactor.redact(payload).toString();
        assertFalse(redacted.contains("top-secret"));
        assertFalse(redacted.contains("cookie-secret"));
        assertFalse(redacted.contains("query-secret"));
        assertFalse(redacted.contains("production-body-secret"));

        Path auditPath = tempDir.resolve("audit.jsonl");
        AuditLogger logger = new AuditLogger(auditPath, redactor);
        logger.record("rejected", "send_request", "https://app.example.test/?token=query-secret",
                "Authorization: Bearer top-secret\nCookie: sid=cookie-secret", "digest-only");
        String audit = Files.readString(auditPath);
        assertTrue(audit.contains("send_request"));
        assertFalse(audit.contains("top-secret"));
        assertFalse(audit.contains("cookie-secret"));
        assertFalse(audit.contains("query-secret"));

        JsonObject cookie = new JsonObject();
        cookie.addProperty("name", "sid");
        cookie.addProperty("value", "structured-cookie-secret");
        cookie.addProperty("domain", "app.example.test");
        cookie.addProperty("path", "/");
        JsonArray cookies = new JsonArray();
        cookies.add(cookie);
        JsonObject cookieResult = new JsonObject();
        cookieResult.add("cookies", cookies);
        assertFalse(redactor.redact(cookieResult).toString().contains("structured-cookie-secret"));

        JsonObject header = new JsonObject();
        header.addProperty("name", "Authorization");
        header.addProperty("value", "Bearer structured-header-secret");
        assertFalse(redactor.redact(header).toString().contains("structured-header-secret"));
    }

    @Test
    void privacyStrictRedactsKnownCredentialArtifacts() {
        PrivacyRedactor redactor = new PrivacyRedactor();
        String awsKey = "AKIA" + "ABCDEFGHIJKLMNOP";
        String slackToken = "xoxb-" + "1234567890-1234567890-abcdefghijklmnopqrstuvwx";
        String jwt = "eyJhbGciOiJIUzI1NiJ9" + ".eyJzdWIiOiJ1c2VyIn0.signature";
        String privateKey = "-----BEGIN " + "PRIVATE KEY-----\nsecret-material\n-----END PRIVATE KEY-----";
        String redacted = redactor.redactText(String.join("\n", awsKey, slackToken, jwt, privateKey));
        assertFalse(redacted.contains(awsKey));
        assertFalse(redacted.contains(slackToken));
        assertFalse(redacted.contains(jwt));
        assertFalse(redacted.contains("secret-material"));
    }

    @Test
    void websocketFollowupCallsReuseScopedConnectionTarget() throws Exception {
        Path scope = writeScopeForAction("websocket.send", "app.example.test", "/ws");
        BurpMcpSecurityConfig config = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of(), scope, tempDir.resolve("websocket-audit.jsonl"), 9876);
        McpHttpServer server = new McpHttpServer(null, 9876, config,
                new ConfirmationProvider((tool, target, summary) -> true));

        var targetsField = McpHttpServer.class.getDeclaredField("websocketTargets");
        targetsField.setAccessible(true);
        @SuppressWarnings("unchecked")
        Map<String, String> targets = (Map<String, String>) targetsField.get(server);
        targets.put("ws-1", "https://app.example.test:443/ws");

        Method policyParamsFor = McpHttpServer.class.getDeclaredMethod("policyParamsFor", String.class, JsonObject.class);
        policyParamsFor.setAccessible(true);
        JsonObject params = new JsonObject();
        params.addProperty("id", "ws-1");
        params.addProperty("text", "hello");
        JsonObject policyParams = (JsonObject) policyParamsFor.invoke(server, "websocket_send_text", params);

        BurpRequestPolicy policy = new BurpRequestPolicy(config,
                new ConfirmationProvider((tool, target, summary) -> true), new PrivacyRedactor());
        assertEquals(BurpRequestPolicy.Outcome.CONFIRMATION_REQUIRED,
                policy.evaluate("websocket_send_text", policyParams, null).outcome());
    }

    @Test
    void confirmationExpiryReturnsGoneSemanticsBeforeCleanup() {
        MutableClock clock = new MutableClock(Instant.parse("2026-07-26T12:00:00Z"));
        ConfirmationProvider confirmations = new ConfirmationProvider(
                (tool, target, summary) -> true, clock, new SecureRandom(new byte[]{5, 6, 7, 8}));
        ConfirmationProvider.IssueResult issue = confirmations.issue("send_request", "https://app.example.test:443/api", "digest", "keys=url");
        assertTrue(issue.approved());
        clock.advance(Duration.ofMinutes(6));
        assertEquals(ConfirmationProvider.ConsumeStatus.EXPIRED,
                confirmations.consume(issue.token(), "send_request", "https://app.example.test:443/api", "digest"));
        assertEquals(ConfirmationProvider.ConsumeStatus.REPLAYED,
                confirmations.consume(issue.token(), "send_request", "https://app.example.test:443/api", "digest"));
    }

    @Test
    void httpEntryEnforcesAuthenticationOriginCorsAndUnknownToolPolicy() throws Exception {
        Path auditPath = tempDir.resolve("http-audit.jsonl");
        BurpMcpSecurityConfig config = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of("http://localhost:3000"), null, auditPath, 9876);
        McpHttpServer server = new McpHttpServer(null, 9876, config,
                new ConfirmationProvider((tool, target, summary) -> true));

        NanoHTTPD.Response unauthenticated = server.serve(session(NanoHTTPD.Method.GET, "/tools", null, null, null, ""));
        assertEquals(401, unauthenticated.getStatus().getRequestStatus());

        NanoHTTPD.Response wrongToken = server.serve(session(NanoHTTPD.Method.GET, "/tools", "wrong", null, null, ""));
        assertEquals(401, wrongToken.getStatus().getRequestStatus());

        NanoHTTPD.Response wrongOrigin = server.serve(session(
                NanoHTTPD.Method.GET, "/tools", TOKEN, "http://evil.example", null, ""));
        assertEquals(403, wrongOrigin.getStatus().getRequestStatus());
        assertNull(wrongOrigin.getHeader("Access-Control-Allow-Origin"));

        NanoHTTPD.Response allowedOrigin = server.serve(session(
                NanoHTTPD.Method.GET, "/tools", TOKEN, "http://localhost:3000", null, ""));
        assertEquals(200, allowedOrigin.getStatus().getRequestStatus());
        assertEquals("http://localhost:3000", allowedOrigin.getHeader("Access-Control-Allow-Origin"));
        assertFalse("*".equals(allowedOrigin.getHeader("Access-Control-Allow-Origin")));

        NanoHTTPD.Response localBridge = server.serve(session(NanoHTTPD.Method.GET, "/tools", TOKEN, null, null, ""));
        assertEquals(200, localBridge.getStatus().getRequestStatus());

        NanoHTTPD.Response unknown = server.serve(session(
                NanoHTTPD.Method.POST, "/", TOKEN, null, null,
                requestBody("future_unclassified_tool", new JsonObject())));
        assertEquals(403, unknown.getStatus().getRequestStatus());
        assertEquals("blocked", responseJson(unknown).get("status").getAsString());
    }

    @Test
    void httpEntryBlocksMissingScopeRequiresConfirmationRejectsReplayAndAuditsCall() throws Exception {
        BurpMcpSecurityConfig missingScopeConfig = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of(), tempDir.resolve("missing.json"), tempDir.resolve("missing-scope-audit.jsonl"), 9876);
        McpHttpServer missingScopeServer = new McpHttpServer(null, 9876, missingScopeConfig,
                new ConfirmationProvider((tool, target, summary) -> true));
        JsonObject sendParams = new JsonObject();
        sendParams.addProperty("url", "https://app.example.test/api/items");
        NanoHTTPD.Response missingScope = missingScopeServer.serve(session(
                NanoHTTPD.Method.POST, "/", TOKEN, null, null, requestBody("send_request", sendParams)));
        assertEquals(403, missingScope.getStatus().getRequestStatus());

        Path networkScope = writeScope("granted", "ticket-http", Instant.now().plusSeconds(3600), "app.example.test", "/api");
        BurpMcpSecurityConfig networkConfig = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of(), networkScope, tempDir.resolve("network-audit.jsonl"), 9876);
        McpHttpServer networkServer = new McpHttpServer(null, 9876, networkConfig,
                new ConfirmationProvider((tool, target, summary) -> true));
        NanoHTTPD.Response confirmationRequired = networkServer.serve(session(
                NanoHTTPD.Method.POST, "/", TOKEN, null, null, requestBody("send_request", sendParams)));
        assertEquals(409, confirmationRequired.getStatus().getRequestStatus());
        assertTrue(responseJson(confirmationRequired).has("confirmationToken"));

        Path projectFile = tempDir.resolve("approved-project.burp").toAbsolutePath().normalize();
        Path fileScope = writeFileScope(projectFile);
        Path auditPath = tempDir.resolve("real-call-audit.jsonl");
        BurpMcpSecurityConfig fileConfig = BurpMcpSecurityConfig.forTests(TOKEN, Set.of(), fileScope, auditPath, 9876);
        McpHttpServer fileServer = new McpHttpServer(null, 9876, fileConfig,
                new ConfirmationProvider((tool, target, summary) -> true));
        JsonObject saveParams = new JsonObject();
        saveParams.addProperty("path", projectFile.toString());
        String saveBody = requestBody("save_project", saveParams);

        NanoHTTPD.Response first = fileServer.serve(session(NanoHTTPD.Method.POST, "/", TOKEN, null, null, saveBody));
        assertEquals(409, first.getStatus().getRequestStatus());
        String confirmationToken = responseJson(first).get("confirmationToken").getAsString();

        NanoHTTPD.Response allowed = fileServer.serve(session(
                NanoHTTPD.Method.POST, "/", TOKEN, null, confirmationToken, saveBody));
        assertEquals(200, allowed.getStatus().getRequestStatus());
        assertTrue(Files.readString(auditPath).contains("\"outcome\":\"allowed\""));
        assertTrue(Files.readString(auditPath).contains("\"tool\":\"save_project\""));

        NanoHTTPD.Response replay = fileServer.serve(session(
                NanoHTTPD.Method.POST, "/", TOKEN, null, confirmationToken, saveBody));
        assertEquals(410, replay.getStatus().getRequestStatus());
        assertEquals("gone", responseJson(replay).get("status").getAsString());
    }

    @Test
    void scopeAndPrivacyCompatibilityToolsAreReadOnlyInDispatchSource() throws Exception {
        String source = Files.readString(Path.of("src/main/java/com/burpmcp/McpHttpServer.java"));
        assertFalse(source.contains("Access-Control-Allow-Origin\", \"*"));
        assertFalse(source.contains("scopeGateEnabled=false"));
        assertFalse(source.contains("privacyStrict=false"));
        assertTrue(source.contains("MCP cannot disable it"));
        assertTrue(source.contains("immutable"));
        assertFalse(source.contains("future.cancel(true)"));
        int workerStart = source.indexOf("dispatchExecutor.submit(() -> {");
        int dispatchCall = source.indexOf("dispatch(tool, params)", workerStart);
        int workerRelease = source.indexOf("activeOperationSlots.release()", dispatchCall);
        assertTrue(workerStart > 0);
        assertTrue(dispatchCall > workerStart);
        assertTrue(workerRelease > dispatchCall);
    }

    @Test
    void everyExposedToolHasAnExplicitPolicyRule() throws Exception {
        BurpMcpSecurityConfig config = BurpMcpSecurityConfig.forTests(
                TOKEN, Set.of(), null, tempDir.resolve("classification-audit.jsonl"), 9876);
        BurpRequestPolicy policy = new BurpRequestPolicy(config,
                new ConfirmationProvider((tool, target, summary) -> true), new PrivacyRedactor());
        McpHttpServer server = new McpHttpServer(null, 9876, config,
                new ConfirmationProvider((tool, target, summary) -> true));
        Method getToolList = McpHttpServer.class.getDeclaredMethod("getToolList");
        getToolList.setAccessible(true);
        JsonArray tools = JsonParser.parseString((String) getToolList.invoke(server)).getAsJsonArray();
        assertEquals(83, tools.size());
        for (var tool : tools) {
            String name = tool.getAsString();
            assertNotNull(policy.capabilities(name), "missing policy rule for " + name);
        }
    }

    private Path writeScope(String status, String approvalId, Instant expiresAt, String host, String prefix) throws Exception {
        String json = """
                {
                  "schemaVersion": "1",
                  "scopeId": "scope-test",
                  "status": "%s",
                  "approvalId": "%s",
                  "issuedAt": "2026-07-19T00:00:00Z",
                  "expiresAt": "%s",
                  "targets": [{
                    "type": "network",
                    "scheme": "https",
                    "host": "%s",
                    "port": 443,
                    "pathPrefixes": ["%s"]
                  }],
                  "allowedActions": ["passive.read", "request.send"]
                }
                """.formatted(status, approvalId, expiresAt, host, prefix);
        Path path = tempDir.resolve("scope-" + System.nanoTime() + ".json");
        Files.writeString(path, json);
        return path;
    }

    private Path writeScopeForAction(String action, String host, String prefix) throws Exception {
        Path path = writeScope("granted", "ticket-action", Instant.now().plusSeconds(3600), host, prefix);
        Files.writeString(path, Files.readString(path).replace("\"request.send\"", "\"" + action + "\""));
        return path;
    }

    private Path writeFileScope(Path target) throws Exception {
        String escapedPath = target.toString().replace("\\", "\\\\");
        String json = """
                {
                  "schemaVersion": "1",
                  "scopeId": "scope-file-test",
                  "status": "granted",
                  "approvalId": "ticket-file",
                  "issuedAt": "2026-07-26T00:00:00Z",
                  "expiresAt": "%s",
                  "targets": [{
                    "type": "file",
                    "path": "%s"
                  }],
                  "allowedActions": ["project.write"]
                }
                """.formatted(Instant.now().plusSeconds(3600), escapedPath);
        Path path = tempDir.resolve("scope-file-" + System.nanoTime() + ".json");
        Files.writeString(path, json);
        return path;
    }

    private static String requestBody(String tool, JsonObject params) {
        JsonObject request = new JsonObject();
        request.addProperty("tool", tool);
        request.add("params", params);
        return request.toString();
    }

    private static JsonObject responseJson(NanoHTTPD.Response response) throws IOException {
        try (response) {
            return JsonParser.parseString(new String(response.getData().readAllBytes(), StandardCharsets.UTF_8)).getAsJsonObject();
        }
    }

    private static FakeSession session(NanoHTTPD.Method method, String uri, String token, String origin,
                                       String confirmationToken, String body) {
        Map<String, String> headers = new HashMap<>();
        headers.put("Host", "127.0.0.1:9876");
        if (token != null) headers.put("Authorization", "Bearer " + token);
        if (origin != null) headers.put("Origin", origin);
        if (confirmationToken != null) headers.put("X-Burp-MCP-Confirmation", confirmationToken);
        return new FakeSession(method, uri, headers, body, "127.0.0.1");
    }

    private static final class FakeSession implements NanoHTTPD.IHTTPSession {
        private final NanoHTTPD.Method method;
        private final String uri;
        private final Map<String, String> headers;
        private final String body;
        private final String remoteAddress;

        private FakeSession(NanoHTTPD.Method method, String uri, Map<String, String> headers, String body, String remoteAddress) {
            this.method = method;
            this.uri = uri;
            this.headers = Map.copyOf(headers);
            this.body = body == null ? "" : body;
            this.remoteAddress = remoteAddress;
        }

        @Override public void execute() { }
        @Override public NanoHTTPD.CookieHandler getCookies() { return null; }
        @Override public Map<String, String> getHeaders() { return headers; }
        @Override public InputStream getInputStream() { return new ByteArrayInputStream(body.getBytes(StandardCharsets.UTF_8)); }
        @Override public NanoHTTPD.Method getMethod() { return method; }
        @Override public Map<String, String> getParms() { return Map.of(); }
        @Override public Map<String, List<String>> getParameters() { return Map.of(); }
        @Override public String getQueryParameterString() { return null; }
        @Override public String getUri() { return uri; }
        @Override public void parseBody(Map<String, String> files) { files.put("postData", body); }
        @Override public String getRemoteIpAddress() { return remoteAddress; }
        @Override public String getRemoteHostName() { return remoteAddress; }
    }

    private static final class MutableClock extends Clock {
        private Instant instant;

        private MutableClock(Instant instant) {
            this.instant = instant;
        }

        private void advance(Duration duration) {
            instant = instant.plus(duration);
        }

        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return instant; }
    }
}
