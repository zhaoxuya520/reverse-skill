---
name: cdp-session-profile-and-port-pitfalls
description: CDP 调试会话的两个运维坑：临时目录 profile 被系统清理导致登录态丢失；端口 LISTENING 不等于它是 CDP
metadata:
  type: project
---

# CDP 调试会话的两个运维坑

**日期**: 2026-10-16
**场景分类**: 其他（浏览器取证环境运维）

## 背景

挖「登录后功能」时依赖一个带调试端口的 Chrome。中途 CDP 失联，排查过程暴露两个坑，
都不是代码问题，而是**环境判据**问题。

## 坑 1：调试 Chrome 的 profile 放在系统临时目录 → 会被清理，登录态随之消失

本项目原有的启动逻辑用的是 `path.join(os.tmpdir(), "rea-chrome-cdp")`。
**系统清理临时目录后，那个 profile 就没了** —— 连带**用户此前在该窗口里的登录态一起消失**。

**症状**：CDP 端口消失 → 重新拉起 → 页面被重定向到登录页 → `me_status: 401`。

**修法**：
- 需要**长期保留登录态**的调试 profile，不要放 `%TEMP%`，改放**稳定目录**（如项目内 `data/` 或 `%LOCALAPPDATA%`）。
- 若必须用临时 profile，就要接受"每次重来需重新登录"，并在流程里**显式确认登录态**再开工。

**判据**：开工前先 `GET /api/me`（或等价的身份端点）—— `401` 就说明登录态没了，别急着往下挖。

## 坑 2：端口有 LISTENING **不代表**它是 CDP 端点

实测：**9222 处于 LISTENING**，于是误判"已有调试端口在跑"，直接复用它 ——
结果 `/json/version` **返回空**，CDP 调用报 `Unexpected end of JSON input`。

**原因**：9222 被**日常使用的 Chrome 主进程**占着（它不提供调试接口）。

**判据（必须同时满足）**：
```bash
# ① 端口在听
netstat -ano | grep ":9222.*LISTENING"
# ② 而且它真的是 CDP —— 看有没有 Browser 字段
curl -s http://127.0.0.1:9222/json/version     # 期望: {"Browser":"Chrome/...","Protocol-Version":"1.3",...}
```
**只看 ① 会误判**。② 返回空 / 非 JSON ⇒ 那不是 CDP。

**为什么不干脆换端口**：不能只看默认端口 —— 调试端口被占用时 Chrome 会**顺延**（9222→9223…），
所以正确做法是**扫描一段区间找真正响应 CDP 的那个**，而不是死盯 9222。

## 附：带登录态拉起调试 Chrome 的正确姿势

```bash
chrome.exe --remote-debugging-port=<port> \
           --user-data-dir=<稳定目录，别用 %TEMP%> \
           --no-first-run --no-default-browser-check \
           --new-window <目标URL>
```
- **必须独立 `--user-data-dir`**：已运行的 Chrome 会吞掉调试参数，端口不生效。
- **从 Windows 命令行启动**用 `cmd /c start "" "chrome.exe" ...`；用某些 shell 的 `Start-Process`
  或含反引号的命令容易在路径/参数上出错（实测报 shell 语法错）。

## 合作纪律（与用户配合的观测）

「先开窗口，再请人操作」：观测窗口是**实时**的，已发生的操作抓不回来。
所以必须**先把窗口开好**，在同一条回复里告诉用户"现在开始、请在同一个标签页内操作"，
用户回复完成后再一次性读取结果。反过来（先说后开）会导致用户的操作落在窗口外，白跑一轮。

## 进化动作

- [x] 新增了 pitfalls 记录

## 环境信息

- OS: win32 x64 ｜ 浏览器: Chrome 155

---

<!-- [进化统计] 本次新增模式: 2（profile 持久化判据 / CDP 端口双重判据） | 本次修复工具链问题: 2 -->
