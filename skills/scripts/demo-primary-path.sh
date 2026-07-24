#!/usr/bin/env bash
# demo-primary-path.sh — reproducible PRIMARY-path showcase (Linux/macOS)
#
# Proves in ~3 minutes:
#   one-line task → master-route PRIMARY → case-init scope → case-guard ready
#
# Usage:
#   bash skills/scripts/demo-primary-path.sh
#   bash skills/scripts/demo-primary-path.sh --out-dir examples/primary-path-demo
#
# Does NOT scan remote targets. Offline / synthetic samples only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"
OUT_DIR="$PACKAGE_ROOT/examples/primary-path-demo"
STAMP="$(date +%Y-%m-%dT%H:%M:%S%z)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR/cases" "$OUT_DIR/routes" "$OUT_DIR/logs"
LOG="$OUT_DIR/logs/demo-run.log"
: > "$LOG"

log() { echo "$*" | tee -a "$LOG"; }

need() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing $f (run from a reverse-skill checkout that includes bash PRIMARY scripts)" >&2
    exit 2
  fi
}

need "$SCRIPT_DIR/master-route.sh"
need "$SCRIPT_DIR/case-init.sh"
need "$SCRIPT_DIR/case-guard.sh"

log "=== reverse-skill PRIMARY path demo ==="
log "stamp: $STAMP"
log "package: $PACKAGE_ROOT"
log "out: $OUT_DIR"

# Sample matrix: hint → expected PRIMARY id (for self-check)
# Format: id|hint|expect_primary
SAMPLES=(
  "apk|analyze this APK for certificate pinning with jadx|R1"
  "js|frontend js reverse encrypted request signature webpack|R3"
  "llm|llm prompt injection jailbreak garak agent security|R14"
  "r2|radare2 quick triage of unknown ELF|R7"
  "offline|local offline apk static reverse sample|R1"
)

MATRIX_MD="$OUT_DIR/route-matrix.md"
{
  echo "# PRIMARY route matrix (live demo)"
  echo ""
  echo "- generated_at: \`$STAMP\`"
  echo "- generator: \`skills/scripts/demo-primary-path.sh\`"
  echo "- host: \`$(uname -s) $(uname -m)\`"
  echo ""
  echo "| Sample | Hint | PRIMARY | Label | Confidence | Match |"
  echo "|--------|------|---------|-------|------------|-------|"
} > "$MATRIX_MD"

fail=0
for row in "${SAMPLES[@]}"; do
  IFS='|' read -r sid hint expect <<<"$row"
  rdir="$OUT_DIR/routes/$sid"
  mkdir -p "$rdir"
  set +e
  out="$(bash "$SCRIPT_DIR/master-route.sh" --hint "$hint" --out-dir "$rdir" 2>&1)"
  rc=$?
  set -e
  printf '%s\n' "$out" > "$rdir/stdout.txt"
  primary="?"; label="?"; conf="?"
  if [[ -f "$rdir/route-scope.md" ]]; then
    primary="$(sed -n 's/^- primary: //p' "$rdir/route-scope.md" | head -1)"
    label="$(sed -n 's/^- primary_label: //p' "$rdir/route-scope.md" | head -1)"
    conf="$(sed -n 's/^- confidence: //p' "$rdir/route-scope.md" | head -1)"
  fi
  match="FAIL"
  if [[ "$primary" == "$expect" ]]; then match="OK"; else fail=$((fail+1)); fi
  # escape pipes in hint for md
  hint_md="${hint//|/\\|}"
  echo "| \`$sid\` | ${hint_md} | **${primary}** | ${label} | ${conf} | ${match} |" >> "$MATRIX_MD"
  log "[route] $sid -> $primary (expect $expect) $match"
done

# Offline case happy path
CASE_NAME="demo-offline-apk"
CASE_ROOT_PKG="$PACKAGE_ROOT/work/$CASE_NAME"

# Placeholder sample path for scope only (NOT a real APK / not analyzed).
mkdir -p "$OUT_DIR/fixtures"
if [[ ! -f "$OUT_DIR/fixtures/sample.apk" ]]; then
  printf 'PK\x03\x04DEMO-NOT-A-REAL-APK' > "$OUT_DIR/fixtures/sample.apk"
fi

set +e
ci_out="$(bash "$SCRIPT_DIR/case-init.sh" \
  --hint "local offline apk static reverse sample" \
  --case-name "$CASE_NAME" \
  --package-root "$PACKAGE_ROOT" \
  --preset offline-sample \
  --sample "$OUT_DIR/fixtures/sample.apk" \
  2>&1)"
ci_rc=$?
set -e
printf '%s\n' "$ci_out" > "$OUT_DIR/logs/case-init.txt"
log "$ci_out"

set +e
guard_out="$(bash "$SCRIPT_DIR/case-guard.sh" --case-root "$CASE_ROOT_PKG" 2>&1)"
guard_rc=$?
set -e
printf '%s\n' "$guard_out" > "$OUT_DIR/logs/case-guard.txt"
log "$guard_out"

# Copy case artifacts into examples (portable showcase)
if [[ -d "$CASE_ROOT_PKG" ]]; then
  rm -rf "$OUT_DIR/cases/$CASE_NAME"
  mkdir -p "$OUT_DIR/cases/$CASE_NAME"
  cp -R "$CASE_ROOT_PKG/." "$OUT_DIR/cases/$CASE_NAME/"
fi

# RESULT CARD (markdown)
CARD="$OUT_DIR/RESULT-CARD.md"
{
  echo "# reverse-skill · PRIMARY Path Result Card"
  echo ""
  echo "> One sentence in → correct skill + ready case directory out."
  echo ""
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| generated_at | \`$STAMP\` |"
  echo "| demo script | \`skills/scripts/demo-primary-path.sh\` |"
  echo "| route samples | ${#SAMPLES[@]} |"
  echo "| route self-check failures | $fail |"
  echo "| offline case | \`$CASE_NAME\` |"
  echo "| case-guard exit | \`$guard_rc\` (0=ready) |"
  echo ""
  echo "## What you get in 3 minutes"
  echo ""
  echo "1. **PRIMARY route** for each sample hint → \`routes/*/route-scope.md\`"
  echo "2. **Case workspace** with \`scope.md\` / \`timeline.md\` / \`workitems.md\`"
  echo "3. **Auth preset** \`offline-sample\` → \`ready_for_act=true\` without fighting the gate"
  echo ""
  echo "## Live matrix"
  echo ""
  echo "See [route-matrix.md](route-matrix.md)."
  echo ""
  echo "## Offline case snapshot"
  echo ""
  if [[ -f "$OUT_DIR/cases/$CASE_NAME/scope.md" ]]; then
    echo '```markdown'
    # first 40 lines of scope
    sed -n '1,40p' "$OUT_DIR/cases/$CASE_NAME/scope.md"
    echo '```'
  else
    echo "_scope.md missing_"
  fi
  echo ""
  echo "## Reproduce"
  echo ""
  echo '```bash'
  echo "git clone https://github.com/zhaoxuya520/reverse-skill.git"
  echo "cd reverse-skill"
  echo "bash skills/scripts/demo-primary-path.sh"
  echo "open examples/primary-path-demo/RESULT-CARD.md"
  echo '```'
  echo ""
  echo "## Not claimed"
  echo ""
  echo "- This demo does **not** decompile a real app or attack a host."
  echo "- It proves the **router + ops gate** product surface end-to-end on Linux/macOS."
  echo "- Domain ACT still requires tools from \`tool-index\` and authorized scope."
} > "$CARD"

# Lightweight HTML card for README / screenshot
HTML="$OUT_DIR/result-card.html"
{
  cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>reverse-skill PRIMARY path result card</title>
<style>
  :root { color-scheme: light dark; }
  body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif; margin: 0; padding: 32px; background: #0b1220; color: #e8eefc; }
  .card { max-width: 820px; margin: 0 auto; border: 1px solid #243047; border-radius: 12px; background: linear-gradient(180deg,#121a2b,#0d1422); box-shadow: 0 20px 60px rgba(0,0,0,.35); overflow: hidden; }
  header { padding: 28px 28px 12px; border-bottom: 1px solid #243047; }
  header h1 { margin: 0 0 8px; font-size: 22px; letter-spacing: .2px; }
  header p { margin: 0; color: #9db0d0; font-size: 14px; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 20px 28px; }
  .metric { background: #172033; border: 1px solid #2a3a58; border-radius: 10px; padding: 14px 16px; }
  .metric .k { color: #8fa3c4; font-size: 12px; text-transform: uppercase; letter-spacing: .06em; }
  .metric .v { margin-top: 6px; font-size: 20px; font-weight: 700; }
  .ok { color: #5ddea8; }
  table { width: calc(100% - 56px); margin: 0 28px 24px; border-collapse: collapse; font-size: 13px; }
  th, td { text-align: left; padding: 10px 8px; border-bottom: 1px solid #243047; vertical-align: top; }
  th { color: #8fa3c4; font-weight: 600; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; color: #c9dbff; }
  footer { padding: 0 28px 24px; color: #7f92b3; font-size: 12px; }
</style>
</head>
<body>
  <div class="card">
    <header>
      <h1>reverse-skill · PRIMARY Path</h1>
      <p>One sentence in → correct skill + ready case directory out · $STAMP</p>
    </header>
    <div class="grid">
      <div class="metric"><div class="k">Route samples</div><div class="v">${#SAMPLES[@]}</div></div>
      <div class="metric"><div class="k">Self-check fails</div><div class="v $([[ $fail -eq 0 ]] && echo ok)">$fail</div></div>
      <div class="metric"><div class="k">Offline case-guard</div><div class="v $([[ $guard_rc -eq 0 ]] && echo ok)">exit $guard_rc</div></div>
      <div class="metric"><div class="k">Preset</div><div class="v">offline-sample</div></div>
    </div>
    <table>
      <thead><tr><th>Sample</th><th>PRIMARY</th><th>Match</th></tr></thead>
      <tbody>
HTML
  for row in "${SAMPLES[@]}"; do
    IFS='|' read -r sid hint expect <<<"$row"
    primary="$(sed -n 's/^- primary: //p' "$OUT_DIR/routes/$sid/route-scope.md" 2>/dev/null | head -1)"
    label="$(sed -n 's/^- primary_label: //p' "$OUT_DIR/routes/$sid/route-scope.md" 2>/dev/null | head -1)"
    match="FAIL"; [[ "$primary" == "$expect" ]] && match="OK"
    printf '        <tr><td><code>%s</code><br/><span style="color:#8fa3c4">%s</span></td><td><strong>%s</strong><br/>%s</td><td class="%s">%s</td></tr>\n' \
      "$sid" "$(printf '%s' "$hint" | sed 's/&/&amp;/g; s/</\&lt;/g')" "$primary" "$label" "$([[ $match == OK ]] && echo ok)" "$match"
  done
  cat <<HTML
      </tbody>
    </table>
    <footer>
      Reproduce: <code>bash skills/scripts/demo-primary-path.sh</code> · artifacts under <code>examples/primary-path-demo/</code><br/>
      This card is a real script output, not a mock layout.
    </footer>
  </div>
</body>
</html>
HTML
} > "$HTML"

# README for examples dir
{
  echo "# primary-path-demo"
  echo ""
  echo "Reproducible showcase for reverse-skill's product surface:"
  echo ""
  echo '```'
  echo "task text → master-route → case-init (offline-sample) → case-guard"
  echo '```'
  echo ""
  echo "| Artifact | Meaning |"
  echo "|----------|---------|"
  echo "| [RESULT-CARD.md](RESULT-CARD.md) | Human-readable result card |"
  echo "| [result-card.html](result-card.html) | Screenshot-friendly card |"
  echo "| [route-matrix.md](route-matrix.md) | Live routing self-check |"
  echo "| [cases/](cases/) | Copied case workspace |"
  echo "| [routes/](routes/) | Per-sample route-scope.md |"
  echo ""
  echo "Regenerate:"
  echo ""
  echo '```bash'
  echo "bash skills/scripts/demo-primary-path.sh"
  echo '```'
} > "$OUT_DIR/README.md"

# summary json
python3 - <<PY
import json, pathlib
out = pathlib.Path(r"$OUT_DIR")
summary = {
  "generated_at": "$STAMP",
  "route_failures": $fail,
  "case_guard_exit": $guard_rc,
  "samples": ${#SAMPLES[@]},
  "case": "$CASE_NAME",
  "ok": ($fail == 0 and $guard_rc == 0),
}
(out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary))
PY

if [[ $fail -ne 0 || $guard_rc -ne 0 ]]; then
  log "DEMO FAILED (route_fail=$fail guard_rc=$guard_rc)"
  exit 1
fi
log "DEMO OK → $OUT_DIR"
echo "DEMO OK → $OUT_DIR"
