# reverse-skill PRIMARY 快路径

> `scripts/master-route.ps1` 与 `scripts/master-route.sh` 必须保持相同路由契约；平台只改变执行入口，不改变 routing semantics。

## 执行契约

```text
1. 先路由后动手
2. 输出 PRIMARY 路径 + 一句话依据
3. case-init / scope.md（ops/scope-contract）— auth 未 granted 禁止对目标 ACT
4. 指定 lead + specialist 角色（ops/role-map）
5. 立即打开 PRIMARY 的 SKILL.md → ACTION REQUIRED
6. 工具路径只认 tool-index；缺则 bootstrap（仅 manifest 能力）
7. 过程追加 timeline / workitems；结论走 Evidence→Finding→Path
8. 未命中 → 读 routing.md 全表或提议新 skill
```

### Windows

```powershell
powershell -File skills\scripts\master-route.ps1 -Hint "<用户任务>"
# 默认写出当前项目的 work/master-route-<ts>/route-scope.md；从其他目录调用时显式指定项目根
powershell -File skills\scripts\master-route.ps1 -Hint "<用户任务>" -ProjectRoot "C:\path\to\analysis-project"
powershell -File skills\scripts\case-init.ps1 -Hint "<用户任务>" -CaseName "my-case"
# case 默认写入当前项目的 work/<case>/；-PackageRoot 保持兼容，-ProjectRoot 优先级更高
powershell -File skills\scripts\case-init.ps1 -Hint "<用户任务>" -CaseName "my-case" -ProjectRoot "C:\path\to\analysis-project"
# 一次成型可 ACT（授权 + 目标 + 网络档）：
powershell -File skills\scripts\case-init.ps1 -Hint "<任务>" -CaseName "my-case" -AuthGranted -TargetUrl "https://target/" -NetworkProfile authorized_target_only
# 本地离线样本：
powershell -File skills\scripts\case-init.ps1 -Hint "offline apk" -CaseName "my-sample" -Preset offline-sample -Sample ".\app.apk"
# 冒烟：verify + 脚本解析 + 路由矩阵（含中文 Hint）
powershell -File skills\scripts\smoke.ps1
# ACT 前轻量 scope 门禁（未就绪 exit 2；-Force 为兼容参数，不能绕过硬门）
powershell -File skills\scripts\case-guard.ps1 -CaseRoot work\my-case
# Evidence 追加
powershell -File skills\scripts\append-evidence.ps1 -CaseRoot work\my-case -Id E-001 -Title "..." -ReproCommand "..."
python3 skills/case-review/scripts/review_case.py work/<case> --verify-hashes --strict
```

### Linux / macOS / Kali

不要求为了核心 route/case 流程安装 PowerShell：

```bash
bash skills/scripts/master-route.sh --hint "<用户任务>"
bash skills/scripts/master-route.sh --hint "<用户任务>" --project-root "/path/to/analysis-project"
bash skills/scripts/case-init.sh --hint "<用户任务>" --case-name "my-case"
bash skills/scripts/case-init.sh --hint "<用户任务>" --case-name "my-case" --project-root "/path/to/analysis-project"
# 本地离线样本：
bash skills/scripts/case-init.sh --hint "offline apk" --case-name "my-sample" --preset offline-sample --sample ./app.apk
# ACT 前轻量 scope 门禁（--force 为兼容参数，不能绕过硬门）：
bash skills/scripts/case-guard.sh --case-root work/my-sample
# 路由 parity：
bash skills/scripts/test-routing.sh
bash skills/scripts/test-bootstrap-manifest.sh
python3 skills/case-review/scripts/review_case.py work/<case> --verify-hashes --strict
```

## 作战契约（ops）

| 文档 | 用途 |
|------|------|
| `ops/IDENTITY.md` | 我们是路由包，不是 Z3r0 平台 |
| `ops/scope-contract.md` | 启动门槛 |
| `ops/evidence-finding-path.md` | 证据链 |
| `case-review/SKILL.md` | Evidence 图审查与报告交接 |
| `ops/role-map.md` | 角色→skill |
| `ops/timeline-workitem.md` | 时间线与覆盖 |
| `ops/sandbox-profile.md` | 工具对照 |
| `ops/skill-supply-chain.md` | 安装外部 skill/MCP 的安全门闩 |
| `references/community-security-skills.md` | 社区 skill 生态（借鉴不并库） |
| `reverse-engineering/references/re-agent-workflow.md` | RE：triage→static→dynamic→synthesis |
| `pentest-tools/references/recon-pipeline.md` | 授权侦察流水线 + 证据门 |

## 优先级（高 → 低）

> 顺序必须与 `config/routing.json` 的 `priority` 数组一致。改路由只改 JSON，再改本表。`verify-routing-coherence.ps1` 会解析本表。

| ID | 条件 | PRIMARY |
|----|------|---------|
| **R4** | DSL VM / fireye / 自定义 opcode VM | `reverse-engineering/dsl-vm-reverse/` |
| **R1** | APK / smali / jadx / apktool | `apk-reverse/` |
| **R2** | IPA / iOS / Objection / MobSF / mobile | `mobile-reverse/` |
| **R3** | JS 签名 / 前端加密 / jshook / CDP | `js-reverse/` |
| **R30** | 浏览器扩展逆向 | `browser-extension-reverse/` |
| **R31** | macOS / Mach-O | `macos-reverse/` |
| **R33** | Go / Rust 二进制 | `go-rust-reverse/` |
| **R5** | .NET / dnSpy / de4dot / ConfuserEx | `dotnet-reverse/` |
| **R9** | 恶意样本 / YARA / 沙箱 | `malware-analysis/` |
| **R21** | 协议 / Protobuf / PCAP 协议 | `protocol-reverse/` |
| **R22** | Ghidra / 开源反编译 | `ghidra-reverse/` |
| **R6** | IDA / 反编译 / 反汇编深挖 | `ida-reverse/` |
| **R7** | radare2 / r2 | `radare2/` |
| **R8** | 固件 / binwalk / IoT / EMBA | `firmware-pentest/` |
| **R34** | 硬件调试口 / UART/JTAG | `hardware-security/` |
| **R28** | OT / ICS / 工控 | `ot-ics/` |
| **R17** | pwn / ROP / 堆栈利用 | `pwn-chain/` |
| **R16** | N-day / 补丁差分 | `patch-diff-exploit/` |
| **R18** | EDR / 免杀 / syscall | `edr-bypass-re/` |
| **R24** | Windows / AD / Kerberos / AD CS | `windows-ad/` |
| **R37** | 联邦身份 SAML/OIDC | `identity-federation/` |
| **R23** | 云 / 容器 / K8s | `cloud-k8s/` |
| **R35** | 数据库安全 | `database-security/` |
| **R25** | 取证 / 内存转储 / 时间线 | `digital-forensics/` |
| **R44** | OSINT / 威胁情报 / 公开 X IOC 补充 | `threat-intelligence/` |
| **R36** | 邮件 / 钓鱼分析 | `email-security/` |
| **R29** | Wi-Fi / 无线渗透 | `wifi-wireless/` |
| **R38** | RF / SDR 研究 | `radio-sdr/` |
| **R32** | 厚客户端安全 | `thick-client/` |
| **R26** | 代码审计 / SAST / Semgrep | `code-audit/` |
| **R27** | 威胁狩猎 / 检测工程 / 蓝队 | `threat-hunting/` |
| **R10** | 攻击链 / 红队 / 横向 / 完整渗透 | `attack-chain/` |
| **R11** | Nmap / Nuclei / SQLMap / SRC / 渗透工具 | `pentest-tools/` |
| **R12** | API / GraphQL / BOLA / JWT 攻击 | `api-security/` |
| **R13** | SBOM / Trivy / 供应链 | `supply-chain-security/` |
| **R14** | LLM / Prompt 注入 / Agent 安全 | `llm-security/` |
| **R15** | bindiff / 符号迁移 / PDB | `binary-diff/` |
| **R19** | 浏览器/桌面自动化 | `browser-automation/` |
| **R40** | Case / Evidence 图审查 | `case-review/` |
| **R20** | 报告 / writeup | `docs-generator/` |
| **R39** | 图表 / Mermaid / Graphviz / PlantUML / 架构图 | `diagram-generator/` |
| **R41** | CTF / AWD / 靶场（单入口，不展开 40 个子技能） | `ctf-sandbox/` |
| **R45** | 方法论 / 决策框架 / 严重混淆 / 找不到入口 | `reverse-engineering/decision-framework/` |
| **R0** | 通用逆向 / 反调试 / OLLVM / 未知二进制 | `reverse-engineering/` |

未命中强关键词 → PRIMARY=`R0`，并提示打开 `routing.md`（歧义附录，不是第二套路由器）。

## 边界

| 任务 | 处理 |
|------|------|
| 纯 CTF 多类型编排 | PRIMARY `ctf-sandbox/` → sidecar `../CTF-Sandbox-Orchestrator/` |

## 读序

```text
RULES.md → MASTER-ROUTING.md → PRIMARY SKILL.md
  → (可选) routing.md 三轴 / field-journal
  → tool-index.md → bootstrap → ACT
```
