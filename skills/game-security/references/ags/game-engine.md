> **reverse-skill adapter** - AGS `game-engine-resources` under PRIMARY `game-security/` (routing **R43**). Not a second PRIMARY.
>
> **Pin:** `gmh5225/awesome-game-security@bf403cf9e37f` (`bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2`). Refresh: `scripts/install-ags-refs.ps1`.
> **Gates that already exist (do not add more here):** reverse-skill `case-init` / `auth.status=granted` before ACT; AGS Ethical Use / authorized-testing text in this file if the upstream skill has it.
> **Handoff:** RS dump-chain quick table (not this skill) -> ``../engines.md`` + ``../il2cpp-dump.md``. Mono -> ``dotnet-reverse/``. Native -> ``ida-reverse/`` / ``ghidra-reverse/``.
> **Fetch:** [fetch-upstream.md](fetch-upstream.md). Wiki: `wiki/overviews/game-engine.md`.
> **Distill:** duplicated Data Source footer only. Taxonomy and workflows kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: game-engine-resources
description: Guide for game-engine internals, source trees, plugins, and engine-specific security research. Use this skill when researching Unreal, Unity, Source, Godot, custom engines, engine detectors, engine explorers, or engine protection patterns relevant to modding, reverse engineering, and anti-cheat.
---

# Game Engine Development Resources

## Overview

This skill covers game engine development resources from the awesome-game-security collection, including both commercial (Unreal, Unity) and open-source engines.

Engine globals, object layouts, metadata formats, and helper APIs vary by engine
branch, build configuration, platform, and game modifications. Verify the exact
version and binary artifacts; use
[`research-rigor`](research-rigor.md) before generalizing signatures or
offsets.

## README Coverage

- `Game Engine > Guide`
- `Game Engine > Source`
- `Game Engine Plugins:Unreal`
- `Game Engine Plugins:Unity`
- `Game Engine Plugins:Godot`
- `Game Engine Plugins:Lumix`
- `Game Engine Detector`
- `Cheat > SDK CodeGen`
- `Cheat > Game Engine Explorer:Unreal`
- `Cheat > Game Engine Explorer:Unity`
- `Cheat > Game Engine Explorer:Source`
- `Anti Cheat > Game Engine Protection:Unreal`
- `Anti Cheat > Game Engine Protection:Unity`
- `Anti Cheat > Game Engine Protection:Source`
- `Game Develop > MCP server`

## Major Engine Categories

### Unreal Engine
- Official documentation and forums
- Source code access (requires Epic Games account)
- Community guides and tutorials
- Plugin development references

### Unity Engine
- C# reference source code
- Asset store resources
- Unity-specific design patterns
- VR/AR development guides

### Open Source Engines
- **Godot**: Free and open-source, supports GDScript and C#
- **Cocos2d-x**: Cross-platform 2D game framework
- **CRYENGINE**: High-fidelity graphics engine
- **Source Engine**: Valve's game engine (various versions)

### Custom/Educational Engines
- Hazel Engine (TheCherno's educational series)
- Bevy (Rust-based data-driven engine)
- Fyrox (Rust game engine)

## Key Technical Areas

### Rendering
- Software renderers for learning
- Ray tracing implementations
- Shader development tutorials
- Post-processing effects

### Mathematics
- Linear algebra libraries (GLM, DirectXMath)
- Physics simulation (PhysX, Bullet)
- Collision detection algorithms

### Networking
- Client-server architectures
- KCP reliable UDP protocol
- Steam networking integration
- MMORPG server implementations

## Resource Categories

### Documentation & Guides
```markdown
- Learning resources and tutorials
- Architecture documentation
- Best practices and style guides
```

### Source Code
```markdown
- Complete engine implementations
- Subsystem references (renderer, physics, audio)
- Plugin and extension examples
```

### Plugins & Extensions
```markdown
- ImGui integration for debug UIs
- Scripting language bindings (Lua, .NET)
- Editor tool plugins
```

## Engine Selection Criteria

When researching engines for security analysis or development:

1. **Target Platform**: PC, mobile, console compatibility
2. **Source Access**: Open source vs proprietary
3. **Language**: C++, C#, Rust, or scripting
4. **Graphics API**: DirectX, OpenGL, Vulkan, Metal
5. **Community**: Documentation and support quality

## SDK Generation Workflows

### Unreal Engine (Dumper-7)
```
1. Identify UE version from binary signatures
2. Inject Dumper-7 into running game process
3. SDK output: C++ headers with UObject hierarchy
4. Key structures: UObject, FName, UClass, UFunction, UProperty
5. Generated SDK enables: property access, function calls, blueprint hooks
6. Alternative tools: UnrealDumper, UE4SS (live scripting + SDK dump)
```

### Unity (IL2CPPDumper)
```
1. Locate global-metadata.dat + GameAssembly.dll (or libil2cpp.so)
2. Run IL2CPPDumper → outputs: dump.cs, il2cpp.h, script.json
3. Load generated headers into IDA/Ghidra for symbol recovery
4. Key structures: Il2CppClass, MethodInfo, FieldInfo, Il2CppType
5. For Mono builds: directly decompile Assembly-CSharp.dll with dnSpy
```

### Source Engine (NetVar Parsing)
```
1. Walk ClientClass linked list from CHLClient
2. For each class, enumerate RecvTable → RecvProp entries
3. Build offset map: class name → property name → offset
4. Example: CCSPlayer → m_iHealth → 0x100
5. Tools: hazedumper, source2gen (Source 2)
```

## Engine Object Models

### Unreal Engine
```
Core hierarchy:
  UObject → UField → UStruct → UClass
  UObject → AActor → APawn → ACharacter → APlayerCharacter

Key globals:
  GUObjectArray / GObjects: registered UObject slots; lifecycle and reachability
    filtering are still required
  GNames / FNamePool: name storage; symbol and structure names vary by UE version
  GWorld (UWorld*): current world context
  GEngine (UEngine*): engine singleton

Memory layout:
  Common UObject fields include VTable, flags, internal index, class, name, and
  outer pointers; order, packing, and presence are build-specific
  Reflected property offsets come from the version-specific class metadata
```

### Unity (IL2CPP)
```
Core structures:
  Il2CppDomain → Il2CppAssembly → Il2CppImage → Il2CppClass
  Il2CppClass: fields, methods, vtable, static_fields pointer

Key patterns:
  il2cpp_domain_get() → domain singleton
  il2cpp_class_from_name() → class lookup by namespace + name
  il2cpp_runtime_invoke() → call managed methods from native

Metadata:
  global-metadata.dat contains string pool, type definitions, method signatures
  Encrypted metadata in some protected games (requires custom decryptor)
```

### Source Engine
```
Core systems:
  Entity list: IClientEntityList → GetClientEntity(index)
  ConVar system: ICvar → FindVar("sv_cheats")
  NetVars: RecvTable hierarchy for network-replicated properties

Key interfaces (accessed via CreateInterface export):
  IVEngineClient, IClientEntityList, IEngineTrace
  ISurface, IPanel (for overlay rendering in Source)
```

## MCP Servers for Game Development

```
The README's > MCP server subcategory includes servers relevant
to game engine workflows:

- Unreal Engine MCP: AI agent controls UE editor (spawn actors, modify properties, blueprints)
- Unity MCP: AI agent interacts with Unity editor and C# scripting
- Godot MCP: AI agent controls Godot editor and GDScript

These complement the RE-focused MCP tools (see reverse-engineering skill)
by enabling AI-assisted game development and rapid prototyping.
```

## Security Research Focus

For game security research, understanding engine internals helps with:
- Memory layout and object structures
- Rendering pipeline hooks
- Network protocol analysis
- Anti-cheat integration points

---
