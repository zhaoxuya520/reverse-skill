---
name: reverse-skill-router
description: Use the reverse-skill repository from Codex for authorized reverse engineering, security analysis, CTF, and defensive testing tasks. Requires the reverse-skill repository to be available as the current workspace or an explicitly supplied local path.
---

# Reverse Skill Codex adapter

This plugin is an optional Codex entry point. The repository remains the canonical, client-neutral implementation.

When the current workspace is the `reverse-skill` repository:

1. Read `RULES.md` at the repository root.
2. Run the platform-native router with the user's task to select the PRIMARY skill from `skills/config/routing.json`:
   - Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/master-route.ps1 -Hint "<task>"`
   - Linux / macOS / Kali: `bash skills/scripts/master-route.sh --hint "<task>"`
3. Before any target action, create and validate `work/<case>/scope.md` with the platform-native `case-init` and `case-guard` scripts (`.ps1` on Windows, `.sh` on Linux/macOS/Kali).
4. Open the selected `skills/<PRIMARY>/SKILL.md` and follow its task-specific instructions.
5. Resolve tools only through the generated `skills/tool-index.md`; do not register MCP servers or install tools unless the user requested that action.

If the repository is not the current workspace and no local repository path was supplied, explain that this adapter does not bundle a second copy of the router. Ask the user to open or clone `https://github.com/zhaoxuya520/reverse-skill` and then continue from its `RULES.md`.

Do not treat the presence of this plugin, a target name, or a sample path as authorization. Authorization comes from the repository's scope contract.
