#!/usr/bin/env bash
# Regression: the apk-reverse decode summary must work with the system grep.
# `grep -oP` is GNU-only; on BSD grep (macOS) it fails, and because decode.sh
# runs under `set -euo pipefail` the failing pipeline aborts the script before
# the summary block is printed at all.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

DECODE="$REPO_ROOT/skills/apk-reverse/scripts/decode.sh"
EXPECTED_PACKAGE="com.example.fixture"

echo "=== Testing APK Decode Manifest Summary ==="

# Fixture: an APK path plus the apktool output that decode.sh would summarize.
mkdir -p "$SCRATCH/fixture/apktool"
: > "$SCRATCH/fixture.apk"
cat > "$SCRATCH/fixture/apktool/AndroidManifest.xml" <<'MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" android:compileSdkVersion="34" package="com.example.fixture">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="Fixture" />
</manifest>
MANIFEST

# Test 1: decode.sh reaches its summary (no abort from a portability failure)
echo "[Test 1] decode.sh completes when jadx/apktool are skipped"
if ! OUTPUT="$(bash "$DECODE" "$SCRATCH/fixture.apk" --skip-jadx --skip-apktool 2>&1)"; then
    echo "FAIL: decode.sh exited non-zero"
    printf '%s\n' "$OUTPUT"
    exit 1
fi

# Test 2: the manifest package attribute is reported
echo "[Test 2] decode.sh reports the manifest package"
if ! printf '%s\n' "$OUTPUT" | grep -Fq "package=$EXPECTED_PACKAGE"; then
    echo "FAIL: expected package=$EXPECTED_PACKAGE"
    printf '%s\n' "$OUTPUT"
    exit 1
fi

echo "TOTAL=2 PASS=2 FAIL=0"
echo "=== All APK Decode Manifest Tests Passed ==="
