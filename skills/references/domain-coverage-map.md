# 本包领域覆盖图（深度优先）

> 对照社区「几百个微 skill」：我们用 **少量深 skill + 路由 + ops** 覆盖主战场。  
> 日期：2026-07-18

## 域 → 本包入口

| 域 | PRIMARY / 模块 | 备注 |
|----|----------------|------|
| 移动 Android | `apk-reverse/` `mobile-reverse/` | |
| 移动 iOS | `mobile-reverse/` | |
| 二进制深挖 | `ida-reverse/` `radare2/` `ghidra-reverse/` | Ghidra = 开源主路径 |
| 通用 RE / 反调试 / OLLVM | `reverse-engineering/` | |
| .NET | `dotnet-reverse/` | |
| 前端 JS / 签名 | `js-reverse/` | |
| 浏览器扩展 | `browser-extension-reverse/` | |
| DSL/风控 VM | `reverse-engineering/dsl-vm-reverse/` | |
| 协议 / PCAP 协议 | `protocol-reverse/` | |
| 固件 IoT | `firmware-pentest/` | |
| 恶意样本 | `malware-analysis/` | |
| 数字取证 / IR | `digital-forensics/` | |
| 威胁狩猎 / 蓝队 | `threat-hunting/` | |
| 渗透工具 | `pentest-tools/` (+ src-hunter) | |
| Windows / AD | `windows-ad/` | |
| 云 / 容器 / K8s | `cloud-k8s/` | |
| 代码审计 / SAST | `code-audit/` | |
| Wi-Fi / 无线 | `wifi-wireless/` | |
| OT / ICS | `ot-ics/` | 被动优先；写寄存器默认禁止 |
| macOS | `macos-reverse/` | iOS 仍走 mobile-reverse |
| 厚客户端 | `thick-client/` | |
| Go / Rust 二进制 | `go-rust-reverse/` | |
| 硬件调试口 | `hardware-security/` | 交接 firmware-pentest |
| 数据库 | `database-security/` | |
| 邮件 / 钓鱼 | `email-security/` | |
| 联邦身份 SSO | `identity-federation/` | 与 api-security JWT 互补 |
| RF / SDR | `radio-sdr/` | 默认只收；非 Wi-Fi |
| 多阶段攻击 | `attack-chain/` | |
| Pwn | `pwn-chain/` | |
| N-day 补丁 | `patch-diff-exploit/` | |
| EDR 研究 | `edr-bypass-re/` | |
| API | `api-security/` | |
| 供应链 SBOM | `supply-chain-security/` | |
| LLM/Agent | `llm-security/` | + `ops/skill-supply-chain.md` |
| 浏览器自动化 | `browser-automation/` | |
| 报告/图 | `docs-generator/` `diagram-generator/` | |
| 符号迁移 | `binary-diff/` | |
| 作战契约 | `ops/` | **特色** |
| CTF 编排 | `CTF-Sandbox-Orchestrator/` | |
| 密码学广覆盖 | 本地可选 `crypto-analysis`（gitignore） | 公开核心以 RE 模式文档为主 |

## 明确不整库并入的域（路由未命中时的策略）

| 域 | 策略 |
|----|------|
| 纯游戏外挂开发 | 不作为产品方向；Unity 样本仍可走 `reverse-engineering` + seed-014 |
| 深度汽车/航空认证级 | 可外链；本包仅有 RF/OT 入口级 |
| 纯 GRC/合规长文 | 不替代专业 GRC 工具；可写报告模板引用 |
| 800+ ATT&CK 微 skill | 用本表 + ATT&CK 可选标签（Finding 字段） |

## 与 MITRE ATT&CK（可选）

Finding 模板允许 `optional_attack: Txxxx`（见 `ops/evidence-finding-path.md`），**不强制**完整 ATT&CK 引擎。
