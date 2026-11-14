# 2026-10-16 Go+Wails 用量看板桌面程序全逻辑还原（stripped 无符号）

## 场景分类
二进制分析 / Go stripped PE 符号恢复 + 逻辑还原（Wails v2 桌面应用）

## 目标概述
对自有 Windows 桌面「AI 编码助手用量看板」（`{target_app}`，Go + Wails v2，单 exe ~15MB）做**纯静态黑盒**还原：
不阅读同项目源码，仅凭二进制恢复全部函数符号，并还原数据采集（3 类数据源）、SQLite 存储、成本计算、报表与前端接口面。

## Scope 摘要（脱敏）
- auth_basis: 用户自有程序，明确授权静态分析（read-only，不运行样本）
- network_profile: offline（纯本地静态分析，全程无外联）
- asset_types: [pe_go_stripped, wails_v2_desktop, sqlite_schema]

## 角色
- lead_role: lead
- specialists: []

## 完整执行链路

1. 基线取证：sha256 / PE 结构 / BuildInfo / 全量字符串（4.1 万条）→ 确认 Go 1.24.4、`-trimpath -s -w`、Wails v2.11.0、CGO_ENABLED=1
2. 符号恢复第一步：GoReSym v1.7.1 → **`failed to locate pclntab`**（新版本 Go 布局不兼容）→ 弃用，转自研
3. 手工 pclntab 解析：扫 `.gopclntab` magic `0xFFFFFFF1` 定位 pcHeader（file_off=10,155,296），读 nfunc=15,684 / nfiles=1,062 / 各子表偏移
4. functab 定位：pclntab+72 处为零填充（预期失败），改用「枚举候选偏移 + entryoff/funcoff 结构校验」暴力定位（file_off=12,921,688），全量导出 `va/entryoff/name`
5. 反汇编归并：capstone x86-64 逐函数反汇编，`call rel32` 目标回查 functab 表得函数名（含 `+offset` 内联标注）；字符串三种解析策略：`[E]` LEA+长度立即数精确配对、`[V]` 描述符 (ptr,len)、`[R]` 可打印窗口兜底 → 208 个项目函数伪码 2,418 行
6. 逻辑重建：按调用图+字符串把 208 函数归入 9 个模块（启动生命周期/config/store/report/claude/cursor/pricing/netx/前端接口），运行时行为用「时间常量 + 字符串常量 + 调用链」三角验证（如 5h=18e12 ns 块、20s 超时、1.5s 重试）
7. 关键链路字节级复查：写 `probe_func.py` 单函数探针（头部常量/错误文案/长度全部锁定），例如 `User-Agent: token-meter/1.0`（len=15 由 `mov [rax+8],0xf` 确认）
8. 数据模型：从 `CREATE TABLE` 字符串提取 5 张业务表 DDL（entries/raw_lines/sessions/files/kv）+ 索引；确认 incremental 扫描（files.offset 位点）、幂等 upsert、WAL pragma
9. 交付：mermaid 架构图 + 30+ 关键函数伪码（VA/行号可溯源）+ 完整报告；case-review `--strict --verify-hashes` → **0 error / 0 warning PASS**

## Evidence 链摘要（脱敏）
| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-001 | n/a | observed | command | `sha256sum <target>.exe` + BuildInfo 提取 | F-001 |
| E-002 | n/a | validated | script | `python scripts/pclntab_parse.py <exe>`（magic 扫描） | F-002 |
| E-003 | n/a | validated | script | `python scripts/pclntab_find_ftab.py <exe>`（结构校验暴力定位） | F-002 |

## Finding / Path 摘要
- top_finding: GoReSym 失败的新版 stripped Go PE，可用「magic 扫描 + functab 结构校验暴力定位 + capstone call-rel32 回查」完整恢复函数名；配合字符串精确长度配对（LEA+mov len）可把头部常量/错误文案还原到字节级
- path_type: solve
- path_one_liner: magic 定位 pclntab → 暴力定位 functab → 全量反汇编+字符串归并 → 按调用图归模块 → 单函数探针字节级验证 → 架构图/伪码/报告交付

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| GoReSym `failed to locate pclntab` | 工具对新版 Go（1.24.x）布局兼容性不足 | 自研 Python 解析器（magic 0xFFFFFFF1 扫描 + 头部字段解析） | 1h |
| functab 不在 pclntab+72 | 该区域零填充，头部后布局与假设不同 | 枚举候选偏移 + 「entryoff 单调 + funcoff 可解析出已知函数名」双校验暴力定位 | 0.5h |
| 临时脚本用平坦 `va-0x400000+0x1c00` 映射取字符串全乱码 | 只对 .text 成立，跨 section（.rdata/.data）失效 | 统一走 pefile section 映射（va_to_off） | 0.3h |
| `probe_func.py` 把 FetchLimits 截断成 0x400 字节 | 假设 jsonl 有 off/size 字段（实际只有 va/entry_off/name） | 用排序 VA 二分求下一个函数入口，差值当函数尺寸 | 0.3h |
| Bash 管道输出含 CJK 被标记 `[Binary output]` | 终端编码（GBK）问题 | 一律写文件 + Read 工具读取，不直接 pipe | 0.2h |
| 9 条证据记录误写进同一个 E-001.md | 未按「一记录一文件 + 标题与文件名一致」契约 | 拆分为 E-001..E-009 独立文件（review_case 契约已在模板中强调，仍需注意） | 0.3h |
| 字符串提取大量混入标准库噪声 | Go 把所有常量集中存放 | 只保留「函数邻近窗口 + 长度精确匹配」的 [E] 类字符串做结论 | 0.5h |

## 工具链发现
- **GoReSym v1.7.1**：对 Go 1.24.4 + `-trimpath -s -w` 样本定位 pclntab 失败 → 该场景需走手工解析
- **capstone**（Python）：x86-64 反汇编稳定；`call rel32` → 目标 VA 回查函数表即可命名调用（含内联偏移）
- **pefile**：section 映射（VA→file offset）是字符串/数据解析的前提
- 自研三件套可复用：pclntab 解析 / functab 暴力定位 / 函数级反汇编+字符串归并（见下方脚本模式）

## 关键代码/命令

```
# 1) pclntab 定位：扫 magic 0xFFFFFFF1（小端字节 F1 FF FF FF）
#    解析 pcHeader: magic, pad, minLC, ptrSize, nfunc, nfiles, textStart, funcnameOff, cuOff, filetabOff, pctabOff, pclnOff
python scripts/pclntab_parse.py <target>.exe

# 2) functab 暴力定位：候选偏移处读 {entryoff u32, funcoff u32} 数组
#    校验：entryoff 严格递增；funcoff 指向 funcnameOff 区且 funcnameOff 能解出 "runtime." 前缀
python scripts/pclntab_find_ftab.py <target>.exe

# 3) 全量反汇编 + 字符串归并（[E] LEA+len 精确配对 / [V] 描述符 / [R] 原始窗口）
python scripts/disasm_funcs.py <target>.exe evidence/funcs_all.jsonl evidence/pseudocode_raw2.txt

# 4) 单函数字节级探针（头部常量 / 错误文案 / 立即数长度）
python scripts/probe_func.py <target>.exe evidence/funcs_all.jsonl "<pkg>.<Func>" out.txt

# 5) 一致性复核（证据/工作项/时间线/报告四表互链）
python skills/case-review/scripts/review_case.py work/<case> --verify-hashes --strict
```

## 对本包的改进建议
- `seed-002_go-malware-stripped` 可补充「GoReSym 失败后的手工 pclntab/functab 恢复」分支，含 functab 结构校验暴力定位思路
- tool-index 里 GoReSym 建议标注已知版本限制（1.7.1 对 Go ≥1.24 部分样本 `failed to locate pclntab`）
- 可新增可复用脚本条目：`pclntab_parse.py` / `pclntab_find_ftab.py` / `disasm_funcs.py`（本 case 已实证）
- 证据记录「一文件一记录、标题=文件名」这条契约很好用，但容易踩（模板已有提示，可考虑在 case-review 报错文案里直接给出修复示例）

## 可复用的模式/脚本片段
- **stripped Go PE 全符号恢复三步法**：magic 扫描 →（+72 失败则）functab 结构校验暴力定位 → call rel32 回查命名
- **字符串字节级还原**：Go 字符串常量的 LEA 指令后紧随 `MOV reg, len` 立即数 → (指针,长度) 精确配对；比裸窗口扫描可信度高一个量级
- **运行时常量三角验证**：`time` 常量（ns bignum）+ 字符串常量 + 调用图三者交叉，无动态运行也可高置信还原行为参数（超时/重试/块长）
- **Windows 凭据链识别**：`Local State → os_crypt.encrypted_key → base64 → DPAPI → AES-GCM("v10")` 是 Chromium 系应用的通用指纹；`CryptUnprotectData` 导入即可预判

## 进化动作
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录（本文件踩坑表）
- [ ] 无需更新

## 环境信息
- OS: Windows 10.0.26300 (x64, Git Bash)
- 工具版本: GoReSym v1.7.1（弃用）、capstone(pip)、pefile、Python3
- 目标平台/版本: PE32+ x86-64，Go 1.24.4，Wails v2.11.0，strip+trimpath

## 脱敏要求
已按 anonymization.md 处理：无真实用户名路径、无 token/凭据值、无私有域名；目标以 `{target_app}` 指代。

---
<!-- [进化统计] 本包累计完成项目: 22 | 本次新增模式: 4 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
