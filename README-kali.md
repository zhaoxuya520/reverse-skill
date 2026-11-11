# Kali Linux Entry

This file is a short entrypoint; use [kali/README-kali.md](kali/README-kali.md) for the full Kali instructions.

## Agent workflow

1. Identify the package root containing `README.md` and `skills/`.
2. Read `kali/README-kali.md` and `kali/RULES-kali.md`, subject to `RULES.md` and its consent gates.
3. If activation and the disclosed command are approved, refresh the Kali tool index:

   ```bash
   bash kali/scripts/refresh-tool-index.sh
   ```

4. Use the shared routing contract in `skills/MASTER-ROUTING.md` and the scope gate in `skills/ops/`.
5. Report the configuration result and continue with the authorized task.

Read-only requests must not execute repository scripts. Obtain explicit approval before first side effects and before client-global changes.

## Paths

| Purpose | Location |
|---|---|
| Shared skills, routing, and operational contracts | `skills/`, `RULES.md` |
| Kali scripts and manifest | `kali/scripts/` |
| Kali details | [kali/README-kali.md](kali/README-kali.md) |
| General agent bootstrap | [README_AI.md](README_AI.md) |
