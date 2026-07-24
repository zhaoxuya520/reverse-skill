# 通用 Scope 契约（任务启动硬门槛）

> **MUST**：任何安全/逆向/渗透任务在 **ACT 之前** 在用户项目或 `work/<case>/` 落地 `scope.md`。  
> 无 scope → 只允许读文档/路由，**禁止** 对目标主动扫描、Hook、利用。  
> 模板可复制；字段名保持英文键，便于脚本校验。

## 如何初始化

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-init.ps1 -Hint "<任务一句话>" -CaseName "my-case"
# 产出：work/<case>/scope.md 等
```

```bash
# Linux / macOS / Kali
bash skills/scripts/case-init.sh --hint "<任务一句话>" --case-name my-case

# 合法本地样本 / 公开 CTF：用 preset，避免 auth 卡死静态分析
bash skills/scripts/case-init.sh --hint "apk reverse" --preset offline-sample --sample ./app.apk
bash skills/scripts/case-init.sh --hint "ctf web" --preset ctf-public --target-url https://chal.example
```

## scope.md 完整模板

```markdown
# Case Scope

## meta
- case_id: {YYYYMMDD-short}
- created: {ISO-8601}
- operator: {name or local}
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
    offline = 无对外发包（纯静态/本地样本）
    lab_only = 仅 lab/VM IP
    authorized_target_only = 仅 in_scope 资产
- MUST NOT use unrestricted against production without written auth

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

## 路由挂钩（AI 必须执行）

```text
RULES / MASTER-ROUTING / SKILL:
  1) master-route → PRIMARY
  2) case-init 或手写 scope.md
  3) auth 未 granted → STOP，只允许补授权材料
  4) ready_for_act = true → 打开 PRIMARY SKILL.md → ACT
```

## network_profile 速查

| mode | 允许 | 禁止 |
|------|------|------|
| `offline` | 静态分析、本地文件、模拟 | 任意外连、公网 RPC |
| `lab_only` | lab/CTF 靶机网段 | 生产/未授权 IP |
| `authorized_target_only` | in_scope 列表 | 列表外资产 |
| `unrestricted_lab` | 隔离实验网（书面） | 互联网生产 |

## 特色

- 纯 Markdown，**无数据库**  
- 与 `tool-index` / bootstrap 正交：scope 管「能不能打」，tool-index 管「用什么打」
