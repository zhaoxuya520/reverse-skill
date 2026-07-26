package com.burpmcp;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

final class BurpRequestPolicy {
    enum Outcome { ALLOW, BLOCKED, CONFIRMATION_REQUIRED, GONE }

    static final class Capabilities {
        final boolean readOnly;
        final boolean network;
        final boolean credentials;
        final boolean destructive;
        final boolean requiresScope;
        final boolean requiresConfirmation;
        final boolean filesystemRead;
        final boolean filesystemWrite;
        final boolean deviceControl;
        final boolean sensitiveOutput;

        Capabilities(boolean readOnly, boolean network, boolean credentials, boolean destructive,
                     boolean requiresScope, boolean requiresConfirmation, boolean filesystemRead,
                     boolean filesystemWrite, boolean deviceControl, boolean sensitiveOutput) {
            this.readOnly = readOnly;
            this.network = network;
            this.credentials = credentials;
            this.destructive = destructive;
            this.requiresScope = requiresScope;
            this.requiresConfirmation = requiresConfirmation;
            this.filesystemRead = filesystemRead;
            this.filesystemWrite = filesystemWrite;
            this.deviceControl = deviceControl;
            this.sensitiveOutput = sensitiveOutput;
        }
    }

    static final class Decision {
        private final Outcome outcome;
        private final String reason;
        private final String action;
        private final String target;
        private final String confirmationToken;
        private final String parameterDigest;
        private final boolean active;

        Decision(Outcome outcome, String reason, String action, String target, String confirmationToken,
                 String parameterDigest, boolean active) {
            this.outcome = outcome;
            this.reason = reason;
            this.action = action;
            this.target = target;
            this.confirmationToken = confirmationToken;
            this.parameterDigest = parameterDigest;
            this.active = active;
        }

        Outcome outcome() { return outcome; }
        String reason() { return reason; }
        String action() { return action; }
        String target() { return target; }
        String confirmationToken() { return confirmationToken; }
        String parameterDigest() { return parameterDigest; }
        boolean active() { return active; }
    }

    private enum TargetMode { NONE, NETWORK, FILE }

    private static final Capabilities PASSIVE = new Capabilities(true, false, false, false, false, false, false, false, false, false);
    private static final Map<String, Rule> RULES = buildRules();
    private static final Set<String> URL_KEYS = Set.of("url", "target", "target_url", "endpoint", "url_template", "base_url");
    private static final Set<String> FILE_KEYS = Set.of("path", "file", "file_path", "project_file", "config_file", "output_path");
    private final BurpMcpSecurityConfig config;
    private final ConfirmationProvider confirmations;
    private final PrivacyRedactor redactor;

    BurpRequestPolicy(BurpMcpSecurityConfig config, ConfirmationProvider confirmations, PrivacyRedactor redactor) {
        this.config = config;
        this.confirmations = confirmations;
        this.redactor = redactor;
    }

    Decision evaluate(String tool, JsonObject params, String confirmationToken) {
        String parameterDigest = digest(params);
        Rule rule = RULES.get(tool);
        if (rule == null) {
            return new Decision(Outcome.BLOCKED, "tool is not registered in policy", "unknown", "",
                    null, parameterDigest, true);
        }
        if (!rule.capabilities.requiresScope) {
            return new Decision(Outcome.ALLOW, "passive.read", "passive.read", "local", null, parameterDigest, false);
        }

        ScopeDocument.LoadResult loadResult = ScopeDocument.load(config.scopeFile(), true);
        if (!loadResult.valid()) {
            return blocked(String.join("; ", loadResult.issues()), rule, "", parameterDigest);
        }
        ScopeDocument scope = loadResult.document();
        if (!scope.isActionAllowed(rule.action)) {
            return blocked("scope does not allow action " + rule.action, rule, "", parameterDigest);
        }

        List<TargetRef> targets = extractTargets(params, rule.targetMode);
        if (rule.targetRequired && targets.isEmpty()) {
            return blocked("active operation target is missing or cannot be normalized", rule, "", parameterDigest);
        }
        if (!scope.hasTargets()) {
            return blocked("scope has no targets", rule, "", parameterDigest);
        }
        for (TargetRef target : targets) {
            boolean matches = target.uri != null ? scope.matchesNetwork(target.uri) : scope.matchesFile(target.path);
            if (!matches) return blocked("target is outside scope", rule, target.description, parameterDigest);
        }

        String targetSummary = targets.isEmpty() ? String.join(",", scope.targetDescriptions()) : joinTargets(targets);
        if (confirmationToken == null || confirmationToken.isBlank()) {
            ConfirmationProvider.IssueResult issue = confirmations.issue(tool, targetSummary, parameterDigest, redactor.parameterSummary(params));
            if (!issue.approved()) return blocked("user denied active operation", rule, targetSummary, parameterDigest);
            return new Decision(Outcome.CONFIRMATION_REQUIRED, "confirmation_required", rule.action, targetSummary,
                    issue.token(), parameterDigest, true);
        }

        ConfirmationProvider.ConsumeStatus status = confirmations.consume(confirmationToken, tool, targetSummary, parameterDigest);
        if (status == ConfirmationProvider.ConsumeStatus.VALID) {
            return new Decision(Outcome.ALLOW, "confirmed", rule.action, targetSummary, null, parameterDigest, true);
        }
        if (status == ConfirmationProvider.ConsumeStatus.EXPIRED || status == ConfirmationProvider.ConsumeStatus.REPLAYED) {
            return new Decision(Outcome.GONE, status.name().toLowerCase(Locale.ROOT), rule.action, targetSummary, null, parameterDigest, true);
        }
        return blocked("confirmation token is invalid", rule, targetSummary, parameterDigest);
    }

    Capabilities capabilities(String tool) {
        Rule rule = RULES.get(tool);
        return rule == null ? null : rule.capabilities;
    }

    private static Decision blocked(String reason, Rule rule, String target, String digest) {
        return new Decision(Outcome.BLOCKED, reason, rule.action, target, null, digest, true);
    }

    private static Map<String, Rule> buildRules() {
        Map<String, Rule> rules = new LinkedHashMap<>();
        passive(rules,
                "proxy_history", "proxy_detail", "proxy_websocket", "proxy_listeners", "proxy_history_filtered",
                "sitemap", "target_info", "encode", "decode", "convert_request", "export_request",
                "generate_csrf_poc", "extract_from_response", "payload_process", "scan_results", "scan_issue_detail",
                "get_scope", "search_history", "compare", "export_config", "cookie_jar", "token_analysis",
                "sequencer", "export_cert", "burp_version", "extensions_list", "websocket_list", "passive_intel",
                "session_list_rules", "jwt_decode", "jwt_attack", "scope_gate", "privacy_mode", "audit_log",
                "websocket_send");
        active(rules, "request.send", TargetMode.NETWORK, true, "send_request", "send_request_parallel");
        active(rules, "replay.send", TargetMode.NETWORK, true, "send_to_repeater", "repeater_send", "repeater_modify_send");
        active(rules, "intruder.run", TargetMode.NETWORK, true, "send_to_intruder", "intruder_attack", "intruder_attack_async",
                "intruder_attack_wordlist", "intruder_pitchfork", "intruder_cluster_bomb", "intruder_battering_ram", "intruder_with_options");
        active(rules, "scan.active", TargetMode.NETWORK, true, "scan", "scan_active", "injection_probe", "access_control_sweep", "race_condition", "inline_fuzzer");
        active(rules, "crawl.run", TargetMode.NETWORK, true, "crawl");
        active(rules, "burp.scope.write", TargetMode.NETWORK, true, "add_to_scope", "remove_from_scope");
        active(rules, "proxy.write", TargetMode.NONE, false, "proxy_match_replace", "proxy_clear", "intercept_toggle", "intercept_modify",
                "register_proxy_rule", "remove_proxy_rule");
        active(rules, "burp.config.write", TargetMode.NONE, false, "import_config", "set_upstream_proxy", "set_dns_override", "set_http2",
                "session_create_rule", "session_remove_rule", "register_http_handler", "remove_http_handler");
        active(rules, "cookie.write", TargetMode.NETWORK, true, "cookie_jar_set");
        active(rules, "websocket.send", TargetMode.NETWORK, true, "websocket_create", "websocket_send_text",
                "websocket_send_binary", "websocket_close");
        active(rules, "project.write", TargetMode.FILE, true, "save_project");
        active(rules, "collaborator.generate", TargetMode.NONE, false, "collaborator_generate");
        active(rules, "collaborator.poll", TargetMode.NONE, false, "collaborator_poll");
        active(rules, "burp.metadata.write", TargetMode.NONE, false, "highlight", "annotate", "add_issue");
        active(rules, "burp.log.write", TargetMode.NONE, false, "log");
        return Map.copyOf(rules);
    }

    private static void passive(Map<String, Rule> rules, String... tools) {
        for (String tool : tools) rules.put(tool, Rule.passive());
    }

    private static void active(Map<String, Rule> rules, String action, TargetMode targetMode, boolean targetRequired, String... tools) {
        Capabilities capabilities = new Capabilities(false, targetMode == TargetMode.NETWORK, action.contains("cookie"),
                true, true, true, targetMode == TargetMode.FILE, targetMode == TargetMode.FILE, false, true);
        for (String tool : tools) rules.put(tool, new Rule(action, targetMode, targetRequired, capabilities));
    }

    private record Rule(String action, TargetMode targetMode, boolean targetRequired, Capabilities capabilities) {
        static Rule passive() {
            return new Rule("passive.read", TargetMode.NONE, false, PASSIVE);
        }
    }

    private static final class TargetRef {
        private final URI uri;
        private final Path path;
        private final String description;

        private TargetRef(URI uri, Path path, String description) {
            this.uri = uri;
            this.path = path;
            this.description = description;
        }
    }

    private static List<TargetRef> extractTargets(JsonObject params, TargetMode mode) {
        LinkedHashMap<String, TargetRef> targets = new LinkedHashMap<>();
        collectTargets(params, mode, targets, 0);
        if (mode == TargetMode.NETWORK && targets.isEmpty()) addHostTarget(params, targets);
        if (mode == TargetMode.FILE) {
            for (String key : FILE_KEYS) {
                if (params.has(key) && params.get(key).isJsonPrimitive()) addFileTarget(params.get(key).getAsString(), targets);
            }
        }
        return List.copyOf(targets.values());
    }

    private static void collectTargets(JsonObject object, TargetMode mode, Map<String, TargetRef> targets, int depth) {
        if (object == null || depth > 3) return;
        for (var entry : object.entrySet()) {
            String key = entry.getKey().toLowerCase(Locale.ROOT);
            JsonElement value = entry.getValue();
            if (value == null || value.isJsonNull()) continue;
            if (mode == TargetMode.NETWORK && URL_KEYS.contains(key) && value.isJsonPrimitive()) {
                addUriTarget(value.getAsString(), targets);
            } else if (mode == TargetMode.FILE && FILE_KEYS.contains(key) && value.isJsonPrimitive()) {
                addFileTarget(value.getAsString(), targets);
            } else if (value.isJsonArray() && (key.equals("urls") || key.equals("requests") || key.equals("targets"))) {
                for (JsonElement item : value.getAsJsonArray()) {
                    if (item.isJsonObject()) collectTargets(item.getAsJsonObject(), mode, targets, depth + 1);
                    else if (item.isJsonPrimitive() && mode == TargetMode.NETWORK) addUriTarget(item.getAsString(), targets);
                }
            } else if (value.isJsonObject() && (key.equals("request") || key.equals("target"))) {
                collectTargets(value.getAsJsonObject(), mode, targets, depth + 1);
            }
        }
        if (mode == TargetMode.NETWORK && object.has("request") && object.get("request").isJsonPrimitive()) {
            addRawRequestTarget(object, object.get("request").getAsString(), targets);
        }
        if (mode == TargetMode.NETWORK && object.has("template") && object.get("template").isJsonPrimitive()) {
            addRawRequestTarget(object, object.get("template").getAsString(), targets);
        }
    }

    private static void addHostTarget(JsonObject params, Map<String, TargetRef> targets) {
        if (!params.has("host") || !params.get("host").isJsonPrimitive()) return;
        String host = params.get("host").getAsString().trim();
        if (host.isEmpty() || host.contains("*") || host.contains("/")) return;
        int port = params.has("port") ? safeInt(params.get("port"), 443) : 443;
        boolean https = params.has("https") ? safeBoolean(params.get("https"), port == 443) : port == 443;
        String path = params.has("path") && params.get("path").isJsonPrimitive() ? params.get("path").getAsString() : "/";
        addBuiltUri(https ? "https" : "http", host, port, path, targets);
    }

    private static void addRawRequestTarget(JsonObject params, String rawRequest, Map<String, TargetRef> targets) {
        if (rawRequest == null || rawRequest.isBlank()) return;
        String host = params.has("host") && params.get("host").isJsonPrimitive() ? params.get("host").getAsString().trim() : "";
        int port = params.has("port") ? safeInt(params.get("port"), 443) : -1;
        boolean https = params.has("https") ? safeBoolean(params.get("https"), true) : true;
        String path = "/";
        String[] lines = rawRequest.split("\\r?\\n");
        if (lines.length > 0) {
            String[] requestLine = lines[0].trim().split("\\s+");
            if (requestLine.length >= 2 && requestLine[1].startsWith("/")) path = requestLine[1];
        }
        if (host.isEmpty()) {
            for (String line : lines) {
                if (line.regionMatches(true, 0, "Host:", 0, 5)) {
                    String authority = line.substring(5).trim();
                    int separator = authority.lastIndexOf(':');
                    if (separator > 0 && authority.indexOf(':') == separator) {
                        host = authority.substring(0, separator);
                        try { port = Integer.parseInt(authority.substring(separator + 1)); } catch (NumberFormatException ignored) { return; }
                    } else host = authority;
                    break;
                }
            }
        }
        if (port < 1) port = https ? 443 : 80;
        addBuiltUri(https ? "https" : "http", host, port, path, targets);
    }

    private static void addBuiltUri(String scheme, String host, int port, String path, Map<String, TargetRef> targets) {
        if (host == null || host.isBlank() || port < 1 || port > 65535) return;
        try {
            String safePath = path == null || path.isBlank() ? "/" : path;
            int query = safePath.indexOf('?');
            String pathPart = query >= 0 ? safePath.substring(0, query) : safePath;
            String queryPart = query >= 0 ? safePath.substring(query + 1) : null;
            URI uri = new URI(scheme, null, host, port, pathPart, queryPart, null);
            addTarget(uri, targets);
        } catch (Exception ignored) {
        }
    }

    private static void addUriTarget(String value, Map<String, TargetRef> targets) {
        if (value == null || value.isBlank()) return;
        try {
            URI uri = URI.create(value.trim());
            if (!("http".equalsIgnoreCase(uri.getScheme()) || "https".equalsIgnoreCase(uri.getScheme()))) return;
            if (uri.getHost() == null || uri.getUserInfo() != null || uri.getFragment() != null) return;
            addTarget(uri, targets);
        } catch (RuntimeException ignored) {
        }
    }

    private static void addTarget(URI uri, Map<String, TargetRef> targets) {
        int port = uri.getPort() >= 0 ? uri.getPort() : ("https".equalsIgnoreCase(uri.getScheme()) ? 443 : 80);
        String path = uri.getPath() == null || uri.getPath().isBlank() ? "/" : uri.getPath();
        String description = uri.getScheme().toLowerCase(Locale.ROOT) + "://" + uri.getHost().toLowerCase(Locale.ROOT) + ":" + port + path;
        targets.putIfAbsent(description, new TargetRef(uri, null, description));
    }

    private static void addFileTarget(String value, Map<String, TargetRef> targets) {
        if (value == null || value.isBlank() || value.contains("*") || value.contains("?")) return;
        try {
            Path path = Path.of(value).toAbsolutePath().normalize();
            String description = path.toString();
            targets.putIfAbsent(description, new TargetRef(null, path, description));
        } catch (RuntimeException ignored) {
        }
    }

    private static String joinTargets(List<TargetRef> targets) {
        return targets.stream().map(target -> target.description).sorted().reduce((left, right) -> left + "," + right).orElse("");
    }

    private static int safeInt(JsonElement value, int fallback) {
        try { return value.getAsInt(); } catch (RuntimeException exception) { return fallback; }
    }

    private static boolean safeBoolean(JsonElement value, boolean fallback) {
        try { return value.getAsBoolean(); } catch (RuntimeException exception) { return fallback; }
    }

    private static String digest(JsonObject params) {
        try {
            JsonObject copy = params == null ? new JsonObject() : params.deepCopy();
            copy.remove("_confirmationToken");
            copy.remove("confirmationToken");
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(canonical(copy).getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to calculate request digest", exception);
        }
    }

    private static String canonical(JsonElement element) {
        if (element == null || element.isJsonNull()) return "null";
        if (element.isJsonArray()) {
            StringBuilder output = new StringBuilder("[");
            boolean first = true;
            for (JsonElement item : element.getAsJsonArray()) {
                if (!first) output.append(',');
                output.append(canonical(item));
                first = false;
            }
            return output.append(']').toString();
        }
        if (element.isJsonObject()) {
            StringBuilder output = new StringBuilder("{");
            List<Map.Entry<String, JsonElement>> entries = new ArrayList<>(element.getAsJsonObject().entrySet());
            entries.sort(Comparator.comparing(Map.Entry::getKey));
            boolean first = true;
            for (var entry : entries) {
                if (!first) output.append(',');
                output.append(new JsonPrimitive(entry.getKey())).append(':').append(canonical(entry.getValue()));
                first = false;
            }
            return output.append('}').toString();
        }
        return element.toString();
    }
}
