# reverse-skill PRIMARY 快路径

> 与 `scripts/master-route.ps1` 保持一致。

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

```powershell
powershell -File skills\scripts\master-route.ps1 -Hint "<用户任务>"
# 默认写出 work/master-route-<ts>/route-scope.md
powershell -File skills\scripts\case-init.ps1 -Hint "<用户任务>" -CaseName "my-case"
# 一次成型可 ACT（授权 + 目标 + 网络档）：
powershell -File skills\scripts\case-init.ps1 -Hint "<任务>" -CaseName "my-case" -AuthGranted -TargetUrl "https://target/" -NetworkProfile authorized_target_only
# 冒烟：verify + 脚本解析 + 路由矩阵（含中文 Hint）
powershell -File skills\scripts\smoke.ps1
# ACT 前轻量 scope 门禁（未就绪 exit 2；-Force 仅警告）
powershell -File skills\scripts\case-guard.ps1 -CaseRoot work\my-case
# Evidence 追加
powershell -File skills\scripts\append-evidence.ps1 -CaseRoot work\my-case -Id E-001 -Title "..." -ReproCommand "..."
```

## 作战契约（ops）

| 文档 | 用途 |
|------|------|
| `ops/IDENTITY.md` | 我们是路由包，不是 Z3r0 平台 |
| `ops/scope-contract.md` | 启动门槛 |
| `ops/evidence-finding-path.md` | 证据链 |
| `ops/role-map.md` | 角色→skill |
| `ops/timeline-workitem.md` | 时间线与覆盖 |
| `ops/sandbox-profile.md` | 工具对照 |
| `ops/skill-supply-chain.md` | 安装外部 skill/MCP 的安全门闩 |
| `references/community-security-skills.md` | 社区 skill 生态（借鉴不并库） |
| `reverse-engineering/references/re-agent-workflow.md` | RE：triage→static→dynamic→synthesis |
| `pentest-tools/references/recon-pipeline.md` | 授权侦察流水线 + 证据门 |

## 优先级（高 → 低）

| ID | 条件 | PRIMARY |
|----|------|---------|
| **R1** | APK / smali / jadx / apktool | `apk-reverse/` |
| **R2** | IPA / iOS / Objection / MobSF / mobile | `mobile-reverse/` |
| **R3** | JS 签名 / 前端加密 / jshook / CDP | `js-reverse/` |
| **R4** | DSL VM / fireye / 自定义 opcode VM | `reverse-engineering/dsl-vm-reverse/` |
| **R5** | .NET / dnSpy / de4dot / ConfuserEx | `dotnet-reverse/` |
| **R9** | 恶意样本 / YARA / 沙箱 | `malware-analysis/` |
| **R6** | IDA / 反编译 / 反汇编深挖 | `ida-reverse/` |
| **R7** | radare2 / r2 | `radare2/` |
| **R8** | 固件 / binwalk / IoT / EMBA | `firmware-pentest/` |
| **R10** | 攻击链 / 红队 / 横向 / 完整渗透 | `attack-chain/` |
| **R11** | Nmap / Nuclei / SQLMap / SRC / 渗透工具 | `pentest-tools/` |
| **R12** | API / GraphQL / BOLA / JWT 攻击 | `api-security/` |
| **R13** | SBOM / Trivy / 供应链 | `supply-chain-security/` |
| **R14** | LLM / Prompt 注入 / Agent 安全 | `llm-security/` |
| **R15** | bindiff / 符号迁移 / PDB | `binary-diff/` |
| **R16** | N-day / 补丁差分 | `patch-diff-exploit/` |
| **R17** | pwn / ROP / 堆栈利用 | `pwn-chain/` |
| **R18** | EDR / 免杀 / syscall | `edr-bypass-re/` |
| **R19** | 浏览器/桌面自动化 | `browser-automation/` |
| **R20** | 报告 / writeup | `docs-generator/` |
| **R21** | 协议 / Protobuf / PCAP 协议 | `protocol-reverse/` |
| **R22** | Ghidra / 开源反编译 | `ghidra-reverse/` |
| **R23** | 云 / 容器 / K8s | `cloud-k8s/` |
| **R24** | Windows / AD / Kerberos / AD CS | `windows-ad/` |
| **R25** | 取证 / 内存转储 / 时间线 | `digital-forensics/` |
| **R26** | 代码审计 / SAST / Semgrep | `code-audit/` |
| **R27** | 威胁狩猎 / 检测工程 / 蓝队 | `threat-hunting/` |
| **R28** | OT / ICS / 工控 | `ot-ics/` |
| **R29** | Wi-Fi / 无线渗透 | `wifi-wireless/` |
| **R30** | 浏览器扩展逆向 | `browser-extension-reverse/` |
| **R31** | macOS / Mach-O | `macos-reverse/` |
| **R32** | 厚客户端安全 | `thick-client/` |
| **R33** | Go / Rust 二进制 | `go-rust-reverse/` |
| **R34** | 硬件调试口 / UART/JTAG | `hardware-security/` |
| **R35** | 数据库安全 | `database-security/` |
| **R36** | 邮件 / 钓鱼分析 | `email-security/` |
| **R37** | 联邦身份 SAML/OIDC | `identity-federation/` |
| **R38** | RF / SDR 研究 | `radio-sdr/` |
| **R0** | 通用逆向 / 反调试 / OLLVM / 未知二进制 | `reverse-engineering/` |

未命中强关键词 → PRIMARY=`R0`，并提示打开 `routing.md`。

## 边界

| 任务 | 处理 |
|------|------|
| 纯 CTF 多类型编排 | `../CTF-Sandbox-Orchestrator/` |

## 读序

```text
RULES.md → MASTER-ROUTING.md → PRIMARY SKILL.md
  → (可选) routing.md 三轴 / field-journal
  → tool-index.md → bootstrap → ACT
```
