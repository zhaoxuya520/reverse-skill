---
name: tool-index-dual-desync-and-scripting-traps
description: 工具索引 .md/.json 双份必须同步；PowerShell 5.1 给不存在属性赋值会整条回滚；换行符三连坑
metadata:
  type: project
---

# 工具索引双份不同步 + 脚本化维护的四个坑

**日期**: 2026-10-16
**场景分类**: 其他（工具链维护 / 索引一致性）
**目标**: 本地逆向技能包的工具索引

## 背景

把「不在 PATH 里的本地工具」（装在独立 venv 或专用目录）登记进工具索引时，
写了个幂等脚本只改人类可读的那份 `.md`。事后核查发现：**机器可读的 `.json` 没同步**。

## 缺陷 1：`.md` 与 `.json` 双份索引不同步（会误导读 json 的客户端）

| 工具 | `tool-index.md` | `tool-index.json` |
|---|---|---|
| 本地 JDK | `yes` | `available: false` |
| 独立 venv 里的动态分析工具 | `yes` | `available: false` |

**为什么危险**：部分 Agent 会优先读**机器可读**的那份 ⇒ 判断「工具没装」⇒ 明明装好的能力被跳过。
**修法**：改索引的脚本必须**同时更新两份**，并在末尾做一次一致性核对（逐工具比对 md 的 `yes/no`
与 json 的 `available`）。

## 缺陷 2：PowerShell 5.1 给 PSCustomObject **不存在的属性**赋值 → 整条 try 回滚

`ConvertFrom-Json` 产生的对象，若给它赋一个不存在的属性，PS 5.1 **直接抛错**
（`在此对象上找不到属性…`），而且是在 `try` 里 ⇒ **整个同步回滚**。

**极具误导性的表现**：同一批工具里，A、B 同步成功，C 失败。原因是 **C 同时在 `tools` 和
`capabilities` 两个数组里**，而 `capabilities` 用的字段名不同（`tool_available` / `ready`，
不是 `available`）⇒ 赋值时炸掉。

**修法**：赋值前先探测属性存在性（PS 5.1 安全写法）：

```powershell
foreach ($c in $o.capabilities) {
  if ($c.name -ne $Name) { continue }
  if ($c.PSObject.Properties['tool_available']) { $c.tool_available = $true }
  if ($c.PSObject.Properties['ready'])          { $c.ready = $true }
}
```

## 缺陷 3：换行符三连坑（同一份 patch 反复被搞坏）

| # | 场景 | 症状 | 修法 |
|---|------|------|------|
| 1 | 用 Python **text mode** 读改写文件 | `git diff` 变成 **58 KB** 巨型补丁（整个文件都算改动） | **二进制读写**（`open(p,'rb')` / `open(p,'wb')`），不做换行转换 |
| 2 | 用文件写入工具新建的源码文件是 **CRLF**，而项目全是 LF | 与项目其余文件不一致 | 写后校验并转 LF |
| 3 | 全局 `core.autocrlf=true`，`git apply` 把目标文件转成 CRLF | 补丁应用后整个文件换行符被改 | `git -c core.autocrlf=false apply <patch>`，或干脆**手工改** |

**判据**：`git diff --stat` 显示的行数与你的实际改动量严重不符（如只改 5 行却报 550 行）
⇒ 立刻怀疑换行符 / BOM，别怀疑 diff 工具。

## 缺陷 4：`find -size -1k` 的语义陷阱（统计假阳性）

用 `find ... -size -1k` 统计「小于 1KB 的文件」得到的结果**只匹配 0 字节文件** —— 因为
`-size` 按**块**计算且**向上取整**，146 B 的文件算 1 块，不满足 `< 1`。

**修法**：用字节单位 `-size -1024c`。
（本例中该错误让我一度得出「文档普遍很薄」的错误结论，实际是「总体有料、个别模块薄」。）

## 可复用的模式

**索引/清单类产物，只要有多种格式，就必须有一个「一致性核对」步骤** ——
且核对必须**逐项比对**，不能只看"两份文件都存在"。

**改文件的脚本，读写都走二进制**，把换行符当作**需要显式保持的数据**，而不是运行时细节。

## 对本包的改进建议

- 若 `tool-index` 要同时供人和机器读，建议**只保留一份作为单一事实源**（如 json），
  另一份由脚本生成 —— 双写必然漂移。
- `refresh-tool-index` 建议支持「额外搜索路径」参数（如 `%USERPROFILE%\Tools\**`），
  这样装在专用目录 / venv 里的工具不必依赖手工桥接。

## 进化动作

- [x] 更新了 tool-index（两份已一致）
- [x] 新增了 pitfalls 记录
- [ ] 更新了路由矩阵
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档

## 环境信息

- OS: Windows 10.0.22631
- 工具版本: PowerShell 5.1 / Node 26 / Git 2.45
- 目标平台/版本: 本地工具索引（md + json 双份）

---

<!-- [进化统计] 本次新增模式: 4（双索引漂移 / PS 赋值 / 换行符 / find 语义） | 本次修复工具链问题: 4 -->
