#!/usr/bin/env bash
# bootstrap-reverse.sh — generic Linux/macOS bootstrapper
#
# Parity target: skills/scripts/bootstrap-reverse.ps1
# Supports the same capability names and the same high-level modes:
#   - dependency expansion
#   - package / release / pipx / npm installation
#   - optional, explicit MCP host registration
#   - optional service start with --start-services
#   - refresh tool index unless --skip-refresh
#
# Usage:
#   bash skills/scripts/bootstrap-reverse.sh <capability1> [capability2] ... [--start-services] [--skip-refresh] [--mcp-host=none|claude|codex|both]
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
CLAUDE_MCP_CONFIG_PATH="${CLAUDE_MCP_CONFIG:-$HOME/.claude/mcp.json}"
CODEX_MCP_CONFIG_PATH="${CODEX_CONFIG_PATH:-$HOME/.codex/config.toml}"
MCP_HOST_TARGET="none"
MANIFEST_PATH="$SCRIPT_DIR/bootstrap-manifest.json"

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_S" in
  Darwin) PLATFORM="macos" ;;
  Linux) PLATFORM="linux" ;;
  *) PLATFORM="unknown" ;;
esac

START_SERVICES=false
SKIP_REFRESH=false
LIST_ONLY=false
MANUAL_REQUIRED=false
FAILED=false
LAST_CAPABILITY_MANUAL=false
LAST_CAPABILITY_REGISTRATION_REQUIRED=false
CAPABILITIES=()

for arg in "$@"; do
  case "$arg" in
    --start-services) START_SERVICES=true ;;
    --skip-refresh) SKIP_REFRESH=true ;;
    --list|-l) LIST_ONLY=true ;;
    --help|-h) CAPABILITIES+=("__help__") ;;
    --mcp-host=none|--mcp-host=claude|--mcp-host=codex|--mcp-host=both)
      MCP_HOST_TARGET="${arg#--mcp-host=}"
      ;;
    --mcp-host=*) echo "Invalid MCP host target: ${arg#--mcp-host=}" >&2; exit 2 ;;
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

manifest_field() {
  local capability="$1"
  local field="$2"
  python3 - "$MANIFEST_PATH" "$capability" "$field" <<'PY'
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
for capability in manifest.get('capabilities', []):
    if capability.get('name') == sys.argv[2]:
        value = capability.get(sys.argv[3])
        if value is None or value == '':
            raise SystemExit(1)
        if isinstance(value, (dict, list)):
            print(json.dumps(value, separators=(',', ':')))
        else:
            print(value)
        raise SystemExit(0)
raise SystemExit(1)
PY
}

manifest_dependency() {
  local name="$1"
  local field="$2"
  python3 - "$MANIFEST_PATH" "$name" "$field" <<'PY'
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
value = manifest.get('bootstrapDependencies', {}).get(sys.argv[2], {}).get(sys.argv[3])
if value is None or value == '':
    raise SystemExit(1)
print(value)
PY
}

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
  [[ -f /etc/os-release ]] || return 1
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      ID_LIKE=*|id_like=*) continue ;;
      ID=*|id=*)
        case "$line" in
          *[Kk][Aa][Ll][Ii]*) return 0 ;;
        esac
        ;;
    esac
  done < /etc/os-release
  return 1
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
  bash skills/scripts/bootstrap-reverse.sh <capability1> [capability2] ... [--start-services] [--skip-refresh] [--mcp-host=none|claude|codex|both]
  bash skills/scripts/bootstrap-reverse.sh --list

Capabilities (parity with bootstrap-reverse.ps1):
  jadx apktool frida frida-ps idalib-mcp jshookmcp reqable-mcp xquik-mcp anything-analyzer idapro
  r2 rabin2 adb agent-browser ghidra-mcp seclists proxycat burpsuite-mcp
  nmap pentestswarm binwalk yara pwntools

Examples:
  bash skills/scripts/bootstrap-reverse.sh jadx apktool frida
  bash skills/scripts/bootstrap-reverse.sh jshookmcp --mcp-host=codex
  bash skills/scripts/bootstrap-reverse.sh reqable-mcp --mcp-host=claude
  bash skills/scripts/bootstrap-reverse.sh idapro --start-services --mcp-host=both
  bash skills/scripts/bootstrap-reverse.sh burpsuite-mcp

Notes:
  - This script supports Linux and macOS.
  - MCP host registration is opt-in. The default is --mcp-host=none and does not write client-global config.
  - Explicit Claude registration uses CLAUDE_MCP_CONFIG or ~/.claude/mcp.json.
  - Explicit Codex registration uses CODEX_CONFIG_PATH or ~/.codex/config.toml.
  - Override install root with REVERSE_SKILL_TOOLS_DIR=~/tools.
EOF
}

ALL_CAPABILITIES=(
  jadx apktool jeb-pro frida frida-ps idalib-mcp jshookmcp reqable-mcp xquik-mcp anything-analyzer idapro
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
  ensure_python_interpreter || return 1
  local pipx_package pipx_version current_version
  pipx_package=$(manifest_dependency pipx package) || return 1
  pipx_version=$(manifest_dependency pipx version) || return 1
  current_version=""
  if has_cmd pipx; then
    current_version=$(pipx --version 2>/dev/null | head -n1 | tr -d '[:space:]')
  fi
  if [[ "$current_version" != "$pipx_version" ]]; then
    python3 -m pip install --user --upgrade "$pipx_package" || return 1
  fi
  python3 -m pipx ensurepath >/dev/null 2>&1 || true
  export PATH="$HOME/.local/bin:$PATH"
}

ensure_python_interpreter() {
  if ! has_cmd python3; then
    case "$PLATFORM" in
      macos) install_brew python ;;
      linux) install_apt python3 ;;
      *) log_err "Install Python 3 manually. See $(platform_doc)"; return 1 ;;
    esac
  fi
  has_cmd python3 || { log_err "Python 3 installation completed without a usable python3 command."; return 1; }
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
  ensure_node_runtime || return 1
  local package version current_version
  package=$(manifest_dependency pnpm package) || return 1
  version=$(manifest_dependency pnpm version) || return 1
  current_version=""
  if has_cmd pnpm; then
    current_version=$(pnpm --version 2>/dev/null | head -n1 | tr -d '[:space:]')
  fi
  if [[ "$current_version" != "$version" ]]; then
    npm install -g "$package" || return 1
  fi
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

install_git_commit() {
  local repo="$1"
  local commit="$2"
  local install_dir="$3"

  git_checkout_is_clean() {
    local checkout="$1"
    local status
    if ! status=$(git -C "$checkout" status --porcelain --untracked-files=all); then
      log_err "Cannot inspect checkout state: $checkout"
      return 1
    fi
    if [[ -n "$status" ]]; then
      log_err "Existing checkout has local changes; refusing to execute it: $checkout"
      return 1
    fi
  }

  cleanup_git_stage() {
    local stage="$1"
    local parent="$2"
    case "$stage" in
      "$parent"/.reverse-bootstrap-*) rm -rf "$stage" ;;
      *) log_err "Refusing to clean unexpected staging path: $stage" ;;
    esac
  }

  if [[ -d "$install_dir/.git" ]]; then
    local current
    if ! current=$(git -C "$install_dir" rev-parse HEAD 2>/dev/null); then
      log_err "Cannot resolve existing checkout HEAD: $install_dir"
      return 1
    fi
    if [[ "$current" != "$commit" ]]; then
      log_err "Existing checkout is not at pinned commit $commit: $install_dir"
      log_err "Move it aside explicitly, then retry; bootstrap will not overwrite local changes."
      return 1
    fi
    git_checkout_is_clean "$install_dir" || return 1
    return 0
  fi
  if [[ -e "$install_dir" ]]; then
    log_err "Install path exists but is not a git checkout: $install_dir"
    return 1
  fi

  local parent stage resolved
  parent=$(dirname "$install_dir")
  ensure_dir "$parent"
  stage=$(mktemp -d "$parent/.reverse-bootstrap-XXXXXX") || return 1
  if ! git init --quiet "$stage" ||
     ! git -C "$stage" remote add origin "$repo" ||
     ! git -C "$stage" fetch --depth 1 origin "$commit" ||
     ! git -C "$stage" checkout --quiet --detach FETCH_HEAD; then
    cleanup_git_stage "$stage" "$parent"
    return 1
  fi
  if ! resolved=$(git -C "$stage" rev-parse HEAD); then
    cleanup_git_stage "$stage" "$parent"
    return 1
  fi
  if [[ "$resolved" != "$commit" ]]; then
    log_err "Pinned checkout verification failed for $repo: expected $commit, got $resolved"
    cleanup_git_stage "$stage" "$parent"
    return 1
  fi
  if ! git_checkout_is_clean "$stage"; then
    cleanup_git_stage "$stage" "$parent"
    return 1
  fi
  if ! python3 - "$stage" "$install_dir" <<'PY'
import os, sys
os.rename(sys.argv[1], sys.argv[2])
PY
  then
    cleanup_git_stage "$stage" "$parent"
    return 1
  fi
}

write_claude_mcp_server() {
  local name="$1"
  local json_payload="$2"
  ensure_dir "$(dirname "$CLAUDE_MCP_CONFIG_PATH")"
  python3 - "$CLAUDE_MCP_CONFIG_PATH" "$name" "$json_payload" <<'PY'
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
PY
  log_ok "MCP server '$name' registered for Claude in $CLAUDE_MCP_CONFIG_PATH"
}

write_codex_mcp_server() {
  local name="$1"
  local json_payload="$2"
  ensure_dir "$(dirname "$CODEX_MCP_CONFIG_PATH")"
  python3 - "$CODEX_MCP_CONFIG_PATH" "$name" "$json_payload" <<'PY'
import json, pathlib, re, sys
path = pathlib.Path(sys.argv[1])
name = sys.argv[2]
payload = json.loads(sys.argv[3])
lines = path.read_text(encoding='utf-8').splitlines() if path.exists() else []
header = re.compile(r'^\s*\[mcp_servers\.([^\].]+)(?:\.env)?\]\s*$')
out = []
skip = False
for line in lines:
    match = header.match(line)
    if line.lstrip().startswith('['):
        if match and match.group(1) == name:
            skip = True
            continue
        if skip:
            skip = False
    if not skip:
        out.append(line)
while out and not out[-1].strip():
    out.pop()
if out:
    out.append('')

def literal(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return '[' + ', '.join(literal(v) for v in value) + ']'
    text = str(value).replace('\\', '\\\\').replace('"', '\\"')
    return f'"{text}"'

out.append(f'[mcp_servers.{name}]')
for key in ('type', 'url', 'command', 'args', 'bearer_token_env_var'):
    if key in payload:
        out.append(f'{key} = {literal(payload[key])}')
for key in sorted(k for k in payload if k not in {'type', 'url', 'command', 'args', 'bearer_token_env_var', 'env', 'headers'}):
    out.append(f'{key} = {literal(payload[key])}')
env = payload.get('env')
if isinstance(env, dict) and env:
    out.append('')
    out.append(f'[mcp_servers.{name}.env]')
    for key in sorted(env):
        out.append(f'{key} = {literal(env[key])}')
path.write_text('\n'.join(out) + '\n', encoding='utf-8')
PY
  log_ok "MCP server '$name' registered for Codex in $CODEX_MCP_CONFIG_PATH"
}

write_mcp_server() {
  local name="$1"
  local json_payload="$2"
  case "$MCP_HOST_TARGET" in
    none)
      LAST_CAPABILITY_REGISTRATION_REQUIRED=true
      log_warn "MCP registration skipped for '$name' (client-neutral default). Re-run with --mcp-host=claude, codex, or both."
      ;;
    claude)
      write_claude_mcp_server "$name" "$json_payload"
      ;;
    codex)
      write_codex_mcp_server "$name" "$json_payload"
      ;;
    both)
      write_claude_mcp_server "$name" "$json_payload"
      write_codex_mcp_server "$name" "$json_payload"
      ;;
  esac
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

ensure_jeb_pro() {
  if has_cmd jeb_wincon || has_cmd jeb; then
    log_ok "JEB Pro ready: $(cmd_path jeb_wincon)$(cmd_path jeb)"
    return 0
  fi
  manual_required jeb-pro "JEB Pro is commercial. Install it with a valid PNF Software license, then refresh the tool index."
  LAST_CAPABILITY_MANUAL=true
  MANUAL_REQUIRED=true
  return 0
}

ensure_jadx() {
  if has_cmd jadx; then log_ok "jadx ready: $(cmd_path jadx)"; return 0; fi
  ensure_java_runtime
  local repo re tag sha
  repo=$(manifest_field jadx repo) || return 1
  re=$(manifest_field jadx assetRegex) || return 1
  tag=$(manifest_field jadx releaseTag) || return 1
  sha=$(manifest_field jadx assetSha256) || return 1
  case "$PLATFORM" in
    macos) install_brew jadx || install_github_release "$repo" "$re" "$TOOLS_ROOT/jadx" "$tag" "$sha" ;;
    linux) install_github_release "$repo" "$re" "$TOOLS_ROOT/jadx" "$tag" "$sha" ;;
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
      local repo tag sha re
      repo=$(manifest_field apktool repo) || return 1
      tag=$(manifest_field apktool releaseTag) || return 1
      sha=$(manifest_field apktool assetSha256) || return 1
      re=$(manifest_field apktool assetRegex) || return 1
      meta=$(latest_github_asset_meta "$repo" "$re" "$tag")
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
  ensure_python_runtime || return 1
  if has_cmd frida && has_cmd frida-ps; then log_ok "frida-tools ready"; return 0; fi
  local package
  package=$(manifest_field frida pipPackage) || return 1
  pipx install --force "$package" || return 1
  export PATH="$HOME/.local/bin:$PATH"
}

ensure_idalib_mcp() {
  ensure_python_runtime || return 1
  if has_cmd ida-pro-mcp; then log_ok "ida-pro-mcp ready: $(cmd_path ida-pro-mcp)"; return 0; fi
  local source
  source=$(manifest_field idalib-mcp pipSource) || return 1
  pipx install --force "$source" || return 1
  export PATH="$HOME/.local/bin:$PATH"
  log_warn "Post-install: run 'ida-pro-mcp --install', choose Streamable HTTP + Global, then restart IDA Pro."
}

ensure_jshookmcp() {
  ensure_node_runtime || return 1
  local package
  package=$(manifest_field jshookmcp npmPackage) || return 1
  write_mcp_server "jshook" "$(python3 - "$package" <<'PY'
import json, sys
print(json.dumps({'command':'npx','args':['-y',sys.argv[1]],'env':{'JSHOOK_BASE_PROFILE':'search'}}))
PY
)"
}

ensure_reqable_mcp() {
  ensure_node_runtime || return 1
  local package
  package=$(manifest_field reqable-mcp npmPackage) || return 1
  write_mcp_server "reqable-mcp" "$(python3 - "$package" <<'PY'
import json, sys
print(json.dumps({'command':'npx','args':['-y',sys.argv[1]]}))
PY
)"
  log_warn "Reqable MCP requires the separately installed Reqable desktop application and its local API."
}

ensure_xquik_mcp() {
  local url payload
  url=$(manifest_field xquik-mcp mcpUrl) || return 1
  payload=$(python3 - "$url" <<'PY'
import json, sys
print(json.dumps({'url': sys.argv[1]}))
PY
)
  write_mcp_server "xquik" "$payload"
  if ! $LAST_CAPABILITY_REGISTRATION_REQUIRED; then
    log_ok "xquik remote MCP registered; complete OAuth in the selected MCP client"
  fi
}

ensure_anything_analyzer() {
  local dir="$TOOLS_ROOT/anything-analyzer"
  local repo commit
  repo=$(manifest_field anything-analyzer repoUrl) || return 1
  commit=$(manifest_field anything-analyzer pinnedCommit) || return 1
  if ! has_cmd git; then
    case "$PLATFORM" in macos) install_brew git ;; linux) install_apt git ;; esac
  fi
  install_git_commit "$repo" "$commit" "$dir" || return 1
  ensure_node_runtime || return 1
  ensure_pnpm || return 1
  write_mcp_server "anything-analyzer" '{"url":"http://localhost:23816/mcp"}'
  if $START_SERVICES; then
    (cd "$dir" && pnpm install --frozen-lockfile) || return 1
    install_git_commit "$repo" "$commit" "$dir" || return 1
    (
      cd "$dir" || exit 1
      if has_cmd nohup; then
        nohup pnpm dev >/tmp/anything-analyzer.log 2>&1 &
      else
        pnpm dev >/tmp/anything-analyzer.log 2>&1 &
      fi
    )
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
  ensure_node_runtime || return 1
  if has_cmd agent-browser; then log_ok "agent-browser ready"; return 0; fi
  local package
  package=$(manifest_field agent-browser npmPackage) || return 1
  npm install -g "$package" || return 1
  if has_cmd npx; then npx playwright install chromium || true; fi
  local setup="$SKILL_ROOT/browser-automation/scripts/setup.sh"
  if [[ -x "$setup" ]]; then "$setup" --skip-browser-install || true; fi
}

ensure_ghidra_mcp() {
  ensure_java_runtime || return 1
  local repo regex
  repo=$(manifest_field ghidra-mcp repo) || return 1
  regex=$(manifest_field ghidra-mcp assetRegex) || return 1
  case "$PLATFORM" in
    macos)
      if ! has_cmd ghidraRun && [[ ! -d /Applications/Ghidra.app ]]; then
        install_brew ghidra || brew install --cask ghidra || true
      fi
      ;;
    linux)
      if ! has_cmd ghidraRun; then
        install_github_release "$repo" "$regex" "$TOOLS_ROOT/ghidra" || \
          manual_required ghidra-mcp "Install Ghidra from GitHub release or Flatpak, then configure ghidra-mcp if used."
      fi
      ;;
  esac
  log_warn "ghidra-mcp requires local Ghidra MCP plugin/server setup. See docs/platforms/$( [[ "$PLATFORM" == macos ]] && echo macos || echo linux ).md"
}

ensure_seclists() {
  local dir="$TOOLS_ROOT/SecLists"
  if [[ -d /usr/share/seclists ]]; then log_ok "SecLists ready"; return 0; fi
  if ! has_cmd git; then case "$PLATFORM" in macos) install_brew git ;; linux) install_apt git ;; esac; fi
  local repo commit
  repo=$(manifest_field seclists repo) || return 1
  commit=$(manifest_field seclists pinnedCommit) || return 1
  install_git_commit "$repo" "$commit" "$dir" || return 1
}

ensure_proxycat() {
  ensure_python_runtime || return 1
  if has_cmd proxycat; then log_ok "proxycat ready"; return 0; fi
  local repo commit
  repo=$(manifest_field proxycat repo) || return 1
  commit=$(manifest_field proxycat pinnedCommit) || return 1
  pipx install "git+${repo}@${commit}" || {
    manual_required proxycat "Clone/install ProxyCat manually; verify command 'proxycat'."
    LAST_CAPABILITY_MANUAL=true
    MANUAL_REQUIRED=true
    return 0
  }
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

register_pentestswarm_mcp() {
  local executable="$1"
  local definition
  definition=$(python3 - "$executable" <<'PY'
import json, sys
print(json.dumps({"command": sys.argv[1], "args": ["mcp", "serve"]}))
PY
)
  write_mcp_server "pentestswarm" "$definition"
}

ensure_pentestswarm() {
  local pentestswarm_path
  pentestswarm_path="$(cmd_path pentestswarm)"
  if [[ -n "$pentestswarm_path" ]]; then
    register_pentestswarm_mcp "$pentestswarm_path"
    log_ok "pentestswarm ready"
    return 0
  fi
  if ! has_cmd go; then
    case "$PLATFORM" in macos) install_brew go ;; linux) install_apt golang-go ;; esac
  fi
  local go_package docker_image
  go_package=$(manifest_field pentestswarm goPackage) || return 1
  docker_image=$(manifest_field pentestswarm dockerImage) || return 1
  if go install "$go_package"; then
    local go_bin
    go_bin="$(go env GOBIN 2>/dev/null || true)"
    if [[ -z "$go_bin" ]]; then
      go_bin="$(go env GOPATH 2>/dev/null || true)/bin"
    fi
    if [[ -x "$go_bin/pentestswarm" ]]; then
      register_pentestswarm_mcp "$go_bin/pentestswarm"
      log_ok "pentestswarm installed and registered"
      return 0
    fi
    log_warn "pentestswarm installed but no executable was found in GOBIN/GOPATH; trying Docker fallback"
  fi
  if has_cmd docker; then
    write_mcp_server "pentestswarm" "$(python3 - "$docker_image" <<'PY'
import json, sys
print(json.dumps({'command':'docker','args':['run','--rm','-i',sys.argv[1],'mcp','serve']}))
PY
)"
    log_warn "pentestswarm Go install failed or produced no runnable binary; prepared Docker fallback $docker_image"
  else
    manual_required pentestswarm "Install Go 1.24+ or Docker, then install Pentest-Swarm-AI and ensure pentestswarm is on PATH."
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
  ensure_python_runtime || return 1
  if python3 -c "import pwn" 2>/dev/null; then log_ok "pwntools ready"; return 0; fi
  local package
  package=$(manifest_field pwntools pipPackage) || return 1
  pipx install "$package" || python3 -m pip install --user "$package" || return 1
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
    jeb-pro) ensure_jeb_pro ;;
    jadx) ensure_jadx ;;
    apktool) ensure_apktool ;;
    frida|frida-ps) ensure_frida_tools ;;
    idalib-mcp) ensure_idalib_mcp ;;
    jshookmcp) ensure_jshookmcp ;;
    reqable-mcp) ensure_reqable_mcp ;;
    xquik-mcp) ensure_xquik_mcp ;;
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

# macOS ships Bash 3.2, which has no mapfile/readarray. Keep this path portable
# instead of requiring users to install a newer Bash just to run the bootstrapper.
EXPANDED=()
while IFS= read -r capability; do
  [[ -n "$capability" ]] || continue
  EXPANDED+=("$capability")
done < <(expand_capabilities "${CAPABILITIES[@]}")

log_info "platform=$PLATFORM doc=$(platform_doc) tools_root=$TOOLS_ROOT mcp_host=$MCP_HOST_TARGET"

if ! ensure_python_interpreter; then
  log_err "Python 3 is required to read bootstrap-manifest.json; no capability was executed."
  exit 1
fi

for cap in "${EXPANDED[@]}"; do
  log_info "ensure $cap"
  LAST_CAPABILITY_MANUAL=false
  LAST_CAPABILITY_REGISTRATION_REQUIRED=false
  if ensure_capability "$cap"; then
    if $LAST_CAPABILITY_MANUAL; then
      status_json_line "$cap" "manual-required" "see $(platform_doc)" >> "$RESULTS_FILE"
    elif $LAST_CAPABILITY_REGISTRATION_REQUIRED; then
      status_json_line "$cap" "registration-required" "re-run with --mcp-host=claude, codex, or both" >> "$RESULTS_FILE"
    else
      status_json_line "$cap" "ready" >> "$RESULTS_FILE"
    fi
  else
    status_json_line "$cap" "failed" "see $(platform_doc)" >> "$RESULTS_FILE"
    FAILED=true
  fi
done

if ! $SKIP_REFRESH; then
  bash "$SCRIPT_DIR/refresh-tool-index.sh" >/dev/null || log_warn "refresh-tool-index.sh failed"
fi

FINAL_EXIT_CODE=0
if $FAILED; then
  FINAL_EXIT_CODE=1
elif $MANUAL_REQUIRED; then
  FINAL_EXIT_CODE=2
fi

if has_cmd python3; then
  python3 - "$RESULTS_FILE" <<'PY'
import json, sys
items=[]
with open(sys.argv[1], encoding='utf-8') as f:
    for line in f:
        if line.strip(): items.append(json.loads(line))
print(json.dumps(items, ensure_ascii=False, indent=2))
PY
else
  log_warn "Python 3 is unavailable; emitting bootstrap results without JSON formatting"
  cat "$RESULTS_FILE"
fi

exit "$FINAL_EXIT_CODE"
