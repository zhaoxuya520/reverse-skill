# 2026-07-22 Electron Bytenode 特权更新链分析

## 场景分类

二进制分析 / Electron / Bytenode / 更新链安全审计

## 目标概述

对一个 Windows x86 Electron 桌面应用完成从 NSIS 安装器、ASAR、Bytenode JSC 到原生游戏 SDK 和远程渲染页面的跨层逆向，确认权限边界、IPC 能力及更新包信任模型。

## 完整执行链路

1. 对 `{electron_app}` 外层 PE 做 SHA-256、Authenticode、manifest、节区、overlay 和缓解措施检查，确认安装器类型与提权级别。
2. 用 7-Zip 只读展开 NSIS，定位内层归档并重建文件清单；继续提取原始 `app.asar`，保留逻辑偏移、大小和逐文件哈希。
3. 从 `package.json`、运行时资源和 JSC 字符串识别 Electron 22.0.0、Node 16.17.1 与 Bytenode 1.5.7；区分原始提取目录和既有修改目录。
4. 使用样本自带 Electron 的 `ELECTRON_RUN_AS_NODE=1` 模式加载 `main.jsc` 与 `preload.jsc`，解决宿主 Node/V8 ABI 不兼容。
5. 在探针中 mock Electron、网络、文件写入、归档、FFI、子进程和退出；记录窗口选项、21 个主进程 IPC handler、29 个 preload bridge 成员及生命周期回调。
6. 冻结 `{remote_ui_domain}` 的静态资源快照，追踪 `https://{update_api_domain}/api/user/v1/check_ver` 返回的 `updateUrl` 如何进入本地 `checkUpdates`。
7. 以 loopback HTTP fixture 驱动更新 handler，确认 URL 接收、下载、解压和 detached updater 启动序列；把未出现的白名单、哈希、包签名和 Authenticode 校验分别记录为“在受控路径中未观察到”。
8. 对 `{native_game_sdk}` 的导出、导入、字符串、PE 防护、签名和关键地址做静态复核，区分 ABI 转发、回调 FIFO、状态看门狗与第三方平台安装分支。
9. 对服务、驱动、hosts、根证书、代理和平台注册表操作采用“条件性能力”措辞；只在具备调用链证据时描述能力，不推断本次运行已经执行。
10. 输出正式报告、三张数据流图、结构化 IOC、复现命令和证据索引，并在结论中分离高置信静态事实、受控动态事实与远程快照时效边界。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| 宿主 Node 直接加载 JSC 失败 | Bytenode 字节码绑定特定 V8/Node ABI | 使用样本 Electron 的 RunAsNode 模式执行 | 中 |
| 启动探针后定时器和退出逻辑干扰结果 | 主进程包含生命周期回调、看门狗和 `process.exit` | 增加 `--run-timeouts`，mock 定时器、退出与四类 app 回调 | 中 |
| 更新 handler 需要同时触发网络、写盘和子进程路径 | 单纯枚举 handler 只能证明注册，不能证明数据流 | 增加 `--update-url` fixture，全链记录参数和副作用 | 中 |
| 分析目录存在既有修改产物 | 修改后的 ASAR/JSC 会污染原始结论 | 仅将 `{sample_dir}`、`{extracted_original_dir}` 作为原始证据源 | 低 |
| 双签名 DLL 的状态容易误判 | 每条签名的证书、时间戳和当前验证状态可能不同 | 使用 `signtool verify /pa /all /v` 逐签名检查 | 低 |
| Native 字符串显示高权限系统能力 | 字符串和导入并不代表当前路径已执行 | 结合 xref/调用链，并标注“条件性能力” | 中 |
| 远程 UI 会持续变化 | 当前 chunk 和 API 行为不是永久固定资产 | 保存带日期的资源快照、哈希和抓取时间 | 低 |

## 工具链发现

- 样本自带 Electron 是执行 Bytenode JSC 的最稳定 ABI 容器；`ELECTRON_RUN_AS_NODE=1` 可在不启动业务 GUI 的情况下运行探针。
- Electron 模块 mock 需要覆盖 `app.whenReady/on/quit`、`BrowserWindow`、`ipcMain.handle/on`、`shell`、`session` 和 `webContents`，否则只会得到不完整注册面。
- 更新链验证应同时记录输入 URL、请求库、目标文件、解压目录和最终 `spawn` 参数，才能建立 renderer 到 updater 的证据闭环。
- PE 签名审计应将“证书存在”“证书在有效期内”“有可信时间戳”“当前链验证成功”分开描述。
- 大型第三方 DLL 宜先用导入/导出和字符串做能力分区，再对服务、网络、证书和进程创建等高风险分支做地址级复核。

## 关键代码/命令

```powershell
$env:ELECTRON_RUN_AS_NODE = '1'
$env:__COMPAT_LAYER = 'RunAsInvoker'

& '{electron_exe}' '{probe_script}' '{main_jsc}' `
  --execute --exercise=all --run-timeouts --quiet `
  --out='{main_probe_json}'

& '{electron_exe}' '{probe_script}' '{main_jsc}' `
  --execute --exercise=all --run-timeouts `
  --update-url='http://127.0.0.1:{port}/update.zip' --quiet `
  --out='{update_probe_json}'

& '{electron_exe}' '{probe_script}' '{preload_jsc}' `
  --execute --exercise=bridge --quiet `
  --out='{preload_probe_json}'

signtool verify /pa /all /v '{native_game_sdk}'
```

## 对本包的改进建议

1. 在 Electron/JS 逆向路线中增加 Bytenode ABI 决策树：宿主 Node 失败后优先使用目标 Electron 的 RunAsNode 模式。
2. 增加通用 Electron mock 覆盖矩阵和 IPC 注册/调用一致性检查脚本。
3. 在更新器审计模板中固定检查 URL 约束、传输协议、manifest 签名、包哈希、签名链、解压穿越和最终执行参数。
4. 报告模板增加“条件性能力”和“已观察行为”的强制分栏，降低从 imports/strings 过度推断的风险。

## 可复用的模式/脚本片段

1. **三层可信边界**：原始安装器 -> 原始 ASAR/JSC -> 远程页面快照，每层分别建立哈希和时间戳。
2. **注册面与执行面分离**：先枚举 IPC/preload API，再对高风险 handler 使用 mock fixture 调用并捕获副作用。
3. **更新链五元组**：`source URL -> downloader -> archive path -> extractor -> executable`，每个节点都保存证据。
4. **Native 能力分级**：导入/字符串为线索，xref/调用链为能力证据，真实动态事件才作为已执行事实。
5. **签名四态模型**：签名存在性、证书有效期、时间戳、当前信任验证分别报告。

## 进化动作

- [x] 新增了 pitfalls 记录
- [x] 更新了经验索引
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档

## 环境信息

- OS: Windows 11 x64
- 工具版本: Electron 22.0.0, Node 16.17.1, Bytenode 1.5.7, Python 3.12
- 目标平台/版本: Windows x86 / Electron desktop app

## 脱敏要求

本文仅保留通用版本、API 路径结构、数量级和分析方法。样本名、发布者、真实域名、案件目录、哈希、配置密钥、token 与用户标识均已替换或省略；未附带样本文件。

---
<!-- [进化统计] 本包累计完成项目: 11 | 本次新增模式: 5 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
