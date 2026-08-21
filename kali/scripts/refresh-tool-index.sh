#!/usr/bin/env bash
# refresh-tool-index.sh — Kali Linux 版工具索引刷新
# 等价于 Windows 版的 refresh-tool-index.ps1
# 输出: skills/tool-index.md + skills/tool-index.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/tool-discovery.sh"

OUTPUT_MD="${1:-${SKILL_ROOT}/tool-index.md}"
OUTPUT_JSON="${2:-${SKILL_ROOT}/tool-index.json}"

GENERATED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')

# ─── 生成 Markdown ────────────────────────────────────────────────────────────────

{
    echo "# 逆向工具索引"
    echo ""
    echo "- 扫描时间: $GENERATED_AT"
    echo "- 扫描平台: Kali Linux ($(uname -r))"
    echo "- 路由入口: \`SKILL.md\` → \`routing.md\` → 对应子 skill"
    echo "- 说明: 本表由 \`kali/scripts/refresh-tool-index.sh\` 自动生成。"
    echo "- 注意: 对于 jshookmcp 这类 MCP server，\`yes\` 只表示本机具备通过 node/npx 拉起它的条件，不表示它已经在 MCP 配置里注册并启用。"
    echo ""
    echo "| 工具 | 归属 skill | 作用 | 可用 | 路径 | 版本 | 来源 | 脚本引用 |"
    echo "|---|---|---|---|---|---|---|---|"

    for entry in "${TOOL_CATALOG[@]}"; do
        result=$(resolve_tool "$entry")
        IFS='|' read -r name skill purpose available resolved_path version source <<< "$result"

        # 获取脚本引用
        refs="${SCRIPT_REFS[$name]:-—}"
        refs_display="${refs//,/<br>}"

        path_display="${resolved_path:-—}"
        version_display="${version:-—}"

        echo "| $name | $skill | $purpose | $available | $path_display | $version_display | $source | $refs_display |"
    done
} > "$OUTPUT_MD"

# ─── 能力状态视图 ──────────────────────────────────────────────────────────────────

{
    echo ""
    echo "---"
    echo ""
    echo "## 能力状态视图 (Capability Status)"
    echo ""
    echo "| 能力 | 工具可用 | MCP 已注册 | 服务在线 | 可自动安装 | 安装方式 |"
    echo "|------|---------|-----------|---------|-----------|---------|"

    CAPABILITY_NAMES=("jadx" "apktool" "jeb-pro" "frida" "idalib-mcp" "jshookmcp" "reqable-mcp" "xquik-mcp" "anything-analyzer" "idapro" "r2" "adb" "agent-browser" "ghidra-mcp" "seclists" "proxycat" "burpsuite-mcp" "nmap" "sqlmap" "hashcat" "hydra" "gobuster" "ffuf" "msfconsole" "nuclei" "bkcrack")

    for cap_name in "${CAPABILITY_NAMES[@]}"; do
        # 检查工具是否可用
        tool_available="✗"
        case "$cap_name" in
            jeb-pro)
                if command -v jeb &>/dev/null || [[ -x "$HOME/tools/JEB/jeb" ]] || [[ -x "$HOME/JEB/jeb" ]] || [[ -x "/opt/jeb/jeb" ]]; then
                    tool_available="✓"
                fi
                ;;
            reqable-mcp|jshookmcp)
                if command -v npx &>/dev/null; then tool_available="✓"; fi
                ;;
            *)
                if command -v "$cap_name" &>/dev/null; then tool_available="✓"; fi
                ;;
        esac

        # 检查 MCP 注册状态
        mcp_registered="—"
        mcp_name="$cap_name"
        case "$cap_name" in
            jshookmcp) mcp_name="jshook" ;;
            xquik-mcp) mcp_name="xquik" ;;
        esac
        mcp_check=$(check_mcp_registered "$mcp_name")
        if [[ "$mcp_check" == "true" ]]; then
            mcp_registered="✓"
        fi

        # 检查服务在线状态
        service_online="—"
        case "$cap_name" in
            idapro)
                if test_tcp_port 13337 2>/dev/null; then service_online="✓"; fi
                ;;
            anything-analyzer)
                if test_tcp_port 23816 2>/dev/null; then service_online="✓"; fi
                ;;
            ghidra-mcp)
                if test_tcp_port 8765 2>/dev/null; then service_online="✓"; fi
                ;;
            burpsuite-mcp)
                if test_tcp_port 9876 2>/dev/null; then service_online="✓"; fi
                ;;
        esac

        # 获取安装方式
        can_auto="✓"
        bootstrap_kind="apt-package"
        case "$cap_name" in
            jadx|ghidra-mcp|seclists)
                bootstrap_kind="github-release"
                ;;
            frida|idalib-mcp|proxycat)
                bootstrap_kind="pip-package"
                ;;
            jshookmcp|reqable-mcp|agent-browser)
                bootstrap_kind="npm-mcp"
                ;;
            xquik-mcp)
                bootstrap_kind="remote-http-mcp"
                ;;
            jeb-pro)
                bootstrap_kind="manual"
                can_auto="✗"
                ;;
            anything-analyzer|idapro)
                bootstrap_kind="local-http-mcp"
                ;;
            burpsuite-mcp)
                bootstrap_kind="manual"
                can_auto="✗"
                ;;
        esac

        echo "| $cap_name | $tool_available | $mcp_registered | $service_online | $can_auto | $bootstrap_kind |"
    done

    echo ""
    echo "> ✓ = 是 | ✗ = 否 | — = 不适用或未检测"
    echo ""
} >> "$OUTPUT_MD"

# ─── 生成 JSON ─────────────────────────────────────────────────────────────────────

if command -v jq &>/dev/null; then
    # 使用 jq 生成结构化 JSON
    json_tools="[]"
    for entry in "${TOOL_CATALOG[@]}"; do
        result=$(resolve_tool "$entry")
        IFS='|' read -r name skill purpose available resolved_path version source <<< "$result"
        refs="${SCRIPT_REFS[$name]:-}"

        avail_bool="false"
        [[ "$available" == "yes" ]] && avail_bool="true"

        json_tools=$(echo "$json_tools" | jq \
            --arg name "$name" \
            --arg skill "$skill" \
            --arg purpose "$purpose" \
            --argjson available "$avail_bool" \
            --arg resolved_path "$resolved_path" \
            --arg version "$version" \
            --arg source "$source" \
            --arg script_refs "$refs" \
            '. + [{
                name: $name,
                skill: $skill,
                purpose: $purpose,
                available: $available,
                resolved_path: $resolved_path,
                version: $version,
                source: $source,
                script_refs: ($script_refs | split(","))
            }]')
    done

    jq -n \
        --arg generated_at "$GENERATED_AT" \
        --arg platform "kali-linux" \
        --argjson tools "$json_tools" \
        '{
            generated_at: $generated_at,
            platform: $platform,
            routing_entry: ["SKILL.md", "routing.md"],
            tools: $tools
        }' > "$OUTPUT_JSON"
else
    # 无 jq 时生成简易 JSON
    echo "{\"generated_at\": \"$GENERATED_AT\", \"platform\": \"kali-linux\", \"note\": \"install jq for full JSON output\"}" > "$OUTPUT_JSON"
fi

echo "✅ 工具索引已刷新"
echo "  markdown=$OUTPUT_MD"
echo "  json=$OUTPUT_JSON"
echo "  tools=${#TOOL_CATALOG[@]}"
