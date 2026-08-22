# Community Issue Triage

Which community concerns can be addressed in-repository, and which still need a maintainer or platform owner.

A pull request should close only issues it actually resolves. Discussion items, third-party platform behavior, and reports without reproduction details stay open.

| Issue | Assessment | Repository action |
|---|---|---|
| #21, #86 | AI safety refusal for a particular target | Authorization-first guidance added; this cannot override a client safety policy. |
| #44, #61 | Installation and usage questions | `docs/QUICKSTART_zh.md` linked from both READMEs. |
| #47 | Codex/plugin integration request | The project remains client-neutral; client-specific plugin work needs an agreed integration contract. |
| #51 | Prefer uv over pip | Documented `uv tool install` vs `uv pip`. Bootstrap still uses pinned `pipx` until maintainers choose a migration scope. **Do not close.** |
| #58, #60 | Low-information reports | Need a reproducible sample, environment, and exact error. |
| #62 | iOS workflow evidence threshold | Maintainer decision about workflow policy and test data. |
| #63 | Account-ban concern | Third-party platform policy; users follow applicable terms. |
| #80 | radare2-skills contribution discussion | See `skills/CONTRIBUTING.md`; maintainers decide scope and ownership. |
| #82 | ZIP download security warning | Source verification, checksum, archive inspection, and scanning guidance added. |
| #83 | Codex synchronization failure | Diagnostic checklist added; still needs a client version and reproducible case. |
| #87 | Non-PE cookbook expansion | Landed as U–AV + AW–DN in `nonpe-format-cookbook.md`. |
