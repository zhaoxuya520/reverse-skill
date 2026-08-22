#!/usr/bin/env bash
# bootstrap-reverse.sh — Kali Linux 版自动安装/补齐工具
# 等价于 Windows 版的 bootstrap-reverse.ps1
#
# 用法:
#   bash bootstrap-reverse.sh <capability1> [capability2] ... [--start-services] [--skip-refresh]
#
# 示例:
#   bash bootstrap-reverse.sh jadx apktool frida
#   bash bootstrap-reverse.sh idapro --start-services
#   bash bootstrap-reverse.sh jshookmcp anything-analyzer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALI_MANIFEST="$SCRIPT_DIR/bootstrap-manifest.json"
source "$SCRIPT_DIR/lib/tool-discovery.sh"

# ─── 参数解析 ──────────────────────────────────────────────────────────────────────

CAPABILITIES=()
START_SERVICES=false
SKIP_REFRESH=false
MANUAL_REQUIRED=false
FAILED=false
LAST_CAPABILITY_MANUAL=false

for arg in "$@"; do
    case "$arg" in
        --start-services) START_SERVICES=true ;;
        --skip-refresh) SKIP_REFRESH=true ;;
        --list|-l)
            echo "jadx apktool jeb-pro frida frida-ps idalib-mcp jshookmcp reqable-mcp xquik-mcp anything-analyzer idapro r2 rabin2 adb agent-browser ghidra-mcp seclists proxycat burpsuite-mcp nmap pentestswarm bkcrack"
            echo "mcp-kali-server metasploitmcp hexstrike-ai adaptixc2 atomic-operator sstimap xsstrike wpprobe fluxion gef coercer evil-winrm-py netexec responder bloodhound certipy"
            exit 0
            ;;
        -*) echo "未知选项: $arg"; exit 1 ;;
        *) CAPABILITIES+=("$arg") ;;
    esac
done

if [[ ${#CAPABILITIES[@]} -eq 0 ]]; then
    echo "用法: $0 <capability1> [capability2] ... [--start-services] [--skip-refresh]"
    echo ""
    echo "可用能力:"
    echo ""
    echo "  [逆向分析]"
    echo "    jadx apktool jeb-pro frida frida-ps idalib-mcp r2 rabin2 adb gef"
    echo ""
    echo "  [渗透测试 - 经典工具]"
    echo "    nmap sqlmap hashcat hydra gobuster ffuf msfconsole nuclei"
    echo "    netexec responder crackmapexec bloodhound certipy wfuzz"
    echo "    aircrack-ng coercer evil-winrm-py"
    echo ""
    echo "  [渗透测试 - Kali 2026.1 新增]"
    echo "    adaptixc2 atomic-operator sstimap xsstrike wpprobe fluxion"
    echo ""
    echo "  [MCP 服务]"
    echo "    jshookmcp reqable-mcp xquik-mcp anything-analyzer idapro agent-browser"
    echo "    mcp-kali-server metasploitmcp hexstrike-ai pentestswarm"
    echo ""
    echo "  [CTF 压缩包]"
    echo "    bkcrack"
    echo ""
    echo "  [其他]"
    echo "    ghidra-mcp seclists proxycat burpsuite-mcp"
    echo ""
    echo "示例:"
    echo "  $0 mcp-kali-server metasploitmcp hexstrike-ai pentestswarm  # 全部渗透 MCP"
    echo "  $0 adaptixc2 sstimap xsstrike wpprobe          # 安装 2026.1 新工具"
    echo "  $0 pentestswarm --start-services               # 安装 Swarm AI"
    echo "  $0 idapro --start-services                     # 安装并启动 IDA MCP"
    exit 1
fi

# ─── 辅助函数 ──────────────────────────────────────────────────────────────────────

log_info() { echo -e "\033[36m[INFO]\033[0m $*"; }
log_ok() { echo -e "\033[32m[OK]\033[0m $*"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
log_err() { echo -e "\033[31m[ERR]\033[0m $*"; }

# 检查是否有 sudo 权限
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    log_warn "部分操作需要 sudo 权限"
    return 1
}

# apt 安装
install_apt_package() {
    local package="$1"
    log_info "apt install $package ..."
    if [[ $EUID -eq 0 ]]; then
        apt-get update -qq && apt-get install -y -qq "$package"
    else
        sudo apt-get update -qq && sudo apt-get install -y -qq "$package"
    fi
}

# pip 安装
install_pip_package() {
    local package="$1"
    local source="${2:-}"
    local target="${source:-$package}"
    log_info "pip3 install $target ..."
    pip3 install --upgrade "$target" --break-system-packages 2>/dev/null \
        || pip3 install --upgrade "$target"
}

# npm 全局安装
install_npm_global() {
    local package="$1"
    log_info "npm install -g $package ..."
    if [[ $EUID -eq 0 ]]; then
        npm install -g "$package"
    else
        sudo npm install -g "$package" 2>/dev/null || npm install -g "$package"
    fi
}

# Git clone at an immutable commit. Existing mismatched checkouts are rejected
# instead of being overwritten, so local operator changes are never discarded.
install_git_commit() {
    local repo="$1"
    local commit="$2"
    local install_dir="$3"

    if [[ -d "$install_dir/.git" ]]; then
        local current status
        if ! current=$(git -C "$install_dir" rev-parse HEAD 2>/dev/null); then
            log_err "无法解析现有 checkout HEAD: $install_dir"
            return 1
        fi
        if [[ "$current" != "$commit" ]]; then
            log_err "Existing checkout is not at pinned commit $commit: $install_dir"
            log_err "Move it aside explicitly, then retry; bootstrap will not overwrite local changes."
            return 1
        fi
        if ! status=$(git -C "$install_dir" status --porcelain --untracked-files=all); then
            log_err "无法检查 checkout 状态: $install_dir"
            return 1
        fi
        if [[ -n "$status" ]]; then
            log_err "现有 checkout 含本地修改，拒绝执行: $install_dir"
            return 1
        fi
        return 0
    fi
    if [[ -e "$install_dir" ]]; then
        log_err "Install path exists but is not a git checkout: $install_dir"
        return 1
    fi

    local parent stage resolved status
    parent=$(dirname "$install_dir")
    mkdir -p "$parent"
    stage=$(mktemp -d "$parent/.reverse-bootstrap-XXXXXX") || return 1
    if ! git init -q "$stage" ||
       ! git -C "$stage" remote add origin "$repo" ||
       ! git -C "$stage" fetch --depth 1 origin "$commit" ||
       ! git -C "$stage" checkout -q --detach FETCH_HEAD; then
        rm -rf "$stage"
        return 1
    fi
    if ! resolved=$(git -C "$stage" rev-parse HEAD); then
        rm -rf "$stage"
        return 1
    fi
    if [[ "$resolved" != "$commit" ]]; then
        log_err "Pinned checkout verification failed (expected $commit, got $resolved)"
        rm -rf "$stage"
        return 1
    fi
    if ! status=$(git -C "$stage" status --porcelain --untracked-files=all) || [[ -n "$status" ]]; then
        log_err "Staged checkout is not clean: $stage"
        rm -rf "$stage"
        return 1
    fi
    if ! mv -T "$stage" "$install_dir"; then
        rm -rf "$stage"
        return 1
    fi
}

# GitHub Release 下载并解压。
# Args: repo asset_regex install_dir [release_tag] [expected_sha256]
install_github_release() {
    local repo="$1"
    local asset_regex="$2"
    local install_dir="$3"
    local release_tag="${4:-}"
    local expected_sha256="${5:-}"

    if ! command -v jq &>/dev/null; then
        log_err "jq is required to select and verify GitHub release assets"
        return 1
    fi

    log_info "从 GitHub Release 下载: $repo ..."

    local api_url
    if [[ -n "$release_tag" ]]; then
        api_url="https://api.github.com/repos/${repo}/releases/tags/${release_tag}"
    else
        api_url="https://api.github.com/repos/${repo}/releases/latest"
    fi

    local release_json
    release_json=$(curl --fail --silent --show-error --location "$api_url")

    local asset
    asset=$(printf '%s' "$release_json" | jq -cer --arg regex "$asset_regex" '.assets[] | select(.name | test($regex)) | {name, browser_download_url, digest}' | head -n1)
    if [[ -z "$asset" || "$asset" == "null" ]]; then
        log_err "未找到匹配 $asset_regex 的 release asset (tag=${release_tag:-latest})"
        return 1
    fi

    local download_url filename api_digest
    download_url=$(printf '%s' "$asset" | jq -r '.browser_download_url')
    filename=$(printf '%s' "$asset" | jq -r '.name')
    api_digest=$(printf '%s' "$asset" | jq -r '.digest // empty')
    local tmp_file
    tmp_file=$(mktemp "/tmp/reverse-bootstrap-${filename}.XXXXXX")
    local tmp_extract=''

    cleanup_github_release() {
        rm -f "$tmp_file"
        if [[ -n "$tmp_extract" ]]; then rm -rf "$tmp_extract"; fi
    }

    log_info "下载: $download_url"
    if ! curl --fail --silent --show-error --location -o "$tmp_file" "$download_url"; then
        cleanup_github_release
        return 1
    fi

    local expected="${expected_sha256#sha256:}"
    expected="${expected,,}"
    if [[ -z "$expected" && -n "$api_digest" ]]; then
        expected="${api_digest#sha256:}"
        expected="${expected,,}"
    fi
    if [[ -z "$expected" ]]; then
        log_err "缺少固定 SHA-256 或 GitHub digest，拒绝安装未校验资产: $filename"
        cleanup_github_release
        return 1
    fi

    local actual
    actual=$(sha256sum "$tmp_file" | awk '{print tolower($1)}')
    if [[ "$actual" != "$expected" ]]; then
        log_err "SHA-256 不匹配: $filename (expected $expected, got $actual)"
        cleanup_github_release
        return 1
    fi
    log_ok "SHA-256 校验通过: $actual"

    # 创建安装目录
    mkdir -p "$install_dir"

    # 根据文件类型解压
    case "$filename" in
        *.tar.gz|*.tgz)
            tar -xzf "$tmp_file" -C "$install_dir" --strip-components=1 2>/dev/null \
                || tar -xzf "$tmp_file" -C "$install_dir"
            ;;
        *.zip)
            tmp_extract=$(mktemp -d /tmp/reverse-bootstrap-extract.XXXXXX)
            unzip -qo "$tmp_file" -d "$tmp_extract"
            # 如果只有一个顶层目录，strip 它
            local top_dirs
            top_dirs=$(find "$tmp_extract" -maxdepth 1 -mindepth 1 -type d)
            if [[ $(printf '%s\n' "$top_dirs" | wc -l) -eq 1 ]]; then
                cp -a "$top_dirs"/. "$install_dir/"
            else
                cp -a "$tmp_extract"/. "$install_dir/"
            fi
            ;;
        *.deb)
            if [[ $EUID -eq 0 ]]; then
                dpkg -i "$tmp_file" || apt-get install -f -y
            else
                sudo dpkg -i "$tmp_file" || sudo apt-get install -f -y
            fi
            ;;
        *)
            cp "$tmp_file" "$install_dir/"
            ;;
    esac

    cleanup_github_release

    # 把 bin 目录加入 PATH（当前 session）
    if [[ -d "$install_dir/bin" ]]; then
        export PATH="$install_dir/bin:$PATH"
    else
        export PATH="$install_dir:$PATH"
    fi

    log_ok "已安装到 $install_dir"
}

# 注册 MCP server 到 Claude 配置
register_mcp_server() {
    local server_name="$1"
    local config_json="$2"  # JSON 格式的 server 配置

    local config_path
    config_path=$(get_claude_mcp_config_path)
    local config_dir
    config_dir=$(dirname "$config_path")

    mkdir -p "$config_dir"

    if [[ ! -f "$config_path" ]]; then
        echo '{"mcpServers":{}}' > "$config_path"
    fi

    if command -v jq &>/dev/null; then
        local tmp_file="/tmp/mcp-config-$$.json"
        jq ".mcpServers.\"${server_name}\" = ${config_json}" "$config_path" > "$tmp_file"
        mv "$tmp_file" "$config_path"
        log_ok "MCP server '$server_name' 已注册到 $config_path"
    else
        log_warn "未安装 jq，无法自动注册 MCP server。请手动编辑 $config_path"
    fi
}

# 等待端口就绪
wait_for_port() {
    local port="$1"
    local timeout="${2:-90}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if test_tcp_port "$port" 2>/dev/null; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

# ─── 能力安装逻辑 ──────────────────────────────────────────────────────────────────

manifest_field() {
    local capability="$1"
    local field="$2"
    if [[ ! -f "$KALI_MANIFEST" ]] || ! command -v jq &>/dev/null; then
        return 1
    fi
    jq -er --arg name "$capability" --arg field "$field" \
        '.capabilities[] | select(.name == $name) | .[$field] // empty' "$KALI_MANIFEST"
}

manifest_dependency() {
    local name="$1"
    local field="$2"
    jq -er --arg name "$name" --arg field "$field" \
        '.bootstrapDependencies[$name][$field] // empty' "$KALI_MANIFEST"
}

install_manifest_release() {
    local capability="$1"
    local repo asset_regex install_dir release_tag asset_sha256
    repo=$(manifest_field "$capability" repo) || {
        log_err "manifest 中缺少 $capability.repo"
        return 1
    }
    asset_regex=$(manifest_field "$capability" assetRegex) || {
        log_err "manifest 中缺少 $capability.assetRegex"
        return 1
    }
    install_dir=$(manifest_field "$capability" installDir) || {
        log_err "manifest 中缺少 $capability.installDir"
        return 1
    }
    release_tag=$(manifest_field "$capability" releaseTag) || {
        log_err "manifest 中缺少 $capability.releaseTag；拒绝使用 latest"
        return 1
    }
    asset_sha256=$(manifest_field "$capability" assetSha256) || {
        log_err "manifest 中缺少 $capability.assetSha256；拒绝下载未固定资产"
        return 1
    }

    install_dir="${install_dir/\$HOME/$HOME}"
    install_github_release "$repo" "$asset_regex" "$install_dir" "$release_tag" "$asset_sha256"
}

ensure_capability() {
    local name="$1"

    # 先检查是否已可用
    if command -v "$name" &>/dev/null; then
        log_ok "$name 已可用: $(command -v "$name")"
        return 0
    fi

    log_info "开始安装: $name"

    case "$name" in
        # ─── apt 预装/可装的工具 ───
        nmap|sqlmap|hashcat|hydra|gobuster|ffuf|adb|bkcrack)
            install_apt_package "$name"
            ;;
        msfconsole)
            install_apt_package "metasploit-framework"
            ;;
        r2|rabin2|rasm2|radiff2|rahash2|rax2)
            if ! command -v r2 &>/dev/null; then
                install_apt_package "radare2"
            fi
            ;;
        apktool)
            install_apt_package "apktool"
            ;;
        seclists)
            install_apt_package "seclists"
            ;;
        # ─── Kali 2026.1 新增工具（全部 apt 直装） ───
        adaptixc2)
            install_apt_package "adaptixc2"
            ;;
        atomic-operator)
            install_apt_package "atomic-operator"
            ;;
        fluxion)
            install_apt_package "fluxion"
            ;;
        gef)
            install_apt_package "gef"
            log_info "GEF 已安装。启动 gdb 时自动加载 GEF 增强功能。"
            ;;
        sstimap)
            install_apt_package "sstimap"
            ;;
        xsstrike)
            install_apt_package "xsstrike"
            ;;
        wpprobe)
            install_apt_package "wpprobe"
            ;;
        evil-winrm-py)
            install_apt_package "evil-winrm-py"
            ;;
        coercer)
            install_apt_package "coercer"
            ;;
        netexec)
            install_apt_package "netexec"
            ;;
        responder)
            install_apt_package "responder"
            ;;
        crackmapexec)
            install_apt_package "crackmapexec"
            ;;
        bloodhound)
            install_apt_package "bloodhound"
            ;;
        certipy)
            install_apt_package "certipy-ad"
            ;;
        wfuzz)
            install_apt_package "wfuzz"
            ;;
        aircrack-ng)
            install_apt_package "aircrack-ng"
            ;;
        # ─── Kali 原生 MCP 工具（apt 安装 + MCP 注册） ───
        mcp-kali-server)
            install_apt_package "mcp-kali-server"
            register_mcp_server "kali-server" '{
                "command": "kali-server-mcp",
                "args": ["--port", "5000"]
            }'
            log_info "启动方式: kali-server-mcp --port 5000"
            log_info "然后用 mcp-server 连接 AI 客户端到 API server"
            ;;
        metasploitmcp)
            install_apt_package "metasploitmcp"
            register_mcp_server "metasploit-mcp" '{
                "command": "metasploitmcp",
                "args": ["--transport", "stdio"]
            }'
            log_info "MetasploitMCP 支持 stdio 和 HTTP 两种模式"
            log_info "  stdio: metasploitmcp --transport stdio"
            log_info "  HTTP:  metasploitmcp --transport http --port 8085"
            ;;
        hexstrike-ai)
            install_apt_package "hexstrike-ai"
            register_mcp_server "hexstrike" '{
                "command": "hexstrike-ai",
                "args": []
            }'
            log_info "HexStrike AI 已安装。150+ 安全工具通过 MCP 暴露给 AI agent。"
            ;;
        # ─── Pentest Swarm AI（群体智能渗透框架） ───
        pentestswarm)
            if command -v pentestswarm &>/dev/null; then
                log_ok "pentestswarm 已可用"
            elif command -v go &>/dev/null; then
                log_info "go install pentestswarm ..."
                go install github.com/Armur-Ai/Pentest-Swarm-AI/cmd/pentestswarm@v0.1.0
            elif command -v docker &>/dev/null; then
                log_info "拉取 pentestswarm Docker 镜像 ..."
                docker pull ghcr.io/armur-ai/pentestswarm:v0.1.0
                log_info "使用方式: docker run --rm ghcr.io/armur-ai/pentestswarm:v0.1.0 scan <target> --scope <scope>"
            else
                log_warn "需要 Go 1.24+ 或 Docker 来安装 pentestswarm"
                log_info "安装 Go: apt install golang-go"
                log_info "然后: go install github.com/Armur-Ai/Pentest-Swarm-AI/cmd/pentestswarm@v0.1.0"
                return 1
            fi
            register_mcp_server "pentestswarm" '{
                "command": "pentestswarm",
                "args": ["mcp", "serve"]
            }'
            log_info "Pentest Swarm AI 已配置"
            log_info "  MCP 模式: pentestswarm mcp serve"
            log_info "  扫描模式: pentestswarm scan <target> --scope <scope> --swarm"
            log_info "  需要设置: export PENTESTSWARM_ORCHESTRATOR_API_KEY=<your-claude-key>"
            ;;

        # ─── pip 安装 ───
        frida|frida-ps)
            install_pip_package "frida-tools==14.10.4"
            ;;
        idalib-mcp)
            install_pip_package "ida-pro-mcp" "git+https://github.com/mrexodia/ida-pro-mcp.git@f82e6e2517a161b77e738951c3071cd446480ba0"
            log_info "运行 ida-pro-mcp --install 完成 IDA 插件安装"
            ;;
        proxycat)
            local proxycat_dir="$HOME/tools/ProxyCat"
            install_git_commit \
                "https://github.com/honmashironeko/ProxyCat.git" \
                "2309b713e2e4f574df14c2ace7e8fa6c00eb6941" \
                "$proxycat_dir"
            pip3 install --upgrade -r "$proxycat_dir/requirements.txt" --break-system-packages 2>/dev/null \
                || pip3 install --upgrade -r "$proxycat_dir/requirements.txt"
            local proxycat_bin_dir="$HOME/.local/bin"
            local proxycat_wrapper="$proxycat_bin_dir/proxycat"
            mkdir -p "$proxycat_bin_dir"
            cat > "$proxycat_wrapper" <<EOF
#!/usr/bin/env bash
exec python3 "$proxycat_dir/ProxyCat.py" "\$@"
EOF
            chmod 0755 "$proxycat_wrapper"
            log_info "ProxyCat installed at pinned commit; command wrapper: $proxycat_wrapper"
            if [[ ":$PATH:" != *":$proxycat_bin_dir:"* ]]; then
                log_warn "Add $proxycat_bin_dir to PATH before using the proxycat command."
            fi
            ;;
        pwntools)
            install_pip_package "pwntools==4.15.0"
            ;;

        # ─── GitHub Release ───
        jadx)
            install_manifest_release "jadx"
            chmod +x "$HOME/tools/jadx/bin/jadx" 2>/dev/null || true
            ;;
        ghidra-mcp)
            if command -v ghidra &>/dev/null; then
                log_ok "ghidra 已通过 apt 安装"
            else
                install_apt_package "ghidra" 2>/dev/null \
                    || install_github_release "NationalSecurityAgency/ghidra" "^ghidra_.*_PUBLIC_.*\\.zip$" "$HOME/tools/ghidra"
            fi
            log_warn "GhidraMCP 插件需手动安装: https://github.com/LaurieWired/GhidraMCP/releases"
            ;;
        nuclei)
            if command -v go &>/dev/null; then
                log_info "go install nuclei ..."
                go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@v3.8.0
            else
                install_github_release "projectdiscovery/nuclei" "^nuclei_.*_linux_amd64\\.zip$" "$HOME/tools/nuclei" "v3.8.0"
            fi
            ;;

        # ─── npm/MCP ───
        jeb-pro)
            log_warn "MANUAL_INSTALL_REQUIRED: jeb-pro"
            log_warn "JEB Pro 是商业工具；请从 PNF Software 获取有效许可证后手动安装。社区 MCP 桥接必须先按 skill-supply-chain.md 审查。"
            LAST_CAPABILITY_MANUAL=true
            MANUAL_REQUIRED=true
            return 0
            ;;
        reqable-mcp)
            if ! command -v node &>/dev/null; then
                install_apt_package "nodejs"
            fi
            if ! command -v npm &>/dev/null; then
                install_apt_package "npm"
            fi
            register_mcp_server "reqable-mcp" '{
                "command": "npx",
                "args": ["-y", "reqable-mcp-server@1.0.1", "--scope", "minimal"]
            }'
            log_warn "Reqable MCP 需要单独安装 Reqable 桌面客户端并启用其本地 API。"
            ;;
        jshookmcp)
            if ! command -v node &>/dev/null; then
                install_apt_package "nodejs"
            fi
            if ! command -v npm &>/dev/null; then
                install_apt_package "npm"
            fi
            register_mcp_server "jshook" '{
                "command": "npx",
                "args": ["-y", "@jshookmcp/jshook@0.3.4"],
                "env": {"JSHOOK_BASE_PROFILE": "search"}
            }'
            ;;
        xquik-mcp)
            register_mcp_server "xquik" '{
                "url": "https://xquik.com/mcp"
            }'
            log_info "Xquik remote MCP 已登记。请从 MCP 客户端完成 OAuth。"
            ;;
        agent-browser)
            if ! command -v node &>/dev/null; then
                install_apt_package "nodejs"
            fi
            install_npm_global "agent-browser@0.31.1"
            npx playwright install chromium 2>/dev/null || true
            ;;

        # ─── 本地 HTTP MCP 服务 ───
        anything-analyzer)
            register_mcp_server "anything-analyzer" "{\"url\": \"http://localhost:23816/mcp\"}"
            if [[ "$START_SERVICES" == "true" ]]; then
                start_anything_analyzer
            fi
            ;;
        idapro)
            # 先确保 idalib-mcp 已安装
            ensure_capability "idalib-mcp"
            register_mcp_server "idapro" "{\"url\": \"http://127.0.0.1:13337/mcp\"}"
            if [[ "$START_SERVICES" == "true" ]]; then
                start_idapro_service
            fi
            ;;

        # ─── 手动安装 ───
        burpsuite-mcp)
            log_warn "MANUAL_INSTALL_REQUIRED: burpsuite-mcp"
            log_warn "Kali 预装 BurpSuite，在扩展市场搜索 MCP 插件安装"
            register_mcp_server "burpsuite" "{\"url\": \"http://localhost:9876/mcp\"}"
            ;;

        *)
            log_err "未知能力: $name"
            return 1
            ;;
    esac
}

# ─── 服务启动 ──────────────────────────────────────────────────────────────────────

start_anything_analyzer() {
    local repo_dir="$HOME/tools/anything-analyzer"
    local repo commit
    repo=$(manifest_field anything-analyzer repoUrl)
    commit=$(manifest_field anything-analyzer pinnedCommit)
    install_git_commit "$repo" "$commit" "$repo_dir" || return 1

    if test_tcp_port 23816 2>/dev/null; then
        log_ok "anything-analyzer 已在运行 (port 23816)"
        return 0
    fi

    local pnpm_package pnpm_version current_pnpm_version=''
    pnpm_package=$(manifest_dependency pnpm package) || return 1
    pnpm_version=$(manifest_dependency pnpm version) || return 1
    if command -v pnpm &>/dev/null; then
        current_pnpm_version=$(pnpm --version 2>/dev/null | head -n1 | tr -d '[:space:]')
    fi
    if [[ "$current_pnpm_version" != "$pnpm_version" ]]; then
        npm install -g "$pnpm_package" || return 1
    fi

    (cd "$repo_dir" && pnpm install --frozen-lockfile) || return 1
    install_git_commit "$repo" "$commit" "$repo_dir" || return 1
    (cd "$repo_dir" && nohup pnpm dev > /tmp/anything-analyzer.log 2>&1 &)

    log_info "等待 anything-analyzer 启动 (port 23816) ..."
    if wait_for_port 23816 120; then
        log_ok "anything-analyzer 已启动"
    else
        log_err "anything-analyzer 启动超时，查看日志: /tmp/anything-analyzer.log"
        return 1
    fi
}

start_idapro_service() {
    if test_tcp_port 13337 2>/dev/null; then
        log_ok "IDA Pro MCP 已在运行 (port 13337)"
        return 0
    fi

    local ida_start_script="$SCRIPT_DIR/ida-start.sh"
    if [[ -x "$ida_start_script" ]]; then
        bash "$ida_start_script"
    else
        log_warn "IDA 启动脚本不存在: $ida_start_script"
        log_warn "请手动启动 IDA Pro，插件会自动监听 13337 端口"
        return 1
    fi
}

# ─── 主流程 ────────────────────────────────────────────────────────────────────────

RESULTS=()

for cap in "${CAPABILITIES[@]}"; do
    LAST_CAPABILITY_MANUAL=false
    if ensure_capability "$cap"; then
        if [[ "$LAST_CAPABILITY_MANUAL" == "true" ]]; then
            RESULTS+=("{\"name\":\"$cap\",\"status\":\"manual-required\"}")
        else
            RESULTS+=("{\"name\":\"$cap\",\"status\":\"ready\"}")
        fi
    else
        RESULTS+=("{\"name\":\"$cap\",\"status\":\"failed\"}")
        FAILED=true
    fi
done

# 刷新工具索引
if [[ "$SKIP_REFRESH" != "true" ]]; then
    log_info "刷新工具索引 ..."
    bash "$SCRIPT_DIR/refresh-tool-index.sh" >/dev/null 2>&1 || true
fi

final_exit_code=0
if [[ "$FAILED" == "true" ]]; then
    final_exit_code=1
elif [[ "$MANUAL_REQUIRED" == "true" ]]; then
    final_exit_code=2
fi

# 输出结果
echo ""
echo "═══════════════════════════════════════════"
echo "  Bootstrap 完成"
echo "═══════════════════════════════════════════"
for r in "${RESULTS[@]}"; do
    name=$(echo "$r" | jq -r '.name' 2>/dev/null || echo "$r")
    status=$(echo "$r" | jq -r '.status' 2>/dev/null || echo "unknown")
    if [[ "$status" == "ready" ]]; then
        echo "  ✓ $name"
    elif [[ "$status" == "manual-required" ]]; then
        echo "  ! $name (manual install required)"
    else
        echo "  ✗ $name (failed)"
    fi
done
echo ""
exit "$final_exit_code"
