package com.burpmcp;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonNull;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class PrivacyRedactor {
    static final String REDACTED = "[REDACTED]";
    private static final Pattern HEADER = Pattern.compile("(?im)^(authorization|proxy-authorization|cookie|set-cookie)\\s*:\\s*.*$");
    private static final Pattern QUERY_SECRET = Pattern.compile("(?i)([?&](?:token|access_token|refresh_token|api_?key|key|secret|password|passwd|auth|authorization|signature|sig)=)[^&#\\s]*");
    private static final Pattern JSON_SECRET = Pattern.compile("(?i)(\"(?:authorization|cookie|set-cookie|token|access_token|refresh_token|api_?key|secret|password|passwd|body|request_body)\"\\s*:\\s*)\"(?:\\\\.|[^\"])*\"");
    private static final Pattern AWS_ACCESS_KEY = Pattern.compile("\\bAKIA[0-9A-Z]{16}\\b");
    private static final Pattern SLACK_TOKEN = Pattern.compile("\\bxox[baprs]-[A-Za-z0-9-]{20,}\\b");
    private static final Pattern JWT = Pattern.compile("\\beyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\b");
    private static final Pattern PRIVATE_KEY = Pattern.compile(
            "-----BEGIN(?: [A-Z0-9]+)? PRIVATE KEY-----.*?-----END(?: [A-Z0-9]+)? PRIVATE KEY-----",
            Pattern.DOTALL);
    private static final Set<String> SENSITIVE_KEYS = Set.of(
            "authorization", "proxy-authorization", "cookie", "set-cookie", "token", "access_token",
            "refresh_token", "apikey", "api_key", "secret", "password", "passwd", "request_body",
            "response_body", "body", "raw_request", "raw_response", "request", "response"
    );

    JsonElement redact(JsonElement input) {
        if (input == null || input.isJsonNull()) return JsonNull.INSTANCE;
        if (input.isJsonArray()) {
            JsonArray output = new JsonArray();
            for (JsonElement element : input.getAsJsonArray()) output.add(redact(element));
            return output;
        }
        if (input.isJsonObject()) {
            JsonObject output = new JsonObject();
            JsonObject object = input.getAsJsonObject();
            boolean redactStructuredValue = isCookieRecord(object) || isSensitiveHeaderRecord(object);
            for (var entry : object.entrySet()) {
                String key = entry.getKey();
                if (isSensitiveKey(key) || redactStructuredValue && "value".equalsIgnoreCase(key)) {
                    output.addProperty(key, REDACTED);
                }
                else output.add(key, redact(entry.getValue()));
            }
            return output;
        }
        if (input.isJsonPrimitive() && input.getAsJsonPrimitive().isString()) {
            return new JsonPrimitive(redactText(input.getAsString()));
        }
        return input.deepCopy();
    }

    String redactText(String input) {
        if (input == null || input.isEmpty()) return input;
        String value = PRIVATE_KEY.matcher(input).replaceAll(REDACTED);
        value = HEADER.matcher(value).replaceAll("$1: " + REDACTED);
        value = QUERY_SECRET.matcher(value).replaceAll("$1" + REDACTED);
        Matcher jsonMatcher = JSON_SECRET.matcher(value);
        value = jsonMatcher.replaceAll("$1\"" + REDACTED + "\"");
        value = AWS_ACCESS_KEY.matcher(value).replaceAll(REDACTED);
        value = SLACK_TOKEN.matcher(value).replaceAll(REDACTED);
        value = JWT.matcher(value).replaceAll(REDACTED);
        return value;
    }

    String redactTarget(String target) {
        if (target == null || target.isBlank()) return target;
        try {
            URI uri = new URI(target);
            if (uri.getRawQuery() == null) return redactText(target);
            String redactedQuery = QUERY_SECRET.matcher("?" + uri.getRawQuery()).replaceAll("$1" + REDACTED).substring(1);
            return new URI(uri.getScheme(), uri.getRawAuthority(), uri.getRawPath(), redactedQuery, null).toString();
        } catch (URISyntaxException | RuntimeException exception) {
            return redactText(target);
        }
    }

    String parameterSummary(JsonObject params) {
        if (params == null || params.size() == 0) return "{}";
        StringBuilder summary = new StringBuilder("keys=");
        boolean first = true;
        for (String key : params.keySet()) {
            if (key.startsWith("_confirmation")) continue;
            if (!first) summary.append(',');
            summary.append(key);
            first = false;
        }
        return summary.toString();
    }

    private static boolean isSensitiveKey(String key) {
        if (key == null) return false;
        String normalized = key.toLowerCase(Locale.ROOT).replace('-', '_');
        return SENSITIVE_KEYS.contains(normalized) || normalized.endsWith("_token") || normalized.endsWith("_secret") || normalized.endsWith("_password");
    }

    private static boolean isCookieRecord(JsonObject object) {
        return object.has("name") && object.has("value") && (object.has("domain") || object.has("path"));
    }

    private static boolean isSensitiveHeaderRecord(JsonObject object) {
        if (!object.has("name") || !object.has("value") || !object.get("name").isJsonPrimitive()) return false;
        String name = object.get("name").getAsString().toLowerCase(Locale.ROOT);
        return Set.of("authorization", "proxy-authorization", "cookie", "set-cookie").contains(name);
    }
}
