#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

echo "=== Testing Bash Workflow ==="

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

# Test 2: case-guard.sh validates valid scope
echo "[Test 2] case-guard.sh accepts valid scope"
if ! bash "$SCRIPT_DIR/case-guard.sh" --case-root "$SCRATCH/work/test-bash-01" > /dev/null; then
    echo "FAIL: case-guard rejected valid scope"
    exit 1
fi

# Test 3: case-guard.sh rejects invalid network mode
echo "[Test 3] case-guard.sh rejects invalid network mode"
sed -i 's/mode: authorized_target_only/mode: invalid_mode/g' "$SCRATCH/work/test-bash-01/scope.md"
if bash "$SCRIPT_DIR/case-guard.sh" --case-root "$SCRATCH/work/test-bash-01" > /dev/null 2>&1; then
    echo "FAIL: case-guard accepted invalid network mode"
    exit 1
fi

# Test 4: case-guard.sh rejects ungranted auth
echo "[Test 4] case-guard.sh rejects ungranted auth"
sed -i 's/mode: invalid_mode/mode: authorized_target_only/g' "$SCRATCH/work/test-bash-01/scope.md"
sed -i 's/status: granted/status: pending/g' "$SCRATCH/work/test-bash-01/scope.md"
if bash "$SCRIPT_DIR/case-guard.sh" --case-root "$SCRATCH/work/test-bash-01" > /dev/null 2>&1; then
    echo "FAIL: case-guard accepted pending auth"
    exit 1
fi

echo "=== All Bash Workflow Tests Passed ==="
