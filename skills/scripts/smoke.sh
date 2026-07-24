#!/usr/bin/env bash
# reverse-skill smoke entrypoint (bash parity of smoke.ps1)
# Usage: bash skills/scripts/smoke.sh [--log-dir DIR]
set -euo pipefail

LOG_DIR=""
PACKAGE_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -LogDir|--log-dir) LOG_DIR="${2:-}"; shift 2 ;;
    -PackageRoot|--package-root) PACKAGE_ROOT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -z "$PACKAGE_ROOT" ]]; then PACKAGE_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"; fi

if [[ -z "$LOG_DIR" ]]; then
  LOG_DIR="${TMPDIR:-/tmp}/rs-smoke-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$LOG_DIR"

FAIL=()
ok() { echo "[OK] $*"; }
bad() { echo "[FAIL] $*"; FAIL+=("$*"); }

echo "=== reverse-skill smoke | LogDir=$LOG_DIR ==="

verify="$SCRIPT_DIR/verify-routing-coherence.sh"
if [[ ! -f "$verify" ]]; then
  bad "verify-routing-coherence.sh missing"
else
  set +e
  bash "$verify" --scratch-dir "$LOG_DIR/verify" >"$LOG_DIR/01-verify.txt" 2>&1
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then ok "verify-routing-coherence exit 0"
  else bad "verify-routing-coherence exit $rc"; fi
fi

# syntax check key bash scripts
parse_ok=0
parse_fail=0
for name in verify-routing-coherence.sh master-route.sh case-init.sh case-guard.sh smoke.sh refresh-tool-index.sh bootstrap-reverse.sh demo-primary-path.sh record-primary-path-demo.sh; do
  p="$SCRIPT_DIR/$name"
  if [[ ! -f "$p" ]]; then
    echo "MISS $name" >> "$LOG_DIR/02-parse.txt"
    parse_fail=$((parse_fail+1))
    continue
  fi
  if bash -n "$p" 2>>"$LOG_DIR/02-parse.txt"; then
    echo "OK $name" >> "$LOG_DIR/02-parse.txt"
    parse_ok=$((parse_ok+1))
  else
    echo "FAIL $name" >> "$LOG_DIR/02-parse.txt"
    parse_fail=$((parse_fail+1))
  fi
done
if [[ $parse_fail -eq 0 ]]; then ok "bash -n scripts ($parse_ok ok)"
else bad "bash -n scripts failed ($parse_fail)"; fi

# master-route sample matrix (quick)
declare -a MATRIX=(
  "apk reverse jadx|R1"
  "js reverse signature|R3"
  "prompt injection llm|R14"
)
for row in "${MATRIX[@]}"; do
  IFS='|' read -r h want <<<"$row"
  out="$LOG_DIR/route-sample-$(echo "$want" | tr '[:upper:]' '[:lower:]')"
  set +e
  bash "$SCRIPT_DIR/master-route.sh" --hint "$h" --out-dir "$out" >"$out.txt" 2>&1
  set -e
  if [[ -f "$out/route-scope.md" ]] && grep -Eq "primary:[[:space:]]*$want" "$out/route-scope.md"; then
    ok "matrix $want"
  else
    bad "matrix want $want for hint: $h"
  fi
done

# case-init + guard happy path
cname="smoke-case-$(date +%H%M%S)"
set +e
bash "$SCRIPT_DIR/case-init.sh" --hint "apk reverse" --case-name "$cname" --package-root "$PACKAGE_ROOT" --preset offline-sample --sample /tmp/demo.apk >"$LOG_DIR/03-case-init.txt" 2>&1
set -e
croot="$PACKAGE_ROOT/work/$cname"
if [[ -f "$croot/scope.md" ]]; then ok "case-init created scope"
else bad "case-init missing scope"; fi
set +e
bash "$SCRIPT_DIR/case-guard.sh" --case-root "$croot" >"$LOG_DIR/04-case-guard.txt" 2>&1
grc=$?
set -e
if [[ $grc -eq 0 ]]; then ok "case-guard exit 0"
else bad "case-guard exit $grc"; fi


# --- demo showcase regenerates cleanly ---
demo="$SCRIPT_DIR/demo-primary-path.sh"
if [[ -f "$demo" ]]; then
  set +e
  bash "$demo" --out-dir "$LOG_DIR/demo-primary-path" >"$LOG_DIR/05-demo.txt" 2>&1
  drc=$?
  set -e
  if [[ $drc -eq 0 ]]; then ok "demo-primary-path exit 0"
  else bad "demo-primary-path exit $drc"; fi
else
  bad "demo-primary-path.sh missing"
fi


# --- recording assets present (GIF may be pre-generated) ---
if [[ -f "$SCRIPT_DIR/record-primary-path-demo.sh" ]]; then ok "record-primary-path-demo.sh present"
else bad "record-primary-path-demo.sh missing"; fi
if [[ -f "$SCRIPT_DIR/lib/render-terminal-gif.py" ]]; then ok "render-terminal-gif.py present"
else bad "render-terminal-gif.py missing"; fi
if [[ -f "$PACKAGE_ROOT/docs/demo/primary-path.tape" ]]; then ok "vhs tape present"
else bad "vhs tape missing"; fi
if [[ -f "$PACKAGE_ROOT/docs/assets/primary-path-demo.gif" ]]; then ok "primary-path-demo.gif present"
else bad "primary-path-demo.gif missing (run record-primary-path-demo.sh)"; fi

# --- install channel (marketplace + README one-liner) ---
mf="$PACKAGE_ROOT/.claude-plugin/marketplace.json"
if [[ -f "$mf" ]]; then
  set +e
  python3 - "$mf" <<'PY' >"$LOG_DIR/06-marketplace.txt" 2>&1
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
assert data.get("name"), "missing name"
assert data.get("owner"), "missing owner"
plugins = data.get("plugins") or []
assert plugins, "empty plugins"
for plugin in plugins:
    source = plugin.get("source")
    assert isinstance(source, str) and source.startswith("./"), f"bad source: {source!r}"
    assert plugin.get("name"), "plugin missing name"
print("marketplace ok:", data.get("name"), "plugins=", len(plugins))
PY
  mrc=$?
  set -e
  if [[ $mrc -eq 0 ]]; then ok "marketplace.json valid"
  else bad "marketplace.json invalid"; fi
else
  bad "marketplace.json missing"
fi

for readme in README.md README_zh.md; do
  rp="$PACKAGE_ROOT/$readme"
  if [[ ! -f "$rp" ]]; then
    bad "$readme missing"
    continue
  fi
  if grep -q 'skills.sh/b/zhaoxuya520/reverse-skill' "$rp" \
    && grep -q 'npx skills add zhaoxuya520/reverse-skill' "$rp" \
    && grep -q 'README_AI.md' "$rp"; then
    ok "$readme install channel"
  else
    bad "$readme missing install channel markers"
  fi
done

# --- README_zh About structure (flowchart fence before 30s proof) ---
set +e
python3 - "$PACKAGE_ROOT/README_zh.md" <<'PY' >"$LOG_DIR/07-readme-zh-about.txt" 2>&1
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
i = text.find("## 关于项目")
j = text.find("## 快速开始")
assert i >= 0 and j > i, "about/getting-started anchors missing"
sec = text[i:j]
assert "### 30" in sec, "30s proof missing in About"
pre = sec.split("### 30", 1)[0]
assert pre.count("```") % 2 == 0, "unclosed fence before 30s proof"
assert "case-init" in pre and "RULES.md" in pre, "flowchart incomplete"
print("README_zh about structure ok")
PY
zrc=$?
set -e
if [[ $zrc -eq 0 ]]; then ok "README_zh about structure"
else bad "README_zh about structure broken"; fi

echo "=== smoke summary ==="
if [[ ${#FAIL[@]} -gt 0 ]]; then
  echo "SMOKE FAILED ${#FAIL[@]}"
  printf ' - %s\n' "${FAIL[@]}"
  printf '%s\n' "${FAIL[@]}" > "$LOG_DIR/failures.txt"
  exit 1
fi
echo "SMOKE PASSED"
echo "SMOKE PASSED" > "$LOG_DIR/smoke.txt"
exit 0
