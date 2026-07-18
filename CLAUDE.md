# CLAUDE.md

This repository is a **task skill router** for authorized reverse engineering, mobile/security analysis, and pentest workflows.

## On Any Task

`RULES.md` is the single source of truth for behavior chain and authorization.

Routing order:

1. `skills/MASTER-ROUTING.md` or `skills/scripts/master-route.ps1 -Hint "..."`
2. `skills/scripts/case-init.ps1` → `work/<case>/scope.md` (must grant auth before ACT)
3. `skills/routing.md` when ambiguous; roles in `skills/ops/role-map.md`
4. Open PRIMARY `SKILL.md` and execute ACTION REQUIRED
5. Timeline/workitems + Evidence→Finding→Path (`skills/ops/`)
6. `skills/tool-index.md` for real tool paths (never guess)
7. Missing tool → `skills/scripts/bootstrap-reverse.ps1` (manifest capabilities only)

**Identity**: lightweight skill router — see `skills/ops/IDENTITY.md` (not a Z3r0 platform).

## First-Run Setup

`skills/tool-index.md` is not in fresh clones. Generate it:

```bash
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/refresh-tool-index.ps1

# macOS / Linux
bash skills/scripts/refresh-tool-index.sh

# Kali
bash kali/scripts/refresh-tool-index.sh
```

Read `README_AI.md` for full bootstrap sequence.

## Coherence check

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/verify-routing-coherence.ps1
```
