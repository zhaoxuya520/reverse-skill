# 游戏安全工作流门闩

配合 `../SKILL.md`。每阶段结束必须停在编号菜单。默认打开引擎/AC/`dma-attack.md` 检测全文。`game-hacking.md` 只在威胁模型/检测面任务打开。本页不是 AGS 完整 skill。

## Phase 1 — 引擎识别

1. `file` / DIE / 目录名：APK、`GameAssembly.dll`、`UnityPlayer.dll`、`UE4Game`/`UnrealEngine`、`libgodot`、`engine.dll`（Source）
2. IL2CPP vs Mono：有 `libil2cpp.so` / `GameAssembly.dll` + `global-metadata.dat` → IL2CPP；仅 `Assembly-CSharp.dll` → Mono
3. 记录 **已验证事实**：路径、哈希、引擎猜测与置信度
4. 列出疑似 AC 模块名；完整检测分类打开 `ags/anti-cheat.md`（架构/检测面，不当 bypass 教程）

门闩：未写出引擎类别，禁止进入 Phase 2 dump。

## Phase 2 — Dump（授权样本）

| 引擎 | 输入 | 产物 | 失败时 |
|------|------|------|--------|
| IL2CPP | so/dll + metadata | dump.cs, il2cpp.h, script.json, DummyDll | InspectorRedux / Cpp2IL；加密则 mmap 后 dump |
| Mono | Assembly-CSharp.dll | dnSpy 工程 | 切 `dotnet-reverse/` |
| Unreal | 自有/授权构建 | 头文件/对象名（版本相关） | 禁止把网上偏移表当 L1 |
| Godot | PCK / GDScript | 资源列表 | 不要当 Unity 流程套用 |

`MUST` 把 dump 产物哈希写入 Evidence。dump 之后继续 Frida / 副本 patch（见 `il2cpp-dump.md`）。

## Phase 3 — 家族识别

对照 `anti-cheat-families.md` 的模块/服务/驱动公开名。只记录：

- 家族名
- 用户态 / 内核 / 服务端哪一层被观察到
- 证据（文件名、服务名、驱动名、字符串）

未观察到 ≠ 「没有 AC」。写成 **unobserved in this sample**。

## Phase 4 — 深挖交接

只在用户选了编号之后切 skill。带上：样本路径、引擎、dump 目录、未解决问题。

## Phase 5 — 合成

- Evidence：命令与产物
- Finding：客户端权威、可离线伪造的校验、缺失的服务端校验
- Path：按 `ags/research-rigor.md` + `ops/evidence-finding-path.md`
