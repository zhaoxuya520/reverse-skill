#!/usr/bin/env bash
# rebuild-sign-install.sh — APK 重打包 + 签名 + 安装
# 等价于 Windows 版的 rebuild-sign-install.ps1
#
# 用法:
#   bash rebuild-sign-install.sh <project_dir> [--out <dir>] [--name <base>]
#                                [--keystore <path>] [--install] [--reinstall]
#                                [--device <serial>] [--clean]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALI_BOOTSTRAP="$(cd "$SCRIPT_DIR/../../../kali/scripts" 2>/dev/null && pwd)/bootstrap-reverse.sh"
DEFAULT_KEYSTORE="$HOME/.android/debug.keystore"

# ─── 参数 ──────────────────────────────────────────────────────────────────────────

PROJECT_DIR=""
OUT_DIR=""
BASE_NAME=""
KEYSTORE="$DEFAULT_KEYSTORE"
KEY_ALIAS="androiddebugkey"
STORE_PASS="android"
KEY_PASS="android"
DEVICE_SERIAL=""
DO_INSTALL=false
REINSTALL=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT_DIR="$2"; shift 2 ;;
        --name) BASE_NAME="$2"; shift 2 ;;
        --keystore) KEYSTORE="$2"; shift 2 ;;
        --alias) KEY_ALIAS="$2"; shift 2 ;;
        --store-pass) STORE_PASS="$2"; shift 2 ;;
        --key-pass) KEY_PASS="$2"; shift 2 ;;
        --device) DEVICE_SERIAL="$2"; shift 2 ;;
        --install) DO_INSTALL=true; shift ;;
        --reinstall) REINSTALL=true; DO_INSTALL=true; shift ;;
        --clean) CLEAN=true; shift ;;
        -*) echo "未知选项: $1"; exit 1 ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done

if [[ -z "$PROJECT_DIR" || ! -d "$PROJECT_DIR" ]]; then
    echo "用法: $0 <apktool_project_dir> [options]"
    echo "  --out <dir>        输出目录（默认: 项目父目录）"
    echo "  --name <base>      输出文件名前缀"
    echo "  --keystore <path>  签名密钥库（默认: ~/.android/debug.keystore）"
    echo "  --install          签名后安装到设备"
    echo "  --reinstall        覆盖安装"
    echo "  --device <serial>  指定设备"
    echo "  --clean            清理旧产物"
    exit 1
fi

# ─── 工具检测 ──────────────────────────────────────────────────────────────────────

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
        echo "ERR: $name 不可用。"
        case "$name" in
            zipalign|apksigner) echo "  安装: sudo apt install android-sdk-build-tools 或 sdkmanager 'build-tools;35.0.0'" ;;
            *) echo "  请手动安装 $name" ;;
        esac
        exit 1
    fi
}

ensure_tool "apktool"
ensure_tool "zipalign"
ensure_tool "apksigner"
ensure_tool "keytool"
[[ "$DO_INSTALL" == "true" ]] && ensure_tool "adb"

# ─── 生成 debug keystore（如果不存在） ─────────────────────────────────────────────

if [[ ! -f "$KEYSTORE" ]]; then
    mkdir -p "$(dirname "$KEYSTORE")"
    echo "INFO: 生成 debug keystore: $KEYSTORE"
    keytool -genkeypair -v \
        -keystore "$KEYSTORE" \
        -storepass "$STORE_PASS" \
        -keypass "$KEY_PASS" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=ReverseSkill,C=CN"
fi

# ─── 路径计算 ──────────────────────────────────────────────────────────────────────

OUT_DIR="${OUT_DIR:-$(dirname "$PROJECT_DIR")}"
BASE_NAME="${BASE_NAME:-$(basename "$PROJECT_DIR")}"
mkdir -p "$OUT_DIR"

UNSIGNED_APK="$OUT_DIR/${BASE_NAME}-unsigned.apk"
ALIGNED_APK="$OUT_DIR/${BASE_NAME}-aligned.apk"
SIGNED_APK="$OUT_DIR/${BASE_NAME}-signed.apk"

if [[ "$CLEAN" == "true" ]]; then
    rm -f "$UNSIGNED_APK" "$ALIGNED_APK" "$SIGNED_APK"
fi

# ─── 重打包 ───────────────────────────────────────────────────────────────────────

echo "=== apktool 重打包 ==="
apktool b "$PROJECT_DIR" -o "$UNSIGNED_APK"

# ─── 对齐 ─────────────────────────────────────────────────────────────────────────

echo "=== zipalign 对齐 ==="
zipalign -f -p 4 "$UNSIGNED_APK" "$ALIGNED_APK"

# ─── 签名 ─────────────────────────────────────────────────────────────────────────

echo "=== apksigner 签名 ==="
apksigner sign \
    --ks "$KEYSTORE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass "pass:$STORE_PASS" \
    --key-pass "pass:$KEY_PASS" \
    --out "$SIGNED_APK" \
    "$ALIGNED_APK"

# ─── 验证 ─────────────────────────────────────────────────────────────────────────

echo "=== 验证签名 ==="
apksigner verify --print-certs "$SIGNED_APK"

echo ""
echo "═══════════════════════════════════════════"
echo "  APK 重打包完成"
echo "═══════════════════════════════════════════"
echo "  unsigned_apk=$UNSIGNED_APK"
echo "  aligned_apk=$ALIGNED_APK"
echo "  signed_apk=$SIGNED_APK"
echo "  keystore=$KEYSTORE"

# ─── 安装 ─────────────────────────────────────────────────────────────────────────

if [[ "$DO_INSTALL" == "true" ]]; then
    echo "=== adb 安装 ==="
    ADB_ARGS=()
    [[ -n "$DEVICE_SERIAL" ]] && ADB_ARGS+=("-s" "$DEVICE_SERIAL")
    ADB_ARGS+=("install")
    [[ "$REINSTALL" == "true" ]] && ADB_ARGS+=("-r")
    ADB_ARGS+=("$SIGNED_APK")

    adb "${ADB_ARGS[@]}"
    echo "  install_device=${DEVICE_SERIAL:-default}"
fi
