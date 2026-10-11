# 2026-10-11 Electron 厚客户端「远程托管登录页 + 客户端薄壳」认证模块静态逆向

## 场景分类

厚客户端安全 / Electron / 认证模块逆向 / 硬编码凭据发现 / 本地凭据落盘审计 / 脱敏审计

## 目标概述

对一个商业闭源 Electron 桌面应用（Windows x64 心智图软件，与同日的「NSIS + 7z + Bytenode 静态画像」为同一目标、第二阶段）**完全逆向其登录/注册模块**，产出**静态架构与安全评估**：认证数据流、凭证/令牌本地存储、客户端信任边界、硬编码密钥、客户端校验缺陷。全程只读、未执行样本代码、未对厂商服务发起任何请求、未产出认证绕过/凭证伪造/撞库，未触碰激活与授权绕过。

## Scope 摘要（脱敏）

- auth_basis: own_system（owner-operated local file，`preset=offline-sample`）
- network_profile: offline
- asset_types: [windows-x64-electron-installer, asar-bundle, v8-bytecode]

## 角色

- lead_role: lead
- specialists: []

## 完整执行链路

1. 明确边界并**先声明**：只做认证面的静态架构与安全评估；不产出绕过/伪造/撞库，不对厂商线上服务发起请求。
2. 主题化扫描认证代码面：写 `auth_sweep.py`，按 `auth_endpoint` / `token` / `signout` / `google_auth` / `storage_key` / `webview_relay` 等主题分组正则扫描 `renderer/**` 与 `static/**`。
   - **关键踩坑**：webpack 压缩后的 bundle 是**单行**，按行长度过滤会把所有命中丢掉 → 必须允许超长行，改用「每文件每主题限流 + 去重 + 跳过 mime-db 类巨型内嵌数据块」控噪。
3. 写 `webpack_mod.py`（按模块 ID + 花括号配平抽取单个 webpack 模块）与 `js_pretty.py`（压缩 JS 语句级排版），抽出两个关键模块：
   - `54856` = 渲染层 ↔ 主进程的 **IPC 契约总表**（`/xos/*`、`/firefly/*`、`/pinia/store/*`、`/windows`、`/custom-url/*`）
   - `63111` = **常量表**（OAuth 凭据、窗口规格、区域/语言映射、错误码）
4. 还原登录对话框 `dialog-signin.js`：确认登录 UI 是 **`<webview>` 加载远程页面**，本地无表单、无口令校验；注册/找回/邮箱验证全是 `GET /xos/go/account/*` 跳转路由。
5. **旁证推断**：检索 `lf.SIGN_IN`（即 `POST /xos/sign-in`）在渲染层的调用点 → **0 命中**，反推凭证交换完全发生在远程页面内。
6. 读登录页 preload（仅 13 行明文 JS）：来源判定为 `hostname.includes('{brand}')` 子串匹配；`window.parent.addEventListener('message', …)` 不校验 `event.origin`；回发用 `postMessage(msg, '*')`。
7. 在模块 `63111` 内定位硬编码 OAuth 凭据：`client_id` 字面量、`client_secret` 用 **`String.fromCharCode(...)` 混淆**（35 码位，解码前缀为 Google 客户端密钥标准前缀）、`redirect_uri` 为 vendor 域 https 回调 → 属 **Web application** 类型客户端。
8. 分析 OAuth 参数：`access_type:"offline"`、**无 `code_challenge`（无 PKCE）**、`state` 仅承载 `app_version`/`app_platform`（**非随机、不回传校验**）；构建开关决定走内嵌窗口还是 `shell.openExternal`。
9. 分析本地持久化：定位 Pinia `account` store 的 `memento` 计算属性 → 含 `token` / `fireflyToken`；对照主进程字符串 `.memento.json`、`main:store:pinia-plugins:memento`、`Failed to load/write memento "%s" from/to state file:`。
10. **本机运行时只读审计**：写 `state_audit.py`，**强制脱敏**（只输出键名/类型/长度/sha256 前 16 位），确认 `%APPDATA%\<vendor>\Electron v3\vana\state\` 下 12 个 `<storeId>.json` 均为**可直接 `json.loads` 的明文**。
11. 检索 OS 级密钥保护能力：`safeStorage` / `keytar` / `encryptString` / `decryptString` / `DPAPI` → **全 0 命中**；`EnableCookieEncryption` fuse = DISABLED。
12. 分析登出：`clearAccount()` 只清内存 ref + 覆盖写 state 文件；`clearStorageData` / `removeAllCookies` / `clearAuthCache` / `flushStore` → **全仓 0 命中** → 站点 Cookie 残留。
13. 分析回调输入面：主进程注册自定义协议、`LOGIN_FROM_OUTSIDE(_GOOGLE)` → `POST /custom-url/<scheme>/login[/google]`；另有 `SessionApi.loginBy{Brand}Token → POST /api/session/login-by-token`（「以外部 token 换会话」）。
14. **归因纪律**：`will-attach-webview` / `nodeIntegration` / `contextIsolation` / `webviewTag` 等字符串在 **Electron 二进制中同样存在** → 不能归因给应用自身，只能列为待动态确认项（做法：先在 Electron 二进制里 grep 同名串）。
15. 产出报告 + 13 条 Evidence + 12 条 Finding + 3 条 Path；`review_case.py --verify-hashes --strict` → PASS（0 error / 0 warning）。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-020 | high | observed | file | `webpack_mod.py <bundle> 63111 out.txt` → 定位 `Ey/NH/Mm` 三个常量 | F-008 |
| E-022 | high | observed | command | `state_audit.py`（只读 + 强制脱敏）审计 `<userdata>/state/*.json` | F-009 |
| E-025 | medium | observed | file | `js_pretty.py` 后读 `handleDidNavigate` 与 `<webview>` attrs | F-012, F-014, F-017 |

> **契约对齐（review_case.py）**：本次产出 `evidence/E-016..E-028.md`，全部满足
> `severity` / `status` / `repro_command` / `content_hash`+`artifact_path` / `linked_workitem` 契约。
> 自检：`python skills/case-review/scripts/review_case.py <case_root> --verify-hashes --strict` → PASS。

## Finding / Path 摘要

- top_finding: **F-008 硬编码 OAuth 客户端密钥随桌面端分发**（high）；次高 **F-009 认证令牌明文落盘（无 OS 级密钥保护）**
- path_type: callflow
- path_one_liner: 远程登录页 → `<webview>`（默认持久会话）→ `postMessage{signin_success, token}` → 宿主直接写 store → `memento` 明文落盘 → `DEVICE_BIND`

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| 首轮认证扫描「命中 1 个文件」 | 压缩 bundle 是单行，`len(line) > 4000 则跳过` 把所有命中都过滤掉了 | 改为允许超长行，用「每文件每主题上限 + 去重 + 排除 mime-db 等巨型块」控噪 | 低 |
| grep `Bearer` 输出约 117 KB 噪声 | 内嵌 mime-db 巨型 JSON blob 被正则命中 | 换 Python 处理：按主题分组、命中数限流、上下文截断 | 低 |
| 差点把 Electron 内部字符串当成应用缺陷 | `will-attach-webview`/`nodeIntegration`/`contextIsolation`/`webviewTag` 在 Electron 主程序二进制（`{target_exe}`）里也存在 | 加一步「在 Electron 二进制中 grep 同名串」做归因过滤；无法归因的一律列为待动态确认项 | 中 |
| 差点把第三方真实凭据写进交付物 | `client_secret` 是可直接使用的真实密钥 | 定**脱敏原则**：只登记「存在性 + 格式 + 混淆手法 + SHA-256 指纹 + 字节偏移」，不复制字面值；本机用户数据审计脚本强制脱敏 | 中 |
| 「令牌明文落盘」缺乏磁盘直证 | 本机账号处于未登录状态，state 文件里没有 `token` | 拆成两层证据：写侧代码确证（静态）+ 持久化机制与保护能力实测（运行时）；Finding 保持 `validated` 但 `confidence=medium`，并在 `residual_risk` 明写边界 | 中 |

## 工具链发现

- 无第三方依赖：全部脚本仅用 Python 3 标准库（`re` / `hashlib` / `sqlite3` / `json` / `os`）。
- **`sqlite3` 只读打开 Chromium 库**的正确姿势：`sqlite3.connect("file:<abs>?mode=ro&immutable=1", uri=True)` —— 不写日志、不加锁，适合取证场景。
- 压缩 JS 的「排版还原」不需要 AST：按语句/块边界插换行 + 引号状态机已足够人工阅读，成本远低于引入 prettier。
- webpack 模块抽取靠 `MODID:(e,t,n)=>{` 正则 + **花括号配平**（含字符串/模板串/转义处理）即可稳定定位。

## 关键代码/命令

```python
# 1) 从压缩 bundle 中抽取单个 webpack 模块（模块边界 + 花括号配平）
MOD_RE = re.compile(r"(?:^|[,\s{])(\d{3,7}):\(([A-Za-z_$][\w$]*),([A-Za-z_$][\w$]*),([A-Za-z_$][\w$]*)\)\s*=>\s*\{")

# 2) 只读 + 脱敏审计本地状态文件（绝不输出值本身）
def describe(v):
    if isinstance(v, str) and v:
        h = hashlib.sha256(v.encode()).hexdigest()[:16]
        return "<REDACTED len=%d sha256=%s>" % (len(v), h)
    ...

# 3) Chromium Cookie 库只读查询（只取 host/name/长度/密文前缀）
con = sqlite3.connect("file:%s?mode=ro&immutable=1" % path.replace("\\", "/"), uri=True)

# 4) 归因过滤：确认某字符串是否也存在于 Electron 二进制中
grep -a -o -c "will-attach-webview" {target_exe}
```

```bash
# 认证面扫描
python artifacts/scripts/auth_sweep.py
# 抽取 + 排版关键模块
python artifacts/scripts/webpack_mod.py <bundle.js> 54856 notes/mods/m54856.txt
python artifacts/scripts/js_pretty.py notes/mods/m54856.txt notes/mods/m54856.pretty.txt
# 保护能力检索（应 0 命中）
grep -iE 'safeStorage|keytar|encryptString|decryptString|DPAPI' main_strings.txt
grep -o 'clearStorageData\|removeAllCookies\|clearAuthCache\|flushStore' renderer/*.js
```

## 对本包的改进建议

- **路由**：R32 thick-client 命中准确；但认证面还需要一个「凭据/令牌落盘审计」的**子检查项**（`safeStorage`/`keytar`/`DPAPI` 检索 + `<userdata>` 状态目录只读审计 + 登出清理 API 检索）。目前这套动作完全靠现场发挥，建议固化进 R32 的 checklist。
- **工具**：建议把「webpack 模块抽取 + 压缩 JS 排版」并入 JS 相关 skill 的工具箱（本次为现场手写）。
- **契约**：`review_case.py --strict` 比 `ops/evidence-finding-path.md` 更严（Evidence 需 `severity`/`status`；Finding 字段须为纯文本 `- key: value`）。建议在 `evidence-finding-path.md` 里同步这两条，避免每次都踩。
- **precedent**：建议在 `precedent-reverse.md` 增加「托管登录页（hosted sign-in page）架构」条目 —— 其典型特征是「本地无表单 + `SIGN_IN` 端点无调用点 + `<webview>` 外壳 + 页面投递令牌」。

## 可复用的模式/脚本片段

**「托管登录页」架构的 5 条识别特征**（命中 ≥3 条即可判定）：

1. 登录窗口是 `<webview src=<远程 URL>>`，本地 HTML 只有一个 `<div id="app">` 外壳；
2. `SIGN_IN` / 登录端点常量在渲染层**无调用点**；
3. 存在 `signin_success` / `login_success` 之类的 **`ipc-message` / `postMessage` 事件名**，由页面投递凭据；
4. 注册/找回/邮箱验证是 `GET /go/...` 形式的**跳转路由**，无本地表单；
5. 存在 `*-preload.js` 之类的「页面 preload」，且其来源判定常为**子串匹配**。

**认证面静态审计清单（可直接复用）**：

- [ ] 硬编码凭据：`client_id` / `client_secret` / `api_key` / `consumer_secret`，注意 `String.fromCharCode` / `atob` / 拼接 / 十六进制等**混淆变体**
- [ ] OAuth 参数：是否 PKCE（`code_challenge`）、`state` 是否随机且回传校验、`access_type` / `redirect_uri` 类型
- [ ] 令牌落盘：`memento` / persisted-state / `localStorage` / `electron-store` 落点；是否有 `safeStorage`/`keytar`/DPAPI
- [ ] Cookie：`EnableCookieEncryption` fuse 状态；登录 webview 是否用独立 `partition`
- [ ] 登出：是否有 `clearStorageData` / `removeAllCookies` / `clearAuthCache` / `flushStore`
- [ ] 回调输入面：自定义协议（`setAsDefaultProtocolClient`）→ `/custom-url/*` handler；入参是否与本地 nonce/PKCE 绑定
- [ ] 来源校验：精确 origin 白名单 vs. `includes()` 子串匹配；`postMessage` 的 targetOrigin；是否校验 `event.origin`
- [ ] 归因过滤：可疑字符串是否**也存在于 Electron 二进制**中（若是 → 不能归因给应用）

## 进化动作

- [x] 新增了 pitfalls 记录（本文件）
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档（建议项见「对本包的改进建议」）
- [ ] 无需更新

## 环境信息

- OS: Windows 10/11 x64（Git Bash + PowerShell 混合）
- 工具版本: Python 3.13.12（仅标准库）
- 目标平台/版本: Windows x64 Electron 桌面应用（Electron 22.x 世代）

## 脱敏要求

- 厂商域名一律写作 `{target_domain}`（如 `https://{target_domain}/in-app/signin`）
- 硬编码凭据**不记录字面值**，只记录：存在性、格式（前缀/长度）、混淆手法、SHA-256 指纹、字节偏移
- 本机用户数据路径中的厂商目录名写作 `%APPDATA%\<vendor>\…`
- 本机账号状态（是否登录、region 值）仅作机制说明，不含任何标识符

## 索引同步（提交前最后一步）

见下方进化动作与 `_index.md` 更新。

---
<!-- [进化统计] 本包累计完成项目: 23 | 本次新增模式: 1（托管登录页 + 凭据落盘审计清单）| 本次修复工具链问题: 0 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
