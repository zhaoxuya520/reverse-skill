package com.burpmcp;

import burp.api.montoya.MontoyaApi;
import burp.api.montoya.collaborator.*;
import burp.api.montoya.core.Registration;
import burp.api.montoya.http.HttpService;
import burp.api.montoya.http.message.HttpRequestResponse;
import burp.api.montoya.http.message.requests.HttpRequest;
import burp.api.montoya.http.message.responses.HttpResponse;
import burp.api.montoya.proxy.ProxyHttpRequestResponse;
import burp.api.montoya.proxy.ProxyWebSocketMessage;
import burp.api.montoya.proxy.http.*;
import burp.api.montoya.scanner.AuditConfiguration;
import burp.api.montoya.scanner.BuiltInAuditConfiguration;
import burp.api.montoya.scanner.Crawl;
import burp.api.montoya.scanner.CrawlConfiguration;
import burp.api.montoya.scanner.audit.Audit;
import burp.api.montoya.scanner.audit.issues.AuditIssue;
import burp.api.montoya.scanner.audit.issues.AuditIssueConfidence;
import burp.api.montoya.scanner.audit.issues.AuditIssueSeverity;
import burp.api.montoya.sitemap.SiteMapFilter;
import com.google.gson.*;
import fi.iki.elonen.NanoHTTPD;

import java.io.IOException;
import burp.api.montoya.core.ByteArray;
import burp.api.montoya.http.sessions.*;
import burp.api.montoya.websocket.extension.ExtensionWebSocket;
import java.time.ZonedDateTime;
import java.nio.charset.StandardCharsets;
import java.net.InetAddress;
import java.net.URI;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.stream.Collectors;

public class McpHttpServer extends NanoHTTPD {
    private final MontoyaApi api;
    private final Gson gson = new GsonBuilder().setPrettyPrinting().create();
    private CollaboratorClient collaborator;
    private volatile Audit activeAudit = null;
    private volatile Crawl activeCrawl = null;
    private final BurpMcpSecurityConfig securityConfig;
    private final PrivacyRedactor privacyRedactor;
    private final ConfirmationProvider confirmationProvider;
    private final BurpRequestPolicy requestPolicy;
    private final AuditLogger auditLogger;
    private final Semaphore activeOperationSlots = new Semaphore(BurpMcpSecurityConfig.MAX_ACTIVE_OPERATIONS);
    private final ExecutorService dispatchExecutor = Executors.newFixedThreadPool(4, runnable -> {
        Thread thread = new Thread(runnable, "burp-mcp-dispatch");
        thread.setDaemon(true);
        return thread;
    });

    public McpHttpServer(MontoyaApi api, int port) {
        this(api, port, BurpMcpSecurityConfig.load(port), ConfirmationProvider.swing());
    }

    McpHttpServer(MontoyaApi api, int port, BurpMcpSecurityConfig securityConfig, ConfirmationProvider confirmationProvider) {
        super("127.0.0.1", port);
        this.api = api;
        this.securityConfig = securityConfig;
        this.privacyRedactor = new PrivacyRedactor();
        this.confirmationProvider = confirmationProvider;
        this.requestPolicy = new BurpRequestPolicy(securityConfig, confirmationProvider, privacyRedactor);
        this.auditLogger = new AuditLogger(securityConfig.auditLog(), privacyRedactor);
    }

    @Override
    public Response serve(IHTTPSession session) {
        String origin = header(session, "Origin");
        if (!hostAllowed(session)) return jsonResponse(Response.Status.BAD_REQUEST, error("blocked", "invalid local Host header"), origin);
        if (origin != null && !securityConfig.isOriginAllowed(origin)) return jsonResponse(Response.Status.FORBIDDEN, error("blocked", "Origin is not allowlisted"), null);
        if (origin == null && !loopback(session.getRemoteIpAddress())) return jsonResponse(Response.Status.FORBIDDEN, error("blocked", "non-local requests require an allowlisted Origin"), null);
        if (Method.OPTIONS.equals(session.getMethod())) {
            Response response = newFixedLengthResponse(Response.Status.OK, "text/plain", "");
            addCorsHeaders(response, origin);
            return response;
        }
        if (!securityConfig.isAuthorized(header(session, "Authorization"))) {
            auditLogger.record("rejected", "", "", "authentication failed", "");
            return jsonResponse(Response.Status.UNAUTHORIZED, error("unauthorized", "Bearer token required"), origin);
        }
        if (Method.GET.equals(session.getMethod()) && "/health".equals(session.getUri())) {
            JsonObject health = new JsonObject();
            health.addProperty("status", "ok");
            health.addProperty("version", version());
            health.add("tools", JsonParser.parseString(getToolList()));
            return jsonResponse(Response.Status.OK, health, origin);
        }
        if (Method.GET.equals(session.getMethod()) && "/tools".equals(session.getUri())) {
            return jsonResponse(Response.Status.OK, JsonParser.parseString(getToolList()), origin);
        }
        if (!Method.POST.equals(session.getMethod())) return jsonResponse(Response.Status.METHOD_NOT_ALLOWED, error("method_not_allowed", "POST only"), origin);
        String contentLength = header(session, "Content-Length");
        if (contentLength != null) {
            try {
                if (Long.parseLong(contentLength) > BurpMcpSecurityConfig.MAX_REQUEST_BODY_BYTES) {
                    return jsonResponse(HTTP_PAYLOAD_TOO_LARGE, error("blocked", "request body is too large"), origin);
                }
            } catch (NumberFormatException exception) {
                return jsonResponse(Response.Status.BAD_REQUEST, error("bad_request", "invalid Content-Length"), origin);
            }
        }
        try {
            Map<String, String> bodyMap = new HashMap<>();
            session.parseBody(bodyMap);
            String body = bodyMap.getOrDefault("postData", "");
            if (body.getBytes(StandardCharsets.UTF_8).length > BurpMcpSecurityConfig.MAX_REQUEST_BODY_BYTES) {
                return jsonResponse(HTTP_PAYLOAD_TOO_LARGE, error("blocked", "request body is too large"), origin);
            }
            JsonObject request = JsonParser.parseString(body).getAsJsonObject();
            String tool = request.has("tool") && request.get("tool").isJsonPrimitive() ? request.get("tool").getAsString() : "";
            JsonObject params = request.has("params") && request.get("params").isJsonObject()
                    ? request.getAsJsonObject("params").deepCopy() : new JsonObject();
            String confirmationToken = firstNonBlank(header(session, "X-Burp-MCP-Confirmation"),
                    params.has("_confirmationToken") ? params.get("_confirmationToken").getAsString() : null);
            params.remove("_confirmationToken");
            params.remove("confirmationToken");
            JsonObject policyParams = policyParamsFor(tool, params);
            BurpRequestPolicy.Decision decision = requestPolicy.evaluate(tool, policyParams, confirmationToken);
            if (decision.outcome() != BurpRequestPolicy.Outcome.ALLOW) {
                auditLogger.record("rejected", tool, decision.target(), decision.reason(), decision.parameterDigest());
                return policyResponse(decision, origin);
            }
            boolean acquired = !decision.active() || activeOperationSlots.tryAcquire();
            if (!acquired) {
                auditLogger.record("rejected", tool, decision.target(), "active operation concurrency limit", decision.parameterDigest());
                return jsonResponse(HTTP_TOO_MANY_REQUESTS, error("blocked", "too many active operations"), origin);
            }
            Future<JsonObject> future;
            try {
                future = dispatchExecutor.submit(() -> {
                    try {
                        JsonObject result = dispatch(tool, params);
                        auditLogger.record("allowed", tool, decision.target(), "tool call", decision.parameterDigest());
                        return result;
                    } catch (RuntimeException exception) {
                        auditLogger.record("error", tool, decision.target(), "tool call failed", decision.parameterDigest());
                        throw exception;
                    } finally {
                        if (decision.active()) activeOperationSlots.release();
                    }
                });
            } catch (RuntimeException exception) {
                if (decision.active()) activeOperationSlots.release();
                throw exception;
            }
            try {
                JsonObject result = future.get(BurpMcpSecurityConfig.REQUEST_TIMEOUT_SECONDS, TimeUnit.SECONDS);
                return jsonResponse(Response.Status.OK, privacyRedactor.redact(result).getAsJsonObject(), origin);
            } catch (TimeoutException timeout) {
                auditLogger.record("error", tool, decision.target(), "request timeout", decision.parameterDigest());
                return jsonResponse(Response.Status.REQUEST_TIMEOUT, error("timeout", "tool execution timed out"), origin);
            }
        } catch (Exception exception) {
            auditLogger.record("error", "", "", "request handling failed", "");
            return jsonResponse(Response.Status.INTERNAL_ERROR, error("internal_error", privacyRedactor.redactText(exception.getMessage())), origin);
        }
    }

    private static final Response.IStatus HTTP_PAYLOAD_TOO_LARGE = new NumericStatus(413, "Payload Too Large");
    private static final Response.IStatus HTTP_TOO_MANY_REQUESTS = new NumericStatus(429, "Too Many Requests");
    private static final Response.IStatus HTTP_GONE = new NumericStatus(410, "Gone");

    private Response policyResponse(BurpRequestPolicy.Decision decision, String origin) {
        JsonObject result = new JsonObject();
        result.addProperty("status", decision.outcome() == BurpRequestPolicy.Outcome.CONFIRMATION_REQUIRED
                ? "confirmation_required" : decision.outcome() == BurpRequestPolicy.Outcome.GONE ? "gone" : "blocked");
        result.addProperty("reason", privacyRedactor.redactText(decision.reason()));
        result.addProperty("action", decision.action());
        if (decision.target() != null && !decision.target().isBlank()) result.addProperty("target", privacyRedactor.redactTarget(decision.target()));
        if (decision.confirmationToken() != null) {
            result.addProperty("confirmationToken", decision.confirmationToken());
            result.addProperty("expiresInSeconds", 300);
        }
        Response.IStatus status = decision.outcome() == BurpRequestPolicy.Outcome.CONFIRMATION_REQUIRED
                ? Response.Status.CONFLICT : decision.outcome() == BurpRequestPolicy.Outcome.GONE ? HTTP_GONE : Response.Status.FORBIDDEN;
        return jsonResponse(status, result, origin);
    }

    private Response jsonResponse(Response.IStatus status, JsonElement payload, String origin) {
        Response response = newFixedLengthResponse(status, "application/json", gson.toJson(payload));
        addCorsHeaders(response, origin);
        return response;
    }

    private static JsonObject error(String status, String message) {
        JsonObject result = new JsonObject();
        result.addProperty("status", status);
        result.addProperty("error", message == null ? "" : message);
        return result;
    }

    private boolean hostAllowed(IHTTPSession session) {
        return securityConfig.isHostAllowed(header(session, "Host"));
    }

    private static String header(IHTTPSession session, String name) {
        if (session == null || session.getHeaders() == null) return null;
        for (Map.Entry<String, String> entry : session.getHeaders().entrySet()) {
            if (entry.getKey() != null && entry.getKey().equalsIgnoreCase(name)) return entry.getValue();
        }
        return null;
    }

    private static boolean loopback(String address) {
        if (address == null || address.isBlank()) return false;
        try {
            return InetAddress.getByName(address).isLoopbackAddress();
        } catch (Exception exception) {
            return false;
        }
    }

    private static String firstNonBlank(String first, String second) {
        if (first != null && !first.isBlank()) return first;
        return second == null || second.isBlank() ? null : second;
    }

    private JsonObject policyParamsFor(String tool, JsonObject params) {
        JsonObject policyParams = params == null ? new JsonObject() : params.deepCopy();
        if (!("websocket_send_text".equals(tool) || "websocket_send_binary".equals(tool) || "websocket_close".equals(tool))) {
            return policyParams;
        }
        if (!policyParams.has("id") || !policyParams.get("id").isJsonPrimitive()) return policyParams;
        String target = websocketTargets.get(policyParams.get("id").getAsString());
        if (target != null && !target.isBlank()) policyParams.addProperty("target", target);
        return policyParams;
    }

    private static String version() {
        String value = McpHttpServer.class.getPackage().getImplementationVersion();
        return value == null || value.isBlank() ? "1.1.0-rc.1" : value;
    }

    private static final class NumericStatus implements Response.IStatus {
        private final int status;
        private final String description;

        private NumericStatus(int status, String description) {
            this.status = status;
            this.description = description;
        }

        @Override
        public String getDescription() { return status + " " + description; }

        @Override
        public int getRequestStatus() { return status; }
    }

    private JsonObject dispatch(String tool, JsonObject params) {
        switch (tool) {
            case "proxy_history": return proxyHistory(params);
            case "proxy_detail": return proxyDetail(params);
            case "proxy_websocket": return proxyWebSocket(params);
            case "proxy_listeners": return proxyListeners(params);
            case "proxy_match_replace": return proxyMatchReplace(params);
            case "proxy_clear": return proxyClear(params);
            case "send_request": return sendRequest(params);
            case "send_to_repeater": return sendToRepeater(params);
            case "repeater_send": return repeaterSend(params);
            case "repeater_modify_send": return repeaterModifySend(params);
            case "send_to_intruder": return sendToIntruder(params);
            case "intruder_attack": return intruderAttack(params);
            case "intruder_attack_async": return intruderAttackAsync(params);
            case "intruder_attack_wordlist": return intruderAttackWordlist(params);
            case "intruder_pitchfork": return intruderPitchfork(params);
            case "intruder_cluster_bomb": return intruderClusterBomb(params);
            case "intruder_battering_ram": return intruderBatteringRam(params);
            case "intruder_with_options": return intruderWithOptions(params);
            case "sitemap": return getSitemap(params);
            case "target_info": return targetInfo(params);
            case "intercept_toggle": return interceptToggle(params);
            case "intercept_modify": return interceptModify(params);
            case "encode": return encode(params);
            case "decode": return decode(params);
            case "convert_request": return convertRequest(params);
            case "export_request": return exportRequest(params);
            case "generate_csrf_poc": return generateCsrfPoc(params);
            case "extract_from_response": return extractFromResponse(params);
            case "scan": return scan(params);
            case "scan_active": return scanActive(params);
            case "scan_results": return scanResults(params);
            case "scan_issue_detail": return scanIssueDetail(params);
            case "crawl": return crawl(params);
            case "get_scope": return getScope(params);
            case "add_to_scope": return addToScope(params);
            case "remove_from_scope": return removeFromScope(params);
            case "collaborator_generate": return collaboratorGenerate(params);
            case "collaborator_poll": return collaboratorPoll(params);
            case "search_history": return searchHistory(params);
            case "highlight": return highlightItem(params);
            case "annotate": return annotate(params);
            case "compare": return compare(params);
            case "export_config": return exportConfig(params);
            case "import_config": return importConfig(params);
            case "set_upstream_proxy": return setUpstreamProxy(params);
            case "set_dns_override": return setDnsOverride(params);
            case "set_http2": return setHttp2(params);
            case "cookie_jar": return cookieJar(params);
            case "token_analysis": return tokenAnalysis(params);
            case "sequencer": return sequencer(params);
            case "export_cert": return exportCert(params);
            case "websocket_send": return websocketSend(params);
            case "payload_process": return payloadProcess(params);
            case "save_project": return saveProject(params);
            case "burp_version": return burpVersion(params);
            case "add_issue": return addIssue(params);
            case "proxy_history_filtered": return proxyHistoryFiltered(params);
            case "register_http_handler": return registerHttpHandler(params);
            case "remove_http_handler": return removeHttpHandler(params);
            case "register_proxy_rule": return registerProxyRule(params);
            case "remove_proxy_rule": return removeProxyRule(params);
            case "extensions_list": return extensionsList(params);
            case "log": return logMessage(params);
            case "cookie_jar_set": return cookieJarSet(params);
            case "send_request_parallel": return sendRequestParallel(params);
            case "websocket_create": return websocketCreate(params);
            case "websocket_send_text": return websocketSendText(params);
            case "websocket_send_binary": return websocketSendBinary(params);
            case "websocket_close": return websocketClose(params);
            case "websocket_list": return websocketList(params);
            case "passive_intel": return passiveIntel(params);
            case "session_create_rule": return sessionCreateRule(params);
            case "session_list_rules": return sessionListRules(params);
            case "session_remove_rule": return sessionRemoveRule(params);
            case "jwt_decode": return jwtDecode(params);
            case "jwt_attack": return jwtAttack(params);
            case "injection_probe": return injectionProbe(params);
            case "access_control_sweep": return accessControlSweep(params);
            case "race_condition": return raceCondition(params);
            case "inline_fuzzer": return inlineFuzzer(params);
            case "scope_gate": return scopeGate(params);
            case "privacy_mode": return privacyMode(params);
            case "audit_log": return auditLog(params);
            default:
                JsonObject err = new JsonObject();
                err.addProperty("error", "Unknown tool: " + tool);
                err.add("available_tools", JsonParser.parseString(getToolList()));
                return err;
        }
    }

    private JsonObject proxyHistory(JsonObject params) {
        JsonObject result = new JsonObject();
        List<ProxyHttpRequestResponse> history = api.proxy().history();
        int limit = params.has("limit") ? params.get("limit").getAsInt() : 100;
        int offset = params.has("offset") ? params.get("offset").getAsInt() : 0;
        String filterUrl = params.has("url_filter") ? params.get("url_filter").getAsString() : null;
        String filterMethod = params.has("method_filter") ? params.get("method_filter").getAsString() : null;
        int filterStatus = params.has("status_filter") ? params.get("status_filter").getAsInt() : 0;

        List<ProxyHttpRequestResponse> filtered = new ArrayList<>(history);
        if (filterUrl != null) {
            filtered = filtered.stream().filter(r -> r.finalRequest().url().contains(filterUrl)).collect(Collectors.toList());
        }
        if (filterMethod != null) {
            filtered = filtered.stream().filter(r -> r.finalRequest().method().equalsIgnoreCase(filterMethod)).collect(Collectors.toList());
        }
        if (filterStatus > 0) {
            filtered = filtered.stream().filter(r -> r.response() != null && r.response().statusCode() == filterStatus).collect(Collectors.toList());
        }
        Collections.reverse(filtered);
        int end = Math.min(offset + limit, filtered.size());
        JsonArray items = new JsonArray();
        for (int i = offset; i < end; i++) {
            ProxyHttpRequestResponse entry = filtered.get(i);
            JsonObject item = new JsonObject();
            item.addProperty("index", i);
            item.addProperty("method", entry.finalRequest().method());
            item.addProperty("url", entry.finalRequest().url());
            item.addProperty("status", entry.response() != null ? entry.response().statusCode() : 0);
            item.addProperty("length", entry.response() != null ? entry.response().body().length() : 0);
            items.add(item);
        }
        result.addProperty("total", filtered.size());
        result.add("items", items);
        return result;
    }

    private JsonObject sendRequest(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            String url = params.get("url").getAsString();
            String body = params.has("body") ? params.get("body").getAsString() : "";
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();

            URI uri = new URI(url);
            String host = uri.getHost();
            int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
            String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : "");
            boolean isHttps = uri.getScheme().equals("https");

            StringBuilder rawReq = new StringBuilder();
            rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\n");
            rawReq.append("Host: ").append(host).append("\r\n");
            for (Map.Entry<String, JsonElement> entry : headers.entrySet()) {
                rawReq.append(entry.getKey()).append(": ").append(entry.getValue().getAsString()).append("\r\n");
            }
            if (!body.isEmpty()) {
                rawReq.append("Content-Length: ").append(body.length()).append("\r\n\r\n").append(body);
            } else {
                rawReq.append("\r\n");
            }

            HttpService service = HttpService.httpService(host, port, isHttps);
            HttpRequest request = HttpRequest.httpRequest(service, rawReq.toString());
            HttpResponse response = api.http().sendRequest(request).response();

            result.addProperty("status", response.statusCode());
            result.addProperty("length", response.body().length());
            String respBody = response.bodyToString();
            if (respBody.length() > 10000) respBody = respBody.substring(0, 10000) + "...[truncated]";
            result.addProperty("body", respBody);
            JsonObject respHeaders = new JsonObject();
            response.headers().forEach(h -> respHeaders.addProperty(h.name(), h.value()));
            result.add("headers", respHeaders);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject sendToRepeater(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String rawRequest = params.get("request").getAsString();
            String tabName = params.has("tab_name") ? params.get("tab_name").getAsString() : "MCP";
            HttpRequest request = buildRequestWithService(rawRequest);
            api.repeater().sendToRepeater(request, tabName);
            result.addProperty("success", true);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject sendToIntruder(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String rawRequest = params.get("request").getAsString();
            HttpRequest request = buildRequestWithService(rawRequest);
            api.intruder().sendToIntruder(request);
            result.addProperty("success", true);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    // Build an HttpRequest with an attached HttpService derived from the Host header.
    // Required by Intruder (and safer for Repeater) — HttpRequest.httpRequest(raw) alone
    // leaves the service null and Intruder rejects it with "HttpRequest must have an HttpService".
    private HttpRequest buildRequestWithService(String rawRequest) {
        java.util.regex.Matcher m = java.util.regex.Pattern.compile(
                "(?im)^Host:\\s*([^:\r\n]+)(?::(\\d+))?\\s*$").matcher(rawRequest);
        if (!m.find()) {
            // No Host header — fall back to the no-service overload (Repeater tolerates it).
            return HttpRequest.httpRequest(rawRequest);
        }
        String host = m.group(1).trim();
        boolean isHttps = rawRequest.contains("https://") || rawRequest.contains(":443");
        int port = m.group(2) != null ? Integer.parseInt(m.group(2))
                  : (isHttps ? 443 : 80);
        HttpService svc = HttpService.httpService(host, port, isHttps);
        return HttpRequest.httpRequest(svc, rawRequest);
    }

    private JsonObject intruderAttack(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlTemplate = params.get("url_template").getAsString();
            String placeholder = params.has("placeholder") ? params.get("placeholder").getAsString() : "@@";
            int from = params.has("from") ? params.get("from").getAsInt() : 0;
            int to = params.has("to") ? params.get("to").getAsInt() : 100;
            int padDigits = params.has("pad_digits") ? params.get("pad_digits").getAsInt() : 0;
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            String bodyTemplate = params.has("body_template") ? params.get("body_template").getAsString() : "";
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();
            int successLengthNot = params.has("success_length_not") ? params.get("success_length_not").getAsInt() : -1;
            String successContains = params.has("success_contains") ? params.get("success_contains").getAsString() : null;

            JsonArray hits = new JsonArray();
            int count = 0, errors = 0;

            for (int i = from; i <= to; i++) {
                String payload = padDigits > 0 ? String.format("%0" + padDigits + "d", i) : String.valueOf(i);
                String url = urlTemplate.replace(placeholder, payload);
                String body = bodyTemplate.replace(placeholder, payload);
                try {
                    URI uri = new URI(url);
                    String host = uri.getHost();
                    int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
                    String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : "");
                    boolean isHttps = uri.getScheme().equals("https");
                    StringBuilder rawReq = new StringBuilder();
                    rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\n");
                    rawReq.append("Host: ").append(host).append("\r\n");
                    for (Map.Entry<String, JsonElement> e : headers.entrySet())
                        rawReq.append(e.getKey()).append(": ").append(e.getValue().getAsString()).append("\r\n");
                    if (!body.isEmpty()) rawReq.append("Content-Length: ").append(body.length()).append("\r\n\r\n").append(body);
                    else rawReq.append("\r\n");
                    HttpService svc = HttpService.httpService(host, port, isHttps);
                    HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(svc, rawReq.toString())).response();
                    count++;
                    boolean isHit = false;
                    if (successLengthNot > 0 && resp.body().length() != successLengthNot) isHit = true;
                    if (successContains != null && resp.bodyToString().contains(successContains)) isHit = true;
                    if (isHit) {
                        JsonObject hit = new JsonObject();
                        hit.addProperty("payload", payload); hit.addProperty("status", resp.statusCode());
                        hit.addProperty("length", resp.body().length());
                        hit.addProperty("body_preview", resp.bodyToString().substring(0, Math.min(300, resp.bodyToString().length())));
                        hits.add(hit);
                    }
                } catch (Exception e) { errors++; }
            }
            result.addProperty("total_requests", count); result.addProperty("errors", errors);
            result.addProperty("hits", hits.size()); result.add("hit_details", hits);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject intruderAttackAsync(JsonObject params) {
        // Multi-threaded version for high-speed attacks
        JsonObject result = new JsonObject();
        try {
            String urlTemplate = params.get("url_template").getAsString();
            String placeholder = params.has("placeholder") ? params.get("placeholder").getAsString() : "@@";
            int from = params.has("from") ? params.get("from").getAsInt() : 0;
            int to = params.has("to") ? params.get("to").getAsInt() : 100;
            int padDigits = params.has("pad_digits") ? params.get("pad_digits").getAsInt() : 0;
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            String bodyTemplate = params.has("body_template") ? params.get("body_template").getAsString() : "";
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();
            int successLengthNot = params.has("success_length_not") ? params.get("success_length_not").getAsInt() : -1;
            int threads = params.has("threads") ? params.get("threads").getAsInt() : 50;

            ExecutorService executor = Executors.newFixedThreadPool(threads);
            ConcurrentLinkedQueue<JsonObject> hits = new ConcurrentLinkedQueue<>();
            AtomicInteger count = new AtomicInteger(0);
            AtomicInteger errors = new AtomicInteger(0);
            AtomicBoolean found = new AtomicBoolean(false);

            List<Future<?>> futures = new ArrayList<>();
            for (int i = from; i <= to; i++) {
                final int idx = i;
                futures.add(executor.submit(() -> {
                    if (found.get()) return;
                    String payload = padDigits > 0 ? String.format("%0" + padDigits + "d", idx) : String.valueOf(idx);
                    String url = urlTemplate.replace(placeholder, payload);
                    String body = bodyTemplate.replace(placeholder, payload);
                    try {
                        URI uri = new URI(url);
                        String host = uri.getHost();
                        int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
                        String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : "");
                        boolean isHttps = uri.getScheme().equals("https");
                        StringBuilder rawReq = new StringBuilder();
                        rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\n");
                        rawReq.append("Host: ").append(host).append("\r\n");
                        for (Map.Entry<String, JsonElement> e : headers.entrySet())
                            rawReq.append(e.getKey()).append(": ").append(e.getValue().getAsString()).append("\r\n");
                        if (!body.isEmpty()) rawReq.append("Content-Length: ").append(body.length()).append("\r\n\r\n").append(body);
                        else rawReq.append("\r\n");
                        HttpService svc = HttpService.httpService(host, port, isHttps);
                        HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(svc, rawReq.toString())).response();
                        count.incrementAndGet();
                        if (successLengthNot > 0 && resp.body().length() != successLengthNot) {
                            JsonObject hit = new JsonObject();
                            hit.addProperty("payload", payload); hit.addProperty("length", resp.body().length());
                            hit.addProperty("body_preview", resp.bodyToString().substring(0, Math.min(300, resp.bodyToString().length())));
                            hits.add(hit); found.set(true);
                        }
                    } catch (Exception e) { errors.incrementAndGet(); }
                }));
            }
            for (Future<?> f : futures) { try { f.get(120, TimeUnit.SECONDS); } catch (Exception e) {} }
            executor.shutdownNow();

            result.addProperty("total_requests", count.get()); result.addProperty("errors", errors.get());
            result.addProperty("hits", hits.size());
            JsonArray hitArr = new JsonArray(); hits.forEach(hitArr::add);
            result.add("hit_details", hitArr);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject getSitemap(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlPrefix = params.has("url_prefix") ? params.get("url_prefix").getAsString() : "";
            int limit = params.has("limit") ? params.get("limit").getAsInt() : 50;
            var entries = api.siteMap().requestResponses(SiteMapFilter.prefixFilter(urlPrefix));
            JsonArray items = new JsonArray(); int c = 0;
            for (var entry : entries) {
                if (c >= limit) break;
                JsonObject item = new JsonObject();
                item.addProperty("url", entry.request().url());
                item.addProperty("method", entry.request().method());
                item.addProperty("status", entry.response() != null ? entry.response().statusCode() : 0);
                items.add(item); c++;
            }
            result.addProperty("total", c); result.add("items", items);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject interceptToggle(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            boolean enable = params.has("enable") ? params.get("enable").getAsBoolean() : true;
            if (enable) api.proxy().enableIntercept(); else api.proxy().disableIntercept();
            result.addProperty("success", true); result.addProperty("intercept_enabled", enable);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject interceptModify(JsonObject params) {
        JsonObject result = new JsonObject();
        result.addProperty("info", "Use intercept_toggle to enable intercept. Modify requests via proxy_history + send_request workflow.");
        return result;
    }

    private JsonObject encode(JsonObject params) {
        JsonObject result = new JsonObject();
        String input = params.get("input").getAsString();
        String type = params.has("type") ? params.get("type").getAsString() : "base64";
        switch (type) {
            case "base64": result.addProperty("output", Base64.getEncoder().encodeToString(input.getBytes())); break;
            case "url": try { result.addProperty("output", java.net.URLEncoder.encode(input, "UTF-8")); } catch (Exception e) { result.addProperty("error", e.getMessage()); } break;
            case "hex": StringBuilder hex = new StringBuilder(); for (byte b : input.getBytes()) hex.append(String.format("%02x", b)); result.addProperty("output", hex.toString()); break;
            default: result.addProperty("error", "Types: base64, url, hex");
        }
        return result;
    }

    private JsonObject decode(JsonObject params) {
        JsonObject result = new JsonObject();
        String input = params.get("input").getAsString();
        String type = params.has("type") ? params.get("type").getAsString() : "base64";
        switch (type) {
            case "base64": result.addProperty("output", new String(Base64.getDecoder().decode(input))); break;
            case "url": try { result.addProperty("output", java.net.URLDecoder.decode(input, "UTF-8")); } catch (Exception e) { result.addProperty("error", e.getMessage()); } break;
            default: result.addProperty("error", "Types: base64, url");
        }
        return result;
    }

    private JsonObject scan(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String url = params.has("url") ? params.get("url").getAsString() : "";
            String mode = params.has("mode") ? params.get("mode").getAsString().toLowerCase() : "active";
            boolean active = !"passive".equals(mode);

            if (url.isEmpty()) { result.addProperty("error", "url is required"); return result; }
            api.scope().includeInScope(url);

            AuditConfiguration cfg = AuditConfiguration.auditConfiguration(
                    active ? BuiltInAuditConfiguration.LEGACY_ACTIVE_AUDIT_CHECKS
                           : BuiltInAuditConfiguration.LEGACY_PASSIVE_AUDIT_CHECKS);
            activeAudit = api.scanner().startAudit(cfg);

            // Seed the audit with a GET request to the URL. Without this the audit
            // has no target and request_count stays 0 — AuditConfiguration accepts
            // no seed URL, so we must feed it explicitly (mirrors scan_active).
            java.net.URL u = new java.net.URL(url);
            String host = u.getHost();
            boolean isHttps = "https".equalsIgnoreCase(u.getProtocol());
            int port = u.getPort() > 0 ? u.getPort() : (isHttps ? 443 : 80);
            String path = (u.getPath() == null || u.getPath().isEmpty()) ? "/" : u.getPath();
            String pathQuery = u.getQuery() != null ? path + "?" + u.getQuery() : path;
            HttpService svc = HttpService.httpService(host, port, isHttps);
            HttpRequest seedReq = HttpRequest.httpRequest(svc,
                    "GET " + pathQuery + " HTTP/1.1\r\nHost: " + host + "\r\nConnection: close\r\n\r\n");
            activeAudit.addRequest(seedReq);

            result.addProperty("success", true);
            result.addProperty("mode", active ? "active" : "passive");
            result.addProperty("url", url);
            result.addProperty("message", "Audit started and seeded with GET request. Use scan_results to retrieve issues. Active scan requires Burp Professional.");
            result.addProperty("note", "Audit runs asynchronously in Burp; issues surface via scan_results / Site map once complete.");
        } catch (Exception e) {
            String msg = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
            if (msg.toLowerCase().contains("professional") || msg.toLowerCase().contains("community") || msg.toLowerCase().contains("license")) {
                result.addProperty("error", "Active/passive audit requires Burp Professional. Detected: " + msg);
            } else {
                result.addProperty("error", msg);
            }
        }
        return result;
    }

    private JsonObject getScope(JsonObject params) {
        JsonObject result = new JsonObject();
        String url = params.has("url") ? params.get("url").getAsString() : "https://example.com";
        boolean inScope = api.scope().isInScope(url);
        result.addProperty("url", url); result.addProperty("in_scope", inScope);
        return result;
    }

    private JsonObject addToScope(JsonObject params) {
        JsonObject result = new JsonObject();
        try { String url = params.get("url").getAsString(); api.scope().includeInScope(url); result.addProperty("success", true); }
        catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject removeFromScope(JsonObject params) {
        JsonObject result = new JsonObject();
        try { String url = params.get("url").getAsString(); api.scope().excludeFromScope(url); result.addProperty("success", true); }
        catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject collaboratorGenerate(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            if (collaborator == null) collaborator = api.collaborator().createClient();
            int count = params.has("count") ? params.get("count").getAsInt() : 1;
            JsonArray payloads = new JsonArray();
            for (int i = 0; i < count; i++) {
                String payload = collaborator.generatePayload().toString();
                payloads.add(payload);
            }
            result.add("payloads", payloads);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject collaboratorPoll(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            if (collaborator == null) { result.addProperty("error", "No collaborator client. Call collaborator_generate first."); return result; }
            var interactions = collaborator.getAllInteractions();
            JsonArray items = new JsonArray();
            for (var interaction : interactions) {
                JsonObject item = new JsonObject();
                item.addProperty("type", interaction.type().name());
                item.addProperty("client_ip", interaction.clientIp().toString());
                item.addProperty("timestamp", interaction.timeStamp().toString());
                items.add(item);
            }
            result.addProperty("count", items.size()); result.add("interactions", items);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject searchHistory(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String regex = params.has("regex") ? params.get("regex").getAsString() : ".*";
            String searchIn = params.has("search_in") ? params.get("search_in").getAsString() : "url";
            int limit = params.has("limit") ? params.get("limit").getAsInt() : 20;
            java.util.regex.Pattern pattern = java.util.regex.Pattern.compile(regex, java.util.regex.Pattern.CASE_INSENSITIVE);
            List<ProxyHttpRequestResponse> history = api.proxy().history();
            JsonArray items = new JsonArray(); int c = 0;
            for (int i = history.size() - 1; i >= 0 && c < limit; i--) {
                ProxyHttpRequestResponse entry = history.get(i);
                boolean match = false;
                if ("url".equals(searchIn)) match = pattern.matcher(entry.finalRequest().url()).find();
                else if ("request".equals(searchIn)) match = pattern.matcher(entry.finalRequest().toString()).find();
                else if ("response".equals(searchIn) && entry.response() != null) match = pattern.matcher(entry.response().toString()).find();
                if (match) {
                    JsonObject item = new JsonObject();
                    item.addProperty("index", i);
                    item.addProperty("method", entry.finalRequest().method());
                    item.addProperty("url", entry.finalRequest().url());
                    item.addProperty("status", entry.response() != null ? entry.response().statusCode() : 0);
                    items.add(item); c++;
                }
            }
            result.addProperty("matches", c); result.add("items", items);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject proxyDetail(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            int index = params.get("index").getAsInt();
            List<ProxyHttpRequestResponse> history = api.proxy().history();
            if (index < 0 || index >= history.size()) { result.addProperty("error", "Index out of range"); return result; }
            ProxyHttpRequestResponse entry = history.get(index);
            result.addProperty("method", entry.finalRequest().method());
            result.addProperty("url", entry.finalRequest().url());
            result.addProperty("request", entry.finalRequest().toString());
            if (entry.response() != null) {
                String resp = entry.response().toString();
                if (resp.length() > 50000) resp = resp.substring(0, 50000) + "...[truncated]";
                result.addProperty("response", resp);
                result.addProperty("status", entry.response().statusCode());
                result.addProperty("response_length", entry.response().body().length());
            }
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject proxyWebSocket(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            var wsHistory = api.proxy().webSocketHistory();
            int limit = params.has("limit") ? params.get("limit").getAsInt() : 50;
            JsonArray items = new JsonArray(); int c = 0;
            for (var msg : wsHistory) {
                if (c >= limit) break;
                JsonObject item = new JsonObject();
                item.addProperty("direction", msg.direction().name());
                item.addProperty("payload", msg.payload().toString().substring(0, Math.min(500, msg.payload().toString().length())));
                items.add(item); c++;
            }
            result.addProperty("total", c); result.add("messages", items);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject intruderAttackWordlist(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlTemplate = params.get("url_template").getAsString();
            String placeholder = params.has("placeholder") ? params.get("placeholder").getAsString() : "@@";
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            JsonArray wordlist = params.getAsJsonArray("wordlist");
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();
            int successLengthNot = params.has("success_length_not") ? params.get("success_length_not").getAsInt() : -1;
            String bodyTemplate = params.has("body_template") ? params.get("body_template").getAsString() : "";

            JsonArray hits = new JsonArray(); int count = 0, errors = 0;
            for (JsonElement word : wordlist) {
                String payload = word.getAsString();
                String url = urlTemplate.replace(placeholder, payload);
                String body = bodyTemplate.replace(placeholder, payload);
                try {
                    URI uri = new URI(url);
                    String host = uri.getHost();
                    int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
                    String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : "");
                    boolean isHttps = uri.getScheme().equals("https");
                    StringBuilder rawReq = new StringBuilder();
                    rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\n");
                    rawReq.append("Host: ").append(host).append("\r\n");
                    for (Map.Entry<String, JsonElement> e : headers.entrySet())
                        rawReq.append(e.getKey()).append(": ").append(e.getValue().getAsString()).append("\r\n");
                    if (!body.isEmpty()) rawReq.append("Content-Length: ").append(body.length()).append("\r\n\r\n").append(body);
                    else rawReq.append("\r\n");
                    HttpService svc = HttpService.httpService(host, port, isHttps);
                    HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(svc, rawReq.toString())).response();
                    count++;
                    boolean isHit = false;
                    if (successLengthNot > 0 && resp.body().length() != successLengthNot) isHit = true;
                    if (isHit) {
                        JsonObject hit = new JsonObject();
                        hit.addProperty("payload", payload); hit.addProperty("status", resp.statusCode());
                        hit.addProperty("length", resp.body().length());
                        hits.add(hit);
                    }
                } catch (Exception e) { errors++; }
            }
            result.addProperty("total_requests", count); result.addProperty("errors", errors);
            result.addProperty("hits", hits.size()); result.add("hit_details", hits);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject scanResults(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            var issues = api.siteMap().issues();
            int limit = params.has("limit") ? params.get("limit").getAsInt() : 50;
            JsonArray items = new JsonArray(); int c = 0;
            for (var issue : issues) {
                if (c >= limit) break;
                JsonObject item = new JsonObject();
                item.addProperty("name", issue.name());
                item.addProperty("severity", issue.severity().name());
                item.addProperty("confidence", issue.confidence().name());
                item.addProperty("url", issue.baseUrl());
                item.addProperty("detail", issue.detail() != null ? issue.detail().substring(0, Math.min(200, issue.detail().length())) : "");
                items.add(item); c++;
            }
            result.addProperty("total", c); result.add("issues", items);

            if (activeAudit != null) {
                JsonObject auditStatus = new JsonObject();
                try {
                    auditStatus.addProperty("request_count", activeAudit.requestCount());
                    auditStatus.addProperty("error_count", activeAudit.errorCount());
                    auditStatus.addProperty("insertion_point_count", activeAudit.insertionPointCount());
                    auditStatus.addProperty("status_message", activeAudit.statusMessage());
                    var auditIssues = activeAudit.issues();
                    auditStatus.addProperty("audit_issue_count", auditIssues.size());
                } catch (Exception ignored) {}
                result.add("active_audit", auditStatus);
            }
            if (activeCrawl != null) {
                JsonObject crawlStatus = new JsonObject();
                try {
                    crawlStatus.addProperty("request_count", activeCrawl.requestCount());
                    crawlStatus.addProperty("error_count", activeCrawl.errorCount());
                } catch (Exception ignored) {}
                result.add("active_crawl", crawlStatus);
            }
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject highlightItem(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            int index = params.get("index").getAsInt();
            String color = params.has("color") ? params.get("color").getAsString() : "red";
            List<ProxyHttpRequestResponse> history = api.proxy().history();
            if (index >= 0 && index < history.size()) {
                var entry = history.get(index);
                var highlight = burp.api.montoya.core.HighlightColor.highlightColor(color);
                entry.annotations().setHighlightColor(highlight);
                result.addProperty("success", true);
            } else { result.addProperty("error", "Index out of range"); }
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject annotate(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            int index = params.get("index").getAsInt();
            String note = params.get("note").getAsString();
            List<ProxyHttpRequestResponse> history = api.proxy().history();
            if (index >= 0 && index < history.size()) {
                history.get(index).annotations().setNotes(note);
                result.addProperty("success", true);
            } else { result.addProperty("error", "Index out of range"); }
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject compare(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            int idx1 = params.get("index1").getAsInt();
            int idx2 = params.get("index2").getAsInt();
            List<ProxyHttpRequestResponse> history = api.proxy().history();
            String resp1 = history.get(idx1).response() != null ? history.get(idx1).response().bodyToString() : "";
            String resp2 = history.get(idx2).response() != null ? history.get(idx2).response().bodyToString() : "";
            result.addProperty("length1", resp1.length());
            result.addProperty("length2", resp2.length());
            result.addProperty("same", resp1.equals(resp2));
            if (!resp1.equals(resp2)) {
                // Simple diff: find first difference position
                int diffPos = 0;
                for (int i = 0; i < Math.min(resp1.length(), resp2.length()); i++) {
                    if (resp1.charAt(i) != resp2.charAt(i)) { diffPos = i; break; }
                }
                result.addProperty("first_diff_at", diffPos);
                result.addProperty("context1", resp1.substring(Math.max(0, diffPos-20), Math.min(resp1.length(), diffPos+50)));
                result.addProperty("context2", resp2.substring(Math.max(0, diffPos-20), Math.min(resp2.length(), diffPos+50)));
            }
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject cookieJar(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            var cookies = api.http().cookieJar().cookies();
            int limit = params.has("limit") ? params.get("limit").getAsInt() : 100;
            String domainFilter = params.has("domain") ? params.get("domain").getAsString() : null;
            JsonArray items = new JsonArray(); int c = 0;
            for (var cookie : cookies) {
                if (c >= limit) break;
                if (domainFilter != null && !cookie.domain().contains(domainFilter)) continue;
                JsonObject item = new JsonObject();
                item.addProperty("name", cookie.name());
                item.addProperty("value", cookie.value());
                item.addProperty("domain", cookie.domain());
                item.addProperty("path", cookie.path());
                items.add(item); c++;
            }
            result.addProperty("total", c); result.add("cookies", items);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject tokenAnalysis(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            JsonArray tokens = params.getAsJsonArray("tokens");
            // Basic entropy analysis
            JsonArray analysis = new JsonArray();
            for (JsonElement t : tokens) {
                String token = t.getAsString();
                double entropy = 0;
                Map<Character, Integer> freq = new HashMap<>();
                for (char ch : token.toCharArray()) freq.merge(ch, 1, Integer::sum);
                for (int count : freq.values()) {
                    double p = (double) count / token.length();
                    entropy -= p * (Math.log(p) / Math.log(2));
                }
                JsonObject item = new JsonObject();
                item.addProperty("token", token);
                item.addProperty("length", token.length());
                item.addProperty("entropy", Math.round(entropy * 100.0) / 100.0);
                item.addProperty("unique_chars", freq.size());
                item.addProperty("quality", entropy > 3.5 ? "good" : entropy > 2.0 ? "medium" : "weak");
                analysis.add(item);
            }
            result.add("analysis", analysis);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject extensionsList(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            // Montoya API uses extension() not extensions()
            result.addProperty("current_extension", api.extension().filename());
            result.addProperty("info", "Use Burp UI Extensions tab to view all loaded extensions.");
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject logMessage(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String message = privacyRedactor.redactText(params.get("message").getAsString());
            String level = params.has("level") ? params.get("level").getAsString() : "info";
            if ("error".equals(level)) api.logging().logToError(message);
            else api.logging().logToOutput(message);
            result.addProperty("success", true);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    // === NEW TOOLS v2.0 ===

    private JsonObject repeaterSend(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String rawRequest = params.get("request").getAsString();
            String host = params.get("host").getAsString();
            int port = params.has("port") ? params.get("port").getAsInt() : 443;
            boolean isHttps = params.has("https") ? params.get("https").getAsBoolean() : true;
            HttpService service = HttpService.httpService(host, port, isHttps);
            HttpRequest request = HttpRequest.httpRequest(service, rawRequest);
            HttpResponse response = api.http().sendRequest(request).response();
            result.addProperty("status", response.statusCode());
            result.addProperty("length", response.body().length());
            String respBody = response.bodyToString();
            if (respBody.length() > 10000) respBody = respBody.substring(0, 10000) + "...[truncated]";
            result.addProperty("body", respBody);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject intruderPitchfork(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlTemplate = params.get("url_template").getAsString();
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            String bodyTemplate = params.has("body_template") ? params.get("body_template").getAsString() : "";
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();
            JsonObject placeholders = params.getAsJsonObject("placeholders");
            int successLengthNot = params.has("success_length_not") ? params.get("success_length_not").getAsInt() : -1;
            List<String> keys = new ArrayList<>(placeholders.keySet());
            List<JsonArray> valueLists = new ArrayList<>();
            for (String key : keys) valueLists.add(placeholders.getAsJsonArray(key));
            int iterations = valueLists.get(0).size();
            JsonArray hits = new JsonArray(); int count = 0, errors = 0;
            for (int i = 0; i < iterations; i++) {
                String url = urlTemplate; String body = bodyTemplate;
                for (int k = 0; k < keys.size(); k++) { String val = valueLists.get(k).get(i).getAsString(); url = url.replace(keys.get(k), val); body = body.replace(keys.get(k), val); }
                try {
                    URI uri = new URI(url); String host = uri.getHost(); int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
                    String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : ""); boolean isHttps = uri.getScheme().equals("https");
                    StringBuilder rawReq = new StringBuilder(); rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\nHost: ").append(host).append("\r\n");
                    for (Map.Entry<String, JsonElement> e : headers.entrySet()) rawReq.append(e.getKey()).append(": ").append(e.getValue().getAsString()).append("\r\n");
                    if (!body.isEmpty()) rawReq.append("Content-Length: ").append(body.length()).append("\r\n\r\n").append(body); else rawReq.append("\r\n");
                    HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(HttpService.httpService(host, port, isHttps), rawReq.toString())).response();
                    count++;
                    if (successLengthNot > 0 && resp.body().length() != successLengthNot) { JsonObject hit = new JsonObject(); hit.addProperty("iteration", i); hit.addProperty("length", resp.body().length()); hits.add(hit); }
                } catch (Exception e) { errors++; }
            }
            result.addProperty("total_requests", count); result.addProperty("errors", errors); result.addProperty("hits", hits.size()); result.add("hit_details", hits);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject proxyListeners(JsonObject params) { JsonObject r = new JsonObject(); r.addProperty("info", "Manage via Burp UI or export_config/import_config. Default: 127.0.0.1:8080"); return r; }
    private JsonObject proxyMatchReplace(JsonObject params) { JsonObject r = new JsonObject(); r.addProperty("info", "Use export_config -> modify proxy.match_replace_rules -> import_config"); return r; }

    private JsonObject targetInfo(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlPrefix = params.has("url") ? params.get("url").getAsString() : "";
            var entries = api.siteMap().requestResponses(SiteMapFilter.prefixFilter(urlPrefix));
            Set<String> hosts = new HashSet<>(); Set<String> tech = new HashSet<>(); int total = 0;
            for (var entry : entries) { hosts.add(entry.request().httpService().host()); total++;
                if (entry.response() != null) entry.response().headers().forEach(h -> { if (h.name().toLowerCase().matches("server|x-powered-by|x-aspnet-version")) tech.add(h.name()+": "+h.value()); });
                if (total > 500) break; }
            JsonArray hArr = new JsonArray(); hosts.forEach(hArr::add); JsonArray tArr = new JsonArray(); tech.forEach(tArr::add);
            result.add("hosts", hArr); result.add("technologies", tArr); result.addProperty("requests_sampled", total);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject convertRequest(JsonObject params) {
        JsonObject result = new JsonObject();
        try { String req = params.get("request").getAsString(); String to = params.has("convert_to") ? params.get("convert_to").getAsString() : "POST";
            result.addProperty("converted", req.replaceFirst("^(GET|POST|PUT|DELETE|PATCH)", to));
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject exportRequest(JsonObject params) {
        JsonObject result = new JsonObject();
        try { String req = params.get("request").getAsString(); String host = params.has("host") ? params.get("host").getAsString() : "example.com";
            boolean https = params.has("https") ? params.get("https").getAsBoolean() : true;
            String[] lines = req.split("\r\n"); String[] p = lines[0].split(" "); String url = (https?"https://":"http://") + host + (p.length>1?p[1]:"/");
            result.addProperty("curl", "curl -X " + p[0] + " '" + url + "'");
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject generateCsrfPoc(JsonObject params) {
        JsonObject result = new JsonObject();
        try { String req = params.get("request").getAsString(); String host = params.has("host") ? params.get("host").getAsString() : "example.com";
            boolean https = params.has("https") ? params.get("https").getAsBoolean() : true;
            String[] lines = req.split("\r\n"); String[] p = lines[0].split(" "); String url = (https?"https://":"http://") + host + (p.length>1?p[1]:"/");
            result.addProperty("poc_html", "<html><body><form id='f' method='"+p[0]+"' action='"+url+"'></form><script>document.getElementById('f').submit()</script></body></html>");
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject scanActive(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String rawReq = params.get("request").getAsString();
            String host = params.get("host").getAsString();
            int port = params.has("port") ? params.get("port").getAsInt() : 443;
            boolean isHttps = params.has("https") ? params.get("https").getAsBoolean() : true;

            HttpService svc = HttpService.httpService(host, port, isHttps);
            HttpRequest request = HttpRequest.httpRequest(svc, rawReq);
            api.scope().includeInScope(request.url());

            AuditConfiguration cfg = AuditConfiguration.auditConfiguration(BuiltInAuditConfiguration.LEGACY_ACTIVE_AUDIT_CHECKS);
            activeAudit = api.scanner().startAudit(cfg);
            activeAudit.addRequest(request);

            result.addProperty("success", true);
            result.addProperty("url", request.url());
            result.addProperty("message", "Active audit started with seeded request. Poll scan_results for issues. Requires Burp Professional.");
        } catch (Exception e) {
            String msg = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
            if (msg.toLowerCase().contains("professional") || msg.toLowerCase().contains("community") || msg.toLowerCase().contains("license")) {
                result.addProperty("error", "Active scan requires Burp Professional. Detected: " + msg);
            } else {
                result.addProperty("error", msg);
            }
        }
        return result;
    }

    private JsonObject scanIssueDetail(JsonObject params) {
        JsonObject result = new JsonObject();
        try { int index = params.get("index").getAsInt(); var issues = api.siteMap().issues(); int c = 0;
            for (var issue : issues) { if (c == index) { result.addProperty("name", issue.name()); result.addProperty("severity", issue.severity().name());
                result.addProperty("url", issue.baseUrl()); result.addProperty("detail", issue.detail() != null ? issue.detail() : ""); break; } c++; }
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject setUpstreamProxy(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            if (!params.has("proxy_host") || !params.has("proxy_port")) {
                result.addProperty("error", "proxy_host and proxy_port are required");
                return result;
            }
            String proxyHost = params.get("proxy_host").getAsString(); int proxyPort = params.get("proxy_port").getAsInt();
            String type = params.has("type") ? params.get("type").getAsString().toLowerCase() : "http";
            String cfg = "{\"project_options\":{\"connections\":{\"upstream_proxy\":{\"servers\":[{\"destination_host\":\"*\",\"proxy_host\":\""+proxyHost+"\",\"proxy_port\":"+proxyPort+",\"enabled\":true}]}}}}";
            api.burpSuite().importProjectOptionsFromJson(cfg); result.addProperty("success", true);
            result.addProperty("proxy_host", proxyHost); result.addProperty("proxy_port", proxyPort);
            result.addProperty("note", "Upstream proxy set. Pass the same host/port to set_upstream_proxy again to change; restart Burp or clear via project options to disable.");
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject sequencer(JsonObject params) {
        JsonObject result = new JsonObject();
        try { JsonArray tokens = params.getAsJsonArray("tokens"); int total = tokens.size(); Set<String> unique = new HashSet<>();
            Map<Character, Integer> freq = new HashMap<>(); int totalChars = 0;
            for (JsonElement t : tokens) { String tk = t.getAsString(); unique.add(tk); for (char ch : tk.toCharArray()) { freq.merge(ch, 1, Integer::sum); totalChars++; } }
            double entropy = 0; for (int count : freq.values()) { double p = (double)count/totalChars; entropy -= p*(Math.log(p)/Math.log(2)); }
            result.addProperty("total", total); result.addProperty("unique", unique.size()); result.addProperty("entropy_bits", Math.round(entropy*100.0)/100.0);
            result.addProperty("quality", entropy > 4.0 ? "excellent" : entropy > 3.0 ? "good" : "fair");
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    // === NEW v3.0 TOOLS ===

    private JsonObject proxyClear(JsonObject params) {
        JsonObject result = new JsonObject();
        result.addProperty("info", "Proxy history cannot be cleared via API. Use Burp UI: Proxy -> HTTP history -> right-click -> Clear history");
        return result;
    }

    private JsonObject repeaterModifySend(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String rawRequest = params.get("request").getAsString();
            String host = params.get("host").getAsString();
            int port = params.has("port") ? params.get("port").getAsInt() : 443;
            boolean isHttps = params.has("https") ? params.get("https").getAsBoolean() : true;
            // Apply modifications
            if (params.has("replace_header")) {
                JsonObject rh = params.getAsJsonObject("replace_header");
                for (Map.Entry<String, JsonElement> e : rh.entrySet()) {
                    rawRequest = rawRequest.replaceAll("(?i)" + e.getKey() + ": [^\r\n]+", e.getKey() + ": " + e.getValue().getAsString());
                }
            }
            if (params.has("add_header")) {
                JsonObject ah = params.getAsJsonObject("add_header");
                int insertPos = rawRequest.indexOf("\r\n") + 2;
                StringBuilder headers = new StringBuilder();
                for (Map.Entry<String, JsonElement> e : ah.entrySet()) headers.append(e.getKey()).append(": ").append(e.getValue().getAsString()).append("\r\n");
                rawRequest = rawRequest.substring(0, insertPos) + headers + rawRequest.substring(insertPos);
            }
            if (params.has("replace_body")) { int bodyStart = rawRequest.indexOf("\r\n\r\n"); if (bodyStart > 0) rawRequest = rawRequest.substring(0, bodyStart + 4) + params.get("replace_body").getAsString(); }
            HttpService svc = HttpService.httpService(host, port, isHttps);
            HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(svc, rawRequest)).response();
            result.addProperty("status", resp.statusCode()); result.addProperty("length", resp.body().length());
            result.addProperty("body", resp.bodyToString().substring(0, Math.min(10000, resp.bodyToString().length())));
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject intruderClusterBomb(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlTemplate = params.get("url_template").getAsString();
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            String bodyTemplate = params.has("body_template") ? params.get("body_template").getAsString() : "";
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();
            JsonObject placeholders = params.getAsJsonObject("placeholders");
            int successLengthNot = params.has("success_length_not") ? params.get("success_length_not").getAsInt() : -1;
            int maxRequests = params.has("max_requests") ? params.get("max_requests").getAsInt() : 10000;
            List<String> keys = new ArrayList<>(placeholders.keySet());
            List<JsonArray> valueLists = new ArrayList<>();
            for (String key : keys) valueLists.add(placeholders.getAsJsonArray(key));
            // Cartesian product
            JsonArray hits = new JsonArray(); int count = 0, errors = 0;
            int[] indices = new int[keys.size()];
            boolean done = false;
            while (!done && count < maxRequests) {
                String url = urlTemplate; String body = bodyTemplate;
                StringBuilder payloadDesc = new StringBuilder();
                for (int k = 0; k < keys.size(); k++) { String val = valueLists.get(k).get(indices[k]).getAsString(); url = url.replace(keys.get(k), val); body = body.replace(keys.get(k), val); payloadDesc.append(val).append("|"); }
                try {
                    URI uri = new URI(url); String host = uri.getHost(); int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
                    String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : ""); boolean isHttps = uri.getScheme().equals("https");
                    StringBuilder rawReq = new StringBuilder(); rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\nHost: ").append(host).append("\r\n");
                    for (Map.Entry<String, JsonElement> e : headers.entrySet()) rawReq.append(e.getKey()).append(": ").append(e.getValue().getAsString()).append("\r\n");
                    if (!body.isEmpty()) rawReq.append("Content-Length: ").append(body.length()).append("\r\n\r\n").append(body); else rawReq.append("\r\n");
                    HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(HttpService.httpService(host, port, isHttps), rawReq.toString())).response();
                    count++;
                    if (successLengthNot > 0 && resp.body().length() != successLengthNot) { JsonObject hit = new JsonObject(); hit.addProperty("payload", payloadDesc.toString()); hit.addProperty("status", resp.statusCode()); hit.addProperty("length", resp.body().length()); hits.add(hit); }
                } catch (Exception e) { errors++; count++; }
                // Increment indices (cartesian product iteration)
                int carry = keys.size() - 1;
                while (carry >= 0) { indices[carry]++; if (indices[carry] < valueLists.get(carry).size()) break; indices[carry] = 0; carry--; }
                if (carry < 0) done = true;
            }
            result.addProperty("total_requests", count); result.addProperty("errors", errors); result.addProperty("hits", hits.size()); result.add("hit_details", hits);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject intruderBatteringRam(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlTemplate = params.get("url_template").getAsString();
            String placeholder = params.has("placeholder") ? params.get("placeholder").getAsString() : "@@";
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            String bodyTemplate = params.has("body_template") ? params.get("body_template").getAsString() : "";
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();
            JsonArray wordlist = params.getAsJsonArray("wordlist");
            int successLengthNot = params.has("success_length_not") ? params.get("success_length_not").getAsInt() : -1;
            // Battering Ram: same payload in ALL positions (url + body + headers)
            JsonArray hits = new JsonArray(); int count = 0, errors = 0;
            for (JsonElement w : wordlist) {
                String payload = w.getAsString();
                String url = urlTemplate.replace(placeholder, payload);
                String body = bodyTemplate.replace(placeholder, payload);
                try {
                    URI uri = new URI(url); String host = uri.getHost(); int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
                    String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : ""); boolean isHttps = uri.getScheme().equals("https");
                    StringBuilder rawReq = new StringBuilder(); rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\nHost: ").append(host).append("\r\n");
                    for (Map.Entry<String, JsonElement> e : headers.entrySet()) rawReq.append(e.getKey()).append(": ").append(e.getValue().getAsString().replace(placeholder, payload)).append("\r\n");
                    if (!body.isEmpty()) rawReq.append("Content-Length: ").append(body.length()).append("\r\n\r\n").append(body); else rawReq.append("\r\n");
                    HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(HttpService.httpService(host, port, isHttps), rawReq.toString())).response();
                    count++;
                    if (successLengthNot > 0 && resp.body().length() != successLengthNot) { JsonObject hit = new JsonObject(); hit.addProperty("payload", payload); hit.addProperty("status", resp.statusCode()); hit.addProperty("length", resp.body().length()); hits.add(hit); }
                } catch (Exception e2) { errors++; }
            }
            result.addProperty("total_requests", count); result.addProperty("errors", errors); result.addProperty("hits", hits.size()); result.add("hit_details", hits);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject intruderWithOptions(JsonObject params) {
        // Intruder attack with payload processing, throttle, response time, grep extract
        JsonObject result = new JsonObject();
        try {
            String urlTemplate = params.get("url_template").getAsString();
            String placeholder = params.has("placeholder") ? params.get("placeholder").getAsString() : "@@";
            int from = params.has("from") ? params.get("from").getAsInt() : 0;
            int to = params.has("to") ? params.get("to").getAsInt() : 100;
            int padDigits = params.has("pad_digits") ? params.get("pad_digits").getAsInt() : 0;
            String method = params.has("method") ? params.get("method").getAsString() : "GET";
            JsonObject headers = params.has("headers") ? params.getAsJsonObject("headers") : new JsonObject();
            int successLengthNot = params.has("success_length_not") ? params.get("success_length_not").getAsInt() : -1;
            int throttleMs = params.has("throttle_ms") ? params.get("throttle_ms").getAsInt() : 0;
            String payloadPrefix = params.has("payload_prefix") ? params.get("payload_prefix").getAsString() : "";
            String payloadSuffix = params.has("payload_suffix") ? params.get("payload_suffix").getAsString() : "";
            String payloadEncoding = params.has("payload_encoding") ? params.get("payload_encoding").getAsString() : "none";
            String grepExtract = params.has("grep_extract") ? params.get("grep_extract").getAsString() : null;
            boolean recordTime = params.has("record_time") ? params.get("record_time").getAsBoolean() : false;

            JsonArray hits = new JsonArray(); int count = 0, errors = 0;
            for (int i = from; i <= to; i++) {
                String rawPayload = padDigits > 0 ? String.format("%0" + padDigits + "d", i) : String.valueOf(i);
                String payload = payloadPrefix + rawPayload + payloadSuffix;
                if ("base64".equals(payloadEncoding)) payload = Base64.getEncoder().encodeToString(payload.getBytes());
                else if ("url".equals(payloadEncoding)) try { payload = java.net.URLEncoder.encode(payload, "UTF-8"); } catch (Exception ex) {}
                else if ("md5".equals(payloadEncoding)) try { payload = java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("MD5").digest(payload.getBytes())); } catch (Exception ex) {}

                String url = urlTemplate.replace(placeholder, payload);
                try {
                    URI uri = new URI(url); String host = uri.getHost(); int port = uri.getPort() == -1 ? (uri.getScheme().equals("https") ? 443 : 80) : uri.getPort();
                    String path = uri.getRawPath() + (uri.getRawQuery() != null ? "?" + uri.getRawQuery() : ""); boolean isHttps = uri.getScheme().equals("https");
                    StringBuilder rawReq = new StringBuilder(); rawReq.append(method).append(" ").append(path).append(" HTTP/1.1\r\nHost: ").append(host).append("\r\n");
                    for (Map.Entry<String, JsonElement> e : headers.entrySet()) rawReq.append(e.getKey()).append(": ").append(e.getValue().getAsString()).append("\r\n");
                    rawReq.append("\r\n");
                    long startMs = System.currentTimeMillis();
                    HttpResponse resp = api.http().sendRequest(HttpRequest.httpRequest(HttpService.httpService(host, port, isHttps), rawReq.toString())).response();
                    long elapsed = System.currentTimeMillis() - startMs;
                    count++;
                    boolean isHit = (successLengthNot > 0 && resp.body().length() != successLengthNot);
                    if (isHit) {
                        JsonObject hit = new JsonObject(); hit.addProperty("payload", rawPayload); hit.addProperty("status", resp.statusCode()); hit.addProperty("length", resp.body().length());
                        if (recordTime) hit.addProperty("time_ms", elapsed);
                        if (grepExtract != null) { java.util.regex.Matcher m = java.util.regex.Pattern.compile(grepExtract).matcher(resp.bodyToString()); if (m.find()) hit.addProperty("extracted", m.group()); }
                        hits.add(hit);
                    }
                    if (throttleMs > 0) Thread.sleep(throttleMs);
                } catch (Exception e2) { errors++; }
            }
            result.addProperty("total_requests", count); result.addProperty("errors", errors); result.addProperty("hits", hits.size()); result.add("hit_details", hits);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject extractFromResponse(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            int index = params.get("index").getAsInt();
            String regex = params.get("regex").getAsString();
            List<ProxyHttpRequestResponse> history = api.proxy().history();
            if (index < 0 || index >= history.size()) { result.addProperty("error", "Index out of range"); return result; }
            String body = history.get(index).response() != null ? history.get(index).response().bodyToString() : "";
            java.util.regex.Pattern pattern = java.util.regex.Pattern.compile(regex);
            java.util.regex.Matcher matcher = pattern.matcher(body);
            JsonArray matches = new JsonArray();
            while (matcher.find()) { matches.add(matcher.group()); }
            result.addProperty("total_matches", matches.size()); result.add("matches", matches);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject crawl(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String url = params.get("url").getAsString();
            api.scope().includeInScope(url);
            activeCrawl = api.scanner().startCrawl(CrawlConfiguration.crawlConfiguration(url));
            result.addProperty("success", true);
            result.addProperty("url", url);
            result.addProperty("message", "Crawl started. Requires Burp Professional. New URLs surface in sitemap; check Crawl progress via request count.");
            result.addProperty("note", "Crawl.statusMessage() is unimplemented in the current API; completion has no reliable polling signal.");
        } catch (Exception e) {
            String msg = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
            if (msg.toLowerCase().contains("professional") || msg.toLowerCase().contains("community") || msg.toLowerCase().contains("license")) {
                result.addProperty("error", "Crawl requires Burp Professional. Detected: " + msg);
            } else {
                result.addProperty("error", msg);
            }
        }
        return result;
    }

    private JsonObject setDnsOverride(JsonObject params) {
        JsonObject result = new JsonObject();
        try { String hostname = params.get("hostname").getAsString(); String ip = params.get("ip").getAsString();
            String cfg = "{\"project_options\":{\"connections\":{\"hostname_resolution\":[{\"enabled\":true,\"hostname\":\""+hostname+"\",\"ip_address\":\""+ip+"\"}]}}}";
            api.burpSuite().importProjectOptionsFromJson(cfg); result.addProperty("success", true);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject setHttp2(JsonObject params) {
        JsonObject result = new JsonObject();
        try { boolean enable = params.has("enable") ? params.get("enable").getAsBoolean() : false;
            String cfg = "{\"project_options\":{\"http\":{\"http2\":{\"enabled\":"+enable+"}}}}";
            api.burpSuite().importProjectOptionsFromJson(cfg); result.addProperty("success", true); result.addProperty("http2_enabled", enable);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject exportCert(JsonObject params) {
        JsonObject result = new JsonObject();
        result.addProperty("info", "Export Burp CA cert: Proxy -> Options -> Import/Export CA certificate -> Export Certificate in DER format");
        result.addProperty("path_hint", "Or visit http://burp/cert in browser with Burp proxy enabled");
        return result;
    }

    private JsonObject websocketSend(JsonObject params) {
        JsonObject result = new JsonObject();
        result.addProperty("info", "WebSocket message sending requires an active WS connection. Use browser with Burp proxy to establish WS, then intercept/modify via Proxy -> WebSocket history.");
        return result;
    }

    private JsonObject payloadProcess(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String input = params.get("input").getAsString();
            String operation = params.get("operation").getAsString();
            String output = input;
            switch (operation) {
                case "base64_encode": output = Base64.getEncoder().encodeToString(input.getBytes()); break;
                case "base64_decode": output = new String(Base64.getDecoder().decode(input)); break;
                case "url_encode": output = java.net.URLEncoder.encode(input, "UTF-8"); break;
                case "url_decode": output = java.net.URLDecoder.decode(input, "UTF-8"); break;
                case "md5": output = java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("MD5").digest(input.getBytes())); break;
                case "sha1": output = java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-1").digest(input.getBytes())); break;
                case "sha256": output = java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(input.getBytes())); break;
                case "hex_encode": StringBuilder hex = new StringBuilder(); for (byte b : input.getBytes()) hex.append(String.format("%02x", b)); output = hex.toString(); break;
                case "lowercase": output = input.toLowerCase(); break;
                case "uppercase": output = input.toUpperCase(); break;
                case "reverse": output = new StringBuilder(input).reverse().toString(); break;
                case "length": output = String.valueOf(input.length()); break;
                default: result.addProperty("error", "Operations: base64_encode/decode, url_encode/decode, md5, sha1, sha256, hex_encode, lowercase, uppercase, reverse, length"); return result;
            }
            result.addProperty("input", input); result.addProperty("output", output); result.addProperty("operation", operation);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject saveProject(JsonObject params) {
        JsonObject result = new JsonObject();
        result.addProperty("info", "Project auto-saves. Use Burp menu: Burp -> Save project to save explicitly.");
        return result;
    }

    private JsonObject exportConfig(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String config = api.burpSuite().exportProjectOptionsAsJson();
            result.addProperty("config", config.substring(0, Math.min(5000, config.length())));
            result.addProperty("truncated", config.length() > 5000);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private JsonObject importConfig(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String config = params.get("config").getAsString();
            api.burpSuite().importProjectOptionsFromJson(config);
            result.addProperty("success", true);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    
    private JsonObject burpVersion(JsonObject params) {
        JsonObject result = new JsonObject();
        try { var v = api.burpSuite().version(); result.addProperty("name", v.name()); result.addProperty("build_number", v.buildNumber()); result.addProperty("edition", String.valueOf(v.edition())); result.addProperty("version", v.toString()); }
        catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject addIssue(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String name = params.get("name").getAsString();
            String url = params.get("url").getAsString();
            String detail = params.has("detail") ? params.get("detail").getAsString() : "";
            String remediation = params.has("remediation") ? params.get("remediation").getAsString() : "";
            String severityStr = params.has("severity") ? params.get("severity").getAsString().toUpperCase() : "INFORMATION";
            String confidenceStr = params.has("confidence") ? params.get("confidence").getAsString().toUpperCase() : "TENTATIVE";

            AuditIssueSeverity severity;
            try { severity = AuditIssueSeverity.valueOf(severityStr); }
            catch (IllegalArgumentException ex) { severity = AuditIssueSeverity.INFORMATION; }
            AuditIssueConfidence confidence;
            try { confidence = AuditIssueConfidence.valueOf(confidenceStr); }
            catch (IllegalArgumentException ex) { confidence = AuditIssueConfidence.TENTATIVE; }

            AuditIssue issue = AuditIssue.auditIssue(
                    name, detail, remediation, url, severity, confidence,
                    "", "", severity);
            api.siteMap().add(issue);
            result.addProperty("success", true);
            result.addProperty("message", "Issue added to sitemap: " + name + " at " + url);
            result.addProperty("severity", severity.name());
            result.addProperty("confidence", confidence.name());
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject proxyHistoryFiltered(JsonObject params) {
        JsonObject result = new JsonObject();
        try { String hasNotes = params.has("has_notes") ? params.get("has_notes").getAsString() : null;
            int limit = params.has("limit") ? params.get("limit").getAsInt() : 50;
            List<ProxyHttpRequestResponse> history = api.proxy().history();
            JsonArray items = new JsonArray(); int c = 0;
            for (int i = history.size() - 1; i >= 0 && c < limit; i--) {
                ProxyHttpRequestResponse entry = history.get(i);
                boolean match = true;
                if (hasNotes != null && "true".equals(hasNotes)) { String notes = entry.annotations().notes(); match = notes != null && !notes.isEmpty(); }
                if (match) { JsonObject item = new JsonObject(); item.addProperty("index", i); item.addProperty("url", entry.finalRequest().url()); item.addProperty("notes", entry.annotations().notes() != null ? entry.annotations().notes() : ""); items.add(item); c++; }
            }
            result.addProperty("matches", c); result.add("items", items);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private volatile String httpHandlerHeader = "";
    private volatile String httpHandlerHeaderValue = "";
    private volatile String httpHandlerMatch = "";
    private volatile String httpHandlerReplace = "";
    private volatile boolean httpHandlerActive = false;
    private volatile Registration httpHandlerRegistration = null;

    private JsonObject registerHttpHandler(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            if (params.has("header_name")) { httpHandlerHeader = params.get("header_name").getAsString(); httpHandlerHeaderValue = params.get("header_value").getAsString(); }
            if (params.has("match")) { httpHandlerMatch = params.get("match").getAsString(); httpHandlerReplace = params.get("replace").getAsString(); }
            if (!httpHandlerActive) {
                httpHandlerRegistration = api.http().registerHttpHandler(new burp.api.montoya.http.handler.HttpHandler() {
                    public burp.api.montoya.http.handler.RequestToBeSentAction handleHttpRequestToBeSent(burp.api.montoya.http.handler.HttpRequestToBeSent req) {
                        HttpRequest m = req; if (!httpHandlerHeader.isEmpty()) m = m.withAddedHeader(httpHandlerHeader, httpHandlerHeaderValue);
                        if (!httpHandlerMatch.isEmpty()) m = HttpRequest.httpRequest(m.httpService(), m.toString().replace(httpHandlerMatch, httpHandlerReplace));
                        return burp.api.montoya.http.handler.RequestToBeSentAction.continueWith(m); }
                    public burp.api.montoya.http.handler.ResponseReceivedAction handleHttpResponseReceived(burp.api.montoya.http.handler.HttpResponseReceived r) { return burp.api.montoya.http.handler.ResponseReceivedAction.continueWith(r); }
                });
                httpHandlerActive = true;
            }
            result.addProperty("success", true);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject removeHttpHandler(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            if (httpHandlerRegistration != null && httpHandlerRegistration.isRegistered()) {
                httpHandlerRegistration.deregister();
            }
            httpHandlerRegistration = null;
            httpHandlerActive = false;
            httpHandlerHeader = ""; httpHandlerHeaderValue = ""; httpHandlerMatch = ""; httpHandlerReplace = "";
            result.addProperty("success", true); result.addProperty("message", "HTTP handler deregistered");
        } catch (Exception e) { result.addProperty("error", e.getMessage()); }
        return result;
    }

    private volatile String proxyRuleUrl = "";
    private volatile boolean proxyRuleActive = false;
    private volatile Registration proxyRuleRegistration = null;

    private JsonObject registerProxyRule(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            String urlContains = params.get("url_contains").getAsString();
            boolean intercept = params.has("intercept") ? params.get("intercept").getAsBoolean() : true;
            if (proxyRuleActive) {
                result.addProperty("error", "A proxy rule is already active. Call remove_proxy_rule first.");
                return result;
            }
            proxyRuleUrl = urlContains;
            proxyRuleRegistration = api.proxy().registerRequestHandler(new ProxyRequestHandler() {
                public ProxyRequestReceivedAction handleRequestReceived(InterceptedRequest req) {
                    if (!proxyRuleUrl.isEmpty() && req.url().contains(proxyRuleUrl)) {
                        return intercept ? ProxyRequestReceivedAction.intercept(req)
                                         : ProxyRequestReceivedAction.doNotIntercept(req);
                    }
                    return ProxyRequestReceivedAction.continueWith(req);
                }
                public ProxyRequestToBeSentAction handleRequestToBeSent(InterceptedRequest req) {
                    return ProxyRequestToBeSentAction.continueWith(req);
                }
            });
            proxyRuleActive = true;
            result.addProperty("success", true);
            result.addProperty("message", "Proxy rule active: " + (intercept ? "intercept" : "do-not-intercept") + " URLs containing " + urlContains);
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }

    private JsonObject removeProxyRule(JsonObject params) {
        JsonObject result = new JsonObject();
        try {
            if (proxyRuleRegistration != null && proxyRuleRegistration.isRegistered()) {
                proxyRuleRegistration.deregister();
            }
            proxyRuleRegistration = null;
            proxyRuleActive = false;
            String was = proxyRuleUrl; proxyRuleUrl = "";
            result.addProperty("success", true);
            result.addProperty("message", "Proxy rule removed" + (was.isEmpty() ? "" : " (was: " + was + ")"));
        } catch (Exception e) { result.addProperty("error", e.getMessage()); } return result;
    }


    // ==================== HELPERS ====================


    // === FIELDS ===
    private final java.util.Map<String, ExtensionWebSocket> wsConnections = new java.util.concurrent.ConcurrentHashMap();
    private final java.util.Map<String, String> websocketTargets = new java.util.concurrent.ConcurrentHashMap<>();
    private final AtomicInteger wsCounter = new AtomicInteger();
    private volatile Registration sessionActionRegistration = null;
    private java.util.concurrent.ExecutorService threadPool = java.util.concurrent.Executors.newFixedThreadPool(4, runnable -> {
        Thread thread = new Thread(runnable, "burp-mcp-tool");
        thread.setDaemon(true);
        return thread;
    });

    private HttpRequestResponse sendOne(String method, String url, String body) {
        try { java.net.URL u=new java.net.URL(url); boolean h="https".equals(u.getProtocol());
            HttpService s=HttpService.httpService(u.getHost(), u.getPort()>0?u.getPort():(h?443:80), h);
            String p=(u.getPath()==null||u.getPath().isEmpty())?"/":u.getPath(); String pq=u.getQuery()!=null?p+"?"+u.getQuery():p;
            String r=method+" "+pq+" HTTP/1.1\r\nHost: "+u.getHost()+"\r\nConnection: close\r\n\r\n";
            if(body!=null&&!body.isEmpty()) r=method+" "+pq+" HTTP/1.1\r\nHost: "+u.getHost()+"\r\nContent-Length: "+body.length()+"\r\nConnection: close\r\n\r\n"+body;
            return api.http().sendRequest(HttpRequest.httpRequest(s, r));
        } catch(Exception ex) { return null; }
    }

    // === PHASE 1 ===
    private JsonObject cookieJarSet(JsonObject p) { JsonObject r=new JsonObject();
        try{ api.http().cookieJar().setCookie(p.get("url").getAsString(),p.get("name").getAsString(),p.get("value").getAsString(),"/",ZonedDateTime.now().plusDays(30)); r.addProperty("success",true); }
        catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject sendRequestParallel(JsonObject p) { JsonObject r=new JsonObject();
        try{ var reqs=p.getAsJsonArray("requests"); java.util.ArrayList futures=new java.util.ArrayList();
            for(int i=0;i<reqs.size();i++){var o=reqs.get(i).getAsJsonObject(); futures.add(threadPool.submit(()->sendOne(o.get("method").getAsString(),o.get("url").getAsString(),o.has("body")?o.get("body").getAsString():null)));}
            var items=new JsonArray();
            for(Object fobj:futures){try{HttpRequestResponse rr=(HttpRequestResponse)((java.util.concurrent.Future)fobj).get(); var ri=new JsonObject(); ri.addProperty("status",rr.response()!=null?rr.response().statusCode():0); ri.addProperty("length",rr.response()!=null?rr.response().bodyToString().length():0); items.add(ri);}catch(Exception ex){}}
            r.add("results",items); r.addProperty("total",items.size());
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject websocketCreate(JsonObject p) {
        JsonObject r = new JsonObject();
        try {
            boolean https = p.has("https") ? p.get("https").getAsBoolean() : true;
            int port = p.has("port") ? p.get("port").getAsInt() : (https ? 443 : 80);
            String host = p.get("host").getAsString();
            String path = p.has("path") ? p.get("path").getAsString() : "/";
            String target = normalizedWebSocketTarget(https, host, port, path);
            var creation = api.websockets().createWebSocket(HttpService.httpService(host, port, https), path);
            r.addProperty("status", creation.status().toString());
            creation.webSocket().ifPresent(webSocket -> {
                String id = "ws-" + wsCounter.incrementAndGet();
                wsConnections.put(id, webSocket);
                websocketTargets.put(id, target);
                r.addProperty("id", id);
            });
        } catch (Exception exception) {
            r.addProperty("error", exception.getMessage());
        }
        return r;
    }

    private static String normalizedWebSocketTarget(boolean https, String host, int port, String path) throws Exception {
        String value = path == null || path.isBlank() ? "/" : path;
        if (!value.startsWith("/")) value = "/" + value;
        int queryIndex = value.indexOf('?');
        String pathPart = queryIndex >= 0 ? value.substring(0, queryIndex) : value;
        String queryPart = queryIndex >= 0 ? value.substring(queryIndex + 1) : null;
        return new URI(https ? "https" : "http", null, host, port, pathPart, queryPart, null).toString();
    }

    private JsonObject websocketSendBinary(JsonObject p) {
        JsonObject r = new JsonObject();
        try {
            var ws = wsConnections.get(p.get("id").getAsString());
            if (ws == null) {
                r.addProperty("error", "WS not found");
                return r;
            }
            ws.sendBinaryMessage(ByteArray.byteArray(p.get("data").getAsString().getBytes(StandardCharsets.UTF_8)));
            r.addProperty("success", true);
        } catch (Exception exception) {
            r.addProperty("error", exception.getMessage());
        }
        return r;
    }

    private JsonObject websocketSendText(JsonObject p) {
        JsonObject r = new JsonObject();
        try {
            var ws = wsConnections.get(p.get("id").getAsString());
            if (ws == null) {
                r.addProperty("error", "WS not found");
                return r;
            }
            ws.sendTextMessage(p.get("text").getAsString());
            r.addProperty("success", true);
        } catch (Exception exception) {
            r.addProperty("error", exception.getMessage());
        }
        return r;
    }

    private JsonObject websocketClose(JsonObject p) {
        JsonObject r = new JsonObject();
        String id = p.get("id").getAsString();
        websocketTargets.remove(id);
        try {
            var ws = wsConnections.remove(id);
            if (ws == null) {
                r.addProperty("error", "WS not found");
                return r;
            }
            ws.close();
            r.addProperty("success", true);
        } catch (Exception exception) {
            r.addProperty("error", exception.getMessage());
        }
        return r;
    }
    private JsonObject websocketList(JsonObject p) { JsonObject r=new JsonObject(); var items=new JsonArray();
            for(String id:wsConnections.keySet()){var i=new JsonObject();i.addProperty("id",id);items.add(i);} r.add("connections",items); r.addProperty("total",items.size()); return r; }
    private JsonObject passiveIntel(JsonObject p) { JsonObject r=new JsonObject();
        try{ var f=new JsonArray(); int lim=p.has("limit")?p.get("limit").getAsInt():100; int c=0;
            for(var e:api.proxy().history()){if(c>=lim)break; String b=e.response()!=null?e.response().bodyToString():""; String all=b+" "+e.request();
            java.util.regex.Matcher m; String t=null;
            if((m=java.util.regex.Pattern.compile("AKIA[0-9A-Z]{16}").matcher(all)).find()) t="AWS Access Key ID";
            else if((m=java.util.regex.Pattern.compile("eyJ[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+").matcher(all)).find()) t="JWT";
            else if((m=java.util.regex.Pattern.compile("-----BEGIN.*PRIVATE KEY-----").matcher(all)).find()) t="Private Key";
            else if((m=java.util.regex.Pattern.compile("xox[baprs]-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24}").matcher(all)).find()) t="Slack Token";
            if(t!=null){var fi=new JsonObject();fi.addProperty("type",t);fi.addProperty("url",e.request().url());f.add(fi);} c++;}
            r.add("findings",f); r.addProperty("total",f.size());
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject sessionCreateRule(JsonObject p) { JsonObject r=new JsonObject();
        try{ if(sessionActionRegistration!=null){r.addProperty("error","Rule active");return r;}
            var pat=java.util.regex.Pattern.compile(p.get("find").getAsString()); String rep=p.get("replace").getAsString();
            sessionActionRegistration=api.http().registerSessionHandlingAction(new SessionHandlingAction(){
                public String name(){return "MCP Rule";}
                public ActionResult performAction(SessionHandlingActionData d){
                    String req=d.request().toString(); req=pat.matcher(req).replaceAll(rep);
                    try{return ActionResult.actionResult(HttpRequest.httpRequest(req));}catch(Exception e){return ActionResult.actionResult(d.request());}
                }});
            r.addProperty("success",true); r.addProperty("rule","s/"+p.get("find").getAsString()+"/"+rep+"/");
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject sessionListRules(JsonObject p) { JsonObject r=new JsonObject(); r.addProperty("active",sessionActionRegistration!=null&&sessionActionRegistration.isRegistered()); return r; }
    private JsonObject sessionRemoveRule(JsonObject p) { JsonObject r=new JsonObject(); if(sessionActionRegistration!=null&&sessionActionRegistration.isRegistered()) sessionActionRegistration.deregister(); sessionActionRegistration=null; r.addProperty("success",true); return r; }

    // === PHASE 2 ===
    private JsonObject jwtDecode(JsonObject p) { JsonObject r=new JsonObject();
        try{ var parts=p.get("token").getAsString().split("\\."); if(parts.length<2){r.addProperty("error","Invalid JWT");return r;}
            r.add("header",JsonParser.parseString(new String(java.util.Base64.getUrlDecoder().decode(parts[0]))));
            r.add("payload",JsonParser.parseString(new String(java.util.Base64.getUrlDecoder().decode(parts[1]))));
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject jwtAttack(JsonObject p) { JsonObject r=new JsonObject();
        try{ var parts=p.get("token").getAsString().split("\\.");
            if("none".equals(p.has("attack")?p.get("attack").getAsString():"none")){
                var h=JsonParser.parseString(new String(java.util.Base64.getUrlDecoder().decode(parts[0]))).getAsJsonObject();
                h.addProperty("alg","none"); r.addProperty("forged",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(h.toString().getBytes())+"."+parts[1]+".");
            }}catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject injectionProbe(JsonObject p) { JsonObject r=new JsonObject();
        try{ String url=p.get("url").getAsString(),param=p.get("param").getAsString(),type=p.has("type")?p.get("type").getAsString():"sqli";
            String[][] lib={{"\'","\' OR \'1\'=\'1","\' AND SLEEP(3)--"},{"syntax","unclosed","mysql","ORA-"}}; // sqli default
            if("ssti".equals(type)) lib=new String[][]{{"{{7*7}}","${7*7}","<%=7*7%>"},{"49"}};
            if("lfi".equals(type)) lib=new String[][]{{"../../etc/passwd","....//....//etc/passwd"},{"root:","bin:"}};
            var items=new JsonArray();
            for(String pl:lib[0]){ String fu=url+(url.contains("?")?"&":"?")+param+"="+java.net.URLEncoder.encode(pl,"UTF-8");
                var u=new java.net.URL(fu); boolean hh="https".equals(u.getProtocol());
                var svc=HttpService.httpService(u.getHost(),u.getPort()>0?u.getPort():(hh?443:80),hh);
                var req=HttpRequest.httpRequest(svc,"GET "+(u.getQuery()!=null?u.getPath()+"?"+u.getQuery():u.getPath())+" HTTP/1.1\r\nHost: "+u.getHost()+"\r\nConnection: close\r\n\r\n");
                var rr=api.http().sendRequest(req); String body=rr.response()!=null?rr.response().bodyToString():"";
                boolean hit=false; for(String ind:lib[1]){if(body.toLowerCase().contains(ind.toLowerCase())){hit=true;break;}}
                var item=new JsonObject(); item.addProperty("payload",pl); item.addProperty("status",rr.response()!=null?rr.response().statusCode():0);
                item.addProperty("length",body.length()); item.addProperty("indicator_match",hit); items.add(item);}
            r.add("results",items); r.addProperty("total",items.size());
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject accessControlSweep(JsonObject p) { JsonObject r=new JsonObject();
        try{ var svc=HttpService.httpService(p.get("host").getAsString(),p.has("port")?p.get("port").getAsInt():443,p.has("https")?p.get("https").getAsBoolean():true);
            var items=new JsonArray();
            for(String a:p.get("auth_headers").getAsString().split("\\|")){
                String mod=p.get("request").getAsString().replaceAll("(?i)Authorization: .*\r\n",a.isEmpty()?"":"Authorization: "+a+"\r\n");
                var rr=api.http().sendRequest(HttpRequest.httpRequest(svc,mod)); var item=new JsonObject();
                item.addProperty("auth",a.isEmpty()?"none":a); item.addProperty("status",rr.response()!=null?rr.response().statusCode():0);
                item.addProperty("length",rr.response()!=null?rr.response().bodyToString().length():0); items.add(item);}
            r.add("sweeps",items);
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject raceCondition(JsonObject p) { JsonObject r=new JsonObject();
        try{ var svc=HttpService.httpService(p.get("host").getAsString(),p.has("port")?p.get("port").getAsInt():443,p.has("https")?p.get("https").getAsBoolean():true);
            var req=HttpRequest.httpRequest(svc,p.get("request").getAsString()); int cnt=p.has("count")?p.get("count").getAsInt():10;
            java.util.ArrayList futures=new java.util.ArrayList(); for(int i=0;i<cnt;i++) futures.add(threadPool.submit(()->api.http().sendRequest(req)));
            var items=new JsonArray(); var lens=new java.util.HashSet();
            for(Object fobj:futures){try{HttpRequestResponse rr=(HttpRequestResponse)((java.util.concurrent.Future)fobj).get(); var item=new JsonObject();
                item.addProperty("status",rr.response()!=null?rr.response().statusCode():0); item.addProperty("length",rr.response()!=null?rr.response().bodyToString().length():0); items.add(item);
                if(rr.response()!=null)lens.add(rr.response().bodyToString().length());}catch(Exception ex){}}
            r.add("results",items); r.addProperty("total",cnt); r.addProperty("unique_lengths",lens.size());
            r.addProperty("verdict",lens.size()>1?"Possible race":"All identical");
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }
    private JsonObject inlineFuzzer(JsonObject p) { JsonObject r=new JsonObject();
        try{ var svc=HttpService.httpService(p.get("host").getAsString(),p.has("port")?p.get("port").getAsInt():443,p.has("https")?p.get("https").getAsBoolean():true);
            String tmpl=p.get("template").getAsString(), marker=p.has("marker")?p.get("marker").getAsString():"FUZZ"; var wl=p.getAsJsonArray("wordlist");
            java.util.ArrayList futures=new java.util.ArrayList(); for(int i=0;i<wl.size();i++){String pl=wl.get(i).getAsString(); futures.add(threadPool.submit(()->api.http().sendRequest(HttpRequest.httpRequest(svc,tmpl.replace(marker,pl)))));}
            var items=new JsonArray();
            for(Object fobj:futures){try{HttpRequestResponse rr=(HttpRequestResponse)((java.util.concurrent.Future)fobj).get(); var item=new JsonObject();
                item.addProperty("status",rr.response()!=null?rr.response().statusCode():0); item.addProperty("length",rr.response()!=null?rr.response().bodyToString().length():0); items.add(item);
            }catch(Exception ex){}}
            r.add("results",items); r.addProperty("total",items.size());
        }catch(Exception e){r.addProperty("error",e.getMessage());} return r; }

    // === PHASE 3-4 ===
    private JsonObject scopeGate(JsonObject p) { JsonObject r=new JsonObject();
        r.addProperty("scope_gate",true); r.addProperty("read_only",true); r.addProperty("scope_file_configured",securityConfig.scopeFile()!=null);
        r.addProperty("message","Scope enforcement is always active; MCP cannot disable it."); return r; }
    private JsonObject privacyMode(JsonObject p) { JsonObject r=new JsonObject();
        r.addProperty("privacy","strict"); r.addProperty("read_only",true); r.addProperty("immutable",true);
        if(p.has("mode") && "off".equalsIgnoreCase(p.get("mode").getAsString())) r.addProperty("blocked",true);
        return r; }
    private JsonObject auditLog(JsonObject p) { JsonObject r=new JsonObject();
        int lim=p.has("limit")?p.get("limit").getAsInt():50; var items=new JsonArray();
        for(String entry:auditLogger.recent(lim)) items.add(entry);
        r.add("entries",items); r.addProperty("total",items.size()); return r; }
    private String getToolList() {
        return "[\"proxy_history\",\"proxy_detail\",\"proxy_websocket\",\"proxy_listeners\"," +
               "\"proxy_match_replace\",\"proxy_clear\",\"proxy_history_filtered\"," +
               "\"send_request\",\"send_to_repeater\",\"repeater_send\",\"repeater_modify_send\"," +
               "\"send_to_intruder\",\"intruder_attack\",\"intruder_attack_async\"," +
               "\"intruder_attack_wordlist\",\"intruder_pitchfork\",\"intruder_cluster_bomb\"," +
               "\"intruder_battering_ram\",\"intruder_with_options\"," +
               "\"sitemap\",\"target_info\",\"intercept_toggle\",\"intercept_modify\",\"encode\"," +
               "\"decode\",\"convert_request\",\"export_request\",\"generate_csrf_poc\"," +
               "\"extract_from_response\",\"payload_process\",\"scan\",\"scan_active\"," +
               "\"scan_results\",\"scan_issue_detail\",\"crawl\",\"get_scope\",\"add_to_scope\"," +
               "\"remove_from_scope\",\"collaborator_generate\",\"collaborator_poll\"," +
               "\"search_history\",\"highlight\",\"annotate\",\"compare\",\"export_config\"," +
               "\"import_config\",\"set_upstream_proxy\",\"set_dns_override\",\"set_http2\"," +
               "\"cookie_jar\",\"token_analysis\",\"sequencer\",\"export_cert\",\"websocket_send\"," +
               "\"save_project\",\"burp_version\",\"add_issue\",\"register_http_handler\"," +
               "\"remove_http_handler\",\"register_proxy_rule\",\"remove_proxy_rule\"," +
               "\"extensions_list\",\"log\",\"cookie_jar_set\",\"send_request_parallel\",\"websocket_create\",\"websocket_send_text\",\"websocket_send_binary\",\"websocket_close\",\"websocket_list\",\"passive_intel\",\"session_create_rule\",\"session_list_rules\",\"session_remove_rule\",\"jwt_decode\",\"jwt_attack\",\"injection_probe\",\"access_control_sweep\",\"race_condition\",\"inline_fuzzer\",\"scope_gate\",\"privacy_mode\",\"audit_log\"]";
    }

    private void addCorsHeaders(Response resp, String origin) {
        // Only reflect allowlisted Origins. Never echo an unapproved Origin on error or success responses.
        if (origin != null && !origin.isBlank() && securityConfig.isOriginAllowed(origin)) {
            resp.addHeader("Access-Control-Allow-Origin", origin);
            resp.addHeader("Vary", "Origin");
        }
        resp.addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        resp.addHeader("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Burp-MCP-Confirmation");
        resp.addHeader("Cache-Control", "no-store");
        resp.addHeader("X-Content-Type-Options", "nosniff");
    }
}
