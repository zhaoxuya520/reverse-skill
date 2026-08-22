# AGS 吸收地图（KEEP 全部 10 个 agent skill）

来源：[gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security)（MIT，Copyright 2022 gmh）。

**Pin：** `gmh5225/awesome-game-security@bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2`（[ags/UPSTREAM.txt](ags/UPSTREAM.txt)）。刷新：`scripts/install-ags-refs.ps1`。

PRIMARY 仍是本包 `game-security/`（路由 **R43**）。AGS 的 10 个 Claude skill **全部作为一等参考装入** `ags/`。命中后 **MUST 硬跳转** 打开对应 `ags/*.md` 全文；`engines.md` / `anti-cheat-families.md` / `tools.md` **不是** 完整 skill。

## 10 skill KEEP 表

| AGS skill（截图名） | 上游目录 | 本包落点 | 冲突优化 |
|---------------------|----------|----------|----------|
| anti-cheat-systems | `.claude/skills/anti-cheat` | **KEEP** [ags/anti-cheat.md](ags/anti-cheat.md) | 家族快表仍在 [anti-cheat-families.md](anti-cheat-families.md)；内核作业交接 `kernel-driver-reverse.md` / `edr-bypass-re/` |
| dma-attack-techniques | `.claude/skills/dma-attack` | **KEEP** [ags/dma-attack.md](ags/dma-attack.md) | **SSoT** for pcileech/FPGA/IOMMU。`anti-cheat.md` DMA 段是 AGS 原文重叠，不删，冲突以本文件为准 |
| game-engine-resources | `.claude/skills/game-engine` | **KEEP** [ags/game-engine.md](ags/game-engine.md) | dump 命令与 tool-index 仍在 [engines.md](engines.md) / [il2cpp-dump.md](il2cpp-dump.md) |
| **game-hacking-techniques** | `.claude/skills/game-hacking` | **KEEP** [ags/game-hacking.md](ags/game-hacking.md) | 技术目录全文保留；不加额外禁令 |
| graphics-api-hooking | `.claude/skills/graphics-api` | **KEEP** [ags/graphics-api.md](ags/graphics-api.md) | Present/DX/VK/GL/ImGui 全文保留 |
| mobile-security | `.claude/skills/mobile-security` | **KEEP** [ags/mobile-security.md](ags/mobile-security.md) | APK 解包仍先 `apk-reverse/`，解完回到本表做游戏向 IL2CPP/root/Zygisk |
| awesome-game-security-overview | `.claude/skills/overview` | **KEEP** [ags/overview.md](ags/overview.md) | 本地分发；上游 README 格式/27 个顶栏保留 |
| game-security-research-rigor | `.claude/skills/research-rigor` | **KEEP** [ags/research-rigor.md](ags/research-rigor.md) | Observation/Finding/Attribution/Decision 映射 `ops/evidence-finding-path.md` |
| reverse-engineering-tools | `.claude/skills/reverse-engineering` | **KEEP** [ags/reverse-engineering.md](ags/reverse-engineering.md) | 游戏 RE 工具/混淆/DBI 目录保留；作业走 `ida-reverse/` `ghidra-reverse/` `radare2/` |
| windows-kernel-security | `.claude/skills/windows-kernel` | **KEEP** [ags/windows-kernel.md](ags/windows-kernel.md) | 回调/Segment Heap/HVCI/WHP 目录保留；驱动作业交接 `kernel-driver-reverse.md` |

分发表（query → 文件）与上游一致，见 [ags/overview.md](ags/overview.md) 的 Skill Routing Guide。

## 事先告知的包装层删减（不是技能能力 DROP）

这些 **不是** 把 AGS skill 蒸没。它们与 reverse-skill 的 IDENTITY / 路由 SSoT **冲突**，所以不整仓 vendor：

| 上游 | 为何不整仓拷进 git | 能力是否还在 |
|------|-------------------|--------------|
| README ~4250 条 bullet（Cheat ~2757 / Anti Cheat ~711 / Engine ~181 / 其余开发向） | `ops/IDENTITY.md`：禁止 submodule 巨型列表 | **在**：按需 fetch，见 [ags/fetch-upstream.md](ags/fetch-upstream.md) |
| `wiki/` 编译综述 | 体量大、上游常更新 | **在**：fetch `wiki/overviews/<topic>.md` |
| `archive/` code2prompt 快照 | 供应链面大 | **在**：fetch `archive/{owner}/{repo}.txt` |
| `description/` 自动摘要 | 同上 | **在**：fetch `description/{owner}/{repo}/description_en.txt` |
| 10 个独立 PRIMARY / `npx skills add` ×10 | reverse-skill 只有一套 `routing.json`；R42 已预留给 threat-intel | **在**：10 个参考挂在 **一个** PRIMARY R43 下 |
| AGS 每份 skill 末尾重复的 Data Source 页脚 | 十份拷贝同一段 fetch 说明 | **在**：抽到 [ags/fetch-upstream.md](ags/fetch-upstream.md) |

若你要改其中任何一条（例如把 README 整份 vendor 进 git），先说，不要默认再蒸技能正文。

## 与 IDENTITY / 路由对齐

- 不 submodule 巨型列表（`ops/IDENTITY.md`、`ops/skill-supply-chain.md`）
- 游戏安全 PRIMARY **R43**。**R42** 预留给 threat-intel（PR #108）。ADF-R42（YARA）是第三命名空间
- 技术门禁：**只**用 reverse-skill `RULES.md`/`IDENTITY.md` 和 AGS skill 原文。不在吸收层另写禁令

## 用户要「完整 AGS 能力」时怎么回答

```text
已经是一个仓库：reverse-skill。
10 个 AGS agent skill 在 skills/game-security/references/ags/（含 game-hacking-techniques）。
链接堆 / wiki / archive 按 fetch-upstream.md 现拉，不 vendor 12k commits。
ACT 前仍要 reverse-skill case-init。AGS 原文 Ethical Use 跟对应 ags/*.md。
```
