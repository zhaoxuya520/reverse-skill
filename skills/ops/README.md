# Operational contracts

This directory contains the operational contracts shared by all specialist skills.

| File | Purpose |
|---|---|
| [IDENTITY.md](IDENTITY.md) | Package boundary and identity. |
| [scope-contract.md](scope-contract.md) | Case scope, authorization, and network profile. |
| [evidence-finding-path.md](evidence-finding-path.md) | Evidence traceability and finding promotion. |
| [role-map.md](role-map.md) | Lead/specialist roles and handoff. |
| [timeline-workitem.md](timeline-workitem.md) | Timeline and work-item coverage. |
| [sandbox-profile.md](sandbox-profile.md) | Tool and isolation profiles. |
| [skill-supply-chain.md](skill-supply-chain.md) | External skill and MCP supply-chain controls. |
| [case-review](../case-review/) | Evidence graph review and report handoff. |

## Related references

- `../references/community-security-skills.md`: curated external skill index.
- `../references/domain-coverage-map.md`: package coverage map.
- `../attack-chain/references/lifecycle-checklist.md`: attack-chain phase gates.
- `../reverse-engineering/references/re-agent-workflow.md`: reverse-engineering phases.
- `../pentest-tools/references/recon-pipeline.md`: authorized reconnaissance and evidence gates.

## Commands

- Case initialization: `../scripts/case-init.ps1` or `../scripts/case-init.sh`.
- Routing coherence: `../scripts/verify-routing-coherence.ps1`.
- Read-only evidence review: `../case-review/scripts/review_case.py`.

Run commands only after the activation and consent gates in `RULES.md` are satisfied.
