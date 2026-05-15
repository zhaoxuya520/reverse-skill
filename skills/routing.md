# 逆向技能路由矩阵

按目标类型、用户意图和工具链，将任务路由到最合适的技能模块。参考用，不强制。

## 按目标类型

| 目标类型 | 推荐入口 | 备选方案 |
|---------|---------|---------|
| APK / Android 应用 | `apk-reverse/` — jadx 反编译 + apktool 解包 | 如核心在 .so → `ida-reverse/` 或 `radare2/` |
| 二进制 exe/dll/so/elf | `ida-reverse/` — IDA Pro 反编译 | `radare2/` — CLI 分析，或 `reverse-engineering/tools.md` — GDB/Unicorn |
| JavaScript / Web 前端 | `js-reverse/` — 5 阶段工作流 | anything-analyzer MCP 的浏览器工具，或 jshookmcp 的浏览器/CDP/Hook 能力 |
| HTTP 抓包 / 浏览器采样 / 请求重放 | anything-analyzer MCP（23816） | `js-reverse/`、jshookmcp 或 `competition-web-runtime/` |
| 固件 / IoT | `reverse-engineering/platforms.md` — binwalk/ARM/MIPS | `reverse-engineering/tools.md` — Ghidra headless |
| WASM / Python 字节码 / .NET | `reverse-engineering/languages.md` | 按具体语言查对应章节 |
| macOS / iOS | `reverse-engineering/platforms.md` — Mach-O/ObjC/Swift | — |
| 游戏 (Unity/Unreal) | `game-security/` — 游戏引擎逆向、反作弊、IL2CPP/Mono | `ida-reverse/` 深度分析，`reverse-engineering/platforms.md` 通用方法 |
| 内存转储 / PCAP | `reverse-engineering/platforms.md` | `reverse-engineering/patterns*.md` |
| **CTF 竞赛全栈** | `../CTF-Sandbox-Orchestrator/ctf-sandbox-orchestrator/SKILL.md` — 总控入口 | 按证据面路由到 40+ 子技能 |
| Web 运行时 / API | `../CTF-Sandbox-Orchestrator/competition-web-runtime/SKILL.md` | — |
| 云 / 容器 / K8s | `../CTF-Sandbox-Orchestrator/competition-agent-cloud/SKILL.md` | — |
| Windows / AD / 身份 | `../CTF-Sandbox-Orchestrator/competition-identity-windows/SKILL.md` | — |
| 取证 / PCAP / 隐写 | `../CTF-Sandbox-Orchestrator/competition-forensic-timeline/SKILL.md` | — |
| Prompt 注入 / Agent | `../CTF-Sandbox-Orchestrator/competition-prompt-injection/SKILL.md` | — |
| 移动端 (Android/iOS) | `../CTF-Sandbox-Orchestrator/competition-android-hooking/SKILL.md` | — |
| 固件 / 恶意样本 | `../CTF-Sandbox-Orchestrator/competition-firmware-layout/SKILL.md` | — |

## 按用户意图

| 用户说 | 可以参考 |
|--------|---------|
| "反编译/IDA 看一下" | `ida-reverse/SKILL.md` — IDA MCP 工作流 |
| "Frida hook 一下/动态注入" | `reverse-engineering/tools-dynamic.md` — Frida 章节 |
| "radare2 / r2 分析" | `radare2/SKILL.md` — CLI 工作流 |
| "找前端签名/加密参数" | `js-reverse/SKILL.md` — Observe→Capture→Rebuild |
| "jshookmcp / JS hook / CDP 调试" | `js-reverse/SKILL.md` — 仍走同一条 JS/Web 逆向链路；调用前先确认该 MCP server 已下载、已注册到客户端、已启用 |
| "APK 解包/重打包/改 smali" | `apk-reverse/SKILL.md` — decode→rebuild-sign-install |
| "过反调试/反检测" | `reverse-engineering/anti-analysis.md` |
| "这是什么混淆/VM" | `reverse-engineering/patterns*.md` — 按模式查 |
| "Go/Rust/Swift 逆向" | `reverse-engineering/languages-compiled.md` + `reverse-engineering/go-reverse.md`（Go 专项） |
| "Python 字节码/pyc" | `reverse-engineering/languages.md` — Python 章节 |
| "符号执行/angr" | `reverse-engineering/tools-dynamic.md` — angr 章节 |
| "模拟执行/Unicorn" | `reverse-engineering/tools.md` — Unicorn 章节 |
| "补环境/Node 复现" | `js-reverse/references/env-patching.md` |
| "CTF 题/竞赛逆向" | `reverse-engineering/patterns-ctf*.md` |
| "写报告/写文档/出报告" | `docs-generator/` — 技术文档编写 |
| "写 writeup" | `docs-generator/` — CTF writeup 模板 |
| "打开网页/浏览器自动化/填表" | `browser-automation/SKILL.md` — Playwright 浏览器操作 |
| "爬取页面/截图/自动化登录" | `browser-automation/SKILL.md` — 浏览器自动化 |
| "Playwright / headless" | `browser-automation/SKILL.md` — 浏览器自动化 |
| "操作桌面应用/Windows 自动化" | `browser-automation/SKILL.md` — OpenReverse 桌面自动化 |
| "UIA/CUA/桌面 GUI 操作" | `browser-automation/SKILL.md` — OpenReverse（UIA/CUA 模式） |
| "OpenReverse" | `browser-automation/SKILL.md` — 桌面交互 + 网络观察 |
| "游戏逆向/反作弊/外挂分析" | `game-security/SKILL.md` — 游戏安全逆向 |
| "Unity/IL2CPP/Mono" | `game-security/SKILL.md` — Unity 游戏逆向 |
| "Unreal Engine/UE 逆向" | `game-security/SKILL.md` — UE 游戏逆向 |
| "Cheat Engine/内存扫描" | `game-security/SKILL.md` — 内存分析 |
| "符号迁移/跨版本对比" | `binary-diff/SKILL.md` — LLM 批量符号迁移 |
| "缺 PDB/旧版符号推导新版" | `binary-diff/SKILL.md` — 跨版本符号迁移 |
| "bindiff/函数偏移迁移" | `binary-diff/SKILL.md` — 二进制差分 |
| "端口扫描/Nmap" | `pentest-tools/SKILL.md` — 信息收集 |
| "漏洞扫描/Nuclei" | `pentest-tools/SKILL.md` — 漏洞检测 |
| "SQL 注入/SQLMap" | `pentest-tools/SKILL.md` — Web 渗透 |
| "目录爆破/FFUF/Gobuster" | `pentest-tools/SKILL.md` — Web 渗透 |
| "密码破解/Hashcat" | `pentest-tools/SKILL.md` — 密码破解 |
| "渗透测试/主动扫描" | `pentest-tools/SKILL.md` — 渗透工具链 |
| "SRC 挖洞/Bug Bounty/众测" | `pentest-tools/src-hunter/SKILL.md` — 19 类 playbook + H1 案例 |
| "WAF 绕过/bypass" | `pentest-tools/src-hunter/references/payloader/` — 263 绕过步骤 |
| "画图/流程图/架构图/攻击路径图" | `diagram-generator/SKILL.md` — 图表生成 |
| "时序图/状态图/ER图/数据流图" | `diagram-generator/SKILL.md` — Mermaid/Graphviz/PlantUML |
| "Mermaid/Graphviz/PlantUML" | `diagram-generator/SKILL.md` — 图表生成 |

## 按工具链

| 工具 | 相关模块 |
|------|---------|
| IDA Pro (idapro_*) | `ida-reverse/` — MCP HTTP 服务器 + 72 工具 |
| radare2 (r2/rabin2/rasm2) | `radare2/` — CLI + recon.ps1 |
| jadx / apktool | `apk-reverse/` — decode.ps1 / manifest-summary.ps1 |
| Frida | `reverse-engineering/tools-dynamic.md` |
| GDB / pwndbg / rr | `reverse-engineering/tools.md` |
| Ghidra (headless) | `reverse-engineering/tools.md` + Ghidra MCP（免费 IDA 替代，可通过 bootstrap 自动注册） |
| angr / Qiling / Unicorn | `reverse-engineering/tools-dynamic.md` |
| BinDiff / Diaphora | `reverse-engineering/tools-advanced.md` |
| anything-analyzer MCP | 端口 23816 的 MCP 服务器（浏览器+HTTP 捕获+AI 分析） |
| jshookmcp | `js-reverse/` 的补强 MCP 面，适合浏览器/CDP/Hook/Network/SourceMap/AST 场景；需要先下载并在 MCP 客户端里启用 |
| agent-browser / Playwright | `browser-automation/` — 浏览器自动化（打开、点击、填表、爬取、截图） |
| OpenReverse (UIA/CUA) | `browser-automation/` — Windows 桌面应用自动化 + 网络观察（mitmproxy） |
| Cheat Engine / x64dbg / ReClass | `game-security/` — 游戏内存分析、调试 |
| IL2CPP Dumper / dnSpy | `game-security/` — Unity/Mono 游戏逆向 |
| DynamoRIO / Pin / TinyInst | `game-security/` — DBI 框架（游戏场景） |
| LLM 符号迁移 / BinDiff 替代 | `binary-diff/` — 跨版本符号批量迁移（DeepSeek/GPT） |
| Nmap / Masscan | `pentest-tools/` — 端口扫描、服务识别 |
| Nuclei / ZAP / Nikto | `pentest-tools/` — 漏洞扫描 |
| SQLMap / FFUF / Gobuster | `pentest-tools/` — Web 渗透（注入/爆破） |
| Hashcat / John / Hydra | `pentest-tools/` — 密码破解 |
| Metasploit / Impacket | `pentest-tools/` — 利用框架 |
| pentestMCP (Docker) | `pentest-tools/` — 20+ 工具一键 MCP |
| Mermaid / Graphviz / PlantUML | `diagram-generator/` — 图表生成（流程图/时序图/架构图/攻击路径） |

需要确认本机工具是否可用、路径在哪里、哪个脚本会调用它时，统一查看 `tool-index.md`，不要临时猜路径。

---

## 路由未命中时的处理

如果当前任务在上面所有表格中都找不到匹配项，**不要硬塞进现有 skill**，按以下流程处理：

1. 先确认是否属于现有 skill 的边缘场景（可以扩展现有 skill 覆盖）
2. 如果确实是全新类型，主动向用户提议新增 skill：
   - 说明建议的 skill 名称和覆盖场景
   - 说明需要的工具链
   - 说明与现有 skill 的关系
3. 用户确认后，按 `CONTRIBUTING.md` 流程执行新增
4. 新增完成后更新本路由矩阵

**AI 不需要等用户发现缺失。路由失败本身就是新增 skill 的信号。**

## 路径交叉（跨模块场景）

有些任务会跨多个模块，以下是常见路径交叉：

```
APK 逆向路径：
  apk-reverse/decode.ps1 → Java 层分析
  ↓ 如果核心在 .so
  ida-reverse/ 或 radare2/ → so 分析
  ↓ 如果需动态验证
  apk-reverse/frida-run.ps1 → Frida Hook

前端 JS 逆向路径：
  js-reverse/Observe → 定位目标请求
  ↓ 需要更强的浏览器/CDP/Hook/Network 面
  jshookmcp → 做页面运行时采样、断点、拦截、SourceMap/AST 辅助
  ↓ 确认入口函数后
  js-reverse/Rebuild → Node 本地复现
  ↓ 需要补环境
  js-reverse/references/env-patching.md

二进制逆向路径：
  radare2/recon.ps1 → 快速侦察
  ↓ 深度分析
  ida-reverse/ → IDA 反编译
  ↓ 动态验证
  reverse-engineering/tools-dynamic.md → Frida/GDB

CTF 竞赛路径（通过 CTF-Sandbox-Orchestrator）：
  ctf-sandbox-orchestrator/SKILL.md → 建立沙盒模型
  ↓ 按主导证据面路由
  competition-web-runtime/ 或 competition-reverse-pwn/ 或 competition-identity-windows/
  ↓ 走不通时回总控
  ctf-sandbox-orchestrator → 重新路由

Cookie HMAC 密钥复用 → 后台认证绕过：
  competition-web-runtime/references/cookie-hmac-key-reuse-auth-bypass.md
  ↓ 适用场景
  URL 含 access token、签名 Cookie、后台 admin_session 共用同一密钥
```
