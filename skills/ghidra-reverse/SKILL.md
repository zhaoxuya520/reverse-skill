---
name: ghidra-reverse
maturity: extended
description: Use for free/open reverse engineering with Ghidra (headless or GUI), including decompile, cross-refs, and optional Ghidra MCP workflows when IDA is unavailable.
---

> **Maturity: `extended`** · usable playbook · see [`../references/skill-maturity.md`](../references/skill-maturity.md). Expect more manual tool work than **core** skills.

# Ghidra Reverse Engineering

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-reverse.md`
2. `NOW`: 确认需要 **Ghidra**（无 IDA / 偏好开源 / 批量 headless）
3. `NEXT`: 读 `../tool-index.md` 查 ghidra / ghidra-mcp 路径
4. `NEXT`: 缺工具 → bootstrap `ghidra-mcp`（若 manifest 支持）或按手动步骤装 Ghidra
5. `ACT`: 导入样本 → 自动分析 → 导出关键函数反编译

## 适用场景

- 无 IDA 许可证时的主逆向入口
- 批量 headless 分析 / CI 中反编译
- Ghidra 脚本（Java/Python Jython/PyGhidra）自动化
- 与 `binary-diff` / `patch-diff-exploit` 的 ghidriff 联动

## 与 IDA 分工

| 需求 | 优先 |
|------|------|
| 已有 IDA MCP 深挖 | `ida-reverse/` |
| 开源 / 批量 / 教学 | **本 skill** |
| 仅 CLI 快速侦察 | `radare2/` |

## 工作流

### 1. 项目与自动分析

```text
□ 新建 Project → Import 文件 → Analyze（默认分析器）
□ 记录语言/编译器识别结果与基址
□ 标记入口、导出表、字符串 xref
```

### 2. 关键函数

```text
□ 从字符串 / 导入 API 反查
□ Decompile 窗口还原算法
□ 重命名函数/变量；写 Plate comment
□ 需要动态时交接 Frida/GDB（reverse-engineering 动态章）
```

### 3. Headless（批量）

```bash
# 示例：analyzeHeadless 路径因安装而异，MUST 从 tool-index 取
analyzeHeadless /path/to/project Proj -import sample.bin -postScript ExportDecomp.py
```

### 4. MCP（若已配置）

```text
□ 确认 ghidra MCP 端口（常见 8765，以 tool-index 为准）
□ 用 MCP 工具拉反编译 / xrefs，禁止猜端口
```

## 工具链

| 工具 | 用途 | 自举 |
|------|------|------|
| Ghidra | 反编译主工具 | 手动 release / 包管理器 |
| ghidra-mcp | AI 桥 | bootstrap 能力名 `ghidra-mcp` |
| ghidriff | 补丁差分 | 见 `patch-diff-exploit` |

## 参考

- `references/ghidra-cheatsheet.md`
- `../ida-reverse/` `../radare2/` `../binary-diff/`

## 路由上下文

**上游**: MASTER R22  
**下游**: 动态验证 → Frida/GDB；利用 → `pwn-chain`  
**同级**: `ida-reverse`（商业深挖）

## 任务完成自检

- [ ] 是否基于真实 Ghidra/tool-index 路径？
- [ ] 是否标注函数地址与重命名？
- [ ] 是否有可复现步骤？
- [ ] Checklist / journal？