# [种子] Unity IL2CPP 游戏逆向 → 还原元数据 + 修改逻辑

> PRIMARY：`game-security/`（**R43**）。下文 AddCoin / VerifyReceipt / 改金币示例是历史实验室笔记，**MUST NOT** 当外挂交付物。路由号 **R42** 预留 threat-intel，不要改回去。

## 场景分类
游戏安全 / 移动逆向

## 目标概述
一个 Unity 打包的 Android 游戏（IL2CPP 模式），游戏内购或核心算法在 C# 编写但已编译成 native。需要还原方法名、定位关键逻辑、改动 / hook 实现修改。

## 完整执行链路

1. 拆包 APK，确认是 IL2CPP
   ```bash
   unzip target.apk -d apk
   ls apk/lib/arm64-v8a/        # 看到 libil2cpp.so 即 IL2CPP
   ls apk/assets/bin/Data/Managed/Metadata/
   # 关键文件: global-metadata.dat
   ```
2. 用 **Il2CppDumper** 还原元数据
   ```bash
   Il2CppDumper libil2cpp.so global-metadata.dat output/
   # 产物：DummyDll/ + script.json + il2cpp.h + dump.cs
   ```
3. 把 IDA 的 IL2CPP 脚本（`ida_with_struct.py`）跑一遍
   - 加载 libil2cpp.so → File → Script File → 选 ida_with_struct.py → 选 script.json
   - IDA 现在能看到 C# 方法名、签名、字符串
4. 在 dump.cs 里按业务关键字搜（`AddCoin` / `OnPurchase` / `Verify` / `IsVip` / `CheckSign`）
5. 拿到关键方法的偏移 → IDA 跳过去看反汇编 / 反编译
6. 选择修改方式：
   - **静态 patch**：直接 IDA 把判断改成 `mov w0, #1; ret`
   - **动态 hook**：Frida 接 il2cpp 方法（用 Frida-Il2CppBridge）
7. 重打包验证 / 注入验证

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| Il2CppDumper 报 metadata 版本不支持 | 新版 Unity 改了 metadata 格式 | 升级 Il2CppDumper 到最新 / 用 Il2CppInspectorRedux 替代 | 30min |
| global-metadata.dat 加密了 | 用了 AntiCheatToolkit / 自定义加密 | 找游戏初始化时的解密函数（通常在 il2cpp_init 周围）→ Frida 在 mmap 后 dump | 2h |
| dump.cs 看到方法名但 IDA 没匹配 | script.json 与 so 不一致 | 必须用同一次 dump 的产物；换 IDA 时清缓存 | 20min |
| Frida hook IL2CPP 方法报错 | IL2CPP 方法不是标准 Java/ObjC，要算 method offset | 用 frida-il2cpp-bridge 库，不要硬写 Interceptor.attach | 1h |
| Patch 后游戏闪退 | 校验文件 hash 或 anti-tamper | 找 hash 校验逻辑也 patch 掉，或用 hook 不改文件 | 2h |
| 重打包后启动崩溃 | apksigner v2 签名不能改字节后再签 | 删 META-INF + apktool b + apksigner sign 一气 | 30min |

## 工具链发现

- **Il2CppDumper** 老牌但仍是默认选择
- **Il2CppInspectorRedux** 更现代，支持新 Unity，能输出 IDA / Ghidra / Binary Ninja 多种插件脚本
- **frida-il2cpp-bridge** 是 IL2CPP 上 hook 的事实标准，比裸 Frida 强 N 倍
- **DnSpy** / **dnSpyEx** 用于看 DummyDll（dump 出来的伪 .NET assembly）
- **UnityCheat** 系列辅助工具（GameGuardian 系不展开）

## 关键代码/命令

frida-il2cpp-bridge hook 示例：

```typescript
// hook.ts
import "frida-il2cpp-bridge";

Il2Cpp.perform(() => {
    const Assembly = Il2Cpp.domain.assembly("Assembly-CSharp").image;

    // hook static method
    const PlayerData = Assembly.class("PlayerData");
    PlayerData.method("AddCoin").implementation = function (n: number) {
        console.log("[+] AddCoin called with:", n);
        return this.method("AddCoin").invoke(99999); // 改成 99999
    };

    // hook instance method
    const Purchase = Assembly.class("Purchase");
    Purchase.method("VerifyReceipt").implementation = function () {
        console.log("[+] VerifyReceipt → always true");
        return true;
    };
});
```

```bash
# 编译 + 注入
npm install frida-il2cpp-bridge
frida-compile hook.ts -o hook.js
frida -U -f com.target.game -l hook.js --no-pause
```

IDA 静态 patch：

```text
1. 打开 libil2cpp.so，跑 il2cpp_load_metadata.py
2. 跳到 dump.cs 中 IsPurchaseValid 对应的偏移
3. 函数开头改成 MOV W0, #1; RET（ARM64）
4. Apply Patches → Save → 替换回 APK → 重签名
```

## 对本包的改进建议

- PRIMARY 现为 `game-security/`（R43；R42 预留 threat-intel）；本条目仍是 IL2CPP dump 先例
- `MUST NOT` 把下文 AddCoin / VerifyReceipt hook 示例当作外挂交付物
- `reverse-engineering/references/il2cpp-cheatsheet.md` 单独成文：dump 工具对比、frida-bridge 模板、加密 metadata 处理
- bootstrap manifest 增加 frida-il2cpp-bridge

## 可复用的模式/脚本片段

**IL2CPP 标准流程**：

```text
1. 确认 IL2CPP（看 lib/abi 下有无 libil2cpp.so）
2. 找到 metadata（assets/bin/Data/Managed/Metadata/global-metadata.dat 或被加密）
3. Il2CppDumper / Inspector 还原
4. IDA + 脚本带回元信息
5. dump.cs 搜业务关键词
6. 选择 patch 还是 hook
7. 验证（启动 + 实际场景）
```

**加密 metadata 处理**：

```text
1. Frida 在 fopen/open 系调用上挂钩，看谁读 global-metadata.dat
2. 在 mmap/read 后 dump 内存里已解密的元数据
3. 把 dump 出来的内存当 metadata 喂给 Il2CppDumper
```

## 进化动作
- [ ] reverse-engineering/references 增加 il2cpp 完整章节
- [ ] bootstrap-manifest 加入 frida-il2cpp-bridge / Il2CppInspectorRedux
- [x] 路由矩阵已含 Unity / IL2CPP（2026-08：PRIMARY 从 R0 迁到 R43 `game-security/`；R42 预留 threat-intel）

## 环境信息
- Windows / macOS（运行 Il2CppDumper 用），目标设备 Android arm64
- IDA Pro 7.7+ 或 Ghidra 11+
- frida-tools 16.x, frida-il2cpp-bridge 0.9+
- Unity 版本: 2019.x - 2022.x（不同版本 metadata 格式略异）

## 脱敏要求
本条目为种子数据，基于公开技术模式编写，不涉及任何真实游戏。包名 `com.target.game` 为占位符。
