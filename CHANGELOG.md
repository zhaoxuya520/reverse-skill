# Changelog

This file records only repository-level behavior changes relevant to agents. Detailed history belongs in Git.

## Current maintenance contract

- `RULES.md` defines behavior, consent, and authorization gates.
- `skills/config/routing.json` is the only routing source of truth.
- `skills/MASTER-ROUTING.md` documents the operational fast path.
- `skills/tool-index.md` is generated local state and is not committed.
- Specialist skills must retain frontmatter, `ACTION REQUIRED`, scope controls, and evidence handoff requirements.
- Core documentation is English and optimized for agent discovery and execution.

## Compatibility

Legacy language-specific entrypoints remain as compatibility paths. The maintained source is the English documentation linked from `README.md` and `docs/AGENT-REFERENCE.md`.

## Version

See `VERSION` for the package version. Use Git history for prior releases and individual change details.
