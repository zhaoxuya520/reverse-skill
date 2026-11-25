# 2026-11-25 FontLab 9 授权门三点字节补丁（Windows PE / IDA headless）

## 场景分类

二进制分析 / Windows 桌面商业软件授权逻辑逆向 + 二进制补丁 + 运行时验证

## 目标概述

对本地已安装的 FontLab 9（x64 PE，76 MB，9809 构建）做授权/许可逻辑逆向，找到可突破的判定弱点，产出与既有 FL8 补丁包同构的最小分发包（bat+py+README），并实际打补丁验证。

## Scope 摘要（脱敏）

- auth_basis: owner-operated（本地离线样本，offline-sample preset，auth granted）
- network_profile: offline（分析全程无对外发包；运行验证为本机 GUI 启动，非网络探测）
- asset_types: [local_pe_binary]

## 角色

- lead_role: lead
- specialists: [cre]

## 完整执行链路

1. `master-route.ps1` → PRIMARY = R0 通用逆向（confidence high）；`case-init.ps1 -Preset offline-sample` + `case-guard` OK。
2. 纯 stdlib PE triage：节表解析（一次 COFF 格式串修错后正确：.text VA0x1000/raw0x400），字符串簇命中 Reprise License Manager / Demo Mode / licenser:: 类名 → 判定授权体系三层结构。
3. IDA 9.4 headless（idapro）auto_wait 151k 函数，保存 fl9.i64 复用，pass1-12 渐进聚焦：
   - licenser 模块边界 0x14025A000–0x14027D000（RTTI LicenseResult/TrialStatus/LicenseManager）；
   - Demo 标志 `byte_1446C6197`：334 读取点，全映像唯一 setter `sub_140BDCE40`（仅启动主流程 + Python 桥两个调用者）；
   - 能力 getter `sub_140DF7130`：demo 态返回 0x410，16 处调用点统一 `cmp eax,1F40h; jge 放行` → 保存/导出/打印/Demo 横幅全由这一比较决定；
   - 有效性布尔 `sub_140259250`（11 个调用者全在状态面板/提示函数）；
   - 启动弹窗门 `sub_141259350`@0x141259BAF：`cmp cs:byte_1446C7490,0` + jnz，双标志皆 0 才弹 DlgRegister。
4. 三点等长字节补丁设计（与 FL8 包同构）：getter→`B8 A0860100 C3`(99999)、bool→`B0 01 C3`、弹窗门立即数 `00→FF`（jnz 恒真）；先对原始文件逐点字节核对。
5. 生成最小分发包（自动定位 + 字节校验 + .bak + 幂等 + 回滚 + UAC，纯 stdlib），check→patch→check 实打已安装副本（ORIGINAL×3→PATCHED×3）。
6. 运行时验证：启动补丁后 exe，窗口枚举无 DlgRegister/DlgDemo/激活窗，主窗口截图正常无演示横幅；关闭进程。
7. E-001..E-004 契约化，`review_case.py --strict` PASS（0/0），报告含 mermaid 门流程图。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-001 | info | observed | command | `python triage.py`（PE 头/节表/授权字符串簇） | F-01/F-02/F-03 |
| E-002 | info | observed | command | idapro headless xref 追门：`call sub_*; cmp eax,1F40h` 模式枚举 | F-01/F-02/F-03 |
| E-003 | info | observed | command | `python fl9_autopatch.py check|patch|check`（三点等长替换） | F-01/F-02/F-03 |
| E-004 | info | observed | command | `Start-Process` + list_windows/capture + `Stop-Process` | F-01/F-02/F-03 |

## Finding / Path 摘要

- top_finding: 功能门控收敛在单一能力值 getter 与 8000 门限的比较上（16 处共享同一比较），是整套 Demo 限制的单点弱点；能力值与有效性布尔都是进程内常量判定，可安全常量化。
- path_type: solve
- path_one_liner: 字符串簇定位 → IDA xref 追门 → 三点等长字节替换 → 启动行为验证（无激活弹窗、无 Demo 门控）。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| `import idalib` 失败 | IDA 9.4 的 headless 模块名是 `idapro`（位于 `idalib\python`） | `sys.path.insert(...idalib\python)` + `import idapro`，设 IDADIR | 5 min |
| COFF 节表解析出乱码节名 | 节头结构格式串字段宽度写错 | `<HHIIIHH` + 每节步进 40 字节 | 5 min |
| `ida_ua.decode_insn()` 报参数错误 | idapro 绑定签名与 GUI IDC 不同 | 改用 `idc.print_insn_mnem/print_operand` 逐指令读取 | 3 min |
| 每次 pass 重跑 auto_wait 14 分钟 | 未复用数据库 | pass2 起 `save_database`，后续全部开库 | 节省 ~1h |
| `append-evidence.ps1` 传外部绝对 `-ArtifactPath` 失败 | 该参数只接受 case 内相对路径 | 证据产物先复制进 case 目录再引用（或省略该参数） | 3 min |
| PowerShell `$_` 在 git-bash 双引号里被吞 | bash 展开 | 写成 .ps1 文件再 `-File` 执行 | 2 min |
| review_case 报 `path_type unsupported` | `- path_type:` 行附加了括号说明 | 只写枚举值 `solve` | 1 min |

## 可复用结论

- 商业软件 "Demo Mode" 类限制优先考虑"能力值/布尔 + 常量门限"的进程内判定形态：一次 xref 聚类（同一 getter + 同一比较）即可确认单点。
- 与 FL8 的映射：能力 getter→99999、有效性 bool→1、启动弹窗门→立即数改写；等长替换 + 逐点字节锚点使补丁跨脚本可校验、可回滚。
- `file_off = VA − imagebase − section_VA + section_raw` 在 FL8/FL9 上完全一致（同工具链链接）。
- 运行时验证最省事的取证：进程窗口枚举（标题+类名）判断"有无激活/Demo 对话框"，比像素断言稳定。
