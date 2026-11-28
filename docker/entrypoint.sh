#!/usr/bin/env bash
# reverse-skill container entrypoint (issue #129)
set -euo pipefail

ROOT="${REVERSE_SKILL_ROOT:-/opt/reverse-skill}"
cd "$ROOT" 2>/dev/null || cd /home/analyst

if [ -d "$ROOT/skills" ] && [ -d "$ROOT/kali" ]; then
  echo "reverse-skill package: $ROOT"
  echo "tools index: bash skills/scripts/refresh-tool-index.sh  (or kali/scripts/refresh-tool-index.sh)"
  echo "router:      bash skills/scripts/master-route.sh --hint \"<task>\""
  echo "case gate:   bash skills/scripts/case-init.sh --hint \"<task>\" --case-name <case>"
  echo "workdirs:    /opt/reverse-skill/work  (host ./work via repo bind mount); /home/analyst/work is a named volume"
else
  echo "WARN: package not mounted at $ROOT — mount the repo: -v \"\$PWD\":/opt/reverse-skill" >&2
fi

exec "$@"
