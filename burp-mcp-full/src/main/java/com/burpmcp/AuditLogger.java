package com.burpmcp;

import com.google.gson.Gson;
import com.google.gson.JsonObject;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Clock;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

final class AuditLogger {
    private static final int MAX_IN_MEMORY = 1000;
    private final Gson gson = new Gson();
    private final Path path;
    private final PrivacyRedactor redactor;
    private final Clock clock;
    private final Deque<String> entries = new ArrayDeque<>();

    AuditLogger(Path path, PrivacyRedactor redactor) {
        this(path, redactor, Clock.systemUTC());
    }

    AuditLogger(Path path, PrivacyRedactor redactor, Clock clock) {
        this.path = path;
        this.redactor = redactor;
        this.clock = clock;
    }

    synchronized void record(String outcome, String tool, String target, String reason, String parameterDigest) {
        JsonObject event = new JsonObject();
        event.addProperty("timestamp", clock.instant().toString());
        event.addProperty("outcome", safe(outcome));
        event.addProperty("tool", safe(tool));
        event.addProperty("target", redactor.redactTarget(safe(target)));
        event.addProperty("reason", redactor.redactText(safe(reason)));
        event.addProperty("parameterDigest", safe(parameterDigest));
        String line = gson.toJson(event);
        entries.addLast(line);
        while (entries.size() > MAX_IN_MEMORY) entries.removeFirst();
        if (path == null) return;
        try {
            Path parent = path.getParent();
            if (parent != null) Files.createDirectories(parent);
            Files.writeString(path, line + System.lineSeparator(), StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE, StandardOpenOption.WRITE, StandardOpenOption.APPEND);
        } catch (IOException ignored) {
        }
    }

    synchronized List<String> recent(int limit) {
        int safeLimit = Math.max(0, Math.min(limit, MAX_IN_MEMORY));
        List<String> all = new ArrayList<>(entries);
        return List.copyOf(all.subList(Math.max(0, all.size() - safeLimit), all.size()));
    }

    private static String safe(String value) {
        return value == null ? "" : value;
    }
}
