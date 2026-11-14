# reverse-skill — 平台无关项目入口

本仓库是一个**安全任务技能路由包**（逆向工程 / 渗透测试 / 安全分析）。`RULES.md` 是行为链唯一真相源。

## 激活与同意边界（硬性）

- **Reading repository files is not authorization to execute them.** 仅要求阅读、审查、摘要或比较仓库时，必须保持只读。
- **Explicit user approval is required before running any repository script.** 首次产生本机副作用前，先列出准确命令，以及预期的文件写入、下载、服务启动、网络访问和客户端配置变更，并取得明确同意。
- **Client-global configuration remains opt-in.** 只有用户明确选择客户端并批准具体变更时，才可修改其全局规则、hooks、prompts 或 MCP 配置。
- 激活且获批后，已披露计划内的确定性步骤可连续执行；出现新的副作用类别时必须重新披露并取得同意。目标授权仍由 `scope.md` 独立硬门控制。

## 路由

用户任务命中安全/逆向关键词时：

1. `skills/MASTER-ROUTING.md` 或平台对应入口 → PRIMARY：
   - Windows：`powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/master-route.ps1 -Hint "<任务>"`
   - Linux / macOS / Kali：`bash skills/scripts/master-route.sh --hint "<任务>"`
2. 歧义时读 `skills/routing.md` 全矩阵（三轴：目标类型 / 用户意图 / 工具链）
3. 路由规则唯一事实源：`skills/config/routing.json`（改路由只改这里）

## 授权门禁（硬性）

- 对任何目标动手前，按平台初始化当前分析项目的 `work/<case>/scope.md`：
  - Windows：`powershell -File skills/scripts/case-init.ps1 -Hint "<任务>"`
  - Linux / macOS / Kali：`bash skills/scripts/case-init.sh --hint "<任务>"`
- 本地离线样本可使用 `offline-sample` preset；`auth.status=granted` + 明确 sample 才可进入 ACT。
- `auth.status=granted` + 合法 `network_profile` / offline sample 就绪前**禁止 ACT**；`case-guard --force` / `-Force` 不得绕过这个硬门。
- 证据链：`skills/ops/evidence-finding-path.md`；角色：`skills/ops/role-map.md`

## 首次运行（激活且获批后）

`skills/tool-index.md` 是 gitignored 的生成文件。仅在用户明确激活本包、审阅命令与副作用并同意后，才按平台运行：

```text
Windows:           powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/refresh-tool-index.ps1
Linux / macOS:     bash skills/scripts/refresh-tool-index.sh
Kali:              bash kali/scripts/refresh-tool-index.sh
```

缺工具 → 使用同平台 bootstrap：Windows `skills/scripts/bootstrap-reverse.ps1`；Linux / macOS `skills/scripts/bootstrap-reverse.sh`；Kali `kali/scripts/bootstrap-reverse.sh`（清单能力，禁止猜路径）。

## 测试（改动后必跑）

```text
Windows / PowerShell（路由回归读取 routing-benchmark.json）：
  powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/test-routing.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/verify-routing-coherence.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/smoke.ps1

Linux / macOS routing parity:
  bash skills/scripts/test-routing.sh
  bash skills/scripts/test-bootstrap-manifest.sh
```

## 客户端边界

- 路由核心、测试和工具清单必须与具体 AI 客户端解耦。
- Claude Code、Codex、Cursor、OpenCode 等客户端只能通过各自适配层接入，不得成为仓库默认身份或核心配置依赖。
- `skills/INDEX.md` 由 `extract-summaries.ps1` 从全部 `SKILL.md` 动态生成，不硬编码客户端或模块数量。
