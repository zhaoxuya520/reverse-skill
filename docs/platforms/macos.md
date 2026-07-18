# macOS Setup

This guide covers macOS users who want to use Cybersecurity Skills Router with Claude Code, Codex CLI, Cursor, Cline, Windsurf, Kiro, or another Agent client.

## Positioning

The core Skill layer is platform-agnostic. On macOS, the main differences are:

- package manager: Homebrew is preferred;
- Python tools: use `pipx` or venv rather than global `pip`;
- GUI apps: BurpSuite, IDA Pro, and Ghidra may live under `/Applications`;
- Android tooling: `android-platform-tools` is available through Homebrew;
- some Linux security tools may need GitHub releases, Go, or manual setup.

## Quick setup baseline

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install \
  git curl wget jq unzip gnu-tar \
  python node openjdk \
  jadx apktool android-platform-tools \
  radare2 graphviz plantuml \
  nmap sqlmap ffuf hashcat binwalk

python3 -m pip install --user pipx
python3 -m pipx ensurepath
```

> Homebrew package names can change over time. If a formula is missing, use the alternative path in the tool matrix below.

## Tool installation matrix

| Capability | Preferred macOS setup | Alternative | Notes |
|---|---|---|---|
| Java / JDK | `brew install openjdk` | Temurin / vendor JDK | Required by jadx, apktool, BurpSuite, Ghidra. |
| Node.js | `brew install node` | `nvm` | Required by MCP bridges and JS tools. |
| Python tools | `pipx install <tool>` | venv | Avoid polluting global Python. |
| jadx | `brew install jadx` | GitHub release ZIP | Provides `jadx` and `jadx-gui`. |
| apktool | `brew install apktool` | official jar + wrapper | Java required. |
| adb | `brew install android-platform-tools` | Android Studio SDK | Provides `adb`. |
| Frida | `pipx install frida-tools` | venv + `pip install frida-tools` | Provides `frida`, `frida-ps`, `frida-trace`. |
| radare2 | `brew install radare2` | GitHub release / source | CLI reverse-engineering. |
| Ghidra | `brew install ghidra` or `brew install --cask ghidra` | GitHub release ZIP | Formula/cask availability may vary. |
| IDA Pro | manual app install | — | Usually under `/Applications/IDA Professional*.app`. |
| BurpSuite | `brew install --cask burp-suite` | manual jar / installer | Load `burp-mcp-full` extension manually. |
| jshookmcp | `npx -y @jshookmcp/jshook@0.3.4` | MCP config command | Requires Node/npm/npx. |
| anything-analyzer | project clone + `pnpm install` | custom local service | Register its MCP endpoint. |
| nuclei | `brew install nuclei` | GitHub release / Go install | Optional security scanner. |
| SecLists | Git clone | — | Usually clone to `~/tools/SecLists`. |

## Recommended path layout

```text
~/tools/
├── SecLists/
├── anything-analyzer/
└── custom-releases/

/Applications/
├── Burp Suite*.app
├── IDA Professional*.app
└── Ghidra*.app

/opt/homebrew/bin/        # Apple Silicon Homebrew
/usr/local/bin/           # Intel Homebrew
~/.local/bin/             # pipx / user scripts
```

## Installing common tools

### Frida via pipx

```bash
pipx install frida-tools
frida --version
frida-ps --version
```

### SecLists

```bash
mkdir -p ~/tools
git clone https://github.com/danielmiessler/SecLists ~/tools/SecLists
```

### anything-analyzer

```bash
mkdir -p ~/tools
git clone https://github.com/Mouseww/anything-analyzer ~/tools/anything-analyzer
cd ~/tools/anything-analyzer
corepack enable
pnpm install
pnpm dev
```

If the service uses a custom port or token, update your Agent client's MCP configuration accordingly.

## MCP setup notes

### BurpSuite MCP

Build the extension:

```bash
cd burp-mcp-full
chmod +x build.sh
./build.sh
```

Load the generated jar in BurpSuite:

```text
Burp Suite → Extensions → Add → Java → build/libs/burp-mcp-full.jar
```

MCP stdio bridge:

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

### IDA Pro

IDA Pro is commercial and must be installed manually. Common locations:

```text
/Applications/IDA Professional.app
/Applications/IDA Free.app
/Applications/IDA Pro *.app
```

If you use IDA MCP, document the actual app path in your client rules or local environment. Do not hard-code another user's path.

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

From the repository root, list the same core capability names as the Windows PowerShell bootstrap:

```bash
bash skills/scripts/bootstrap-reverse.sh --list
```

Install or configure supported capabilities with the generic Bash bootstrap:

```bash
bash skills/scripts/bootstrap-reverse.sh jadx apktool frida
bash skills/scripts/bootstrap-reverse.sh jshookmcp anything-analyzer
bash skills/scripts/bootstrap-reverse.sh burpsuite-mcp
```

Refresh the local tool index only:

```bash
bash skills/scripts/refresh-tool-index.sh
```

This writes:

```text
skills/tool-index.md
skills/tool-index.json
```

`bootstrap-reverse.sh` installs/configures supported capabilities where possible on macOS, using Homebrew, `pipx`, `npm`, GitHub releases, and MCP registration. `refresh-tool-index.sh` is detection-only. Manual-only tools such as IDA Pro and BurpSuite still require local app installation and app-specific setup.

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
brew list --formula | grep -E 'jadx|apktool|radare2|graphviz|plantuml' || true
bash skills/scripts/refresh-tool-index.sh
```

## macOS caveats

- GUI app paths vary by edition and version. Do not hard-code IDA or Burp paths unless you verified them locally.
- Some security tools are Linux-first. Prefer Homebrew formulae first, then GitHub releases, then source builds.
- iOS analysis may require additional signing, device, and jailbreak-specific setup; keep those steps in a dedicated mobile reverse Skill rather than this generic platform page.
