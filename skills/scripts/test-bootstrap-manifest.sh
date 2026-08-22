#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP="$SCRIPT_DIR/bootstrap-reverse.sh"
KALI_BOOTSTRAP="$SCRIPT_DIR/../../kali/scripts/bootstrap-reverse.sh"
MANIFEST="$SCRIPT_DIR/bootstrap-manifest.json"
REAL_PYTHON="$(command -v python3)"
SCRATCH="$(mktemp -d /tmp/reverse-bootstrap-test-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
STUB_BIN="$SCRATCH/bin"
CALL_LOG="$SCRATCH/calls.log"
mkdir -p "$STUB_BIN" "$SCRATCH/home" "$SCRATCH/tools"

cat > "$STUB_BIN/command-stub" <<'STUB'
#!/usr/bin/env bash
name="$(basename "$0")"
{ printf '%s' "$name"; for arg in "$@"; do printf '|%s' "$arg"; done; printf '\n'; } >> "$CALL_LOG"
if [[ "$name" == sudo || "$name" == nohup ]]; then
  next="${1:-}"; shift || true
  exec "$(dirname "$0")/$next" "$@"
fi
case "$name:${1:-}" in
  pipx:--version) printf '%s\n' "${STUB_PIPX_VERSION:-0}" ;;
  pnpm:--version) printf '%s\n' "${STUB_PNPM_VERSION:-0}" ;;
  brew:install)
    if [[ "${2:-}" == python ]]; then
      ln -sf "$STUB_PYTHON_SOURCE" "$STUB_ACTIVE_BIN/python3"
    fi
    ;;
  apt-get:install)
    pkg="${3:-${2:-}}"
    if [[ "$pkg" == python3 ]]; then
      ln -sf "$STUB_PYTHON_SOURCE" "$STUB_ACTIVE_BIN/python3"
    fi
    ;;
  git:init)
    target="${!#}"; mkdir -p "$target/.git"; printf '%s\n' unpinned-head > "$target/.stub-head"
    ;;
  git:-C)
    case "${3:-}" in
      fetch)
        [[ "${STUB_FAIL_FETCH:-0}" != 1 ]] || exit 1
        printf '%s\n' "${7:-}" > "$2/.stub-fetch"
        ;;
      checkout) cp "$2/.stub-fetch" "$2/.stub-head" ;;
      rev-parse) cat "$2/.stub-head" ;;
      status) [[ ! -e "$2/.stub-dirty" ]] || printf '%s\n' '?? .npmrc' ;;
    esac
    ;;
  nc:-z)
    [[ "${STUB_NC_PREOCCUPIED:-0}" != 1 ]] || exit 0
    count=0; [[ ! -f "$STUB_NC_STATE" ]] || count="$(cat "$STUB_NC_STATE")"
    printf '%s\n' "$((count + 1))" > "$STUB_NC_STATE"
    (( count > 0 )) && exit 0 || exit 1
    ;;
esac
[[ "${STUB_FAIL_COMMAND:-}" != "$name" ]]
STUB
chmod +x "$STUB_BIN/command-stub"
for name in git node npm npx pipx pnpm sleep nc apt-get sudo nohup; do ln -s command-stub "$STUB_BIN/$name"; done
ln -s command-stub "$STUB_BIN/brew"

cat > "$STUB_BIN/python3" <<STUB
#!/usr/bin/env bash
{ printf 'python3'; for arg in "\$@"; do printf '|%s' "\$arg"; done; printf '\n'; } >> "\$CALL_LOG"
if [[ "\${1:-}" == '-m' && "\${2:-}" == pip ]]; then [[ "\${STUB_FAIL_PIP_INSTALL:-0}" != 1 ]]; exit; fi
if [[ "\${1:-}" == '-m' && "\${2:-}" == pipx ]]; then exit 0; fi
if [[ "\${1:-}" == '-c' && "\${2:-}" == 'import pwn' ]]; then exit 1; fi
if [[ "\${1:-}" == '-' && "\${2:-}" == 23816 ]]; then exit 0; fi
exec "$REAL_PYTHON" "\$@"
STUB
chmod +x "$STUB_BIN/python3"

# Keep the Kali subflow hermetic on generic Linux/macOS hosts. The Kali
# bootstrap reads its manifest with jq, but this regression test must not
# depend on the host having jq installed just to exercise that code path.
JQ_STUB_PY="$SCRATCH/jq-stub.py"
cat > "$JQ_STUB_PY" <<'PY'
import json
import re
import sys

args = sys.argv[1:]
raw = False
exit_status = False
variables = {}
positionals = []
i = 0
while i < len(args):
    arg = args[i]
    if arg.startswith('-') and set(arg[1:]) <= {'e', 'r'}:
        raw = raw or 'r' in arg
        exit_status = exit_status or 'e' in arg
        i += 1
        continue
    if arg == '--arg':
        variables[args[i + 1]] = args[i + 2]
        i += 3
        continue
    positionals.append(arg)
    i += 1

if not positionals:
    raise SystemExit(2)

expression = positionals[0]
input_path = positionals[1] if len(positionals) > 1 else None
if input_path:
    with open(input_path, encoding='utf-8') as handle:
        data = json.load(handle)
else:
    data = json.load(sys.stdin)

if expression == '.bootstrapDependencies[$name][$field] // empty':
    result = data.get('bootstrapDependencies', {}).get(variables['name'], {}).get(variables['field'])
elif expression == '.capabilities[] | select(.name == $name) | .[$field] // empty':
    capability = next((item for item in data.get('capabilities', []) if item.get('name') == variables['name']), None)
    result = None if capability is None else capability.get(variables['field'])
elif expression in ('.name', '.status'):
    result = data.get(expression[1:])
else:
    match = re.fullmatch(r'\.mcpServers\."([^"]+)"\s*=\s*(.+)', expression)
    if not match:
        raise SystemExit(2)
    data.setdefault('mcpServers', {})[match.group(1)] = json.loads(match.group(2))
    result = data

if exit_status and (result is None or result is False or result == ''):
    raise SystemExit(1)
if raw and not isinstance(result, (dict, list)):
    print('' if result is None else result)
else:
    print(json.dumps(result, ensure_ascii=False))
PY

cat > "$STUB_BIN/jq" <<STUB
#!/usr/bin/env bash
exec "$REAL_PYTHON" "$JQ_STUB_PY" "\$@"
STUB
chmod +x "$STUB_BIN/jq"

json_value() {
  "$REAL_PYTHON" - "$MANIFEST" "$1" "$2" <<'PY'
import json, pathlib, sys
d=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
if sys.argv[2] == 'dependency': v=d['bootstrapDependencies'][sys.argv[3]]['package']
else: v=next(x for x in d['capabilities'] if x['name']==sys.argv[2])[sys.argv[3]]
print(v)
PY
}

run_generic() {
  env PATH="$STUB_BIN:/usr/bin:/bin" HOME="$SCRATCH/home" CALL_LOG="$CALL_LOG" \
    STUB_ACTIVE_BIN="$STUB_BIN" STUB_PYTHON_SOURCE="$STUB_BIN/python3" \
    STUB_PIPX_VERSION="${STUB_PIPX_VERSION:-}" STUB_PNPM_VERSION="${STUB_PNPM_VERSION:-}" \
    STUB_FAIL_PIP_INSTALL="${STUB_FAIL_PIP_INSTALL:-0}" STUB_FAIL_FETCH="${STUB_FAIL_FETCH:-0}" \
    REVERSE_SKILL_TOOLS_DIR="${TEST_TOOLS_ROOT:-$SCRATCH/tools}" \
    CLAUDE_MCP_CONFIG="$SCRATCH/home/mcp.json" bash "$BOOTSTRAP" "$@"
}
run_kali() {
  rm -f "$SCRATCH/nc-count"
  env PATH="$STUB_BIN:/opt/homebrew/bin:/usr/bin:/bin" HOME="$SCRATCH/home" \
    CALL_LOG="$CALL_LOG" STUB_NC_STATE="$SCRATCH/nc-count" STUB_PNPM_VERSION="${STUB_PNPM_VERSION:-}" \
    STUB_FAIL_FETCH="${STUB_FAIL_FETCH:-0}" STUB_NC_PREOCCUPIED="${STUB_NC_PREOCCUPIED:-0}" bash "$KALI_BOOTSTRAP" "$@"
}
expect_line() { grep -Fqx "$1" "$CALL_LOG" || { echo "missing argv: $1" >&2; cat "$CALL_LOG" >&2; return 1; }; }
expect_fragment() { grep -Fq "$1" "$CALL_LOG" || { echo "missing argv fragment: $1" >&2; cat "$CALL_LOG" >&2; return 1; }; }
rejects_without_pnpm() {
  local runner="$1"; shift
  : > "$CALL_LOG"; set +e; "$runner" "$@" >/dev/null 2>&1; local rc=$?; set -e
  [[ $rc -ne 0 ]] && ! grep -Eq '^pnpm\|(install|dev)' "$CALL_LOG"
}

pipx_package=$(json_value dependency pipx)
pnpm_package=$(json_value dependency pnpm)
anything_repo=$(json_value anything-analyzer repoUrl)
anything_pin=$(json_value anything-analyzer pinnedCommit)

# The manifest parser is bootstrapped before a Node-only sink, without installing pipx.
NO_PYTHON_BIN="$SCRATCH/no-python-bin"
PARSER_FIXTURE="$SCRATCH/parser-bootstrap"
mkdir -p "$NO_PYTHON_BIN"
for name in git node npm npx pipx pnpm sleep nc brew apt-get sudo nohup; do ln -s "$STUB_BIN/command-stub" "$NO_PYTHON_BIN/$name"; done
for tool in bash uname dirname mktemp rm head tr basename mkdir cat ln; do ln -s "$(command -v "$tool")" "$NO_PYTHON_BIN/$tool"; done
mkdir -p "$PARSER_FIXTURE"
cp "$BOOTSTRAP" "$PARSER_FIXTURE/bootstrap-reverse.sh"
cp "$MANIFEST" "$PARSER_FIXTURE/bootstrap-manifest.json"
: > "$CALL_LOG"
if ! env PATH="$NO_PYTHON_BIN" HOME="$SCRATCH/home" CALL_LOG="$CALL_LOG" \
  STUB_ACTIVE_BIN="$NO_PYTHON_BIN" STUB_PYTHON_SOURCE="$STUB_BIN/python3" \
  REVERSE_SKILL_TOOLS_DIR="$SCRATCH/tools" CLAUDE_MCP_CONFIG="$SCRATCH/home/mcp.json" \
  bash "$PARSER_FIXTURE/bootstrap-reverse.sh" agent-browser --skip-refresh \
  >"$SCRATCH/parser-out.log" 2>&1; then
  echo "parser-bootstrap failed:" >&2
  cat "$SCRATCH/parser-out.log" >&2
  exit 1
fi
if [[ "$(uname -s)" == Darwin ]]; then
  expect_line 'brew|install|python'
else
  expect_line 'apt-get|install|-y|python3'
fi
expect_line "npm|install|-g|$(json_value agent-browser npmPackage)"
if grep -Fq '|pip|install|' "$CALL_LOG"; then
  echo "unexpected pip install invocation" >&2
  exit 1
fi

# A required empty manifest field fails before any package-manager sink.
BROKEN_DIR="$SCRATCH/broken-bootstrap"
mkdir -p "$BROKEN_DIR"
cp "$BOOTSTRAP" "$BROKEN_DIR/bootstrap-reverse.sh"
"$REAL_PYTHON" - "$MANIFEST" "$BROKEN_DIR/bootstrap-manifest.json" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
next(x for x in data['capabilities'] if x['name'] == 'agent-browser')['npmPackage'] = ''
pathlib.Path(sys.argv[2]).write_text(json.dumps(data), encoding='utf-8')
PY
: > "$CALL_LOG"
set +e
env PATH="$STUB_BIN:/usr/bin:/bin" HOME="$SCRATCH/home" CALL_LOG="$CALL_LOG" \
  STUB_ACTIVE_BIN="$STUB_BIN" STUB_PYTHON_SOURCE="$STUB_BIN/python3" \
  REVERSE_SKILL_TOOLS_DIR="$SCRATCH/tools" CLAUDE_MCP_CONFIG="$SCRATCH/home/mcp.json" \
  bash "$BROKEN_DIR/bootstrap-reverse.sh" agent-browser --skip-refresh >/dev/null 2>&1
broken_rc=$?
set -e
[[ $broken_rc -ne 0 ]]
if grep -Eq '^npm\|install\|-g(\||$)' "$CALL_LOG"; then
  echo "unexpected global npm install invocation" >&2
  exit 1
fi

# Table: each generic package-manager sink receives its canonical manifest value.
while IFS='|' read -r capability _field expected; do
  : > "$CALL_LOG"
  STUB_PIPX_VERSION=1.16.5 run_generic "$capability" --skip-refresh >/dev/null
  expect_line "$expected"
done <<EOF
frida|pipPackage|pipx|install|--force|$(json_value frida pipPackage)
idalib-mcp|pipSource|pipx|install|--force|$(json_value idalib-mcp pipSource)
agent-browser|npmPackage|npm|install|-g|$(json_value agent-browser npmPackage)
proxycat|repo|pipx|install|git+$(json_value proxycat repo)@$(json_value proxycat pinnedCommit)
pwntools|pipPackage|pipx|install|$(json_value pwntools pipPackage)
EOF

# pipx itself is pinned; a failed pinned install has no mutable fallback.
: > "$CALL_LOG"
if STUB_FAIL_PIP_INSTALL=1 run_generic frida --skip-refresh >/dev/null 2>&1; then
  exit 1
fi
expect_line "python3|-m|pip|install|--user|--upgrade|$pipx_package"
[[ $(grep -c '|pip|install|' "$CALL_LOG") -eq 1 ]]
if grep -Eq '^pipx\|(install|upgrade)' "$CALL_LOG"; then
  echo "unexpected pipx invocation" >&2
  exit 1
fi

# Generic Anything Analyzer: staged checkout, pinned pnpm, frozen install, clean recheck, then dev.
: > "$CALL_LOG"
STUB_PIPX_VERSION=1.16.5 STUB_PNPM_VERSION=0 run_generic anything-analyzer --start-services --skip-refresh >/dev/null
anything_dir="$SCRATCH/tools/anything-analyzer"
expect_line "npm|install|-g|$pnpm_package"
expect_line 'pnpm|install|--frozen-lockfile'
expect_line 'pnpm|dev'
expect_fragment "remote|add|origin|$anything_repo"
expect_fragment "fetch|--depth|1|origin|$anything_pin"
[[ -d "$anything_dir/.git" ]]
[[ $(grep -c '|status|--porcelain|--untracked-files=all' "$CALL_LOG") -ge 2 ]]

# Dirty sources never reach install/dev.
touch "$anything_dir/.stub-dirty"
rejects_without_pnpm run_generic anything-analyzer --start-services --skip-refresh
rm "$anything_dir/.stub-dirty"

# Failed fetch leaves no final checkout or staging poison; a retry can succeed.
retry_root="$SCRATCH/retry-tools"
TEST_TOOLS_ROOT="$retry_root" STUB_FAIL_FETCH=1 rejects_without_pnpm run_generic anything-analyzer --start-services --skip-refresh
[[ ! -e "$retry_root/anything-analyzer" ]]
[[ -z "$(find "$retry_root" -maxdepth 1 -name '.reverse-bootstrap-*' -print -quit)" ]]
: > "$CALL_LOG"
TEST_TOOLS_ROOT="$retry_root" STUB_PNPM_VERSION=10.24.0 run_generic anything-analyzer --start-services --skip-refresh >/dev/null
[[ -d "$retry_root/anything-analyzer/.git" ]]

# Kali exercises the same source-before-execution boundary where associative arrays are supported.
if (( BASH_VERSINFO[0] >= 4 )); then
  kali_dir="$SCRATCH/home/tools/anything-analyzer"
  rm -rf "$kali_dir"
  : > "$CALL_LOG"
  set +e
  STUB_PNPM_VERSION=0 run_kali anything-analyzer --start-services --skip-refresh >/dev/null 2>&1
  set -e
  expect_line "npm|install|-g|$pnpm_package"
  expect_line 'pnpm|install|--frozen-lockfile'
  [[ $(grep -c '|status|--porcelain|--untracked-files=all' "$CALL_LOG") -ge 2 ]]
  touch "$kali_dir/.stub-dirty"
  rejects_without_pnpm run_kali anything-analyzer --start-services --skip-refresh
  STUB_NC_PREOCCUPIED=1 rejects_without_pnpm run_kali anything-analyzer --start-services --skip-refresh
  expect_fragment '|status|--porcelain|--untracked-files=all'

  rm -rf "$kali_dir"
  : > "$CALL_LOG"
  STUB_FAIL_FETCH=1 rejects_without_pnpm run_kali anything-analyzer --start-services --skip-refresh
  [[ ! -e "$kali_dir" ]]
  [[ -z "$(find "${kali_dir%/*}" -maxdepth 1 -name '.reverse-bootstrap-*' -print -quit)" ]]
  set +e
  STUB_PNPM_VERSION=10.24.0 run_kali anything-analyzer --start-services --skip-refresh >/dev/null 2>&1
  set -e
  [[ -d "$kali_dir/.git" ]]
  expect_line 'pnpm|install|--frozen-lockfile'
fi

echo 'bootstrap manifest source regression passed'
