#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REFRESH="$SCRIPT_DIR/refresh-tool-index.sh"
DISCOVERY="$SCRIPT_DIR/lib/tool-discovery.sh"
BOOTSTRAP="$SCRIPT_DIR/bootstrap-reverse.sh"
REAL_BASH="$(command -v bash)"
REAL_PYTHON="$(command -v python3)"
REAL_HEAD="$(command -v head)"
SCRATCH="$(mktemp -d /tmp/reverse-pwntools-discovery-XXXXXX)"
trap 'rm -rf -- "$SCRATCH"' EXIT

BIN_DIR="$SCRATCH/bin"
HOME_DIR="$SCRATCH/home"
WORK_DIR="$SCRATCH/workdir"
FIXTURE_SCRIPTS="$SCRATCH/fixture/kali/scripts"
OUTPUT_MD="$SCRATCH/tool-index.md"
OUTPUT_JSON="$SCRATCH/tool-index.json"
mkdir -p "$BIN_DIR" "$HOME_DIR" "$WORK_DIR" "$FIXTURE_SCRIPTS/lib"

# Exercise temporary copies of the production refresh path and discovery
# catalog. Disable the port probe and quarantine literal absolute fallback
# paths in the copied catalog so the fixture cannot contact localhost or run a
# host security tool outside its isolated PATH.
cp "$REFRESH" "$FIXTURE_SCRIPTS/refresh-tool-index.sh"
cp "$DISCOVERY" "$FIXTURE_SCRIPTS/lib/tool-discovery.sh"
"$REAL_PYTHON" - \
    "$DISCOVERY" \
    "$FIXTURE_SCRIPTS/lib/tool-discovery.sh" \
    "$SCRATCH/unavailable-host-paths" <<'PY'
import hashlib
import re
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
fixture_path = Path(sys.argv[2])
unavailable_root = Path(sys.argv[3])
source_bytes = source_path.read_bytes()
source_hash = hashlib.sha256(source_bytes).hexdigest()
source_text = source_bytes.decode("utf-8")
fixture_text = fixture_path.read_text(encoding="utf-8")


def catalog_bounds(catalog_lines, label):
    starts = [
        index
        for index, line in enumerate(catalog_lines)
        if line.rstrip("\r\n") == "declare -a TOOL_CATALOG=("
    ]
    if len(starts) != 1:
        raise SystemExit(
            f"{label} must contain exactly one TOOL_CATALOG declaration; "
            f"found {len(starts)}"
        )
    start = starts[0]
    ends = [
        index
        for index in range(start + 1, len(catalog_lines))
        if catalog_lines[index].rstrip("\r\n") == ")"
    ]
    if not ends:
        raise SystemExit(f"could not find the end of {label} TOOL_CATALOG")
    return start, ends[0]

port_probe = (
    """test_tcp_port() {
    local port="$1"
    local host="${2:-127.0.0.1}"
"""
    + "    (echo >"
    + "/dev/"
    + """tcp/"$host"/"$port") 2>/dev/null && return 0
    # fallback to nc
    nc -z "$host" "$port" 2>/dev/null && return 0
    return 1
}
"""
)
if fixture_text.count(port_probe) != 1:
    raise SystemExit(
        "expected exactly one canonical test_tcp_port source block, "
        f"found {fixture_text.count(port_probe)}"
    )
fixture_text = fixture_text.replace(
    port_probe,
    "test_tcp_port() {\n    return 1\n}\n",
    1,
)

lines = fixture_text.splitlines(keepends=True)
catalog_start, catalog_end = catalog_bounds(lines, "temporary fixture")
source_lines = source_text.splitlines(keepends=True)
source_catalog_start, source_catalog_end = catalog_bounds(
    source_lines, "production source"
)
entry_pattern = re.compile(r'^(\s*)"([^"]*)"(\r?\n)?$')
rewritten = 0
source_pwntools_lines = [
    line
    for line in source_lines[source_catalog_start + 1 : source_catalog_end]
    if line.strip().startswith('"pwntools|')
]
if len(source_pwntools_lines) != 1:
    raise SystemExit(
        "production catalog must contain exactly one pwntools row; "
        f"found {len(source_pwntools_lines)}"
    )

source_pwntools_match = entry_pattern.fullmatch(source_pwntools_lines[0])
if source_pwntools_match is None:
    raise SystemExit(
        f"production pwntools catalog row is malformed: {source_pwntools_lines[0]!r}"
    )
source_pwntools_fields = source_pwntools_match.group(2).split("|")
if len(source_pwntools_fields) != 5:
    raise SystemExit(
        "production pwntools catalog row must have exactly five fields: "
        f"{source_pwntools_match.group(2)!r}"
    )
expected_pwntools_fields = [
    "pwntools",
    "reverse-engineering",
    "CTF pwn 利用开发框架",
    "version",
    "pwn",
]
if source_pwntools_fields != expected_pwntools_fields:
    raise SystemExit(
        "production pwntools catalog payload must be exactly "
        f"{expected_pwntools_fields!r}, got {source_pwntools_fields!r}"
    )

for index in range(catalog_start + 1, catalog_end):
    stripped = lines[index].strip()
    if not stripped or stripped.startswith("#"):
        continue
    match = entry_pattern.fullmatch(lines[index])
    if match is None:
        raise SystemExit(f"malformed TOOL_CATALOG line {index + 1}: {lines[index]!r}")
    indent, payload, newline = match.groups()
    fields = payload.split("|")
    if len(fields) != 5:
        raise SystemExit(
            f"TOOL_CATALOG line {index + 1} must have exactly five fields: {payload!r}"
        )
    name, skill, purpose, version_args, fallback_text = fields
    if name == "pwntools":
        if lines[index] != source_pwntools_lines[0]:
            raise SystemExit("temporary pwntools catalog row differs from production")
        continue

    candidates = fallback_text.split(",") if fallback_text else []
    for candidate_index, candidate in enumerate(candidates):
        if not candidate.startswith("/"):
            continue
        candidates[candidate_index] = str(
            unavailable_root / f"{name}-{candidate_index}"
        )
        rewritten += 1
    fields[4] = ",".join(candidates)
    lines[index] = f'{indent}"{"|".join(fields)}"{newline or ""}'

if rewritten <= 0:
    raise SystemExit("expected to quarantine at least one absolute catalog fallback")

fixture_pwntools_lines = [
    line
    for line in lines[catalog_start + 1 : catalog_end]
    if line.strip().startswith('"pwntools|')
]
if fixture_pwntools_lines != source_pwntools_lines:
    raise SystemExit("pwntools row was not preserved exactly in the temporary catalog")

for index in range(catalog_start + 1, catalog_end):
    stripped = lines[index].strip()
    if not stripped or stripped.startswith("#"):
        continue
    match = entry_pattern.fullmatch(lines[index])
    if match is None:
        raise SystemExit(f"rewritten TOOL_CATALOG line {index + 1} is malformed")
    fields = match.group(2).split("|")
    for candidate in fields[4].split(",") if fields[4] else []:
        if candidate.startswith("/") and not candidate.startswith(f"{unavailable_root}/"):
            raise SystemExit(
                f"absolute fallback escaped quarantine on line {index + 1}: {candidate!r}"
            )

fixture_path.write_text("".join(lines), encoding="utf-8")
source_hash_after = hashlib.sha256(source_path.read_bytes()).hexdigest()
if source_hash_after != source_hash:
    raise SystemExit(
        "production tool-discovery.sh changed while creating the fixture: "
        f"before={source_hash}, after={source_hash_after}"
    )
PY
REFRESH="$FIXTURE_SCRIPTS/refresh-tool-index.sh"

# Keep discovery hermetic: expose only the host utilities required by the real
# refresh script. In particular, no host security tools can leak into results.
for name in bash date dirname mktemp python3 uname; do
    source_path="$(command -v "$name")" || {
        echo "required test dependency not found: $name" >&2
        exit 1
    }
    ln -s "$source_path" "$BIN_DIR/$name"
done

# Sentinel for probe-local terminal suppression. A correct
# `PWNLIB_NOTERM=1 pwn version | head` scopes the variable to pwn; a global
# export reaches head and is rejected instead of silently weakening this test.
cat > "$BIN_DIR/head" <<'STUB'
#!/bin/bash
: "${TEST_REAL_HEAD:?TEST_REAL_HEAD must point to the host head executable}"
: "${TEST_HEAD_SENTINEL_MARKER:?TEST_HEAD_SENTINEL_MARKER must be set}"
if [[ "${PWNLIB_NOTERM+x}" == "x" ]]; then
    if [[ ! -e "$TEST_HEAD_SENTINEL_MARKER" ]]; then
        printf 'head sentinel: PWNLIB_NOTERM leaked outside the pwntools probe (value=%q)\n' \
            "${PWNLIB_NOTERM-}" >&2
        : > "$TEST_HEAD_SENTINEL_MARKER"
    fi
    exit 97
fi
exec "$TEST_REAL_HEAD" "$@"
STUB
chmod +x "$BIN_DIR/head"

HAVE_JQ=false
if source_path="$(command -v jq 2>/dev/null)"; then
    ln -s "$source_path" "$BIN_DIR/jq"
    HAVE_JQ=true
else
    echo "INFO: jq is unavailable; validating the documented fallback JSON contract" >&2
fi

cat > "$BIN_DIR/pwn" <<'STUB'
#!/bin/bash
if [[ $# -ne 1 || "$1" != "version" ]]; then
    printf 'pwn test stub: expected exactly one argument: version; got:' >&2
    printf ' <%s>' "$@" >&2
    printf '\n' >&2
    exit 64
fi
if [[ "${PWNLIB_NOTERM:-}" != "1" ]]; then
    printf '%s\n' 'Warning: _curses.error: setupterm: could not find terminfo database' >&2
fi
printf '%s\n' '[*] Pwntools v4.15.0' >&2
STUB
chmod +x "$BIN_DIR/pwn"

# Always pass temporary output paths and a temporary HOME: this must not write
# generated indexes into the repository or inspect client-global config. Run
# from an empty temporary directory so relative fallback globs cannot discover
# or execute an untracked repository-root command.
(
    cd "$WORK_DIR"
    unset TERM PWNLIB_NOTERM
    env PATH="$BIN_DIR" HOME="$HOME_DIR" TEST_REAL_HEAD="$REAL_HEAD" \
        TEST_HEAD_SENTINEL_MARKER="$SCRATCH/head-leak" \
        "$REAL_BASH" "$REFRESH" "$OUTPUT_MD" "$OUTPUT_JSON" >/dev/null
)
if [[ -e "$SCRATCH/head-leak" ]]; then
    echo "head sentinel marker recorded a leaked PWNLIB_NOTERM" >&2
    exit 1
fi

"$REAL_PYTHON" - \
    "$OUTPUT_MD" \
    "$OUTPUT_JSON" \
    "$BIN_DIR/pwn" \
    "$HAVE_JQ" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

markdown_path = Path(sys.argv[1])
json_path = Path(sys.argv[2])
pwn_stub = sys.argv[3]
have_jq = sys.argv[4] == "true"
lines = markdown_path.read_text(encoding="utf-8").splitlines()
errors = []


def parse_markdown_row(line):
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        return None
    return [cell.strip() for cell in stripped[1:-1].split("|")]


tool_header = ["工具", "归属 skill", "作用", "可用", "路径", "版本", "来源", "脚本引用"]
tool_headers = [
    index for index, line in enumerate(lines) if parse_markdown_row(line) == tool_header
]
tool_matches = []
if len(tool_headers) != 1:
    errors.append(f"expected exactly one Markdown tool table, got {len(tool_headers)}")
else:
    for line in lines[tool_headers[0] + 2 :]:
        row = parse_markdown_row(line)
        if row is None:
            break
        if row and row[0] == "pwntools":
            tool_matches.append(row)

if len(tool_matches) != 1:
    errors.append(
        f"expected exactly one pwntools Markdown tool row, got {len(tool_matches)}"
    )
else:
    tool_row = tool_matches[0]
    if len(tool_row) != 8:
        errors.append(
            f"pwntools Markdown tool row must have exactly 8 columns: {tool_row!r}"
        )
    else:
        if tool_row[1] != "reverse-engineering":
            errors.append(
                "pwntools Markdown skill must be 'reverse-engineering', "
                f"got {tool_row[1]!r}"
            )
        if tool_row[2] != "CTF pwn 利用开发框架":
            errors.append(
                "pwntools Markdown purpose must be 'CTF pwn 利用开发框架', "
                f"got {tool_row[2]!r}"
            )
        if tool_row[3] != "yes":
            errors.append(f"pwntools Markdown availability must be 'yes', got {tool_row[3]!r}")
        if os.path.realpath(tool_row[4]) != os.path.realpath(pwn_stub):
            errors.append(
                "pwntools Markdown path must resolve to the pwn stub: "
                f"got {tool_row[4]!r}"
            )
        if tool_row[5] != "[*] Pwntools v4.15.0":
            errors.append(
                "pwntools Markdown version must be '[*] Pwntools v4.15.0', "
                f"got {tool_row[5]!r}"
            )
        if tool_row[6] != "command":
            errors.append(
                "pwntools Markdown source must be 'command', "
                f"got {tool_row[6]!r}"
            )

capability_headings = [
    index
    for index, line in enumerate(lines)
    if line.startswith("## ") and line[3:].startswith("能力状态视图")
]
capability_matches = []
if len(capability_headings) != 1:
    errors.append(
        f"expected exactly one capability-view heading, got {len(capability_headings)}"
    )
else:
    section_start = capability_headings[0] + 1
    section_end = len(lines)
    for index in range(section_start, len(lines)):
        if re.match(r"^##(?:\s|$)", lines[index]):
            section_end = index
            break
    for line in lines[section_start:section_end]:
        row = parse_markdown_row(line)
        if row and row[0] == "pwntools":
            capability_matches.append(row)

if len(capability_matches) != 1:
    errors.append(
        "expected exactly one pwntools capability row before the next level-2 "
        f"heading, got {len(capability_matches)}"
    )
else:
    capability_row = capability_matches[0]
    if len(capability_row) != 6:
        errors.append(
            "pwntools capability row must have exactly 6 columns: "
            f"{capability_row!r}"
        )
    else:
        if capability_row[1] != "✓":
            errors.append(
                f"pwntools capability must be available, got {capability_row[1]!r}"
            )
        if capability_row[5] != "pip-package":
            errors.append(
                "pwntools install method must be 'pip-package', "
                f"got {capability_row[5]!r}"
            )

try:
    with json_path.open(encoding="utf-8") as stream:
        data = json.load(stream)
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"tool-index JSON is not parseable: {exc}") from exc

if not isinstance(data, dict):
    errors.append(f"tool-index JSON root must be an object, got {type(data).__name__}")
elif have_jq:
    tools = data.get("tools")
    if not isinstance(tools, list):
        errors.append("jq JSON output must contain a tools array")
    else:
        json_matches = [
            tool
            for tool in tools
            if isinstance(tool, dict) and tool.get("name") == "pwntools"
        ]
        if len(json_matches) != 1:
            errors.append(
                f"expected exactly one pwntools JSON entry, got {len(json_matches)}"
            )
        else:
            pwntools = json_matches[0]
            if pwntools.get("skill") != "reverse-engineering":
                errors.append(
                    "pwntools JSON skill must be 'reverse-engineering', "
                    f"got {pwntools.get('skill')!r}"
                )
            if pwntools.get("purpose") != "CTF pwn 利用开发框架":
                errors.append(
                    "pwntools JSON purpose must be 'CTF pwn 利用开发框架', "
                    f"got {pwntools.get('purpose')!r}"
                )
            if pwntools.get("available") is not True:
                errors.append("pwntools JSON availability must be true")
            if os.path.realpath(pwntools.get("resolved_path", "")) != os.path.realpath(pwn_stub):
                errors.append(
                    "pwntools JSON resolved_path must point to the pwn stub: "
                    f"{pwntools.get('resolved_path')!r}"
                )
            if pwntools.get("version") != "[*] Pwntools v4.15.0":
                errors.append(
                    "pwntools JSON version must be '[*] Pwntools v4.15.0', "
                    f"got {pwntools.get('version')!r}"
                )
            if pwntools.get("source") != "command":
                errors.append(
                    "pwntools JSON source must be 'command', "
                    f"got {pwntools.get('source')!r}"
                )
else:
    expected_note = "install jq for full JSON output"
    if data.get("note") != expected_note:
        errors.append(
            f"fallback JSON note must be {expected_note!r}, got {data.get('note')!r}"
        )

if errors:
    raise SystemExit("pwntools discovery validation failed:\n- " + "\n- ".join(errors))
PY

list_output="$(
    cd "$WORK_DIR"
    env PATH="$BIN_DIR" HOME="$HOME_DIR" "$REAL_BASH" "$BOOTSTRAP" --list
)"
"$REAL_PYTHON" - "$list_output" <<'PY'
import sys

tokens = sys.argv[1].split()
if "pwntools" not in tokens:
    raise SystemExit("bootstrap --list must include the complete token 'pwntools'")
PY

HELP_VALIDATOR="$SCRATCH/validate-bootstrap-help.py"
cat > "$HELP_VALIDATOR" <<'PY'
import re
import sys
from pathlib import Path


if len(sys.argv) != 2:
    raise SystemExit("usage: validate-bootstrap-help.py HELP_OUTPUT")

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
section_pattern = re.compile(r"^\s*\[([^]]+)\]\s*$")
matching_section_titles = []

section_starts = [
    (index, heading.group(1))
    for index, line in enumerate(lines)
    if (heading := section_pattern.fullmatch(line)) is not None
]
for section_number, (section_start, title) in enumerate(section_starts):
    if section_number + 1 < len(section_starts):
        section_end = section_starts[section_number + 1][0]
    else:
        section_end = len(lines)
    section_lines = lines[section_start + 1 : section_end]
    if any("pwntools" in line.split() for line in section_lines):
        matching_section_titles.append(title)

expected_section_titles = ["逆向分析"]
if matching_section_titles != expected_section_titles:
    raise SystemExit(
        "bootstrap human help must classify the complete token 'pwntools' "
        "once and only once under [逆向分析]; "
        f"matching section titles: {matching_section_titles!r}"
    )
PY

set +e
(
    cd "$WORK_DIR"
    env PATH="$BIN_DIR" HOME="$HOME_DIR" "$REAL_BASH" "$BOOTSTRAP"
) > "$SCRATCH/bootstrap-help.txt" 2>&1
help_status=$?
set -e
if [[ $help_status -eq 0 ]]; then
    echo "bootstrap without arguments must exit non-zero" >&2
    exit 1
fi
"$REAL_PYTHON" "$HELP_VALIDATOR" "$SCRATCH/bootstrap-help.txt"

# Mutation checks lock the classification rule itself: the token is accepted
# only under reverse analysis, while a duplicate in any other section fails.
cat > "$SCRATCH/help-only-reverse.txt" <<'EOF'
可用能力:

  [逆向分析]
    jadx pwntools gef

  [其他]
    not-pwntools ghidra-mcp
EOF
"$REAL_PYTHON" "$HELP_VALIDATOR" "$SCRATCH/help-only-reverse.txt"

cat > "$SCRATCH/help-duplicate-section.txt" <<'EOF'
可用能力:

  [逆向分析]
    jadx pwntools gef

  [其他]
    pwntools ghidra-mcp
EOF
if "$REAL_PYTHON" "$HELP_VALIDATOR" "$SCRATCH/help-duplicate-section.txt" \
    >/dev/null 2>&1; then
    echo "help validator mutation survived: duplicate pwntools classification was accepted" >&2
    exit 1
fi

"$REAL_PYTHON" - \
    "$REPO_ROOT/skills/scripts/bootstrap-manifest.json" \
    "$REPO_ROOT/kali/scripts/bootstrap-manifest.json" <<'PY'
import json
import sys

for manifest_path in sys.argv[1:]:
    with open(manifest_path, encoding="utf-8") as stream:
        manifest = json.load(stream)
    capabilities = manifest.get("capabilities")
    if not isinstance(capabilities, list):
        raise SystemExit(f"{manifest_path}: capabilities must be an array")
    matches = [
        cap
        for cap in capabilities
        if isinstance(cap, dict) and cap.get("name") == "pwntools"
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"{manifest_path}: expected exactly one pwntools capability, got {len(matches)}"
        )
    if matches[0].get("verifyCommand") != "pwn":
        raise SystemExit(
            f"{manifest_path}: pwntools verifyCommand must be 'pwn', "
            f"got {matches[0].get('verifyCommand')!r}"
        )
PY

# The bootstrap preflight must use the executable supplied by pwntools (`pwn`),
# not the logical capability name (`pwntools`). Keep pip fully isolated: this
# stub records any attempted invocation and never calls the host package manager
# or the network.
PIP_MARKER="$SCRATCH/pip3-invoked"
cat > "$BIN_DIR/pip3" <<'STUB'
#!/bin/bash
: "${PIP_MARKER:?PIP_MARKER must be set}"
printf '%q ' "$@" > "$PIP_MARKER"
printf '\n' >> "$PIP_MARKER"
exit 0
STUB
chmod +x "$BIN_DIR/pip3"

set +e
bootstrap_output="$(
    cd "$WORK_DIR"
    env PATH="$BIN_DIR" HOME="$HOME_DIR" PIP_MARKER="$PIP_MARKER" \
        "$REAL_BASH" "$BOOTSTRAP" pwntools --skip-refresh 2>&1
)"
bootstrap_status=$?
set -e

if [[ -e "$PIP_MARKER" ]]; then
    pip_argv="$(<"$PIP_MARKER")"
    echo "bootstrap invoked pip3 even though pwn is available: $pip_argv" >&2
    exit 1
fi
if [[ $bootstrap_status -ne 0 ]]; then
    echo "bootstrap failed even though pwn is available (exit $bootstrap_status)" >&2
    printf '%s\n' "$bootstrap_output" >&2
    exit 1
fi

# A successful exit or the generic completion summary is insufficient: the
# preflight itself must report that the logical pwntools capability resolved to
# the isolated pwn executable. Strip terminal color before matching the exact
# ready line so ANSI formatting cannot weaken or break the assertion.
"$REAL_PYTHON" - "$bootstrap_output" "$BIN_DIR/pwn" <<'PY'
import re
import sys

ansi_escape = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
lines = [ansi_escape.sub("", line).rstrip("\r") for line in sys.argv[1].splitlines()]
expected = f"[OK] pwntools 已可用: {sys.argv[2]}"
if expected not in lines:
    raise SystemExit(
        "bootstrap preflight did not report the resolved pwn stub path on the "
        f"exact ready line {expected!r}; normalized output:\n"
        + "\n".join(lines)
    )
PY

echo "Kali pwntools discovery regression passed"
