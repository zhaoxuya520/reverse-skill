# Agent Skill 供应链安全（本包特色）

> 来源综合：OWASP Agentic Skills Top 10（AST10）、Anthropic Agent Skills 安全建议、公开投毒事件（如 ClawHavoc，见 AST10 时间线）  
> 检索日期：2026-07-17  
> 适用：安装/编写/合并 **任何** skill、MCP、bootstrap 脚本时

本包**可执行脚本面**静态审计（后门 / 删库 / 管道执行）：[`docs/PACKAGE-SECURITY-AUDIT.md`](../../docs/PACKAGE-SECURITY-AUDIT.md)。

## 1. 为什么 reverse-skill 要单独管这个

本包会：

- 指导 AI **执行命令与 bootstrap 下载**
- 通过 MCP 接触本地与网络  
- 写入 field-journal / 报告  

恶意 skill 可导致：凭据窃取、持久化提示词、供应链后门。  
我们用 **文档门闩 + 工具真相源**，而不是再做一个 skill 应用商店。

## 2. 威胁对照（精简 AST10 思路）

| 风险类 | 表现 | 本包控制 |
|--------|------|----------|
| 恶意/投毒 skill | 诱导 exfil、写 memory/后门 | 只信本仓库 + 用户书面授权的外源；外源先人工读 SKILL.md 与 scripts |
| 权限过度 | 无差别 `curl \| bash`、全盘读 | bootstrap 仅 manifest 能力；scope `network_profile` |
| 依赖投毒 | pip/npm 恶意包 | 优先官方 release；记录版本到 tool-index |
| MCP 盲信 | 未审计 MCP 服务器 | tool-index 注册状态 + 端口探测；不默认信任远程 MCP |
| MCP/CLI 自动执行投毒 | 仓库 `.env` 改 `CODEX_HOME` 等导致启动即执行恶意 MCP（HackTricks / CVE 类案例） | 不信任仓库内默认 MCP 配置；启动 Agent 前检查 env 与 MCP 列表 |
| 提示注入进 skill | SKILL 正文藏隐蔽指令 | 审阅 diff；禁止「隐藏在 HTML 注释的执行指令」不经用户 |
| 范围漂移 | skill 诱导扩大扫描 / 「一个域名全自动打穿」 | ops/scope-contract：out_of_scope + auth；禁止无 in_scope 的狂扫 |
| 技能堆叠过载 | 同时挂载过多 skill 反而漏报（公开评测观察） | 只加载 PRIMARY + 必要 secondary（MASTER-ROUTING） |

## 3. 安装外部 skill 的 MUST 清单

```text
□ 来源：官方 org / 已审计列表（如 ToB curated）/ 用户自有
□ 阅读全部 SKILL.md + scripts/* + package 依赖
□ 无神秘外连、无读取 ~/.ssh / 浏览器库 的默认步骤
□ 与本包路由冲突时：以本包 MASTER-ROUTING + scope 为准
□ 不复制进 monorepo 除非走 CONTRIBUTING 与脱敏
□ 更新 skills/references/community-security-skills.md 记录来源日期
```

## 4. 与 bootstrap / MCP 的边界

| 动作 | 允许 | 禁止 |
|------|------|------|
| `bootstrap-reverse.ps1 -Capability X` | X ∈ bootstrap-manifest.json | 任意新 name 而不改 manifest |
| 注册 MCP | 用户确认 + tool-index 刷新 | 静默写入全局 MCP 指向未知 URL |
| 跑社区 Python 一键 pentest | 授权 lab + 读源码后 | 直接生产目标 + 未知脚本 |

## 5. 本包作者/贡献者

- 新 skill：CONTRIBUTING + ACTION REQUIRED + 完成自检  
- 引用社区内容：标注 URL + 日期（本文件 / community-security-skills.md）  
- 发现可疑行为：停止执行，告知用户，不自动「尝试绕过」

## 6. 快速自检（每次合并外部材料前）

```powershell
# 列出将引入的脚本扩展名
Get-ChildItem -Recurse -Include *.ps1,*.sh,*.py,*.js | Select-Object FullName
# 粗搜危险模式（人工复核，非完备）
# 在外部目录执行：Select-String -Pattern 'Invoke-WebRequest|curl .\||wget .\||~/.ssh|exfil'
```

## 7. 相关

- 身份：`IDENTITY.md`  
- 外部目录：`../references/community-security-skills.md`  
- 授权：`scope-contract.md` + `field-journal/precedent-auth.md`  
