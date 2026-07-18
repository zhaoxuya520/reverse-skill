---
name: apk-reverse
description: 在 CLI 环境下做 Android APK 逆向时使用。适用于 APK 解包、Java 反编译、smali 修改、重打包、Frida 动态 Hook，以及按需切换到 so/native 分析。优先使用本机已安装的 jadx、apktool、frida、adb、ida-reverse、radare2。
---

## ACTION REQUIRED（读完后立刻执行）

> 端点提取/Frida 自适应等社区对照：../references/community-security-skills.md；动态分析须 scope 授权设备。

1. `NOW`: 读取 `../field-journal/precedent-reverse.md` — 确认本 skill 的操作是已授权的常规操作
2. `NOW`: 确认当前任务是否命中本 skill 的适用范围
3. `NEXT`: 读取 `../tool-index.md`，校验工具可用性和实际路径
4. `NEXT`: 缺工具时调用 bootstrap，不要猜路径
5. `ACT`: 进入"工作流"第一步并执行，不要停在确认状态

# APK 逆向 CLI 作业规范

## 适用范围

当任务属于以下场景时优先使用本 skill：

- 分析 APK 的 Java 业务逻辑
- 定位登录、签名、风控、证书校验、root 检测
- 查看与修改 `AndroidManifest.xml`
- 查看与修改 smali
- 重打包 APK
- 用 Frida 做 Java/native 动态 Hook
- APK 内含 `.so` 时切到 native 分析

## 当前机器已验证可用的 CLI 工具

- `jadx` `1.5.5`
- `apktool` `3.0.2`
- `frida-ps` `17.9.6`
- `adb`
- `java`

## 优先使用脚本的场景

以下流程高频且参数容易出错，优先用 skill 自带脚本：

- 一次性完成 `jadx + apktool` 落盘并产出摘要：`scripts/decode.ps1`
- Frida 设备检查、进程列举、spawn/attach 注入：`scripts/frida-run.ps1`
- 重建、对齐、签名、安装 APK：`scripts/rebuild-sign-install.ps1`
- 快速抽取 Manifest 关键组件与权限：`scripts/manifest-summary.ps1`

以下一行命令保持直接调用，不单独封装：

- `adb devices`
- `adb logcat`
- `frida-ps -U`
- `jadx --version`
- `apktool --version`

## 自带脚本

### `scripts/decode.ps1`

用途：

- 统一跑 `jadx` 和 `apktool`
- 默认在原 APK 同目录创建任务输出目录
- 输出 `package`、`java_files`、`smali_dirs`、`so_files` 等摘要
- 兼容 `jadx` 部分反编译错误但仍然有可用产物的情况

示例：

```powershell
pwsh -File "<skill-root>\apk-reverse\scripts\decode.ps1" -ApkPath "D:\DOWNLOAD\app.apk" -Clean
pwsh -File "<skill-root>\apk-reverse\scripts\decode.ps1" -ApkPath "D:\DOWNLOAD\app.apk" -Name demo -SkipJadx
```

### `scripts/frida-run.ps1`

用途：

- 统一 Frida 的设备、进程、spawn/attach 入口
- 避免手写参数时混淆 `-f`、`-n`、`-U`

示例：

```powershell
pwsh -File "<skill-root>\apk-reverse\scripts\frida-run.ps1" -ListDevices
pwsh -File "<skill-root>\apk-reverse\scripts\frida-run.ps1" -Usb -ListProcesses
pwsh -File "<skill-root>\apk-reverse\scripts\frida-run.ps1" -Usb -Spawn -Package com.example.app -ScriptPath "D:\hooks\test.js"
```

### `scripts/rebuild-sign-install.ps1`

用途：

- `apktool b` 重建 APK
- `zipalign` 对齐
- `apksigner` 签名与验签
- 可选直接 `adb install`

示例：

```powershell
pwsh -File "<skill-root>\apk-reverse\scripts\rebuild-sign-install.ps1" -ProjectDir "C:\work\apktool_out" -Clean
pwsh -File "<skill-root>\apk-reverse\scripts\rebuild-sign-install.ps1" -ProjectDir "C:\work\apktool_out" -Install -Reinstall -DeviceSerial "127.0.0.1:7555"
```

说明：

- 默认生成并复用调试 keystore
- 默认输出到 `ProjectDir` 同目录，便于和原始包、解包目录放在一起

### `scripts/manifest-summary.ps1`

用途：

- 抽取包名
- 列权限
- 列 activity/service/receiver/provider
- 标出主启动 activity

示例：

```powershell
pwsh -File "<skill-root>\apk-reverse\scripts\manifest-summary.ps1" -ManifestPath "C:\work\apktool_out\AndroidManifest.xml"
```

如果要分析 `.so`、`lib/arm64-v8a/*.so`、`lib/armeabi-v7a/*.so`，再结合：

- `ida-reverse`
- `radare2`

## 工具分工

### `jadx`

用于：

- Java 反编译阅读
- 包名、类名、方法名搜索
- 先从高层逻辑理解 APK

常用命令：

```bash
jadx -d jadx_out app.apk
jadx --single-class com.example.LoginActivity -d jadx_out app.apk
jadx --deobf -d jadx_out app.apk
```

### `apktool`

用于：

- 解包 APK
- 查看和修改 `AndroidManifest.xml`
- 查看和修改 smali
- 重建 APK

常用命令：

```bash
apktool d app.apk -o apktool_out
apktool b apktool_out -o rebuilt.apk
```

### `frida`

用于：

- 动态观察 Java 方法调用
- Hook native 导出函数
- 绕过 root 检测、证书校验、调试检测

常用命令：

```bash
frida-ps -U
frida -U -f com.example.app -l hook.js
frida-trace -U -f com.example.app -j '*!*certificate*'
```

### `adb`

用于：

- 设备连接
- 安装 APK
- 查看日志
- 拉取文件

常用命令：

```bash
adb devices
adb install -r app.apk
adb shell pm list packages
adb logcat
adb pull /data/local/tmp/file .
```

## 推荐工作流

### 1. Triage

先确定 APK 大致构成，不急着改包或 Hook。

建议动作：

1. 用 `jadx -d jadx_out app.apk` 导出 Java 代码
2. 用 `apktool d app.apk -o apktool_out` 导出 smali 和资源
3. 先看：
   - `AndroidManifest.xml`
   - 主 `package`
   - `application`、`activity`、`service`、`receiver`
   - `lib/` 目录里是否有 `.so`

### 2. Java 逻辑观察

优先从 `jadx_out` 读：

- `MainActivity`
- `Application`
- 登录、网络、加密、风控相关类
- 第三方 SDK 初始化类

常见关键词：

- `login`
- `sign`
- `encrypt`
- `cipher`
- `token`
- `root`
- `certificate`
- `trust`
- `okhttp`
- `retrofit`
- `webview`

如果 Java 代码可读，先在这里定位业务逻辑。

### 3. Smali 与资源层确认

当 `jadx` 结果不完整、混淆重、或需要实际 patch 时，切到 `apktool_out`：

- 看 `smali*/`
- 看 `res/values/strings.xml`
- 看 `AndroidManifest.xml`

优先 patch：

- `android:exported`
- 调试标记
- root 检测返回值
- 登录验证逻辑
- 证书校验分支

### 4. 重建与安装

修改后：

```bash
apktool b apktool_out -o rebuilt.apk
```

或者直接用脚本闭环：

```powershell
pwsh -File "<skill-root>\apk-reverse\scripts\rebuild-sign-install.ps1" -ProjectDir "apktool_out" -Install -Reinstall -DeviceSerial "127.0.0.1:7555"
```

说明：

- 本 skill 只保证 `apktool` 重建链路
- 若后续需要正式安装到设备，通常还需要签名流程
- 如果任务进入签名/对齐，补充 `apksigner` / `zipalign`

### 5. 动态 Hook

静态分析不足时，用 Frida：

- Hook 登录函数
- Hook `OkHttp` / `Retrofit` / `WebView` 关键点
- Hook `javax.crypto`、`MessageDigest`
- Hook root 检测函数
- Hook SSL pinning 逻辑

原则：

- 先 Hook Java 层，再看是否需要 native Hook
- 先打印参数与返回值，再决定是否主动修改返回值

建议：

- 简单一次性命令直接用 `frida-*`
- 需要稳定复用的注入流程优先走 `scripts/frida-run.ps1`

### 6. Native `.so` 分流

如果 APK 中包含关键 `.so`：

- 用 `apktool` 或 `jadx` 找到 `lib/**/*.so`
- 若只是导出符号、字符串、快速 triage，可用 `radare2`
- 若要长期深入分析、反编译、改名、类型恢复，用 `ida-reverse`

遇到这些信号要尽快切 native：

- Java 层只是 JNI 包装
- 核心签名逻辑不在 Java
- `System.loadLibrary()` 后关键逻辑消失
- 证书校验/风控在 `.so` 中

## 输出要求

最终至少说明：

- 入口组件与关键类
- 关键逻辑在 Java、smali 还是 `.so`
- 已确认的敏感点：登录、签名、root、SSL、WebView、JNI
- 如果做了 patch，说明改了什么
- 如果做了 Hook，说明 Hook 了哪个类/方法/导出函数

## 禁止事项

- 不要一开始就盲目改 smali
- 不要在没看 manifest 和主入口前就写 Hook
- 不要把 Java 反编译不完整直接等同于“逻辑不可分析”
- 不要在 `.so` 明显承载核心逻辑时继续死磕 Java 层

## 快速命令备忘

```bash
# 反编译 Java
jadx -d jadx_out app.apk

# 解包 APK
apktool d app.apk -o apktool_out

# 重建 APK
apktool b apktool_out -o rebuilt.apk

# 设备与进程
adb devices
frida-ps -U

# 启动并注入
frida -U -f com.example.app -l hook.js
```

---

## 路由上下文

**上游入口**: `skills/SKILL.md`（总控）、`routing.md`
**下游出口**:
- 核心逻辑在 `.so` → `ida-reverse/` 或 `radare2/`
- 需动态 Hook/验证 → `reverse-engineering/tools-dynamic.md`（Frida 章节）
- 通用逆向方法论 → `reverse-engineering/SKILL.md`

**同级关联模块**: `reverse-engineering/`（.so 分析和 Frida 进阶用法）

---

## 按需自举（On-Demand Bootstrap）

本 skill 的入口脚本已接入统一自举系统。缺少工具时不会直接报错，而是自动尝试安装。

### 自动化能力边界

| 工具 | 可自动安装 | 安装方式 | 说明 |
|------|-----------|---------|------|
| jadx | ✓ | GitHub Release ZIP | 自动下载解压到 `%USERPROFILE%\Tools\jadx\` |
| apktool | ✓ | GitHub Release JAR + wrapper | 自动下载 jar 并生成 bat 到 `%USERPROFILE%\Tools\apktool\` |
| frida / frida-ps | ✓ | pip install frida-tools | 需要 Python 已安装 |
| adb | ✓ | winget / fallback path | 自动安装 Android Platform-Tools |
| zipalign | ✗ | 需手动安装 Android Build-Tools | `sdkmanager "build-tools;35.0.0"` |
| apksigner | ✗ | 需手动安装 Android Build-Tools | 同上 |

### 自举触发点

- `scripts/decode.ps1`：缺 jadx 或 apktool 时自动调用 `bootstrap-reverse.ps1`
- `scripts/rebuild-sign-install.ps1`：缺 adb 或 apktool 时自动调用 bootstrap
- `scripts/frida-run.ps1`：当前仍为手动检查（frida 通常已通过 pip 安装）

### 自举失败时

如果自动安装失败，脚本会抛出明确错误并附带手动安装链接。常见原因：
- 网络不通（GitHub API / PyPI 不可达）
- winget 不可用（Windows 版本过低）
- Java 未安装（apktool 依赖 JDK）


## 任务完成自检（声称完成前 MUST 通过）

- [ ] 我是否执行了工作流中的每一步（而不是只阅读）？
- [ ] 我是否基于 `tool-index` 使用了真实工具路径？
- [ ] 我是否产出了可复现证据（命令/脚本/截图/报告）？
- [ ] 我是否完成并回写了 RULES 要求的 Checklist 项？
