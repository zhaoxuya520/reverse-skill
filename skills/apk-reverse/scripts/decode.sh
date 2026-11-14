#!/usr/bin/env bash
# decode.sh — APK 解包（jadx 反编译 + apktool 解包）
# 等价于 Windows 版的 decode.ps1
#
# 用法:
#   bash decode.sh <apk_path> [--name <task_name>] [--out <output_dir>]
#                              [--skip-jadx] [--skip-apktool] [--clean]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALI_BOOTSTRAP="$(cd "$SCRIPT_DIR/../../../kali/scripts" 2>/dev/null && pwd)/bootstrap-reverse.sh"

# ─── 参数解析 ──────────────────────────────────────────────────────────────────────

APK_PATH=""
TASK_NAME=""
OUT_ROOT=""
SKIP_JADX=false
SKIP_APKTOOL=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) TASK_NAME="$2"; shift 2 ;;
        --out) OUT_ROOT="$2"; shift 2 ;;
        --skip-jadx) SKIP_JADX=true; shift ;;
        --skip-apktool) SKIP_APKTOOL=true; shift ;;
        --clean) CLEAN=true; shift ;;
        -*) echo "未知选项: $1"; exit 1 ;;
        *) APK_PATH="$1"; shift ;;
    esac
done

if [[ -z "$APK_PATH" ]]; then
    echo "用法: $0 <apk_path> [--name <name>] [--out <dir>] [--skip-jadx] [--skip-apktool] [--clean]"
    exit 1
fi

if [[ ! -f "$APK_PATH" ]]; then
    echo "ERR: APK 文件不存在: $APK_PATH"
    exit 1
fi

# ─── 工具检测与自动安装 ─────────────────────────────────────────────────────────────

ensure_tool() {
    local name="$1"
    if command -v "$name" &>/dev/null; then
        return 0
    fi
    echo "INFO: $name 未找到，尝试自动安装..."
    if [[ -x "$KALI_BOOTSTRAP" ]]; then
        bash "$KALI_BOOTSTRAP" "$name" --skip-refresh 2>/dev/null || true
    fi
    if ! command -v "$name" &>/dev/null; then
        echo "ERR: $name 安装失败，请手动安装"
        return 1
    fi
    echo "INFO: $name 安装成功"
}

[[ "$SKIP_JADX" != "true" ]] && ensure_tool "jadx"
[[ "$SKIP_APKTOOL" != "true" ]] && ensure_tool "apktool"

# ─── 路径计算 ──────────────────────────────────────────────────────────────────────

APK_BASENAME=$(basename "$APK_PATH" .apk | sed 's/[^A-Za-z0-9._-]/_/g')
TASK_NAME="${TASK_NAME:-$APK_BASENAME}"
OUT_ROOT="${OUT_ROOT:-$(dirname "$APK_PATH")}"
TASK_ROOT="$OUT_ROOT/$TASK_NAME"
JADX_OUT="$TASK_ROOT/jadx"
APKTOOL_OUT="$TASK_ROOT/apktool"

if [[ "$CLEAN" == "true" && -d "$TASK_ROOT" ]]; then
    rm -rf "$TASK_ROOT"
fi

mkdir -p "$TASK_ROOT"

# ─── jadx 反编译 ──────────────────────────────────────────────────────────────────

JADX_EXIT=0
if [[ "$SKIP_JADX" != "true" ]]; then
    rm -rf "$JADX_OUT"
    echo "=== jadx 反编译 ==="
    jadx -d "$JADX_OUT" "$APK_PATH" || JADX_EXIT=$?
fi

# ─── apktool 解包 ─────────────────────────────────────────────────────────────────

APKTOOL_EXIT=0
if [[ "$SKIP_APKTOOL" != "true" ]]; then
    rm -rf "$APKTOOL_OUT"
    echo "=== apktool 解包 ==="
    apktool d "$APK_PATH" -o "$APKTOOL_OUT" -f || APKTOOL_EXIT=$?
fi

# ─── 统计输出 ──────────────────────────────────────────────────────────────────────

PACKAGE=""
if [[ -f "$APKTOOL_OUT/AndroidManifest.xml" ]]; then
    PACKAGE=$(grep -oE 'package="[^"]*"' "$APKTOOL_OUT/AndroidManifest.xml" 2>/dev/null | head -1 | sed 's/package="//;s/"//')
fi

JAVA_COUNT=0
[[ -d "$JADX_OUT" ]] && JAVA_COUNT=$(find "$JADX_OUT" -name "*.java" | wc -l)

SMALI_DIRS=0
[[ -d "$APKTOOL_OUT" ]] && SMALI_DIRS=$(find "$APKTOOL_OUT" -maxdepth 1 -type d -name "smali*" | wc -l)

SO_COUNT=0
[[ -d "$APKTOOL_OUT" ]] && SO_COUNT=$(find "$APKTOOL_OUT" -name "*.so" | wc -l)

echo ""
echo "═══════════════════════════════════════════"
echo "  APK 解包完成"
echo "═══════════════════════════════════════════"
echo "  task_root=$TASK_ROOT"
echo "  jadx_out=$JADX_OUT"
echo "  apktool_out=$APKTOOL_OUT"
echo "  package=$PACKAGE"
echo "  jadx_exit_code=$JADX_EXIT"
echo "  apktool_exit_code=$APKTOOL_EXIT"
echo "  java_files=$JAVA_COUNT"
echo "  smali_dirs=$SMALI_DIRS"
echo "  so_files=$SO_COUNT"
