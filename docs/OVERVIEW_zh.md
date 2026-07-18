# Cybersecurity Skills Router 概览

> 面向代码 Agent 的安全任务路由与工具编排系统：先判断任务，再选择 Skill，最后调用真实工具执行。

如果你是第一次看到这个仓库，请先读这份文档。`README_AI.md` 是给 AI Agent 执行 bootstrap 的入口。

## 这个项目是什么

Cybersecurity Skills Router 是一套面向 Claude Code、Codex CLI、Cursor、Cline、Windsurf 等代码 Agent 的 **Skill Router + Tool Orchestration** 系统。

它让 Agent 在处理 APK、二进制、前端 JS、HTTP 抓包、CTF、固件、安全测试等复杂任务时，不再直接猜命令，而是：

1. 先根据目标类型和用户意图完成路由；
2. 再进入对应 Skill 的方法论和工作流；
3. 检查本机工具、MCP 服务和脚本入口；
4. 调用真实工具执行分析；
5. 任务结束后生成报告，并把可复用经验沉淀回 field journal。

简短地说：

> 这不是一个单工具安装包，而是一套让 AI Agent 稳定执行安全 / 逆向任务的工作流操作系统。

## 为什么需要它

普通代码 Agent 在安全和逆向任务中很容易失控：

- 遇到 APK、ELF、JS、PCAP、CTF 时不知道该走哪条分析链；
- 不知道什么时候用 jadx、apktool、Frida、IDA、radare2、BurpSuite；
- 工具路径、MCP 服务、脚本入口分散在不同机器上，迁移困难；
- 同类问题每次重新踩坑，经验无法复用；
- 输出大量解释，但没有真正进入工具执行。

本项目的目标是把这些问题收敛成一条明确的执行链：

```text
用户任务
  ↓
RULES.md
  ↓
Skill Router
  ↓
目标场景 Skill
  ↓
工具 / MCP / 脚本
  ↓
报告 + field journal
```

## 核心能力

| 能力 | 说明 |
|---|---|
| Skill Router | 根据目标类型、用户意图、工具链需求，把任务分发到对应 Skill。 |
| Tool Orchestration | 整合 jadx、apktool、Frida、radare2、IDA、BurpSuite、浏览器工具等执行面。 |
| MCP Integration | 通过 MCP 或本地桥接，把 BurpSuite、IDA、浏览器分析等能力暴露给 Agent。 |
| Bootstrap Scripts | 检测本机工具状态，必要时给出自动安装或人工补齐路径。 |
| Field Journal | 把完成过的任务、踩坑、命令和模式沉淀成可复用经验。 |
| Report Generation | 任务完成后生成分析报告、攻击路径图、流程图或 CTF writeup。 |

## 平台支持

| 平台 | 状态 | 入口 |
|---|---|---|
| Windows | 完整主线 | `README.md`、PowerShell 脚本 |
| Kali Linux | 专项适配 | `kali/README-kali.md` |
| Ubuntu / Debian Linux | 通用适配 | `platforms/linux.md`、`skills/scripts/bootstrap-reverse.sh`、`skills/scripts/refresh-tool-index.sh` |
| macOS | 通用适配 | `platforms/macos.md`、`skills/scripts/bootstrap-reverse.sh`、`skills/scripts/refresh-tool-index.sh` |

平台总览见 [PLATFORMS.md](PLATFORMS.md)。普通 Linux / macOS 用户建议先查看能力列表：

```bash
bash skills/scripts/bootstrap-reverse.sh --list
```

只刷新工具索引时运行：

```bash
bash skills/scripts/refresh-tool-index.sh
```

## 支持的 Agent 客户端

- Claude Code
- Codex CLI
- Cursor
- Cline
- Windsurf
- Kiro
- 其他支持项目规则、system prompt、MCP 或外部工具调用的代码 Agent

本项目不绑定某一个客户端。它的核心资产是 `RULES.md`、`skills/SKILL.md`、`skills/routing.md`、工具索引、子 Skill 和 MCP / 脚本入口。

## 支持场景

| 场景 | 主要入口 |
|---|---|
| APK / Android 分析 | `skills/apk-reverse/`、`skills/mobile-reverse/` |
| 二进制逆向 | `skills/ida-reverse/`、`skills/radare2/`、`skills/reverse-engineering/` |
| JS 参数 / 前端签名分析 | `skills/js-reverse/` |
| HTTP 抓包 / 请求重放 | BurpSuite MCP、anything-analyzer、browser automation |
| CTF / 安全竞赛 | `CTF-Sandbox-Orchestrator/` |
| 固件 / IoT 分析 | `skills/firmware-pentest/` |
| 补丁差分 / N-day 分析 | `skills/patch-diff-exploit/` |
| 安全测试工具链 | `skills/pentest-tools/` |
| LLM / Agent 安全 | `skills/llm-security/` |
| 报告和图表 | `skills/docs-generator/`、`skills/diagram-generator/` |

## 示例工作流

用户输入：

```text
帮我分析这个 APK 的签名校验逻辑。
```

期望 Agent 行为：

1. 识别任务类型：APK / Android / 签名校验；
2. 路由到 `apk-reverse`，必要时分流到 Frida 或 native `.so` 分析；
3. 检查 jadx、apktool、adb、Frida 是否可用；
4. 解包 APK，提取 Manifest、Java 层逻辑和 native library；
5. 判断静态分析是否足够，必要时生成动态 hook 方案；
6. 输出签名校验位置、关键调用链、绕过思路和验证步骤；
7. 任务完成后生成报告，并将可复用经验写入 field journal。

## 仓库结构

```text
.
├── README.md                    # 主入口（英文）
├── README_zh.md                 # 主入口（中文）
├── README_AI.md                 # AI Agent bootstrap 入口（英文）
├── RULES.md                     # 全局路由与执行规则
├── docs/OVERVIEW.md              # 详细概览（英文）
├── docs/OVERVIEW_zh.md           # 详细概览（中文）
├── docs/ARCHITECTURE.md          # 架构说明
├── docs/PLATFORMS.md             # 平台支持总览
├── skills/                      # 主 Skill 目录
│   ├── SKILL.md                 # 总控入口
│   ├── routing.md               # 路由矩阵
│   ├── field-journal/           # 经验沉淀
│   ├── apk-reverse/
│   ├── js-reverse/
│   ├── reverse-engineering/
│   ├── ida-reverse/
│   ├── radare2/
│   └── ...
├── CTF-Sandbox-Orchestrator/    # CTF 场景子技能库
├── burp-mcp-full/               # BurpSuite MCP 控制模块
└── kali/                        # Kali 环境辅助脚本
```

## 快速开始

### 人类用户

1. 先读本文件，理解项目定位；
2. 再读 `README.md`，让 AI Agent 执行 bootstrap；
3. 根据你的客户端配置 MCP、Rules 或项目级指令；
4. 用一个真实任务验证路由是否生效。

### AI Agent

如果你是 AI Agent，不要停在概览。请进入执行入口：

1. 读取 `README_AI.md`；
2. 执行其中的第 0 节；
3. 读取 `RULES.md`；
4. 加载 `skills/SKILL.md` 和 `skills/routing.md`；
5. 先路由，再执行。

## 和普通 Prompt 包有什么区别

普通 Prompt 包通常只给模型一段建议。这个项目更强调可执行结构：

- 有明确入口：`RULES.md`、`SKILL.md`、`routing.md`；
- 有场景分流：不同目标进入不同 Skill；
- 有工具执行面：MCP、脚本、本地工具链；
- 有经验回写：任务完成后沉淀可复用经验；
- 有迁移机制：换机器后重新扫描工具索引，恢复执行能力。

它不是让 Agent “知道更多”，而是让 Agent “少猜、少跳步、能落地执行”。

## 安全与使用边界

本项目用于授权环境中的安全研究、逆向分析、CTF、教学实验、内部安全测试和防护验证。请确保你对目标系统拥有合法授权。

主 README 中的安全相关规则用于减少已授权实验环境中的重复确认和流程空转，不代表鼓励未授权访问、破坏性操作或真实目标攻击。

## 项目定位

如果你需要向人解释这个项目，可以这样概括：

> 独立设计并开源了一套面向代码 Agent 的安全任务 Skill Router，将逆向、安全测试、CTF 等复杂任务拆成可路由、可执行、可沉淀的工作流，并通过 MCP 和脚本把本地工具链接入 Agent。

关键词：AI Agent、Skill Router、Tool Orchestration、MCP、Workflow Automation、Security Analysis、Field Journal。

## 相关文档

- [README.md](../README.md)：主入口（中文）
- [README_AI.md](../README_AI.md)：AI bootstrap 入口（英文）
- [PLATFORMS.md](PLATFORMS.md)：平台支持总览
- [platforms/linux.md](platforms/linux.md)：普通 Linux 适配
- [platforms/macos.md](platforms/macos.md)：macOS 适配
- [RULES.md](../RULES.md)：全局执行规则
- [ARCHITECTURE.md](ARCHITECTURE.md)：架构说明
- [skills/routing.md](../skills/routing.md)：路由矩阵
- [burp-mcp-full/README.md](../burp-mcp-full/README.md)：BurpSuite MCP 模块

## License

MIT License. See [LICENSE](../LICENSE).

