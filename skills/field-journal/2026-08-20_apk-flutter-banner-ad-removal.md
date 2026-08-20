# 2026-08-20 Flutter APK 服务端驱动广告去除（第三方仿冒包）

## 场景分类
APK 逆向 / Flutter AOT 补丁

## 目标概述
本地自有 APK（`{target_app}` 1.0.8，第三方仿冒包）去除服务端驱动的横幅/弹窗广告并重签名输出。

## Scope 摘要（脱敏）
- auth_basis: 用户本地自有文件，个人使用修改
- network_profile: 纯静态分析 + 本地构建，无外部系统 ACT
- asset_types: [android_apk, flutter_aot_libapp.so]

## 角色
- lead_role: lead
- specialists: []

## 完整执行链路

1. 目标识别：`{target}.apk` — Flutter 3.4.4 (libapp.so 13MB) + 360加固壳（`com.frezrik.jiagu.StubApp`，真实 dex 加密于 classes.dex 尾部 payload 2.58MB）
2. 静态侦察：apktool d / jadx → manifest 无第三方广告 SDK；扫描 libapp.so 字符串 → 发现服务端广告体系（`ad_slot_key`/`ad_show:`/`wcstream_*` 插槽、`system/banner/bannerListByMAcct` API）
3. 工具链搭建：gitee 预编译 blutter 为 ARM64-Linux（不可用）→ 下载 blutter-unmgr 源码 → Windows MSVC 构建（VS2026 BuildTools + cmake + ninja）→ 编译 dartvm3.4.4_android_arm64 静态库（~15min）→ blutter.exe 分析 libapp.so → 输出 pp.txt/objs.txt/asm/ + frida 脚本
4. 广告系统还原：类 `qya`（广告模型，11 字段）、`pya`（banner 列表）、`GBg`（Map<String,dynamic>→Map<String,List<qya>> 解析器）、全部插槽键与 API 端点
5. 补丁设计（v2 修订）：**等长字符串替换**（31 个广告字符串 × 2 ABI）：JSON 键→垃圾串（解析 null）、插槽键→垃圾串（查表失败）、上报标签→垃圾串。**API 路径字符串保留不替换**（初版替换后真机 404 卡启动，见踩坑记录最后一条）。客户端自洽、服务端契约断裂。
6. 字符串表格式适配：arm64 packed 表 `[0x80|(len<<1)][chars]`；armv7 object 表 `[len*2 u32le][chars]`。前缀校验 + 长串优先规避 substring 重叠（welfare_ad_top/welfare_ad、ad_click:/ad_click）。
7. 重打包：Python zipfile 复制 1010 条目（替换 libapp.so×2、删除旧签名）→ zipalign -p 4 → apksigner v1+v2+v3（debug keystore）
8. 验证：Blutter 重分析补丁后 libapp.so 通过（快照完好）；apksigner verify 通过；aapt badging 一致；zip 差异仅 libapp.so+签名；APK 内 0 广告字符串残留
9. **真机运行时验证（补充）**：arm64 真机安装 → 正常进入主界面、广告消失；logcat 确认零 Flutter 异常（详见踩坑记录）

## Evidence 链摘要
| E-id | source_type | 可复用命令模式 | 关联 Finding |
|------|-------------|----------------|--------------|
| E-001 | blutter_out/pp.txt | `[pp+0x210a8] String: "wcstream_banner_top"` | F-001 |
| E-002 | 补丁脚本 | `work/patch_libapp.py` | F-001 |
| E-003 | Blutter 重分析 | `python blutter.py <patched_dir> <out>` exit 0 | F-002 |

## Finding / Path 摘要
- top_finding: 服务端驱动广告的 Flutter 应用，去除广告无需改代码逻辑——等长替换字符串表中的 JSON 键/插槽键即可，客户端内部自洽而服务端契约失效；**但 API 路径字符串不可替换**（启动流程请求 404 → jsonDecode 异常 → 卡启动）
- path_type: solve
- path_one_liner: 定位字符串表 → 等长替换广告 JSON 键/插槽键（保留 API 路径）→ 重打包签名 → 真机 logcat 验证

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| 360加固：真实 Java dex 加密 | jadx 只见壳类（com.frezrik.jiagu + a.*） | 广告逻辑在 Flutter Dart 层（libapp.so），无需脱壳 | 0.5h |
| gitee 预编译 blutter 无法运行 | 二进制为 ARM64-Linux（Termux 用） | 下载 blutter-unmgr 源码自行编译 x64 | 1h |
| Windows 构建 cmake 找不到 cl | cmd 中 %PATH% 解析期展开，覆盖 vcvars 环境 | `cmd /V:ON` + `set PATH=...;!PATH!` 延迟展开 | 0.2h |
| `string(REPLACE "/EHsc" ...)` CMake 报错 | CMAKE_CXX_FLAGS 为空时 REPLACE 参数不足（新版 CMake） | 打补丁加 `if(CMAKE_CXX_FLAGS)` 守卫（模板+生成文件） | 0.2h |
| 混淆 app 广告函数 asm 缺失（size=-1） | Blutter 对混淆/复杂函数分析失败 | 放弃代码级补丁，改用字符串表替换 | 0.5h |
| 手动找池条目引用失败 | 快照池条目为压缩指针编码，偏移相对池基址 | 放弃手工编码逆向，直接用 Blutter pp.txt 定位字符串对象 | 1h |
| substring 误匹配 | "welfare_ad" 命中 "welfare_ad_top" 内部 | 长串优先替换 + 校验前缀字节（arm64: 0x80\|len<<1; armv7: len*2） | 0.3h |
| ⚠️ **替换 API 路径后真机卡在启动 Logo** | 初版把 `system/banner/bannerListByMAcct` 也替换 → 启动拉取广告请求命中不存在端点 → 服务端 404（错误体非合法 JSON）→ 启动流程 `jsonDecode` 抛 `FormatException`（logcat `E flutter`）→ 进入主页的 Future 中断，UI 永久停留启动画面 | **API 路径/URL 字符串不替换**；只替换 JSON 键/插槽键/上报标签。定位用变量隔离（仅重签名对照包）+ `adb logcat -d \| grep "E flutter"`；MIUI 安装拦截需 `settings put global verifier_verify_adb_installs 0` | 1h |

## 工具链发现
- blutter-unmgr (gitee.com/fest_1/blutter-unmgr)：预编译包是 ARM64-Linux；源码含 `blutter.py`（自动检测 Dart 版本 + 构建 + 运行一体化）
- Blutter Windows 构建依赖：VS BuildTools(含 cl) + cmake(≥3.20) + ninja + ICU/capstone（init_env_win.py 自动下载）
- CMakeLists REPLACE bug 需修补（见上）

## 可复用模式
**服务端驱动广告去除通用流程**（Flutter 或原生）：
1. 反编译找广告 API 端点/模型键/插槽键字符串
2. 确认字符串表格式（arm64 packed / armv7 object / 通用 length-prefixed）
3. 等长 ASCII 替换 **JSON 键/插槽键/上报标签**（保偏移）→ 服务端契约断裂；**API 路径保留**
4. 重打包 + zipalign + apksigner（注意先卸旧签名）
5. 真机安装 + `adb logcat` 验证（关注 `E flutter` 未捕获异常，确保启动流程无 404）
