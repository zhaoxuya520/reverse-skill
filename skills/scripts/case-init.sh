#!/usr/bin/env bash
# reverse-skill case initializer (bash parity of case-init.ps1 + offline/ctf presets)
# Usage:
#   bash skills/scripts/case-init.sh --hint "apk reverse" --case-name demo
#   bash skills/scripts/case-init.sh --hint "local sample" --preset offline-sample --sample ./app.apk
#   bash skills/scripts/case-init.sh --hint "ctf web" --preset ctf-public --target-url https://chal.example
set -euo pipefail

HINT=""
CASE_NAME=""
PACKAGE_ROOT=""
AUTH_STATUS=""
AUTH_GRANTED=0
AUTH_BASIS="unknown"
EVIDENCE_OF_AUTH=""
TARGET_URL=""
NETWORK_PROFILE=""
SAMPLE=""
PRESET=""
IN_SCOPE_ASSETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Hint|--hint) HINT="${2:-}"; shift 2 ;;
    -CaseName|--case-name) CASE_NAME="${2:-}"; shift 2 ;;
    -PackageRoot|--package-root) PACKAGE_ROOT="${2:-}"; shift 2 ;;
    -AuthStatus|--auth-status) AUTH_STATUS="${2:-}"; shift 2 ;;
    -AuthGranted|--auth-granted) AUTH_GRANTED=1; shift ;;
    -AuthBasis|--auth-basis) AUTH_BASIS="${2:-}"; shift 2 ;;
    -EvidenceOfAuth|--evidence-of-auth) EVIDENCE_OF_AUTH="${2:-}"; shift 2 ;;
    -TargetUrl|--target-url) TARGET_URL="${2:-}"; shift 2 ;;
    -NetworkProfile|--network-profile) NETWORK_PROFILE="${2:-}"; shift 2 ;;
    -Sample|--sample|--offline-sample) SAMPLE="${2:-}"; shift 2 ;;
    -Preset|--preset) PRESET="${2:-}"; shift 2 ;;
    -InScopeAssets|--in-scope-asset) IN_SCOPE_ASSETS+=("${2:-}"); shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *)
      if [[ -z "$HINT" && "$1" != -* ]]; then HINT="$1"; shift
      else echo "Unknown arg: $1" >&2; exit 2; fi
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -z "$PACKAGE_ROOT" ]]; then
  PACKAGE_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"
fi

# Presets: reduce "AI refuses to work" friction for legitimate local/CTF work.
case "$PRESET" in
  "" ) ;;
  offline-sample|own-sample|local-sample)
    AUTH_GRANTED=1
    AUTH_STATUS="granted"
    AUTH_BASIS="own_system"
    NETWORK_PROFILE="${NETWORK_PROFILE:-offline}"
    EVIDENCE_OF_AUTH="${EVIDENCE_OF_AUTH:-preset:offline-sample (owner-operated local file)}"
    if [[ -n "$SAMPLE" ]]; then IN_SCOPE_ASSETS+=("$SAMPLE"); fi
    ;;
  ctf-public|ctf)
    AUTH_GRANTED=1
    AUTH_STATUS="granted"
    AUTH_BASIS="ctf_public"
    NETWORK_PROFILE="${NETWORK_PROFILE:-authorized_target_only}"
    EVIDENCE_OF_AUTH="${EVIDENCE_OF_AUTH:-preset:ctf-public}"
    ;;
  own-system|lab-only)
    AUTH_GRANTED=1
    AUTH_STATUS="granted"
    AUTH_BASIS="own_system"
    NETWORK_PROFILE="${NETWORK_PROFILE:-lab_only}"
    EVIDENCE_OF_AUTH="${EVIDENCE_OF_AUTH:-preset:own-system/lab}"
    ;;
  *)
    echo "WARN: unknown preset '$PRESET' (allowed: offline-sample|ctf-public|own-system)" >&2
    ;;
esac

if [[ -z "$CASE_NAME" ]]; then
  slug="$(printf '%s' "$HINT" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/^$/case/' | cut -c1-40)"
  CASE_NAME="$(date +%Y%m%d-%H%M%S)-${slug}"
fi

CASE_ROOT="$PACKAGE_ROOT/work/$CASE_NAME"
mkdir -p "$CASE_ROOT/evidence" "$CASE_ROOT/notes" "$CASE_ROOT/report"

auth_status_resolved="pending"
if [[ $AUTH_GRANTED -eq 1 ]]; then auth_status_resolved="granted"; fi
if [[ -n "$AUTH_STATUS" ]]; then
  candidate="$(printf '%s' "$AUTH_STATUS" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$candidate" in
    pending|granted|denied|unknown) auth_status_resolved="$candidate" ;;
    *) echo "WARN: ignoring invalid --auth-status '$AUTH_STATUS'" >&2 ;;
  esac
fi

if [[ -n "$EVIDENCE_OF_AUTH" ]]; then
  evidence_auth="$EVIDENCE_OF_AUTH"
elif [[ $AUTH_GRANTED -eq 1 || "$auth_status_resolved" == "granted" ]]; then
  evidence_auth="cli-flag AuthGranted or AuthStatus=granted"
else
  evidence_auth="FILL_ME"
fi

ASSETS=()
[[ -n "$TARGET_URL" ]] && ASSETS+=("$TARGET_URL")
[[ -n "$SAMPLE" ]] && ASSETS+=("$SAMPLE")
for a in "${IN_SCOPE_ASSETS[@]:-}"; do
  [[ -n "$a" ]] || continue
  dup=0
  for e in "${ASSETS[@]:-}"; do [[ "$e" == "$a" ]] && dup=1 && break; done
  [[ $dup -eq 0 ]] && ASSETS+=("$a")
done
if [[ ${#ASSETS[@]} -eq 0 && "$HINT" =~ https?://([^[:space:]/]+) ]]; then
  ASSETS+=("https://${BASH_REMATCH[1]}/")
fi

network_mode="${NETWORK_PROFILE:-offline}"

# Route PRIMARY via bash master-route
ROUTE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/rs-case-route.XXXXXX")"
primary="reverse-engineering/SKILL.md"
primary_id="R0"
if [[ -f "$SCRIPT_DIR/master-route.sh" ]]; then
  set +e
  bash "$SCRIPT_DIR/master-route.sh" --hint "$HINT" --out-dir "$ROUTE_TMP" >/dev/null 2>&1
  set -e
  if [[ -f "$ROUTE_TMP/route-scope.md" ]]; then
    rt="$(cat "$ROUTE_TMP/route-scope.md")"
    if printf '%s\n' "$rt" | grep -Eq '^[[:space:]]*-[[:space:]]*primary_skill:[[:space:]]*skills/'; then
      primary="$(printf '%s\n' "$rt" | grep -E '^[[:space:]]*-[[:space:]]*primary_skill:[[:space:]]*skills/' | head -1 | sed -E 's/.*skills\///' | tr -d '\r')"
    fi
    if printf '%s\n' "$rt" | grep -Eq '^[[:space:]]*-[[:space:]]*primary:[[:space:]]*'; then
      primary_id="$(printf '%s\n' "$rt" | grep -E '^[[:space:]]*-[[:space:]]*primary:[[:space:]]*' | head -1 | sed -E 's/.*primary:[[:space:]]*//' | tr -d '\r')"
    fi
  fi
fi
rm -rf "$ROUTE_TMP"

created="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
if [[ ${#ASSETS[@]} -gt 0 ]]; then
  assets_block="$(printf '  - %s\n' "${ASSETS[@]}")"
else
  assets_block="  []"
fi

ready=false
if [[ "$auth_status_resolved" == "granted" && ( ${#ASSETS[@]} -gt 0 || "$network_mode" == "offline" ) ]]; then
  # offline without assets still not ready unless sample cue exists in hint/sample
  if [[ ${#ASSETS[@]} -gt 0 ]]; then ready=true
  elif [[ "$network_mode" == "offline" && ( -n "$SAMPLE" || "$HINT" =~ \.(apk|bin|exe|so|dll|ipa) ) ]]; then ready=true
  fi
fi

check_auth="[ ]"; [[ "$auth_status_resolved" == "granted" ]] && check_auth="[x]"
check_scope="[ ]"; [[ ${#ASSETS[@]} -gt 0 || "$network_mode" == "offline" ]] && check_scope="[x]"
check_net="[ ]"; [[ -n "$network_mode" ]] && check_net="[x]"
ready_str="false"; [[ "$ready" == true ]] && ready_str="true"

if [[ "$ready" == true ]]; then
  timeline_next="open PRIMARY SKILL.md and ACT within scope"
  timeline_summary="case directory created; scope ready_for_act=true"
else
  timeline_next="fill scope auth + in_scope; set ready_for_act"
  timeline_summary="case directory created; scope pending auth"
fi

cat > "$CASE_ROOT/scope.md" <<EOF
# Case Scope

## meta
- case_id: $CASE_NAME
- created: $created
- operator: local
- primary_skill: $primary
- primary_id: $primary_id
- lead_role: lead
- specialist_roles: []
- hint: $HINT
- preset: ${PRESET:-none}

## auth
- status: $auth_status_resolved
- basis: $AUTH_BASIS
- evidence_of_auth: $evidence_auth
- MUST NOT proceed if status != granted

## in_scope
- assets:
$assets_block
- surfaces: []
- activities: []

## out_of_scope
- assets: []
- activities: [dos, phishing_real_users, unrestricted_exfil]

## network_profile
- mode: $network_mode
- notes: |
    offline | lab_only | authorized_target_only | unrestricted_lab
    Change mode only after auth.status = granted.
    Presets: offline-sample | ctf-public | own-system

## deliverables
- report: true
- field_journal: true
- diagrams: true
- timeline: true

## constraints
- timebox: {}
- stealth: low
- data_handling: anonymize

## signoff
- ready_for_act: $ready_str
- checklist:
  - $check_auth auth.status = granted
  - $check_scope in_scope.assets non-empty OR offline sample path set
  - $check_net network_profile.mode chosen
  - [ ] out_of_scope reviewed
  - [ ] roles assigned (see skills/ops/role-map.md)

## ops_refs
- skills/ops/scope-contract.md
- skills/ops/evidence-finding-path.md
- skills/ops/role-map.md
- skills/ops/timeline-workitem.md
- skills/ops/IDENTITY.md
EOF

cat > "$CASE_ROOT/timeline.md" <<EOF
# Timeline (append-only)

## $created | lead | init
- action: case-init
- command_or_ref: skills/scripts/case-init.sh
- result_summary: $timeline_summary
- artifacts: [scope.md, workitems.md]
- evidence_ids: []
- next: $timeline_next
EOF

cat > "$CASE_ROOT/workitems.md" <<'EOF'
# Work Items

| ID | title | role | targets | surface | status | evidence | notes |
|----|-------|------|---------|---------|--------|----------|-------|
| WI-001 | Establish scope and auth | lead | case | process | in_progress | | |

## Coverage
- [ ] Recon/analysis complete for in_scope assets
- [ ] Critical/High candidates triaged (or N/A for pure RE)
- [ ] Validated findings have Evidence (E-*)
- [ ] Path documented (attack/call/solve)
- [ ] Timeline continuous across major phases
- [ ] Report via docs-generator
- [ ] field-journal anonymized

## Refs
- skills/ops/timeline-workitem.md
- skills/ops/evidence-finding-path.md
EOF

if [[ "$ready" == true ]]; then
  cat > "$CASE_ROOT/README.md" <<EOF
# Case $CASE_NAME

1. Scope is ready_for_act=true (auth granted + in_scope set)
2. Open primary skill: skills/$primary
3. Append \`timeline.md\`; update \`workitems.md\`
4. Append Evidence under \`evidence/\`
5. Promote findings with Evidence chain (skills/ops/evidence-finding-path.md)
6. Report via docs-generator; journal via field-journal
EOF
else
  cat > "$CASE_ROOT/README.md" <<EOF
# Case $CASE_NAME

1. Edit \`scope.md\` — set auth.status=granted and in_scope
   - or re-run: \`bash skills/scripts/case-init.sh --hint "..." --preset offline-sample --sample ./sample.apk\`
   - or: \`--preset ctf-public --target-url https://...\`
2. Set ready_for_act when checklist complete
3. Open primary skill: skills/$primary
4. Append \`timeline.md\`; update \`workitems.md\`
5. Promote findings with Evidence chain (skills/ops/evidence-finding-path.md)
6. Report via docs-generator; journal via field-journal
EOF
fi

echo "CASE -> $CASE_ROOT"
echo "PRIMARY skill: skills/$primary ($primary_id)"
echo "auth.status=$auth_status_resolved network_profile=$network_mode ready_for_act=$ready_str"
if [[ "$ready" == true ]]; then
  echo "NEXT: open PRIMARY SKILL.md and ACT within scope"
else
  echo "NEXT: fill scope.md auth + in_scope; then open PRIMARY SKILL.md"
  echo "HINT: try --preset offline-sample|--preset ctf-public|--preset own-system"
fi
