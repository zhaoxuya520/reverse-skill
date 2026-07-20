# 2026-07-20 Windows 逆向工具链完整自举

## 场景分类

其他 / 工具链与环境

## 目标概述

在 Windows 24H2 主机上安装并验证覆盖原生、托管、Android、固件、协议、取证、浏览器和 MCP 的逆向工程工具链。

## 完整执行链路

1. 读取共享 tool-index，先复用已安装工具。
2. 运行通用 PATH 探针，按缺口补齐静态、动态、固件和协议工具。
3. 对大文件从可信清单提取 URL 与 SHA-256，使用禁用 IPv6 的 aria2 直连下载。
4. 为便携工具建立 `{user_profile}\Tools\reverse-bin` 统一入口。
5. 构建并注册 Ghidra、IDA、JS、浏览器流量和 Burp MCP。
6. 使用真实 PE/APK/.NET/PYC/WASM/固件夹具验证工具，不只运行版本命令。
7. 刷新共享 tool-index，并输出正式安装报告和流程图。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| winget 大文件下载长时间无进度 | Delivery Optimization 与默认 IPv6 路径不稳定 | 从 winget 元数据取官方 URL/散列，使用 `aria2c --disable-ipv6=true` | 高 |
| anything-analyzer SQLite ABI 不匹配 | 普通 `pnpm rebuild better-sqlite3` 构建成 Node ABI，而 Electron 需要 Electron ABI | 使用项目的 `pnpm run postinstall` | 中 |
| WSL 服务 1053，系统功能不存在 | Windows 镜像裁剪掉 WSL、VirtualMachinePlatform、Hyper-V 功能包 | 保留真实 Linux 命令缺口，改用 Windows 原生工具与 QEMU full-system | 中 |
| Dr. Memory 版本正常但注入崩溃 | Windows 11 24H2 build 26100 兼容性问题 | 记录上游 issue，使用 AppVerifier/PageHeap/UMDH/CDB/Frida | 中 |
| Codex TOML 无法加载 | 历史项目路径乱码造成缺引号、无效转义和重复键 | 仅修复表头语法并校验 `codex mcp list` | 低 |
| Burp MCP 注册后无工具 | Burp GUI 尚未加载扩展，9876 未监听 | 构建固定 JAR，记录 GUI 加载条件 | 低 |

## 工具链发现

- 通用探针最终为 57/64；7 个缺口全部属于 Linux 用户态或内核能力。
- Windows SDK Debugging Tools 是 Dr. Memory 不兼容时的重要补充：CDB、GFlags、UMDH、NTSD、KD。
- MCP 应分别验证“stdio/HTTP 初始化”和“GUI 后端在线”；注册成功不等于工具可调用。
- IDA Free 可用于本地交互分析，但不能替代合法 IDA Pro 的 idalib/Hex-Rays MCP 后端。

## 关键代码/命令

```powershell
python "{skill_root}\scripts\toolchain_probe.py" --format markdown
aria2c --disable-ipv6=true --max-connection-per-server=16 --split=16 "{official_url}"
powershell -NoProfile -ExecutionPolicy Bypass -File "{package_root}\skills\scripts\refresh-tool-index.ps1"
codex mcp list
cdb -g -G C:\Windows\System32\where.exe cmd
```

## 对本包的改进建议

- 将 Dr. Memory、CDB、GFlags、UMDH、DTC、SquashFS、flashrom 和 Frida Trace 纳入 Windows tool-index catalog。
- capability 状态应区分 `installed`、`bridge-ready`、`backend-online`、`runtime-verified`。
- 为裁剪版 Windows 增加明确的 Linux-only 缺口说明，不生成同名伪包装器。

## 可复用的模式/脚本片段

大文件下载固定模式：先从官方包元数据核对版本、URL 和 SHA-256，再用 aria2 禁用 IPv6 下载；下载后同时验证散列和 Authenticode（如适用）。

## 进化动作

- [ ] 更新了路由矩阵
- [x] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录
- [ ] 无需更新

## 环境信息

- OS: Windows NT build 26100.4946，24H2，x64
- 工具版本: 详见本机正式安装报告与 tool-index
- 目标平台/版本: Windows 原生工具链，并覆盖 Android、Linux/ELF 静态分析与 full-system 仿真

## 脱敏要求

本记录不含真实目标、凭据、令牌、内部 URL 或用户名；路径均使用占位符。

## 索引同步

已更新 `_index.md` 的统计与“工具链与环境”分类。

---
<!-- [进化统计] 本包累计完成项目: 11 | 本次新增模式: 3 | 本次修复工具链问题: 5 -->
<!-- [社区贡献] 本地记录已完成。 -->
