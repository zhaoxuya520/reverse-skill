# 2026-09-20 iJiami 加固壳 dyncryptor RC4 变体 + zlib 解密链恢复

## 场景分类

APK 逆向（商业加固壳自定义解密链恢复）

## 目标概述

对一枚业主授权的八字排盘类 Android APK（{target_package}，sha256 {sample_sha256}）做离线静态逆向：确认 Java 业务层是否可恢复、恢复加固壳自定义解密管线、采集 UI 契约供授权方原生重建。全程离线单样本，不触生产。

## Scope 摘要（脱敏）

- auth_basis: 业主授权样本 + 授权重建上下文，仅离线静态分析
- network_profile: offline
- asset_types: [Android APK (~89 MB), native .so (arm32/x64), DEX overlay 加密区, 加密 blob, asset 数据集]

## 角色

- lead_role: lead（案例管理、证据登记、报告收尾）
- specialists: [cre（静态逆向）, doc（收尾文档）]

## 完整执行链路

1. case-init + scope（offline / anonymize / low），定三目标与红线。
2. apktool 基线解码（E-001）：Application=`s.h.e.l.l.S`、124 activities、无业务 Java；libjgdtc / libijmDataEncryption{,_x64}.so → 壳特征初判。
3. 承接首轮遗留 iJiami 元数据 blob（E-002，208 B 标记前缀）。
4. x64 装载器 r2 recon（E-003/E-004/E-007）：stripped PIE、NX partial-RELRO、zlib/dlopen 导入、无网络导入；6 字节间接 thunk `fcn.00002de0: jmp qword [0x3ff48]` → VMP 迹象（F-004 candidate）。
5. 真机 UI 采集（E-016）：dumpLayout 钉住启动 Activity 与根节点契约。
6. arm32 链路（E-005/E-006/E-012）：overlay magic xrefs 定位 JNI 链 fcn.00012e60 → KSA fcn.00012788 → PRGA fcn.00012834；识别计算跳转 opcode 派发解释器（VMP-style）。
7. overlay 手工解析（E-008）：stub_end 0x3a70 后 21,499,724 B overlay，3 records（r1 2,420,690 B @0x4020 熵 7.999927；r2 19,037,852 B；r3 39,708 B），magic `71680001`，共享前缀 `632337b8`。
8. **dyncryptor 完整解密（E-009/E-010/E-011）**：RC4 变体 KSA（i=3, j=5, i+=2, j+=state[i]+1）+ KEY {key_hex} + zlib 到 EOF；arm32 678,676 B → 1,260,533 B、x64 926,149 B → 2,257,585 B，双架构独立验证（F-003 validated/high）。
9. 弯路一：assets/bttets（698 文件）初判为算法数据集，全量哈希指纹甄别后确认全部为 1 字节 0x20 占位（E-013）→ Java 层不可恢复定论（F-002 / F-005）。
10. 弯路二：unidbg 动态确认（E-017）捕获 0 字节且早于源码 mtime → 如实记 INCOMPLETE（F-007 candidate/low），静态结论自足。
11. 收尾：17 条证据不可变登记（append-evidence.ps1）、7 findings + 2 paths、timeline 10 条、英文 5 节报告、本 journal。

## Evidence 链摘要（脱敏）

| E-id | severity | status | source_type | 可复用命令模式 | 关联 Finding |
|---|---|---|---|---|---|
| E-009 | info | observed | command | 自写解包脚本对 blob 做 RC4 变体解密 + zlib 到 EOF，输出 sha256 已存证 | F-003 |
| E-011 | info | observed | command | r2 `-A` 后 `pdf @ KSA函数` 提取步进（i+=2 / j+=state[i]+1 / 初值 3,5） | F-003 |
| E-013 | info | observed | command | 全量 sha256/crc32 直方图甄别占位数据集（698 × 同哈希 → 0x20 占位） | F-005 |

> 契约对齐：17 条证据全部经 `append-evidence.ps1` 不可变登记（severity=info / status=observed / source_type=command，实质严重性由 findings 承载）；本表仅列解密链最关键 3 条，全量见案例 `evidence/INDEX.md`。

## Finding / Path 摘要

- top_finding: F-003 — dyncryptor 管线（RC4 变体 KSA/PRGA + zlib）完整恢复，validated / high
- path_type: solve
- path_one_liner: overlay 手工解析定位加密 blob → 静态读出 KSA 变体步进与 KEY → 自写脚本离线复现双架构解密（P-002）

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|---|---|---|---|
| bttets 误判为八字算法数据集 | 698 文件全部是同尺寸 1 字节 0x20 占位，单文件抽查不可靠 | 全量 sha256/crc32 直方图 + payload_hex 全集比对，占位实锤 | ~0.5h |
| unidbg 捕获 0 字节 | 捕获时间戳早于 harness 源码 mtime，运行未产出可观察输出即中止 | 如实记 INCOMPLETE（F-007），不阻塞静态结论；教训：捕获文件必须先验证非空 + mtime 再采信 | ~1h |
| apktool 停在 iJiami overlay 前无法继续 | 自定义 overlay 布局非标准 zip/dex 结构 | 自写解析脚本按 magic + 记录头（offset/size）手工切分 | ~1h |

## 工具链发现

- radare2 6.2.2 在 89 MB APK + 21 MB overlay 上稳定，`recon.ps1` 批处理输出可直接落证据。
- apktool 不解析 iJiami overlay：基线解码（manifest/res）仍有效，加密区必须手工。
- `append-evidence.ps1` 不可变登记 + `review_case.py` 契约校验，证据链可机器审计，值得沿用。
- unidbg 对 iJiami 壳默认文件系统解析易静默失败——无输出 ≠ 成功。

## 关键代码/命令

（识别特征示意，非可运行；权威实现见案例 evidence E-008..E-011 与报告）

```python
# iJiami dyncryptor RC4 变体识别特征（arm32 KSA fcn.00012788，x64 同构）
i, j = 3, 5                          # 非标准初值（教材 RC4 为 0, 0）
while i < 256:
    j = (j + state[i] + 1) & 0xFF    # 非标准步进（教材 RC4 为 j + state[i]）
    i += 2                           # 非标准步长
    state[i], state[j] = state[j], state[i]
# KEY 为 10 字节硬编码 {key_hex}
# keystream 随后 zlib 解压到 EOF
# 双架构验证：arm32 blob@0x44514 678,676 B → 1,260,533 B；x64 blob@0x343b0 926,149 B → 2,257,585 B
```

## 对本包的改进建议

1. `append-evidence.ps1` 应对 repro_command 做证据相对路径前缀校验（本案例 E-003..E-006 的 repro 缺 `evidence\` 前缀，登记后不可变无法修正）。
2. unidbg / 动态类工具建议在 pitfalls 增加「捕获有效性必查项」：输出非空 + 捕获 mtime 晚于源码 mtime。
3. workitems coverage 语句建议中性措辞（如 "Report via docs-generator" → "Report authored per closeout contract"），避免勾选项与事实不符。

## 可复用的模式/脚本片段

1. **加固壳 overlay 手工解析模式**：apktool 停在加密区时，读 DEX stub 末尾 offset（stub_end）→ 扫 magic → 按记录头（offset/size）切分 → 熵值确认加密性。本例 stub_end=0x3a70、magic=0x71680001。
2. **RC4 变体识别信号**：KSA/PRGA 出现 i+=2、j+=state[i]+1、初值 i=3/j=5 即判定变体——按实际指令重写，不要套教材实现。
3. **占位数据集哈希指纹甄别**：海量小文件先做全量 sha256 直方图，同哈希 × N 即占位，免去逐文件人工分析。

## 进化动作

- [ ] 更新了路由矩阵
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [ ] 新增了 pitfalls 记录
- [x] 无需更新

## 环境信息

- OS: Windows + PowerShell 5.1
- 工具版本: radare2 6.2.2（commit ad27058…）、apktool、Python 3（自写解析/解包脚本）、unidbg（尝试性使用）
- 目标平台/版本: Android APK；iJiami（爱加密）商业加固壳；UI 采集用 Android 真机（API 26）

## 脱敏要求

本文件已按 [`anonymization.md`](anonymization.md) 完成脱敏：

- 占位符：{target_package} / {sample_sha256} / {key_hex}
- 不含：设备型号/序列号、真实包名/bundleName、完整 KEY、blob sha256 明文值、任何真实用户数据
- 保留：工具名+版本、函数名/偏移、magic/结构特征、模式性结论（公开技术信息）

## 索引同步

- [x] 「按场景分类 → APK / Android 逆向」新增条目
- [x] 「高频成功模式」新增「Android 加固壳自定义解密链」小节
- [x] 「实体倒排」新增「iJiami（爱加密）加固 APK」小节
- [x] 「累计统计」更新（真实项目 22 / 总条目 39 / 最近更新 2026-09-20）

---

<!-- [进化统计] 本包累计完成项目: 22 | 本次新增模式: 1 | 本次修复工具链问题: 0 -->
