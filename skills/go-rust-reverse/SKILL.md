---
name: go-rust-reverse
description: Use for reverse engineering stripped Go and Rust binaries including runtime recognition, pclntab/moduel data recovery, panic strings, and idiomatic decompilation recovery.
---

# Go / Rust Binary Reverse Engineering

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`: 读取 `../field-journal/precedent-reverse.md`
2. `NOW`: 确认样本为 Go/Rust 编译产物（`file`/字符串/运行时特征）
3. `NEXT`: GoReSym / 相关插件是否可用
4. `ACT`: 运行时识别 → 符号/元数据恢复 → 业务逻辑

## 适用场景

- 剥离符号的 Go 恶意软件/工具
- Rust 发行二进制、panic 字符串驱动分析
- 与通用 ida/ghidra 互补的语言专用方法

## 工作流

### Go

```text
□ 识别 go.buildid、runtime 符号残留、pclntab
□ GoReSym / redress / IDA Go 插件恢复函数名
□ 注意 interface、slice、string 结构在反编译中的形态
□ 网络/加密库路径：crypto/* net/http
```

### Rust

```text
□ panic 字符串、rust_begin_unwind、crate 路径暗示
□ 范型实例化导致的代码膨胀；先定位字符串 xref
□ 异步/tokio 状态机需结合交叉引用
```

### 动态

```text
□ 仍可用 Frida；注意 Go 栈与调度
□ 优先日志与配置字符串驱动断点
```

## 工具链

| 工具 | 用途 |
|------|------|
| GoReSym | Go 元数据 |
| IDA/Ghidra + Go/Rust 插件 | 反编译 |
| radare2 | 快速字符串 |
| strings / rabin2 | 分诊 |
| `go version -m` / `go tool buildid` / `go tool nm` | Go 内建元数据（无需 GoReSym） |
| `scripts/extract_strings.py` / `scripts/pe_exports.py` | Go pclntab 名字、Rust 字符串、PE 导出表（纯 Python，无依赖） |
| `references/ExportDecomp.java` | Ghidra headless postScript：导出导出函数反编译 |

## 无 GoReSym 的 pclntab 恢复（已验证）

Go 二进制即使 `-ldflags=-s -w -buildid=` 且 `go tool nm` 报 `no symbols`，
`runtime.pclntab` 仍保留全部函数名。最小流程：

```text
□ go version -m <exe>              # 工具链、模块、依赖、build flags、本地 replace 路径
□ go tool nm <exe>                 # 期望 no symbols（确认已剥离）
□ go tool buildid <exe>            # 空 = 已清除
□ python scripts/extract_strings.py <exe> gofunc   # 恢复 main.* / 供应商包函数名
□ python scripts/pe_exports.py <dll>               # 原生伴生 DLL 的精确导出 RVA/VA
□ Ghidra headless（见 references/ExportDecomp.java）反编译原生导出
```

**注意**：恢复函数名是元数据还原，不是绕过保护；结论中必须明确该边界。
`tool-index.md` 里的路径可能滞后，运行前确认可执行文件真实存在（曾见 `rabin2`
索引存在但安装目录只剩 `r2sdb`）。

## 参考

- `references/go-rust-notes.md`
- `references/ExportDecomp.java`（Ghidra headless 导出反编译）
- `scripts/extract_strings.py` `scripts/pe_exports.py`
- `../reverse-engineering/go-reverse.md` `../ida-reverse/` `../ghidra-reverse/`
- seed: `field-journal/seed-002_go-malware-stripped.md`
- journal: `field-journal/2026-09-29_stripped-go-pclntab-rust-dll-triage.md`

## 路由上下文

**上游**: MASTER R33  
**下游**: 恶意样本流程 `malware-analysis`；通用 RE `reverse-engineering`

## 任务完成自检

- [ ] 是否恢复关键函数名或等价映射？
- [ ] 是否标注语言运行时证据？
- [ ] Checklist？