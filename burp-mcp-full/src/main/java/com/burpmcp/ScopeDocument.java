package com.burpmcp;

import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;

import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

final class ScopeDocument {
    private static final Gson GSON = new Gson();
    private final String schemaVersion;
    private final String scopeId;
    private final String status;
    private final String approvalId;
    private final String issuedAt;
    private final String expiresAt;
    private final List<Target> targets;
    private final List<String> allowedActions;

    private ScopeDocument(String schemaVersion, String scopeId, String status, String approvalId,
                          String issuedAt, String expiresAt, List<Target> targets, List<String> allowedActions) {
        this.schemaVersion = schemaVersion;
        this.scopeId = scopeId;
        this.status = status;
        this.approvalId = approvalId;
        this.issuedAt = issuedAt;
        this.expiresAt = expiresAt;
        this.targets = targets == null ? List.of() : List.copyOf(targets);
        this.allowedActions = allowedActions == null ? List.of() : List.copyOf(allowedActions);
    }

    static LoadResult load(Path path, boolean requireGranted) {
        List<String> issues = new ArrayList<>();
        if (path == null) {
            issues.add("scope file is not configured");
            return new LoadResult(null, issues);
        }
        if (!Files.isRegularFile(path)) {
            issues.add("scope file not found: " + path);
            return new LoadResult(null, issues);
        }
        Raw raw;
        try {
            raw = GSON.fromJson(Files.readString(path, StandardCharsets.UTF_8), Raw.class);
        } catch (IOException exception) {
            issues.add("scope JSON is invalid");
            return new LoadResult(null, issues);
        } catch (JsonSyntaxException | IllegalStateException exception) {
            issues.add("scope JSON is invalid");
            return new LoadResult(null, issues);
        }
        if (raw == null) {
            issues.add("scope document is empty");
            return new LoadResult(null, issues);
        }
        ScopeDocument document = new ScopeDocument(raw.schemaVersion, raw.scopeId, raw.status, raw.approvalId,
                raw.issuedAt, raw.expiresAt, raw.targets, raw.allowedActions);
        issues.addAll(document.validate(requireGranted));
        return new LoadResult(document, issues);
    }

    boolean isGranted() {
        return "granted".equals(status);
    }

    boolean isActionAllowed(String action) {
        return allowedActions.contains(action);
    }

    boolean hasTargets() {
        return !targets.isEmpty();
    }

    boolean matchesNetwork(URI candidate) {
        if (candidate == null || candidate.getScheme() == null || candidate.getHost() == null) return false;
        String scheme = candidate.getScheme().toLowerCase(Locale.ROOT);
        String host = candidate.getHost().toLowerCase(Locale.ROOT);
        int port = effectivePort(candidate);
        String path = candidate.getPath() == null || candidate.getPath().isEmpty() ? "/" : candidate.getPath();
        if (containsUnsafePath(candidate.getRawPath())) return false;
        for (Target target : targets) {
            if (!"network".equals(target.type)) continue;
            if (!scheme.equalsIgnoreCase(target.scheme) || !host.equalsIgnoreCase(target.host) || port != target.port) continue;
            for (String prefix : target.pathPrefixes == null ? List.<String>of() : target.pathPrefixes) {
                String normalized = normalizePrefix(prefix);
                if ("/".equals(normalized) || path.equals(normalized) || path.startsWith(normalized + "/")) return true;
            }
        }
        return false;
    }

    boolean matchesFile(Path candidate) {
        if (candidate == null) return false;
        Path normalized;
        try {
            normalized = candidate.toAbsolutePath().normalize();
        } catch (RuntimeException exception) {
            return false;
        }
        for (Target target : targets) {
            if (!"file".equals(target.type) || target.path == null) continue;
            try {
                if (normalized.equals(Path.of(target.path).toAbsolutePath().normalize())) return true;
            } catch (RuntimeException ignored) {
            }
        }
        return false;
    }

    List<String> targetDescriptions() {
        List<String> descriptions = new ArrayList<>();
        for (Target target : targets) descriptions.add(target.describe());
        return Collections.unmodifiableList(descriptions);
    }

    private List<String> validate(boolean requireGranted) {
        List<String> issues = new ArrayList<>();
        if (!"1".equals(schemaVersion)) issues.add("schemaVersion must be 1");
        if (blank(scopeId)) issues.add("scopeId is missing");
        if (!("draft".equals(status) || "granted".equals(status) || "denied".equals(status) || "expired".equals(status))) {
            issues.add("status is invalid");
        }
        if (blank(approvalId)) issues.add("approvalId is missing");
        Instant issued = parseInstant(issuedAt, "issuedAt", issues);
        Instant expires = parseInstant(expiresAt, "expiresAt", issues);
        if (issued != null && expires != null && !expires.isAfter(issued)) issues.add("expiresAt must be later than issuedAt");
        if ((isGranted() || requireGranted) && "granted".equals(status) && "FILL_ME".equals(approvalId)) {
            issues.add("approvalId must be user supplied");
        }
        if ((isGranted() || requireGranted) && !"granted".equals(status)) issues.add("scope status is not granted");
        if ((isGranted() || requireGranted) && expires != null && !expires.isAfter(Instant.now())) issues.add("scope is expired");
        if ((isGranted() || requireGranted) && targets.isEmpty()) issues.add("granted scope requires a target");
        if ((isGranted() || requireGranted) && allowedActions.isEmpty()) issues.add("granted scope requires an allowed action");
        Set<String> seenActions = new HashSet<>();
        for (String action : allowedActions) {
            if (blank(action) || !action.matches("^[a-z][a-z0-9_.:-]+$")) issues.add("allowedActions contains an invalid action");
            if (action != null && !seenActions.add(action)) issues.add("allowedActions contains a duplicate action");
        }
        for (Target target : targets) validateTarget(target, issues);
        return issues;
    }

    private static void validateTarget(Target target, List<String> issues) {
        if (target == null || target.type == null) {
            issues.add("target type is missing");
            return;
        }
        if ("network".equals(target.type)) {
            if (!("http".equalsIgnoreCase(target.scheme) || "https".equalsIgnoreCase(target.scheme))) issues.add("network target scheme is invalid");
            if (blank(target.host) || target.host.matches(".*[*\\s/].*")) issues.add("network target host must be exact");
            if (target.port < 1 || target.port > 65535) issues.add("network target port is invalid");
            if (target.pathPrefixes == null || target.pathPrefixes.isEmpty()) issues.add("network target pathPrefixes is empty");
            if (target.pathPrefixes != null) for (String prefix : target.pathPrefixes) {
                if (blank(prefix) || !prefix.startsWith("/") || prefix.contains("*") || prefix.contains("?")) issues.add("network target path prefix is invalid");
            }
        } else if ("file".equals(target.type)) {
            if (blank(target.path) || target.path.contains("*") || target.path.contains("?")) issues.add("file target path must be exact");
        } else {
            issues.add("target type is invalid");
        }
    }

    private static Instant parseInstant(String value, String field, List<String> issues) {
        if (blank(value)) {
            issues.add(field + " is missing");
            return null;
        }
        try {
            return Instant.parse(value);
        } catch (DateTimeParseException first) {
            try {
                return OffsetDateTime.parse(value).toInstant();
            } catch (DateTimeParseException second) {
                issues.add(field + " is invalid");
                return null;
            }
        }
    }

    private static int effectivePort(URI uri) {
        if (uri.getPort() >= 0) return uri.getPort();
        return "https".equalsIgnoreCase(uri.getScheme()) ? 443 : 80;
    }

    private static boolean containsUnsafePath(String rawPath) {
        if (rawPath == null) return false;
        String lower = rawPath.toLowerCase(Locale.ROOT);
        return rawPath.contains("\\") || lower.contains("%2f") || lower.contains("%5c") || lower.contains("%2e")
                || rawPath.contains("/../") || rawPath.endsWith("/..") || rawPath.contains("/./");
    }

    private static String normalizePrefix(String prefix) {
        if (prefix == null || prefix.isEmpty()) return "/";
        if (prefix.length() > 1) return prefix.replaceAll("/+\\z", "");
        return prefix;
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }

    static final class LoadResult {
        private final ScopeDocument document;
        private final List<String> issues;

        LoadResult(ScopeDocument document, List<String> issues) {
            this.document = document;
            this.issues = List.copyOf(issues);
        }

        ScopeDocument document() {
            return document;
        }

        List<String> issues() {
            return issues;
        }

        boolean valid() {
            return document != null && issues.isEmpty();
        }
    }

    private static final class Raw {
        String schemaVersion;
        String scopeId;
        String status;
        String approvalId;
        String issuedAt;
        String expiresAt;
        List<Target> targets;
        List<String> allowedActions;
    }

    private static final class Target {
        String type;
        String scheme;
        String host;
        int port;
        List<String> pathPrefixes;
        String path;

        String describe() {
            if ("file".equals(type)) return "file:" + path;
            StringBuilder value = new StringBuilder().append(scheme).append("://").append(host).append(':').append(port);
            if (pathPrefixes != null && !pathPrefixes.isEmpty()) value.append(pathPrefixes.get(0));
            return value.toString();
        }
    }
}
