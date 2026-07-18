# RE Agent 工作流门闩（静态↔动态）

> 来源启发：binary-re 阶段划分、社区 RE skill（Frida/r2/Ghidra/IDA 循环）、Cerberus 三头环（静/动/插桩）  
> 日期：2026-07-17  
> 适用：`reverse-engineering/`、`ida-reverse/`、`radare2/`、与 cre 角色交接

## 0. 启动

```text
□ scope.md：offline 样本路径 或 授权设备/靶机
□ tool-index：file/strings/r2/ida/frida 等实际路径
□ 角色：cre（ops/role-map）
```

## 1. Triage（5–15 分钟）

```text
□ file / DIE / 熵 / 壳特征
□ strings / rabin2 -z 捡漏
□ 架构/链接/是否 .NET/Go/Rust/加壳
□ 产出：E-triage + 假设清单（勿过早下结论）
```

## 2. Static

| 工具 | 何时 |
|------|------|
| radare2 / rabin2 | 快速函数/导入/字符串 |
| IDA / Ghidra（MCP 或 headless） | 深挖、交叉引用、类型 |
| jadx / dnSpy | Android / .NET |
| OLLVM 文档 | 控制流平坦化怀疑 |

```text
□ 定位关键函数（加密/校验/网络/授权）
□ 记录地址/符号 → Evidence
□ 一条路不通 → 换工具（IDA↔r2↔Ghidra）
```

**无 MCP 时**：可用导出反编译文本再分析（对照 P4nda0s reverse-skills / IDA-NO-MCP 思路），仍写 Evidence 路径。

## 3. Dynamic

```text
□ Frida / gdb / emulator：验证静态假设
□ 反调试/反 Frida → reverse-engineering/anti-analysis
□ Android：root 检测 / SSL pinning 绕过脚本按需生成，**须在授权设备**
□ 崩溃日志驱动下一轮 hook（自适应循环）
```

## 4. Synthesis

```text
□ Finding：算法/校验逻辑/可利用点
□ Path：callflow 或 solve 步骤挂 E-*
□ 报告 docs-generator + 可选图
□ field-journal 脱敏
```

## 5. 与「堆 RE skill 插件」的差异

- 本包用 **阶段门闩 + tool-index**，不默认启用 Hex-Rays「unsafe 全自动执行」类插件  
- 动态插桩默认 **offline/lab** network_profile  
