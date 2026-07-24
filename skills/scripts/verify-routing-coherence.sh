#!/usr/bin/env bash
# reverse-skill routing + ops contract gates (bash parity of verify-routing-coherence.ps1)
# Usage: bash skills/scripts/verify-routing-coherence.sh [--scratch-dir DIR]
set -euo pipefail

SCRATCH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -ScratchDir|--scratch-dir) SCRATCH="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"
MASTER_ROUTE="$SCRIPT_DIR/master-route.sh"
CASE_INIT="$SCRIPT_DIR/case-init.sh"

if [[ -z "$SCRATCH" ]]; then
  SCRATCH="${TMPDIR:-/tmp}/rs-verify-$(date +%Y%m%d%H%M%S)"
fi
mkdir -p "$SCRATCH"

FAIL=()
ok() { echo "[OK] $*"; }
bad() { echo "[FAIL] $*"; FAIL+=("$*"); }

ops_files=(
  "ops/IDENTITY.md"
  "ops/scope-contract.md"
  "ops/evidence-finding-path.md"
  "ops/role-map.md"
  "ops/timeline-workitem.md"
  "ops/sandbox-profile.md"
  "ops/skill-supply-chain.md"
  "ops/README.md"
  "references/community-security-skills.md"
  "references/domain-coverage-map.md"
  "references/skill-maturity.md"
  "attack-chain/references/lifecycle-checklist.md"
  "reverse-engineering/references/re-agent-workflow.md"
  "pentest-tools/references/recon-pipeline.md"
  "MASTER-ROUTING.md"
  "scripts/master-route.ps1"
  "scripts/master-route.sh"
  "scripts/case-init.ps1"
  "scripts/case-init.sh"
  "scripts/case-guard.sh"
  "docs-generator/references/security-report-templates.md"
  "field-journal/_template.md"
)

: > "$SCRATCH/artifacts-index.txt"
for rel in "${ops_files[@]}"; do
  if [[ -e "$SKILLS_ROOT/$rel" ]]; then
    ok "artifact $rel"
    echo "OK $rel" >> "$SCRATCH/artifacts-index.txt"
  else
    bad "missing $rel"
    echo "MISS $rel" >> "$SCRATCH/artifacts-index.txt"
  fi
done

for hub in MASTER-ROUTING.md SKILL.md routing.md; do
  t="$(cat "$SKILLS_ROOT/$hub")"
  case "$t" in
    *ops/scope-contract*|*case-init*) ok "hub link scope in $hub" ;;
    *) bad "hub $hub missing scope/case-init link" ;;
  esac
  case "$t" in
    *ops/IDENTITY*|*IDENTITY.md*) ok "hub identity $hub" ;;
    *) bad "hub $hub missing IDENTITY" ;;
  esac
done

hub_all=""
for hub in MASTER-ROUTING.md SKILL.md ops/README.md routing.md; do
  [[ -f "$SKILLS_ROOT/$hub" ]] && hub_all="${hub_all}$(cat "$SKILLS_ROOT/$hub")"
done
for n in community-security-skills skill-supply-chain re-agent-workflow recon-pipeline; do
  # use case — more reliable than grep -F on large strings under bash 3.2/macOS
  case "$hub_all" in
    *"$n"*) ok "hub surfaces $n" ;;
    *) bad "hub missing surface for $n" ;;
  esac
done

for rp in "$PACKAGE_ROOT/RULES.md" "$PACKAGE_ROOT/RULES_zh.md"; do
  name="$(basename "$rp")"
  if [[ ! -f "$rp" ]]; then bad "missing $name"; continue; fi
  rt="$(cat "$rp")"
  if printf '%s' "$rt" | grep -Fq 'case-init' && printf '%s' "$rt" | grep -Eq 'scope-contract|scope\.md|network_profile'; then
    ok "$name has case-init/scope gate"
  else
    bad "$name missing case-init/scope/network_profile gate"
  fi
  if printf '%s' "$rt" | grep -Eq 'auth\.status\s*=\s*granted|auth.status=granted|未就绪禁止|MUST NOT ACT against targets|禁止对目标 ACT'; then
    ok "$name has auth hard gate language"
  else
    bad "$name missing auth hard-gate language"
  fi
  # Global injection must be confirm-before-write (not silent MUST write)
  if printf '%s' "$rt" | grep -Eiq 'confirm before write|未经用户明确同意|MUST NOT silently|禁止.*静默|explicit consent|明确同意'; then
    ok "$name has confirm-before-write global injection"
  else
    bad "$name missing confirm-before-write global injection language"
  fi
done

assert_fields() {
  local path="$1"; shift
  local t; t="$(cat "$path")"
  local n
  for n in "$@"; do
    if printf '%s' "$t" | grep -Fq "$n"; then ok "field '$n' in $(basename "$path")"
    else bad "field '$n' missing in $path"; fi
  done
}

assert_fields "$SKILLS_ROOT/ops/scope-contract.md" auth in_scope out_of_scope network_profile ready_for_act
assert_fields "$SKILLS_ROOT/references/community-security-skills.md" trailofbits agentskills.io MUST 2026-07

# route matrix
declare -a CASES=(
  "apk|apk jadx reverse|R1|apk-reverse/SKILL.md"
  "js|js reverse frontend signature|R3|js-reverse/SKILL.md"
  "r2|radare2 analyze|R7|radare2/SKILL.md"
  "llm|llm prompt injection jailbreak garak|R14|llm-security/SKILL.md"
  "pwn|pwn rop ret2libc pwntools|R17|pwn-chain/SKILL.md"
  "ghidra|ghidra headless decompile|R22|ghidra-reverse/SKILL.md"
  "ad|bloodhound kerberoast active directory|R24|windows-ad/SKILL.md"
  "macos|macos mach-o codesign reverse|R31|macos-reverse/SKILL.md"
  "sdr|sdr hackrf gnu radio rf|R38|radio-sdr/SKILL.md"
)

for spec in "${CASES[@]}"; do
  IFS='|' read -r n h id sub <<<"$spec"
  out="$SCRATCH/route-$n"
  mkdir -p "$out"
  set +e
  stdout="$(bash "$MASTER_ROUTE" --hint "$h" --out-dir "$out" 2>&1)"
  rc=$?
  set -e
  printf '%s\n' "$stdout" > "$SCRATCH/route-$n.txt"
  if [[ ! -f "$out/route-scope.md" ]]; then bad "no scope $n"; continue; fi
  text="$(cat "$out/route-scope.md")"
  if printf '%s' "$text" | grep -Eq "^[[:space:]]*-[[:space:]]*primary:[[:space:]]*$id[[:space:]]*$"; then
    ok "$n -> $id"
  else
    bad "$n id want $id"
  fi
  if [[ -f "$SKILLS_ROOT/$sub" ]]; then ok "exists $sub"; else bad "missing $sub"; fi
done

for ghost in blockchain-security bitcoin-puzzle; do
  if [[ -e "$SKILLS_ROOT/$ghost" ]]; then bad "core must not contain skills/$ghost"
  else ok "no skills/$ghost"; fi
done

# default outdir under work/
set +e
def="$(bash "$MASTER_ROUTE" --hint 'radare2 analyze' 2>&1)"
set -e
printf '%s\n' "$def" > "$SCRATCH/default-out.txt"
if printf '%s' "$def" | grep -Eq 'work[/\\]master-route-'; then ok 'default OutDir under work/'
else bad 'default OutDir not under work/'; fi

case_name="verify-ops-$(date +%H%M%S)"
set +e
ci="$(bash "$CASE_INIT" --hint 'apk jadx reverse' --case-name "$case_name" --package-root "$PACKAGE_ROOT" 2>&1)"
set -e
printf '%s\n' "$ci" > "$SCRATCH/case-init.txt"
case_root="$PACKAGE_ROOT/work/$case_name"
for f in scope.md timeline.md workitems.md; do
  if [[ -f "$case_root/$f" ]]; then ok "case-init $f"; else bad "case-init missing $f"; fi
done
if [[ -f "$case_root/scope.md" ]]; then
  sc="$(cat "$case_root/scope.md")"
  for k in auth network_profile in_scope ready_for_act; do
    if printf '%s' "$sc" | grep -Fq "$k"; then ok "case scope has $k"; else bad "case scope missing $k"; fi
  done
fi

# preset offline ready path
preset_name="verify-offline-$(date +%H%M%S)"
set +e
ci2="$(bash "$CASE_INIT" --hint 'local apk reverse' --case-name "$preset_name" --package-root "$PACKAGE_ROOT" --preset offline-sample --sample /tmp/sample.apk 2>&1)"
set -e
printf '%s\n' "$ci2" > "$SCRATCH/case-init-preset.txt"
preset_root="$PACKAGE_ROOT/work/$preset_name"
if [[ -f "$preset_root/scope.md" ]] && grep -Eq 'ready_for_act:[[:space:]]*true' "$preset_root/scope.md"; then
  ok "offline-sample preset ready_for_act=true"
else
  bad "offline-sample preset not ready"
fi
if bash "$SCRIPT_DIR/case-guard.sh" --case-root "$preset_root" >/dev/null 2>&1; then
  ok "case-guard accepts offline-sample preset"
else
  bad "case-guard rejects offline-sample preset"
fi


# --- skill maturity honesty ---
mat_file="$SKILLS_ROOT/references/skill-maturity.md"
if [[ -f "$mat_file" ]]; then
  ok "skill-maturity.md present"
  # Extract experimental skill names from markdown table rows: | `name/` |
  # Only the first `name/` cell on each table row (not "prefer instead" links)
  exp_names="$(awk '/^## experimental/{p=1;next} /^## /{p=0} p' "$mat_file" | sed -n 's/^| `\([a-z0-9-]*\)\/`.*/\1/p')"
  if [[ -z "$exp_names" ]]; then
    bad "experimental section empty in skill-maturity.md"
  else
    ok "experimental section has names"
  fi
  for name in $exp_names; do
    sm="$SKILLS_ROOT/$name/SKILL.md"
    if [[ ! -f "$sm" ]]; then bad "experimental skill missing: $name"; continue; fi
    if grep -Eq '^maturity:[[:space:]]*experimental[[:space:]]*$' "$sm"; then
      ok "experimental fm $name"
    else
      bad "experimental fm missing on $name"
    fi
    if grep -Eiq 'Maturity:.*experimental' "$sm"; then
      ok "experimental banner $name"
    else
      bad "experimental banner missing on $name"
    fi
  done
  # hubs should surface maturity map
  if printf '%s' "$hub_all" | grep -Fq 'skill-maturity'; then ok "hub surfaces skill-maturity"
  else
    # hub_all may not include references; check MASTER + SKILL
    if grep -RFq 'skill-maturity' "$SKILLS_ROOT/MASTER-ROUTING.md" "$SKILLS_ROOT/SKILL.md" 2>/dev/null; then
      ok "hub surfaces skill-maturity"
    else
      bad "hubs missing skill-maturity link"
    fi
  fi
else
  bad "skill-maturity.md missing"
fi


# ghost dsl path scan
for rel in SKILL.md routing.md MASTER-ROUTING.md scripts/master-route.ps1 scripts/master-route.sh; do
  p="$SKILLS_ROOT/$rel"
  [[ -f "$p" ]] || continue
  t="$(cat "$p")"
  if printf '%s' "$t" | grep -Fq '`dsl-vm-reverse/' && ! printf '%s' "$t" | grep -Fq 'reverse-engineering/dsl-vm-reverse'; then
    bad "ghost dsl path in $rel"
  fi
done
ok 'ghost dsl scan done'

id="$(cat "$SKILLS_ROOT/ops/IDENTITY.md")"
if printf '%s' "$id" | grep -Eq '不是|不做|NOT|not a Z3r0|FastAPI|React'; then ok 'identity distinguishes platform'
else bad 'identity weak'; fi
if printf '%s' "$id" | grep -Eq 'tool-index|bootstrap|field-journal|路由'; then ok 'identity keeps reverse-skill DNA'
else bad 'identity missing DNA'; fi

echo "Scratch=$SCRATCH"
if [[ ${#FAIL[@]} -gt 0 ]]; then
  echo "FAILED ${#FAIL[@]}"
  printf ' - %s\n' "${FAIL[@]}"
  printf '%s\n' "${FAIL[@]}" > "$SCRATCH/failures.txt"
  exit 1
fi
echo "ALL ROUTING COHERENCE CHECKS PASSED"
echo "ALL ROUTING COHERENCE CHECKS PASSED" > "$SCRATCH/verify.txt"
exit 0
