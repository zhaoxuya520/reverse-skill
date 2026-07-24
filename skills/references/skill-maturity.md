# Skill Maturity Map

> **Purpose:** Be honest about depth. reverse-skill prefers **deep skills + routing** over hundreds of micro-skills.
> Scaffold modules stay routable, but are labeled so agents and humans do not treat them as full playbooks.
>
> Counts: core=19, extended=7, experimental=13 · policy 2026-07-24

## Levels

| Level | Meaning | Agent duty |
|-------|---------|------------|
| **core** | Production-depth: multi-file and/or scripts, battle-tested entry | Follow full workflow; prefer as PRIMARY when keywords match |
| **extended** | Usable playbook; may lack automation scripts | OK as PRIMARY; expect more manual tool work |
| **experimental** | Scaffold / thin shell | Announce maturity; prefer deeper sibling when overlapping; extend before production reliance |

### Classification heuristics (maintainers)

```
if scripts >= 1 or files >= 4 or SKILL.md lines >= 180 → core
elif lines >= 90 or files >= 3 → extended
else → experimental
# Manual promotions allowed for important PRIMARY paths (e.g. ghidra-reverse, windows-ad).
```

## core

| Skill | lines | files | scripts |
|-------|------:|------:|--------:|
| `api-security/` | 188 | 3 | 0 |
| `apk-reverse/` | 399 | 13 | 7 |
| `attack-chain/` | 656 | 4 | 0 |
| `binary-diff/` | 318 | 2 | 0 |
| `browser-automation/` | 246 | 3 | 1 |
| `diagram-generator/` | 192 | 6 | 2 |
| `dotnet-reverse/` | 196 | 4 | 0 |
| `edr-bypass-re/` | 238 | 4 | 0 |
| `firmware-pentest/` | 365 | 4 | 0 |
| `ida-reverse/` | 356 | 4 | 2 |
| `js-reverse/` | 216 | 13 | 0 |
| `llm-security/` | 145 | 5 | 0 |
| `malware-analysis/` | 231 | 4 | 0 |
| `mobile-reverse/` | 205 | 4 | 0 |
| `patch-diff-exploit/` | 264 | 4 | 0 |
| `pentest-tools/` | 305 | 114 | 0 |
| `pwn-chain/` | 196 | 4 | 0 |
| `radare2/` | 416 | 4 | 2 |
| `reverse-engineering/` | 216 | 24 | 0 |

## extended

| Skill | lines | files | scripts |
|-------|------:|------:|--------:|
| `cloud-k8s/` | 103 | 2 | 0 |
| `docs-generator/` | 178 | 3 | 0 |
| `ghidra-reverse/` | 91 | 2 | 0 |
| `ot-ics/` | 96 | 2 | 0 |
| `protocol-reverse/` | 101 | 2 | 0 |
| `supply-chain-security/` | 177 | 3 | 0 |
| `windows-ad/` | 88 | 2 | 0 |

## experimental

| Skill | lines | files | scripts | Prefer instead / notes |
|-------|------:|------:|--------:|------------------------|
| `browser-extension-reverse/` | 77 | 2 | 0 | web JS → `js-reverse/` |
| `code-audit/` | 85 | 2 | 0 | runtime web → `pentest-tools/`; mobile → `mobile-reverse/` |
| `database-security/` | 59 | 2 | 0 | pair with `pentest-tools/` / `code-audit/` |
| `digital-forensics/` | 86 | 2 | 0 | malware → `malware-analysis/`; network → `protocol-reverse/` |
| `email-security/` | 58 | 2 | 0 | pair with `pentest-tools/` / journal phishing cases |
| `go-rust-reverse/` | 74 | 2 | 0 | general RE → `reverse-engineering/` / `ida-reverse/` / `ghidra-reverse/` |
| `hardware-security/` | 58 | 2 | 0 | hand off to `firmware-pentest/` after interface triage |
| `identity-federation/` | 59 | 2 | 0 | JWT-only API → `api-security/` |
| `macos-reverse/` | 77 | 2 | 0 | iOS → `mobile-reverse/`; binary → IDA/r2/Ghidra |
| `radio-sdr/` | 54 | 2 | 0 | `wifi-wireless/` for Wi-Fi; RF lab-only |
| `thick-client/` | 83 | 2 | 0 | desktop automation → `browser-automation/`; binary → RE tools |
| `threat-hunting/` | 86 | 2 | 0 | malware → `malware-analysis/`; detection content is scaffold |
| `wifi-wireless/` | 58 | 2 | 0 | lab rules first; no unauthorized RF |

## Agent rules (MUST)

1. When PRIMARY skill is **experimental**, say so in one line before ACT.
2. Do **not** invent missing tools/scripts for experimental skills; use tool-index + bootstrap only for real tools.
3. Prefer promoting an experimental skill (references, scripts, field-journal) over adding another thin directory.
4. Routing still lists experimental skills — maturity is honesty, not deletion.
5. New skills default to **experimental** until they meet extended/core heuristics (see CONTRIBUTING).

## Related

- Domain map: `domain-coverage-map.md`
- Community contrast: `community-security-skills.md`
- Identity: `../ops/IDENTITY.md`
