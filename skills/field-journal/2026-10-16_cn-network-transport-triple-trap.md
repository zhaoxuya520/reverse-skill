---
name: cn-network-transport-triple-trap
description: 境内访问境外 API 的三重传输坑：Node fetch 不读代理、CF TLS 指纹、execFile 经 GBK 破坏 UTF-8 请求体
metadata:
  type: project
---

# 境内访问境外 API 的传输层三重坑

**日期**: 2026-10-16
**场景分类**: 抓包分析 / 其他（网络传输层）
**目标**: `{target_domain}`（境外 API，经本地代理访问）

## 背景

本机直连境外目标不可用，需经本地代理（`127.0.0.1:{port}`）。同一段时间内，
`curl` 请求稳定成功，而 Node 原生 `fetch` 报 `fetch failed`。逐个排查后确认是**三个独立问题叠加**。

## 三个坑与判据

### 坑 1：Node 的 fetch（undici）**默认不读** `HTTPS_PROXY` / `HTTP_PROXY` 环境变量

| 调用方式 | 是否读代理环境变量 |
|---|---|
| `curl` | ✅ 读 |
| Node `fetch` | ❌ **默认不读** → `fetch failed` |

**修复（Node 24+）**：`NODE_USE_ENV_PROXY=1 node app.js` 或 `node --use-env-proxy app.js`

### 坑 2：即使配好代理，Node 的 undici **TLS 指纹过不了 Cloudflare**（403 Just a moment）

同一时刻 `curl` 返回 200 —— 说明不是 IP 或代理问题，是**客户端指纹**。
⇒ **结论：对受 CF 保护的境外端点，不要用 Node fetch，直接用 curl。**

### 坑 3：Windows 上 `execFile('curl', args)` 的**参数会经系统代码页（GBK/CP936）转换**，破坏 UTF-8 请求体

表现极具误导性：

| 请求体内容 | 结果 |
|---|---|
| 纯 ASCII | **成功** |
| 含中文 | 上游返回 `illegal parameter`（服务端按 UTF-8 解码失败） |
| **含韩文** | **"意外"成功** —— 因为 GBK 表示不了韩文，被替换成 `?` 退回 ASCII |

**修复**：请求体一律写**临时文件**，用 `--data-binary @<file>`（文件按 UTF-8 写入），
**不要**用 `-d '<json>'`。即使当前只有 ASCII 也统一走文件 —— 哪天上层加入中文就不会重踩。

## 推荐传输层形态（可直接照搬）

```js
// 用 curl 作传输层，理由与要点：
//  ① DNS 污染 / 代理：curl 读系统代理，Node fetch 不读
//  ② CF 挑战：Node TLS 指纹被拦，curl 通过
//  ③ 中文 body：参数走命令行会被 GBK 破坏 ⇒ body 写临时文件 + --data-binary @file
//  ④ windowsHide: true —— 见下方"附带坑"
const args = [
  '-s', '--compressed', '-m', String(sec), '-A', UA,
  '-X', method, '-w', '\n__HTTP__%{http_code}',
];
if (proxy) args.push('--proxy', proxy);
args.push('--data-binary', '@' + tmpFile);   // ← body 必须走文件
args.push(url);
execFile('curl', args, { windowsHide: true, maxBuffer: 32 * 1024 * 1024 }, cb);
```

**附带坑**：`execFile` / `spawn` 在 Windows 上默认 **`windowsHide: false`**（注意 `exec` 默认是 true），
而本机默认终端是 Windows Terminal ⇒ **每调一次 curl 就弹一个终端窗口并抢前台**。
高频轮询场景表现为「弹窗不停地弹出来又关闭」。加 `windowsHide: true` 即根治，不影响功能。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| Node 请求全部 `fetch failed` | undici 不读代理环境变量 | `NODE_USE_ENV_PROXY=1` | 20 min |
| 配了代理仍 403 | undici TLS 指纹被 CF 拦 | 改用 curl | 25 min |
| 含中文的 POST 报参数不合法，含韩文的却成功 | 命令行参数经 GBK 转换破坏 UTF-8 | body 走临时文件 + `--data-binary @file` | 40 min |
| 高频请求时终端窗口疯狂弹出 | `execFile` 默认 `windowsHide:false` | 加 `windowsHide:true` | 15 min |

## 可复用的模式

**「同一时刻用两种客户端各试一次」是最快的分层判据**：
`curl` 成功而 Node 失败 ⇒ 问题在**客户端栈**（代理 / TLS 指纹），不在网络或目标；
两者都失败 ⇒ 才是网络 / 目标问题。别一上来就怀疑 DNS。

**「报错内容随数据语言变化」是编码问题的强信号**：
ASCII 成功 / 中文失败 / 韩文"意外"成功，这个组合基本可直接判定为 **代码页转换破坏 UTF-8**。

## 对本包的改进建议

- `bootstrap` 与文档层建议加一条**通用提示**：「Windows + 境内 + 境外 API」场景下
  默认传输层选 curl，并显式 `windowsHide`。
- 若包内示例用 Node fetch 访问境外端点，应在文档里写明 `NODE_USE_ENV_PROXY` 与 CF 指纹两条限制。

## 进化动作

- [x] 新增了 pitfalls 记录
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档

## 环境信息

- OS: Windows 10.0.22631
- 工具版本: Node v26.7.0 / curl（系统版）/ PowerShell 5.1
- 目标平台/版本: 境外 API（HTTPS，受 CDN/WAF 保护）

---

<!-- [进化统计] 本次新增模式: 3（代理 / 指纹 / 编码） | 本次修复工具链问题: 3 -->
