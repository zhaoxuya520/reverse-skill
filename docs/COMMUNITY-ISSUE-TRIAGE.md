# Community Issue Triage

This document records which community concerns can be addressed in-repository and which require a maintainer or platform owner.

| Issue | Assessment | Repository action |
|---|---|---|
| #21, #86 | AI safety refusal for a particular target | Added authorization-first and defensive-use guidance; this cannot override a client safety policy. |
| #44, #61 | Installation and usage questions | Added `QUICKSTART_zh.md` and linked it from both READMEs. |
| #47 | Codex/plugin integration request | The project remains client-neutral; client-specific plugin work needs an agreed integration contract. |
| #51 | Prefer uv over pip | Added correct guidance for `uv tool install` and `uv pip` without unsafe mechanical replacement. Bootstrap still uses pinned pipx. |
| #58, #60 | Low-information reports | Need a reproducible sample, environment, and exact error before a code fix is possible. |
| #62 | iOS workflow evidence threshold | Requires a maintainer decision about workflow policy and test data rather than a blind code change. |
| #63 | Account-ban concern | Depends on third-party platform policy; users should follow applicable terms. |
| #80 | radare2-skills contribution discussion | Contribution instructions are available in `skills/CONTRIBUTING.md`; maintainers must decide scope and ownership. |
| #82 | ZIP download security warning | Covered by `docs/UV-AND-DOWNLOAD-SECURITY.md` plus the quick-start archive checklist. |
| #83 | Codex synchronization failure | Added a diagnostic checklist; a client version and reproducible case are still required for a client-side fix. |
| #77, #87, #95, #97, #99, #100, #101, #103, #104 | Feature proposals or existing work items | These require separate design review and should not be silently duplicated by a documentation PR. |

A Pull Request should close only issues that it actually resolves. Discussion items, third-party platform behavior, and reports without reproduction details should remain open for maintainer review.
