> **reverse-skill adapter** - AGS `awesome-game-security-overview` under PRIMARY `game-security/` (routing **R43**). Not a second PRIMARY.
>
> **Pin:** `gmh5225/awesome-game-security@bf403cf9e37f` (`bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2`). Refresh: `scripts/install-ags-refs.ps1`.
> **Gates that already exist (do not add more here):** reverse-skill `case-init` / `auth.status=granted` before ACT; AGS Ethical Use / authorized-testing text in this file if the upstream skill has it.
> **Handoff:** hard-jump table is PRIMARY ``game-security/SKILL.md`` plus this file. Do not vendor the 4250-bullet README; fetch via ``fetch-upstream.md``.
> **Fetch:** [fetch-upstream.md](fetch-upstream.md). Wiki: `wiki/overviews/overview.md`.
> **Distill:** duplicated Data Source footer only. Taxonomy and workflows kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: awesome-game-security-overview
description: Guide for understanding and contributing to the awesome-game-security curated resource list. Use this skill when adding new resources, organizing categories, mapping topics across anti-cheat, Windows kernel, DMA, reverse engineering, and game-engine research, or maintaining README.md format consistency.
---

# Awesome Game Security - Project Overview

## Purpose

This is a curated collection of resources related to game security, covering both offensive (game hacking, cheating) and defensive (anti-cheat) aspects. The project serves as a comprehensive reference for security researchers, game developers, and enthusiasts, especially where Windows internals, driver trust, reverse engineering, DMA, and modern anti-cheat defenses intersect.

## README Coverage

- Top-level engines and rendering: `Game Engine`, `Renderer`, `DirectX`, `OpenGL`, `Vulkan`
- Offensive research: `Cheat`
- Defensive research: `Anti Cheat`
- Platform hardening: `Windows Security Features`
- Platform-specific ecosystems: `Android Emulator`, `IOS Emulator`, `Windows Emulator`, `Linux Emulator`
- Supporting infrastructure: `Mathematics`, `3D Graphics`, `AI`, `Image Codec`, `Wavefront Obj`, `Task Scheduler`, `Game Network`, `PhysX SDK`, `Game Develop`, `Game Assets`, `Game Hot Patch`, `Game Testing`, `Game Tools`, `Game Manager`, `Game CI`
- Platform subsystems: `WSL`, `WSA`
- Console emulation: `Game Boy`, `Nintendo Switch`, `Xbox`, `PlayStation`
- Tips and tricks: `Some Tricks`

## Project Structure

```
awesome-game-security/
├── README.md           # Main resource list
├── LICENSE             # MIT License
├── awesome-image.webp  # Project banner
└── scripts/
    ├── generate-toc.py  # Generate table of contents
    └── remove-forks.py  # Clean up forked repos
```

## README.md Format Convention

### Category Structure

Each category follows this format:

```markdown
## Category Name
> Subcategory (optional)
- https://github.com/user/repo [Brief description]
- https://github.com/user/repo [Another description]
```

### Link Format

- Always use full GitHub URLs for repositories
- Non-GitHub links are also supported (blog posts, articles, documentation sites)
- Add brief descriptions in square brackets `[description]`
- Use consistent spacing and formatting
- Group related resources under subcategories with `>`

### Example Entry

```markdown
## Game Engine
> Guide
- https://github.com/example/guide [Comprehensive game dev guide]

> Source
- https://github.com/example/engine [Open source game engine]
```

## Skill Routing Guide

When an AI agent receives a query, use this table to select the best skill:

| Query topic | MUST open (full skill) | Related |
|---|---|---|
| EAC, BattlEye, Vanguard, detection, heartbeat, screenshot | [anti-cheat.md](anti-cheat.md) | [windows-kernel.md](windows-kernel.md) |
| pcileech, FPGA, DMA, IOMMU, Thunderbolt | [dma-attack.md](dma-attack.md) (SSoT) | [anti-cheat.md](anti-cheat.md) |
| Unreal SDK, Unity IL2CPP, engine structs, Godot, Lumix | [game-engine.md](game-engine.md) | [game-hacking.md](game-hacking.md) |
| Memory hacking, injection, overlays, driver comm, HWID spoof | [game-hacking.md](game-hacking.md) | [graphics-api.md](graphics-api.md) |
| D3D/Vulkan/OpenGL hooks, Present hook, shader interception | [graphics-api.md](graphics-api.md) | [game-hacking.md](game-hacking.md) |
| Android root, Frida, iOS jailbreak, KernelSU, APatch | [mobile-security.md](mobile-security.md) | [game-hacking.md](game-hacking.md) |
| IDA, Ghidra, DBI, deobfuscation, binary diffing, MCP RE tools, trap-and-emulate CFT, WHP tracing | [reverse-engineering.md](reverse-engineering.md) | anti-cheat, windows-kernel |
| Drivers, callbacks, PatchGuard, HVCI, ETW, pool forensics, WHP API | [windows-kernel.md](windows-kernel.md) | anti-cheat, reverse-engineering |
| Claim validation, citation checks, detector evaluation, evidence conflicts | [research-rigor.md](research-rigor.md) | the matching domain skill |
| Adding resources, README format, link validation | [overview.md](overview.md) | (any) |

Also check `wiki/overviews/<topic>.md` for the matching primary skill topic before deep README/archive dives.

## Main Categories

All 27 top-level `##` sections in README.md:

1. **Game Engine**: Engines, source code, plugins (Unreal/Unity/Godot/Lumix), detectors
2. **Mathematics**: Linear algebra, physics libraries
3. **Renderer**: Software renderers, ray tracing
4. **3D Graphics**: 3D modeling and graphics resources
5. **AI**: Machine learning for games
6. **Image Codec**: Image processing libraries
7. **Wavefront Obj**: OBJ file parsers
8. **Task Scheduler**: Job/task scheduling systems
9. **Game Network**: Networking, KCP, JWT, geolocation
10. **PhysX SDK**: NVIDIA PhysX resources
11. **Game Develop**: Development guides, source code, MCP servers, AI agents
12. **Game Assets / Hot Patch / Testing / Tools / Manager / CI**: Supporting infrastructure
13. **DirectX**: Guides, hooks, tools, emulation, overlays
14. **OpenGL**: Guides, source, hooks
15. **Vulkan**: API, guides, hooks
16. **Cheat**: Offensive research (debugging, injection, hooking, DMA, overlays, driver comm, EFI, anti-forensics, game-specific)
17. **Anti Cheat**: Defensive research (protection, detection, callbacks, forensics, signature scanning)
18. **Some Tricks**: Ring0/Ring3/Linux/Android tricks and techniques
19. **Windows Security Features**: DSE, PatchGuard, VBS, HVCI, Secure Boot
20. **WSL / WSA**: Windows Subsystem for Linux/Android
21. **Windows / Linux / Android / IOS Emulator**: Platform emulators
22. **Game Boy / Nintendo Switch / Xbox / PlayStation**: Console emulators and research

## Contributing Guidelines

1. **Check for duplicates** before adding new resources
2. **Verify links** are working and point to original repos
3. **Add descriptions** that clearly explain the resource's purpose
4. **Place in correct category** based on primary functionality
5. **Follow existing format** for consistency

## Quality Criteria

- Resource should be actively maintained or historically significant
- Should provide unique value not covered by existing entries
- Prefer original repos over forks unless fork adds significant value
- Include language/platform tags when helpful (e.g., `[Rust]`, `[Unity]`)

## Research Rigor

For factual synthesis, detector assessment, or consequential security claims,
use [`research-rigor`](research-rigor.md) with the matching domain
skill.

- Treat README entries, generated descriptions, wiki pages, and archives as
  discovery/provenance layers, not automatic proof of their embedded claims.
- Verify citation identity and confirm the source text supports the exact claim.
- Separate observation, finding, attribution, and action.
- Do not import fixed thresholds or confidence values without representative
  calibration and validation for the target environment.
- Narrow the conclusion or report it as inconclusive when evidence is missing
  or contradictory.

## Scripts Usage

### Generate Table of Contents
```bash
python scripts/generate-toc.py
```

### Remove Fork References
```bash
python scripts/remove-forks.py
```

---
