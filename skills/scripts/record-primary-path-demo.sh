#!/usr/bin/env bash
# record-primary-path-demo.sh — produce a real terminal GIF of the PRIMARY path.
#
# Preference order:
#   1) vhs (if installed) + docs/demo/primary-path.tape
#   2) Pillow renderer + live command capture (no extra deps beyond python3+ffmpeg optional)
#
# Usage:
#   bash skills/scripts/record-primary-path-demo.sh
#   bash skills/scripts/record-primary-path-demo.sh --out docs/assets/primary-path-demo.gif

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"
OUT_GIF="$PACKAGE_ROOT/docs/assets/primary-path-demo.gif"
OUT_SCENES="$PACKAGE_ROOT/examples/primary-path-demo/terminal-scenes.txt"
OUT_CAST_DIR="$PACKAGE_ROOT/examples/primary-path-demo/recording"
TITLE="reverse-skill · PRIMARY path"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_GIF="${2:-}"; shift 2 ;;
    --scenes-out) OUT_SCENES="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$OUT_GIF")" "$(dirname "$OUT_SCENES")" "$OUT_CAST_DIR"

if command -v vhs >/dev/null 2>&1 && [[ -f "$PACKAGE_ROOT/docs/demo/primary-path.tape" ]]; then
  echo "Using vhs..."
  (
    cd "$PACKAGE_ROOT"
    vhs "$PACKAGE_ROOT/docs/demo/primary-path.tape"
  )
  if [[ -f "$PACKAGE_ROOT/docs/assets/primary-path-demo.gif" ]]; then
    echo "GIF via vhs → $PACKAGE_ROOT/docs/assets/primary-path-demo.gif"
    exit 0
  fi
  echo "vhs finished but GIF missing; falling back to Pillow renderer"
fi

# --- live capture of real commands (synthetic offline only) ---
TMP_DEMO="$OUT_CAST_DIR/live-demo"
rm -rf "$TMP_DEMO"
mkdir -p "$TMP_DEMO"

# Build scenes file from real outputs
{
  echo '$ bash skills/scripts/demo-primary-path.sh'
  echo '# one sentence in → PRIMARY skill + ready case out'
  echo '---'
} > "$OUT_SCENES"

set +e
DEMO_OUT="$(bash "$SCRIPT_DIR/demo-primary-path.sh" --out-dir "$TMP_DEMO" 2>&1)"
DEMO_RC=$?
set -e
printf '%s\n' "$DEMO_OUT" > "$OUT_CAST_DIR/demo-stdout.txt"

# compress demo stdout into scene beats
python3 - "$OUT_SCENES" "$OUT_CAST_DIR/demo-stdout.txt" "$TMP_DEMO" <<'PY'
import pathlib, sys, re
scenes_path, stdout_path, demo_dir = map(pathlib.Path, sys.argv[1:4])
stdout = stdout_path.read_text(encoding="utf-8", errors="replace").splitlines()
lines = []
# keep high-signal lines only
keep_pat = re.compile(r"(PRIMARY|route|CASE|case-guard|ready_for_act|auth\.status|DEMO OK|Label:|confidence|R\d+)", re.I)
for ln in stdout:
    s = ln.rstrip()
    if not s:
        continue
    if keep_pat.search(s) or s.startswith("[route]") or s.startswith("CASE"):
        lines.append(s)

# chunk into scenes
chunks = []
buf = []
for s in lines:
    buf.append(s)
    if s.startswith("[route]") or "CASE-GUARD" in s or s.startswith("DEMO OK") or "ready_for_act" in s:
        chunks.append(buf)
        buf = []
if buf:
    chunks.append(buf)

# always include matrix summary if present
matrix = demo_dir / "route-matrix.md"
if matrix.exists():
    mlines = [ln for ln in matrix.read_text(encoding="utf-8").splitlines() if ln.startswith("| `")]
    if mlines:
        chunks.append(["# route-matrix (live)"] + mlines[:8])

parts = [scenes_path.read_text(encoding="utf-8")]
for ch in chunks:
    parts.append("\n".join(ch))
scenes_path.write_text("\n---\n".join(parts).rstrip() + "\n", encoding="utf-8")
print(f"scenes={len(chunks)} lines_kept={sum(len(c) for c in chunks)}")
PY

if [[ $DEMO_RC -ne 0 ]]; then
  echo "ERROR: demo-primary-path failed (rc=$DEMO_RC)" >&2
  exit $DEMO_RC
fi

RENDER="$SCRIPT_DIR/lib/render-terminal-gif.py"
if [[ ! -f "$RENDER" ]]; then
  echo "ERROR: missing $RENDER" >&2
  exit 2
fi

python3 "$RENDER" --scenes "$OUT_SCENES" --out "$OUT_GIF" --title "$TITLE"
ls -la "$OUT_GIF"
echo "GIF → $OUT_GIF"
echo "Scenes → $OUT_SCENES"
