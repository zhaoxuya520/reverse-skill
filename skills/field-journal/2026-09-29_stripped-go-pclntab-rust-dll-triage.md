# 2026-09-29 剥离符号的 Go EXE + rustc 原生 DLL 静态分诊

## 场景分类
二进制分析（Go / Rust 逆向，语言运行时识别 + 符号/元数据恢复）

## 目标概述
对一个剥离符号的 Go 应用 EXE 与其 rustc 编译的原生授权运行时 DLL 做纯静态分诊：
恢复 Go 函数名表、识别原生 DLL 身份与导出、导出关键反编译，不触碰加密程序语义。

## Scope 摘要（脱敏）
- auth_basis: own_system（owner 自有的本地样本）
- network_profile: offline
- asset_types: [pe-exe, pe-dll]

## 角色
- lead_role: lead
- specialists: []

## 完整执行链路

1. 路由：`master-route.ps1 -Hint "... go rust binary ..."` → PRIMARY R33（go-rust-reverse），secondary R22（ghidra-reverse）。
2. case-init（`offline-sample` preset）→ `auth.status=granted`，`network_profile=offline`，`ready_for_act=true`；case-guard OK。
3. 样本哈希与类型确认；`rabin2` 索引路径失效（见踩坑），改用脚本解析 PE。
4. `go version -m <exe>` → 工具链/模块/依赖/build flags/本地 replace 路径（`-trimpath -tags=release` 仍在）。
5. `go tool nm <exe>` → `no symbols`；`go tool buildid <exe>` → 空（确认已剥离）。
6. 字符串扫描恢复 `runtime.pclntab` 中的 Go 函数名（无需 GoReSym）。
7. 字符串扫描原生 DLL → rustc 提交哈希 + 9 个 C ABI 导出。
8. 脚本解析 PE 导出表 → 精确 RVA/VA；Ghidra 12.1.4 headless 自动分析 + 导出反编译。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-002 | info | validated | command | `go version -m <exe>` | F-001 |
| E-003 | info | validated | command | `python3 scripts/extract_strings.py <exe> gofunc` | F-002 |
| E-006 | info | validated | command | `analyzeHeadless ... -postScript ExportDecomp.java` | F-002 |

## Finding / Path 摘要
- top_finding: 剥离符号的 Go EXE 仍通过保留的 `runtime.pclntab` 完整暴露供应商保护面（函数名级），
  与原生 rustc DLL 的清晰 C ABI 导出互补，可在无动态分析下重建授权调用路径。
- path_type: callflow
- path_one_liner: `go version -m` → pclntab 函数名 → 原生 DLL 导出 → Ghidra 反编译导出函数。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| `rabin2`/`r2` 找不到 | `tool-index.md` 路径存在但安装 `bin` 只剩 `r2sdb`，且不在 PATH | 改用脚本 `pe_exports.py` 解析 PE；不猜路径 | 小 |
| Ghidra postScript 报 “class could not be found” | 实际是 `javac` 类型错误：`getExternalEntryPointIterator()` 返回 `AddressIterator` 而非 `SymbolIterator` | 读 headless 日志开头的真实编译错误；改类型 | 小 |
| Ghidra 无系统 java | `JAVA_HOME` 未设置 | 指向 Ghidra 自带 JDK 目录 | 小 |

## 工具链发现
- Go 自带工具链（`go version -m` / `go tool nm` / `go tool buildid`）即可完成 Go 元数据与“是否剥离”判定，GoReSym 非必需。
- GoReSym 类结果（数千函数名）可由 pclntab 字符串扫描复现，适合无 GoReSym 环境。
- Ghidra 12.1.4 headless 在 Windows 上稳定；Java postScript 是可靠批量反编译方式。
- radare2 索引可能滞后，务必确认可执行文件真实存在。

## 关键代码/命令

```
go version -m <exe>
go tool nm <exe>          # 期望 no symbols
go tool buildid <exe>     # 期望空
python extract_strings.py <exe> gofunc
python extract_strings.py <dll> rust
python pe_exports.py <dll>
$env:JAVA_HOME="<ghidra>\jdk-21..."; $env:KOTIK_GHIDRA_OUT="<out>"
analyzeHeadless.bat <projdir> Proj -import <dll> -scriptPath . -postScript ExportDecomp.java -deleteProject
```

## 对本包的改进建议
- `tool-index.md` 刷新应校验可执行性，而不是仅记录路径存在。
- go-rust-reverse 增加“无 GoReSym 的 pclntab 分诊”小节与脚本（本次已贡献）。
- 可在 skill 中提示 Ghidra postScript 的类型陷阱与日志定位方法。

## 可复用的模式/脚本片段
- `scripts/extract_strings.py`：Go pclntab 名字 / Rust 字符串过滤，纯 Python 无依赖。
- `scripts/pe_exports.py`：无依赖 PE 段表 + 导出表解析（输出精确 RVA/VA）。
- `references/ExportDecomp.java`：Ghidra headless 导出可执行入口 + panic 锚点反编译。

## 进化动作
- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [x] 更新了子 skill 文档（go-rust-reverse SKILL.md）
- [x] 新增了 pitfalls 记录（tool-index 滞后、Ghidra postScript 类型错误）
- [ ] 无需更新

## 环境信息
- OS: Windows 10.0.26100
- 工具版本: Go 1.27.0（目标），Ghidra 12.1.4 + JDK 21，Python 3.13
- 目标平台/版本: windows/amd64（Go 应用 + rustc 原生 DLL）

## 脱敏要求
已脱敏：无真实域名/IP/token；样本为 owner 自有本地文件。
