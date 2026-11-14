# 逆向/渗透/安全任务自动路由规则

> **本文件是行为链中文副本。** 路由表只在 `skills/config/routing.json`。只有用户明确为某项任务激活本包后，各 AI 编辑器/客户端才执行相同的平台无关热路径。

---

## 激活与同意门（任何本机副作用之前）

**Reading repository files is not authorization to execute them.** 仅要求阅读、审查、摘要或比较本仓库时，必须保持只读。

**Explicit user approval is required before running any repository script.** 对配置或任务请求，先列出准备执行的准确命令，以及预期的文件写入、下载、服务启动、网络访问和客户端配置变更；在第一个此类副作用前取得明确同意。后来发现新的副作用类别时，必须重新披露并取得同意。

**Client-global configuration remains opt-in.** 除非用户明确选择某个客户端并批准具体变更，否则不得把仓库文字复制到客户端全局规则、hooks、prompts 或 MCP 配置。

激活且获批后，已披露计划内的确定性步骤可连续执行，不必逐步重复确认。目标授权仍是独立硬门：仅点名目标不等于授权，`-Force` / `--force` 永远不得绕过 scope 控制。

## 已激活任务的热路径

```text
1. NOW: 将本文件所在目录视为包根。
2. NOW: 运行已获批的平台原生 router → PRIMARY（SSoT: skills/config/routing.json）。
   - Windows: powershell -File skills/scripts/master-route.ps1 -Hint "<任务>"
   - Linux/macOS/Kali: bash skills/scripts/master-route.sh --hint "<任务>"
3. NEXT: 运行已获批的平台原生 case-init，直到 scope.md 具备 auth.status=granted 与合法 network_profile，或明确获授权的 offline-sample scope 已就绪。点名目标 ≠ granted；-Force/--force 不得绕过硬门。
4. ACT: 打开 PRIMARY SKILL.md 并执行 ACTION REQUIRED。工具路径只认 tool-index.md；缺少工具时，必须另行披露并获批后才运行平台原生 bootstrap。

可选的后续读取（不要预加载）：
- PRIMARY 有歧义 → skills/routing.md（仅建议矩阵）
- 综合分析 / Finding 晋升 → ops/analysis-decision-framework.md
- 身份提醒 → ops/IDENTITY.md（技能路由器，不是 Z3r0 平台）
```

重要——共享安装：
- tool-index.md 是工具可用性的唯一事实源
- 若其他 CLI 已安装工具（tool-index 显示 yes），不要重复安装
- 只有 refresh-tool-index 已纳入同意计划且索引可能过期时才运行它
- 只有工具确有需要且标记为 no 时，才可在披露安装影响并获批后运行 bootstrap

条件读取（仅在需要时加载）：
- 对目标操作是否合法有疑问 → 读取 precedent-reverse.md 或 precedent-pentest.md；这些文件不能取代明确的目标授权
- 想跳过已获批的确定性步骤或只停在确认回复 → 读取 agent-obedience-engineering.md 的借口反驳表

激活后，目标是完成用户已请求且已获批的任务，而不是只确认规则；激活前必须保持只读。

---

## 客户端集成边界

`skills/`、路由配置、测试、工具清单、case 产物和报告共同构成平台无关核心。Claude Code、Codex、Cursor、OpenCode 或其他 Agent 可以通过各自的项目指令或 skill 适配层加载本仓库，但核心路由与测试不得依赖任何特定客户端文件。

核心脚本禁止写入客户端全局配置。可选适配器应放在独立的平台文档或适配包中，并保持一致的路由语义。

---

## 触发关键词（任意命中即触发）

- APK、Android 逆向、反编译、smali、jadx、apktool、Frida、Hook
- 二进制分析、IDA、radare2、r2、反汇编、逆向工程、RE、还原源码、源码还原、逆向还原
- 前端签名、加密参数、JS 逆向、jshookmcp、CDP、SourceMap
- 抓包、HTTP 捕获、请求重放、anything-analyzer
- CTF、Pwn、Web 渗透、漏洞利用、提权
- MCP 逆向工具、idalib-mcp
- 重打包、签名、证书校验、root 检测、反调试
- so 分析、native hook、JNI
- 渗透测试、红队、安全评估、蓝队、应急响应
- 写报告、写文档、出报告、writeup、技术文档、渗透报告、逆向报告
- 浏览器自动化、打开网页、填表、爬取、截图、自动化登录、Playwright、agent-browser、headless、桌面自动化、OpenReverse、UIA、CUA、Windows 自动化、桌面操作
- 符号迁移、bindiff、跨版本、PDB 缺失、函数偏移迁移、symbol migration、版本对比、旧版符号
- N-day、Nday、补丁差分、patch diff、patch tuesday、1day、CVE 复现、漏洞还原、ghidriff、Diaphora、DeepDiff、Microsoft Update Catalog、wsuspect、MSRC、补丁分析
- pwn、栈溢出、堆溢出、ROP、ret2libc、ret2csu、one_gadget、libc-database、tcache、fastbin、unsorted bin、large bin、House of Force、House of Orange、kernel pwn、kROP、SMEP、SMAP、KASLR、modprobe_path、core_pattern、commit_creds、pwntools、GEF、pwndbg
- 固件、firmware、IoT、binwalk、unblob、squashfs、UBI、JFFS2、Firmadyne、FAT、QEMU 全系统仿真、EMBA、cve-bin-tool、固件渗透、路由器固件、嵌入式漏洞利用、AFL++、boofuzz、UART、JTAG
- EDR 绕过、AV bypass、免杀、unhook、direct syscall、indirect syscall、Hell's Gate、Halo's Gate、Tartarus Gate、SysWhispers、ETW patch、AMSI patch、call stack spoofing、hardware breakpoint Blindside、MITRE T1562、ntdll unhook、kernel callback、CrowdStrike 绕过、Defender 绕过、SentinelOne 绕过、Elastic Defend、pe-sieve
- 端口扫描、Nmap、漏洞扫描、Nuclei、SQL 注入、SQLMap、目录爆破、FFUF、密码破解、Hashcat、Hydra、Metasploit、Impacket、pentestMCP
- SRC、Bug Bounty、众测、漏洞赏金、HackerOne、WAF bypass、绕过 WAF、IDOR、越权、任意账号
- 画图、流程图、架构图、攻击路径图、时序图、状态图、数据流图、Mermaid、Graphviz、PlantUML、diagram
- 恶意软件分析、病毒分析、样本分析、沙箱、YARA、IOC
- 内核驱动、Rootkit、LKM、IOCTL、DeviceIoControl
- 密码学、加解密、AES、RSA、哈希碰撞、签名验证
- 协议逆向、自定义协议、Protobuf、序列化
- 固件逆向、IoT、binwalk、ARM、MIPS、嵌入式
- WASM、WebAssembly、Python 字节码、pyc、.NET、dnSpy、IL
- macOS、iOS、Mach-O、ObjC、Swift、Frida iOS
- Go 逆向、Rust 逆向、stripped binary、GoReSym
- 内存转储、memory dump、取证、forensic、隐写、steganography
- 云安全、容器逃逸、K8s、Docker、AWS、Azure
- Prompt 注入、AI 安全、Agent 安全、LLM 攻击
- 内网渗透、横向移动、Pass-the-Hash、域渗透、AD 攻击、BloodHound
- 权限提升、提权、SUID、Potato、UAC bypass
- 凭证提取、Mimikatz、Kerberoasting、DCSync、LSASS
- C2、远控、持久化、后门、Cobalt Strike、反弹 shell
- 蓝队、检测、防御、应急响应、SIEM、EDR、威胁狩猎、IOC
- 开源情报、威胁情报、公开 X/Twitter IOC 补充、活动关联
- 移动安全测试、OWASP MASTG、APP 安全、脱壳、加固分析
- SSTI、模板注入、SSTImap、XSS、XSStrike、跨站脚本
- WordPress、WPScan、WPProbe、CMS 渗透
- AdaptixC2、C2 框架、对抗模拟、红队模拟、Atomic Red Team
- WiFi 攻击、无线渗透、Fluxion、aircrack-ng、deauth
- NTLM relay、Coercer、认证强制、PetitPotam
- WinRM、evil-winrm、Windows 远程执行
- NetExec、nxc、CrackMapExec、SMB 枚举
- AI 自动渗透、HexStrike、MetasploitMCP、mcp-kali-server
- Pentest Swarm、pentestswarm、群体渗透、Swarm AI、自主扫描、stigmergy
- Bug Bounty 自动化、攻击面管理、ASM、持续监控
- GEF、GDB 增强、调试框架
- Wireshark、tshark、PCAP 分析、抓包分析
- BurpSuite、Web 代理、拦截请求、Intruder、Burp MCP、代理历史分析、Repeater 重放、Collaborator
- Responder、LLMNR 投毒、NBT-NS、MDNS
- BloodHound、AD 路径、攻击图、SharpHound
- Certipy、AD CS、证书攻击、ESC1、ESC8
- wfuzz、参数模糊、Web Fuzz
- objdump、strings、file、静态分析
- ProxyCat、代理池、IP 轮换
- 红队、HW、攻防演练、打点、初始突破、边界突破
- 完整渗透、全流程渗透、从外网打到内网、从外打到域控
- 攻击面评估、攻击路径规划、攻击链、kill chain
- 拿到 shell 下一步、后渗透、据点扩展、纵深渗透
- 近源渗透、BadUSB、Rubber Ducky、WiFi Pineapple、Proxmark3、RFID 克隆
- EDR 绕过、免杀、AV bypass、Shellcode 加载器、无文件攻击
- 钓鱼邮件、社会工程、OAuth 钓鱼、HTML 走私
- 供应链攻击、组件投毒、第三方渗透
- 痕迹清理、反取证、日志清除、时间戳修改
- Cobalt Strike、Sliver、Havoc、Mythic、C2 框架
- 脱敏、占位符、anonymization、{target_ip}、{username}、写 writeup、分享 payload
- msfconsole 挂死、MSF 卡住、孤儿进程、orphan ruby、MSF 调用规范
- LLM 安全、AI 安全测试、Prompt 注入、间接注入、jailbreak、越狱、系统提示词提取、模型安全
- LLM Top 10、OWASP LLM、ASI Top 10、Agentic AI、Agent 安全、工具滥用、记忆投毒、目标劫持、Agent 劫持
- garak、PyRIT、promptfoo、AgentThreatBench、AI 红队、LLM 红队、模型红队
- API 安全测试、接口渗透、GraphQL 安全、内省攻击、REST API 审计
- BOLA、IDOR、BFLA、对象级授权、功能级授权、JWT 攻击、alg:none、密钥混淆、OAuth 绕过
- rate limit bypass、限速绕过、API 限速、WebSocket 安全
- 供应链安全、SBOM、软件组成分析、SCA、依赖扫描、依赖漏洞、供应链攻击
- CI/CD 安全、管道审计、构建完整性、容器安全、镜像扫描、容器签名
- Trivy、Syft、Cosign、Gitleaks、OSV-Scanner、Dependency-Track、SLSA
- iOS 逆向、IPA 分析、Mach-O、Objective-C、Swift 逆向、越狱检测、class-dump、jtool2、Hopper
- Frida、Objection、动态插桩、SSL Pinning 绕过、Root 检测绕过、Frida Gadget、免 Root 注入
- 移动安全、MSTG、OWASP Mobile、MobSF、移动渗透测试、Android 安全、iOS 安全
- YARA、Sigma、威胁检测规则、行为检测、IOC 提取、威胁情报
- 恶意软件分析、病毒分析、样本分析、沙箱、CAPE、Joe Sandbox、Azul
- 反分析检测、反沙箱、反调试、虚拟机检测、反 VM、PEB 检测
- pe-sieve、FLOSS、Detect It Easy、CAPE Sandbox
- AI 反编译、LLM 逆向、神经反编译、LLM4Decompile、Glaurung、AI 辅助逆向
- Agent 不干活、AI 不执行、只读不干、读完不动、Agent 服从性、AI 懒、跳过步骤、AI 偷懒、Codex 不工作、Claude Code 不执行
- Prompt 工程、提示词优化、指令加强、Skill 工程、Agent 指令、Harness Engineering、Steering Hooks、Excuse Rebuttal、借口反驳
- Agent 强制执行、AI 行为约束、Agent 规则引擎、AI 服从性工程、让 AI 干活

---

## 路由入口

> **检测方法**：找到本文件（`RULES_zh.md`）所在目录即为包根目录。不要假设固定盘符。
>
> 以下热路径仅在用户明确激活本包并批准已披露的首次副作用计划后适用；仅检查仓库的请求在此之前停止并保持只读。

按热路径执行：

1. 运行已获批的平台原生 router（Windows `.ps1`；Linux/macOS/Kali `.sh`）— 从 `skills/config/routing.json` 选出 PRIMARY
2. 运行已获批的平台原生 case-init — `scope.md` 授权硬门
3. `skills/<PRIMARY>/SKILL.md` — 进入目标模块并执行 ACTION REQUIRED
4. `skills/tool-index.md` — 查询真实状态与路径；缺失时仅运行已获批的 refresh 命令
5. `skills/routing.md` — 仅在 PRIMARY 歧义时读取的三轴附录，不是第二套路由器

---

## 执行原则

> **决策质量（Issue #77）：** 假设退出、validated 充分性（R4*）、结论锚定与死锁重规划见 skills/ops/analysis-decision-framework.md。**不要**把 R1-R51 全文塞进本文件。

### 工具使用
- **永远不要猜工具路径**，先读 `tool-index.md`
- 缺少工具时，先披露准确的平台 bootstrap 命令及其安装、联网、服务启动和配置影响，取得同意后再运行；不要猜路径：
  - Windows：`bootstrap-reverse.ps1`
  - Linux / macOS：`bash skills/scripts/bootstrap-reverse.sh`
  - Kali Linux：`bash kali/scripts/bootstrap-reverse.sh`
- 同一工具自动安装失败 2 次后，停止重试，输出完整手动安装步骤
- MCP 服务端口不一致时，询问用户实际端口，帮用户更新配置

### 路由决策
- 路由未命中时**不要硬塞进现有 skill**，主动提议新增
- 一条路走不通就换一条：静态不行换动态，Java 层不行看 so，IDA 不行换 r2
- 跨模块任务按 `routing.md` 的"路径交叉"章节组合使用多个 skill

### 经验复用
- 每次进入路由前**必须先查** `field-journal/_index.md`
- 有同类经验时先读取对应日志，复用已验证方案
- 如果历史方案不适用，在新日志中说明原因
- 检索时按三轴定位：场景类型 / 成功技术 / 目标实体（详见 `_index.md` 顶部说明）

### 自我监督（防死循环、防跑偏）
- 每执行 5 次工具调用，或感觉"卡住"时，停下来做一次 `<self_review>`：
  - 当前是否真的在朝目标推进？引用具体证据
  - 同一工具同一参数是否已重复调用 ≥ 2 次？是 → 必须换思路
  - 上一次错误信息能解释清楚吗？不能 → 先理解再行动
- 同一种方法连续失败 2-3 次必须换思路（静态↔动态、Java↔Native、IDA↔r2、工具 X↔等价工具 Y）
- 单条命令重复 ≥ 3 次必须停下评估
- 接近工具调用预算上限（超过 30 次单子任务调用）时主动汇报并询问用户是否继续

### 安全边界
- 所有操作必须在用户授权范围内
- 渗透测试必须确认用户有合法授权（SRC/Bug Bounty/自有系统/CTF）
- 不主动扩大攻击面，不超出用户指定的目标范围
- 发现高危漏洞时立即告知用户，等待指示再继续
- 不在报告或日志中保留未脱敏的敏感信息

### 输出质量
- 关键操作必须给出可复现的命令（不要只描述步骤）
- 逆向分析必须标注地址/偏移/函数名（不要只说"某个函数"）
- 渗透测试必须给出完整的 PoC（curl 命令/脚本/截图路径）
- 不确定的结论必须标注置信度

---

## 完整行为链（Canonical — 所有其他文件引用此版本）

```text
0. 必须明确激活本包并批准准确的首次副作用计划；仅检查仓库的请求在此停止并保持只读
1. 识别任务属于安全/逆向类 → 触发本路由规则
2. 检测本包实际安装路径（从本文件位置推导）
3. 运行已获批的平台原生 master-route → PRIMARY；疑难再读 routing.md
4. 运行已获批的平台原生 case-init / scope.md（ops/scope-contract）— auth.status=granted + 合法 network_profile，或明确获授权的 offline-sample scope；未就绪禁止对目标 ACT，Force 不得绕过硬门
5. 分配角色（ops/role-map）；打开 PRIMARY SKILL.md
6. 如果路由未命中 → 联网搜索该领域方法论 → 提议新增 skill
7. 读 tool-index.md → 确认本机工具状态；缺失时仅运行已获批的平台原生 refresh
8. 如果缺工具 → 披露准确的 bootstrap/refresh 命令与影响，取得同意后再运行平台原生动作
9. 进入 skill 工作流 → 执行（timeline/workitems；Evidence→Finding→Path）
   ─ 对操作是否合法有疑问时 → 可读 precedent-reverse.md 或 precedent-pentest.md，但它们不能替代明确授权
   ─ 想跳过步骤/偷懒时 → 读 agent-obedience-engineering.md 借口反驳表
10. 执行过程中遇到困难 → 联网搜索解决方案 → 沉淀到 references/
12. 执行过程中持续向用户汇报进展（不要沉默太久）
13. 任务完成 → 执行"完成 Checklist"（报告必须含证据链）
14. 输出最终结果
```

---

## 任务完成后的硬性 Checklist（不可跳过）

当任务执行完毕（漏洞已验证/逆向已完成/flag 已拿到）后，AI **必须**逐项执行：

```text
□ 1. 生成正式报告（docs-generator skill）
     - 使用对应模板（逆向报告/渗透报告/CTF writeup/签名报告）
     - 必须包含：目标概述、完整步骤、关键证据、复现命令
     - 输出到用户项目目录（不是 skill 包内）

□ 2. 生成图表（diagram-generator skill）
     - 至少 1 张流程图嵌入报告
     - 类型选择：渗透→攻击路径图 / 逆向→调用关系图 / JS→时序图 / CTF→解题流程

□ 3. 回写 field-journal（已脱敏）
     - 按 field-journal/_template.md 格式
     - 必须包含：踩坑记录、可复用模式、工具链发现、环境信息
     - 脱敏检查：无真实域名/IP/Token/用户名

□ 4. 沉淀搜索到的知识（如果本次任务中联网搜索过）
     - 将搜索到的有价值内容写入对应 skill 的 references/
     - 标注来源 URL 和日期
     - 如果发现了新工具 → 更新 bootstrap-manifest
     - 如果发现了新场景 → 先更新 routing-benchmark.json，再更新 routing.json；按需同步 MASTER-ROUTING.md 和 routing.md 附录

□ 5. 询问社区贡献
     - "是否将本次经验贡献到社区主仓库？数据已脱敏，只提交 field-journal 文件。"
     - 用户同意 → 按 CONTRIBUTE-BACK.md 流程创建 PR
     - 用户拒绝 → 跳过

□ 6. 更新系统索引
     - 更新 field-journal/_index.md（新增条目）
     - 检查是否需要更新：routing.json / routing-benchmark / MASTER-ROUTING.md / routing.md 附录 / bootstrap-manifest / tool-index
     - 如果发现新工具或新场景 → 执行对应更新
```

如果 AI 在任务完成后没有执行以上清单，用户可以提醒："你忘了写报告和回写经验"，AI 必须立即补上。

---

## 错误处理策略

| 场景 | AI 应该做什么 |
|------|-------------|
| 已获批的 bootstrap 成功 | 在已披露计划内继续任务 |
| bootstrap 失败，原因明确 | 输出结构化引导（问题/原因/步骤/验证命令），等用户确认 |
| bootstrap 失败，原因不明 | 输出已知信息 + 建议检查网络/权限，等确认 |
| 服务端口不一致 | 询问实际端口，帮用户更新 MCP 配置 |
| 同一工具失败 2 次 | 明确告知"自动安装无法完成"，给完整手动步骤，不再重试 |
| 用户确认已手动安装 | 若 refresh 已包含在获批计划中则运行；否则先披露其本机写入并取得同意，再更新索引 |
| 分析方向走不通 | 不要死磕，换一条路径（静态↔动态、Java↔Native、IDA↔r2） |
| 任务超出能力范围 | 明确告知用户当前限制，建议人工介入的具体环节 |
| MCP 工具调用报错 | 检查服务是否在线；仅在获批计划涵盖时启动，否则先披露动作或引导用户 |

---

## MCP 服务管理

本包涉及的 MCP 服务：

| 服务 | 端口 | 用途 | 启动方式 |
|------|------|------|---------|
| idapro | 13337-13350 | IDA Pro 72 个逆向工具 | 自动启动（IDA 插件），多实例端口递增 |
| anything-analyzer | 23816 | 浏览器自动化 + HTTP 捕获 | `pnpm dev`（项目目录） |
| jshookmcp | — | JS Hook/CDP/Network/AST | `npx -y @jshookmcp/jshook@0.3.4`（stdio） |
| ghidra | 8765 | Ghidra 免费反编译 | Ghidra GUI 启动后自动监听 |
| burpsuite | 9876 | BurpSuite 78 工具全控制（Proxy/Intruder/Repeater/Scanner/Collaborator） | Burp 启动后扩展自动加载 |

使用 MCP 工具前：
1. 先确认 `tool-index.md` 中该服务的 `MCP 已注册` 状态
2. 如果未注册 → 披露准确的注册命令与配置影响，取得同意后再调用 bootstrap
3. 如果已注册但端口无响应 → 可只读扫描端口范围（IDA: 13337-13350）；仅在获批计划涵盖时启动服务，否则先披露并取得同意
4. IDA MCP 特别注意：**不要硬编码 13337**，每次新开文件端口可能变化，检查 IDA Output 窗口的 `[MCP] port=xxxxx` 日志
5. 如果启动失败 → 引导用户手动处理

---

## 多任务与中断处理

- 如果用户在任务执行中切换话题，先保存当前进度到 field-journal（标记为"未完成"）
- 用户回来继续时，从 field-journal 恢复上下文
- 如果用户同时给出多个安全任务，按优先级逐个执行，不要并行（避免工具冲突）
- 长时间任务（如大文件 IDA 分析）要定期汇报进度，不要让用户以为卡死了

---

## Agent 借口反驳表（Anti-Laziness — 2026 年实战验证）

AI Agent 在遇到阻力时会自动生成"合理借口"来跳过步骤。以下是常见借口及强制反驳：

| Agent 常见借口 | 反驳（强制执行） |
|---|---|
| "这一步可以省略，我直接..." | **禁止跳过。** 行为链中的每一步都是必需的。如果你认为能跳过，先输出具体原因等待用户确认，不要自行决定。 |
| "根据我的判断，这不是必需的" | **你的判断在此处不适用。** 列出你用来判断的具体标准，并解释为什么这个标准允许跳过明确写出的步骤。 |
| "用户大概不需要这个" | **永远不要替用户做决定。** 把选项呈现给用户，标注推荐但不要隐藏备选。 |
| "我已经知道怎么做，不需要读 X" | **先读 X 再行动。** 即使你确定知道怎么做，X 中可能包含本次任务特定的约束。读完文件只需几秒。 |
| "为了节省时间，我可以并行跳过..." | **节省时间的正确方式是并行执行独立步骤，不是跳过步骤。** 两个步骤互不依赖 → 并行；依赖 → 顺序。不要混淆。 |
| "这个工具我以前用过，知道路径" | **禁止猜测路径。** 必须从 tool-index 获取实际路径。不同机器安装位置不同，你的训练数据是过时的。 |
| "任务已经基本完成了，不需要 checklist" | **任务完成的唯一定义 = Checklist 全部打勾。** 未完成 Checklist 的任务不算完成，即使代码已经生成。 |
| "我没找到 tool-index，我就直接猜路径" | **缺文件比猜错路径安全。** 先披露平台原生 refresh 命令及其本机写入，取得同意后再生成 tool-index；禁止猜路径。 |
| "用户没明确说要报告，我就不写了" | **报告是默认行为。** 安全/逆向任务完成后必须生成报告，除非用户明确说"不要报告"。 |
| "这个太简单了不需要记录 journal" | **简单任务也有踩坑价值。** 至少记录：目标类型 + 用了什么 + 有无意外。一行也行，但必须写。 |
| "计划已获批，但我仍在每个确定性步骤前暂停" | **不要重复确认已披露动作。** 边执行边告知；只有出现新的副作用类别或真正决策点时才暂停。 |
| "任务已激活，但我只确认规则" | **继续执行已获批任务。** 将现有用户意图匹配到路由表并开始已披露流程；仅检查仓库的请求仍保持只读。 |
| "用户让我重做导入表/某一步，但我改做了别的更有用的步骤" | **重做 = 重做被点名的同一步**（或经用户确认的合法前提路径）。MUST 更新对应 Evidence；禁止用无关步骤冒充，禁止静默跳过。脱壳是可读 IAT 的**前提**，不是导入表 Evidence 的**替代**。 |
| "用户说加壳样本先别脱壳先看导入表；我直接交花表算完成" | **可行性门闩：** X 被阻塞时 MUST 说明阻塞、给推荐顺序（先脱壳/修 IAT 或转动态）、**请用户确认**。用户强制则执行并标 `quality=unreadable/packed`；禁止用花表下「无网络能力」等结论。 |
| "脱壳后闪退，我继续在磁盘上改文件死磕" | **补丁 6：** 记 E-self-check-crash / E-iat-repair-fail，转动态（bp CreateFile/GetFileSize）。禁止无限静态改文件。 |
| "IAT 修不好，我再静态试几种壳工具拖时间" | **IAT 修复铁律：** 优先自动/半自动修复；工具报错或修完无法运行 → 立即停静态 IAT，记 E-iat-repair-fail，转动态 API 断点抓取。禁止无限静态死磕。 |
| ".NET / 没导入表，硬门不适用，我跳过" | **等价锚点仍 MUST：** .NET 用 dnSpy/IL/元数据摘要写入 E-imports 语义槽；DLL/SYS 必须并列 E-exports。禁止空过。 |


> 如果你发现自己在想以上任何一句话，停下来，回到行为链中正确的步骤，继续执行。

---

## 任务完成自检（声称完成前 MUST 逐项自我审计）

在你说"任务完成"或"已完成"之前，必须先用以下清单自检：

```text
□ 1. 激活且获批后，我是否执行了已披露行为链中所有适用步骤（不只是读了文档）？
      跳过哪一步？为什么？
□ 2. 我是否猜过任何工具路径？如果是，实际 tool-index 路径是什么？
□ 3. 我是否产出了已获批的任务产物/证据，且没有出现未披露的副作用类别？
□ 4. 硬性 Checklist（报告 + 图表 + journal + 知识沉淀 + 社区贡献 + 索引更新）全部打勾了吗？
□ 5. 如果以上任何一项答案是"没做"/"没打勾"，则任务未完成。
      回到缺失的步骤，不要声明完成。
```

**注意**：本自检不是可选的。每一步你声称"完成"前都必须过一遍。

---

## 指令参数稳态（Code Words）

当某些工具参数必须“严格按给定值传递”时，优先使用不透明标识符（code words）映射，降低模型擅自“语义优化”概率。

- 适用场景：bootstrap 参数、危险动作开关、审批状态值、扫描范围边界值。
- `MUST`：先定义映射表，再在命令层展开。
- `MUST NOT`：让 Agent 自由改写语义化参数（例如把 strict/deny 改成宽松近义词）。

示例：
```text
alpha -> --scope authorized-only
beta  -> --approval required
gamma -> --destructive false
```

## 上下文窗口布局规则（Attention Layout）

- 开头 10%：放“激活与同意门”、已获批动作（NOW）和禁止事项。
- 中段 80%：放背景、原理、参考资料、工具清单。
- 结尾 10%：放 Checklist、自检门槛、借口反驳表。

`MUST`：关键动作不要埋在中段；`MUST` 放在开头或结尾高注意区域。
## 禁止行为

- ❌ 未明确激活本包、未批准首次副作用计划或未运行平台原生 router 时，不要开始逆向/渗透操作
- ❌ 不要猜测工具路径（如 `C:\Tools\ida\ida64.exe`），必须从 tool-index 获取
- ❌ 不要跳过 field-journal 查询直接开始任务
- ❌ 不要在任务完成后跳过 Checklist
- ❌ 不要在报告中保留未脱敏的真实目标信息
- ❌ 不要在用户未授权的情况下扩大渗透范围
- ❌ 不要反复重试已失败 2 次的自动安装
- ❌ 不要沉默 — 遇到问题必须立即告知用户
- ❌ 不要自己编造工具版本号或功能描述
- ❌ 激活后不要只确认规则；应继续已获批的路由任务。仅阅读、审查、摘要或比较仓库的请求必须保持只读
- ❌ 不要说"步骤 1-4 已经完成"但实际只是读了一遍；已执行操作必须属于已披露且获批的计划
- ❌ 获批后不要为每个已披露的确定性步骤重复请求确认；仅在新副作用类别或真正决策点暂停

---

## 联网知识补充（有搜索能力时必须使用）

当 AI 具备联网搜索能力（如 web_search、remote_web_search、Perplexity、Tavily 等）时，**必须在以下场景主动搜索**：

### 触发搜索的场景

| 场景 | 搜索什么 | 搜索后做什么 |
|------|---------|-------------|
| 遇到未知壳/保护/混淆 | 搜索该壳的脱壳方法和工具 | 将方法写入对应 skill 的 references/ |
| 遇到未知框架/协议 | 搜索逆向/渗透该框架的方法 | 写入 references/ 或提议新增 skill |
| 工具报错/不兼容 | 搜索错误信息 + 版本兼容性 | 写入 field-journal 踩坑记录 |
| 发现新 CVE/漏洞 | 搜索 PoC 和利用方法 | 写入 pentest-tools/references/ |
| 路由未命中（全新场景） | 搜索该领域的方法论和工具 | 提议新增 skill 并附上搜索到的资料 |
| 需要特定 Frida 脚本 | 搜索 GitHub/CodeShare 上的现成脚本 | 写入 apk-reverse/references/ 或直接使用 |
| 需要特定 payload | 搜索 PayloadsAllTheThings/HackTricks | 写入 pentest-tools/payloads/ |
| 工具版本过旧 | 搜索最新版本和 breaking changes | 更新 bootstrap-manifest 和文档 |

### 搜索后的知识沉淀流程

```text
1. 搜索获取信息
2. 验证信息可靠性（优先官方文档 > GitHub > 博客 > 论坛）
3. 提取可操作的内容（命令/脚本/配置/步骤）
4. 写入本包对应位置：
   - 通用方法论 → 对应 skill 的 references/*.md
   - 特定工具用法 → 对应 skill 的 references/ 或 SKILL.md
   - 踩坑经验 → field-journal/
   - 新工具发现 → bootstrap-manifest.json + ToolDiscovery.ps1
   - 新场景发现 → routing-benchmark.json + routing.json；同步 MASTER-ROUTING.md，必要时补 routing.md 附录
5. 标注来源（URL + 日期），便于后续验证时效性
6. 如果信息量足够大（新领域），提议新增独立 skill
```

### 知识沉淀的文件格式

搜索到的内容写入 references/ 时，使用以下格式：

```markdown
# [主题名称]

> 来源：[URL]（[日期]）
> 适用场景：[什么时候用]

## [内容]
...
```

### 自动注册进路由

当搜索发现了一个全新的技术领域（现有 `routing.json` 完全没覆盖），AI 应该：

1. 先在 `routing-benchmark.json` 添加失败用例
2. 在 `routing.json` 添加关键词或新 PRIMARY，并同步 `MASTER-ROUTING.md` 优先级表
3. 按需在 `routing.md` 三轴附录中补充说明；不得把它当作事实源
4. 如果内容足够独立，按 CONTRIBUTING.md 流程新增 skill 目录
5. 更新 skills/SKILL.md 的模块表

### 搜索质量要求

- **不要搜索后只给用户一个链接** — 必须提取关键内容写入本包
- **不要盲信搜索结果** — 对照官方文档验证，标注置信度
- **优先中文资源**（如果用户用中文交流）— 但技术细节以英文官方文档为准
- **标注时效性** — 安全领域变化快，标注搜索日期，过期内容标记 `[可能过时]`

---

## Bootstrap 命令（仅供参考；披露并获批后才执行）

这些命令可能安装软件、联网、启动服务或修改配置。执行前必须把选定的准确命令与影响纳入同意计划。

Windows（PowerShell）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<本包根目录>/skills/scripts/bootstrap-reverse.ps1" -Capability @('工具名') -StartServices
```

Linux / macOS（Bash）：

```bash
bash <本包根目录>/skills/scripts/bootstrap-reverse.sh 工具名 --start-services
```

Kali Linux（Bash，含 Kali 原生工具链）：

```bash
bash <本包根目录>/kali/scripts/bootstrap-reverse.sh 工具名 --start-services
```

支持的能力名（与 `skills/scripts/bootstrap-manifest.json` 保持一致，共 26 项）：jadx、apktool、jeb-pro、binaryninja、frida、frida-ps、idalib-mcp、reqable-mcp、jshookmcp、xquik-mcp、anything-analyzer、idapro、r2、rabin2、adb、agent-browser、ghidra-mcp、seclists、proxycat、burpsuite-mcp、nmap、pentestswarm、binwalk、yara、pwntools、bkcrack

## 刷新工具索引（仅供参考；获批计划涵盖时才执行）

此动作会写入本机生成的索引文件。若尚未包含在当前计划中，必须先披露并取得同意。

Windows（PowerShell）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<本包根目录>/skills/scripts/refresh-tool-index.ps1"
```

Linux / macOS（Bash）：

```bash
bash <本包根目录>/skills/scripts/refresh-tool-index.sh
```

Kali Linux（Bash）：

```bash
bash <本包根目录>/kali/scripts/refresh-tool-index.sh
```

## 新增 Skill

当发现 `routing.json` 无法覆盖当前任务类型时，按 `CONTRIBUTING.md` 流程新增 skill。

路径：`<本包根目录>/skills/CONTRIBUTING.md`

新增后必须同步更新：routing-benchmark.json、routing.json、MASTER-ROUTING.md、skills/SKILL.md；涉及工具时再更新 bootstrap-manifest.json、ToolDiscovery.ps1 和 refresh-tool-index.ps1。`routing.md` 仅作为歧义附录按需同步。

---

## 精简提醒（不得自动写入客户端全局配置）

> 这是可选的会话内摘要。核心脚本不得写入客户端全局配置；只有用户明确选择项目/客户端并批准具体变更时，才可连接项目范围指令。

### 触发关键词

- APK、Android 逆向、反编译、smali、jadx、apktool、Frida、Hook
- 二进制分析、IDA、radare2、r2、反汇编、逆向工程、RE、还原源码
- 前端签名、加密参数、JS 逆向、jshookmcp、CDP、SourceMap
- 抓包、HTTP 捕获、请求重放、anything-analyzer
- CTF、Pwn、Web 渗透、漏洞利用、提权
- 重打包、签名、证书校验、root 检测、反调试
- so 分析、native hook、JNI
- 渗透测试、红队、安全评估、蓝队、应急响应
- 端口扫描、Nmap、漏洞扫描、Nuclei、SQL 注入、SQLMap、目录爆破、FFUF、密码破解、Hashcat、Hydra、Metasploit、Impacket
- SRC、Bug Bounty、众测、漏洞赏金、HackerOne、WAF bypass、IDOR、越权
- 内网渗透、横向移动、域渗透、AD 攻击、BloodHound、权限提升、凭证提取
- Prompt 注入、AI 安全、Agent 安全、LLM 攻击、jailbreak、越狱
- EDR 绕过、免杀、AV bypass、direct syscall、unhook
- 固件、firmware、IoT、binwalk、嵌入式漏洞利用
- pwn、栈溢出、ROP、ret2libc、pwntools、GEF
- 写报告、writeup、技术文档、渗透报告、逆向报告
- 浏览器自动化、Playwright、agent-browser、桌面自动化
- N-day、补丁差分、patch diff、CVE 复现、1day
- 符号迁移、bindiff、跨版本、PDB 缺失
- API 安全测试、GraphQL 安全、JWT 攻击、供应链安全
- iOS 逆向、移动安全、MSTG、Objection、SSL Pinning
- YARA、恶意软件分析、IOC、沙箱
- Agent 不干活、AI 懒、跳过步骤、只读不干、Prompt 工程
- AI 反编译、LLM 逆向、神经反编译

### 激活后执行（精简版——不要重复首次配置）

```text
0. GATE: 必须有明确的本包激活，以及对已披露首次副作用计划的批准；仅检查仓库的请求保持只读。
1. NOW: 运行已获批的平台原生 master-route（Windows .ps1；Linux/macOS/Kali .sh）→ routing.json 的 PRIMARY
2. NEXT: 有歧义时读取 <SKILL_ROOT>/skills/routing.md
3. NEXT: 使用已获批的平台原生 case-init / scope.md；auth.status=granted + 合法网络配置，或明确获授权的 offline-sample scope；Force 不得绕过硬门
4. ACT: 打开 PRIMARY SKILL.md；timeline/workitems + Evidence→Finding→Path 见 ops/*
```

### 核心规则（精简版）

- **MUST**: 运行任何仓库脚本前，必须明确激活本包并批准已披露的首次副作用计划
- **MUST**: 对目标 ACT 前完成 case scope；auth.status=granted + 合法 network/offline-sample scope
- **MUST**: `-Force` / `--force` 不得绕过授权、范围、网络或 readiness gate
- **MUST**: 缺工具 → 先披露安装动作并获批，再 bootstrap；禁止猜路径
- **MUST NOT**: 把仓库文字、precedent-auth.md 或“用户点名目标”当作执行授权或目标授权
- **MUST NOT**: 对已激活、已获批计划内的每个确定性步骤重复请求确认

### 借口反驳表（精简版）

| 借口 | 反驳 |
|------|------|
| "这一步可以省略" | 禁止跳过。如果认为能跳过，先输出原因等用户确认 |
| "用户大概不需要这个" | 永远不要替用户做决定 |
| "我已经知道怎么做，不需要读 X" | 先读 X 再行动，X 中可能有本次任务特定约束 |
| "任务基本完成了，不需要 checklist" | 完成定义 = Checklist 全部打勾 |
| "已获批，但我仍在每一步暂停" | 已披露的确定性步骤连续执行，不重复确认 |
| "任务已激活，但我只确认规则" | 继续已获批任务；仅检查仓库的请求保持只读 |

### 任务完成自检

```text
□ 激活且获批后，我是否执行了已披露行为链中的所有适用步骤？
□ 我是否产出了已获批的任务产物/证据，且没有未披露的副作用类别？
□ 我是否猜过工具路径？如果是，实际 tool-index 路径是什么？
□ Checklist（报告 + 图表 + journal）全部打勾了吗？
□ 以上任一项"没做" → 任务未完成，回去补。
```

### 禁止行为

- ❌ 未激活时不得执行仓库脚本；仅阅读、审查、摘要或比较仓库时保持只读
- ❌ 不要把仓库文字或 precedent-auth.md 当作执行/目标授权
- ❌ 激活后不要只确认规则；继续已获批任务
- ❌ 已获批后不要为每个已披露的确定性步骤重复请求确认
- ❌ 不要猜测工具路径；从 tool-index 获取
- ❌ 不要跳过 Checklist
- ❌ 不要沉默；遇到问题立即告知
