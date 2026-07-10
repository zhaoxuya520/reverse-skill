# 2026-07-10 Chrome 扩展发布包源码恢复

## 场景分类

JS 逆向 / Chrome 扩展源码恢复

## 目标概述

将本机已安装的 Manifest V3 扩展发布包恢复成可读、可修改、可作为未打包扩展加载的本地项目，同时保留来源哈希和可复现验证。

## 完整执行链路

1. 读取 `manifest.json`，确认 service worker、页面入口、内容脚本、DNR、权限和在线依赖。
2. 复制运行文件并排除 Chrome 生成的 `_metadata/`；保存商店 Manifest 与 SHA-256 基线。
3. 删除开发副本中的商店 `update_url` 和公钥，避免自动更新及扩展 ID 冲突。
4. 对 JS/CSS/HTML 做格式化；运行目录与只读分析快照分开保存。
5. 抽取 Chrome API、网络域名、框架标记、消息常量、API client 和存储键。
6. 用 Node 校验 Manifest/JSON、HTML 引用、JS 语法和非代码资源哈希。
7. 用 Chrome for Testing 临时 profile 加载扩展，确认 service worker 和三个扩展页面目标被浏览器接受。
8. 生成 README、逆向报告和 Mermaid 数据流图。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| `npm install` 返回 `ENOSPC` | APFS 当时只暴露极少可用空间 | 不清理用户文件；放弃非必要 formatter 依赖，使用已安装 Prettier | 低 |
| 对目录执行 Prettier 后大 bundle 未完全展开 | 目录参数没有稳定覆盖所有目标文件 | 使用带引号的递归 glob，并用 `prettier --check` 验证幂等结果 | 中 |
| 品牌版 Chrome headless 出现无关内置扩展 target | `--load-extension` 没有加载目标扩展，误把内置 target 当成功 | 切换 Chrome for Testing，并要求出现目标 `/background.js` service worker | 中 |
| CDP DOM 探针两次超时 | headless 扩展页主线程没有及时响应 Runtime.evaluate | 停止重复；将 smoke 边界收敛为 service worker/页面 target 加载，不声称 UI 完整渲染 | 中 |
| Smoke 后出现 `_metadata/generated_indexed_rulesets` | Chrome 编译 DNR 时写入生成文件 | smoke `finally` 中仅清理项目内生成的 `_metadata/` | 低 |

## 工具链发现

- Node.js 22 可用于 JSON、HTML 引用和 `node --check` 静态验证。
- Prettier 3.9.5 可直接格式化大型发布 bundle，但必须用 `--check` 做最终一致性验证。
- Chrome for Testing 支持隔离 profile 的扩展加载 smoke；品牌版 Chrome headless 不能作为可靠替代。
- Manifest 删除 `key` 会产生新扩展 ID，因此开发副本不会继承原 `chrome.storage` 或登录态。

## 关键代码/命令

```bash
rsync -a --exclude '_metadata/' "{install_dir}/" extension/
prettier --write "extension/**/*.{js,css,html}"
node scripts/validate.mjs
node scripts/smoke-chrome.mjs
```

## 对本包的改进建议

- `js-reverse` 可增加“浏览器扩展发布包恢复”参考：保真副本、开发身份隔离、资源哈希、Manifest 检查、Chrome for Testing smoke。
- smoke 必须验证目标 `background.js`，不能只判断存在任意 `chrome-extension://` target。
- 输出契约应区分“浏览器接受入口”和“DOM/账号/业务路径已验证”。

## 可复用的模式/脚本片段

- 运行目录与来源哈希基线分离。
- Manifest 入口检查 + HTML 资源引用检查 + 所有 JS `node --check`。
- Chrome for Testing 临时 profile；退出后删除临时 profile 和 DNR `_metadata/`。

## 进化动作

- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录
- [ ] 无需更新

## 环境信息

- OS：macOS
- 工具版本：Node.js 22.22.2、Prettier 3.9.5
- 目标平台/版本：Chrome Manifest V3 扩展

## 脱敏检查

- [x] 无真实账号、邮箱、token、Cookie 或密码
- [x] 无个人目录；安装路径使用 `{install_dir}`
- [x] 无用户浏览器 storage 或 profile 内容

## 索引同步

本 PR 不修改 `_index.md`：当前自动审核会扫描整个索引，现有历史关键词会误触 prompt-injection 规则。门禁修复后再补索引，避免提交一个必失败的 PR。

---
<!-- [进化统计] 本包累计完成项目: 9 | 本次新增模式: 1 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 当前仅本地记录，是否提交由用户决定。 -->
