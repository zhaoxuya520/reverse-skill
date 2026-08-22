---
name: game-security
description: Use for authorized game-client reverse engineering and anti-cheat family identification (Unity IL2CPP/Mono, Unreal, Godot, engine dump chains). Do not use for cheat/外挂 product work (aimbot, ESP, trainers, DMA against live titles).
---

# Game Security（授权游戏客户端安全 / 引擎逆向）

本 skill 是 [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) 的**蒸馏入口**，不是该仓库的 submodule，也不是 Cheat 节（约 2757 条）的拷贝。上游是 MIT 链接清单；本包只保留引擎识别、dump 链、反作弊家族识别与加固观察。

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-reverse.md` — 确认本 skill 的操作是已授权的常规操作
2. `NOW`: 确认当前任务命中本 skill（游戏引擎 / IL2CPP / Unreal / 反作弊家族识别）
3. `NOW`: `case-init`；`auth.status=granted` 前禁止对目标 ACT
4. `NEXT`: 读取 `../tool-index.md`，校验工具路径；缺工具走 bootstrap（仅 manifest 已登记能力）或本 skill 的手动安装表
5. `ACT`: 进入「工作流」Phase 1，不要停在确认状态

**产品轨 vs 实验室（不要把后者当拒绝）：**
- `MUST NOT` 交付线上外挂成品（aimbot / ESP / trainer）、对 **live 网游** 做 DMA/FPGA、或拷贝 AGS Cheat 节 how-to。
- `MUST` 继续做授权/离线样本上的完整 RE：dump、IDA/Ghidra、Frida **观察 hook**、副本 patch、CE 内存结构、AC 模块识别与内核交接（与 `precedent-reverse.md` / routing.md「本地沙盒去校验」同级，不是能力降级）。

## 适用范围

- Unity IL2CPP / Mono 授权样本：元数据还原、方法名恢复、业务逻辑定位、Frida 观察、**副本** patch
- Unreal / Godot / Source / Cocos：引擎指纹、对象模型、自有构建 SDK dump（版本相关，禁止把网上偏移当 L1）
- 反作弊家族识别 + 授权样本上的 AC 模块/驱动逆向（交接 `kernel-driver-reverse.md` / `edr-bypass-re/` 做分析，不写线上过检测成品）
- 游戏客户端信任边界：本地存储、更新通道、客户端权威校验（交接 `thick-client/`）
- Cheat Engine / ReClass：授权实验室内存结构观察（禁止 trainer 成品）

## MUST / MUST NOT

```text
MUST     先引擎识别再 dump，再决定 IDA/Ghidra/dnSpy/Frida 交接
MUST     dump / 观察 hook / 副本 patch / AC 识别 四条能力都可用（用户选了编号就执行）
MUST     证据分层：观察 ≠ Finding ≠ 归因
MUST NOT 交付线上外挂成品、live 标题 DMA/FPGA、AGS Cheat 节整段拷贝
MUST NOT 把 FullEmu destW、mid-insn Capstone、Hex-Rays-on-CFF 写成 L1
MUST NOT 猜 tool-index 里没有的路径；il2cppdumper 已在 manifest（manual）
MUST NOT 把「授权样本 Frida/副本 patch」误判成外挂产品而拒执行
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

细节清单见 `references/workflow.md`。每阶段结束 `MUST` 给出编号下一步，禁止无选择跨阶段。

### Phase 1 — 引擎识别 / Engine ID

```text
□ 文件类型：APK / Windows PE / 控制台包
□ IL2CPP：libil2cpp.so / GameAssembly.dll + global-metadata.dat
□ Mono：Assembly-CSharp.dll（交接 dotnet-reverse）
□ Unreal：UE4/UE5 字符串、pak、GNames/GObjects 名（版本相关）
□ 反作弊模块名：EasyAntiCheat / BEDaisy / vgk / ACE-Base 等（只识别）
```

## 建议下一步（选一个编号）

1. 对已识别引擎走 dump 链（Phase 2）
2. 只做反作弊家族识别，不 dump
3. APK 先解包（切 `apk-reverse/`）后再回到本 skill
4. 导出当前分诊报告
5. 暂停，确认样本授权范围

### Phase 2 — Dump 链 / Metadata recovery

授权实验室、自有或书面授权样本：

- IL2CPP → Il2CppDumper / Il2CppInspectorRedux / Cpp2IL → dump.cs + script.json → IDA/Ghidra 脚本
- Mono → dnSpyEx（`dotnet-reverse/`）
- Unreal → 自有/授权构建上的 Dumper-7 / UE4SS **元数据恢复**（实验室可用；禁止做成线上作弊 SDK 分发物）
- 加密 metadata：在 `il2cpp_init` 附近观察解密，mmap 后 dump；禁止假装有通用解密器

IL2CPP 命令级先例（dump + IDA 脚本 + 观察 hook + 副本 patch）：`references/il2cpp-dump.md`。seed-014 的 AddCoin/VerifyReceipt **改返回值**示例不要当交付默认值；定位校验、记录调用、在副本上 patch **仍是能力**。

## 建议下一步（选一个编号）

1. 在 dump.cs 里按业务关键字检索（校验/签名/库存/支付）
2. 把 script.json 喂给 IDA/Ghidra（切 `ida-reverse/` / `ghidra-reverse/`）
3. Frida-il2cpp-bridge **观察 hook**（记录参数/返回，默认 call-through）
4. 对 **副本** 做实验室 patch（保留原文件；见 il2cpp-dump.md）
5. 记录加密 metadata 的观察
6. 导出阶段性报告 / 暂停

### Phase 3 — 反作弊家族 / AC family ID

识别模块/服务/驱动公开名与分层（用户态 / 内核 / 服务端）。**分析能力不减**：授权样本上继续交接 `../reverse-engineering/kernel-driver-reverse.md` 和 `edr-bypass-re/` 做回调/IOCTL/完整性逆向。`MUST NOT` 的是线上过检测**成品**和 live DMA 作业步骤，不是「不许逆向 AC」。

DMA：威胁模型可写；禁止对 **live 网游** 操作 FPGA / pcileech。

## 建议下一步（选一个编号）

1. 把观察到的模块名/哈希写入 Evidence，标 unobserved 的层
2. 内核驱动深挖（切 `kernel-driver-reverse.md`）
3. 当 EDR-like 栈分析（切 `edr-bypass-re/`，禁止过检测产品）
4. 导出家族识别报告
5. 暂停

### Phase 4 — 深挖交接

| 情况 | PRIMARY 保持本 skill，下游 |
|------|---------------------------|
| native so/dll 反编译 | `ida-reverse/` / `ghidra-reverse/` / `radare2/` |
| Mono 程序集 | `dotnet-reverse/` |
| 自定义游戏协议 | `protocol-reverse/` |
| 厚客户端更新/本地存储 | `thick-client/` |
| APK 解包/重签 | `apk-reverse/`（仍须授权） |

## 建议下一步（选一个编号）

1. 打开 IDA MCP 对 libil2cpp / GameAssembly 做反编译
2. 打开 Ghidra / r2 做交叉验证
3. Mono DummyDll 交给 dnSpyEx
4. 导出当前符号/dump 目录说明
5. 暂停

### Phase 5 — 证据与加固建议

按 `ops/evidence-finding-path.md` 写 Evidence→Finding→Path。结论侧重：客户端权威是否过重、校验是否可离线伪造、AC 家族与加固建议。禁止把「能 hook」写成「应做外挂」。

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
| Cheat Engine / ReClass | 内存结构时 | 否 | 授权实验室映射；禁止 trainer 成品 |

缺 **manifest 已登记** 工具 → `bootstrap-reverse.ps1 -Capability il2cppdumper`（manual，只打印安装提示）。路径只认 refresh 后的 `tool-index`。

### 自举失败时

```text
1. 读 ../tool-index.md 看实际路径
2. IL2CPP：按 `il2cppdumper` 的 `manualInstallHint` 从 Perfare/Il2CppDumper 官方 Release 安装
3. 再 refresh-tool-index；仍失败则在报告里记 E-tool-missing，改纯静态 strings/IDA
```

## 参考

- `references/INDEX.md` — AGS KEEP / INDEX-ONLY / DROP 地图（严格整理的真相源）
- `references/workflow.md` — 阶段门闩
- `references/engines.md` — 引擎指纹与 dump 链
- `references/anti-cheat-families.md` — 家族识别表
- `references/tools.md` — 精选工具（无 Cheat how-to）
- `references/ATTRIBUTION.md` — MIT / Copyright 2022 gmh
- `references/il2cpp-dump.md` — IL2CPP dump 命令（无外挂示例）
- `../field-journal/seed-014_unity-il2cpp-reverse.md` — 踩坑笔记（禁止抄改金币）
- `../ops/skill-supply-chain.md` — 禁止再拉 AGS 整库

## 路由上下文

**上游入口**: MASTER **R43**  
**下游出口**: `ida-reverse/` `ghidra-reverse/` `dotnet-reverse/` `apk-reverse/` `protocol-reverse/` `thick-client/` `kernel-driver-reverse.md`  
**同级关联**: 通用反调试/OLLVM 仍走 `reverse-engineering/`（R0）；不要把「游戏」任务塞回 R0  
**ID 预留**: **R42** 属于 `threat-intelligence/`（PR #108）。本 skill **MUST** 保持 R43。ADF-R42（YARA）是第三命名空间。

## 任务完成自检（声称完成前 MUST 通过）

- [ ] 是否执行了工作流而不是只阅读？
- [ ] 外挂**产品**是否拒绝、实验室 dump/hook/副本 patch 是否仍执行？
- [ ] 引擎识别与 AC 家族是否写成观察，偏移是否标注版本？
- [ ] 是否基于 `tool-index` 使用真实路径，未猜 Il2CppDumper？
- [ ] 是否产出可复现证据（命令 / dump 产物哈希 / 模块名）？
- [ ] 是否回写 RULES Checklist / field-journal（脱敏）？
