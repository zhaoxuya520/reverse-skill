# 游戏安全工具（RE / 防御；精选）

> 本页 **不是** AGS 完整 skill。游戏 RE 工具/插件/混淆目录 **MUST** 打开 [ags/reverse-engineering.md](ags/reverse-engineering.md)。本页只绑 `tool-index`。链接堆按 [ags/fetch-upstream.md](ags/fetch-upstream.md) 现拉。

## 路径（reverse-skill）

- **MUST NOT** 猜工具路径。缺工具 → 读 [`tool-index.md`](../../tool-index.md)；未生成则跑 `skills/scripts/refresh-tool-index.ps1`。
- **Il2CppDumper 已登记**为 manifest 名 `il2cppdumper`（`bootstrapKind: manual`，`canAutoInstall: false`）。bootstrap **只打印** `manualInstallHint`。
- 完整游戏 RE 工具/插件目录：[ags/reverse-engineering.md](ags/reverse-engineering.md)。

## 精选表

`bootstrap?`：**是** = 本包 `bootstrap-reverse` 能力名；其余 **手动**（自行 release / 包管理器，再 refresh 索引）。

| 工具 | 用途（防御 / RE） | bootstrap? |
|------|-------------------|------------|
| **Il2CppDumper** | 授权 IL2CPP 样本：`global-metadata.dat` + `GameAssembly.dll` / `libil2cpp.so` → DummyDll / `script.json` | **手动**（能力名 `il2cppdumper`） |
| **Il2CppInspectorRedux** | 新 Unity metadata；IDA/Ghidra/BN 脚本 | 手动 |
| **Cpp2IL** | IL2CPP → 可分析 C# / 调用图（元数据恢复） | 手动 |
| **dnSpyEx** | Unity **Mono** `Assembly-CSharp.dll` 反编译 / IL | 手动（走 `dotnet-reverse/`） |
| **UE4SS** | 反射 / 调试脚本 / SDK dump | 手动 |
| **Dumper-7** | UE 反射 headers | 手动 |
| **AssetStudio** / **UAssetGUI** | Unity/UE 资产检视 | 手动 |
| **Detect It Easy** | 引擎 / 壳 / CLR 指纹 triage | 手动 |
| **IDA Pro** | native `so`/`dll` 深反编译 | 能力 `idalib-mcp` / `idapro`；本体商业手动 → [`ida-reverse/`](../../ida-reverse/SKILL.md) |
| **Ghidra** | 开源 native 深挖 | `ghidra-mcp`（本体常手动）→ [`ghidra-reverse/`](../../ghidra-reverse/SKILL.md) |
| **Frida** | 授权动态插桩 | **是**（`frida` / `frida-ps`）→ [`tools-dynamic.md`](../../reverse-engineering/tools-dynamic.md) |
| **frida-il2cpp-bridge** | **自有 / 授权样本** 上按 IL2CPP 类名 hook（实验室） | 手动（npm；**不是** manifest） |
| **Cheat Engine** | 见下节 | 手动 |
| **apktool / jadx** | 游戏 APK 先解包 | **是** → [`apk-reverse/`](../../apk-reverse/SKILL.md) |

**MUST NOT** 在本文件重复 IDA/Ghidra/Frida 操作手册；跟 PRIMARY skill。

## Cheat Engine

`case-init` 就绪后用于内存映射与结构观察。对照 dump 字段名，偏移写成 Observation。AC 在场时对照 [anti-cheat-families.md](anti-cheat-families.md) 与 [ags/anti-cheat.md](ags/anti-cheat.md)。

## 实验室 IL2CPP hook

`frida-il2cpp-bridge`：按类/方法名 hook。完整命令见 [il2cpp-dump.md](il2cpp-dump.md)。seed-014 是踩坑笔记。

## 缺工具时

```text
1. skills/tool-index.md — 真实路径 / 可用列
2. 未生成 → refresh-tool-index.ps1|.sh
3. 仅当能力在 bootstrap-manifest.json 时才 bootstrap-reverse.ps1
4. Il2CppDumper / Inspector / Cpp2IL / UE4SS / Dumper-7 / AssetStudio / CE / DIE / frida-il2cpp-bridge
   → 手动安装后重新 refresh；禁止猜 %USERPROFILE%\Tools\...
```

Frida 本体可自举；**bridge 与 Il2CppDumper 仍手动**。

## 上游链接堆

其余 AGS 条目 **MUST** 指向上游，不在本包展开：

https://github.com/gmh5225/awesome-game-security/blob/main/README.md

README 条目 / wiki / archive 是 **发现层**，不是 L1 证明（`ops/evidence-finding-path.md`）。引擎交接 [engines.md](engines.md)；AC 家族 [anti-cheat-families.md](anti-cheat-families.md)。
