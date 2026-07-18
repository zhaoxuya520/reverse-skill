---
name: browser-extension-reverse
description: Use for authorized reverse engineering of browser extensions (Chrome/Firefox) including manifest analysis, background workers, and extension-based credential or traffic logic recovery.
---

# Browser Extension Reverse Engineering

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-reverse.md`
2. `NOW`: 确认目标是**浏览器扩展**（crx/xpi/解压目录），不是普通网页 JS（普通 → `js-reverse/`）
3. `NEXT`: 解压扩展；读 manifest
4. `ACT`: 权限面 → 后台脚本 → 网络/存储钩子

## 适用场景

- Chrome/Edge MV2/MV3 扩展分析
- Firefox 扩展
- 恶意扩展 IOC、供应链扩展投毒调查
- 扩展实现的签名/加密/代理逻辑还原

## 工作流

### 1. 包体

```text
□ crx 解压 / 从 profile 取扩展目录
□ manifest.json：permissions、host_permissions、background、content_scripts
□ 评估过度权限（<all_urls>、webRequest、debugger）
```

### 2. 逻辑

```text
□ service_worker / background 入口
□ content_script 注入点与世界（isolated）
□ chrome.storage / IndexedDB 密钥
□ 与 `js-reverse` 相同：Observe 网络与消息传递（runtime.sendMessage）
```

### 3. 动态

```text
□ 开发者模式加载解压目录
□ chrome://extensions 检查错误
□ DevTools 附加 service worker
□ 必要时 Frida/浏览器 CDP（jshookmcp）
```

## 工具链

| 工具 | 用途 |
|------|------|
| 解压/jq | manifest |
| Chrome DevTools | worker 调试 |
| js-reverse 工具链 | 深度 JS |
| YARA | 恶意扩展规则 |

## 参考

- `references/extension-analysis.md`
- field-journal 扩展恢复相关条目
- `../js-reverse/` `../malware-analysis/`

## 路由上下文

**上游**: MASTER R30  
**下游**: 复杂混淆 JS → `js-reverse`；投毒调查 → supply-chain / malware

## 任务完成自检

- [ ] 是否列出权限面与入口脚本？
- [ ] 是否还原关键数据流？
- [ ] Checklist？