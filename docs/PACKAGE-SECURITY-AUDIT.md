# reverse-skill 包内安全审计（可执行面）

> 日期：2026-07-18  
> 范围：`skills/**/scripts`、`skills/scripts`、`kali/scripts`、`burp-mcp-full` 可执行脚本与 bootstrap 清单  
> **不含**：`src-hunter` / payloader 等**教学型 payload 文档**（其 DROP/注入样例属方法论，非自动执行）

## 结论（总评）

| 级别 | 判定 |
|------|------|
| **后门 / 主动删库 / 格式化磁盘** | **未发现** |
| **管道下载执行（curl\|sh / IEX DownloadString）** | **未发现** |
| **硬编码云密钥 / 私钥** | **未发现**（文档中的 `sk-` / `BEGIN RSA` 为检测示例） |
| **供应链残余风险** | **已部分加固（中低→低）**：钉死 `@latest`；GitHub 下载支持 **manifest SHA256 + API digest** |

**总评：可执行 skill 脚本面当前未发现植入式后门或「一键删库」逻辑；危险删除均限定在工具重装临时目录 / case 输出目录。**

### 2026-07-18 加固（本提交）

| 项 | 动作 |
|----|------|
| jshookmcp | `@latest` → `@0.3.4` |
| pentestswarm | `@latest` / docker `:latest` → `@v0.1.0` / `:v0.1.0` |
| jadx | pin `v1.5.6` + `assetSha256` |
| apktool | pin `v3.0.2` + `assetSha256` |
| bootstrap PS/sh | 下载后 `Assert-DownloadedFileIntegrity` / `verify_sha256`；优先 manifest 哈希，其次 GitHub `digest`；失败删文件并中止 |
| 未钉哈希的 release | 仍可安装，但 **WARN** 并打印实际 sha256 |

## 扫描方法

对可执行扩展（`.ps1` / `.sh` / `.py` / `.js` / `.java`）检索：

- `Invoke-Expression` / `IEX` / `FromBase64String` / `DownloadString`
- `curl|bash` / `wget|sh` 管道执行
- `DROP DATABASE|TABLE`、`rm -rf /`、`Remove-Item ... C:\Windows`
- 反弹 shell 形态（`/dev/tcp` 滥用、`TcpClient` 回连）
- 隐藏窗口启动（复核用途）

第二轮：人工阅读 `bootstrap-reverse.ps1/.sh` 下载与删除路径、`mcp-bridge.js`、图表/密码学 Python 脚本。

## 发现明细

### 1. 删除操作（均为预期清理，非删库）

| 位置 | 行为 | 风险 |
|------|------|------|
| `bootstrap-reverse.ps1` `Expand-ArchiveIntoDirectory` | 删除目标安装目录后重装；删除 `%TEMP%\reverse-bootstrap-*` | 仅工具安装路径，非用户业务库 |
| `bootstrap-reverse.ps1` anything-analyzer | 失败时 `Remove-Item node_modules` 后 `pnpm install` | 限定克隆的工具仓 |
| `apk-reverse/scripts/decode.*` | 清理任务输出目录 jadx/apktool out | 限定 task 根 |
| `case-init.ps1` | 清理临时目录 | 临时 |
| `bootstrap-reverse.sh` | 同类 temp / 安装目标清理 | 同左 |

**未发现** 针对 `C:\`、系统目录、任意数据库连接串上的 `DROP`/`TRUNCATE` 可执行逻辑。

### 2. 网络行为（工具自举，非 C2）

| 位置 | 行为 | 说明 |
|------|------|------|
| `bootstrap-reverse.ps1` | `api.github.com` 拉 release；`Invoke-WebRequest` 下 zip/jar | 仓库名来自 **manifest 白名单** |
| `bootstrap-reverse.sh` | `curl` / `git clone` / `pipx` / `npm` | 同上 |
| `mcp-bridge.js` | 仅 `127.0.0.1:9876` HTTP → Burp | 本地环回 |
| `ToolDiscovery.ps1` | 探测 `http://host:port/mcp` | 健康检查 |
| `kali/.../tool-discovery.sh` | `(echo >/dev/tcp/$host/$port)` | **端口探测**，非反弹 shell |

### 3. 隐藏窗口

| 位置 | 用途 |
|------|------|
| `bootstrap-reverse.ps1` `Start-Process ... -WindowStyle Hidden` | 后台启动 `pnpm dev`（anything-analyzer） |
| `ida-reverse/scripts/start.ps1` | 启动 IDA 相关进程（需保持后台） |

属服务启动形态，未发现隐藏下载恶意载荷。

### 4. 文档 / payload 中的「危险字样」（非自动执行）

`pentest-tools/src-hunter`、`attack-chain` 等 **Markdown/JSON 教学材料** 含 SQL 注入、`DROP` 示例、日志清理 **红队方法论**。  
这些 **不会被 bootstrap 或 master-route 自动执行**；执行依赖 AI/人工在**已授权 scope** 下选用。

相关约束见：`ops/scope-contract.md`、`ops/skill-supply-chain.md`、`field-journal/precedent-*.md`。

### 5. 供应链残余风险（建议后续加固，非已证实后门）

| 项 | 风险 | 建议 |
|----|------|------|
| `bootstrap-manifest.json` 中 `@jshookmcp/jshook@0.3.4`、`pentestswarm@v0.1.0` | 标签漂移 / 供应链投毒面 | 钉死版本号 + 校验和 |
| GitHub release zip **无 SHA256 校验** | 被替换 release 时难以及时发现 | manifest 增加 `assetSha256` 并在 bootstrap 校验 |
| `npm install -g` / `pip` 默认源 | 依赖生态固有风险 | 仅装 manifest 能力；生产环境用私有源/锁定 |

## 可执行脚本清单（审计基线）

```
skills/scripts/*.ps1|*.sh + lib/ToolDiscovery.ps1
skills/apk-reverse/scripts/*
skills/radare2/scripts/*
skills/ida-reverse/scripts/*
skills/browser-automation/scripts/*
skills/diagram-generator/scripts/*.py
kali/scripts/*
burp-mcp-full/mcp-bridge.js (+ Java 扩展源)
```

## 建议的持续检查

```powershell
# 可执行面快速体检（示例）
rg -n "Invoke-Expression|FromBase64String|DownloadString|rm -rf /|DROP DATABASE" skills/scripts skills/*/scripts kali/scripts burp-mcp-full -g "*.ps1" -g "*.sh" -g "*.py" -g "*.js"
```

新增 skill 的 **可执行脚本** 合入前应再跑本清单；仅 Markdown 方法论变更不强制。

## 签署

- 审计执行：仓库本地静态扫描 + 关键路径人工复核  
- 结果：无后门 / 无自动删库；供应链加固列为后续改进项  
'@
