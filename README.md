<p align="center">
  <img src="reverse-skill.png" alt="reverse-skill" width="140" />
</p>

<h1 align="center">reverse-skill</h1>
<h3 align="center">Cybersecurity Skills Router · 逆向技能路由包</h3>

<p align="center"><em style="font-family: Georgia, serif; font-size: 1.2em; color: #777;">Navigate the dark waters, sail against the stream.</em></p>

<p align="center">
  <a href="https://github.com/zhaoxuya520/reverse-skill/releases/tag/v1.0.0"><img src="https://img.shields.io/badge/release-v1.0.0-blue" alt="release"></a>
  <a href="https://github.com/zhaoxuya520/reverse-skill/stargazers"><img src="https://img.shields.io/github/stars/zhaoxuya520/reverse-skill?style=flat&logo=github" alt="stars"></a>
  <a href="https://github.com/zhaoxuya520/reverse-skill/forks"><img src="https://img.shields.io/github/forks/zhaoxuya520/reverse-skill?style=flat&logo=github" alt="forks"></a>
  <a href="https://github.com/zhaoxuya520/reverse-skill/issues"><img src="https://img.shields.io/github/issues/zhaoxuya520/reverse-skill?style=flat&logo=github" alt="issues"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="license"></a>
  <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/changelog-Keep%20a%20Changelog-orange" alt="changelog"></a>
  <a href="https://skills.sh/zhaoxuya520/reverse-skill"><img src="https://skills.sh/b/zhaoxuya520/reverse-skill" alt="skills.sh"></a>
</p>

<p align="center">
  <a href="https://trendshift.io/repositories/43969?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-43969" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/43969/daily" alt="zhaoxuya520%2Freverse-skill | Trendshift" width="250" height="55"/></a>
</p>

<br/>

<p align="center">
  <a href="#about">About</a> ·
  <a href="#getting-started">Getting Started</a> ·
  <a href="#usage">Usage</a> ·
  <a href="skills/MASTER-ROUTING.md">Fast route</a> ·
  <a href="skills/routing.md">Routing</a> ·
  <a href="skills/ops/">Ops contracts</a> ·
  <a href="README_AI.md">AI Bootstrap</a> ·
  <a href="#sponsors">Sponsors</a> ·
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  🌐 <a href="README_zh.md">中文</a>
</p>

<br/>

<a id="about"></a>

## About

> **If you are an AI Agent, jump to [README_AI.md](README_AI.md) and follow the instructions strictly.**

When an AI agent (Claude Code, Codex CLI, Cursor, etc.) encounters an APK, a binary, frontend JS encryption, a CTF challenge, or a pentesting target, this package routes it to the right methodology, checks available tools, and executes a repeatable workflow instead of guessing commands.

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

PRIMARY ladder: [skills/MASTER-ROUTING.md](skills/MASTER-ROUTING.md) · Full matrix: [skills/routing.md](skills/routing.md) · Ops: [skills/ops/](skills/ops/)

### 30-second proof (real run, not a mock)

One sentence in → correct PRIMARY skill + ready case directory:

<p align="center">
  <img src="docs/assets/primary-path-demo.gif" alt="PRIMARY path demo GIF" width="720" />
</p>

```bash
bash skills/scripts/demo-primary-path.sh
bash skills/scripts/record-primary-path-demo.sh   # regenerate GIF (Pillow; or vhs if installed)
# → examples/primary-path-demo/  + docs/assets/primary-path-demo.gif
```

| Live sample | PRIMARY |
|-------------|---------|
| APK / jadx / cert pinning | **R1** `apk-reverse` |
| JS signature / webpack | **R3** `js-reverse` |
| LLM prompt injection | **R14** `llm-security` |
| radare2 ELF triage | **R7** `radare2` |
| offline local APK + `case-guard` | **ready_for_act=true** |

Artifacts from the last committed demo run: [examples/primary-path-demo/RESULT-CARD.md](examples/primary-path-demo/RESULT-CARD.md) · [result-card.html](examples/primary-path-demo/result-card.html)

<br/>

<div align="center">
  <a href="https://star-history.com/#zhaoxuya520/reverse-skill&Date">
    <img src="docs/assets/star-history.svg" alt="Star History" width="650" />
  </a>
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
- **A code AI client** — Claude Code, Codex CLI, Cursor, etc.

### Installation

**One-line agent install** (skills into Claude Code / Codex / compatible agents):

```bash
npx skills add zhaoxuya520/reverse-skill
```

[skills.sh catalog](https://skills.sh/zhaoxuya520/reverse-skill) · list without install: `npx skills add zhaoxuya520/reverse-skill -l`

**After install, tell the agent (copy-paste):**

```text
Read README_AI.md and RULES.md first. You are the reverse-skill router: PRIMARY route → scope/auth gate → specialist skill. For a dry run, execute: bash skills/scripts/demo-primary-path.sh. For a real authorized offline APK: bash skills/scripts/case-init.sh --hint "apk reverse" --preset offline-sample --sample ./app.apk. Do not ACT on any live target until scope says ready_for_act=true.
```

**Claude Code plugin marketplace** (dual channel; after this lands on default branch):

```text
/plugin marketplace add zhaoxuya520/reverse-skill
```

Manifest: [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) (router pack entry — not “800 micro-skills”).

**Full toolchain still needs a clone.** `npx skills add` ships agent skill files; scripts (`master-route`, `case-init`, `bootstrap`, tool-index refresh), Kali helpers, and local `work/` cases live in the git tree:

```bash
git clone https://github.com/zhaoxuya520/reverse-skill.git
cd reverse-skill
```

Then refresh the tool index per platform:

| Platform | Command |
|----------|---------|
| Windows | `powershell -File skills/scripts/refresh-tool-index.ps1` |
| Linux / macOS | `bash skills/scripts/refresh-tool-index.sh` |
| Kali Linux | `bash kali/scripts/refresh-tool-index.sh` |

PRIMARY path (route → case scope → smoke), also per platform:

| Platform | Route | Case init | Verify / smoke |
|----------|-------|-----------|----------------|
| Windows | `powershell -File skills/scripts/master-route.ps1 -Hint "<task>"` | `powershell -File skills/scripts/case-init.ps1 -Hint "<task>"` | `powershell -File skills/scripts/smoke.ps1` |
| Linux / macOS / Kali | `bash skills/scripts/master-route.sh --hint "<task>"` | `bash skills/scripts/case-init.sh --hint "<task>"` | `bash skills/scripts/smoke.sh` |

Authorized local/CTF work without fighting the auth gate:

```bash
# own APK / binary on disk (offline static analysis)
bash skills/scripts/case-init.sh --hint "apk reverse" --preset offline-sample --sample ./app.apk

# public CTF target
bash skills/scripts/case-init.sh --hint "ctf web" --preset ctf-public --target-url https://chal.example
```

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
| HTTP capture / request replay | anything-analyzer + `js-reverse/` |
| Malware / YARA | `skills/malware-analysis/` |
| Penetration testing / scanning | `skills/pentest-tools/` |
| Attack chain / red-team orchestration | `skills/attack-chain/` |
| CTF competition | `CTF-Sandbox-Orchestrator/` (40+ sub-skills) |
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
| [skills/tool-index.md](skills/tool-index.md) | Local tool status (auto-generated) |
| [skills/scripts/master-route.ps1](skills/scripts/master-route.ps1) | One-shot PRIMARY triage |
| [skills/scripts/case-init.ps1](skills/scripts/case-init.ps1) | Case dir: scope / timeline / workitems |
| [skills/ops/](skills/ops/) | Scope, Evidence chain, roles, timeline (skill-router form) |

### Repository layout

```
.
├── .claude-plugin/marketplace.json   # Claude Code marketplace dual channel
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

For sponsorship or business inquiries:

<p align="center">
  <a href="mailto:24781737@qq.com?subject=%5BSponsorship%5D%20reverse-skill">
    <img src="https://img.shields.io/badge/Email%20us-24781737%40qq.com-0A66C2?style=for-the-badge&logo=maildotru&logoColor=white" alt="Email us — 24781737@qq.com" />
  </a>
</p>

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

- **Email:** [24781737@qq.com](mailto:24781737@qq.com)
- **Telegram:** [t.me/AI_And_Security](https://t.me/+uf7-Ji6R-RQxZTUy)
- **X (Twitter):** [@apivixtls](https://x.com/apivixtls)
