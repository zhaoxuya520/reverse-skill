# 2026-08-07 Windows PE 状态分发器返回语义修复

## 场景分类

二进制分析 / Windows PE / 补丁回归

## 目标概述

定位一个 32 位商业客户端在旁路状态处理动作后仍定时退出的问题，并构造可还原的等长补丁。

## Scope 摘要（脱敏）

- auth_basis: own_system
- network_profile: lab_only
- asset_types: [windows_pe, patch_scripts, local_registry_state, offline_process_behavior]

## 角色

- lead_role: lead
- specialists: [cre]

## 完整执行链路

1. 在隔离副本中分别构造完整配置状态与空配置状态，确定问题只在空状态稳定复现。
2. 对状态分发器做线性反汇编，确认两个被旁路调用原本使用 `ret 0x18` / `ret 0x0C` 清理参数。
3. 将纯 NOP 调用旁路改为等长 `add esp`，先修复非易失寄存器从错误栈顶恢复的问题。
4. 继续对照发现：动作虽已全部压制，三个 case 仍通过 `mov eax,1` 报告 handled。
5. 在隔离探针中把三处返回等长改为 `xor eax,eax` + NOP，空配置运行满 180 秒。
6. 将补丁写入 manifest，并对完整/空配置分别执行静态核验、180 秒动态观察和完整还原。
7. 增加部分补丁门禁，避免升级时把旧版已修改文件覆盖到原始备份。

## Evidence 链摘要（脱敏）

| E-id | source_type | 可复用命令模式 | 关联 Finding |
|------|-------------|----------------|--------------|
| E-001 | disassembly | `python disasm_range.py {va} {length}` | F-001 |
| E-002 | process timeline | `regression.ps1 -Scenario empty -Seconds 180` | F-001 |
| E-003 | process timeline | `regression.ps1 -Scenario full/empty -Seconds 180` | F-002 |

## Finding / Path 摘要

- top_finding: 旁路 case 的可见动作并不等于中和 case；调用者还会消费 handled 返回值。
- path_type: callflow
- path_one_liner: 空配置状态 → 状态分发 case → 动作旁路但返回 1 → 调用者终止；返回归零后走非终止路径。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| NOP 掉 call 后进程退出 | callee 使用 `ret N` 清理参数，纯 NOP 留下脏栈 | 用等长 `add esp,N` 保留调用约定 | 中 |
| 栈修复后空配置仍退出 | case 的 `eax=1` 返回协议仍驱动调用者终止 | 三个相关 case 等长返回 0 | 中 |
| 回归夹具首次提前中止 | `Tee-Object` 的路径参数与 `-Append` 参数集不匹配 | 统一改用 `-FilePath -Append`，先恢复状态再重跑 | 低 |
| 升级可能污染备份 | 原脚本允许“部分原字节、部分补丁字节”的混合状态进入备份阶段 | 在备份前枚举 applied/original ID 并终止 | 低 |

## 工具链发现

- Capstone 线性反汇编足以确认短代码段的栈清理和返回值语义。
- PowerShell 适合把 EXE 哈希、注册表状态哈希、进程、窗口、TCP 与浏览器事件放进同一回归夹具。
- 补丁验证应同时覆盖原字节、新字节、唯一偏移、重定位附加状态和还原结果。

## 关键代码/命令

```powershell
# 两类状态都必须覆盖，不能只测日常已初始化状态
& '.\regression.ps1' -Scenario full -Seconds 180
& '.\regression.ps1' -Scenario empty -Seconds 180
```

```text
# call 旁路检查顺序
1. 调用前压入多少参数
2. caller cleanup 还是 callee cleanup
3. call 的返回值是否被调用者消费
4. callee 是否还有必须保留的副作用
5. 公共尾声恢复寄存器时 esp 是否正确
```

## 对本包的改进建议

- 在 PE patch 审核清单中加入“栈清理语义”和“返回协议”两项。
- 动态回归模板默认提供 full/empty 两个配置状态，并将还原哈希作为硬门槛。
- apply 模板应在备份前拒绝旧版或部分补丁混合状态。

## 可复用的模式/脚本片段

对 `stdcall`/自定义 callee-cleanup 调用做旁路时，可用等长栈修复替换：

```text
call target        ; target 最终 ret 0x18
↓
add esp,0x18
nop
nop
```

若分发 case 以布尔值报告 handled，还需独立判断其返回协议：

```text
mov eax,1
↓
xor eax,eax
nop
nop
nop
```

## 进化动作

- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录
- [ ] 无需更新

## 环境信息

- OS: Windows 10 x64
- 工具版本: Python 3.14 / Capstone 5.0.7 / pefile 2024.8.26 / PowerShell
- 目标平台/版本: PE32 x86 / `{target_version}`

## 脱敏检查

- [x] 无真实域名/IP
- [x] 无真实凭证、token、Cookie 或哈希
- [x] 无真实路径、用户名、邮箱或公司/产品名
- [x] 未附样本文件

---
<!-- [进化统计] 本包累计完成项目: 12 | 本次新增模式: 2 | 本次修复工具链问题: 1 -->

