# Cybersecurity Skills Router Overview

> A workflow router and tool orchestration system for code Agents: classify the task, choose the right Skill, then call real tools to execute.

If this is your first time seeing this repository, start here. `README_AI.md` contains the AI Agent bootstrap entry with execution instructions.

## What is this?

Cybersecurity Skills Router is a **Skill Router + Tool Orchestration** system for code Agents such as Claude Code, Codex CLI, Cursor, Cline, Windsurf, and Kiro.

It helps an Agent handle APKs, binaries, frontend JavaScript, HTTP traffic, CTF challenges, firmware, and security-testing tasks through a repeatable workflow:

1. classify the target and user intent;
2. route to the right Skill and methodology;
3. check local tools, MCP servers, and script entry points;
4. call real tools to perform the analysis;
5. generate reports and write reusable experience back into the field journal.

In short:

> This is not a single-tool installer. It is a workflow operating system for making AI Agents execute security and reverse-engineering tasks with less guessing and more structure.

## Why does it exist?

General-purpose code Agents often struggle with security and reverse-engineering workflows:

- they do not know whether to use jadx, apktool, Frida, IDA, radare2, or BurpSuite;
- APK, ELF, JS, PCAP, and CTF tasks require different playbooks;
- tools, MCP servers, and local scripts are scattered across machines;
- the same mistakes get repeated because experience is not reused;
- the Agent may explain a lot while never entering the actual execution path.

This project turns that chaos into a clear execution chain:

```text
User task
  ↓
RULES.md
  ↓
Skill Router
  ↓
Scenario-specific Skill
  ↓
Tools / MCP / Scripts
  ↓
Report + field journal
```

## Core capabilities

| Capability | Description |
|---|---|
| Skill Router | Routes tasks by target type, user intent, and toolchain requirements. |
| Tool Orchestration | Connects jadx, apktool, Frida, radare2, IDA, BurpSuite, browsers, and scripts. |
| MCP Integration | Exposes BurpSuite, IDA, browser analysis, and other execution surfaces to Agents. |
| Bootstrap Scripts | Detects local tool status and guides automatic or manual setup. |
| Field Journal | Stores reusable lessons, commands, pitfalls, and patterns after tasks. |
| Report Generation | Produces analysis reports, diagrams, attack paths, and CTF writeups. |

## Platform support

| Platform | Status | Entry |
|---|---|---|
| Windows | Full primary path | `README.md`, PowerShell scripts |
| Kali Linux | Specialized support | `kali/README-kali.md` |
| Ubuntu / Debian Linux | Generic support | `platforms/linux.md`, `skills/scripts/bootstrap-reverse.sh`, `skills/scripts/refresh-tool-index.sh` |
| macOS | Generic support | `platforms/macos.md`, `skills/scripts/bootstrap-reverse.sh`, `skills/scripts/refresh-tool-index.sh` |

See [PLATFORMS.md](PLATFORMS.md) for the full platform matrix. Ordinary Linux and macOS users can list bootstrap capabilities with:

```bash
bash skills/scripts/bootstrap-reverse.sh --list
```

For index refresh only, run:

```bash
bash skills/scripts/refresh-tool-index.sh
```

## Supported Agent clients

- Claude Code
- Codex CLI
- Cursor
- Cline
- Windsurf
- Kiro
- Other code Agents that support project rules, system prompts, MCP, or external tools

The repository is not tied to one client. Its core assets are `RULES.md`, `skills/SKILL.md`, `skills/routing.md`, tool indexes, sub-skills, and MCP/script entry points.

## Supported scenarios

| Scenario | Main entry |
|---|---|
| APK / Android analysis | `skills/apk-reverse/`, `skills/mobile-reverse/` |
| Binary reverse engineering | `skills/ida-reverse/`, `skills/radare2/`, `skills/reverse-engineering/` |
| Frontend JS signing / parameter analysis | `skills/js-reverse/` |
| HTTP traffic / request replay | BurpSuite MCP, anything-analyzer, browser automation |
| CTF / security competitions | `CTF-Sandbox-Orchestrator/` |
| Firmware / IoT analysis | `skills/firmware-pentest/` |
| Patch diff / N-day analysis | `skills/patch-diff-exploit/` |
| Security-testing toolchain | `skills/pentest-tools/` |
| LLM / Agent security | `skills/llm-security/` |
| Reports and diagrams | `skills/docs-generator/`, `skills/diagram-generator/` |

## Example workflow

User request:

```text
Analyze the signature verification logic in this APK.
```

Expected Agent behavior:

1. identify the task as APK / Android / signature verification;
2. route to `apk-reverse`, and optionally pivot to Frida or native `.so` analysis;
3. check whether jadx, apktool, adb, and Frida are available;
4. unpack the APK and inspect Manifest, Java code, and native libraries;
5. decide whether static analysis is enough or dynamic hooks are needed;
6. report verification locations, call chains, bypass ideas, and validation steps;
7. generate a report and write reusable lessons into the field journal.

## Repository layout

```text
.
├── README.md                    # Main entry (English)
├── README_zh.md                 # Main entry (Chinese)
├── README_AI.md                 # AI Agent bootstrap entry (English)
├── RULES.md                     # Global routing and execution rules
├── docs/OVERVIEW.md              # Detailed overview (English)
├── docs/OVERVIEW_zh.md           # Detailed overview (Chinese)
├── docs/ARCHITECTURE.md          # Architecture notes
├── docs/PLATFORMS.md             # Platform support matrix
├── skills/                      # Main Skill directory
│   ├── SKILL.md                 # Controller entry
│   ├── routing.md               # Routing matrix
│   ├── field-journal/           # Experience journal
│   ├── apk-reverse/
│   ├── js-reverse/
│   ├── reverse-engineering/
│   ├── ida-reverse/
│   ├── radare2/
│   └── ...
├── CTF-Sandbox-Orchestrator/    # CTF scenario sub-skills
├── burp-mcp-full/               # BurpSuite MCP control module
└── kali/                        # Kali helper scripts
```

## Quick start

### For humans

1. Read this overview to understand the project;
2. read `README.md` and let your Agent run the bootstrap flow;
3. configure MCP, project rules, or system instructions for your client;
4. validate routing with a real task.

### For AI Agents

If you are an AI Agent, do not stop at this overview. Enter the execution path:

1. read `README_AI.md`;
2. execute section 0;
3. read `RULES.md`;
4. load `skills/SKILL.md` and `skills/routing.md`;
5. route first, then execute.

## How is this different from a prompt pack?

A prompt pack usually gives the model advice. This project emphasizes executable structure:

- clear entries: `RULES.md`, `SKILL.md`, `routing.md`;
- scenario routing: different targets enter different Skills;
- execution surfaces: MCP, scripts, and local toolchains;
- experience feedback: completed tasks update reusable knowledge;
- migration support: rescan tool indexes and recover the workflow on a new machine.

It is designed to make the Agent guess less, skip less, and execute more reliably.

## Security and responsible use

This project is intended for authorized security research, reverse engineering, CTFs, teaching labs, internal security testing, and defensive validation. Make sure you have permission to analyze or test the target system.

Rules in the bootstrap README are meant to reduce repeated confirmation loops and workflow stalling in authorized environments. They do not encourage unauthorized access, destructive operations, or attacks against real targets.

## Project positioning

A concise way to explain the project:

> I designed and open-sourced a Skill Router for code Agents that turns reverse-engineering, security-testing, and CTF tasks into routable, executable, and reusable workflows, with MCP/script integrations for local tools.

Keywords: AI Agent, Skill Router, Tool Orchestration, MCP, Workflow Automation, Security Analysis, Field Journal.

## Related documents

- [README.md](../README.md): Main entry (English)
- [README_zh.md](../README_zh.md): Main entry (Chinese)
- [README_AI.md](../README_AI.md): AI bootstrap entry
- [OVERVIEW_zh.md](OVERVIEW_zh.md): Chinese overview
- [PLATFORMS.md](PLATFORMS.md): platform support matrix
- [platforms/linux.md](platforms/linux.md): generic Linux setup
- [platforms/macos.md](platforms/macos.md): macOS setup
- [RULES.md](../RULES.md): global execution rules
- [ARCHITECTURE.md](ARCHITECTURE.md): architecture notes
- [skills/routing.md](../skills/routing.md): routing matrix
- [burp-mcp-full/README.md](../burp-mcp-full/README.md): BurpSuite MCP module

## License

MIT License. See [LICENSE](../LICENSE).

