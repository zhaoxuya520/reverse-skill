<p align="center">
  <img src="reverse-skill.png" alt="reverse-skill" width="140" />
</p>

<h1 align="center">reverse-skill</h1>
<h3 align="center">Cybersecurity Skills Router · 逆向技能路由包</h3>

<p align="center"><em style="font-family: Georgia, serif; font-size: 1.2em; color: #777;">Navigate the dark waters, sail against the stream.</em></p>

<p align="center">
  <a href="https://github.com/zhaoxuya520/reverse-skill/releases"><img src="https://img.shields.io/badge/release-v1.0.1-blue" alt="release v1.0.1"></a>
  <a href="https://github.com/zhaoxuya520/reverse-skill/stargazers"><img src="https://img.shields.io/github/stars/zhaoxuya520/reverse-skill?style=flat&logo=github" alt="stars"></a>
  <a href="https://github.com/zhaoxuya520/reverse-skill/forks"><img src="https://img.shields.io/github/forks/zhaoxuya520/reverse-skill?style=flat&logo=github" alt="forks"></a>
  <a href="https://github.com/zhaoxuya520/reverse-skill/issues"><img src="https://img.shields.io/github/issues/zhaoxuya520/reverse-skill?style=flat&logo=github" alt="issues"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="license"></a>
  <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/changelog-Keep%20a%20Changelog-orange" alt="changelog"></a>
</p>

<p align="center">
<a href="https://trendshift.io/repositories/43969?utm_source=repository-badge&amp;utm_medium=badge&amp;utm_campaign=badge-repository-43969" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/repositories/43969" alt="zhaoxuya520%2Freverse-skill | Trendshift" width="250" height="55"/></a>
  <a href="https://trendshift.io/repositories/43969?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-43969" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/43969/daily" alt="zhaoxuya520%2Freverse-skill | Trendshift" width="250" height="55"/></a>
</p>

<br/>
<p align="center">
  <a href="#about">About</a> ·
  <a href="#getting-started">Getting Started</a> ·
  <a href="#usage">Usage</a> ·
  <a href="https://reverse.apivix.com/docs/">Tutorial</a> ·
  <a href="skills/MASTER-ROUTING.md">Fast route</a> ·
  <a href="skills/routing.md">Routing</a> ·
  <a href="skills/ops/">Ops contracts</a> ·
  <a href="README_AI.md">AI Bootstrap</a> ·
  <a href="#sponsors">Sponsors</a> ·
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  🌐 <a href="README_zh.md">中文</a> ·
  <a href="https://reverse.apivix.com/">Project website</a> ·
  <a href="https://reverse.apivix.com/docs/">Online tutorial</a>
</p>

<br/>

<a id="about"></a>

## About

> **If you are an AI Agent, jump to [README_AI.md](README_AI.md) and follow the instructions strictly.**

When an AI agent (Claude Code, Codex, Cursor, OpenCode, or another compatible client) encounters an APK, a binary, frontend JS encryption, a CTF challenge, or a pentesting target, this package routes it to the right methodology, checks available tools, and executes a repeatable workflow instead of guessing commands.

```
User task
  → RULES.md
  → MASTER-ROUTING / master-route.ps1 (PRIMARY)
  → case-init / scope.md (auth + network_profile; no target ACT until ready)
  → Scenario skill → tools / MCP / scripts
  → timeline + Evidence→Finding→Path → report + field-journal
```

**Why this exists:**
- AI agents don't know whether to use jadx, apktool, Frida, IDA, or BurpSuite for a given task
- APK, ELF, JS, PCAP, and CTF tasks each need different playbooks
- Tools, MCP servers, and scripts are scattered across machines
- The same mistakes get repeated because experience isn't reused

### Current status

| Routing rules | Regression benchmark | Core skill modules | CI platforms | Client model |
|---:|---:|---:|---|---|
| 44 (R0–R44; R42 unused ADF) | 181 cases | 45 tracked modules | Windows + Ubuntu | Client-neutral |

The routing core is driven by one structured configuration, validated by cross-platform CI, and kept separate from optional client adapters.

PRIMARY ladder: [skills/MASTER-ROUTING.md](skills/MASTER-ROUTING.md) · Full matrix: [skills/routing.md](skills/routing.md) · Ops: [skills/ops/](skills/ops/)

<br/>

<div align="center">
  <a href="https://afterglow.watch"><img src="https://afterglow.watch/badge/zhaoxuya520/reverse-skill" alt="star velocity"></a>
</div>

<br/>

<p align="right">(<a href="#about">back to top</a>)</p>

### Built With

<p align="left">
  <img src="https://skillicons.dev/icons?i=py,nodejs,powershell,bash,java,docker,git&theme=light" /><br/>
  <code>IDA Pro</code> · <code>radare2</code> · <code>Ghidra</code>
</p>

<p align="right">(<a href="#about">back to top</a>)</p>

<a id="getting-started"></a>

## Getting Started

### Prerequisites

- **Java / JDK** — for jadx and apktool
- **Node.js 22.12+** — for JS toolchain and MCP servers
- **Python 3.x** — for Frida and helper scripts
- **A code AI client** — Claude Code, Codex, Cursor, OpenCode, or another compatible client

### Installation

```
git clone https://github.com/zhaoxuya520/reverse-skill.git
```

Then refresh the tool index per platform:

| Platform | Command |
|----------|---------|
| Windows | `powershell -File skills/scripts/refresh-tool-index.ps1` |
| Linux / macOS | `bash skills/scripts/refresh-tool-index.sh` |
| Kali Linux | `bash kali/scripts/refresh-tool-index.sh` |

Check [skills/tool-index.md](skills/tool-index.md) to see detected tools.

Platform-specific docs:
- **Kali Linux** → [kali/README-kali.md](kali/README-kali.md)
- **Ubuntu/Debian** → [docs/platforms/linux.md](docs/platforms/linux.md)
- **macOS** → [docs/platforms/macos.md](docs/platforms/macos.md)

<p align="right">(<a href="#getting-started">back to top</a>)</p>

<a id="usage"></a>

## Usage

### Supported scenarios

| Scenario | Entry |
|----------|-------|
| APK / Android analysis | `skills/apk-reverse/` |
| iOS / mobile | `skills/mobile-reverse/` |
| Binary reverse (exe/dll/so/elf) | `skills/ida-reverse/` / `skills/radare2/` |
| .NET / C# | `skills/dotnet-reverse/` |
| Frontend JS / encrypted params | `skills/js-reverse/` |
| DSL VM / custom JS opcode VM | `skills/reverse-engineering/dsl-vm-reverse/` |
| HTTP capture / request replay | anything-analyzer, Reqable MCP + `js-reverse/` |
| Malware / YARA | `skills/malware-analysis/` |
| Penetration testing / scanning | `skills/pentest-tools/` |
| Attack chain / red-team orchestration | `skills/attack-chain/` |
| Case evidence review / report handoff | `skills/case-review/` |
| CTF competition | `CTF-Sandbox-Orchestrator/` (42 sub-skills) |
| Firmware / IoT | `skills/firmware-pentest/` |
| Patch diff / N-day | `skills/patch-diff-exploit/` |
| Pwn / exploit development | `skills/pwn-chain/` |
| EDR bypass | `skills/edr-bypass-re/` |
| API / GraphQL | `skills/api-security/` |
| Supply chain / SBOM | `skills/supply-chain-security/` |
| LLM / AI security | `skills/llm-security/` |
| OLLVM deobfuscation | `skills/reverse-engineering/references/ollvm-deobfuscation.md` |
| Diagrams / reports | `skills/diagram-generator/` / `skills/docs-generator/` |

### Key files

| File | Purpose |
|------|---------|
| [README_AI.md](README_AI.md) | AI agent bootstrap and configuration |
| [RULES.md](RULES.md) | Global routing rules (scope gate before ACT) |
| [skills/MASTER-ROUTING.md](skills/MASTER-ROUTING.md) | PRIMARY fast ladder |
| [skills/routing.md](skills/routing.md) | Task → skill routing matrix |
| [skills/SKILL.md](skills/SKILL.md) | Master entry point |
| [skills/INDEX.md](skills/INDEX.md) | Auto-generated, client-neutral skill navigation index |
| [skills/config/routing.json](skills/config/routing.json) | **Routing single source of truth** (44 rules, R0–R44; R43 game-security, R44 threat-intel, R42 unused ADF) |
| [skills/tool-index.md](skills/tool-index.md) | Local tool status (auto-generated) |
| [skills/scripts/master-route.ps1](skills/scripts/master-route.ps1) | One-shot PRIMARY triage (reads routing.json) |
| [skills/scripts/case-init.ps1](skills/scripts/case-init.ps1) | Case dir: scope / timeline / workitems |
| [skills/case-review/](skills/case-review/) | Read-only Evidence graph review and artifact fixity checks |
| [skills/scripts/test-routing.ps1](skills/scripts/test-routing.ps1) | Routing regression runner (181 benchmark cases) |
| [skills/scripts/verify-routing-coherence.ps1](skills/scripts/verify-routing-coherence.ps1) | Structure + supply-chain pin gate checks |
| [skills/scripts/extract-summaries.ps1](skills/scripts/extract-summaries.ps1) | Regenerates INDEX.md from skill frontmatter |
| [AGENTS.md](AGENTS.md) | Platform-neutral repository instructions |
| [skills/ops/](skills/ops/) | Scope, Evidence chain, roles, timeline (skill-router form) |

### Testing (run after any routing/config change)

```powershell
# 1. Routing regression — 181 (hint → expected PRIMARY) cases, fails CI on any mismatch
powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/test-routing.ps1
# 2. Structure coherence + supply-chain pin gate (unpinned auto-install fails)
powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/verify-routing-coherence.ps1
# 3. Smoke: verify + script parse + quick route matrix
powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/smoke.ps1
# 4. INDEX.md drift check (regenerate with extract-summaries.ps1 if dirty)
powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/extract-summaries.ps1 -Check
```

GitHub Actions CI runs all of the above on **Windows + Ubuntu** for every push/PR.

### Client-neutral integration

The routing core, regression suite, manifests, and case workflow do not depend on a specific AI client. Claude Code, Codex, Cursor, OpenCode, and other clients should load the repository through their own adapter or project-instruction mechanism. Client-specific configuration must remain optional and outside the core routing contract.

### Repository layout

```
.
├── README.md / README_zh.md / README_AI.md
├── RULES.md / RULES_zh.md
├── skills/
│   ├── MASTER-ROUTING.md / SKILL.md / routing.md
│   ├── ops/                   # ops contracts
│   ├── scripts/               # master-route, case-init, bootstrap, verify
│   ├── field-journal/
│   ├── apk-reverse/ mobile-reverse/ js-reverse/ dotnet-reverse/
│   ├── ida-reverse/ radare2/ reverse-engineering/ malware-analysis/
│   ├── pentest-tools/ attack-chain/ pwn-chain/ firmware-pentest/
│   ├── api-security/ supply-chain-security/ llm-security/
│   └── ...
├── CTF-Sandbox-Orchestrator/
├── docs/
├── kali/                      # see kali/README-kali.md
└── work/                      # local cases (gitignored)
```

<p align="right">(<a href="#usage">back to top</a>)</p>

<a id="sponsors"></a>

## Sponsors

<table>
  <tr>
    <td align="center" width="220">
      <a href="https://www.atlascloud.ai/?ref=W3Q77C">
        <img src="docs/assets/sponsors/atlas-cloud.svg" alt="Atlas Cloud" width="190" />
      </a>
      <br />
      <a href="https://www.atlascloud.ai/oss-program">
        <img src="https://www.atlascloud.ai/oss-program/powered-by-atlas-cloud.svg" alt="Powered by Atlas Cloud" height="24" />
      </a>
    </td>
    <td>
      <strong><a href="https://www.atlascloud.ai/?ref=W3Q77C">Atlas Cloud</a></strong> is a full-modal AI inference platform that provides unified API access to 400+ curated image, video, audio, 3D, and language models. Atlas Cloud supports reverse-skill with model services for cross-platform routing verification, documentation, and open security workflows.
    </td>
  </tr>
  <tr>
    <td align="center" width="220">
      <a href="https://gokite.ai/">
        <img src="https://gokite.ai/images/Kite_Logo.svg" alt="Kite AI" width="150" />
      </a>
    </td>
    <td>
      <strong><a href="https://gokite.ai/">Kite AI</a></strong> builds identity and payment infrastructure for the agent economy. Its support helps sustain reverse-skill's open-source maintenance, routing benchmarks, and platform-neutral security workflows.
    </td>
  </tr>
</table>

<p align="right">(<a href="#sponsors">back to top</a>)</p>

<a id="contributing"></a>

## Contributing

Contributions are welcome! Fork the repo, create a feature branch, and open a PR.

1. Fork the Project
2. `git checkout -b feature/AmazingFeature`
3. `git commit -m 'Add some AmazingFeature'`
4. `git push origin feature/AmazingFeature`
5. Open a Pull Request

### Contributors

<a href="https://github.com/zhaoxuya520/reverse-skill/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=zhaoxuya520/reverse-skill" alt="contributors" />
</a>

<p align="right">(<a href="#contributing">back to top</a>)</p>

<a id="license"></a>

## License

This project (`reverse-skill`) is primarily licensed under the **MIT License** (see [LICENSE](LICENSE)).

**Submodule and third-party dependencies:**
- **CTF-Sandbox-Orchestrator/**: **GNU GPLv3**
- **Pentest Swarm AI**: Original project is **AGPL-3.0**. This repo only invokes it via CLI or MCP and does not include its source code
- Other tools (jadx, frida, nmap, burpsuite-mcp, etc.) are subject to their respective official licenses

<p align="right">(<a href="#license">back to top</a>)</p>

<a id="acknowledgments"></a>

## Acknowledgments

Thanks to all open-source tool authors. This project integrates tools across reverse engineering, penetration testing, CTF, and security analysis — every tool is the fruit of community effort.

Special thanks to the OLLVM deobfuscation ecosystem contributors and everyone who submitted test samples, issues, and PRs.

<p align="right">(<a href="#acknowledgments">back to top</a>)</p>

## Contact

- **Email:** [ww7517437@gmail.com](mailto:ww7517437@gmail.com)
- **Issues:** [GitHub Issues](https://github.com/zhaoxuya520/reverse-skill/issues)

## Disclaimer

This project is intended solely for lawful security research, education, CTF competitions, and testing of systems that you own or have explicit authorization to assess.

**Unauthorized access, scanning, exploitation, disruption, data acquisition, or any other use against systems without prior permission is strictly prohibited.** Users are solely responsible for complying with applicable laws, regulations, and the authorized scope of testing. The maintainers accept no liability for misuse of this project or for any resulting damage or legal consequences

## Installation and download security

See [Installation and Download Security Guidance](docs/UV-AND-DOWNLOAD-SECURITY.md).

## Community quick start and issue triage

See [Quick Start](docs/QUICKSTART_zh.md) and [Community Issue Triage](docs/COMMUNITY-ISSUE-TRIAGE.md) for installation, client integration, and how community issues are classified. Installation/archive security details remain in [Installation and Download Security Guidance](docs/UV-AND-DOWNLOAD-SECURITY.md).
