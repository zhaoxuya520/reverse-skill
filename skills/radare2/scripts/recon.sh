#!/usr/bin/env bash
# recon.sh — radare2 快速侦察（二进制基本信息、节区、导入导出、字符串）
# 等价于 Windows 版的 recon.ps1
#
# 用法:
#   bash recon.sh <target_file> [--strings-limit 40] [--imports-limit 80] [--analyze]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALI_BOOTSTRAP="$(cd "$SCRIPT_DIR/../../../kali/scripts" 2>/dev/null && pwd)/bootstrap-reverse.sh"

# ─── 参数 ──────────────────────────────────────────────────────────────────────────

TARGET=""
STRINGS_LIMIT=40
IMPORTS_LIMIT=80
RUN_ANALYSIS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strings-limit) STRINGS_LIMIT="$2"; shift 2 ;;
        --imports-limit) IMPORTS_LIMIT="$2"; shift 2 ;;
        --analyze) RUN_ANALYSIS=true; shift ;;
        -*) echo "未知选项: $1"; exit 1 ;;
        *) TARGET="$1"; shift ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "用法: $0 <target_file> [--strings-limit N] [--imports-limit N] [--analyze]"
    exit 1
fi

if [[ ! -f "$TARGET" ]]; then
    echo "ERR: 文件不存在: $TARGET"
    exit 1
fi

# ─── 工具检测 ──────────────────────────────────────────────────────────────────────

ensure_tool() {
    local name="$1"
    if command -v "$name" &>/dev/null; then
        return 0
    fi
    echo "INFO: $name 未找到，尝试安装..."
    if [[ -x "$KALI_BOOTSTRAP" ]]; then
        bash "$KALI_BOOTSTRAP" r2 --skip-refresh 2>/dev/null || true
    fi
    if ! command -v "$name" &>/dev/null; then
        echo "ERR: $name 不可用。安装: apt install radare2"
        exit 1
    fi
}

ensure_tool "rabin2"
[[ "$RUN_ANALYSIS" == "true" ]] && ensure_tool "r2"

# ─── 绝对路径 ──────────────────────────────────────────────────────────────────────

TARGET="$(realpath "$TARGET")"
echo "目标文件: $TARGET"

# ─── 侦察 ─────────────────────────────────────────────────────────────────────────

echo ""
echo "=== 基本信息 ==="
rabin2 -I -- "$TARGET"

echo ""
echo "=== 节区 ==="
rabin2 -S -- "$TARGET"

# `head` closes the pipe after N lines. With `set -o pipefail`, a large binary
# makes rabin2 die of SIGPIPE (exit 141) and aborts the whole recon before the
# exports/strings/analysis sections run. `sed` consumes the full stream but
# still limits output, and keeps genuine rabin2 failures visible.
echo ""
echo "=== 导入 ==="
rabin2 -i -- "$TARGET" | sed -n "1,${IMPORTS_LIMIT}p"

echo ""
echo "=== 导出 ==="
rabin2 -E -- "$TARGET"

echo ""
echo "=== 字符串 ==="
rabin2 -zz -- "$TARGET" | sed -n "1,${STRINGS_LIMIT}p"

if [[ "$RUN_ANALYSIS" == "true" ]]; then
    echo ""
    echo "=== 函数与入口分析 ==="
    r2 -A -q -c 's entry0;afl;iz;ii;q' -- "$TARGET"
fi
