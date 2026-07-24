#!/usr/bin/env bash
# tool-discovery.sh — Kali Linux 版工具发现库
# 等价于 Windows 版的 ToolDiscovery.ps1

set -euo pipefail

# ─── 路径推导 ───────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALI_SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KALI_DIR="$(cd "$KALI_SCRIPTS_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$KALI_DIR/.." && pwd)"
SKILL_ROOT="$PROJECT_ROOT/skills"

# ─── 工具目录定义 ─────────────────────────────────────────────────────────────────

# 每个工具的定义格式: name|skill|purpose|version_args|fallback_commands
# fallback_commands 用逗号分隔
declare -a TOOL_CATALOG=(
    "jadx|apk-reverse|Java 反编译|--version|jadx,${HOME}/tools/jadx/bin/jadx,/opt/jadx/bin/jadx"
    "apktool|apk-reverse|APK 解包与重建|--version|apktool,${HOME}/tools/apktool/apktool,/usr/local/bin/apktool"
    "adb|apk-reverse|设备连接与 logcat|version|adb,${HOME}/Android/Sdk/platform-tools/adb"
    "java|apk-reverse|运行 jar 与 Java 工具链|-version|java"
    "apksigner|apk-reverse|APK 签名|--version|apksigner,${HOME}/Android/Sdk/build-tools/*/apksigner"
    "zipalign|apk-reverse|APK 对齐||zipalign,${HOME}/Android/Sdk/build-tools/*/zipalign"
    "frida|apk-reverse|Frida 动态注入|--version|frida"
    "frida-ps|apk-reverse|Frida 进程枚举|--version|frida-ps"
    "r2|radare2|radare2 主分析器|-v|r2,radare2,${HOME}/tools/radare2/bin/r2,/usr/bin/r2"
    "rabin2|radare2|二进制侦察|-v|rabin2,${HOME}/tools/radare2/bin/rabin2,/usr/bin/rabin2"
    "rasm2|radare2|汇编/反汇编|-v|rasm2,${HOME}/tools/radare2/bin/rasm2"
    "radiff2|radare2|二进制差分|-v|radiff2,${HOME}/tools/radare2/bin/radiff2"
    "rahash2|radare2|哈希与校验|-v|rahash2,${HOME}/tools/radare2/bin/rahash2"
    "rax2|radare2|进制与位运算转换|-v|rax2,${HOME}/tools/radare2/bin/rax2"
    "python|reverse-engineering|辅助脚本执行|--version|python3,python"
    "pip|reverse-engineering|Python 包管理|--version|pip3,pip"
    "node|js-reverse|运行 Node 侧 JS 复现与 MCP 客户端|--version|node"
    "npx|js-reverse|运行临时 npm 包与 MCP 入口|--version|npx"
    "jshookmcp|js-reverse|JS/CDP Hook MCP（须在客户端注册）||__jshookmcp_special__"
    "agent-browser|browser-automation|浏览器自动化（Playwright）|--version|agent-browser"
    "analyzeHeadless|reverse-engineering|Ghidra 无头分析||analyzeHeadless,${HOME}/tools/ghidra/support/analyzeHeadless,/opt/ghidra/support/analyzeHeadless,/usr/share/ghidra/support/analyzeHeadless"
    "playwright|browser-automation|Playwright 浏览器引擎|--version|playwright,npx playwright"
    "proxycat|pentest-tools|代理池管理与轮换|--version|proxycat"
    "nmap|pentest-tools|端口扫描与服务识别|--version|nmap"
    "sqlmap|pentest-tools|SQL 注入自动化|--version|sqlmap"
    "hashcat|pentest-tools|密码破解|--version|hashcat"
    "hydra|pentest-tools|在线密码爆破|-h|hydra"
    "gobuster|pentest-tools|目录爆破|version|gobuster"
    "ffuf|pentest-tools|模糊测试|-V|ffuf"
    "msfconsole|pentest-tools|Metasploit 框架|--version|msfconsole"
    "nikto|pentest-tools|Web 漏洞扫描|-Version|nikto"
    "binwalk|reverse-engineering|固件分析与提取|--help|binwalk"
    "gdb|reverse-engineering|调试器|--version|gdb"
    "objdump|reverse-engineering|反汇编|--version|objdump"
    "strings|reverse-engineering|字符串提取|--version|strings"
    "file|reverse-engineering|文件类型识别|--version|file"
    "nuclei|pentest-tools|漏洞扫描|-version|nuclei"
    # ─── Kali 2026.1 新增工具 ───
    "metasploitmcp|pentest-tools|Metasploit MCP Server|-h|metasploitmcp"
    "mcp-kali-server|pentest-tools|Kali 官方 MCP Server（终端桥接）|-h|kali-server-mcp,mcp-server"
    "hexstrike-ai|pentest-tools|AI MCP 安全自动化平台（150+ 工具）||hexstrike-ai"
    "adaptixc2|pentest-tools|后渗透与对抗模拟框架||AdaptixServer"
    "atomic-operator|pentest-tools|Atomic Red Team 测试执行|--help|atomic-operator"
    "sstimap|pentest-tools|SSTI 自动检测与利用|-h|sstimap"
    "xsstrike|pentest-tools|高级 XSS 扫描器|-h|xsstrike"
    "wpprobe|pentest-tools|WordPress 插件枚举|--help|wpprobe"
    "fluxion|pentest-tools|WiFi 安全审计与社工||fluxion"
    "gef|reverse-engineering|GDB Enhanced Features（现代化调试）||gdb"
    "evil-winrm-py|pentest-tools|Python WinRM 远程执行|-h|evil-winrm-py"
    "coercer|pentest-tools|Windows 认证强制（AD 攻击）|-h|coercer"
    "pentestswarm|pentest-tools|群体智能自主渗透框架（Swarm AI）|--version|pentestswarm"
    # ─── Kali 经典预装但之前未列入的工具 ───
    "netexec|pentest-tools|网络服务枚举与利用（CrackMapExec 继任）|--help|nxc,netexec"
    "responder|pentest-tools|LLMNR/NBT-NS/MDNS 投毒|-h|responder"
    "crackmapexec|pentest-tools|网络渗透瑞士军刀|--help|crackmapexec,cme"
    "bloodhound|pentest-tools|AD 攻击路径可视化||bloodhound"
    "certipy|pentest-tools|AD 证书服务攻击|--version|certipy"
    "wfuzz|pentest-tools|Web 模糊测试|--help|wfuzz"
    "john|pentest-tools|密码破解||john"
    "aircrack-ng|pentest-tools|WiFi 破解套件|--help|aircrack-ng"
    "wireshark|pentest-tools|网络协议分析|--version|wireshark,tshark"
    "burpsuite|pentest-tools|Web 代理与漏洞扫描||burpsuite"
)

# 脚本引用映射
declare -A SCRIPT_REFS=(
    ["jadx"]="apk-reverse/scripts/decode.sh"
    ["apktool"]="apk-reverse/scripts/decode.sh,apk-reverse/scripts/rebuild-sign-install.sh"
    ["adb"]="apk-reverse/scripts/rebuild-sign-install.sh"
    ["java"]="apk-reverse/scripts/decode.sh"
    ["apksigner"]="apk-reverse/scripts/rebuild-sign-install.sh"
    ["zipalign"]="apk-reverse/scripts/rebuild-sign-install.sh"
    ["frida"]="apk-reverse/scripts/frida-run.sh"
    ["frida-ps"]="apk-reverse/scripts/frida-run.sh"
    ["r2"]="radare2/scripts/recon.sh"
    ["rabin2"]="radare2/scripts/recon.sh"
    ["rasm2"]="radare2/SKILL.md"
    ["radiff2"]="radare2/SKILL.md"
    ["rahash2"]="radare2/SKILL.md"
    ["rax2"]="radare2/SKILL.md"
    ["python"]="apk-reverse/scripts/frida-run.sh"
    ["node"]="js-reverse/SKILL.md"
    ["npx"]="js-reverse/SKILL.md"
    ["jshookmcp"]="js-reverse/SKILL.md"
    ["agent-browser"]="browser-automation/SKILL.md"
    ["playwright"]="browser-automation/SKILL.md"
    ["nmap"]="pentest-tools/SKILL.md"
    ["proxycat"]="pentest-tools/SKILL.md"
    ["metasploitmcp"]="pentest-tools/SKILL.md"
    ["mcp-kali-server"]="pentest-tools/SKILL.md"
    ["hexstrike-ai"]="pentest-tools/SKILL.md"
    ["adaptixc2"]="pentest-tools/SKILL.md"
    ["sstimap"]="pentest-tools/SKILL.md"
    ["xsstrike"]="pentest-tools/SKILL.md"
    ["wpprobe"]="pentest-tools/SKILL.md"
    ["coercer"]="pentest-tools/SKILL.md"
    ["pentestswarm"]="pentest-tools/SKILL.md"
    ["evil-winrm-py"]="pentest-tools/SKILL.md"
    ["gef"]="reverse-engineering/SKILL.md"
    ["netexec"]="pentest-tools/SKILL.md"
    ["responder"]="pentest-tools/SKILL.md"
)

# ─── 工具发现函数 ─────────────────────────────────────────────────────────────────

# 查找命令的完整路径
find_command() {
    local name="$1"
    command -v "$name" 2>/dev/null || true
}

# 检测端口是否在监听
test_tcp_port() {
    local port="$1"
    local host="${2:-127.0.0.1}"
    (echo >/dev/tcp/"$host"/"$port") 2>/dev/null && return 0
    # fallback to nc
    nc -z "$host" "$port" 2>/dev/null && return 0
    return 1
}

# 获取工具版本（stdout: version text; exit code preserved in VERSION_EC）
get_tool_version() {
    local cmd="$1"
    local version_args="$2"
    VERSION_EC=0
    VERSION_OUT=""

    if [[ -z "$version_args" ]]; then
        echo ""
        return 0
    fi

    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/rs-kver.XXXXXX")"
    set +e
    # shellcheck disable=SC2086
    "$cmd" $version_args >"$tmp" 2>&1
    VERSION_EC=$?
    set -e
    VERSION_OUT="$(head -n1 "$tmp" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    rm -f "$tmp"
    echo "$VERSION_OUT"
}

version_is_broken() {
    local text="${1:-}"
    local ec="${2:-0}"
    if [[ "$ec" != "0" && -z "$text" ]]; then
        return 0
    fi
    if [[ -z "$text" ]]; then
        return 1
    fi
    printf '%s' "$text" | grep -Eiq       'unable to locate|no java runtime|not found|command not found|no such file|is not recognized|could not find|cannot find|not installed|Unable to locate a Java Runtime'       && return 0
    return 1
}


# MCP registration (best-effort)
mcp_server_registered() {
    local needle="$1"
    local cfg
    for cfg in "${CLAUDE_MCP_CONFIG:-}" "${HOME}/.claude/mcp.json" "${HOME}/.config/claude/mcp.json"; do
        [[ -n "$cfg" && -f "$cfg" ]] || continue
        if grep -Eiq "$needle|@jshookmcp/jshook" "$cfg" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

# 解析工具定义并检测可用性
# 返回: name|skill|purpose|available|resolved_path|version|source
resolve_tool() {
    local entry="$1"
    IFS='|' read -r name skill purpose version_args fallbacks <<< "$entry"

    # jshookmcp honesty: registration required
    if [[ "$name" == "jshookmcp" ]]; then
        local npx_path
        npx_path=$(find_command npx)
        if mcp_server_registered "jshook"; then
            echo "${name}|${skill}|${purpose}|yes|${npx_path:-mcp-config}|MCP registered (jshook)|mcp-registered"
        elif [[ -n "$npx_path" ]]; then
            echo "${name}|${skill}|${purpose}|no|${npx_path}|npx present; MCP NOT registered|npx-only"
        else
            echo "${name}|${skill}|${purpose}|no|||missing"
        fi
        return
    fi

    IFS=',' read -ra candidates <<< "$fallbacks"

    for candidate in "${candidates[@]}"; do
        # 展开 glob（如 build-tools/*/apksigner）
        local expanded
        expanded=$(compgen -G "$candidate" 2>/dev/null | head -n1) || expanded=""

        if [[ -n "$expanded" && -x "$expanded" ]]; then
            local ver
            ver=$(get_tool_version "$expanded" "$version_args")
            if [[ -n "$version_args" ]] && version_is_broken "$ver" "$VERSION_EC"; then
                echo "${name}|${skill}|${purpose}|no|${expanded}|${ver}|path-broken"
                return
            fi
            echo "${name}|${skill}|${purpose}|yes|${expanded}|${ver}|path"
            return
        fi

        # 尝试作为命令名查找
        local cmd_path
        cmd_path=$(find_command "$candidate")
        if [[ -n "$cmd_path" ]]; then
            local ver
            ver=$(get_tool_version "$cmd_path" "$version_args")
            if [[ -n "$version_args" ]] && version_is_broken "$ver" "$VERSION_EC"; then
                echo "${name}|${skill}|${purpose}|no|${cmd_path}|${ver}|command-broken"
                return
            fi
            echo "${name}|${skill}|${purpose}|yes|${cmd_path}|${ver}|command"
            return
        fi
    done

    # 未找到
    echo "${name}|${skill}|${purpose}|no|||missing"
}

# 获取 MCP 配置路径（Claude Code）
get_claude_mcp_config_path() {
    echo "${HOME}/.claude/mcp.json"
}

# 检查 MCP server 是否已注册
check_mcp_registered() {
    local server_name="$1"
    local config_path
    config_path=$(get_claude_mcp_config_path)

    if [[ ! -f "$config_path" ]]; then
        echo "false"
        return
    fi

    if command -v jq &>/dev/null; then
        local result
        result=$(jq -r ".mcpServers.\"${server_name}\" // empty" "$config_path" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "true"
        else
            echo "false"
        fi
    else
        # fallback: grep
        if grep -q "\"${server_name}\"" "$config_path" 2>/dev/null; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# 获取 bootstrap manifest 路径
get_bootstrap_manifest_path() {
    echo "${KALI_SCRIPTS_DIR}/bootstrap-manifest.json"
}

# 从 manifest 获取能力定义（需要 jq）
get_capability_definition() {
    local name="$1"
    local manifest
    manifest=$(get_bootstrap_manifest_path)

    if [[ ! -f "$manifest" ]]; then
        echo ""
        return
    fi

    if command -v jq &>/dev/null; then
        jq -r ".capabilities[] | select(.name == \"${name}\")" "$manifest" 2>/dev/null
    else
        echo ""
    fi
}
