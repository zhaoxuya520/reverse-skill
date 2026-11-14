#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

echo "=== Testing Bash Workflow ==="

# Portable in-place rewrite: works with GNU sed and BSD sed (macOS).
# Avoids platform-specific `sed -i` / `sed -i ''` branching.
replace_in_file() {
    local expr="$1"
    local file="$2"
    local tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    sed "$expr" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Test 1: case-init.sh creates proper structure
echo "[Test 1] case-init.sh basic execution"
bash "$SCRIPT_DIR/case-init.sh" \
  --hint "authorized web review" \
  --case-name "test-bash-01" \
  --package-root "$SCRATCH" \
  --auth-granted \
  --target-url "https://example.test/" \
  --network-profile "authorized_target_only" > /dev/null

if [ ! -f "$SCRATCH/work/test-bash-01/scope.md" ]; then
    echo "FAIL: scope.md not created"
    exit 1
fi

# Test 2: case-init.sh rejects unknown presets before writing artifacts
echo "[Test 2] case-init.sh rejects unknown preset"
invalid_preset_case="test-bash-invalid-preset"
if bash "$SCRIPT_DIR/case-init.sh" \
  --hint "invalid preset regression" \
  --case-name "$invalid_preset_case" \
  --project-root "$SCRATCH" \
  --preset "definitely-not-valid" > /dev/null 2>&1; then
    echo "FAIL: case-init accepted unknown preset"
    exit 1
fi

if [ -e "$SCRATCH/work/$invalid_preset_case" ]; then
    echo "FAIL: case-init wrote a partial case for unknown preset"
    exit 1
fi

# Test 3: case-guard.sh validates valid scope
echo "[Test 3] case-guard.sh accepts valid scope"
if ! bash "$SCRIPT_DIR/case-guard.sh" --case-root "$SCRATCH/work/test-bash-01" > /dev/null; then
    echo "FAIL: case-guard rejected valid scope"
    exit 1
fi

# Test 4: case-guard.sh rejects invalid network mode
echo "[Test 4] case-guard.sh rejects invalid network mode"
replace_in_file 's/mode: authorized_target_only/mode: invalid_mode/g' "$SCRATCH/work/test-bash-01/scope.md"
if bash "$SCRIPT_DIR/case-guard.sh" --case-root "$SCRATCH/work/test-bash-01" > /dev/null 2>&1; then
    echo "FAIL: case-guard accepted invalid network mode"
    exit 1
fi

# Test 5: case-guard.sh rejects ungranted auth
echo "[Test 5] case-guard.sh rejects ungranted auth"
replace_in_file 's/mode: invalid_mode/mode: authorized_target_only/g' "$SCRATCH/work/test-bash-01/scope.md"
replace_in_file 's/status: granted/status: pending/g' "$SCRATCH/work/test-bash-01/scope.md"
if bash "$SCRIPT_DIR/case-guard.sh" --case-root "$SCRATCH/work/test-bash-01" > /dev/null 2>&1; then
    echo "FAIL: case-guard accepted pending auth"
    exit 1
fi

echo "TOTAL=5 PASS=5 FAIL=0"
echo "=== All Bash Workflow Tests Passed ==="
