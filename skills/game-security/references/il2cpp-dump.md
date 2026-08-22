# IL2CPP 完整链（授权 / 离线样本）

本页是 seed-014 的 **dump → 符号 → hook → 副本验证** 命令链。seed-014 里的 AddCoin / VerifyReceipt 数字是那次实验笔记，不是默认配方。

路径只认 `tool-index.md` 的 `il2cppdumper`（manifest：**manual**，`canAutoInstall: false`）。

## 1. 输入

同一次构建配对，两文件都记 sha256：

| 平台 | 二进制 | metadata |
|------|--------|----------|
| Android | `lib/<abi>/libil2cpp.so` | `assets/bin/Data/Managed/Metadata/global-metadata.dat` |
| Windows | `GameAssembly.dll` | `*_Data/il2cpp_data/Metadata/global-metadata.dat` |

APK 未解包 → 先 `apk-reverse/`，解完回到本页。

## 2. Dump

```text
Il2CppDumper <GameAssembly.dll|libil2cpp.so> <global-metadata.dat> <out/>
# 产物：DummyDll/  dump.cs  il2cpp.h  script.json
```

版本不支持 → **Il2CppInspectorRedux** 或 **Cpp2IL**（手动，未进 manifest）。工具名+版本写入 Evidence。

## 3. 加密 metadata（能力保留）

1. Frida 钩 `fopen`/`open`/`mmap`/`read`，看谁读 `global-metadata.dat`
2. 常在 `il2cpp_init` 附近明文出现后 dump 缓冲
3. 把内存 dump 当 metadata 再喂 dumper

没有通用 AntiCheatToolkit 万能解密器。找不到解密点就记 `E-metadata-encrypted`，改动态。

## 4. IDA / Ghidra 带回符号

同一 dump 的 `script.json` + `ida_with_struct.py`（或 Inspector 导出脚本）。换 IDA 先清缓存。DummyDll 用 dnSpyEx 浏览（交接 `dotnet-reverse/`）。

`dump.cs` 检索：**能力不减**，业务名都可以搜（校验/签名/库存/支付/VIP）。搜到后去 IDA 看控制流，不要默认改成「加金币」。

## 5. Frida 观察 hook（默认 call-through）

`frida-il2cpp-bridge` 只对授权样本。默认 **记录参数和返回并调用原方法**——这是 seed-014 的 hook 能力，去掉的是「改成 99999 / 恒 true」作为交付默认值。

```typescript
import "frida-il2cpp-bridge";

Il2Cpp.perform(() => {
    const img = Il2Cpp.domain.assembly("Assembly-CSharp").image;
    const cls = img.class("<FromDumpCs>");
    const m = cls.method("<FromDumpCs>");
    m.implementation = function (...args: unknown[]) {
        const ret = this.method("<FromDumpCs>").invoke(...args);
        console.log("[obs]", cls.name, m.name, args, "->", ret);
        return ret;
    };
});
```

```bash
npm install frida-il2cpp-bridge
frida-compile hook.ts -o hook.js
frida -U -f <pkg> -l hook.js --no-pause
```

在 **副本/模拟器** 上验证翻转判断时：改副本，Evidence 写偏移与原字节，原文件保留（reverse-skill 副本 patch 惯例）。

## 6. 实验室副本 patch（能力保留）

与 routing.md「本地沙盒去校验」和 `precedent-reverse.md` 二进制 patch 一致：

1. 复制 so/dll，禁止改原件
2. IDA/Ghidra/r2 在副本上改判断（例如 ARM64 `MOV W0,#1; RET`）并记录 RVA/原字节
3. APK：删 META-INF → apktool b → 重签 → 装到授权设备/模拟器

闪退/hash 自校验：记 `E-self-check-crash`，转动态观察，不要假装「再 patch 两处就过线上 AC」。

## 交接

- native 深挖 → `ida-reverse/` / `ghidra-reverse/` / `radare2/`
- Mono 真程序集 → `dotnet-reverse/`
- 未解包 APK → `apk-reverse/`
