#!/usr/bin/env bash
# Lightweight scope gate before ACT. Exit 0=ok, 2=not ready, 1=usage/error.
# Usage:
#   bash skills/scripts/case-guard.sh --case-root work/my-case
#   bash skills/scripts/case-guard.sh --case-root work/my-case --force
set -euo pipefail

CASE_ROOT=""
FORCE=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -CaseRoot|--case-root) CASE_ROOT="${2:-}"; shift 2 ;;
    -Force|--force) FORCE=1; shift ;;
    -Quiet|--quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

info() { [[ $QUIET -eq 1 ]] || echo "$*"; }

if [[ -z "$CASE_ROOT" ]]; then
  echo "ERROR: --case-root required" >&2
  exit 1
fi
if [[ ! -d "$CASE_ROOT" ]]; then
  echo "ERROR: CaseRoot missing: $CASE_ROOT" >&2
  exit 1
fi

SCOPE_PATH="$CASE_ROOT/scope.md"
if [[ ! -f "$SCOPE_PATH" ]]; then
  echo "ERROR: scope.md missing under $CASE_ROOT" >&2
  exit 1
fi

SCOPE="$(cat "$SCOPE_PATH")"
ISSUES=()

if printf '%s' "$SCOPE" | grep -Eq '(?m)^\s*-\s*status:\s*granted\s*$' 2>/dev/null; then
  :
fi
# portable: no PCRE required
auth_granted=0
if printf '%s\n' "$SCOPE" | grep -Eiq '^[[:space:]]*-[[:space:]]*status:[[:space:]]*granted[[:space:]]*$'; then
  auth_granted=1
elif printf '%s\n' "$SCOPE" | grep -Eiq '^[[:space:]]*status:[[:space:]]*granted[[:space:]]*$'; then
  auth_granted=1
fi
[[ $auth_granted -eq 1 ]] || ISSUES+=("auth.status is not granted")

net_mode=""
net_mode="$(printf '%s\n' "$SCOPE" | grep -E '^[[:space:]]*-[[:space:]]*mode:[[:space:]]*\S+' | head -1 | sed -E 's/^[[:space:]]*-[[:space:]]*mode:[[:space:]]*//' | tr -d '\r' | awk '{print $1}')"
if [[ -z "$net_mode" ]]; then
  ISSUES+=("network_profile.mode missing")
elif [[ "$net_mode" == "offline" ]]; then
  if ! printf '%s' "$SCOPE" | grep -Eiq 'sample|offline.?path|本地.?样本|\.apk\b|\.bin\b|\.exe\b'; then
    ISSUES+=("network_profile.mode is offline without offline sample cue")
  fi
fi

has_asset=0
# crude: look for indented list items after assets: that are not []
if printf '%s\n' "$SCOPE" | awk '
  BEGIN{inscope=0; inassets=0}
  /^##[[:space:]]*in_scope/ {inscope=1; inassets=0; next}
  /^##[[:space:]]/ {if(inscope){inscope=0; inassets=0}}
  inscope && /-[[:space:]]*assets:/ {inassets=1; next}
  inscope && inassets && /^[[:space:]]+-[[:space:]]+/ {
    line=$0
    sub(/^[[:space:]]+-[[:space:]]+/,"",line)
    if (line !~ /^\[/ && length(line)>0) { found=1 }
  }
  END{ exit(found?0:1) }
'; then
  has_asset=1
fi
if [[ $has_asset -eq 0 && "$net_mode" != "offline" ]]; then
  ISSUES+=("in_scope.assets appears empty")
fi

ready=0
if printf '%s\n' "$SCOPE" | grep -Eiq '^[[:space:]]*-[[:space:]]*ready_for_act:[[:space:]]*true[[:space:]]*$'; then
  ready=1
fi
[[ $ready -eq 1 ]] || ISSUES+=("ready_for_act is not true")

if [[ ${#ISSUES[@]} -eq 0 ]]; then
  info "CASE-GUARD OK: $CASE_ROOT"
  exit 0
fi

echo "CASE-GUARD NOT READY: $CASE_ROOT"
for i in "${ISSUES[@]}"; do echo " - $i"; done

if [[ $FORCE -eq 1 ]]; then
  echo "CASE-GUARD: --force set; continuing with warnings only."
  exit 0
fi

echo "Fix scope (or re-run case-init with --auth-granted --target-url ...) or pass --force."
exit 2
