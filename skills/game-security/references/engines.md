# 游戏引擎识别（RE / 防御）

> 本页是 reverse-skill **磁盘指纹 + dump 链**（绑定 tool-index）。引擎对象模型 / SDK dump 工作流补充：[ags/game-engine.md](ags/game-engine.md)。  
> Distill from [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, 2026-08-22).

## 授权（reverse-skill）

- **MUST** 在 `auth.status=granted` 且合法 `network_profile` / `offline-sample` 就绪后才 ACT（`ops/scope-contract.md`）。
- 引擎对象模型 / SDK dump 全文：[ags/game-engine.md](ags/game-engine.md)。aimbot / overlay / DMA 全文：[ags/game-hacking.md](ags/game-hacking.md)。
- 引擎全局是 **version-specific 名字**，不是固定偏移（AGS research-rigor）。

## 磁盘制品识别

| Engine | 关键 on-disk 制品 | 不要当成 |
|--------|-------------------|----------|
| **Unity IL2CPP** | Win: `GameAssembly.dll` + `UnityPlayer.dll` + `global-metadata.dat`（常见 `Data/il2cpp_data/Metadata/`）。Android: `libil2cpp.so` + `libunity.so` + `assets/bin/Data/Managed/Metadata/global-metadata.dat` | Mono CLR / `Assembly-CSharp.dll` 即全部逻辑 |
| **Unity Mono** | `Assembly-CSharp.dll`（常有 `Assembly-CSharp-firstpass.dll`），`mono-2.0-bdwgc.dll` / `libmonobdwgc-2.0.so`，`Data/Managed/` | `GameAssembly.dll` / `libil2cpp.so` |
| **Unreal UE4/UE5** | `UnrealEditor*` / `UE4Game` / `UE5Game` / `*-Win64-Shipping.exe`，`.pak`，`Engine.ini`。字符串 **名字**：`GNames` / `FNamePool` / `GUObjectArray` / `GObjects` | 把这些名字当固定 RVA / 跨标题偏移 |
| **Godot** | 可执行旁 `.pck`；`libgodot` / `Godot_v*` 字符串。`project.godot` 多在源树，未必进发行包 | `.pck` = Unity metadata |
| **Source / Source 2** | `client.dll` `engine.dll` `server.dll`。S1: `gameinfo.txt`。S2: `gameinfo.gi` + `.vpk` | NetVar 偏移跨版本恒定 |
| **Cocos** | `libcocos2d.so` / `libcocos2dcpp.so` / `libcocos2djs.so`；JS 绑定常见 `project.json` + `main.js` | Unity IL2CPP |

**MUST** 用 DIE / `file` / 目录清单交叉确认。单文件名是 Observation，不是引擎归因。

## 授权样本 dump 链（元数据恢复）

`case-init` 就绪后按 dump 链执行。产物：符号 / 类型 / headers。

| Backend | 工具 | RE 产物 |
|---------|------|---------|
| IL2CPP | Il2CppDumper / Il2CppInspectorRedux / Cpp2IL | DummyDll / `dump.cs` / `script.json` / `il2cpp.h` → IDA/Ghidra |
| Mono | dnSpyEx | 托管 C# / IL → `dotnet-reverse/` |
| Unreal | Dumper-7 / UE4SS | 反射元数据 / headers（见 `ags/game-engine.md`） |

IL2CPP 实验室顺序：

```text
确认制品 → 配对同一次构建的 binary + global-metadata.dat
→ dumper → DummyDll + script.json
→ IDA/Ghidra 加载脚本做符号恢复 → native 深挖
```

完整链见 [il2cpp-dump.md](il2cpp-dump.md)。seed-014 是踩坑笔记，不是默认配方。

## 加密 metadata

部分包加密 `global-metadata.dat`。实验室：**观察** `il2cpp_init` 附近解密；在 **mmap/read 之后** dump 已解密缓冲再喂 dumper。

- **MUST** 记 Observation（谁打开文件、何时明文出现），再升 Finding。

## 交接

| 看到 | PRIMARY |
|------|---------|
| APK 未解包 | `apk-reverse/` |
| Mono `Assembly-CSharp.dll` | `dotnet-reverse/` |
| `libil2cpp.so` / `GameAssembly.dll` native | `ida-reverse/` / `ghidra-reverse/` |
| 内核 AC 驱动 | [anti-cheat-families.md](anti-cheat-families.md) → `kernel-driver-reverse.md` |

## 证据边界

- `GNames` / `GObjects` / `FNamePool` / `GUObjectArray`：**版本相关名字**，偏移随引擎分支 / 游戏改动。
- Observation ≠ Finding ≠ Path：`ops/evidence-finding-path.md` 与 `ags/research-rigor.md`。
