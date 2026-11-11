# Scope Contract

> **MUST:** Before target activity in a security, reverse-engineering, or penetration-testing task, create `work/<case>/scope.md` in the user's analysis project.
> Without an authorized scope, only documentation and routing may be read; active scanning, hooking, and exploitation are prohibited.
> Copy the template as needed and preserve its English keys for automated validation. Before running repository scripts, obtain explicit approval for the disclosed commands and effects.

## Initialization

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-init.ps1 -Hint "<one-sentence task>" -CaseName "my-case"
# Default output: work/<case>/scope.md and related artifacts in the analysis project.
# When invoking from elsewhere, specify -ProjectRoot "C:\path\to\analysis-project".

# Authorized local offline sample: granted authorization + offline + explicit sample -> ready_for_act=true
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-init.ps1 `
  -Hint "offline apk" -CaseName "my-sample" -Preset offline-sample -Sample ".\app.apk"
```

Linux / macOS / Kali：

```bash
bash skills/scripts/case-init.sh --hint "<任务一句话>" --case-name "my-case"
# 默认产出：caller 当前分析项目的 work/<case>/scope.md 等
# 从其他目录调用时显式指定：--project-root "/path/to/analysis-project"

# 合法本地离线样本
bash skills/scripts/case-init.sh \
  --hint "offline apk" --case-name "my-sample" \
  --preset offline-sample --sample ./app.apk
```

`-PackageRoot` / `--package-root` remain compatibility parameters. Use `-ProjectRoot` / `--project-root` to identify the project that owns the case artifacts.

## Complete scope.md template

```markdown
# Case Scope

## meta
- case_id: {YYYYMMDD-short}
- created: {ISO-8601}
- operator: {name or local}
- project_root: {caller analysis project}
- primary_skill: {from master-route}
- lead_role: lead   # see ops/role-map.md
- specialist_roles: []  # e.g. cie, cpe, cre

## auth
- status: granted | pending | denied
- basis: written_contract | bug_bounty_scope | ctf_public | own_system | lab_only
- evidence_of_auth: {ticket/path or "CTF public" or "owner-operated"}
- MUST NOT proceed if status != granted

## in_scope
- assets: []          # hosts, domains, APK paths, binaries, URLs
- surfaces: []        # web, mobile, binary, network, api
- activities: []      # recon, reverse, exploit_validate, report

## out_of_scope
- assets: []
- activities: []      # e.g. DoS, phishing real users, data exfil

## network_profile
- mode: offline | lab_only | authorized_target_only | unrestricted_lab
- notes: |
    offline = no external packets; static analysis or local sample only
    lab_only = lab or VM IPs only
    authorized_target_only = in-scope assets only
- MUST NOT use unrestricted against production without written authorization

## deliverables
- report: true
- field_journal: true
- diagrams: true
- timeline: true

## constraints
- timebox: {}
- stealth: low | medium | high
- data_handling: anonymize | no_user_pii

## signoff
- ready_for_act: false
- checklist:
  - [ ] auth.status = granted
  - [ ] in_scope.assets non-empty OR offline sample path set
  - [ ] network_profile.mode chosen
  - [ ] out_of_scope reviewed
```

## Routing integration

```text
RULES / MASTER-ROUTING / SKILL:
  1) master-route -> PRIMARY
  2) Initialize the case with the platform-native case-init or write scope.md.
  3) If authorization is not granted, stop and obtain authorization evidence.
  4) When ready_for_act = true, open the PRIMARY SKILL.md and act.
```

`case-guard -Force` and `case-guard --force` are compatibility parameters. They must not bypass `auth.status`, a valid scope, the network profile, or `ready_for_act`.

## Network profiles

| Mode | Allowed | Prohibited |
|------|---------|------------|
| `offline` | Static analysis, local files, simulation | External connections and public RPC |
| `lab_only` | Authorized lab or CTF target networks | Production and unauthorized IP addresses |
| `authorized_target_only` | Listed in-scope assets | Assets outside the list |
| `unrestricted_lab` | Isolated lab network with written authorization | Internet production systems |

## Design

- Case artifacts use Markdown and require no database.
- Scope determines whether an action is allowed; the tool index and bootstrap determine which tools are available.
