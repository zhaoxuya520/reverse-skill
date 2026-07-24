# reverse-skill · PRIMARY Path Result Card

> One sentence in → correct skill + ready case directory out.

| Field | Value |
|-------|-------|
| generated_at | `2026-07-24T20:28:18+0800` |
| demo script | `skills/scripts/demo-primary-path.sh` |
| route samples | 5 |
| route self-check failures | 0 |
| offline case | `demo-offline-apk` |
| case-guard exit | `0` (0=ready) |

## What you get in 3 minutes

1. **PRIMARY route** for each sample hint → `routes/*/route-scope.md`
2. **Case workspace** with `scope.md` / `timeline.md` / `workitems.md`
3. **Auth preset** `offline-sample` → `ready_for_act=true` without fighting the gate

## Live matrix

See [route-matrix.md](route-matrix.md).

## Offline case snapshot

```markdown
# Case Scope

## meta
- case_id: demo-offline-apk
- created: 2026-07-24T20:28:19+08:00
- operator: local
- primary_skill: apk-reverse/SKILL.md
- primary_id: R1
- lead_role: lead
- specialist_roles: []
- hint: local offline apk static reverse sample
- preset: offline-sample

## auth
- status: granted
- basis: own_system
- evidence_of_auth: preset:offline-sample (owner-operated local file)
- MUST NOT proceed if status != granted

## in_scope
- assets:
  - /tmp/luban-inspect/reverse-skill/examples/primary-path-demo/fixtures/sample.apk
- surfaces: []
- activities: []

## out_of_scope
- assets: []
- activities: [dos, phishing_real_users, unrestricted_exfil]

## network_profile
- mode: offline
- notes: |
    offline | lab_only | authorized_target_only | unrestricted_lab
    Change mode only after auth.status = granted.
    Presets: offline-sample | ctf-public | own-system

## deliverables
- report: true
- field_journal: true
- diagrams: true
```

## Reproduce

```bash
git clone https://github.com/zhaoxuya520/reverse-skill.git
cd reverse-skill
bash skills/scripts/demo-primary-path.sh
open examples/primary-path-demo/RESULT-CARD.md
```

## Not claimed

- This demo does **not** decompile a real app or attack a host.
- It proves the **router + ops gate** product surface end-to-end on Linux/macOS.
- Domain ACT still requires tools from `tool-index` and authorized scope.
