# AGS 吸收地图（严格整理）

来源：[gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security)（MIT，Copyright 2022 gmh）。检索日：**2026-08-22**。

上游约 4250 条 bullet、12k+ commit、356KB README。本包 **MUST NOT** submodule 或拷贝该 README。需要某条链接时打开上游，不要在本仓库再维护一份列表。

## 决策总表

| 上游 | 规模/形态 | 本包策略 | 落点 |
|------|-----------|----------|------|
| `.claude/skills/anti-cheat` | AC 架构 + 大量 bypass/DMA 操作文 | **KEEP 识别层**；DROP bypass/DMA 实操 | `anti-cheat-families.md` |
| `.claude/skills/game-engine` | 引擎源码/插件/SDK dump | **KEEP 指纹 + dump 链**；不拷 Cheat SDK 产品用法 | `engines.md` + `il2cpp-dump.md` |
| `.claude/skills/research-rigor` | 观察/Finding/归因分层 | **KEEP 压缩**（对齐 Evidence→Finding→Path） | `anti-cheat-families.md` + 本 skill 铁律 |
| `.claude/skills/reverse-engineering` | 游戏 RE 工具综述 | **INDEX-ONLY** → 已有 `ida-reverse` / `ghidra-reverse` / `radare2` | `tools.md` |
| `.claude/skills/windows-kernel` | 回调 / MMVAD / PatchGuard | **INDEX-ONLY** → `kernel-driver-reverse.md` | 交接，不复制 |
| `.claude/skills/dma-attack` | PCIe/FPGA | **INDEX-ONLY 威胁模型**；MUST NOT 操作步骤 | `anti-cheat-families.md` 一段 |
| `.claude/skills/graphics-api` | DX/GL/VK hook / overlay | **INDEX-ONLY**；MUST NOT ESP 教程 | 用户问 overlay 威胁时一句话 + 上游 |
| `.claude/skills/mobile-security` | 移动游戏 | **不新建** → `apk-reverse/` `mobile-reverse/` | 解包后再回 R43 |
| `.claude/skills/overview` | 仓库导航 | **DROP**（由本文件替代） | — |
| `.claude/skills/game-hacking` | 外挂实现视角 | **DROP** | 产品轨禁止 |
| README `Cheat` | ~2757 links | **DROP** | 禁止拷贝 how-to |
| README `Anti Cheat` | ~711 links | **KEEP 家族名**；链接留上游 | `anti-cheat-families.md` |
| README `Game Engine` | ~181 links | **KEEP 指纹**；源码列表留上游 | `engines.md` |
| README 其余（数学/渲染/资源/CI/模拟器/主机） | 开发向 | **DROP** | 非本包域 |
| `wiki/` `archive/` `description/` `scripts/` | 列表维护/代码快照 | **不 vendor** | 供应链面大 |

## 与 IDENTITY 对齐

- 不 submodule 巨型列表（`ops/IDENTITY.md`、`ops/skill-supply-chain.md`）
- 纯游戏外挂开发 **不是** 产品方向（`domain-coverage-map.md`）
- 游戏安全现在是 PRIMARY **R43**，不再把 Unity/IL2CPP 塞进 R0。**R42 预留**给 threat-intel（PR #108），禁止抢号

## 用户要「合并整个 AGS 仓库」时怎么回答

```text
已经是一个仓库：reverse-skill。
合并方式 = 蒸馏 skill + 本地图，而不是 12,893 commits。
完整链接仍在 https://github.com/gmh5225/awesome-game-security
```
