#!/usr/bin/env bash
# Client-neutral Bash entry for the structured router.
# routing.json is the only route table; this file must not duplicate route rules.
set -euo pipefail

HINT=""
OUT_DIR=""
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Hint|-hint|--hint) HINT="${2:-}"; shift 2 ;;
    -OutDir|-out-dir|--out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    -ProjectRoot|-project-root|--project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    -h|--help)
      echo 'Usage: master-route.sh --hint TEXT [--out-dir DIR] [--project-root DIR]'
      exit 0
      ;;
    *)
      if [[ -z "$HINT" && "$1" != -* ]]; then HINT="$1"; shift
      else echo "Unknown arg: \"$1\"" >&2; exit 2; fi
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"
CONFIG_PATH="$SKILLS_ROOT/config/routing.json"

PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PYTHON="$candidate"
    break
  fi
done
if [[ -z "$PYTHON" ]]; then
  echo 'ERROR: Python 3 is required by the Bash structured router.' >&2
  exit 2
fi
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "ERROR: routing config missing: $CONFIG_PATH" >&2
  exit 2
fi

# Match the PowerShell entrypoint: by default, route artifacts belong to the
# caller's current project rather than the installed reverse-skill package.
if [[ -z "$PROJECT_ROOT" ]]; then PROJECT_ROOT="$(pwd -P)"; fi
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$PROJECT_ROOT/work/master-route-$(date +%Y%m%d-%H%M%S)"
fi

"$PYTHON" - "$CONFIG_PATH" "$SKILLS_ROOT" "$PROJECT_ROOT" "$OUT_DIR" "$HINT" <<'PY'
import datetime
import json
import pathlib
import re
import sys

config_path, skills_root_raw, project_root_raw, out_dir_raw, hint = sys.argv[1:]
skills_root = pathlib.Path(skills_root_raw)
project_root = pathlib.Path(project_root_raw).resolve()
out_dir = pathlib.Path(out_dir_raw)

try:
    config = json.loads(pathlib.Path(config_path).read_text(encoding="utf-8-sig"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"ERROR: routing config is not valid JSON: {exc}", file=sys.stderr)
    raise SystemExit(2)

routes = config.get("routes", {})
priority = config.get("priority", [])
fallback = config.get("meta", {}).get("fallbackId", "R0")
route_ids = set(routes)
if set(priority) != route_ids:
    missing = sorted(route_ids - set(priority))
    extra = sorted(set(priority) - route_ids)
    print(f"WARN: routes/priority mismatch; missing={missing}, extra={extra}", file=sys.stderr)

text = hint.lower()
scores = {}
selected_order = []

def matches(pattern):
    return bool(re.search(pattern, text, flags=re.IGNORECASE))

try:
    for route_id, route in routes.items():
        for rule in route.get("keywords", []):
            must = rule.get("must")
            hit = bool(must and matches(must))
            must_all = rule.get("mustAll") or []
            if isinstance(must_all, str):
                must_all = [must_all]
            if hit and any(not matches(pattern) for pattern in must_all):
                hit = False
            exclude = rule.get("exclude")
            if hit and exclude and matches(exclude):
                hit = False
            if hit:
                scores[route_id] = scores.get(route_id, 0) + 1
                if route_id not in selected_order:
                    selected_order.append(route_id)
except re.error as exc:
    print(f"ERROR: invalid regex in routing.json: {exc}", file=sys.stderr)
    raise SystemExit(2)

primary = None
max_score = -1
for route_id in priority:
    score = scores.get(route_id)
    if score is not None and score > max_score:
        primary = route_id
        max_score = score

notes = []
if primary is None:
    primary = fallback
    confidence = "low"
    notes.append("No strong keyword hit; open routing.md full matrix" if text else "Empty hint; provide task text")
else:
    confidence = "high" if len(selected_order) == 1 else "medium"

if primary not in routes:
    print(f"ERROR: fallback/primary route is missing: {primary}", file=sys.stderr)
    raise SystemExit(2)

route = routes[primary]
primary_path = route["skill"]
skill_path = skills_root / pathlib.PurePosixPath(primary_path)
if not skill_path.is_file():
    print(f"ERROR: PRIMARY skill missing: {skill_path}", file=sys.stderr)
    raise SystemExit(2)

out_dir.mkdir(parents=True, exist_ok=True)
secondary = [f"skills/{routes[item]['skill']}" for item in selected_order if item != primary]
lines = [
    "# reverse-skill Master route (PRIMARY)",
    f"- created: {datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat()}",
    "- package: reverse-skill",
    f"- hint: {hint}",
    f"- primary: {primary}",
    f"- primary_label: {route['label']}",
    f"- primary_skill: skills/{primary_path}",
    f"- confidence: {confidence}",
    f"- project_root: {project_root}",
    f"- secondary: {', '.join(secondary) if secondary else '(none)'}",
    "",
    "## MUST open next",
    "",
    "1. skills/MASTER-ROUTING.md",
    f"2. skills/{primary_path}",
    "",
    "## Notes",
]
lines.extend(f"- {note}" for note in notes)
if not notes:
    lines.append("- (none)")
(out_dir / "route-scope.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"PRIMARY -> skills/{primary_path}")
print(f"Label: {route['label']} | confidence: {confidence}")
for note in notes:
    print(f"NOTE: {note}")
print(f"Wrote {out_dir / 'route-scope.md'}")
print("ACTION: Open PRIMARY SKILL.md now and execute ACTION REQUIRED.")
PY
