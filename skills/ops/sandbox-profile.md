# 可选沙箱工具 Profile（对照 bootstrap-manifest）

> Z3r0 默认镜像工具很全；reverse-skill **不捆绑镜像**，用本表做「覆盖率对照」与可选 Docker 建议。

## reverse-skill 可自动 bootstrap 的能力

来源：`skills/scripts/bootstrap-manifest.json`（以文件为准）：

| 能力 | 典型场景 |
|------|----------|
| jadx / apktool / adb / frida / frida-ps | Android |
| r2 / rabin2 | 二进制 CLI |
| idalib-mcp / idapro | IDA MCP |
| jshookmcp / anything-analyzer / agent-browser | Web/JS/浏览器 |
| ghidra-mcp | Ghidra |
| nmap / seclists / proxycat / burpsuite-mcp / pentestswarm | 渗透 |
| binwalk / pwntools / yara | 固件/pwn/恶意 |

```powershell
powershell -File skills\scripts\bootstrap-reverse.ps1 -Capability @('jadx','nmap','yara') -StartServices
powershell -File skills\scripts\refresh-tool-index.ps1
```

## Z3r0 沙箱常见但本包 manifest 未自动装的

| 工具 | reverse-skill 策略 |
|------|-------------------|
| subfinder / amass / httpx / ffuf / nuclei / sqlmap | 文档安装 / Kali 脚本 / 外部 MCP；**勿假装 bootstrap 已有** |
| Ghidra GUI 全量 | ghidra-mcp 能力 + 手动插件步骤 |
| gdb / pwndbg | 平台文档手动；pwntools 可 bootstrap |
| hydra / hashcat | 手动或 Kali |
| SecLists | seclists 能力 |

## 推荐「轻量 Docker 作战」profile（可选，非依赖）

仅当用户 **自己** 有 Docker 且授权 lab 时：

```text
最小：nmap + nuclei + sqlmap 容器或 pentestMCP 类镜像
移动：jadx + apktool + frida 宿主机
逆向：宿主机 IDA/r2 + tool-index
```

**MUST NOT** 要求用户安装 Z3r0 才能使用 reverse-skill。

## network_profile 联动

沙箱内扫描仍受 case `scope.md` 的 `network_profile` 约束：

- `offline` → 不建议起对外扫描容器  
- `authorized_target_only` → 容器也只能打 in_scope  
