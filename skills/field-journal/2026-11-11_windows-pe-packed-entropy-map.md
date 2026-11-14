# 2026-11-11 Windows 强壳 PE 静态测绘

## 场景分类

二进制分析 / PE 加壳样本全面分诊（纯静态、离线）

## 目标概述

对一个约 60 MiB 的本地 Windows x64 GUI 可执行文件做全面静态分析，判定软件身份、保护结构、可推断的风险边界，并明确哪些结论不能下。

## Scope 摘要（脱敏）

- auth_basis: owner-operated（本地离线样本，offline-sample preset）
- network_profile: offline（无对外发包）
- asset_types: [local_pe_binary, sibling_executables_readonly]

## 角色

- lead_role: lead
- specialists: [cre]

## 完整执行链路

1. `master-route.ps1` → PRIMARY = R0 通用逆向（confidence low，无强关键词命中）；同步 `case-init.ps1 -Preset offline-sample` 落地 scope，auth=granted / network=offline / ready_for_act=true。
2. 读 `scope-contract.md`、`re-agent-workflow.md`、`precedent-reverse.md`、`tool-index.md`，确认 r2/rabin2/Python 可用，IDA/Ghidra/YARA 缺失 → 动态脱壳路径本次不可达。
3. 首轮手工解析 PE 头：x86-64 PE32+ / 10 节 / 6 节 RawSize=0 / 单一 60 MiB 满熵节 / EP 落在加密节内 → 判定为内存还原型强壳。
4. rabin2 交叉验证导入表（Triage 硬门）：仅 6 DLL / 7 API，手工补出被截断的第 7 个；标注 `quality=packed/decoy`。
5. 手工解析资源目录树 → 版本信息给出软件真实名称、版本、语言；提取 7 个 PNG 图标与 manifest。
6. 统计学判定加密：4 MiB 熵、可打印比例、χ²、重复 16B 块、单字节 XOR 爆破、已知壳标记扫描。
7. 64 KiB 窗口全载荷熵地图 → 定位代码块地址表、变形 x64 stub 区、尾部 RVA 区间表。
8. 低熵岛内容勘察 → 确认 6 字节/条的 (u32 RVA + u16 flag) 记录与 REX+push/pop 生成的机器码。
9. 同目录兄弟 exe 只读结构比对 → 环境旁证（不展开其内容）。
10. 生成 E-001~E-010 / F-001~F-007 / P-001，`review_case.py --strict` 校验 PASS（0 error / 0 warning）；产出 Markdown 正式报告 + HTML 可视化报告。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|------|----------|--------|-------------|----------------|--------------|
| E-002 | high | observed | command | `python static_analyze.py`（PE 头 / 节表 / EP 映射） | F-001 |
| E-003 | high | observed | command | `rabin2 -i sample.exe` + 手工 IMAGE_IMPORT_DESCRIPTOR | F-003 |
| E-006 | high | observed | command | `python context_analyze.py`（熵 / 可打印比 / XOR 爆破） | F-001 |

## Finding / Path 摘要

- top_finding: 商用级内存还原型强壳，99.8% 内容加密，静态不可审计；诱饵式极小 IAT 不可用于能力否定。
- path_type: callflow
- path_one_liner: loader 映射虚拟节 → 填诱饵 IAT → 进入加密节 EP → 查代码块映射表 → 动态解析真实 API → 解密回填原映像 → 变形 stub 中介执行（结构推断，未动态验证）。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| `rabin2` 报 `Cannot open file` 且路径乱码 | Windows 侧工具按 ANSI 解释命令行，中文文件名被破坏 | 在 case 目录复制一份纯 ASCII 名的只读副本，先核对 SHA256 一致 | 5 min |
| `pefile` 报 `module has no attribute DIRECTORY_TYPE` | 2024.8.26 版该常量已改名/移除 | 不依赖 py 常量，按 IMAGE_IMPORT_DESCRIPTOR 20 字节结构手工解析 | 5 min |
| Python `SyntaxError: bytes can only contain ASCII` | bytes 字面量里写了中文关键词 | 中文字符串用 `x.encode("utf-8")` 生成 | 2 min |
| 熵函数 `NameError: math` | 新脚本漏 import | 补 import 后重跑 | 1 min |
| 初读 ImageBase 得到 0x40000000（错误） | PE32+ 的 ImageBase 是 8 字节，误用 `<I` 读 4 字节 | 改 `<Q`，正确值 0x140000000；同时 subsystem 读 2 字节而非 4 | 3 min |
| gzip/zlib/MZ 魔数在载荷里命中 900+ 次，差点误判为嵌套压缩包 | 2 字节魔数在 60 MB 均匀随机数据中的期望命中约 960 次 | 加入「期望命中数」对照与熵/重复块交叉验证，判定为随机巧合 | 8 min |
| 首轮 marker 扫描出现 `UPX`，疑似 UPX 壳 | 3 字节短串在 60 MB 中偶发命中 | 检查 UPX 段头/节名/入口 stub 均无 → 排除，写入证据避免误报 | 3 min |

## 工具链发现

- 可用：`rabin2 6.2.4`、`Python 3.13.15`（`pefile 2024.8.26`、`capstone 5.0.9`）。手工 struct 解析比 pefile 更可靠地处理被壳篡改过的 PE。
- 缺失：IDA Pro、Ghidra、x64dbg、YARA、Frida → 无法走「脱壳 → 修 IAT → 反编译」路径，只能停在静态分诊 + 结构测绘。
- `rabin2 -I` 的 `cmp.csum` 与 PE 头 `checksum` 字段对比，是识别「壳重建头部」的低成本信号。
- `rabin2 -z` 在满熵节里输出的全是噪声字符串，需配合熵过滤，不要直接当 IOC。

## 关键代码/命令

```bash
# 中文路径 → ASCII 副本（先核对哈希）
cp "{local_sample}" "{case_root}/sample.exe" && sha256sum "{case_root}/sample.exe"

# Triage 硬门
rabin2 -I sample.exe; rabin2 -i sample.exe; rabin2 -E sample.exe

# 四轮自写测绘
python static_analyze.py     # 头 / 节 / 熵 / 数据目录 / IOC
python deep_analyze.py       # 导入描述符 / 资源树 / 版本 / 反汇编
python context_analyze.py    # 熵统计 / 兄弟样本比对 / 异常清单
python payload_map.py        # 64 KiB 熵地图 / 尾部索引表
python islands.py            # 低熵岛勘察

# 证据链校验
python review_case.py "{case_root}" --verify-hashes --strict
```

## 对本包的改进建议

- `routing.json` 的 R0 对「全面分析这个软件 / 样本」这类请求只有 low confidence fallback；建议增加「PE 样本全面分诊 / 软件构成分析」关键词组，或在 `routing.md` 三轴附录给出「未知 PE → R9 六阶段方法 + R0 测绘」的显式组合指引。
- `tool-index` 中 Windows 动态工具缺失是本次停在静态的主要外部原因；可在文档里预先给出「无 IDA/x64dbg 时的静态测绘上限」说明，避免误以为分析不完整。
- 建议把「短魔数在满熵数据中的期望命中数」写入 triage 菜谱，防止把随机巧合当容器证据。

## 可复用的模式/脚本片段

1. **虚拟节检测**：节表 `RawSize=0` 数量 + EP 是否落在唯一大节内 → 判定内存还原型壳。
2. **加密判定三件套**：Shannon 熵（≥7.99）、可打印 ASCII 比例对比理论值 37.11%、重复 16B 块数（ECB 检测）→ 区分「加密」与「明文/简单 XOR」。
3. **熵地图定位壳元数据**：64 KiB 滑窗扫描，低熵岛通常就是壳的代码块映射表 / 区间表 / 变形代码区。
4. **诱饵 IAT 识别**：API 总数 < 20 且跨 DLL 无业务关联 → 标注 `quality=packed/decoy`，禁止据此做能力否定。
5. **证据链自检**：报告里 `### F-xxx` 带 `evidence_ids`、`### P-xxx` 带 `E-xxx` 引用，`review_case.py --strict` 即可零警告通过。

## 进化动作

- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录（本文件）
- [ ] 无需更新

## 环境信息

- OS: Windows (win32, Git Bash + PowerShell 5.1)
- 工具版本: radare2 6.2.4 / Python 3.13.15 / pefile 2024.8.26 / capstone 5.0.9
- 目标平台/版本: Windows PE32+ x86-64 GUI，商用级第三方保护壳

## 脱敏说明

本记录不含真实域名、IP、Token、用户名或内网地址；样本路径一律以 `{local_sample}` / `{case_root}` 占位，软件名称以「本地 PE 样本」泛称，哈希仅保留在用户项目的证据目录中。

<!-- [进化统计] 本包累计完成项目: 22 | 本次新增模式: 5 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 完成后询问用户是否 PR 到主仓库。流程见 CONTRIBUTE-BACK.md -->
