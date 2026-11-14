---
name: cdp-runtime-recovery-vs-playwright
description: Playwright 场景拿不到 request initiator 调用栈；CDP 原生有。含压缩脚本断点必须给 columnNumber 等 3 个坑
metadata:
  type: project
---

# 用 CDP 补 Playwright 拿不到的运行时证据

**日期**: 2026-10-16
**场景分类**: JS 逆向 / 抓包分析
**目标**: `{target_domain}`（SPA，登录态页面）

## 背景

既有抓包能力基于 Playwright 场景驱动的浏览器快照。它的**产物里自己写着一条诚实边界**：

> *Playwright scenario events **do not expose request initiator stacks**;
> receipt order does not prove causality.*

也就是：**拿不到「这个请求是页面里哪段代码发出来的」**。而这恰好是 JS 逆向第一阶段
（回溯调用来源）的核心诉求。

## 核心发现：换用 CDP 原生域即可

`Network.requestWillBeSent` 事件**自带** `initiator.stack.callFrames`，
包含 `functionName` / `url` / `lineNumber` / `columnNumber`。实测一次拿到 **14 层调用栈**，
且函数名与源码门面逐层吻合（`<请求封装> → <方法别名> → <门面方法> → … → <框架入口>`）。

**这不是"更高阶的技巧"，而是"选错了观测通道"** —— Playwright 不暴露 ≠ 浏览器不给。

## 另外两类 CDP 才能拿到的证据

1. **断点读函数入参/返回值**：在请求封装函数的 `fetch(` 调用处下断点，
   暂停时读 `scopeChain[0]`（local）即可直接看到 `method` / `path` / `opts` 三个入参 ——
   这是「参数怎么生成的」最直接的答案。
2. **压缩脚本的源码搜索与定点**：`Debugger.getScriptSource` 取全量源码后本地正则搜索，
   比在 DevTools 里肉眼找快得多。

## 三个必踩的坑（都实测过）

### 坑 1：XHR 断点对 **fetch 架构无效**

`DOMDebugger.setXHRBreakpoint` **只对 `XMLHttpRequest` 生效**。现代 SPA 普遍走 `fetch`
⇒ 断点下好、请求照发、**暂停 0 次**（且不报错，最容易被误判成"这个页面没有请求"）。

**对策**：fetch 站点改用「在请求封装函数内按文本下断点」（见坑 2）。
另外 CDP **没有** `beforeXHR` 这个 instrumentation 值（`Debugger.setInstrumentationBreakpoint`
只有 `beforeScriptExecution` 系列），照抄会静默失败。

### 坑 2：打包脚本下断点必须**同时给 lineNumber 与 columnNumber**

打包产物可能**整份只有 8 行、每行几十万字符**。只给 `lineNumber` 会把断点下到**行首**
（实测落进一个中文字符串字面量里），读出来的变量与目标完全不相干。

```js
// 从文本匹配位置算出行内列号
const line = src.slice(0, idx).split('\n').length - 1;
const lineStart = src.lastIndexOf('\n', idx) + 1;
const column = idx - lineStart;                              // ★ 必需
await call('Debugger.setBreakpointByUrl', { url, lineNumber: line, columnNumber: column });
```

回读 `result.locations` 判断 CDP 是否真的接受了该位置：**`locations.length === 0`
= 该位置没有可执行语句**（大概率是匹配落在字符串里），应换更独特的文本。

### 坑 3：`Debugger.enable` 必须在**注册 `scriptParsed` 监听器之后**调用

先 `enable` 会让 Chrome 把已有脚本的 `scriptParsed` **一次性回放掉**，而那时还没有监听器
⇒ 收到 **0 个脚本** ⇒ 报「在 0 个脚本里没找到文本」。之后再 `enable` **不会重放**（已启用）。
判据：收集到的脚本数为 0。

## 可复用的模式

**「实时窗口 + 窗口内触发」必须放进同一条命令**。CDP 抓包是实时的，窗口开始前完成的请求永远抓不到；
而「请用户在窗口期内操作」无法由脚本保证（答应了却发现在窗口外操作 = 白跑一轮，本项目踩过）。
做法：给窗口类命令加 `--then <表达式文件> --then-after <秒>`，在窗口开始后 N 秒用**同一条 CDP 连接**
执行触发表达式（常用 `location.reload()`，会带来整页初始化请求链）。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| XHR 断点暂停 0 次 | 目标走 fetch，XHR 断点不覆盖 | 改在请求封装函数内按文本下断点 | 30 min |
| 断点读到不相干变量 | 压缩脚本单行 40 万字符，只给行号下到行首 | 补 `columnNumber` + 回读 `locations` 校验 | 35 min |
| 报「在 0 个脚本里没找到文本」 | `enable` 早于监听器注册，回放丢失 | 先注册 `scriptParsed` 再 `enable` | 25 min |

## 对本包的改进建议

- 若 `js-reverse` 模块的执行面依赖某类外部 MCP，建议在文档里**并行给一条 CDP 直连方案**，
  避免该 MCP 未就绪时整条路由不可用。
- 该模块 `references/` 偏薄（12 个文件平均约 271 B），本文提到的三个坑属于**必踩级**，
  建议提取成一页 reference。

## 进化动作

- [x] 新增了 pitfalls 记录
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档

## 环境信息

- OS: win32 x64
- 工具版本: Chrome 155 / Node 26（原生 WebSocket）
- 目标平台/版本: 现代 SPA（打包产物，无 source map）

---

<!-- [进化统计] 本次新增模式: 2（运行时调用栈恢复 / 断点取参） | 本次修复工具链问题: 3 -->
