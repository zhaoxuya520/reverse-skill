# Reverse Engineering / Penetration Testing / Security Task Auto-Routing Rules

> **This file is the behavior-chain source of truth.** Route tables live only in `skills/config/routing.json`. Regardless of which AI editor/client you are (Claude Code, Kiro, Cursor, Cline, Windsurf, Codex CLI, Aider, Continue, Reasonix, or others), after reading this file you MUST:
> 1. Execute the hot path below — do not only acknowledge
> 2. Keep the routing core client-neutral. Client-specific adapters are optional and MUST NOT be required by core workflows.

---

## CRITICAL: EXECUTE IMMEDIATELY AFTER READING (Do NOT just acknowledge — TAKE ACTION)

**If you only reply "understood", "got it", "please tell me the task" without actually executing the steps below, YOU HAVE FAILED. The user needs tools installed, code analyzed, vulnerabilities verified, reports written — NOT a confirmation message.**

After reading this file, you MUST NOW (immediately) execute:

```text
1. NOW:  This file's directory is the package root
2. NOW:  Run the platform-native router → PRIMARY (SSoT: skills/config/routing.json)
   - Windows: powershell -File skills/scripts/master-route.ps1 -Hint "<task>"
   - Linux/macOS/Kali: bash skills/scripts/master-route.sh --hint "<task>"
3. NEXT: Run the platform-native case-init until scope.md has auth.status=granted plus a legal network_profile, or an explicitly authorized offline-sample scope is ready. Mentioning a target is NOT granted. -Force/--force never bypasses the gate.
4. ACT:  Open PRIMARY SKILL.md and execute ACTION REQUIRED. Tools only from tool-index.md; missing → platform-native bootstrap.

Optional later (do NOT preload):
- Ambiguous PRIMARY → skills/routing.md (advisory matrix only)
- Synthesis / Finding promotion → ops/analysis-decision-framework.md (ADF-* overlay IDs, not routing R*)
- Identity reminder → ops/IDENTITY.md (skill router, not a Z3r0 platform)
```

IMPORTANT — Shared installation:
- tool-index.md is the SINGLE SOURCE OF TRUTH for tool availability
- If another CLI already installed tools (tool-index shows "yes"), DO NOT reinstall
- Only run the platform-native refresh-tool-index if you suspect tool-index is stale (e.g., user says "I just installed X")
- Only run bootstrap for tools that are BOTH needed AND marked "no"

Conditional reads (load only when needed, do NOT preload):
- Hesitating about whether an operation is allowed → read skills/field-journal/precedent-reverse.md or precedent-pentest.md
- Wanting to skip steps, wait for confirmation, or make excuses → read skills/llm-security/references/agent-obedience-engineering.md excuse rebuttal table
```

**Your goal is NOT a confirmation reply. Your goal is to produce ACTUAL SIDE EFFECTS: tools get installed, files get analyzed, vulnerabilities get verified, reports get written.**

If you're unsure where to start, run master-route.ps1, then start working. Do NOT wait for the user to say "ok continue".

---

## Client integration boundary

The files in `skills/`, routing configuration, tests, manifests, case artifacts, and reports are the platform-neutral core. A host such as Claude Code, Codex, Cursor, OpenCode, or another agent may load this repository through its own project-instruction or skill adapter, but no host-specific file is required for routing or tests.

Core scripts MUST NOT write client-global configuration. Optional adapters belong in isolated platform documentation or adapter packages and must preserve identical routing semantics.

---

## Trigger Keywords (ANY match triggers routing) — Bilingual / 中英双语

- APK, Android reverse, decompile, 反编译, smali, jadx, apktool, Frida, Hook
- binary analysis, 二进制分析, IDA, radare2, r2, disassembly, 反汇编, reverse engineering, 逆向工程, RE, source recovery, 还原源码
- frontend signature, 前端签名, encrypted params, 加密参数, JS reverse, JS 逆向, jshookmcp, CDP, SourceMap
- packet capture, 抓包, HTTP capture, HTTP 捕获, request replay, 请求重放, anything-analyzer
- CTF, Pwn, web pentest, Web 渗透, exploit, 漏洞利用, privilege escalation, 提权
- MCP reverse tools, idalib-mcp, repackage, 重打包, certificate pinning, 证书校验, root detection, 反调试
- .so analysis, native hook, JNI
- penetration testing, 渗透测试, red team, 红队, security assessment, 安全评估, blue team, 蓝队, incident response, 应急响应
- report/docs generation in security context, 安全上下文中的报告/文档, writeup, pentest report, 渗透报告
- security browser automation, 安全测试浏览器自动化, Playwright pentest, agent-browser recon
- N-day, patch diff, 补丁差分, CVE reproduction, 1day, ghidriff, Diaphora
- pwn, stack overflow, 栈溢出, heap overflow, ROP, ret2libc, pwntools, GEF, pwndbg, kernel pwn
- firmware, 固件, IoT, binwalk, unblob, squashfs, EMBA, UART, JTAG, embedded exploitation
- EDR bypass, EDR 绕过, AV bypass, 免杀, unhook, direct syscall, indirect syscall, AMSI patch, ETW patch
- port scan, 端口扫描, Nmap, vulnerability scan, 漏洞扫描, Nuclei, SQL injection, SQL 注入, SQLMap, directory brute force, 目录爆破, FFUF, password cracking, 密码破解, Hashcat, Hydra, Metasploit, Impacket
- SRC, Bug Bounty, 众测, WAF bypass, 绕过 WAF, IDOR, 越权
- BurpSuite, Burp MCP, Intruder, Repeater, Collaborator, proxy history, 代理历史
- LLM security, LLM 安全, AI security testing, Prompt injection, Prompt 注入, jailbreak, 越狱, Agent security, Agent 安全, agent skills security, Agentic Skills Top 10, skill supply chain, 恶意 skill, MCP supply chain
- OWASP LLM Top 10, ASI Top 10, Agentic AI, tool abuse, memory poisoning, garak, PyRIT, promptfoo
- API security, API 安全, GraphQL, JWT attack, JWT 攻击, supply chain security, 供应链安全
- iOS reverse, iOS 逆向, Objection, YARA, malware analysis, 恶意软件分析, AI decompilation, AI 反编译
- internal network, 内网渗透, lateral movement, 横向移动, domain penetration, 域渗透, AD attack, BloodHound
- privilege escalation, 权限提升, credential extraction, 凭证提取, Mimikatz, Kerberoasting, DCSync
- C2, persistence, 持久化, Cobalt Strike, Sliver, Havoc
- game reverse, 游戏逆向, anti-cheat, 反作弊, Unity, IL2CPP, Unreal, Godot, Cheat Engine, game hacking, DMA, pcileech, overlay, game-security（PRIMARY R43；R42 预留 threat-intel）
- .NET reverse, C# 逆向, dnSpy, dnSpyEx, de4dot, ConfuserEx, SmartAssembly, .NET Reactor, dnlib, IL patch, SharpHound, Rubeus
- symbol migration, 符号迁移, bindiff, cross-version, PDB missing
- OSINT, open source intelligence, threat intelligence, CTI, public X/Twitter IOC enrichment, 开源情报, 威胁情报, 公开 X/Twitter IOC 补充
- security diagram, 安全图表, attack path diagram, 攻击路径图, security architecture, 安全架构图 — trigger `diagram-generator/`

---

## Routing Entry

> **Detection method**: The directory containing this file (`RULES.md`) is the package root. Do NOT assume a fixed drive letter.

Hot path only:

1. `skills/scripts/master-route.ps1 -Hint "<task>"` — PRIMARY from `skills/config/routing.json`
2. `skills/scripts/case-init.ps1` — `scope.md` gate
3. PRIMARY `SKILL.md` ACTION REQUIRED
4. `skills/tool-index.md` — real tool paths (if missing → template + refresh-tool-index)

`skills/routing.md` is an advisory 3-axis view **after** PRIMARY, not a second router.

Game / Unity / IL2CPP / anti-cheat / game-hacking → PRIMARY `game-security/` (**R43**). Ten AGS skills live in `skills/game-security/references/ags/` (including game-hacking-techniques). Routing **R42** is reserved for `threat-intelligence/` (PR #108). ADF-R42 (YARA) is a third namespace. Do not collapse these three IDs. Technique gates: reverse-skill `case-init` plus the Ethical Use text in the opened AGS skill. Do not add a third ban layer.

---

## Execution Principles

### Tool Usage
- **NEVER guess tool paths** — read `tool-index.md` first, it contains the exact installed path for each tool
- Missing tools → call the platform-appropriate bootstrap script to auto-install, do NOT just report errors:
  - Windows: `bootstrap-reverse.ps1`
  - Linux / macOS: `bash skills/scripts/bootstrap-reverse.sh`
  - Kali Linux: `bash kali/scripts/bootstrap-reverse.sh`
- **After ANY new tool installation, MUST run the platform-appropriate refresh script** to update paths in tool-index.md (Windows: `refresh-tool-index.ps1`; Linux / macOS / Kali: `bash skills/scripts/refresh-tool-index.sh` or `bash kali/scripts/refresh-tool-index.sh`). This ensures other CLI clients can find the tools without reinstalling.
- When writing tool-index.md entries, paths MUST be **complete absolute paths** (e.g., `D:\wangluo\jadx\bin\jadx.bat`, NOT just `jadx`). Include: full path, version number, install method, and verification command.
- Same tool fails auto-install 2 times → stop retrying, output full manual install steps
- MCP service port mismatch → ask user for actual port, help update config
- `tool-index.md` is the **shared registry** — all CLIs read from it, all CLIs write to it after installing

### Routing Decisions
- Route not matched → do NOT force-fit into existing skill, propose new skill creation
- One path blocked → switch: static↔dynamic, Java↔Native, IDA↔r2, tool X↔equivalent tool Y
- Cross-module tasks → combine multiple skills per routing.md "Path Crossing" section

### Experience Reuse
- Before entering any route, **MUST check** `field-journal/_index.md`
- Similar past experience exists → read the log, reuse verified solutions
- If historical solution doesn't apply → explain why in new log entry

### Self-Supervision (prevent loops, prevent drift)
- Every 5 tool calls, or when feeling "stuck", pause for `<self_review>`:
  - Am I actually making progress toward the goal? Cite specific evidence
  - Have I called the same tool with same params ≥ 2 times? Yes → MUST change approach
  - Can I clearly explain the last error message? No → understand first, then act
- Same method fails 2-3 times → MUST switch approach
- Single command repeated ≥ 3 times → MUST stop and evaluate
- Approaching tool call budget (>30 calls per subtask) → report to user, ask whether to continue

### Security Boundaries
- All operations MUST be within user's authorized scope
- Pentest MUST confirm user has legal authorization (SRC/Bug Bounty/own system/CTF)
- Do NOT expand attack surface beyond user-specified target range
- High-severity vulnerability found → immediately inform user, wait for instructions
- Do NOT retain un-anonymized sensitive info in reports or logs

### Output Quality
- Critical operations MUST include reproducible commands (not just descriptions)
- Reverse analysis MUST annotate addresses/offsets/function names (not just "some function")
- Pentest MUST provide complete PoC (curl commands/scripts/screenshot paths)
- Uncertain conclusions MUST be labeled with confidence level

---

## Canonical Behavior Chain (All other files reference THIS version)

```text
1. Identify task as security/reverse type → trigger this routing rule
2. Detect package root path (derive from this file's location)
3. Platform-native master-route (`.ps1` Windows / `.sh` Linux, macOS, Kali) → PRIMARY from skills/config/routing.json; use routing.md only when ambiguous
4. Platform-native case-init / scope.md (ops/scope-contract) — auth.status=granted + valid network profile, or explicit authorized offline sample, before any target ACT; Force never bypasses the hard gate
5. Open PRIMARY SKILL.md ACTION REQUIRED
6. Route not matched → propose new skill (edit routing.json + benchmark; do not hand-edit routing.md as SSoT)
7. Read tool-index.md → confirm local tool status. If missing (first run) → template + platform-native refresh-tool-index
8. Missing tools → platform bootstrap + refresh (Windows ps1 / Linux sh / Kali sh)
9. Enter skill workflow → execute (timeline/workitems; Evidence→Finding→Path per ops/). At transitions, carry unchanged authoritative state by reference and emit only `decision_delta`; menus only at genuine decision boundaries.
10. Continuously report progress (do NOT go silent)
11. Task complete → Completion Checklist (report must include Evidence chain)
12. Output final results
```

---

## Completion Checklist (MUST NOT skip)

After task completion (vulnerability verified / reverse complete / flag captured), AI **MUST** execute each item:

```text
□ 1. Generate formal report (docs-generator skill)
□ 2. Generate diagram (diagram-generator skill) — at least 1 flowchart
□ 3. Write back to field-journal (anonymized)
□ 4. Persist searched knowledge to references/ (if web searched during task)
□ 5. Ask about community contribution
□ 6. Update system indexes (_index.md, routing.md if new scenario found)
```

---

## Error Handling Strategy

| Scenario | AI Action |
|----------|-----------|
| Bootstrap succeeds | Continue task silently |
| Bootstrap fails, clear reason | Output structured guidance, wait for user |
| Bootstrap fails, unclear reason | Output known info + suggest checking network/permissions |
| Service port mismatch | Ask actual port, help update MCP config |
| Same tool fails 2 times | Declare "auto-install cannot complete", give full manual steps, stop retrying |
| Analysis direction blocked | Switch path (static↔dynamic, Java↔Native, IDA↔r2) |
| Task exceeds capability | Clearly state limitations, suggest specific human intervention points |
| MCP tool call errors | Check if service is online (port probe), try to start or guide user |

---

## MCP Service Management

| Service | Port | Purpose | Startup |
|---------|------|---------|---------|
| idapro | 13337-13350 | IDA Pro 72 reverse tools | Auto-start (IDA plugin), port increments per instance |
| anything-analyzer | 23816 | Browser automation + HTTP capture | `pnpm dev` (project dir) |
| jshookmcp | — | JS Hook/CDP/Network/AST | `npx -y @jshookmcp/jshook@0.3.4` (stdio) |
| ghidra | 8765 | Ghidra free decompiler | Ghidra GUI auto-listens after launch |
| burpsuite | 9876 | BurpSuite 78-tool full control (Proxy/Intruder/Repeater/Scanner/Collaborator) | Burp extension auto-loads |

---

## Excuse Rebuttal Table (Anti-Laziness — 2026 Field-Tested)

| Agent's Common Excuse | Rebuttal (ENFORCE) |
|---|---|
| "I can skip this step, let me just..." | **FORBIDDEN to skip.** Every step in the behavior chain is required. If you think you can skip, output your specific reason and wait for user confirmation. |
| "Based on my judgment, this isn't necessary" | **Your judgment does not apply here.** List the specific criteria you used, explain why it allows skipping an explicitly written step. |
| "The user probably doesn't need this" | **NEVER decide for the user.** Present all options, mark recommendations but don't hide alternatives. |
| "I already know how to do this, don't need to read X" | **Read X first, then act.** Even if you're sure, X may contain task-specific constraints. Reading takes seconds. |
| "To save time, I can skip..." | **The correct way to save time is parallel execution of independent steps, NOT skipping steps.** |
| "I've used this tool before, I know the path" | **FORBIDDEN to guess paths.** MUST get actual path from tool-index. Different machines have different install locations. |
| "Task is basically done, don't need checklist" | **Task completion = ALL Checklist items checked.** Unchecked checklist = task NOT complete. |
| "I'll reply to user first, continue after confirmation" | **Don't wait for confirmation on deterministic steps.** Execute while informing user. Only pause at genuine decision points. |
| "I understand the rules, please tell me your task" | **This is the WORST failure mode.** Correct behavior: proactively match user intent to routing table, output analysis, start executing. |
| "User asked to redo import-table / step X, but I did something else more useful" | **Redo = redo the named step** (or the user-confirmed prerequisite path). MUST refresh Evidence for X. FORBIDDEN to substitute an unrelated step or silently skip X. Unpacking is a **prerequisite** for readable IAT, not a substitute for import Evidence. |
| "User said skip unpack and read IAT on a packed sample; I'll just dump the garbage table as done" | **Feasibility gate:** if X is blocked (packed/unreadable IAT), MUST state the blocker, recommend order (unpack/repair IAT or go dynamic), and **ask confirm**. If user forces X, do it and mark `quality=unreadable/packed`; FORBIDDEN to draw capability-negative conclusions from garbage IAT. |
| "Self-check crash after unpack; keep patching the file on disk" | **Patch 6:** record E-self-check-crash / E-iat-repair-fail, switch to dynamic (bp CreateFile/GetFileSize). FORBIDDEN endless static file thrash. |
| "IAT repair keeps failing; I'll grind more static unpackers" | **IAT repair iron rule:** try auto/semi-auto repair first; on tool error or unreable binary after repair, STOP static IAT, record E-iat-repair-fail, switch to dynamic API breakpoints. FORBIDDEN infinite static IAT thrash. |
| "No import table (.NET) so the hard gate does not apply" | **Equivalent anchor still MUST:** .NET → dnSpy/IL/metadata summary into E-imports slot; DLL/SYS → E-exports alongside imports. FORBIDDEN to skip the gate. |

---

## Self-Audit Before Claiming "Complete"

Before saying "task complete" or "done", MUST self-check:

```text
□ 1. Did I actually execute every step in the behavior chain (not just read docs)?
□ 2. Did I guess any tool paths? If yes, what's the actual tool-index path?
□ 3. Did I produce actual side effects (tools installed / files analyzed / vulns verified / reports written)?
□ 4. Is the Completion Checklist fully checked?
□ 5. If ANY answer is "no" → task is NOT complete. Go back and fix.
```

---

## Prohibited Behaviors

- ❌ Do NOT start reverse/pentest without running master-route.ps1 (routing.json)
- ❌ Do NOT guess tool paths — MUST get from tool-index
- ❌ Do NOT skip field-journal lookup before starting task
- ❌ Do NOT skip Checklist after task completion
- ❌ Do NOT retain un-anonymized real target info in reports
- ❌ Do NOT expand pentest scope without user authorization
- ❌ Do NOT retry auto-install after 2 failures
- ❌ Do NOT go silent — immediately inform user of problems
- ❌ Do NOT fabricate tool version numbers or feature descriptions
- ❌ Do NOT reply "understood, tell me your task" after reading rules — proactively route and start working
- ❌ Do NOT say "steps 1-4 complete" when you only read them — distinguish "read" from "executed"
- ❌ Do NOT wait for user confirmation at every step — deterministic steps execute immediately

---

## Multi-Task & Interrupt Handling

- If user switches topic mid-task, save current progress to field-journal (mark as "incomplete")
- When user returns, restore context from field-journal
- Multiple security tasks given simultaneously → execute sequentially by priority (avoid tool conflicts)
- Long-running tasks (e.g., large file IDA analysis) → report progress periodically, don't let user think it's stuck

---

## Context Window Layout Rules (Attention Optimization)

LLM attention distribution (high→low):
```text
[First 10%]  ████████████ ← Highest attention — put "immediate action" instructions here
[Middle 80%] ████░░░░░░░░ ← Attention decays — put reference materials here
[Last 10%]   ████████████ ← Attention recovers — put "MUST NOT skip" and Checklist here
```

- **MUST**: Critical actions go in first or last 10% of any instruction file
- **MUST NOT**: Bury important directives in the middle of long documents

---

## Parameter Stability (Code Words)

When tool parameters MUST be passed exactly as given, use opaque identifiers (code words) to reduce model's tendency to "semantically optimize":

- Applicable: bootstrap params, dangerous action switches, approval status values, scan scope boundaries
- **MUST**: Define mapping table first, expand in command layer
- **MUST NOT**: Let Agent freely rewrite semantic parameters (e.g., changing strict/deny to lenient synonyms)

Example:
```text
alpha -> --scope authorized-only
beta  -> --approval required
gamma -> --destructive false
```

---

## Web Search Knowledge Augmentation (MUST use when search capability available)

When AI has web search capability, **MUST proactively search** in these scenarios:

| Scenario | Search For | After Search |
|----------|-----------|--------------|
| Unknown packer/protection/obfuscation | Unpacking methods and tools | Write to skill's references/ |
| Unknown framework/protocol | Reverse/pentest methodology | Write to references/ or propose new skill |
| Tool error/incompatibility | Error message + version compatibility | Write to field-journal |
| New CVE/vulnerability discovered | PoC and exploitation method | Write to pentest-tools/references/ |
| Route not matched (new scenario) | Domain methodology and tools | Propose new skill with search results |

---

## Bootstrap Command

Windows (PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_ROOT>/skills/scripts/bootstrap-reverse.ps1" -Capability @('tool_name') -StartServices

Supported capability names (must match `skills/scripts/bootstrap-manifest.json`):  
jadx, apktool, jeb-pro, frida, frida-ps, idalib-mcp, reqable-mcp, jshookmcp, xquik-mcp, anything-analyzer, idapro, r2, rabin2, adb, agent-browser, ghidra-mcp, seclists, proxycat, burpsuite-mcp, nmap, pentestswarm, binwalk, yara, pwntools, bkcrack, il2cppdumper

Do NOT invent capabilities. Tools not listed require manual install steps in the skill docs.
```

Linux / macOS (Bash):

```bash
bash <SKILL_ROOT>/skills/scripts/bootstrap-reverse.sh tool_name --start-services
```

Kali Linux (Bash, Kali-native tooling):

```bash
bash <SKILL_ROOT>/kali/scripts/bootstrap-reverse.sh tool_name --start-services
```

## Refresh Tool Index

Windows (PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_ROOT>/skills/scripts/refresh-tool-index.ps1"
```

Linux / macOS (Bash):

```bash
bash <SKILL_ROOT>/skills/scripts/refresh-tool-index.sh
```

Kali Linux (Bash):

```bash
bash <SKILL_ROOT>/kali/scripts/refresh-tool-index.sh
```

---

## Compact reminder (do NOT write this into client-global config)

> Optional in-session recap. Core scripts MUST NOT write client-global configuration.

### Trigger Keywords (Bilingual)

- APK, Android reverse, 反编译, jadx, apktool, Frida, Hook
- binary analysis, 二进制分析, IDA, radare2, r2, disassembly, 反汇编, reverse engineering, 逆向工程
- frontend signature, 前端签名, JS reverse, JS 逆向, jshookmcp, CDP, SourceMap
- packet capture, 抓包, HTTP capture, anything-analyzer
- CTF, Pwn, web pentest, Web 渗透, exploit, 漏洞利用, privilege escalation, 提权
- penetration testing, 渗透测试, red team, 红队, Nmap, Nuclei, SQLMap, FFUF, Hashcat, Metasploit
- SRC, Bug Bounty, WAF bypass, IDOR, 越权
- BurpSuite, Burp MCP, Intruder, Repeater, Collaborator
- LLM security, Prompt injection, jailbreak, Agent security, garak, PyRIT
- EDR bypass, 免杀, AV bypass, direct syscall
- firmware, IoT, binwalk, embedded
- internal network, 内网渗透, lateral movement, domain penetration, BloodHound
- API security, 供应链安全, supply chain, YARA, malware analysis, 恶意软件分析
- iOS reverse, 游戏逆向, game reverse, anti-cheat, Unity, IL2CPP, Unreal, pwn, ROP, kernel pwn

### Post-Trigger Execution (Compact — do NOT re-run first-time setup!)

```text
1. NOW: Run the platform-native master-route (.ps1 on Windows / .sh on Linux, macOS, Kali) → PRIMARY from routing.json
2. NEXT: If ambiguous, open <SKILL_ROOT>/skills/routing.md
3. NEXT: Use platform-native case-init / scope.md — set auth.status=granted + valid network profile, or an explicit authorized offline-sample scope; Force never bypasses the hard gate
4. ACT: Open PRIMARY SKILL.md; timeline/workitems + Evidence→Finding→Path (ops/*)
```

### Core Rules (Compact)

- **MUST**: case scope (platform-native case-init / ops/scope-contract) before ACT; auth.status=granted + valid network/offline-sample scope required
- **MUST**: `-Force` / `--force` never bypasses authorization, scope, network, or readiness gates
- **MUST**: Missing tools → bootstrap, NEVER guess paths
- **MUST NOT**: Treat precedent-auth.md or "user named a target" as granted
- **MUST NOT**: Reply "understood, tell me your task" after reading rules
- **MUST NOT**: Wait for user confirmation at every step — deterministic steps execute immediately

### Excuse Rebuttal (Compact)

| Excuse | Rebuttal |
|--------|----------|
| "Can skip this step" | FORBIDDEN. Output reason, wait for user |
| "User probably doesn't need this" | NEVER decide for user |
| "Already know how, don't need to read X" | Read X first, may have task-specific constraints |
| "Task basically done, no checklist needed" | Completion = ALL checklist items checked |
| "I'll reply first, continue after confirmation" | Deterministic steps execute immediately |
| "Understood the rules, tell me your task" | WORST failure. Proactively route and start |
