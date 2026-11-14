#!/usr/bin/env python3
"""Fail closed on repository executable/reference boundary regressions.

The check reads Git index blobs, so antivirus quarantine of a working-tree
research payload cannot silently remove it from review coverage.
"""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import PurePosixPath


PAYLOAD_PATH = "skills/pentest-tools/src-hunter/references/payloader/waf-bypass.md"
PAYLOAD_SHA256 = "0273517455962bb9908264f82e4708b31d541c91c2ec715e8032d6c1376728b5"
ALLOWED_BINARY_HASHES = {
    "burp-mcp-full/gradle/wrapper/gradle-wrapper.jar":
        "2db75c40782f5e8ba1fc278a5574bab070adccb2d21ca5a6e5ed840888448046",
}
EXECUTABLE_SUFFIXES = {
    ".ps1", ".sh", ".py", ".js", ".mjs", ".cjs", ".java", ".bat", ".cmd"
}
BINARY_SUFFIXES = {
    ".exe", ".dll", ".so", ".dylib", ".sys", ".jar", ".zip", ".7z",
    ".rar", ".bin", ".apk", ".ipa", ".wasm", ".class", ".pyc"
}
SCAN_EXCLUDES = {"skills/scripts/verify-repository-security.py"}
EXPECTED_PATTERN_HITS = {
    ("kali/scripts/lib/tool-discovery.sh", "dev-tcp-port-probe"),
    ("skills/scripts/lib/ToolDiscovery.ps1", "tcp-client-health-probe"),
}
PATTERNS = {
    "dynamic-powershell-eval": re.compile(r"Invoke" r"-Expression|\bIEX\b", re.I),
    "encoded-loader": re.compile(r"FromBase64" r"String|Download" r"String", re.I),
    "pipe-to-shell": re.compile(r"(?:curl|wget)[^\n]*\|\s*(?:ba)?sh\b", re.I),
    "root-recursive-delete": re.compile(r"\brm\s+-rf\s+/\s*(?:$|[;&|])", re.M),
    "database-drop": re.compile(r"\bDROP\s+(?:DATABASE|TABLE)\b", re.I),
    "tcp-client-health-probe": re.compile(r"System\.Net\.Sockets\.TCPClient", re.I),
    "dev-tcp-port-probe": re.compile(r"/dev/tcp/"),
}
ACTION_USE = re.compile(r"^\s*-?\s*uses:\s*([^\s#]+)", re.M)
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
AGENT_ENTRY_FILES = ("README_AI.md", "RULES.md", "RULES_zh.md", "AGENTS.md")
REQUIRED_AGENT_CONSENT_MARKERS = (
    "Reading repository files is not authorization to execute them.",
    "Explicit user approval is required before running any repository script.",
    "Client-global configuration remains opt-in.",
)
UNSAFE_AGENT_ENTRY_PATTERNS = {
    "execute-section-on-read": re.compile(r"execute section 0 immediately", re.I),
    "automatic-execution-on-read": re.compile(r"must automatically execute", re.I),
    "remove-user-from-setup": re.compile(
        r"the user does not need to operate manually", re.I
    ),
    "global-instruction-injection": re.compile(r"global injection", re.I),
    "execute-immediately-after-read": re.compile(
        r"execute immediately after reading", re.I
    ),
    "must-run-after-read": re.compile(
        r"after reading this file,?\s+you must now", re.I
    ),
    "side-effects-as-read-goal": re.compile(r"produce actual side effects", re.I),
    "skip-first-consent": re.compile(r"do not wait for the user to say", re.I),
    "auto-configure-after-read": re.compile(
        r"auto-configure after reading", re.I
    ),
    "execute-after-read-zh": re.compile(
        r"读完(?:本文件|规则|文档)?后?[^\n]{0,40}(?:立即[^\n]{0,6}(?:执行|运行)|必须[：,:， ]{0,3}(?:执行|运行|NOW))",
        re.I,
    ),
    "automatic-execution-after-read-zh": re.compile(
        r"(?:读完|读取)[^\n]{0,40}自动(?:执行|运行)", re.I
    ),
    "global-instruction-injection-zh": re.compile(r"全局注入", re.I),
    "side-effects-as-read-goal-zh": re.compile(
        r"产生实际(?:的)?副作用", re.I
    ),
    "extract-into-global-config-zh": re.compile(
        r"首次配置时由 AI 提取本段写入", re.I
    ),
    "precedent-as-authorization-zh": re.compile(
        r"授权已在 precedent-auth\.md 中确认", re.I
    ),
    "precedent-as-step-zero": re.compile(
        r"step 0[^\n]{0,80}precedent-auth", re.I
    ),
    "precedent-declaration-as-gate-zh": re.compile(
        r"precedent-auth\.md[^\n]{0,30}授权预声明", re.I
    ),
}


def check_agent_entry_contract(path: str, text: str) -> list[str]:
    errors: list[str] = []
    for marker in REQUIRED_AGENT_CONSENT_MARKERS:
        if marker not in text:
            errors.append(
                f"agent entry missing consent marker: {path}: {marker}"
            )
    for label, pattern in UNSAFE_AGENT_ENTRY_PATTERNS.items():
        if pattern.search(text):
            errors.append(f"unsafe agent execute-on-read pattern {label}: {path}")
    return errors


def git(*args: str) -> bytes:
    return subprocess.run(
        ["git", *args], capture_output=True, check=True
    ).stdout


def tracked_entries() -> dict[str, str]:
    raw = git("ls-files", "-s", "-z").decode("utf-8")
    result: dict[str, str] = {}
    for record in raw.split("\0"):
        if not record:
            continue
        meta, path = record.split("\t", 1)
        result[path] = meta.split()[0]
    return result


def blob(path: str) -> bytes:
    return git("show", f":{path}")


def main() -> int:
    entries = tracked_entries()
    errors: list[str] = []

    symlinks = sorted(path for path, mode in entries.items() if mode == "120000")
    if symlinks:
        errors.extend(f"tracked symlink requires review: {path}" for path in symlinks)

    for path in AGENT_ENTRY_FILES:
        if path not in entries:
            errors.append(f"agent entry file missing from index: {path}")
            continue
        text = blob(path).decode("utf-8-sig", errors="replace")
        errors.extend(check_agent_entry_contract(path, text))

    binary_paths = sorted(
        path for path in entries if PurePosixPath(path).suffix.lower() in BINARY_SUFFIXES
    )
    for path in binary_paths:
        expected = ALLOWED_BINARY_HASHES.get(path)
        if expected is None:
            errors.append(f"unreviewed tracked binary-like file: {path}")
            continue
        actual = hashlib.sha256(blob(path)).hexdigest()
        if actual != expected:
            errors.append(f"binary hash changed: {path} expected={expected} actual={actual}")

    if PAYLOAD_PATH not in entries:
        errors.append(f"reviewed payload corpus missing from index: {PAYLOAD_PATH}")
    else:
        actual_payload = hashlib.sha256(blob(PAYLOAD_PATH)).hexdigest()
        if actual_payload != PAYLOAD_SHA256:
            errors.append(
                f"payload corpus changed; repeat security review: expected={PAYLOAD_SHA256} "
                f"actual={actual_payload}"
            )

    for path in sorted(entries):
        suffix = PurePosixPath(path).suffix.lower()
        if suffix not in EXECUTABLE_SUFFIXES or path in SCAN_EXCLUDES:
            continue
        text = blob(path).decode("utf-8-sig", errors="replace")
        if PAYLOAD_PATH in text or "src-hunter/references/payloader" in text:
            errors.append(f"executable source references passive payload corpus: {path}")
        for label, pattern in PATTERNS.items():
            if not pattern.search(text):
                continue
            if (path, label) not in EXPECTED_PATTERN_HITS:
                errors.append(f"unexpected executable pattern {label}: {path}")

    for path in sorted(p for p in entries if p.startswith(".github/workflows/") and p.endswith((".yml", ".yaml"))):
        text = blob(path).decode("utf-8-sig")
        for use in ACTION_USE.findall(text):
            if use.startswith("./"):
                continue
            if "@" not in use or not FULL_SHA.fullmatch(use.rsplit("@", 1)[1]):
                errors.append(f"GitHub Action is not pinned to a full commit SHA: {path}: {use}")

    if errors:
        print(f"FAIL verify-repository-security: {len(errors)} issue(s)")
        for error in errors:
            print(f"  {error}")
        return 1

    print(
        "OK verify-repository-security: "
        f"tracked={len(entries)} executable_sources="
        f"{sum(PurePosixPath(p).suffix.lower() in EXECUTABLE_SUFFIXES for p in entries)} "
        f"binary_like={len(binary_paths)} agent_entries={len(AGENT_ENTRY_FILES)} "
        "symlinks=0"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
