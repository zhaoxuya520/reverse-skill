#!/usr/bin/env bash
# bootstrap-reverse.sh — generic Linux/macOS bootstrapper
#
# Parity target: skills/scripts/bootstrap-reverse.ps1
# Supports the same capability names and the same high-level modes:
#   - dependency expansion
#   - package / release / pipx / npm installation
#   - MCP registration hints / config writing
#   - optional service start with --start-services
#   - refresh tool index unless --skip-refresh
#
# Usage:
#   bash skills/scripts/bootstrap-reverse.sh <capability1> [capability2] ... [--start-services] [--skip-refresh]
#   bash skills/scripts/bootstrap-reverse.sh --list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_ROOT/.." && pwd)"
TOOLS_ROOT="${REVERSE_SKILL_TOOLS_DIR:-$HOME/tools}"
if [[ "$TOOLS_ROOT" != /* ]]; then
  TOOLS_ROOT="$PWD/$TOOLS_ROOT"
fi
if [[ -z "$TOOLS_ROOT" || "$TOOLS_ROOT" == "/" || "$TOOLS_ROOT" == "$HOME" ]]; then
  echo "Unsafe REVERSE_SKILL_TOOLS_DIR: $TOOLS_ROOT" >&2
  exit 2
fi
MCP_CONFIG_PATH="${CLAUDE_MCP_CONFIG:-$HOME/.claude/mcp.json}"

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_S" in
  Darwin) PLATFORM="macos" ;;
  Linux) PLATFORM="linux" ;;
  *) PLATFORM="unknown" ;;
esac

START_SERVICES=false
SKIP_REFRESH=false
LIST_ONLY=false
CAPABILITIES=()

for arg in "$@"; do
  case "$arg" in
    --start-services) START_SERVICES=true ;;
    --skip-refresh) SKIP_REFRESH=true ;;
    --list|-l) LIST_ONLY=true ;;
    --help|-h) CAPABILITIES+=("__help__") ;;
    -*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) CAPABILITIES+=("$arg") ;;
  esac
done

log_info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
log_ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
log_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
log_err() { printf '\033[31m[ERR]\033[0m %s\n' "$*"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }
cmd_path() { command -v "$1" 2>/dev/null || true; }

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

ensure_dir() { mkdir -p "$1"; }

safe_remove_install_dir() {
  local target="$1"
  local tmp_target="${2:-}"
  if [[ -z "$target" || "$target" == "/" || "$target" == "$HOME" || "$target" == "$TOOLS_ROOT" ]]; then
    log_err "Refusing to remove unsafe install path: $target"
    return 1
  fi
  case "$target" in
    "$TOOLS_ROOT"/*) ;;
    *) log_err "Refusing to remove path outside tools root: $target"; return 1 ;;
  esac
  rm -rf "$target"
  if [[ -n "$tmp_target" ]]; then
    case "$tmp_target" in
      /tmp/reverse-bootstrap-*|"$TOOLS_ROOT"/*.tmp) rm -rf "$tmp_target" ;;
      *) log_err "Refusing to remove unsafe tmp path: $tmp_target"; return 1 ;;
    esac
  fi
}

make_temp_file() {
  local suffix="${1:-download}"
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/reverse-bootstrap-XXXXXX)"
  printf '%s/%s
' "$tmp_dir" "$suffix"
}

sudo_cmd() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  elif has_cmd sudo; then
    sudo "$@"
  else
    log_err "sudo is required for: $*"
    return 1
  fi
}

is_kali() {
  [[ -f /etc/os-release ]] && grep -qi '^ID=.*kali' /etc/os-release
}

platform_doc() {
  case "$PLATFORM" in
    macos) echo "docs/platforms/macos.md" ;;
    linux)
      if is_kali; then echo "kali/README-kali.md"; else echo "docs/platforms/linux.md"; fi
      ;;
    *) echo "PLATFORMS.md" ;;
  esac
}

print_usage() {
  cat <<'EOF'
Usage:
  bash skills/scripts/bootstrap-reverse.sh <capability1> [capability2] ... [--start-services] [--skip-refresh]
  bash skills/scripts/bootstrap-reverse.sh --list

Capabilities (parity with bootstrap-reverse.ps1):
  jadx apktool frida frida-ps idalib-mcp jshookmcp anything-analyzer idapro
  r2 rabin2 adb agent-browser ghidra-mcp seclists proxycat burpsuite-mcp
  nmap pentestswarm binwalk yara pwntools

Examples:
  bash skills/scripts/bootstrap-reverse.sh jadx apktool frida
  bash skills/scripts/bootstrap-reverse.sh jshookmcp anything-analyzer
  bash skills/scripts/bootstrap-reverse.sh idapro --start-services
  bash skills/scripts/bootstrap-reverse.sh burpsuite-mcp

Notes:
  - This script supports Linux and macOS.
  - It writes MCP config to ~/.claude/mcp.json by default.
  - Override with CLAUDE_MCP_CONFIG=/path/to/mcp.json.
  - Override install root with REVERSE_SKILL_TOOLS_DIR=~/tools.
EOF
}

ALL_CAPABILITIES=(
  jadx apktool frida frida-ps idalib-mcp jshookmcp anything-analyzer idapro
  r2 rabin2 adb agent-browser ghidra-mcp seclists proxycat burpsuite-mcp
  nmap pentestswarm binwalk yara pwntools
)

if $LIST_ONLY; then
  printf '%s\n' "${ALL_CAPABILITIES[@]}"
  exit 0
fi

if [[ ${#CAPABILITIES[@]} -eq 0 || "${CAPABILITIES[0]}" == "__help__" ]]; then
  print_usage
  exit 0
fi

install_apt() {
  local package="$1"
  log_info "apt install $package"
  sudo_cmd apt-get update -qq
  sudo_cmd apt-get install -y "$package"
}

install_brew() {
  local package="$1"
  if ! has_cmd brew; then
    log_err "Homebrew is required. Install it first: https://brew.sh/"
    return 1
  fi
  log_info "brew install $package"
  brew install "$package"
}

install_brew_cask() {
  local package="$1"
  if ! has_cmd brew; then
    log_err "Homebrew is required. Install it first: https://brew.sh/"
    return 1
  fi
  log_info "brew install --cask $package"
  brew install --cask "$package"
}

ensure_python_runtime() {
  if ! has_cmd python3; then
    case "$PLATFORM" in
      macos) install_brew python ;;
      linux) install_apt python3 ;;
      *) log_err "Install Python 3 manually. See $(platform_doc)"; return 1 ;;
    esac
  fi
  if ! has_cmd pipx; then
    case "$PLATFORM" in
      macos)
        python3 -m pip install --user pipx || install_brew pipx
        ;;
      linux)
        install_apt pipx || python3 -m pip install --user pipx
        ;;
    esac
  fi
  python3 -m pipx ensurepath >/dev/null 2>&1 || true
  export PATH="$HOME/.local/bin:$PATH"
}

ensure_node_runtime() {
  if has_cmd node && has_cmd npm && has_cmd npx; then return 0; fi
  case "$PLATFORM" in
    macos) install_brew node ;;
    linux) install_apt nodejs; install_apt npm ;;
    *) log_err "Install Node.js manually. See $(platform_doc)"; return 1 ;;
  esac
}

ensure_java_runtime() {
  if has_cmd java; then return 0; fi
  case "$PLATFORM" in
    macos) install_brew openjdk ;;
    linux) install_apt openjdk-17-jdk ;;
    *) log_err "Install Java manually. See $(platform_doc)"; return 1 ;;
  esac
}

ensure_pnpm() {
  ensure_node_runtime
  if has_cmd pnpm; then return 0; fi
  if has_cmd corepack; then corepack enable || true; fi
  if ! has_cmd pnpm; then npm install -g pnpm; fi
}

# Args: repo regex [release_tag]
# Prints: url\tdigest_or_empty
latest_github_asset_meta() {
  local repo="$1"
  local regex="$2"
  local tag="${3:-}"
  python3 - "$repo" "$regex" "$tag" <<'PY'
import json, re, sys, urllib.request
repo, pattern, tag = sys.argv[1:4]
if tag:
    url = f'https://api.github.com/repos/{repo}/releases/tags/{tag}'
else:
    url = f'https://api.github.com/repos/{repo}/releases/latest'
req = urllib.request.Request(url, headers={'User-Agent':'reverse-skill-bootstrap'})
with urllib.request.urlopen(req, timeout=30) as r:
    data = json.load(r)
for asset in data.get('assets', []):
    if re.search(pattern, asset.get('name','')):
        digest = asset.get('digest') or ''
        print(f"{asset.get('browser_download_url')}\t{digest}")
        raise SystemExit(0)
raise SystemExit(f'no asset matched {pattern} for {repo} tag={tag!r}')
PY
}

latest_github_asset_url() {
  local repo="$1"
  local regex="$2"
  local tag="${3:-}"
  latest_github_asset_meta "$repo" "$regex" "$tag" | cut -f1
}

# verify_sha256 file expected_or_empty [github_digest]
# expected may be "hex" or "sha256:hex"; github_digest same. Prefer expected.
verify_sha256() {
  local file="$1"
  local expected="$2"
  local api_digest="${3:-}"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | awk '{print tolower($1)}')
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | awk '{print tolower($1)}')
  else
    log_warn "sha256 tool missing; skip integrity for $file"
    return 0
  fi
  local exp="$expected"
  if [[ -z "$exp" && -n "$api_digest" ]]; then
    exp="$api_digest"
  fi
  exp=$(printf '%s' "$exp" | sed -E 's/^[Ss][Hh][Aa]256://')
  exp=$(printf '%s' "$exp" | tr 'A-F' 'a-f')
  if [[ -n "$exp" ]]; then
    if [[ "$actual" != "$exp" ]]; then
      rm -f "$file"
      log_err "SHA256 mismatch for $(basename "$file"): expected $exp got $actual (file deleted)"
      return 1
    fi
    log_ok "SHA256 OK: $actual"
  else
    log_warn "No pinned digest for $(basename "$file"); recorded sha256=$actual"
  fi
}

extract_archive() {
  local archive="$1"
  local dest="$2"
  safe_remove_install_dir "$dest" "$dest.tmp"
  mkdir -p "$dest"
  case "$archive" in
    *.zip)
      unzip -q "$archive" -d "$dest.tmp"
      ;;
    *.tar.gz|*.tgz)
      mkdir -p "$dest.tmp"
      tar -xzf "$archive" -C "$dest.tmp"
      ;;
    *)
      mkdir -p "$dest"
      cp "$archive" "$dest/"
      return 0
      ;;
  esac
  local top_count
  top_count=$(find "$dest.tmp" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
  if [[ "$top_count" == "1" ]] && [[ -d "$(find "$dest.tmp" -mindepth 1 -maxdepth 1 | head -n1)" ]]; then
    cp -a "$(find "$dest.tmp" -mindepth 1 -maxdepth 1 | head -n1)"/. "$dest/"
  else
    cp -a "$dest.tmp"/. "$dest/"
  fi
  case "$dest.tmp" in /tmp/reverse-bootstrap-*|"$TOOLS_ROOT"/*.tmp) rm -rf "$dest.tmp" ;; esac
}

# install_github_release repo regex dest [release_tag] [expected_sha256]
install_github_release() {
  local repo="$1"
  local regex="$2"
  local dest="$3"
  local tag="${4:-}"
  local expected_sha="${5:-}"
  local meta url digest file
  ensure_dir "$TOOLS_ROOT"
  meta=$(latest_github_asset_meta "$repo" "$regex" "$tag")
  url=$(printf '%s' "$meta" | cut -f1)
  digest=$(printf '%s' "$meta" | cut -f2)
  file="$(make_temp_file "$(basename "$url")")"
  log_info "download $url"
  curl -L -o "$file" "$url"
  verify_sha256 "$file" "$expected_sha" "$digest" || return 1
  extract_archive "$file" "$dest"
  rm -rf "$(dirname "$file")"
  export PATH="$dest/bin:$dest:$PATH"
  log_ok "installed $repo to $dest"
}

write_mcp_server() {
  local name="$1"
  local json_payload="$2"
  ensure_dir "$(dirname "$MCP_CONFIG_PATH")"
  python3 - "$MCP_CONFIG_PATH" "$name" "$json_payload" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
name = sys.argv[2]
payload = json.loads(sys.argv[3])
if path.exists():
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        data = {}
else:
    data = {}
data.setdefault('mcpServers', {})[name] = payload
path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
print(path)
PY
  log_ok "MCP server '$name' registered in $MCP_CONFIG_PATH"
}

test_tcp_port() {
  local port="$1"
  python3 - "$port" <<'PY' >/dev/null 2>&1
import socket, sys
port=int(sys.argv[1])
s=socket.socket()
s.settimeout(1)
s.connect(('127.0.0.1', port))
PY
}

test_mcp_http() {
  local port="$1"
  local timeout_seconds="${2:-3}"
  python3 - "$port" "$timeout_seconds" <<'PY' >/dev/null 2>&1
import sys, json, urllib.request
port = int(sys.argv[1])
timeout = int(sys.argv[2])
body = json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}).encode()
req = urllib.request.Request(
    f"http://127.0.0.1:{port}/mcp",
    data=body,
    headers={"Content-Type": "application/json"},
    method="POST"
)
try:
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        exit(0 if resp.status == 200 else 1)
except Exception:
    exit(1)
PY
}

wait_for_port() {
  local port="$1"
  local timeout_seconds="${2:-90}"
  local elapsed=0
  while (( elapsed < timeout_seconds )); do
    if test_tcp_port "$port"; then return 0; fi
    sleep 2
    elapsed=$((elapsed+2))
  done
  return 1
}

manual_required() {
  local name="$1"
  local hint="$2"
  log_warn "MANUAL_INSTALL_REQUIRED: $name — $hint"
}

is_ready_cmd() {
  local cmd="$1"
  has_cmd "$cmd"
}

ensure_jadx() {
  if has_cmd jadx; then log_ok "jadx ready: $(cmd_path jadx)"; return 0; fi
  ensure_java_runtime
  local tag="v1.5.6"
  local sha="545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974"
  local re='^jadx-1\.5\.6\.zip$'
  case "$PLATFORM" in
    macos) install_brew jadx || install_github_release skylot/jadx "$re" "$TOOLS_ROOT/jadx" "$tag" "$sha" ;;
    linux) install_github_release skylot/jadx "$re" "$TOOLS_ROOT/jadx" "$tag" "$sha" ;;
  esac
}

ensure_apktool() {
  if has_cmd apktool; then log_ok "apktool ready: $(cmd_path apktool)"; return 0; fi
  ensure_java_runtime
  case "$PLATFORM" in
    macos) install_brew apktool ;;
    linux)
      if install_apt apktool; then return 0; fi
      ensure_dir "$TOOLS_ROOT/apktool"
      local meta url digest jar wrapper
      local tag="v3.0.2"
      local sha="eee4669a704a14e0623407e6701b0b91887e61e1e4049cb7a82833e14ae8b5fd"
      local re='^apktool_3\.0\.2\.jar$'
      meta=$(latest_github_asset_meta iBotPeaches/Apktool "$re" "$tag")
      url=$(printf '%s' "$meta" | cut -f1)
      digest=$(printf '%s' "$meta" | cut -f2)
      jar="$TOOLS_ROOT/apktool/apktool.jar"
      curl -L -o "$jar" "$url"
      verify_sha256 "$jar" "$sha" "$digest" || return 1
      wrapper="$TOOLS_ROOT/apktool/apktool"
      printf '#!/usr/bin/env bash\njava -jar "%s" "$@"\n' "$jar" > "$wrapper"
      chmod +x "$wrapper"
      export PATH="$TOOLS_ROOT/apktool:$PATH"
      ;;
  esac
}

ensure_frida_tools() {
  ensure_python_runtime
  if has_cmd frida && has_cmd frida-ps; then log_ok "frida-tools ready"; return 0; fi
  pipx install frida-tools || pipx upgrade frida-tools
  export PATH="$HOME/.local/bin:$PATH"
}

ensure_idalib_mcp() {
  ensure_python_runtime
  if has_cmd ida-pro-mcp; then log_ok "ida-pro-mcp ready: $(cmd_path ida-pro-mcp)"; return 0; fi
  pipx install 'git+https://github.com/mrexodia/ida-pro-mcp.git' || pipx upgrade ida-pro-mcp
  export PATH="$HOME/.local/bin:$PATH"
  log_warn "Post-install: run 'ida-pro-mcp --install', choose Streamable HTTP + Global, then restart IDA Pro."
}

ensure_jshookmcp() {
  ensure_node_runtime
  write_mcp_server "jshook" '{"command":"npx","args":["-y","@jshookmcp/jshook@0.3.4"],"env":{"JSHOOK_BASE_PROFILE":"search"}}'
}

ensure_anything_analyzer() {
  ensure_node_runtime
  ensure_pnpm
  local dir="$TOOLS_ROOT/anything-analyzer"
  if [[ ! -d "$dir/.git" ]]; then
    if ! has_cmd git; then
      case "$PLATFORM" in macos) install_brew git ;; linux) install_apt git ;; esac
    fi
    rm -rf "$dir"
    git clone https://github.com/Mouseww/anything-analyzer "$dir"
  fi
  write_mcp_server "anything-analyzer" '{"url":"http://localhost:23816/mcp"}'
  if $START_SERVICES; then
    (cd "$dir" && pnpm install && nohup pnpm dev >/tmp/anything-analyzer.log 2>&1 &)
    if wait_for_port 23816 120; then
      if test_mcp_http 23816; then
        log_ok "anything-analyzer MCP server ready on port 23816 (HTTP verified)"
      else
        log_warn "anything-analyzer port 23816 open but MCP HTTP handshake failed; check /tmp/anything-analyzer.log"
      fi
    else
      log_warn "anything-analyzer did not open port 23816; see /tmp/anything-analyzer.log"
    fi
  fi
}

ensure_idapro() {
  ensure_idalib_mcp
  write_mcp_server "idapro" '{"url":"http://127.0.0.1:13337/mcp"}'
  if $START_SERVICES; then
    case "$PLATFORM" in
      linux)
        log_warn "Linux package does not include an IDA GUI launcher. Start IDA manually and ensure MCP listens on 127.0.0.1:13337."
        ;;
      macos)
        log_warn "Start IDA Pro manually on macOS and confirm MCP port in the IDA Output window."
        ;;
    esac
    wait_for_port 13337 45 || log_warn "idapro MCP service is not online on port 13337 yet."
    if test_mcp_http 13337 3; then
      log_ok "idapro MCP server ready (HTTP verified)"
    else
      log_warn "idapro port 13337 open but MCP HTTP handshake failed; check IDA Output window"
    fi
  fi
}

ensure_r2() {
  if has_cmd r2; then log_ok "r2 ready: $(cmd_path r2)"; return 0; fi
  case "$PLATFORM" in
    macos) install_brew radare2 ;;
    linux)
      if install_apt radare2; then return 0; fi
      manual_required r2 "Install radare2 from GitHub/source: https://github.com/radareorg/radare2"
      ;;
  esac
}

ensure_adb() {
  if has_cmd adb; then log_ok "adb ready: $(cmd_path adb)"; return 0; fi
  case "$PLATFORM" in
    macos) install_brew android-platform-tools ;;
    linux) install_apt adb || manual_required adb "Install Android platform-tools from https://developer.android.com/tools/releases/platform-tools" ;;
  esac
}

ensure_agent_browser() {
  ensure_node_runtime
  if has_cmd agent-browser; then log_ok "agent-browser ready"; return 0; fi
  npm install -g agent-browser
  if has_cmd npx; then npx playwright install chromium || true; fi
  local setup="$SKILL_ROOT/browser-automation/scripts/setup.sh"
  if [[ -x "$setup" ]]; then "$setup" --skip-browser-install || true; fi
}

ensure_ghidra_mcp() {
  ensure_java_runtime
  case "$PLATFORM" in
    macos)
      if ! has_cmd ghidraRun && [[ ! -d /Applications/Ghidra.app ]]; then
        install_brew ghidra || brew install --cask ghidra || true
      fi
      ;;
    linux)
      if ! has_cmd ghidraRun; then
        install_github_release NationalSecurityAgency/ghidra '^ghidra_.*_PUBLIC_.*\.zip$' "$TOOLS_ROOT/ghidra" || \
          manual_required ghidra-mcp "Install Ghidra from GitHub release or Flatpak, then configure ghidra-mcp if used."
      fi
      ;;
  esac
  log_warn "ghidra-mcp requires local Ghidra MCP plugin/server setup. See docs/platforms/$( [[ "$PLATFORM" == macos ]] && echo macos || echo linux ).md"
}

ensure_seclists() {
  local dir="$TOOLS_ROOT/SecLists"
  if [[ -d "$dir/.git" || -d /usr/share/seclists ]]; then log_ok "SecLists ready"; return 0; fi
  if ! has_cmd git; then case "$PLATFORM" in macos) install_brew git ;; linux) install_apt git ;; esac; fi
  git clone https://github.com/danielmiessler/SecLists "$dir"
}

ensure_proxycat() {
  ensure_python_runtime
  if has_cmd proxycat; then log_ok "proxycat ready"; return 0; fi
  pipx install git+https://github.com/honmashironeko/ProxyCat.git || manual_required proxycat "Clone/install ProxyCat manually; verify command 'proxycat'."
}

ensure_burpsuite_mcp() {
  local bridge_json
  bridge_json=$(python3 - "$REPO_ROOT/burp-mcp-full/mcp-bridge.js" <<'PY'
import json, sys
print(json.dumps({"command":"node","args":[sys.argv[1]]}))
PY
)
  write_mcp_server "burpsuite" "$bridge_json"
  manual_required burpsuite-mcp "Build burp-mcp-full and load build/libs/burp-mcp-full.jar in BurpSuite Extensions."
}

ensure_nmap() {
  if has_cmd nmap; then log_ok "nmap ready"; return 0; fi
  case "$PLATFORM" in macos) install_brew nmap ;; linux) install_apt nmap ;; esac
}

ensure_pentestswarm() {
  if has_cmd pentestswarm; then log_ok "pentestswarm ready"; return 0; fi
  if ! has_cmd go; then
    case "$PLATFORM" in macos) install_brew go ;; linux) install_apt golang-go ;; esac
  fi
  if ! go install github.com/Armur-Ai/Pentest-Swarm-AI/cmd/pentestswarm@v0.1.0; then
    if has_cmd docker; then
      write_mcp_server "pentestswarm" '{"command":"docker","args":["run","--rm","-i","ghcr.io/armur-ai/pentestswarm:v0.1.0","mcp","serve"]}'
      log_warn "pentestswarm Go install failed; registered Docker fallback ghcr.io/armur-ai/pentestswarm:v0.1.0"
    else
      manual_required pentestswarm "Install Go 1.24+ or Docker, then install Pentest-Swarm-AI and ensure pentestswarm is on PATH."
    fi
  fi
}

ensure_binwalk() {
  if has_cmd binwalk; then log_ok "binwalk ready: $(cmd_path binwalk)"; return 0; fi
  case "$PLATFORM" in
    macos) install_brew binwalk ;;
    linux) install_apt binwalk || manual_required binwalk "git clone https://github.com/ReFirmLabs/binwalk.git and install manually" ;;
  esac
}

ensure_yara() {
  if has_cmd yara; then log_ok "yara ready: $(cmd_path yara)"; return 0; fi
  case "$PLATFORM" in
    macos) install_brew yara ;;
    linux) install_apt yara || manual_required yara "Install from source: https://github.com/VirusTotal/yara" ;;
  esac
}

ensure_pwntools() {
  ensure_python_runtime
  if python3 -c "import pwn" 2>/dev/null; then log_ok "pwntools ready"; return 0; fi
  pipx install pwntools || python3 -m pip install --user pwntools
}

status_json_line() {
  local name="$1"
  local status="$2"
  local extra="${3:-}"
  if [[ -n "$extra" ]]; then
    printf '{"name":"%s","status":"%s","note":"%s"}\n' "$name" "$status" "$extra"
  else
    printf '{"name":"%s","status":"%s"}\n' "$name" "$status"
  fi
}

cap_depends() {
  case "$1" in
    idapro) echo "idalib-mcp idapro" ;;
    frida-ps) echo "frida frida-ps" ;;
    rabin2) echo "r2 rabin2" ;;
    *) echo "$1" ;;
  esac
}

expand_capabilities() {
  local seen=" "
  local out=()
  local cap dep
  for cap in "$@"; do
    for dep in $(cap_depends "$cap"); do
      if [[ "$seen" != *" $dep "* ]]; then
        out+=("$dep")
        seen+="$dep "
      fi
    done
  done
  printf '%s\n' "${out[@]}"
}

ensure_capability() {
  local name="$1"
  case "$name" in
    jadx) ensure_jadx ;;
    apktool) ensure_apktool ;;
    frida|frida-ps) ensure_frida_tools ;;
    idalib-mcp) ensure_idalib_mcp ;;
    jshookmcp) ensure_jshookmcp ;;
    anything-analyzer) ensure_anything_analyzer ;;
    idapro) ensure_idapro ;;
    r2|rabin2) ensure_r2 ;;
    adb) ensure_adb ;;
    agent-browser) ensure_agent_browser ;;
    ghidra-mcp) ensure_ghidra_mcp ;;
    seclists) ensure_seclists ;;
    proxycat) ensure_proxycat ;;
    burpsuite-mcp) ensure_burpsuite_mcp ;;
    nmap) ensure_nmap ;;
    pentestswarm) ensure_pentestswarm ;;
    binwalk) ensure_binwalk ;;
    yara) ensure_yara ;;
    pwntools) ensure_pwntools ;;
    *) log_err "No bootstrap definition for capability: $name"; return 1 ;;
  esac
}

RESULTS_FILE="$(mktemp)"
trap 'rm -f "$RESULTS_FILE"' EXIT

mapfile -t EXPANDED < <(expand_capabilities "${CAPABILITIES[@]}")

log_info "platform=$PLATFORM doc=$(platform_doc) tools_root=$TOOLS_ROOT"

for cap in "${EXPANDED[@]}"; do
  log_info "ensure $cap"
  if ensure_capability "$cap"; then
    status_json_line "$cap" "ready" >> "$RESULTS_FILE"
  else
    status_json_line "$cap" "failed" "see $(platform_doc)" >> "$RESULTS_FILE"
  fi
done

if ! $SKIP_REFRESH; then
  bash "$SCRIPT_DIR/refresh-tool-index.sh" >/dev/null || log_warn "refresh-tool-index.sh failed"
fi

python3 - "$RESULTS_FILE" <<'PY'
import json, sys
items=[]
with open(sys.argv[1], encoding='utf-8') as f:
    for line in f:
        if line.strip(): items.append(json.loads(line))
print(json.dumps(items, ensure_ascii=False, indent=2))
PY
