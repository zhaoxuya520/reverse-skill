#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP="$SCRIPT_DIR/bootstrap-reverse.sh"
REFRESH="$SCRIPT_DIR/refresh-tool-index.sh"
REAL_HEAD="$(command -v head)"
SCRATCH="$(mktemp -d /tmp/reverse-client-neutral-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

HOME_DIR="$SCRATCH/home"
BIN_DIR="$SCRATCH/bin"
TOOLS_DIR="$SCRATCH/tools"
CLAUDE_CFG="$SCRATCH/client/claude.json"
CODEX_CFG="$SCRATCH/client/codex.toml"
mkdir -p "$HOME_DIR" "$BIN_DIR" "$TOOLS_DIR" "$(dirname "$CLAUDE_CFG")"

for name in bash date dirname mktemp python3 rm sed tr uname; do
  ln -s "$(command -v "$name")" "$BIN_DIR/$name"
done

# Keep PWNLIB_NOTERM probe-local: a script-level export must leak into this
# downstream pipeline stage and be rejected, while `PWNLIB_NOTERM=1 pwn ...`
# leaves head's environment clean.
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

for name in node npm npx; do
  cat > "$BIN_DIR/$name" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 1.0.0; fi
exit 0
STUB
  chmod +x "$BIN_DIR/$name"
done

cat > "$BIN_DIR/ghidra" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$BIN_DIR/ghidra"

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

EMPTY_VERSION_DIR="$SCRATCH/empty-version"
EMPTY_VERSION_REFRESH="$EMPTY_VERSION_DIR/refresh-tool-index.sh"
EMPTY_VERSION_MD="$EMPTY_VERSION_DIR/tool-index.md"
EMPTY_VERSION_JSON="$EMPTY_VERSION_DIR/tool-index.json"
mkdir -p "$EMPTY_VERSION_DIR"
cp "$REFRESH" "$EMPTY_VERSION_REFRESH"
python3 - "$REFRESH" "$EMPTY_VERSION_REFRESH" <<'PY'
import hashlib
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
fixture_path = Path(sys.argv[2])
source_bytes = source_path.read_bytes()
if fixture_path.read_bytes() != source_bytes:
    raise SystemExit("empty-version fixture must begin as an exact production copy")

old = b'  "node|core-runtime|Node.js runtime for MCP bridges|node|node --version|"'
new = b'  "node|core-runtime|Node.js runtime for MCP bridges|node||"'
matches = source_bytes.count(old)
if matches != 1:
    raise SystemExit(
        "production refresh must contain exactly one canonical node row; "
        f"found {matches}"
    )

fixture_path.write_bytes(source_bytes.replace(old, new, 1))
if hashlib.sha256(source_path.read_bytes()).digest() != hashlib.sha256(source_bytes).digest():
    raise SystemExit("production refresh changed while creating empty-version fixture")
PY

export PATH="$BIN_DIR:$PATH"
export HOME="$HOME_DIR"
export REVERSE_SKILL_TOOLS_DIR="$TOOLS_DIR"
export CLAUDE_MCP_CONFIG="$CLAUDE_CFG"
export CODEX_CONFIG_PATH="$CODEX_CFG"

MD="$SCRATCH/tool-index.md"
JSON="$SCRATCH/tool-index.json"
(
  unset TERM PWNLIB_NOTERM
  PATH="$BIN_DIR" TEST_REAL_HEAD="$REAL_HEAD" \
    TEST_HEAD_SENTINEL_MARKER="$SCRATCH/baseline-head-leak" \
    "$BIN_DIR/bash" "$REFRESH" "$MD" "$JSON" >/dev/null
)
if [[ -e "$SCRATCH/baseline-head-leak" ]]; then
  echo "head sentinel marker recorded a leaked PWNLIB_NOTERM in baseline refresh" >&2
  exit 1
fi

set +e
(
  unset TERM PWNLIB_NOTERM
  PATH="$BIN_DIR" TEST_REAL_HEAD="$REAL_HEAD" \
    TEST_HEAD_SENTINEL_MARKER="$EMPTY_VERSION_DIR/head-leak" \
    "$BIN_DIR/bash" "$EMPTY_VERSION_REFRESH" \
      "$EMPTY_VERSION_MD" "$EMPTY_VERSION_JSON" >/dev/null
) 2> "$EMPTY_VERSION_DIR/refresh.stderr"
empty_version_refresh_status=$?
set -e

empty_version_validation_status=0
if [[ -e "$EMPTY_VERSION_DIR/head-leak" ]]; then
  echo "head sentinel marker recorded a leaked PWNLIB_NOTERM in empty-version refresh" >&2
  empty_version_validation_status=1
fi
if [[ $empty_version_refresh_status -ne 0 ]]; then
  printf 'empty version_spec refresh must exit 0; got %d\n' \
    "$empty_version_refresh_status" >&2
  while IFS= read -r line; do
    printf 'empty version_spec stderr: %s\n' "$line" >&2
  done < "$EMPTY_VERSION_DIR/refresh.stderr"
  empty_version_validation_status=1
else
  set +e
  python3 - "$EMPTY_VERSION_MD" "$EMPTY_VERSION_JSON" <<'PY'
import json
import sys
from pathlib import Path

markdown_lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
node_rows = [
    [cell.strip() for cell in line.strip()[1:-1].split("|")]
    for line in markdown_lines
    if line.startswith("| node |")
]
if len(node_rows) != 1:
    raise SystemExit(f"expected exactly one node Markdown row, got {len(node_rows)}")
if len(node_rows[0]) != 8 or node_rows[0][5] != "—":
    raise SystemExit(
        "empty node version_spec must use the existing Markdown default '—'; "
        f"got {node_rows[0]!r}"
    )

data = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
node_records = [tool for tool in data.get("tools", []) if tool.get("name") == "node"]
if len(node_records) != 1:
    raise SystemExit(f"expected exactly one node JSON record, got {len(node_records)}")
node_record = node_records[0]
if "version" not in node_record:
    raise SystemExit(
        "empty node version_spec expected explicit JSON null field; "
        "version field is missing"
    )
if node_record["version"] is not None:
    raise SystemExit(
        "empty node version_spec expected explicit JSON null field; "
        f"got {node_record['version']!r}"
    )
PY
  empty_version_validation_status=$?
  set -e
fi

set +e
python3 - "$JSON" "$BIN_DIR/ghidra" "$BIN_DIR/pwn" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
tools = data['tools']
assert sum(t['name'] == 'binwalk' for t in tools) == 1, 'binwalk must appear exactly once'
by_tool = {t['name']: t for t in tools}
assert by_tool['npx']['available'] is True
assert by_tool['jshookmcp']['available'] is False, 'npx must not masquerade as jshookmcp'
assert by_tool['reqable-mcp']['available'] is False, 'npx must not masquerade as reqable-mcp'
assert by_tool['ghidra']['available'] is True, 'the distro-provided ghidra launcher must be discovered'
assert os.path.realpath(by_tool['ghidra']['path']) == os.path.realpath(sys.argv[2])
pwntools_matches = [tool for tool in tools if tool.get('name') == 'pwntools']
if len(pwntools_matches) != 1:
    raise SystemExit(
        f"expected exactly one pwntools tool record, got {len(pwntools_matches)}"
    )
pwntools = pwntools_matches[0]
expected_pwntools = {
    'available': True,
    'version': '[*] Pwntools v4.15.0',
    'source': 'command',
    'skill': 'reverse-engineering',
    'purpose': 'CTF pwn exploit development framework',
}
for field, expected in expected_pwntools.items():
    if pwntools.get(field) != expected:
        raise SystemExit(
            f"pwntools {field} must be {expected!r}, got {pwntools.get(field)!r}"
        )
if os.path.realpath(pwntools.get('path') or '') != os.path.realpath(sys.argv[3]):
    raise SystemExit(
        "pwntools path must resolve to the strict pwn stub: "
        f"got {pwntools.get('path')!r}"
    )
by_cap = {c['name']: c for c in data['capabilities']}
assert by_cap['jshookmcp']['ready'] is False
assert by_cap['reqable-mcp']['ready'] is False
PY
baseline_validation_status=$?
set -e

if [[ $empty_version_validation_status -ne 0 || $baseline_validation_status -ne 0 ]]; then
  exit 1
fi

cat > "$CODEX_CFG" <<'EOF'
[mcp_servers.jshook]
command = "npx"
args = ["-y", "@jshookmcp/jshook@0.3.4"]
EOF
(
  unset TERM PWNLIB_NOTERM
  TEST_REAL_HEAD="$REAL_HEAD" \
    TEST_HEAD_SENTINEL_MARKER="$SCRATCH/registered-head-leak" \
    bash "$REFRESH" "$MD" "$JSON" >/dev/null
)
if [[ -e "$SCRATCH/registered-head-leak" ]]; then
  echo "head sentinel marker recorded a leaked PWNLIB_NOTERM in registered refresh" >&2
  exit 1
fi
python3 - "$JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
cap = {c['name']: c for c in data['capabilities']}['jshookmcp']
assert cap['mcp_registered'] is True, 'Codex-only MCP registration must be discovered'
assert cap['runtime_available'] is True
assert cap['ready'] is True, 'registered npm MCP + npx runtime should be ready'
PY

rm -f "$CLAUDE_CFG" "$CODEX_CFG"
default_out="$(bash "$BOOTSTRAP" jshookmcp --skip-refresh)"
[[ "$default_out" == *'"status":"registration-required"'* || "$default_out" == *'"status": "registration-required"'* ]]
[[ ! -e "$CLAUDE_CFG" ]]
[[ ! -e "$CODEX_CFG" ]]

codex_out="$(bash "$BOOTSTRAP" jshookmcp --skip-refresh --mcp-host=codex)"
[[ "$codex_out" == *'"status":"ready"'* || "$codex_out" == *'"status": "ready"'* ]]
[[ ! -e "$CLAUDE_CFG" ]]
grep -Eq '^\[mcp_servers\.jshook\]$' "$CODEX_CFG"

rm -f "$CLAUDE_CFG" "$CODEX_CFG"
claude_out="$(bash "$BOOTSTRAP" jshookmcp --skip-refresh --mcp-host=claude)"
[[ "$claude_out" == *'"status":"ready"'* || "$claude_out" == *'"status": "ready"'* ]]
[[ -f "$CLAUDE_CFG" ]]
[[ ! -e "$CODEX_CFG" ]]
python3 - "$CLAUDE_CFG" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
assert 'jshook' in data.get('mcpServers', {})
PY

echo 'client-neutral Bash bootstrap/discovery regression passed'
