package com.burpmcp;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

final class BurpMcpSecurityConfig {
    static final int MAX_REQUEST_BODY_BYTES = 1024 * 1024;
    static final int REQUEST_TIMEOUT_SECONDS = 30;
    static final int MAX_ACTIVE_OPERATIONS = 2;
    private static final int MIN_TOKEN_LENGTH = 32;

    private final String token;
    private final Set<String> allowedOrigins;
    private final Path scopeFile;
    private final Path auditLog;
    private final int port;

    private BurpMcpSecurityConfig(String token, Set<String> allowedOrigins, Path scopeFile, Path auditLog, int port) {
        this.token = validateToken(token);
        this.allowedOrigins = Collections.unmodifiableSet(new LinkedHashSet<>(allowedOrigins));
        this.scopeFile = scopeFile;
        this.auditLog = auditLog;
        this.port = port;
    }

    static BurpMcpSecurityConfig load(int port) {
        String token = firstNonBlank(System.getProperty("burpmcp.token"), System.getenv("BURP_MCP_TOKEN"));
        String origins = firstNonBlank(System.getProperty("burpmcp.allowedOrigins"), System.getenv("BURP_MCP_ALLOWED_ORIGINS"));
        String scope = firstNonBlank(System.getProperty("burpmcp.scopeFile"), System.getenv("BURP_MCP_SCOPE_FILE"));
        String audit = firstNonBlank(System.getProperty("burpmcp.auditLog"), System.getenv("BURP_MCP_AUDIT_LOG"));
        Path scopeFile = scope == null ? null : Path.of(scope).toAbsolutePath().normalize();
        Path auditLog = audit == null
                ? Path.of(System.getProperty("user.home"), ".burp-mcp", "audit.jsonl").toAbsolutePath().normalize()
                : Path.of(audit).toAbsolutePath().normalize();
        return new BurpMcpSecurityConfig(token, parseOrigins(origins), scopeFile, auditLog, port);
    }

    static BurpMcpSecurityConfig forTests(String token, Set<String> origins, Path scopeFile, Path auditLog, int port) {
        Set<String> normalized = new LinkedHashSet<>();
        for (String origin : origins) normalized.add(normalizeOrigin(origin));
        return new BurpMcpSecurityConfig(token, normalized, scopeFile, auditLog, port);
    }

    boolean isAuthorized(String authorizationHeader) {
        if (authorizationHeader == null || !authorizationHeader.regionMatches(true, 0, "Bearer ", 0, 7)) return false;
        byte[] expected = token.getBytes(StandardCharsets.UTF_8);
        byte[] supplied = authorizationHeader.substring(7).trim().getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(expected, supplied);
    }

    boolean isOriginAllowed(String origin) {
        if (origin == null || origin.isBlank()) return false;
        try {
            return allowedOrigins.contains(normalizeOrigin(origin));
        } catch (IllegalArgumentException exception) {
            return false;
        }
    }

    boolean isHostAllowed(String hostHeader) {
        if (hostHeader == null || hostHeader.isBlank()) return false;
        String value = hostHeader.trim().toLowerCase(Locale.ROOT);
        String host;
        Integer requestPort = null;
        if (value.startsWith("[")) {
            int end = value.indexOf(']');
            if (end < 0) return false;
            host = value.substring(1, end);
            if (value.length() > end + 1) {
                if (value.charAt(end + 1) != ':') return false;
                requestPort = parsePort(value.substring(end + 2));
                if (requestPort == null) return false;
            }
        } else {
            int separator = value.lastIndexOf(':');
            if (separator > 0 && value.indexOf(':') == separator) {
                host = value.substring(0, separator);
                requestPort = parsePort(value.substring(separator + 1));
                if (requestPort == null) return false;
            } else {
                host = value;
            }
        }
        if (!Set.of("127.0.0.1", "localhost", "::1").contains(host)) return false;
        return requestPort == null || requestPort == port;
    }

    Set<String> allowedOrigins() {
        return allowedOrigins;
    }

    Path scopeFile() {
        return scopeFile;
    }

    Path auditLog() {
        return auditLog;
    }

    int port() {
        return port;
    }

    private static String validateToken(String token) {
        if (token == null || token.isBlank()) throw new IllegalStateException("BURP_MCP_TOKEN or -Dburpmcp.token is required");
        String value = token.trim();
        if (value.length() < MIN_TOKEN_LENGTH) throw new IllegalStateException("Burp MCP bearer token must be at least 32 characters");
        return value;
    }

    private static Set<String> parseOrigins(String raw) {
        Set<String> origins = new LinkedHashSet<>();
        if (raw == null || raw.isBlank()) return origins;
        for (String value : raw.split(",")) {
            if (!value.isBlank()) origins.add(normalizeOrigin(value));
        }
        return origins;
    }

    private static String normalizeOrigin(String raw) {
        URI uri;
        try {
            uri = URI.create(raw.trim());
        } catch (Exception exception) {
            throw new IllegalArgumentException("Invalid allowed Origin: " + raw, exception);
        }
        String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
        String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
        if (!(scheme.equals("http") || scheme.equals("https")) || host.isBlank()
                || uri.getRawPath() != null && !uri.getRawPath().isEmpty()
                || uri.getRawQuery() != null || uri.getRawFragment() != null || uri.getUserInfo() != null) {
            throw new IllegalArgumentException("Allowed Origin must be an exact http(s) origin: " + raw);
        }
        int port = uri.getPort();
        return scheme + "://" + host + (port < 0 ? "" : ":" + port);
    }

    private static Integer parsePort(String raw) {
        try {
            int value = Integer.parseInt(raw);
            return value >= 1 && value <= 65535 ? value : null;
        } catch (NumberFormatException exception) {
            return null;
        }
    }

    private static String firstNonBlank(String first, String second) {
        if (first != null && !first.isBlank()) return first;
        if (second != null && !second.isBlank()) return second;
        return null;
    }
}
