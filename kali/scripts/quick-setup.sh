#!/usr/bin/env bash
# quick-setup.sh — Kali 2026.1 一键初始化
# 在全新 Kali 系统上运行此脚本，自动完成：
#   1. 系统更新
#   2. 安装 Kali 2026.1 新工具
#   3. 配置 Kali 原生 MCP
#   4. 安装非预装的逆向工具
#   5. 刷新工具索引
#   6. 输出配置报告
#
# 用法:
#   sudo bash kali/scripts/quick-setup.sh [--skip-update] [--minimal]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── 参数 ──────────────────────────────────────────────────────────────────────────

SKIP_UPDATE=false
MINIMAL=false

for arg in "$@"; do
    case "$arg" in
        --skip-update) SKIP_UPDATE=true ;;
        --minimal) MINIMAL=true ;;
    esac
done

# ─── 颜色 ──────────────────────────────────────────────────────────────────────────

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

banner() { echo -e "\n${BOLD}${CYAN}═══ $* ═══${RESET}\n"; }
ok() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
info() { echo -e "${CYAN}[i]${RESET} $*"; }

# ─── 检查权限 ──────────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 权限运行: sudo bash $0"
    exit 1
fi

# ─── 检查 Kali 版本 ────────────────────────────────────────────────────────────────

banner "检查系统版本"

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    info "系统: $PRETTY_NAME"
    info "版本: ${VERSION:-unknown}"
    info "内核: $(uname -r)"
else
    warn "无法检测系统版本，继续执行..."
fi

# ─── 系统更新 ──────────────────────────────────────────────────────────────────────

if [[ "$SKIP_UPDATE" != "true" ]]; then
    banner "系统更新"
    apt-get update -qq
    apt-get upgrade -y -qq
    ok "系统已更新"
else
    info "跳过系统更新 (--skip-update)"
fi

# ─── 安装 Kali 2026.1 新工具 ──────────────────────────────────────────────────────

banner "安装 Kali 2026.1 新工具"

NEW_TOOLS_2026_1=(
    "adaptixc2"
    "atomic-operator"
    "fluxion"
    "gef"
    "metasploitmcp"
    "sstimap"
    "wpprobe"
    "xsstrike"
)

NEW_TOOLS_2025_4=(
    "evil-winrm-py"
    "hexstrike-ai"
)

for tool in "${NEW_TOOLS_2026_1[@]}" "${NEW_TOOLS_2025_4[@]}"; do
    if dpkg -l "$tool" &>/dev/null 2>&1; then
        ok "$tool 已安装"
    else
        info "安装 $tool ..."
        apt-get install -y -qq "$tool" 2>/dev/null && ok "$tool 安装成功" || warn "$tool 安装失败（可能尚未在你的源中）"
    fi
done

# ─── 安装 Kali 原生 MCP ──────────────────────────────────────────────────────────

banner "配置 Kali 原生 MCP"

MCP_TOOLS=("mcp-kali-server" "metasploitmcp" "hexstrike-ai")

for tool in "${MCP_TOOLS[@]}"; do
    if dpkg -l "$tool" &>/dev/null 2>&1; then
        ok "$tool 已安装"
    else
        info "安装 $tool ..."
        apt-get install -y -qq "$tool" 2>/dev/null && ok "$tool 安装成功" || warn "$tool 安装失败"
    fi
done

# ─── 安装 AD/内网渗透工具 ─────────────────────────────────────────────────────────

if [[ "$MINIMAL" != "true" ]]; then
    banner "安装 AD/内网渗透工具"

    AD_TOOLS=("coercer" "netexec" "responder" "bloodhound" "certipy-ad")

    for tool in "${AD_TOOLS[@]}"; do
        if dpkg -l "$tool" &>/dev/null 2>&1; then
            ok "$tool 已安装"
        else
            info "安装 $tool ..."
            apt-get install -y -qq "$tool" 2>/dev/null && ok "$tool 安装成功" || warn "$tool 安装失败"
        fi
    done
fi

# ─── 安装非预装逆向工具 ───────────────────────────────────────────────────────────

banner "安装逆向分析工具"

# jadx（Kali 不预装，从 GitHub 下载）
if ! command -v jadx &>/dev/null; then
    info "安装 jadx（从 GitHub Release）..."
    bash "$SCRIPT_DIR/bootstrap-reverse.sh" jadx --skip-refresh 2>/dev/null && ok "jadx 安装成功" || warn "jadx 安装失败"
else
    ok "jadx 已可用"
fi

# Node.js（部分 MCP 需要）
if ! command -v node &>/dev/null; then
    info "安装 Node.js ..."
    apt-get install -y -qq nodejs npm && ok "Node.js 安装成功" || warn "Node.js 安装失败"
else
    ok "Node.js 已可用: $(node -v)"
fi

# frida-tools
if ! command -v frida &>/dev/null; then
    info "安装 frida-tools ..."
    pip3 install --break-system-packages frida-tools 2>/dev/null && ok "frida-tools 安装成功" || warn "frida-tools 安装失败"
else
    ok "frida 已可用"
fi

# ─── 配置 MCP 客户端 ──────────────────────────────────────────────────────────────

banner "配置 MCP 客户端"

# 检测实际用户（sudo 下 $HOME 可能是 /root）
REAL_USER="${SUDO_USER:-root}"
REAL_HOME=$(eval echo "~$REAL_USER")

MCP_CONFIG_DIR="$REAL_HOME/.claude"
MCP_CONFIG="$MCP_CONFIG_DIR/mcp.json"

if command -v jq &>/dev/null; then
    mkdir -p "$MCP_CONFIG_DIR"

    if [[ ! -f "$MCP_CONFIG" ]]; then
        echo '{"mcpServers":{}}' > "$MCP_CONFIG"
    fi

    # 注册 kali-server
    jq '.mcpServers["kali-server"] = {"command": "kali-server-mcp", "args": ["--port", "5000"]}' "$MCP_CONFIG" > /tmp/mcp-tmp.json && mv /tmp/mcp-tmp.json "$MCP_CONFIG"

    # 注册 metasploit-mcp
    jq '.mcpServers["metasploit-mcp"] = {"command": "metasploitmcp", "args": ["--transport", "stdio"]}' "$MCP_CONFIG" > /tmp/mcp-tmp.json && mv /tmp/mcp-tmp.json "$MCP_CONFIG"

    # 注册 hexstrike
    jq '.mcpServers["hexstrike"] = {"command": "hexstrike-ai", "args": []}' "$MCP_CONFIG" > /tmp/mcp-tmp.json && mv /tmp/mcp-tmp.json "$MCP_CONFIG"

    # 注册 jshook
    jq '.mcpServers["jshook"] = {"command": "npx", "args": ["-y", "@jshookmcp/jshook@0.3.4"], "env": {"JSHOOK_BASE_PROFILE": "search"}}' "$MCP_CONFIG" > /tmp/mcp-tmp.json && mv /tmp/mcp-tmp.json "$MCP_CONFIG"

    chown "$REAL_USER:$REAL_USER" "$MCP_CONFIG" "$MCP_CONFIG_DIR"
    ok "MCP 配置已写入: $MCP_CONFIG"
else
    warn "未安装 jq，无法自动配置 MCP。请手动复制 kali/mcp-kali-example.json"
    info "安装 jq: apt install jq"
fi

# ─── 刷新工具索引 ──────────────────────────────────────────────────────────────────

banner "刷新工具索引"

chmod +x "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/lib/*.sh
sudo -u "$REAL_USER" bash "$SCRIPT_DIR/refresh-tool-index.sh" 2>/dev/null || bash "$SCRIPT_DIR/refresh-tool-index.sh"
ok "工具索引已刷新"

# ─── 输出报告 ──────────────────────────────────────────────────────────────────────

banner "配置完成"

echo -e "${BOLD}✅ Kali 2026.1 逆向技能路由包已配置完成${RESET}"
echo ""
echo "  安装路径: $(cd "$SCRIPT_DIR/../.." && pwd)"
echo "  MCP 配置: $MCP_CONFIG"
echo "  工具索引: $(cd "$SCRIPT_DIR/../.." && pwd)/skills/tool-index.md"
echo ""
echo "  Kali 原生 MCP:"
command -v kali-server-mcp &>/dev/null && echo "    ✓ mcp-kali-server" || echo "    ✗ mcp-kali-server"
command -v metasploitmcp &>/dev/null && echo "    ✓ metasploitmcp" || echo "    ✗ metasploitmcp"
command -v hexstrike-ai &>/dev/null && echo "    ✓ hexstrike-ai" || echo "    ✗ hexstrike-ai"
echo ""
echo "  2026.1 新工具:"
for tool in "${NEW_TOOLS_2026_1[@]}"; do
    if dpkg -l "$tool" &>/dev/null 2>&1; then
        echo "    ✓ $tool"
    else
        echo "    ✗ $tool"
    fi
done
echo ""
echo "  下一步:"
echo "    1. 告诉你的 AI 客户端读取 kali/RULES-kali.md"
echo "    2. 或者直接问 AI：'读一下 kali/RULES-kali.md 并执行配置'"
echo "    3. 之后遇到安全/逆向任务会自动路由"
echo ""
