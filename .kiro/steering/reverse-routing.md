---
inclusion: auto
---

# 逆向/渗透/安全任务自动路由规则

当遇到以下任何一类任务时，必须先进入逆向技能路由包：

## 触发关键词（任意命中即触发）

- APK、Android 逆向、反编译、smali、jadx、apktool、Frida、Hook
- 二进制分析、IDA、radare2、r2、反汇编、逆向工程、RE
- 前端签名、加密参数、JS 逆向、jshookmcp、CDP、SourceMap
- 抓包、HTTP 捕获、请求重放、anything-analyzer
- CTF、Pwn、Web 渗透、漏洞利用、提权
- MCP 逆向工具、idalib-mcp
- 重打包、签名、证书校验、root 检测、反调试
- so 分析、native hook、JNI
- 渗透测试、红队、安全评估、蓝队、应急响应
- 写报告、写文档、出报告、writeup、技术文档、渗透报告、逆向报告
- 浏览器自动化、打开网页、填表、爬取、截图、自动化登录、Playwright、agent-browser、headless、桌面自动化、OpenReverse、UIA、CUA、Windows 自动化、桌面操作
- 游戏逆向、反作弊、Cheat Engine、Unity、IL2CPP、Unreal Engine、x64dbg、游戏安全、game hacking、anti-cheat、EAC、BattlEye
- 符号迁移、bindiff、跨版本、PDB 缺失、函数偏移迁移、symbol migration、版本对比、旧版符号
- 端口扫描、Nmap、漏洞扫描、Nuclei、SQL 注入、SQLMap、目录爆破、FFUF、密码破解、Hashcat、Hydra、Metasploit、Impacket、pentestMCP
- SRC、Bug Bounty、众测、漏洞赏金、HackerOne、WAF bypass、绕过 WAF、IDOR、越权、任意账号
- 画图、流程图、架构图、攻击路径图、时序图、状态图、数据流图、Mermaid、Graphviz、PlantUML、diagram

## 路由入口（相对于本包根目录，按顺序读取）

> **注意**：以下路径是相对于本包安装位置的。AI 应自动检测本包实际所在目录，不要假设固定盘符。
> 检测方法：找到本文件（`.kiro/steering/reverse-routing.md`）所在目录，向上两级即为包根目录。

1. `skills/SKILL.md`
2. `skills/routing.md`
3. `skills/tool-index.md`

## 首次使用必做

如果 `tool-index.md` 中的路径不是当前机器的（用户名不对、盘符不对），先执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<本包根目录>/skills/scripts/refresh-tool-index.ps1"
```

这会重新扫描当前机器的工具状态并更新索引。

## 执行原则

- 不要猜工具路径，先读 tool-index.md
- 缺少工具时先调用 `bootstrap-reverse.ps1` 自动补齐，不要直接报错
- 如果自动补齐失败，立即输出结构化引导（含手动安装步骤和验证命令），引导用户配置，不要沉默或反复重试
- 同一工具失败 2 次后，明确告知用户"自动安装无法完成"，给出完整手动步骤，不再重试
- MCP 服务端口不一致时，询问用户实际端口，帮用户更新配置
- 任务完成后必须执行"自动进化回写"流程（写入 field-journal/）
- 每次进入本包时先检查 `field-journal/_index.md` 是否有同类项目经验可复用

## 完整行为链

```
1. 识别任务属于安全/逆向类 → 触发本路由规则
2. 检测本包实际安装路径（从本 steering 文件位置推导）
3. 如果 tool-index 路径与当前机器不符 → 先执行 refresh-tool-index.ps1
4. 读取 SKILL.md → routing.md → 确定进入哪个子 skill
5. 如果路由未命中 → 提议新增 skill（按 CONTRIBUTING.md 流程）
6. 检查 field-journal/_index.md → 是否有同类经验可复用
7. 读取 tool-index.md → 确认本机工具状态
8. 如果缺工具 → 调用 bootstrap-reverse.ps1 自动补齐
9. 如果自动补齐失败 → 输出结构化引导（含手动步骤），等用户确认后继续
10. 进入对应 skill 的工作流 → 执行任务
11. 任务完成 → 调用 docs-generator skill 生成报告（含 diagram-generator 生成的攻击路径图/数据流图等可视化图表）
12. 自动回写 field-journal/（已脱敏）
13. 询问用户："是否将本次经验贡献到社区主仓库？数据已脱敏，只提交 field-journal 文件。"
14. 更新 _index.md → 检查是否需要更新路由/索引/manifest → 执行更新
15. 输出最终结果
```

## 任务完成后的硬性 Checklist（不可跳过）

当任务执行完毕（漏洞已验证/逆向已完成/flag 已拿到）后，AI **必须**逐项执行以下清单，不允许跳过任何一项：

```text
□ 1. 生成正式报告（docs-generator）
     - 使用对应模板（逆向报告/渗透报告/CTF writeup/签名报告）
     - 报告必须包含：目标概述、完整步骤、关键证据、复现命令
     - 报告长度：至少 500 字，复杂任务至少 1000 字
     - 输出到用户项目目录

□ 2. 生成图表（diagram-generator）
     - 至少包含 1 张流程图（攻击路径/分析流程/数据流）
     - 用 Mermaid 代码块嵌入报告中
     - 图表类型参考：
       · 渗透测试 → 攻击路径图（flowchart）
       · 逆向分析 → 函数调用关系图 或 数据流图
       · JS 签名 → 请求链路时序图（sequenceDiagram）
       · CTF → 解题思路流程图

□ 3. 回写 field-journal（已脱敏）
     - 按 _template.md 格式
     - 必须包含：踩坑记录、可复用模式、工具链发现
     - 脱敏检查：无真实域名/IP/Token

□ 4. 询问社区贡献
     - 向用户展示："是否将本次经验贡献到社区主仓库？数据已脱敏。"
     - 等待用户回复

□ 5. 更新索引
     - 更新 field-journal/_index.md
     - 检查是否需要更新 routing.md / bootstrap-manifest
```

如果 AI 在任务完成后没有执行以上清单，用户可以提醒："你忘了写报告和回写经验"，AI 必须立即补上。

## Bootstrap 命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<本包根目录>/skills/scripts/bootstrap-reverse.ps1" -Capability @('工具名') -StartServices
```

## 刷新工具索引

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<本包根目录>/skills/scripts/refresh-tool-index.ps1"
```

## 新增 Skill

当发现路由矩阵无法覆盖当前任务类型时，按 `CONTRIBUTING.md` 流程新增 skill：

路径：`<本包根目录>/skills/CONTRIBUTING.md`

新增后必须同步更新：路由矩阵、bootstrap-manifest、ToolDiscovery、refresh-tool-index、本 steering 文件的关键词列表。
