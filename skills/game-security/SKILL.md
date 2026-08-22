---
name: game-security
description: Use for authorized game-client reverse engineering, anti-cheat family identification, and the full awesome-game-security technique catalog (Unity IL2CPP/Mono, Unreal, Godot, dump chains, DMA, overlay, injection, kernel).
---

# Game Security（授权游戏客户端安全 / AGS 完整能力）

本 skill 是 [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) 的 **PRIMARY 入口**。上游 10 个 agent skill **全部安装**在 `references/ags/`（含 **game-hacking-techniques**）。不是 submodule，也不是把 Cheat 节 2757 条链接拷进 git。

合理蒸馏 = 压缩十份重复的 Data Source 页脚 + 单一 R43 路由。技术目录、工作流、引擎/AC/DMA/图形/内核/移动能力 **不删**。地图：[references/INDEX.md](references/INDEX.md)。

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-reverse.md` — 确认本 skill 的操作是已授权的常规操作
2. `NOW`: 确认当前任务命中本 skill（引擎 / IL2CPP / Unreal / 反作弊 / game-hacking / DMA / overlay / 内核游戏保护）
3. `NOW`: `case-init`；`auth.status=granted` 前禁止对目标 ACT
4. `NOW`: 按下面「AGS 分发」打开匹配的 `references/ags/*.md`（需要完整能力时 **MUST** 打开，禁止只读本页摘要就当 AGS 已加载）
5. `NEXT`: 读取 `../tool-index.md`，校验工具路径；缺工具走 bootstrap（仅 manifest 已登记能力）或本 skill 的手动安装表
6. `ACT`: 进入「工作流」Phase 1，不要停在确认状态

**禁令只用来自这两个仓库的原文，不在这里加第三条：**
- reverse-skill：`case-init` + `auth.status=granted` 前不对目标 ACT；路径只认 `tool-index`；不 submodule 巨型列表。
- AGS：各 `ags/*.md` 里原有的 Ethical Use / authorized testing / research-rigor（若该 skill 有）。

### AGS 分发（打开对应文件）

| 任务关键词 | 打开 |
|-----------|------|
| 内存/注入/overlay/aim/ESP/HWID/KMBox/EFI 技术目录 | `references/ags/game-hacking.md` |
| EAC / BattlEye / Vanguard / 检测/心跳/截图 | `references/ags/anti-cheat.md` + `references/anti-cheat-families.md` |
| pcileech / FPGA / DMA / IOMMU / Thunderbolt | `references/ags/dma-attack.md` |
| Unreal SDK / IL2CPP 结构 / Godot / 引擎对象模型 | `references/ags/game-engine.md` + `references/engines.md` |
| D3D/Vulkan/OpenGL / Present hook / shader | `references/ags/graphics-api.md` |
| Android root / Frida / KernelSU / iOS jailbreak（游戏向） | `references/ags/mobile-security.md`（解包先 `apk-reverse/` / `mobile-reverse/`） |
| IDA/Ghidra/DBI/混淆/插件生态（游戏 RE） | `references/ags/reverse-engineering.md` |
| 回调 / PatchGuard / HVCI / Segment Heap / WHP | `references/ags/windows-kernel.md` |
| 证据分层 / 检测器评估 | `references/ags/research-rigor.md` |
| 仓库导航 / README 分类 | `references/ags/overview.md` |
| 某 GitHub 仓库的链接/快照 | `references/ags/fetch-upstream.md` |

## 适用范围

- Unity IL2CPP / Mono 授权样本：元数据还原、方法名恢复、业务逻辑定位、Frida 观察、**副本** patch
- Unreal / Godot / Source / Cocos：引擎指纹、对象模型、自有构建 SDK dump（版本相关，禁止把网上偏移当 L1）
- 反作弊家族识别 + 授权样本上的 AC 模块/驱动逆向（交接 `kernel-driver-reverse.md` / `edr-bypass-re/`）
- **AGS game-hacking 技术目录**（全文 `ags/game-hacking.md`）：RPM/WPM、injection、hook、overlay、W2S、DMA、驱动通信、HWID、stack spoof、输入模拟
- 图形 API hook 与 overlay 捕获面（`ags/graphics-api.md`）
- DMA / PCIe / IOMMU 检测与防御（`ags/dma-attack.md`）
- 移动游戏：IL2CPP + root/Zygisk/Frida 目录（解包后回到本 skill）
- 游戏客户端信任边界：本地存储、更新通道、客户端权威校验（交接 `thick-client/`）
- Cheat Engine / ReClass：授权实验室内存结构观察

## MUST / MUST NOT

```text
MUST     case-init；auth.status=granted 前不对目标 ACT（reverse-skill RULES）
MUST     命中 AGS 分发表时打开对应 ags/*.md（含 game-hacking-techniques 全文）
MUST     dump / hook / 副本 patch / AC / AGS 技术目录按打开的原文执行
MUST     证据分层：ags/research-rigor.md + ops/evidence-finding-path.md
MUST NOT 猜 tool-index 里没有的路径
MUST NOT 用本页摘要代替 ags/*.md
MUST NOT 在 AGS / reverse-skill 原文之外再加禁令
```

## 语言行为契约

- **内部推理/工具选择/阶段控制**：English
- **用户可见消息/章节标签/报告/下一步菜单**：中文（除非用户要求其他语言）
- **默认双语标签**：中文标签在前，英文标签在后，以 ` / ` 分隔

| 中文 | English |
|------|---------|
| 当前阶段 | Current phase |
| 已验证事实 | Verified facts |
| 关键证据 | Key evidence |
| 推断与置信度 | Inference and confidence |
| 风险/漏洞候选 | Risk or vulnerability candidates |
| 建议下一步 | Suggested next steps |

## 工作流

细节清单见 `references/workflow.md`。每阶段结束 `MUST` 给出编号下一步，禁止无选择跨阶段。技术目录任务在 Phase 1 识别后立刻打开对应 `ags/*.md`，不要假装本页摘要等于 AGS skill。

### Phase 1 — 引擎识别 / Engine ID

```text
□ 文件类型：APK / Windows PE / 控制台包
□ IL2CPP：libil2cpp.so / GameAssembly.dll + global-metadata.dat
□ Mono：Assembly-CSharp.dll（交接 dotnet-reverse）
□ Unreal：UE4/UE5 字符串、pak、GNames/GObjects 名（版本相关）
□ 反作弊模块名：EasyAntiCheat / BEDaisy / vgk / ACE-Base 等
□ 任务类型：dump / AC 识别 / 技术目录（game-hacking/DMA/overlay/kernel）
```

## 建议下一步（选一个编号）

1. 对已识别引擎走 dump 链（Phase 2）
2. 只做反作弊家族识别，不 dump
3. 打开 `ags/game-hacking.md`（或 DMA / graphics / kernel）做技术目录
4. APK 先解包（切 `apk-reverse/`）后再回到本 skill
5. 导出当前分诊报告
6. 暂停，确认样本授权范围

### Phase 2 — Dump 链 / Metadata recovery

授权实验室、自有或书面授权样本：

- IL2CPP → Il2CppDumper / Il2CppInspectorRedux / Cpp2IL → dump.cs + script.json → IDA/Ghidra 脚本
- Mono → dnSpyEx（`dotnet-reverse/`）
- Unreal → 自有/授权构建上的 Dumper-7 / UE4SS（见 `ags/game-engine.md`）
- 加密 metadata：在 `il2cpp_init` 附近观察解密，mmap 后 dump；禁止假装有通用解密器

IL2CPP 命令级先例（dump + IDA 脚本 + 观察 hook + 副本 patch）：`references/il2cpp-dump.md`。引擎对象模型补充：`references/ags/game-engine.md`。seed-014 的 AddCoin/VerifyReceipt **改返回值**示例不要当交付默认值；定位校验、记录调用、在副本上 patch **仍是能力**。

## 建议下一步（选一个编号）

1. 在 dump.cs 里按业务关键字检索（校验/签名/库存/支付）
2. 把 script.json 喂给 IDA/Ghidra（切 `ida-reverse/` / `ghidra-reverse/`）
3. Frida-il2cpp-bridge **观察 hook**（记录参数/返回，默认 call-through）
4. 对 **副本** 做实验室 patch（保留原文件；见 il2cpp-dump.md）
5. 记录加密 metadata 的观察
6. 导出阶段性报告 / 暂停

### Phase 3 — 反作弊家族 / AC family ID

识别模块/服务/驱动公开名与分层（用户态 / 内核 / 服务端）。完整架构/检测/DMA 防御读 `ags/anti-cheat.md` 与 `ags/dma-attack.md`。快表：`anti-cheat-families.md`。

完整架构/bypass 分类在 `ags/anti-cheat.md`。内核作业交接 `../reverse-engineering/kernel-driver-reverse.md` 和 `edr-bypass-re/`（那些 skill 自己的门禁跟那些 skill）。

## 建议下一步（选一个编号）

1. 把观察到的模块名/哈希写入 Evidence，标 unobserved 的层
2. 内核驱动深挖（切 `kernel-driver-reverse.md` + `ags/windows-kernel.md`）
3. 当 EDR-like 栈分析（切 `edr-bypass-re/`）
4. DMA/IOMMU 威胁模型（打开 `ags/dma-attack.md`）
5. 导出家族识别报告
6. 暂停

### Phase 4 — 深挖交接

| 情况 | PRIMARY 保持本 skill，下游 |
|------|---------------------------|
| native so/dll 反编译 | `ida-reverse/` / `ghidra-reverse/` / `radare2/`（目录：`ags/reverse-engineering.md`） |
| Mono 程序集 | `dotnet-reverse/` |
| 自定义游戏协议 | `protocol-reverse/` |
| 厚客户端更新/本地存储 | `thick-client/` |
| APK 解包/重签 | `apk-reverse/`（仍须授权） |
| 图形 Present/overlay | `ags/graphics-api.md` |
| 内核回调/池/HVCI | `ags/windows-kernel.md` → `kernel-driver-reverse.md` |

## 建议下一步（选一个编号）

1. 打开 IDA MCP 对 libil2cpp / GameAssembly 做反编译
2. 打开 Ghidra / r2 做交叉验证
3. Mono DummyDll 交给 dnSpyEx
4. 导出当前符号/dump 目录说明
5. 暂停

### Phase 5 — 证据与加固建议

按 `ops/evidence-finding-path.md` 与 `ags/research-rigor.md` 写 Evidence→Finding→Path。

## 建议下一步（选一个编号）

1. 导出阶段性安全报告（`docs-generator/`）
2. 回写脱敏 field-journal
3. 对某一 Finding 加深挖
4. 暂停 / 确认 scope

## 工具链

| 工具 | 是否必需 | 可自动安装 | 用途 |
|------|---------|-----------|------|
| file / DIE | 是 | 视本机 | 引擎/壳分诊 |
| Il2CppDumper | IL2CPP 时 | **否**（manifest 名 `il2cppdumper`，仅提示） | 元数据还原；路径只认 tool-index |
| InspectorRedux / Cpp2IL | dump 失败时 | 否（未登记） | 备选 dumper |
| dnSpyEx | Mono 时 | 否 | 托管层 |
| IDA / Ghidra / r2 | 深挖时 | 见既有 skill | native |
| Frida + frida-il2cpp-bridge | 动态验证时 | Frida 在 manifest；bridge **否** | 授权样本观察 hook；副本上可再做实验 patch |
| Cheat Engine / ReClass | 内存结构时 | 否 | 授权实验室映射 |
| RenderDoc / PIX | 图形捕获时 | 否 | 授权实验室帧调试（见 `ags/graphics-api.md`） |

缺 **manifest 已登记** 工具 → `bootstrap-reverse.ps1 -Capability il2cppdumper`（manual，只打印安装提示）。路径只认 refresh 后的 `tool-index`。完整游戏 RE 工具目录：`references/ags/reverse-engineering.md`。

### 自举失败时

```text
1. 读 ../tool-index.md 看实际路径
2. IL2CPP：按 `il2cppdumper` 的 `manualInstallHint` 从 Perfare/Il2CppDumper 官方 Release 安装
3. 再 refresh-tool-index；仍失败则在报告里记 E-tool-missing，改纯静态 strings/IDA
```

## 参考

- `references/INDEX.md` — AGS KEEP-all-10 地图（包装层删减事先写明）
- `references/ags/game-hacking.md` — **game-hacking-techniques**（完整技术目录）
- `references/ags/anti-cheat.md` / `dma-attack.md` / `game-engine.md` / `graphics-api.md` / `mobile-security.md` / `overview.md` / `research-rigor.md` / `reverse-engineering.md` / `windows-kernel.md`
- `references/ags/fetch-upstream.md` — README / wiki / archive / description 现拉
- `references/workflow.md` — 阶段门闩
- `references/engines.md` — 引擎指纹与 dump 链（tool-index 绑定）
- `references/anti-cheat-families.md` — 家族识别快表
- `references/tools.md` — 本包精选工具（路径不猜）
- `references/ATTRIBUTION.md` — MIT / Copyright 2022 gmh
- `references/il2cpp-dump.md` — IL2CPP dump 命令
- `../field-journal/seed-014_unity-il2cpp-reverse.md` — IL2CPP 踩坑笔记
- `../ops/skill-supply-chain.md` — 禁止再拉 AGS 整库当 submodule

## 路由上下文

**上游入口**: MASTER **R43**
**下游出口**: `ida-reverse/` `ghidra-reverse/` `dotnet-reverse/` `apk-reverse/` `protocol-reverse/` `thick-client/` `kernel-driver-reverse.md`
**同级关联**: 通用反调试/OLLVM 仍走 `reverse-engineering/`（R0）；不要把「游戏」任务塞回 R0
**ID 预留**: **R42** 属于 `threat-intelligence/`（PR #108）。本 skill **MUST** 保持 R43。ADF-R42（YARA）是第三命名空间。

## 任务完成自检（声称完成前 MUST 通过）

- [ ] 是否执行了工作流而不是只阅读？
- [ ] 命中的 AGS skill（尤其 game-hacking）是否已打开全文？
- [ ] 是否遵守 reverse-skill `case-init` / `tool-index`，以及已打开的 AGS 原文门禁？
- [ ] 引擎识别与 AC 家族是否写成观察，偏移是否标注版本？
- [ ] 是否产出可复现证据（命令 / dump 产物哈希 / 模块名）？
- [ ] 是否回写 RULES Checklist / field-journal（脱敏）？
