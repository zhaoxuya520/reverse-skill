# 2026-10-11 Electron 厚客户端受控动态执行补证（RunAsNode 宿主 + 记录型网络桩）

## 场景分类
二进制分析 / 抓包分析（受控动态执行）

## 目标概述
对已静态画像的 Electron 厚客户端样本，在**自建隔离宿主**中实际执行其主进程字节码，
把静态阶段「不可读 / 仅有强推断」的关键结论落实为运行时事实——**不安装、不注册、
零字节出网**。

## Scope 摘要（脱敏）
- auth_basis: own_system（用户明确授权「允许动态抓包」，并说明当前无账号）
- network_profile: offline（出口全部被桩替换；未对厂商生产系统发起任何请求）
- asset_types: [electron_app, v8_bytecode, nsis_installer]

## 角色
- lead_role: lead
- specialists: []

## 完整执行链路

1. **确认承载方式**。样本是 Electron 应用，主进程逻辑在 `main/main.bytecode`（V8 code cache）。
   第一反应是「需要装 Electron 才能跑」——**错的**。样本自带的 `{app}.exe` 就是
   Electron 二进制，用 `ELECTRON_RUN_AS_NODE=1` 即可把它当 Node 运行时用，
   且 ABI 与样本**完全一致**（`process.versions.modules` 直接对得上）。
   这一步同时解决了原生依赖（`native-keymap` 等）的 ABI 匹配问题。
   → 不安装、不写系统目录、不注册任何东西。

2. **复刻 bytenode 加载器**。从 `main/main.js` 抄 `fixBytecode` / `readSourceHash` /
   `Module._extensions['.bytecode']` 三件套，逐字照搬。加载成功的判据是
   `script.cachedDataRejected === false`，并且 `sourceHash` 与静态阶段的记录一致。

3. **隔离目录**。在加载字节码**之前**就把 `APPDATA` / `LOCALAPPDATA` / `TEMP` / `TMP`
   重定向到 case 内的 `isolated/` 目录。顺序很重要——样本模块级代码就会调
   `app.getPath('userData')`。

4. **替换 electron 模块**。写一个 `fake-electron.js` 实现 `app` / `BrowserWindow` /
   `ipcMain` / `session` / `protocol` / `Menu` / `net` 等。
   **关键设计**：未知成员不要返回 `undefined`，而是返回一个「可调用、可继续取属性」的
   深代理，并把访问记成 `electron.missing` 事件。否则第一个缺失的 API 就会让
   模块级代码抛 `undefined is not a function`，整个分析卡死在第一屏。

5. **打桩网络与子进程**。`net` / `tls` / `http` / `https` / `dns` / `dgram` /
   `child_process` 全部换成**记录型桩**：把调用参数完整录下来，然后返回错误
   `HARNESS_NETWORK_BLOCKED`。这一步是「零出网」的技术保证。

6. **补齐依赖解析**。样本依赖分两层：webpack 打包进字节码的，和
   `resources/app.asar.unpacked/node_modules/` 下的原生/大体积依赖。
   真实运行时由 Electron 的 asar 解析器统一处理，自建宿主需要在
   `Module._resolveFilename` 失败时回落到该目录。**第一版漏了这步**，
   表现为 `Cannot find module 'iconv-lite'`。

7. **派发 ready 事件**。字节码加载成功 ≠ 应用启动。样本用的是
   `app.on('ready')` 而**不是** `app.whenReady()`。第一版宿主只实现了 `whenReady`，
   结果字节码跑完了模块级、`ipcMain` 上注册了一堆 handler，却**一个窗口都没创建**。
   必须由宿主显式 `app.emit('ready')` 才能进入真正的启动流程。
   → **这是本次最大的弯路**，见踩坑表。

8. **枚举 IPC 面**。样本用 `ipcMain.on(channel, fn)` 注册（**不是** `invoke`/`handle`），
   所以要在覆写 `on` 时顺手把 handler 存下来，才能后续合成调用。

9. **合成 IPC 调用驱动出站请求**。构造合成 `IpcMainEvent`（`sender` 指向桩 webContents），
   按通道名调用样本注册的 handler，传入合成业务体。样本走完真实的请求构造逻辑，
   记录型 `net` 桩把 URL / method / headers / body 全录下，再在 `end()` 处截断。
   → **这就是「不碰网络的抓包」**。

10. **载荷信封试错**。直接把业务体作为 `args[0]` 传进去，样本读到的是 `undefined`
    （表现为 `user=null`、`feature_id=undefined`、路径段 `undefined`）。
    试了 6 种形态（裸对象 / JSON 字符串 / `{body}` / `{data}` / 位置参数 / `{payload}`），
    只有 **`{payload: {...}}`** 命中。这类「信封形状」问题用**哨兵值**一次性探明最省事：
    给每个候选字段名填一个唯一字符串，看哪个出现在出站请求里。

11. **安全回调合成探针**。把注册进来的 `will-navigate` / `onHeadersReceived` /
    `setWindowOpenHandler` / `will-attach-webview` / 权限处理器存下来，
    用合成输入回放，观测判定结果。
    → 这一步直接抓到了「按域名白名单剥离 `X-Frame-Options`」。

12. **产物脱敏 + 时间戳归一化**。归档前把主机名 / 机器 UUID / SHA-256 指纹 / 用户路径
    替换为占位符，并把事件流的相对时间戳与 ISO 时间戳置零。
    → 处理之后连续两次采集的 SHA-256 **逐字节一致**，证据才真正可复核。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-041 | info | validated | runtime | `ELECTRON_RUN_AS_NODE=1 ./{app}.exe host-bootstrap.js` | — |
| E-044 | high | validated | runtime | 合成响应头回放 `onHeadersReceived(filter, handler)` | F-032 |
| E-046 | medium | validated | runtime | 合成 IPC 调用 + 记录型 `electron.net` 桩 | F-034, F-035 |

> 本次 case 的完整证据目录在用户项目内（`evidence/E-041..E-048.md`），
> `case-review --strict --verify-hashes` 结果：**PASS，0 error / 0 warning**。

## Finding / Path 摘要
- top_finding: 窗口四项安全选项同时弱化（`nodeIntegration` + `contextIsolation=false`
  + `webviewTag` + `enableRemoteModule`），且样本按厂商域名白名单**定向剥离
  `X-Frame-Options`**——两者叠加构成「厂商网页侧脚本注入 → 本机代码执行」的完整链路
- path_type: callflow
- path_one_liner: `registerSchemesAsPrivileged(internal,cache)` → 窗口以弱化
  `webPreferences` 创建 → `onHeadersReceived` 剥离 `X-Frame-Options` → 页面内
  `<webview>` 可嵌厂商页面 → 该上下文具备 Node 能力

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| 字节码加载成功，但一个窗口都没创建 | 样本用 `app.on('ready')`，宿主只实现了 `app.whenReady()` | 宿主显式 `app.emit('ready')`；同时实现 `will-finish-launching` | 高 |
| `undefined is not a function` at `new h(...)` | fake electron 缺某个 API，返回 `undefined` | 未知成员返回**可调用的深代理**，并记 `electron.missing` 事件 | 中 |
| `ERR_INVALID_ARG_TYPE: path must be string. Received function app.getAppPath()` | 深代理让缺失的 `getAppPath` 返回了函数，`path.join(fn,...)` 炸 | 补齐 `app.getAppPath()` 与整套 `getPath`/`setPath`；目录按 Electron 语义自动 `mkdir` | 低 |
| `Cannot find module 'iconv-lite' / native-keymap / fontkit` | 依赖分两层，第二层在 `app.asar.unpacked/node_modules` | 包装 `Module._resolveFilename`，失败时回落到该目录 | 中 |
| `h.headersReceived is not a function` | 样本用两参数形式 `onHeadersReceived(filter, listener)` | 桩要同时支持 `onXxx(fn)` 与 `onXxx(filter, fn)` 两种签名 | 低 |
| 合成 IPC 调用后请求体里没有我传的字段 | 业务体需要包在 `{payload: {...}}` 信封里 | 用**哨兵值**一次性探明字段名与信封形状 | 中 |
| 采集产物每次都不同，哈希对不上 | 事件流带相对时间戳 | 归档前把 `"t":<digits>` 与 ISO 时间戳归一化置零 | 低 |
| 采集把宿主整表环境变量录进了证据 | `child_process` 桩原样记录了 `{env: process.env}` | 在**桩的源头**把 `env` 替换为 `{__redacted:true, __keyCount:n}` | 低 |
| 差一点把 `[object Object] os get Caption` 当成样本缺陷 | `WHERE WMIC` 的 stdout 被桩置空，样本退化为把对象插进模板字符串 | 忽略该前缀只看语义后缀，并在证据里**显式标注这是环境产物** | 低 |

## 工具链发现

- **`ELECTRON_RUN_AS_NODE=1` + 样本自带 Electron 二进制**是分析 Electron 厚客户端
  最低摩擦的承载方式：免安装、ABI 精确匹配、原生 `.node` 依赖可直接加载。
- **fuses 决定可行性**：`RunAsNode` 若被关闭则此路不通（需改走完整启动 + 调试端口）。
  静态阶段应先读 fuse wire 再决定动态方案。
- 样本若启用 `EnableNodeCliInspectArguments`，可考虑 `--inspect-brk` 加断点，
  比纯事件记录更精确，但会显著增加复杂度。
- **深代理兜底**是自建 fake 模块的通用手法：缺失成员返回可调用代理 + 记录事件，
  比逐个补齐 API 快得多，且能一次跑完收集出完整缺失清单。

## 关键代码/命令

```bash
# 承载（不安装，直接用样本自带的 Electron 二进制）
cd <extract_dir>
HARNESS_IPC_CALLS='<合成调用集>' \
ELECTRON_RUN_AS_NODE=1 \
HARNESS_READY=never \
HARNESS_FIRE_READY=1 \
HARNESS_TIMEOUT=30000 \
./<app>.exe host-bootstrap.js
```

```js
// 深代理：未知成员可调用、可继续取属性，避免 undefined is not a function
function deepProxy (name) {
  const fn = function () {}
  return new Proxy(fn, {
    get (t, prop) {
      if (prop === 'then' || prop === 'catch') return undefined   // 不要变成 thenable
      if (prop === Symbol.toPrimitive) return function () { return name }
      return deepProxy(name + '.' + String(prop))
    },
    apply (t, thisArg, args) { rec.emit('electron.call', { path: name, args: cap(args) }); return deepProxy(name + '()') },
    construct (t, args) { rec.emit('electron.new', { path: name, args: cap(args) }); return deepProxy(name + '{}') }
  })
}
```

```js
// 记录型网络桩：完整录下请求构造，再在 end() 处截断
end: function (chunk) {
  if (chunk != null) req.write(chunk)
  rec.emit('net.request.final', { options, headers, body: chunks.join('') })
  process.nextTick(function () { (listeners.error || []).forEach(f => f(new Error('NETWORK_BLOCKED'))) })
}
```

```js
// 依赖两层：解析失败时回落到 app.asar.unpacked/node_modules
const orig = Module._resolveFilename
Module._resolveFilename = function (request, parent, isMain, options) {
  try { return orig.call(this, request, parent, isMain, options) }
  catch (err) {
    if (typeof request !== 'string' || request.startsWith('.') || path.isAbsolute(request)) throw err
    const synthetic = { id: entry, filename: entry, paths: Module._nodeModulePaths(UNPACKED_NM) }
    try { return orig.call(this, request, synthetic, false, options) } catch (e2) { throw err }
  }
}
```

## 对本包的改进建议

1. **`thick-client` 子技能应新增「受控动态执行」小节**，收录：
   `ELECTRON_RUN_AS_NODE` 承载法、fuse 前置检查、bytenode 加载器复刻、
   深代理兜底、依赖两层回落、`app.on('ready')` vs `whenReady` 的差别。
2. **新增 pitfall**：「字节码加载成功 ≠ 应用启动流程被驱动」。
   仅凭 `require(bytecode)` 成功就认为环境搭好了，会白等一轮。
3. **`case-review` 契约补充说明**：`findings` 计数是从 `report/*.md` 的
   `### F-xxx` 标题解析的，**不是**从 `findings.md` 解析的。
   新 Finding 必须同时以完整字段块写进报告，否则 `--strict` 虽 PASS 但计数偏低。
4. **证据可复现性**建议写进 `evidence-finding-path.md`：
   运行时采集产物归档前应归一化时间戳，否则 `--verify-hashes` 每次都对不上。
5. **脱敏清单**补充：`child_process` / `spawn` 类桩会透传 `{env: process.env}`，
   需在**桩的源头**脱敏，而不是靠事后正则。

## 可复用的模式/脚本片段

- **受控动态执行骨架**：`bootstrap.js`（加载器 + 隔离目录 + 看门狗）
  + `fake-electron.js`（深代理兜底 + 安全回调探针）
  + `stubs.js`（记录型网络/子进程桩）
  + `recorder.js`（增量 JSONL 事件流）
  + `capture.sh`（一键采集 + 脱敏 + 归一化）
- **合成输入探针模式**：把注册进来的安全回调存下来，用「厂商 URL / 第三方 URL /
  `file://` / `javascript:`」四类合成输入回放，直接读出判定策略。
- **哨兵值探字段名**：给每个候选键填唯一字符串，一次请求即可确定真实字段名，
  比逐个试快一个数量级。
- **信封形状试错表**：裸对象 / JSON 字符串 / `{body}` / `{data}` / `{payload}` /
  位置参数——自研 IPC 路由器常见六种，按序试。

## 进化动作
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录（见「对本包的改进建议」第 2、3、4、5 条）
- [ ] 无需更新

## 环境信息
- OS: Windows 10 x64（10.0.26200）
- 工具版本: 自建 Node 宿主（Python 3.13 辅助脚本，标准库）
- 目标平台/版本: Electron 22.3.1 / Chromium 108.0.5359.215 / Node 16.17.1 / V8 10.8.168.25-electron.0

## 脱敏要求
- 目标域名以 `{target_domain}` 表示；真实机器标识（主机名 / 机器 UUID / 硬件指纹）
  与宿主用户路径**已全部脱敏**为占位符
- 无 Token / Cookie / 密码 / API key 落盘；合成入参均使用 `example.invalid` 等保留域
- 未使用任何真实账号

## 索引同步（提交前最后一步）

- [x] `_index.md` 已更新

---
<!-- [进化统计] 本包累计完成项目: 24 | 本次新增模式: 4 | 本次修复工具链问题: 5 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
