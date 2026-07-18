#!/usr/bin/env bash
# refresh-tool-index.sh — generic Linux/macOS tool index refresh
#
# This script is intentionally detection-only. It does not install tools.
# Output defaults:
#   skills/tool-index.md
#   skills/tool-index.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_ROOT/.." && pwd)"

OUTPUT_MD="${1:-${SKILL_ROOT}/tool-index.md}"
OUTPUT_JSON="${2:-${SKILL_ROOT}/tool-index.json}"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
UNAME_R="$(uname -r 2>/dev/null || echo unknown)"

case "$UNAME_S" in
  Darwin) PLATFORM="macos" ;;
  Linux) PLATFORM="linux" ;;
  *) PLATFORM="unknown" ;;
esac

has_cmd() { command -v "$1" >/dev/null 2>&1; }
cmd_path() { command -v "$1" 2>/dev/null || true; }

run_version() {
  local cmd="$1"; shift
  if ! has_cmd "$cmd"; then
    echo ""
    return 0
  fi
  "$cmd" "$@" 2>&1 | head -n 1 | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true
}

file_exists_any() {
  local p
  for p in "$@"; do
    if [[ -e "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  echo ""
}

brew_prefix() {
  if has_cmd brew; then
    brew --prefix 2>/dev/null || true
  fi
}

install_hint() {
  local name="$1"
  case "$PLATFORM:$name" in
    linux:java) echo "apt: sudo apt install openjdk-17-jdk" ;;
    linux:node) echo "apt/nvm: sudo apt install nodejs npm; prefer NodeSource or nvm for newer Node" ;;
    linux:python3) echo "apt: sudo apt install python3 python3-venv python3-pip pipx" ;;
    linux:jadx) echo "GitHub release: download jadx ZIP to ~/tools/jadx" ;;
    linux:apktool) echo "apt or jar: sudo apt install apktool; or official apktool.jar" ;;
    linux:adb) echo "apt or Android platform-tools: sudo apt install adb" ;;
    linux:frida) echo "pipx: pipx install frida-tools" ;;
    linux:r2|linux:radare2) echo "GitHub/source preferred; apt if available" ;;
    linux:ghidra) echo "GitHub release ZIP or Flatpak; Java required" ;;
    linux:burpsuite) echo "manual installer/jar; then load burp-mcp-full jar" ;;
    linux:jshookmcp) echo "npx: npx -y @jshookmcp/jshook@0.3.4" ;;
    linux:anything-analyzer) echo "git clone + pnpm install + pnpm dev" ;;
    linux:nuclei) echo "GitHub release or go install; apt may be unavailable" ;;
    linux:seclists) echo "git clone https://github.com/danielmiessler/SecLists ~/tools/SecLists" ;;

    macos:java) echo "brew: brew install openjdk" ;;
    macos:node) echo "brew/nvm: brew install node; or nvm" ;;
    macos:python3) echo "brew: brew install python; then pipx/venv" ;;
    macos:jadx) echo "brew: brew install jadx" ;;
    macos:apktool) echo "brew: brew install apktool" ;;
    macos:adb) echo "brew: brew install android-platform-tools" ;;
    macos:frida) echo "pipx: pipx install frida-tools" ;;
    macos:r2|macos:radare2) echo "brew: brew install radare2" ;;
    macos:ghidra) echo "brew: brew install ghidra or brew install --cask ghidra" ;;
    macos:burpsuite) echo "brew cask/manual: brew install --cask burp-suite" ;;
    macos:jshookmcp) echo "npx: npx -y @jshookmcp/jshook@0.3.4" ;;
    macos:anything-analyzer) echo "git clone + corepack enable + pnpm install + pnpm dev" ;;
    macos:nuclei) echo "brew: brew install nuclei" ;;
    macos:seclists) echo "git clone https://github.com/danielmiessler/SecLists ~/tools/SecLists" ;;

    linux:binwalk) echo "apt: sudo apt install binwalk" ;;
    linux:yara) echo "apt: sudo apt install yara" ;;
    linux:pwntools) echo "pipx: pipx install pwntools" ;;

    macos:binwalk) echo "brew: brew install binwalk" ;;
    macos:yara) echo "brew: brew install yara" ;;
    macos:pwntools) echo "pipx: pipx install pwntools" ;;
    *) echo "see PLATFORMS.md and docs/platforms/${PLATFORM}.md" ;;
  esac
}

# name|skill|purpose|commands|version command args|extra path probes
TOOLS=(
  "java|core-runtime|Java runtime for jadx/apktool/Burp/Ghidra|java|java -version|"
  "python3|core-runtime|Python runtime for helper scripts and pipx tools|python3|python3 --version|"
  "pipx|core-runtime|Isolated Python CLI installer|pipx|pipx --version|"
  "node|core-runtime|Node.js runtime for MCP bridges|node|node --version|"
  "npm|core-runtime|Node package manager|npm|npm --version|"
  "npx|core-runtime|Run npm MCP packages|npx|npx --version|"
  "jadx|apk-reverse|APK Java/Kotlin decompiler|jadx|jadx --version|$HOME/tools/jadx/bin/jadx"
  "apktool|apk-reverse|APK decode and rebuild|apktool|apktool --version|"
  "adb|apk-reverse|Android device bridge|adb|adb version|$HOME/tools/android-platform-tools/platform-tools/adb"
  "frida|reverse-engineering|Dynamic instrumentation CLI|frida|frida --version|$HOME/.local/bin/frida"
  "frida-ps|reverse-engineering|Frida process listing|frida-ps|frida-ps --version|$HOME/.local/bin/frida-ps"
  "r2|radare2|radare2 CLI analysis|r2|r2 -v|"
  "rabin2|radare2|Binary metadata extraction|rabin2|rabin2 -v|"
  "ghidra|reverse-engineering|Ghidra reverse-engineering suite|ghidraRun|ghidraRun --version|$HOME/tools/ghidra/ghidraRun;/Applications/Ghidra.app"
  "idapro|ida-reverse|IDA Pro commercial reverse-engineering suite|idat|idat -v|/opt/idapro/idat;/Applications/IDA Professional.app;/Applications/IDA Free.app"
  "burpsuite|burp-mcp|BurpSuite desktop application|burpsuite|burpsuite --version|/Applications/Burp Suite Professional.app;/Applications/Burp Suite Community Edition.app"
  "graphviz|diagram-generator|Graphviz diagram rendering|dot|dot -V|"
  "plantuml|diagram-generator|PlantUML diagram rendering|plantuml|plantuml -version|"
  "nmap|pentest-tools|Network scanner|nmap|nmap --version|"
  "sqlmap|pentest-tools|SQL injection testing tool|sqlmap|sqlmap --version|"
  "ffuf|pentest-tools|Web fuzzer|ffuf|ffuf -V|"
  "hashcat|pentest-tools|Password recovery|hashcat|hashcat --version|"
  "nuclei|pentest-tools|Template-based vulnerability scanner|nuclei|nuclei -version|"
  "binwalk|firmware-pentest|Firmware extraction and analysis|binwalk|binwalk --version|"
  "seclists|pentest-tools|Security wordlists|none|none|$HOME/tools/SecLists;/usr/share/seclists"
  "jshookmcp|js-reverse|JS/CDP/Hook MCP runtime via npx|npx|npx --version|"
  "anything-analyzer|browser-automation|Browser/HTTP analyzer MCP project|none|none|$HOME/tools/anything-analyzer;$REPO_ROOT/../anything-analyzer"
  "burp-mcp-full|burp-mcp|Local Burp MCP extension and stdio bridge|none|none|$REPO_ROOT/burp-mcp-full/mcp-bridge.js"
  "binwalk|firmware-pentest|Firmware extraction and analysis|binwalk|binwalk --version|"
  "yara|malware-analysis|Malware rule matching engine|yara|yara --version|"
  "pwntools|reverse-engineering|CTF pwn exploit development framework|pwn|pwn --version|"
)

records_tmp="$(mktemp)"
trap 'rm -f "$records_tmp"' EXIT

{
  echo "# Tool Index"
  echo ""
  echo "- Generated at: $GENERATED_AT"
  echo "- Platform: $PLATFORM ($UNAME_S $UNAME_R)"
  echo "- Script: \`skills/scripts/refresh-tool-index.sh\`"
  echo "- Note: This script detects tools only. It does not install tools."
  echo ""
  echo "| Tool | Skill | Purpose | Available | Path | Version | Source | Install hint |"
  echo "|---|---|---|---|---|---|---|---|"
} > "$OUTPUT_MD"

for entry in "${TOOLS[@]}"; do
  IFS='|' read -r name skill purpose commands version_spec probes <<< "$entry"

  available="no"
  path=""
  version=""
  source=""

  if [[ "$commands" != "none" ]]; then
    IFS=',' read -ra cmd_list <<< "$commands"
    for cmd in "${cmd_list[@]}"; do
      if has_cmd "$cmd"; then
        available="yes"
        path="$(cmd_path "$cmd")"
        source="command"
        break
      fi
    done
  fi

  if [[ "$available" == "no" && -n "${probes:-}" ]]; then
    IFS=';' read -ra probe_list <<< "$probes"
    for probe in "${probe_list[@]}"; do
      if [[ -e "$probe" ]]; then
        available="yes"
        path="$probe"
        source="path-probe"
        break
      fi
    done
  fi

  if [[ "$version_spec" != "none" ]]; then
    read -r ver_cmd ver_arg1 ver_arg2 <<< "$version_spec"
    if has_cmd "$ver_cmd"; then
      version="$(run_version "$ver_cmd" ${ver_arg1:-} ${ver_arg2:-})"
    fi
  fi

  [[ -z "$path" ]] && path="—"
  [[ -z "$version" ]] && version="—"
  [[ -z "$source" ]] && source="—"
  hint="$(install_hint "$name")"

  echo "| $name | $skill | $purpose | $available | $path | $version | $source | $hint |" >> "$OUTPUT_MD"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$skill" "$purpose" "$available" "$path" "$version" "$source" "$hint" >> "$records_tmp"
done

{
  echo ""
  echo "---"
  echo ""
  echo "## Next steps"
  echo ""
  case "$PLATFORM" in
    linux)
      echo "- Read \`docs/platforms/linux.md\` for ordinary Linux setup."
      echo "- If the host is Kali, read \`kali/README-kali.md\` instead."
      ;;
    macos)
      echo "- Read \`docs/platforms/macos.md\` for Homebrew and app-bundle setup."
      ;;
    *)
      echo "- Read \`PLATFORMS.md\` and choose the closest platform guide."
      ;;
  esac
  echo "- Register MCP servers in your Agent client; tool availability does not imply MCP registration."
} >> "$OUTPUT_MD"

# --- Capability status view -------------------------------------------------
# Parity with skills/scripts/refresh-tool-index.ps1 (the "能力状态视图" block).
# Computed by parsing skills/scripts/bootstrap-manifest.json plus probing the
# local MCP config and each declared servicePort. All logic is contained in the
# Python heredoc below so this script keeps its existing bash dependencies.

MANIFEST_PATH="$SCRIPT_DIR/bootstrap-manifest.json"
MCP_CONFIG_PATH_FOR_CAP="${CLAUDE_MCP_CONFIG:-$HOME/.claude/mcp.json}"
CAP_RECORDS_TMP="$(mktemp)"
# Replace earlier single-file trap with one that also cleans this capability tmp file.
trap 'rm -f "$records_tmp" "$CAP_RECORDS_TMP"' EXIT

if [[ -f "$MANIFEST_PATH" ]]; then
  # Pass tool availability info (collected earlier) so the capability view can
  # reflect the same "tool ready" judgement as the tool table above.
  python3 - "$MANIFEST_PATH" "$MCP_CONFIG_PATH_FOR_CAP" "$records_tmp" "$CAP_RECORDS_TMP" <<'PY'
import json, pathlib, socket, sys, urllib.request

manifest_path, mcp_config_path, tool_records_path, out_path = sys.argv[1:5]

# Load capability definitions
try:
    manifest = json.loads(pathlib.Path(manifest_path).read_text(encoding='utf-8'))
except Exception:
    manifest = {'capabilities': []}
capabilities = manifest.get('capabilities', [])

# Load currently registered MCP server names
registered_names = set()
try:
    mcp_data = json.loads(pathlib.Path(mcp_config_path).read_text(encoding='utf-8'))
    registered_names = set(mcp_data.get('mcpServers', {}).keys())
except Exception:
    pass

# Load tool availability from the table we already wrote (best-effort match by name)
tool_available = {}
try:
    with open(tool_records_path, encoding='utf-8') as f:
        for line in f:
            parts = line.rstrip('\n').split('\t')
            if len(parts) >= 4:
                tool_available[parts[0]] = (parts[3] == 'yes')
except Exception:
    pass

def tcp_open(port, timeout=1.0):
    try:
        s = socket.socket(); s.settimeout(timeout)
        s.connect(('127.0.0.1', int(port))); s.close()
        return True
    except Exception:
        return False

def mcp_http_handshake(port, timeout=3):
    try:
        body = json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}).encode()
        req = urllib.request.Request(
            f"http://127.0.0.1:{int(port)}/mcp",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200
    except Exception:
        return False

rows = []
for cap in capabilities:
    name = cap.get('name')
    if not name:
        continue
    bootstrap_kind = cap.get('bootstrapKind', '')
    can_auto_install = bool(cap.get('canAutoInstall', False))
    mcp_names = cap.get('mcpNames') or []
    service_port = cap.get('servicePort')
    verification_mode = cap.get('verificationMode', '')

    registered = any(n in registered_names for n in mcp_names) if mcp_names else False
    service_online = False
    mcp_http_verified = False
    if service_port:
        service_online = tcp_open(service_port)
        if service_online:
            mcp_http_verified = mcp_http_handshake(service_port)

    tool_ready = bool(tool_available.get(name, False))

    if mcp_names:
        if verification_mode == 'service-and-registration':
            ready = registered and service_online
        elif verification_mode == 'service-or-registration':
            ready = registered or service_online
        elif bootstrap_kind == 'npm-mcp':
            ready = registered and tool_ready
        else:
            ready = registered or tool_ready
    else:
        ready = tool_ready

    rows.append({
        'name': name,
        'tool_available': tool_ready,
        'ready': ready,
        'mcp_registered': registered if mcp_names else None,
        'service_online': service_online if service_port else None,
        'mcp_http_verified': mcp_http_verified if service_port else None,
        'can_auto_install': can_auto_install,
        'bootstrap_kind': bootstrap_kind,
    })

with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(rows, f, ensure_ascii=False)
PY

  # Append the markdown capability table (mirrors the headings used in the ps1 version)
  {
    echo ""
    echo "---"
    echo ""
    echo "## 能力状态视图 (Capability Status)"
    echo ""
    echo "| 能力 | 工具可用 | Ready | MCP 已注册 | 服务在线 | MCP HTTP | 可自动安装 | 安装方式 |"
    echo "|------|---------|-------|-----------|---------|----------|-----------|---------|"
  } >> "$OUTPUT_MD"

  python3 - "$CAP_RECORDS_TMP" "$OUTPUT_MD" <<'PY'
import json, sys
rows = json.loads(open(sys.argv[1], encoding='utf-8').read())
def yn(v):  # True->✓, False->✗
    return '✓' if v else '✗'
def opt(v):  # True->✓, False->—, None->—
    if v is True: return '✓'
    if v is False: return '—'
    return '—'
with open(sys.argv[2], 'a', encoding='utf-8') as out:
    for r in rows:
        out.write(
            f"| {r['name']} | {yn(r['tool_available'])} | {yn(r['ready'])} | "
            f"{opt(r['mcp_registered'])} | {opt(r['service_online'])} | "
            f"{opt(r['mcp_http_verified'])} | {yn(r['can_auto_install'])} | "
            f"{r['bootstrap_kind'] or '—'} |\n"
        )
    out.write("\n> ✓ = 是 | ✗ = 否 | — = 不适用或未检测\n\n")
PY
else
  CAP_RECORDS_TMP=""
fi
# --- end capability status view ---------------------------------------------

python3 - "$records_tmp" "$OUTPUT_JSON" "$GENERATED_AT" "$PLATFORM" "$UNAME_S $UNAME_R" "${CAP_RECORDS_TMP:-}" <<'PY'
import json, sys
records_path, output_json, generated_at, platform, uname, cap_records_path = sys.argv[1:7]
tools=[]
with open(records_path, encoding='utf-8') as f:
    for line in f:
        name, skill, purpose, available, path, version, source, hint = line.rstrip('\n').split('\t')
        tools.append({
            'name': name,
            'skill': skill,
            'purpose': purpose,
            'available': available == 'yes',
            'path': None if path == '—' else path,
            'version': None if version == '—' else version,
            'source': None if source == '—' else source,
            'install_hint': hint,
        })
capabilities = []
if cap_records_path:
    try:
        with open(cap_records_path, encoding='utf-8') as f:
            capabilities = json.load(f)
    except Exception:
        capabilities = []
with open(output_json, 'w', encoding='utf-8') as f:
    json.dump({
        'generated_at': generated_at,
        'platform': platform,
        'uname': uname,
        'script': 'skills/scripts/refresh-tool-index.sh',
        'tools': tools,
        'capabilities': capabilities,
    }, f, ensure_ascii=False, indent=2)
PY

echo "✅ Tool index refreshed"
echo "  markdown=$OUTPUT_MD"
echo "  json=$OUTPUT_JSON"
echo "  platform=$PLATFORM"
echo "  tools=${#TOOLS[@]}"
