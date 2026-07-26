package com.burpmcp;

import javax.swing.JOptionPane;
import javax.swing.SwingUtilities;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

final class ConfirmationProvider {
    enum ConsumeStatus { VALID, INVALID, EXPIRED, REPLAYED }

    interface ApprovalPrompt {
        boolean approve(String tool, String target, String parameterSummary);
    }

    static final class IssueResult {
        private final boolean approved;
        private final String token;

        IssueResult(boolean approved, String token) {
            this.approved = approved;
            this.token = token;
        }

        boolean approved() {
            return approved;
        }

        String token() {
            return token;
        }
    }

    private static final Duration TOKEN_LIFETIME = Duration.ofMinutes(5);
    private final SecureRandom random;
    private final Clock clock;
    private final ApprovalPrompt prompt;
    private final Map<String, Entry> active = new HashMap<>();
    private final Map<String, Instant> used = new HashMap<>();

    ConfirmationProvider(ApprovalPrompt prompt) {
        this(prompt, Clock.systemUTC(), new SecureRandom());
    }

    ConfirmationProvider(ApprovalPrompt prompt, Clock clock, SecureRandom random) {
        this.prompt = prompt;
        this.clock = clock;
        this.random = random;
    }

    static ConfirmationProvider swing() {
        return new ConfirmationProvider((tool, target, summary) -> {
            AtomicBoolean approved = new AtomicBoolean(false);
            Runnable dialog = () -> approved.set(JOptionPane.showConfirmDialog(
                    null,
                    "Tool: " + tool + "\nTarget: " + target + "\nParameters: " + summary,
                    "Burp MCP active operation confirmation",
                    JOptionPane.YES_NO_OPTION,
                    JOptionPane.WARNING_MESSAGE
            ) == JOptionPane.YES_OPTION);
            try {
                if (SwingUtilities.isEventDispatchThread()) dialog.run();
                else SwingUtilities.invokeAndWait(dialog);
            } catch (Exception exception) {
                return false;
            }
            return approved.get();
        });
    }

    synchronized IssueResult issue(String tool, String target, String parameterDigest, String parameterSummary) {
        cleanup();
        if (!prompt.approve(tool, target, parameterSummary)) return new IssueResult(false, null);
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        active.put(token, new Entry(tool, target, parameterDigest, clock.instant().plus(TOKEN_LIFETIME)));
        return new IssueResult(true, token);
    }

    synchronized ConsumeStatus consume(String token, String tool, String target, String parameterDigest) {
        cleanup();
        Instant usedUntil = used.get(token);
        if (usedUntil != null) return ConsumeStatus.REPLAYED;
        Entry entry = active.remove(token);
        if (entry == null) return ConsumeStatus.INVALID;
        Instant now = clock.instant();
        if (!entry.expiresAt.isAfter(now)) {
            used.put(token, now.plus(TOKEN_LIFETIME));
            return ConsumeStatus.EXPIRED;
        }
        if (!entry.tool.equals(tool) || !entry.target.equals(target) || !entry.parameterDigest.equals(parameterDigest)) {
            return ConsumeStatus.INVALID;
        }
        used.put(token, now.plus(TOKEN_LIFETIME));
        return ConsumeStatus.VALID;
    }

    private void cleanup() {
        Instant now = clock.instant();
        Iterator<Map.Entry<String, Entry>> activeIterator = active.entrySet().iterator();
        while (activeIterator.hasNext()) {
            Instant retentionEnd = activeIterator.next().getValue().expiresAt.plus(TOKEN_LIFETIME);
            if (!retentionEnd.isAfter(now)) activeIterator.remove();
        }
        Iterator<Map.Entry<String, Instant>> usedIterator = used.entrySet().iterator();
        while (usedIterator.hasNext()) if (!usedIterator.next().getValue().isAfter(now)) usedIterator.remove();
    }

    private static final class Entry {
        private final String tool;
        private final String target;
        private final String parameterDigest;
        private final Instant expiresAt;

        private Entry(String tool, String target, String parameterDigest, Instant expiresAt) {
            this.tool = tool;
            this.target = target;
            this.parameterDigest = parameterDigest;
            this.expiresAt = expiresAt;
        }
    }
}
