# Cybersecurity Skills Router — Kali Linux 专供版

> 本目录是 Kali Linux 2026.1 优化适配层。基于 2026 年 3 月发布的 Kali 2026.1（内核 6.18）进行专项优化。
> 核心知识库（skills/、CTF-Sandbox-Orchestrator/）与 Windows 版共享；Kali 专属 README 和 Bash 入口需要覆盖 Windows 核心能力名，同时额外提供 Kali 原生工具/MCP 能力。  
> 根目录 [README-kali.md](../README-kali.md) 仅为短跳转，**以本文件为准**。

---

## AI：读完后立即执行

```text
1. 检测包根目录（含 skills/ 与 kali/ 的仓库根）
2. 读取 kali/RULES-kali.md → 全局注入与工具扫描
3. bash kali/scripts/refresh-tool-index.sh
4. 与主包共用作战链：
   - skills/MASTER-ROUTING.md（或 pwsh skills/scripts/master-route.ps1）
   - skills/scripts/case-init.ps1 → work/<case>/scope.md
   - auth.status=granted + network_profile 后才对目标 ACT
   - skills/ops/（证据链 / 角色 / 时间线 / IDENTITY）
5. 向用户报告配置结果
```

通用 Agent 引导见仓库根 [README_AI.md](../README_AI.md)（检测到 Kali 时再读本文件）。

---

## 0. 与 Windows 版的关系（能力名对齐）

```text
项目根目录/
├── skills/                    # 共享：SKILL、routing、MASTER-ROUTING、ops、scripts、field-journal
├── CTF-Sandbox-Orchestrator/  # 共享：40+ CTF 子技能
├── kali/                      # ← 你在这里
│   ├── scripts/
│   │   ├── bootstrap-reverse.sh
│   │   ├── refresh-tool-index.sh
│   │   ├── bootstrap-manifest.json
│   │   └── lib/
│   │       └── tool-discovery.sh
│   ├── RULES-kali.md
│   └── README-kali.md
├── RULES.md                   # Windows 版规则
└── Readme.md                  # Windows 版说明
```


### 0.1 对齐原则

Kali 专属入口不是 Windows README 的简单复制，而是 **同一套核心能力名 + Kali 额外能力**：

- Windows：`skills/scripts/bootstrap-reverse.ps1`
- Kali：`kali/scripts/bootstrap-reverse.sh`
- 普通 Linux/macOS：`skills/scripts/bootstrap-reverse.sh`

Kali 脚本应覆盖 Windows manifest 中的核心能力名，例如 `jadx`、`apktool`、`frida`、`jshookmcp`、`anything-analyzer`、`idapro`、`r2`、`adb`、`ghidra-mcp`、`seclists`、`burpsuite-mcp`、`nmap`、`pentestswarm`；同时可以额外支持 Kali 原生工具，例如 `mcp-kali-server`、`metasploitmcp`、`hexstrike-ai`、`sstimap`、`xsstrike`、`netexec` 等。

**共享的部分**（不需要改动）：
- 所有 `SKILL.md`、`routing.md`、`MASTER-ROUTING.md`
- `skills/ops/` 作战契约（scope / 证据链 / 角色 / 时间线）
- 所有 `references/` 知识库
- `field-journal/` 自进化机制
- `CTF-Sandbox-Orchestrator/` 全部
- `docs-generator/`、`diagram-generator/`
- `skills/scripts/case-init.ps1`、`master-route.ps1`（可用 pwsh 调用）

**Kali 专属的部分**：
- 脚本全部是 bash（`.sh`）
- 包管理走 `apt`
- 路径约定为 Linux 风格（`/opt/`、`~/tools/`、`/usr/bin/`）
- 大量工具 Kali 预装，bootstrap 逻辑大幅简化

---

## 1. Kali 的天然优势

以下工具在 Kali 2026.1 中**开箱即用**（无需 bootstrap）：

### 经典预装工具

| 工具 | Kali 包名 | 状态 |
|------|----------|------|
| nmap | nmap | 预装 |
| sqlmap | sqlmap | 预装 |
| hashcat | hashcat | 预装 |
| john | john | 预装 |
| hydra | hydra | 预装 |
| metasploit | metasploit-framework | 预装 |
| gobuster | gobuster | 预装 |
| ffuf | ffuf | 预装 |
| radare2 | radare2 | 预装 |
| binwalk | binwalk | 预装 |
| frida | python3-frida-tools | 预装或 pip |
| burpsuite | burpsuite | 预装 |
| wireshark | wireshark | 预装 |
| nikto | nikto | 预装 |
| wfuzz | wfuzz | 预装 |
| impacket | impacket-scripts | 预装 |
| netexec | netexec | 预装 |
| responder | responder | 预装 |
| aircrack-ng | aircrack-ng | 预装 |
| bloodhound | bloodhound | apt 可装 |
| ghidra | ghidra | apt 可装 |

### Kali 2026.1 新增工具（2026年3月）

| 工具 | 包名 | 用途 |
|------|------|------|
| AdaptixC2 | adaptixc2 | 后渗透与对抗模拟框架 |
| Atomic-Operator | atomic-operator | 跨平台 Atomic Red Team 测试执行 |
| Fluxion | fluxion | WiFi 安全审计与社会工程 |
| GEF | gef | GDB 现代化增强调试框架 |
| MetasploitMCP | metasploitmcp | Metasploit 的 MCP Server 接口 |
| SSTImap | sstimap | 服务端模板注入自动检测与利用 |
| WPProbe | wpprobe | 快速 WordPress 插件枚举 |
| XSStrike | xsstrike | 高级 XSS 扫描器 |

### Kali 2025.4 新增工具（2025年12月）

| 工具 | 包名 | 用途 |
|------|------|------|
| evil-winrm-py | evil-winrm-py | Python 版 WinRM 远程命令执行 |
| hexstrike-ai | hexstrike-ai | AI MCP 安全自动化平台（150+ 工具） |
| bpf-linker | bpf-linker | BPF 静态链接器 |

### Kali 原生 MCP 工具（重点优化）

| 工具 | 包名 | 用途 | 安装 |
|------|------|------|------|
| mcp-kali-server | mcp-kali-server | Kali 官方 MCP，AI 直接调用终端工具 | `apt install mcp-kali-server` |
| MetasploitMCP | metasploitmcp | Metasploit MCP 接口 | `apt install metasploitmcp` |
| HexStrike AI | hexstrike-ai | 150+ 安全工具 MCP 自动化 | `apt install hexstrike-ai` |

> **这是 Kali 版相比 Windows 版最大的优势**：三个 MCP 工具直接 apt 安装，无需手动配置 GitHub/npm/Docker。

这意味着 `bootstrap-reverse.sh` 在 Kali 上的工作量远小于 Windows 版。

---

## 2. 快速开始

### 2.0 一键初始化（推荐新系统使用）

```bash
# 全新 Kali 2026.1 系统一键配置（需要 root）
sudo bash kali/scripts/quick-setup.sh

# 跳过系统更新（网络慢时）
sudo bash kali/scripts/quick-setup.sh --skip-update

# 最小安装（不装 AD/内网工具）
sudo bash kali/scripts/quick-setup.sh --minimal
```

这个脚本会自动完成：系统更新 → 安装 2026.1 新工具 → 配置原生 MCP → 安装逆向工具 → 刷新索引 → 输出报告。

### 2.1 首次配置

```bash
# 1. 进入项目根目录
cd /path/to/cybersecurity-skills-router

# 2. 给脚本加执行权限
chmod +x kali/scripts/*.sh kali/scripts/lib/*.sh

# 3. 刷新工具索引（检测本机工具状态）
bash kali/scripts/refresh-tool-index.sh

# 4. 查看结果
cat skills/tool-index.md
```

### 2.2 一键配齐 Kali 原生 MCP（强烈推荐）

```bash
# 安装 Kali 官方 MCP 三件套
bash kali/scripts/bootstrap-reverse.sh mcp-kali-server metasploitmcp hexstrike-ai

# 安装后 MCP 配置自动写入 ~/.claude/mcp.json
# 如果用 Kiro，手动复制到 ~/.kiro/settings/mcp.json
```

### 2.3 安装 2026.1 新工具

```bash
# 全部新工具一键安装
bash kali/scripts/bootstrap-reverse.sh adaptixc2 atomic-operator sstimap xsstrike wpprobe fluxion gef

# AD/内网渗透套件
bash kali/scripts/bootstrap-reverse.sh coercer evil-winrm-py netexec responder bloodhound certipy
```

### 2.4 安装缺失工具

```bash
# 安装单个工具
bash kali/scripts/bootstrap-reverse.sh jadx

# 安装多个工具
bash kali/scripts/bootstrap-reverse.sh jadx apktool frida jshookmcp

# 安装并启动服务
bash kali/scripts/bootstrap-reverse.sh idapro --start-services
```

### 2.5 让 AI 客户端自动路由

告诉你的 AI 客户端读取 `kali/RULES-kali.md`，它会自动完成全局注入。

---

## 3. 路径约定

| 用途 | Kali 路径 |
|------|----------|
| 工具安装目录 | `~/tools/` 或 `/opt/` |
| jadx | `/opt/jadx/` 或 `~/tools/jadx/` |
| apktool | `/usr/local/bin/apktool`（apt）或 `~/tools/apktool/` |
| Ghidra | `/opt/ghidra/` 或 `~/tools/ghidra/` |
| IDA Pro | `/opt/idapro/`（如果有 Linux 版） |
| Android SDK | `~/Android/Sdk/` |
| SecLists | `/usr/share/seclists/`（apt）或 `~/tools/SecLists/` |
| Node.js | `/usr/bin/node`（apt/nvm） |
| Python | `/usr/bin/python3`（系统自带） |
| MCP 配置 | `~/.claude/mcp.json` 或 `~/.kiro/settings/mcp.json` |

---

## 4. 与 Windows 版的差异总结

| 维度 | Windows 版 | Kali 版 |
|------|-----------|---------|
| 脚本语言 | PowerShell (.ps1) | Bash (.sh) |
| 包管理 | winget / GitHub Release ZIP | apt / pip / npm / GitHub Release tar.gz |
| 路径分隔符 | `\` | `/` |
| 环境变量 | `%USERPROFILE%` | `$HOME` |
| 预装工具 | 几乎没有 | 大量安全工具预装 |
| IDA 启动 | `start.ps1` | 手动启动 Linux 版 IDA；脚本只注册/检查 MCP，除非本机自行补了 launcher |
| MCP 配置路径 | `%USERPROFILE%\.claude\mcp.json` | `~/.claude/mcp.json` |
| 端口检测 | `TcpClient` | `nc -z` 或 `ss` |

---

## 5. 验证清单

```bash
# ─── 基础命令 ───
java -version
python3 --version
pip3 --version
node -v
npx -v

# ─── 逆向工具 ───
jadx --version
apktool --version
adb version
frida --version
r2 -v
gdb --version          # GEF 自动加载

# ─── 渗透工具（Kali 预装） ───
nmap --version
sqlmap --version
hashcat --version
hydra -h | head -1
msfconsole --version
gobuster version
ffuf -V
nuclei -version

# ─── Kali 2026.1 新工具 ───
sstimap -h 2>&1 | head -3
xsstrike -h 2>&1 | head -3
wpprobe --help 2>&1 | head -3
coercer -h 2>&1 | head -3
evil-winrm-py -h 2>&1 | head -3

# ─── AD/内网工具 ───
netexec --help 2>&1 | head -3
responder -h 2>&1 | head -3
certipy --version 2>&1 | head -1

# ─── Kali 原生 MCP ───
which kali-server-mcp && echo "mcp-kali-server OK"
which metasploitmcp && echo "metasploitmcp OK"
which hexstrike-ai && echo "hexstrike-ai OK"

# ─── 刷新工具索引 ───
bash kali/scripts/refresh-tool-index.sh

# ─── 检查 MCP 服务（如果已配置） ───
nc -z 127.0.0.1 5000 && echo "mcp-kali-server OK" || echo "mcp-kali-server offline"
nc -z 127.0.0.1 8085 && echo "metasploitmcp OK" || echo "metasploitmcp offline"
nc -z 127.0.0.1 13337 && echo "IDA MCP OK" || echo "IDA MCP offline"
nc -z 127.0.0.1 23816 && echo "anything-analyzer OK" || echo "anything-analyzer offline"
```

---

## 6. 常见问题

### Q: Kali 自带的 radare2 版本太旧怎么办？

```bash
# 用官方源安装最新版
bash kali/scripts/bootstrap-reverse.sh r2
# Kali 版默认优先 apt 安装/补齐 radare2；如需最新版可按平台文档改用 GitHub/source
```

### Q: 我用的是 Parrot OS / BlackArch，能用吗？

可以。脚本检测的是命令是否存在，不绑定特定发行版。只是 `apt` 相关的自动安装可能需要改成 `pacman`（BlackArch）。

### Q: IDA Pro Linux 版怎么配？

把 IDA 安装到 `/opt/idapro/`，然后修改 `kali/scripts/bootstrap-manifest.json` 中 `idapro` 的 `startScript` 路径。

### Q: 我想同时在 Windows 和 Kali 上用这套系统

没问题。`skills/` 目录通过 Git 同步，`field-journal/` 的经验两边共享。只是执行脚本时 Windows 用 `skills/scripts/*.ps1`，Kali 用 `kali/scripts/*.sh`。


