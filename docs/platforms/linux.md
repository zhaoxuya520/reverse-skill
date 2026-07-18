# Generic Linux Setup

This guide covers ordinary Linux distributions such as Ubuntu, Debian, Linux Mint, Pop!_OS, and other Debian-family systems. Kali Linux has a dedicated path: [`../../kali/README-kali.md`](../../kali/README-kali.md).

## Positioning

The core knowledge layer is platform-agnostic. On Linux, what changes is the execution layer:

- package manager: usually `apt`, sometimes distro-specific package managers;
- Python isolation: prefer `pipx` or a venv because modern systems may enforce PEP 668;
- GUI apps: BurpSuite, IDA Pro, Ghidra paths differ by installation method;
- security tools: distro packages may be old or absent, so GitHub releases are often preferred.

## Quick setup baseline

```bash
sudo apt update
sudo apt install -y \
  git curl wget ca-certificates unzip tar jq \
  python3 python3-venv python3-pip pipx \
  openjdk-17-jdk nodejs npm \
  graphviz plantuml nmap sqlmap ffuf hashcat binwalk

python3 -m pipx ensurepath
```

> Ubuntu repository versions can be old. For Node.js, radare2, jadx, nuclei, and Ghidra, prefer the alternatives below when the distro package is missing or outdated.

## Tool installation matrix

| Capability | Preferred Linux setup | Alternative | Notes |
|---|---|---|---|
| Java / JDK | `sudo apt install openjdk-17-jdk` | SDKMAN / vendor JDK | Required by jadx, apktool, BurpSuite, Ghidra. |
| Node.js | NodeSource or `nvm` | distro `nodejs npm` | Distro Node can be old; MCP servers often prefer recent Node. |
| Python tools | `pipx install <tool>` | project venv | Avoid global `pip install` on PEP 668 systems. |
| jadx | GitHub release ZIP | custom install under `~/tools/jadx` | Ubuntu apt may not have `jadx`. |
| apktool | `sudo apt install apktool` | official `apktool.jar` + wrapper | Distro package may be old. |
| adb | `sudo apt install adb` | official Android platform-tools | Use official platform-tools for latest devices. |
| Frida | `pipx install frida-tools` | venv + `pip install frida-tools` | Provides `frida`, `frida-ps`, `frida-trace`. |
| radare2 | GitHub release / build from source | distro package when available | Ubuntu 22.04 may not provide a candidate. |
| Ghidra | GitHub release ZIP | Flatpak / distro package | Java required. |
| IDA Pro | manual Linux installer | — | Commercial tool; set `IDADIR` or document local path. |
| BurpSuite | manual installer / jar | distro package if available | Load `burp-mcp-full` extension manually. |
| jshookmcp | `npx -y @jshookmcp/jshook@0.3.4` | MCP config command | Requires Node/npm/npx. |
| anything-analyzer | project clone + `pnpm install` | custom local service | Register its MCP endpoint in the Agent client. |
| nuclei | GitHub release / `go install` | distro package if available | Often absent in Ubuntu apt. |
| SecLists | `git clone https://github.com/danielmiessler/SecLists ~/tools/SecLists` | distro package if available | Keep path in tool index. |

## Recommended path layout

```text
~/tools/
├── jadx/
├── ghidra/
├── SecLists/
├── android-platform-tools/
└── anything-analyzer/

~/.local/bin/              # pipx / user scripts
/opt/idapro/               # optional IDA Pro install
/usr/bin/                  # distro packages
```

## Installing common tools

### jadx from GitHub release

```bash
mkdir -p ~/tools/jadx
curl -L https://github.com/skylot/jadx/releases/latest/download/jadx-1.5.5.zip -o /tmp/jadx.zip
unzip -q /tmp/jadx.zip -d ~/tools/jadx
export PATH="$HOME/tools/jadx/bin:$PATH"
jadx --version
```

If the release filename changes, download the latest Linux/ZIP asset from <https://github.com/skylot/jadx/releases>.

### Frida via pipx

```bash
pipx install frida-tools
frida --version
frida-ps --version
```

### radare2

Prefer the official release or source install when the distro package is absent:

```bash
git clone https://github.com/radareorg/radare2 ~/tools/radare2-src
cd ~/tools/radare2-src
sys/install.sh
r2 -v
```

### Ghidra

```bash
mkdir -p ~/tools/ghidra
# Download latest release from https://github.com/NationalSecurityAgency/ghidra/releases
# unzip ghidra_*.zip into ~/tools/ghidra
```

### Android platform-tools alternative

```bash
mkdir -p ~/tools/android-platform-tools
# Download platform-tools-latest-linux.zip from Android Developers
# unzip into ~/tools/android-platform-tools
export PATH="$HOME/tools/android-platform-tools/platform-tools:$PATH"
adb version
```

## MCP setup notes

### BurpSuite MCP

Build the extension:

```bash
cd burp-mcp-full
chmod +x build.sh
./build.sh
```

Then load the generated jar in BurpSuite:

```text
Burp Suite → Extensions → Add → Java → build/libs/burp-mcp-full.jar
```

MCP stdio bridge example:

```json
{
  "mcpServers": {
    "burpsuite": {
      "command": "node",
      "args": ["/absolute/path/to/reverse-skill/burp-mcp-full/mcp-bridge.js"]
    }
  }
}
```

### jshookmcp

```json
{
  "mcpServers": {
    "jshook": {
      "command": "npx",
      "args": ["-y", "@jshookmcp/jshook@0.3.4"],
      "env": {
        "JSHOOK_BASE_PROFILE": "search"
      }
    }
  }
}
```

## Bootstrap capabilities and refresh tool index

From the repository root, list all bootstrap capabilities:

```bash
bash skills/scripts/bootstrap-reverse.sh --list
```

Install/configure capabilities with the same core names as the Windows version:

```bash
bash skills/scripts/bootstrap-reverse.sh jadx apktool frida
bash skills/scripts/bootstrap-reverse.sh jshookmcp anything-analyzer
bash skills/scripts/bootstrap-reverse.sh idapro --start-services
```

Refresh the tool index only:

```bash
bash skills/scripts/bootstrap-reverse.sh --list
bash skills/scripts/refresh-tool-index.sh
```

This generates:

```text
skills/tool-index.md
skills/tool-index.json
```

The bootstrap script installs or configures supported capabilities where possible using the same core capability names as Windows. The refresh script detects common Linux/macOS tools and records install hints. Manual-only tools such as IDA Pro and BurpSuite still require local installation and app-specific setup.

## Validation checklist

```bash
java -version
python3 --version
node -v
npm -v
npx -v
jadx --version || true
apktool --version || true
adb version || true
frida --version || true
r2 -v || true
ghidraRun 2>/dev/null || true
bash skills/scripts/refresh-tool-index.sh
```

## When to use Kali docs instead

Use [`../../kali/README-kali.md`](../../kali/README-kali.md) when:

- the host is actually Kali;
- you want Kali-native security tooling and MCP integrations;
- you need Metasploit, NetExec, responder, BloodHound, Certipy, HexStrike, or other offensive-security distributions pre-wired.

For Ubuntu / Debian, keep this generic Linux guide as the default and only borrow Kali scripts when the tool is known to exist on your system.
