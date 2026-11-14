# Platform Support

This project uses a layered platform model:

1. **Core knowledge layer**: `skills/`, `RULES.md`, `routing.md`, and `CTF-Sandbox-Orchestrator/`. This layer is platform-agnostic.
2. **Execution layer**: scripts, local tools, MCP servers, and path conventions. This layer is platform-specific.
3. **Client layer**: Claude Code, Codex CLI, Cursor, Cline, Windsurf, Kiro, or any Agent client that can load rules and call tools.

## Support matrix

| Platform | Status | Primary entry | Notes |
|---|---|---|---|
| Windows | Full primary path | `README.md`, PowerShell scripts | Original mainline. Uses `.ps1`, Windows paths, `winget` / GitHub release ZIPs. |
| Kali Linux | Full specialized path | `kali/README-kali.md` | Dedicated Kali layer with `apt`, bash scripts, and Kali-native security tooling. |
| Ubuntu / Debian Linux | Supported generic path | `docs/platforms/linux.md`, `skills/scripts/bootstrap-reverse.sh`, `skills/scripts/refresh-tool-index.sh` | Uses `apt`, `pipx` / venv, `npm`, GitHub releases, and optional Kali scripts as reference. |
| macOS | Supported generic path | `docs/platforms/macos.md`, `skills/scripts/bootstrap-reverse.sh`, `skills/scripts/refresh-tool-index.sh` | Uses Homebrew, `pipx` / venv, `npm`, app bundle paths, and manual IDA / Burp setup. |

## What is shared across platforms

The following are not tied to a platform:

- `RULES.md`
- `skills/SKILL.md`
- `skills/routing.md`
- most `SKILL.md` methodology files
- `CTF-Sandbox-Orchestrator/`
- MCP concepts and JSON configuration shape
- `burp-mcp-full/mcp-bridge.js`
- Java source under `burp-mcp-full/`

## What is platform-specific

The following must be adapted per OS:

- tool installation commands;
- executable names and paths;
- script language (`.ps1` vs `.sh`);
- package managers (`winget`, `apt`, `brew`, `pipx`, `npm`);
- desktop app locations such as IDA Pro and BurpSuite;
- Android SDK / platform-tools paths;
- MCP config file locations for each Agent client.

## Tool coverage by platform

> **Capability-name honesty:** `skills/scripts/bootstrap-manifest.json` is the generic (non-Kali) source of truth (26 capabilities). Names such as `sqlmap`, `nuclei`, `ffuf`, `hashcat`, `msfconsole`, and `gobuster` exist only in `kali/scripts/bootstrap-manifest.json` — do not expect `skills/scripts/bootstrap-reverse.sh --list` to offer them on Ubuntu/macOS.

| Capability | Windows | Kali Linux | Ubuntu / Debian | macOS | Notes |
|---|---|---|---|---|---|
| Java / JDK | Installer / winget | `apt` | `apt` | `brew` | Required by jadx, apktool, Burp. |
| Node.js / npm / npx | Installer / winget | `apt` / `nvm` | `apt` / NodeSource / `nvm` | `brew` / `nvm` | Required for MCP bridges and JS tooling. |
| Python | Installer | system Python + venv | system Python + venv | Homebrew Python + venv | Avoid global `pip` when PEP 668 is active. |
| jadx | GitHub release | `apt` or GitHub release | GitHub release preferred | `brew install jadx` | Ubuntu apt may not provide it. |
| apktool | release package | `apt` | `apt` or release jar | `brew install apktool` | Version can be old in apt. |
| adb | Android SDK | `apt` / platform-tools | `apt install adb` or platform-tools | `brew install android-platform-tools` | Use official platform-tools if distro package is old. |
| Frida | `pipx` / venv | `pipx` / venv | `pipx` / venv | `pipx` / venv | Package is usually `frida-tools`. |
| radare2 | release / installer | `apt` / GitHub release | GitHub release preferred | `brew install radare2` | Ubuntu 22.04 apt may not have a candidate. |
| Ghidra | manual / release | `apt` or release | GitHub release / Flatpak | `brew install --cask ghidra` or formula | Java required. |
| IDA Pro | manual app | manual Linux app | manual Linux app | manual app bundle | Commercial tool; scripts only wrap local installs. |
| BurpSuite | manual app | manual app / package | manual app | `brew install --cask burp-suite` | MCP extension still needs loading into Burp. |
| Graphviz | installer | `apt` | `apt` | `brew` | Used by diagram generation. |
| PlantUML | jar / package | `apt` | `apt` | `brew` | Optional diagram tool. |
| Nmap | installer | `apt` | `apt` | `brew` | Security testing. |
| sqlmap | Python / package | `apt` | `apt` / pipx | `brew` / pipx | Security testing. |
| ffuf | release | `apt` / release | `apt` / release | `brew` | Fuzzing. |
| hashcat | release | `apt` | `apt` | `brew` | GPU support differs by OS. |
| nuclei | release / go | package / release | GitHub release / go | `brew install nuclei` | Often absent in Ubuntu apt. |
| SecLists | Git clone | package / clone | Git clone | Git clone | Path convention differs by OS. |

## Recommended routing for setup docs

- Windows users: start from `README.md`.
- Kali users: start from `kali/README-kali.md`.
- Ubuntu / Debian users: start from `docs/platforms/linux.md`.
- macOS users: start from `docs/platforms/macos.md`.
- Kali users should use `kali/scripts/bootstrap-reverse.sh` and `kali/scripts/refresh-tool-index.sh`. Generic Linux/macOS users should use `skills/scripts/bootstrap-reverse.sh` and `skills/scripts/refresh-tool-index.sh`.

## Linux/macOS bootstrap and tool index

For generic Linux/macOS, list supported bootstrap capabilities:

```bash
bash skills/scripts/bootstrap-reverse.sh --list
```

Install or configure capabilities with the same capability names as the Windows PowerShell version:

```bash
bash skills/scripts/bootstrap-reverse.sh jadx apktool frida
bash skills/scripts/bootstrap-reverse.sh jshookmcp anything-analyzer
bash skills/scripts/bootstrap-reverse.sh idapro --start-services
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

The generic Bash bootstrap uses the same core capability names as the Windows PowerShell version. Kali has a dedicated Bash bootstrap that covers those core names plus Kali-native extras. Refresh scripts only detect tools and suggest platform-appropriate installation commands. Use the platform guides for setup and manual-only tools.
