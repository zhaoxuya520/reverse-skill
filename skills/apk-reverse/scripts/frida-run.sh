#!/usr/bin/env bash
# frida-run.sh — Frida 动态注入脚本
# 等价于 Windows 版的 frida-run.ps1
#
# 用法:
#   bash frida-run.sh --package <pkg> --script <js> [--usb] [--spawn]
#   bash frida-run.sh --list-devices
#   bash frida-run.sh --list-processes [--usb]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALI_BOOTSTRAP="$SCRIPT_DIR/../../../kali/scripts/bootstrap-reverse.sh"

# ─── 参数 ──────────────────────────────────────────────────────────────────────────

PACKAGE=""
PROCESS=""
REMOTE_HOST="127.0.0.1:27042"
SCRIPT_PATH=""
USB=false
SPAWN=false
PAUSE=false
LIST_DEVICES=false
LIST_PROCESSES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --package|-p) PACKAGE="$2"; shift 2 ;;
        --process) PROCESS="$2"; shift 2 ;;
        --remote|-H) REMOTE_HOST="$2"; shift 2 ;;
        --script|-l) SCRIPT_PATH="$2"; shift 2 ;;
        --usb|-U) USB=true; shift ;;
        --spawn|-f) SPAWN=true; shift ;;
        --pause) PAUSE=true; shift ;;
        --list-devices) LIST_DEVICES=true; shift ;;
        --list-processes) LIST_PROCESSES=true; shift ;;
        -*) echo "未知选项: $1"; exit 1 ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# ─── 工具检测 ──────────────────────────────────────────────────────────────────────

ensure_frida() {
    if command -v frida &>/dev/null; then
        return 0
    fi
    if [[ -f "$KALI_BOOTSTRAP" && -x "$KALI_BOOTSTRAP" ]]; then
        echo "INFO: frida 未找到，尝试安装..."
        bash "$KALI_BOOTSTRAP" frida --skip-refresh 2>/dev/null || true
    else
        echo "INFO: Kali bootstrap 不可用，请按下方提示手动安装。" >&2
    fi
    if ! command -v frida &>/dev/null; then
        echo "ERR: frida 不可用。安装: pip3 install frida-tools"
        exit 1
    fi
}

ensure_frida

# ─── 列出设备 ──────────────────────────────────────────────────────────────────────

if [[ "$LIST_DEVICES" == "true" ]]; then
    frida-ls-devices 2>/dev/null || python3 -c "
import frida
for d in frida.enumerate_devices():
    print(f'{d.id}\t{d.type}\t{d.name}')
"
    exit 0
fi

# ─── 列出进程 ──────────────────────────────────────────────────────────────────────

if [[ "$LIST_PROCESSES" == "true" ]]; then
    if [[ "$USB" == "true" ]]; then
        frida-ps -U
    else
        frida-ps -H "$REMOTE_HOST"
    fi
    exit 0
fi

# ─── 注入执行 ──────────────────────────────────────────────────────────────────────

TARGET="${PACKAGE:-$PROCESS}"
if [[ -z "$TARGET" ]]; then
    echo "用法: $0 --package <pkg> --script <js> [--usb] [--spawn]"
    echo "  或: $0 --list-devices"
    echo "  或: $0 --list-processes [--usb]"
    exit 1
fi

if [[ -z "$SCRIPT_PATH" || ! -f "$SCRIPT_PATH" ]]; then
    echo "ERR: Frida 脚本不存在: ${SCRIPT_PATH:-未指定}"
    exit 1
fi

FRIDA_ARGS=()

if [[ "$USB" == "true" ]]; then
    FRIDA_ARGS+=("-U")
else
    FRIDA_ARGS+=("-H" "$REMOTE_HOST")
fi

if [[ "$SPAWN" == "true" ]]; then
    FRIDA_ARGS+=("-f")
else
    FRIDA_ARGS+=("-n")
fi

FRIDA_ARGS+=("$TARGET")
FRIDA_ARGS+=("-l" "$SCRIPT_PATH")

if [[ "$PAUSE" != "true" ]]; then
    FRIDA_ARGS+=("--no-pause")
fi

echo "=== Frida 注入 ==="
echo "  目标: $TARGET"
echo "  脚本: $SCRIPT_PATH"
echo "  模式: $([ "$SPAWN" == "true" ] && echo "spawn" || echo "attach")"
echo "  连接: $([ "$USB" == "true" ] && echo "USB" || echo "$REMOTE_HOST")"
echo ""

frida "${FRIDA_ARGS[@]}"
