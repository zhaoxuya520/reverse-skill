# AGS 吸收地图（KEEP 全部 10 个 agent skill）

来源：[gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security)（MIT，Copyright 2022 gmh）。检索日：**2026-08-22**。

PRIMARY 仍是本包 `game-security/`（路由 **R43**）。AGS 的 10 个 Claude skill **全部作为一等参考装入** `ags/`，不是 DROP，也不是 INDEX-ONLY 空指针。

等价于 AGS 侧 `npx skills add` ×10：agent 在 R43 命中后按下面的分发表打开对应文件。

## 10 skill KEEP 表

| AGS skill（截图名） | 上游目录 | 本包落点 | 冲突优化 |
|---------------------|----------|----------|----------|
| anti-cheat-systems | `.claude/skills/anti-cheat` | **KEEP** [ags/anti-cheat.md](ags/anti-cheat.md) | 家族快表仍在 [anti-cheat-families.md](anti-cheat-families.md)；内核作业交接 `kernel-driver-reverse.md` / `edr-bypass-re/` |
| dma-attack-techniques | `.claude/skills/dma-attack` | **KEEP** [ags/dma-attack.md](ags/dma-attack.md) | 威胁模型 + 检测目录全保留；未授权 live 标题 FPGA 不是交付物 |
| game-engine-resources | `.claude/skills/game-engine` | **KEEP** [ags/game-engine.md](ags/game-engine.md) | dump 命令与 tool-index 仍在 [engines.md](engines.md) / [il2cpp-dump.md](il2cpp-dump.md) |
| **game-hacking-techniques** | `.claude/skills/game-hacking` | **KEEP** [ags/game-hacking.md](ags/game-hacking.md) | 技术目录全保留（RPM/injection/overlay/aim/DMA/HWID/KMBox…）；禁止的是 live-title trainer **成品** |
| graphics-api-hooking | `.claude/skills/graphics-api` | **KEEP** [ags/graphics-api.md](ags/graphics-api.md) | Present/DX/VK/GL/ImGui 目录保留；overlay 当威胁模型或授权实验室 |
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
| 10 个独立 PRIMARY / `npx skills add` ×10 | 本包只有一套 `routing.json`；R42 已预留给 threat-intel | **在**：10 个参考挂在 **一个** PRIMARY R43 下 |
| AGS 每份 skill 末尾重复的 Data Source 页脚 | 十份拷贝同一段 fetch 说明 | **在**：抽到 [ags/fetch-upstream.md](ags/fetch-upstream.md)（合理蒸馏） |
| 对 **未授权 live 网游** 交付 trainer / 可分发外挂成品 | `case-init` + `auth.status=granted` 硬门；RULES 只拒成品 | 技术目录、dump、观察 hook、副本 patch、AC/DMA/内核 RE **全部执行** |

若你要改其中任何一条（例如把 README 整份 vendor 进 git），先说，不要默认再蒸技能正文。

## 与 IDENTITY / 路由对齐

- 不 submodule 巨型列表（`ops/IDENTITY.md`、`ops/skill-supply-chain.md`）
- 游戏安全 PRIMARY **R43**。**R42** 预留给 threat-intel（PR #108）。ADF-R42（YARA）是第三命名空间
- 「纯外挂产品轨」= 不交付 live-title trainer；**不是** 删除 game-hacking 技术目录

## 用户要「完整 AGS 能力」时怎么回答

```text
已经是一个仓库：reverse-skill。
10 个 AGS agent skill 在 skills/game-security/references/ags/（含 game-hacking-techniques）。
链接堆 / wiki / archive 按 fetch-upstream.md 现拉，不 vendor 12k commits。
ACT 前仍要 case-init；授权实验室能力不减。
```
