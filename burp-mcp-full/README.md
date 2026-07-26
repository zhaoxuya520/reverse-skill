# BurpSuite MCP Full Control Extension

通过 MCP 协议控制 BurpSuite 核心功能。跨平台支持 Windows / Linux (Kali) / macOS。

> `1.1.0-rc.1` 起默认启用认证、精确 Scope、主动操作确认、严格隐私脱敏和真实调用审计。服务只监听 `127.0.0.1`，不能通过 MCP 关闭这些门控。

## 安全前置配置

启动 Burp 之前，至少设置 32 字符的 bearer token。主动操作还必须配置用户提供、未过期且精确匹配目标的 `scope.json`。

```powershell
$env:BURP_MCP_TOKEN = '<至少 32 字符的随机值>'
$env:BURP_MCP_SCOPE_FILE = 'C:\path\to\scope.json'
$env:BURP_MCP_ALLOWED_ORIGINS = 'http://localhost:3000,http://127.0.0.1:3000'
$env:BURP_MCP_AUDIT_LOG = 'C:\path\to\burp-mcp-audit.jsonl'
```

也可用 JVM property `-Dburpmcp.token=...`。环境变量必须由启动 Burp 的进程继承；不要把真实 token 提交到仓库或共享配置。

最小 Scope 模板：

```json
{
  "schemaVersion": "1",
  "scopeId": "scope-example",
  "status": "granted",
  "approvalId": "FILL_ME_WITH_USER_APPROVAL",
  "issuedAt": "2026-07-26T00:00:00Z",
  "expiresAt": "2026-07-27T00:00:00Z",
  "targets": [{
    "type": "network",
    "scheme": "https",
    "host": "app.example.invalid",
    "port": 443,
    "pathPrefixes": ["/api"]
  }],
  "allowedActions": ["passive.read", "request.send", "replay.send", "scan.active"]
}
```

- 协议、主机、端口和路径前缀必须精确匹配；通配符、路径穿越和越界重定向默认拒绝。
- `BURP_MCP_ALLOWED_ORIGINS` 是逗号分隔的精确 Origin allowlist；未设置时拒绝所有带 `Origin` 的浏览器请求。
- 无 `Origin` 的请求只接受本机 loopback 原生 bridge。CORS 不返回通配符。
- 被动只读工具仍要求 bearer token；发送、重放、Intruder、主动扫描、写配置、写 Cookie、WebSocket 发送等还要求 Scope 和确认。
- 首次主动调用会在 Burp UI 展示工具、规范化目标和参数摘要。批准后签发五分钟、单次使用且绑定参数的一次性令牌；重放返回 `410`。
- `privacyStrict` 始终开启，统一脱敏 `Authorization`、`Cookie`、`Set-Cookie`、查询密钥、请求体和日志。
- `scope_gate` 与 `privacy_mode` 仅用于读取当前安全状态，不能改变门控。
- 每次真实工具调用和拒绝原因写入 JSONL audit；默认路径为 `~/.burp-mcp/audit.jsonl`。

## 快速开始

### 1. 编译扩展

**Windows**:
```cmd
cd burp-mcp-full
build.bat
```

**Linux / Kali / macOS**:
```bash
cd burp-mcp-full
chmod +x build.sh
./build.sh
```

构建脚本会自动：检测 JDK 21+、下载依赖（montoya-api 2025.5 / gson / nanohttpd）、编译、把扩展描述符（`META-INF/extensions/burp-extension.properties`）打入 jar、打包 fat jar。无需 Gradle。

输出：`build/libs/burp-mcp-full.jar`。

### 2. 加载到 Burp

```
Burp Suite → Extensions → Add → Java → 选择 build/libs/burp-mcp-full.jar
```

加载后在 Output 看到：
```
[MCP] Server started on http://127.0.0.1:9876
```

### 3. 配置 MCP 客户端

在任何 MCP 客户端（Claude Code / Kiro / Cursor / Cline / Windsurf）中添加（stdio 模式）：

```json
{
  "mcpServers": {
    "burpsuite": {
      "command": "node",
      "args": ["<本目录路径>/mcp-bridge.js"],
      "env": {
        "BURP_MCP_TOKEN": "<通过客户端安全变量注入，不要提交真实值>",
        "BURP_MCP_PORT": "9876"
      }
    }
  }
}
```

### 4. 开始使用

对 AI 说："分析 Burp 代理历史中的请求，找出安全漏洞"

## 功能列表

扩展暴露 83 个工具。常用分类如下（完整列表见 `src/main/java/com/burpmcp/McpHttpServer.java` 的 `getToolList()`，或携带 bearer token 访问 `GET http://127.0.0.1:9876/tools`）：

| 分类 | 工具 |
|------|------|
| Proxy 历史 | `proxy_history`, `proxy_detail`, `proxy_history_filtered`, `proxy_websocket`, `proxy_listeners`, `proxy_match_replace`, `proxy_clear`, `search_history`, `highlight`, `annotate`, `compare` |
| 发送请求 | `send_request`, `send_to_repeater`, `repeater_send`, `repeater_modify_send`, `send_to_intruder` |
| Intruder 攻击 | `intruder_attack`, `intruder_attack_async`, `intruder_attack_wordlist`, `intruder_pitchfork`, `intruder_cluster_bomb`, `intruder_battering_ram`, `intruder_with_options`, `payload_process` |
| 扫描 / 爬取 | `scan`(主动/被动), `scan_active`, `scan_results`, `scan_issue_detail`, `crawl`, `sequencer` |
| Scope / Sitemap | `sitemap`, `target_info`, `get_scope`, `add_to_scope`, `remove_from_scope`, `add_issue` |
| 拦截 / 规则 | `intercept_toggle`, `intercept_modify`, `register_http_handler`, `remove_http_handler`, `register_proxy_rule`, `remove_proxy_rule` |
| 编解码 | `encode`, `decode`, `convert_request`, `export_request`, `generate_csrf_poc`, `extract_from_response`, `token_analysis` |
| Collaborator | `collaborator_generate`, `collaborator_poll` |
| 配置 | `export_config`, `import_config`, `set_upstream_proxy`, `set_dns_override`, `set_http2`, `cookie_jar`, `export_cert`, `websocket_send`, `save_project`, `burp_version`, `extensions_list`, `log` |

> 扫描/爬取（`scan`、`scan_active`、`crawl`）需要 **Burp Professional**。Community 版会返回明确的许可证错误。手动添加的 issue（`add_issue`）会写入 Site map。

## 关键工具参数

### `intruder_attack` — 自动化枚举攻击

| 参数 | 说明 |
|------|------|
| `url_template` | URL 模板，占位符默认 `@@` |
| `placeholder` | 占位符字符串（默认 `@@`） |
| `from` / `to` | 枚举起止值 |
| `pad_digits` | 补零位数（0 不补） |
| `method` | HTTP 方法（默认 GET） |
| `body_template` | 请求体模板（含占位符） |
| `headers` | 请求头对象 |
| `success_length_not` | 命中条件：响应长度 ≠ 此值 |
| `success_contains` | 命中条件：响应体包含此字符串 |

### `scan` — 启动审计

| 参数 | 说明 |
|------|------|
| `url` | 目标 URL（必填，自动加入 scope） |
| `mode` | `active`（默认）或 `passive` |

启动后用 `scan_results` 轮询 issues 与活动审计状态（请求数、错误数、插入点数）。

### `register_proxy_rule` — 代理请求拦截规则

| 参数 | 说明 |
|------|------|
| `url_contains` | 命中条件：URL 包含此串 |
| `intercept` | `true` 拦截 / `false` 放行不拦截（默认 true） |

通过 `remove_proxy_rule` 注销规则（基于 `Registration.deregister()`，真正从 Burp 卸载）。

## 调用示例

以下 HTTP 调用都必须包含：

```http
Authorization: Bearer <BURP_MCP_TOKEN>
Content-Type: application/json
```

### 查看代理历史
```json
POST http://127.0.0.1:9876
{"tool": "proxy_history", "params": {"limit": 10, "url_filter": "personalblog"}}
```

### 发送请求
```json
POST http://127.0.0.1:9876
{"tool": "send_request", "params": {"method": "GET", "url": "https://example.com/api/test"}}
```

### 自动化枚举攻击（核心功能）
```json
POST http://127.0.0.1:9876
{
  "tool": "intruder_attack",
  "params": {
    "url_template": "https://target.com/api/verify?code=@@",
    "method": "POST",
    "from": 0,
    "to": 999999,
    "pad_digits": 6,
    "success_length_not": 176,
    "headers": {"User-Agent": "Mozilla/5.0"}
  }
}
```

### 开关拦截
```json
POST http://127.0.0.1:9876
{"tool": "intercept_toggle", "params": {"enable": false}}
```

## 端口配置

默认且仅监听 `127.0.0.1:9876`。第一批安全版本不支持直接远程监听。如需更改端口（例如与 PortSwigger 官方 MCP 扩展冲突）：

1. **Burp 侧**：启动 Burp 时传 JVM 参数 `-Dburp.mcp.port=9877`，或设环境变量 `BURP_MCP_PORT=9877`。
2. **桥接侧**：MCP 客户端配置里设环境变量 `BURP_MCP_PORT=9877` 与 `BURP_MCP_HOST=127.0.0.1`。

两侧端口必须一致。若 Burp 未运行或端口不通，桥接会在 `tools/list` 与 `tools/call` 返回明确的连接错误指引。

## 故障排查

| 现象 | 排查 |
|------|------|
| Burp Output 无 "[MCP] Server started" | 确认 token 至少 32 字符，再检查端口冲突与 Burp Errors 面板 |
| MCP 客户端报 "Burp MCP not connected" | 确认 Burp 已运行且扩展已加载；确认两侧端口一致 |
| HTTP 返回 `401` | bridge 与 Burp 必须使用相同的 `BURP_MCP_TOKEN` |
| HTTP 返回 `403 blocked` | 检查 `scope.json` 状态、有效期、allowedActions 和精确目标 |
| HTTP 返回 `409 confirmation_required` | 在 Burp UI 审阅并批准；标准 bridge 会携带一次性令牌重试 |
| HTTP 返回 `410 gone` | 确认令牌已过期或已使用，重新发起主动调用 |
| 浏览器请求被 CORS 拒绝 | 将精确 Origin 加入 `BURP_MCP_ALLOWED_ORIGINS`，不要使用 `*` |
| 扫描返回 "requires Burp Professional" | 正常，Community 版不支持 Scanner API |
| `remove_http_handler` / `remove_proxy_rule` 无效 | 确认之前 `register_*` 返回 success=true |

## 源码构建（Gradle 可选）

```bash
cd burp-mcp-full
gradle jar      # 需本机已装 Gradle 8.7+
# 输出: build/libs/burp-mcp-full.jar
```

> 推荐使用 `build.bat` / `build.sh`（零依赖，自动下载 jar）。Gradle 路径仅作备选。
