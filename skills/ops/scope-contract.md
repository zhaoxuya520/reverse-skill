# Scope 契约（执行硬门槛）

任何主动安全、逆向或网络操作都必须先通过当前用户提供的 `scope.json`。`scope.json` 是唯一事实源；`scope.md` 仅由 `case-init.ps1` 从 JSON 派生，不能通过手工编辑授权。

## 初始化

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-init.ps1 -Hint "<任务一句话>" -CaseName "my-case"
# 默认产出 work/<case>/scope.json（draft）和兼容的 scope.md
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-init.ps1 -ScopeFile .\approved-scope.json -CaseName "my-case"
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-guard.ps1 -CaseRoot work\my-case
```

旧的 `-AuthGranted`、`-AuthStatus`、`-ReadyForAct` 和 `case-guard.ps1 -Force` 参数仅为兼容调用方保留；它们不能创建授权、修改策略或绕过执行门。

## scope.json 最小格式

```json
{
  "schemaVersion": "1",
  "scopeId": "approval-2026-001",
  "status": "granted",
  "approvalId": "ticket-123",
  "issuedAt": "2026-07-19T00:00:00Z",
  "expiresAt": "2026-07-20T00:00:00Z",
  "targets": [
    {
      "type": "network",
      "scheme": "https",
      "host": "app.example.test",
      "port": 443,
      "pathPrefixes": ["/lab"]
    }
  ],
  "allowedActions": ["passive.read", "request.send"],
  "notes": "User-provided approval record"
}
```

Schema: `skills/ops/scope.schema.json`.

Rules:

- `schemaVersion`, `scopeId`, `status`, `approvalId`, `issuedAt`, `expiresAt`, `targets`, and `allowedActions` are required.
- A granted document requires a non-placeholder approval ID, at least one target, at least one action, and a future expiry.
- Network targets match exact scheme, host, port, and path-prefix boundaries. `*`, `?`, blank hosts, and implicit wildcard domains are rejected.
- Local file targets match one normalized exact path. Redirects and follow-up targets must be checked again; leaving the declared target is denied.
- Missing, malformed, expired, denied, wildcard, or out-of-scope documents fail closed.

## Capability policy

The enforced policy labels operations with `readOnly`, `network`, `credentials`, `destructive`, `requiresScope`, and `requiresConfirmation`. Reserved fields are `filesystemRead`, `filesystemWrite`, `deviceControl`, and `sensitiveOutput`.

`passive.read` is the default authenticated read-only capability. Requests, scans, replay, Intruder, WebSocket sends, cookie writes, configuration writes, project writes, and similar active operations require a valid scope, an exact target/action match, and explicit confirmation. Policy failures return `blocked` or `confirmation_required`; Markdown, journal text, and `-Force` cannot change the result.

## out_of_scope

- assets: []
- activities: [dos, phishing_real_users, unrestricted_exfil]

## deliverables

- report: true
- field_journal: true
- diagrams: true
- timeline: true

## Derived scope.md compatibility view

The generated Markdown retains the legacy sections and keys used by older tooling:

```markdown
## auth
- status: granted | draft | denied | expired
- source_of_truth: scope.json
- scope_id: <scopeId>
- approval_id: <approvalId>
- scope.md is derived and cannot grant authorization

## in_scope
- assets: []

## network_profile
- mode: offline | lab_only | authorized_target_only | unrestricted_lab

## signoff
- ready_for_act: false
```

Consumers must read and validate `scope.json`; the compatibility view is informational only.

## Routing hook

1. Run `master-route.ps1` or read the primary route.
2. Run `case-init.ps1` to create a draft or import a user-provided `scope.json`.
3. Run `case-guard.ps1`; a non-zero result means stop active execution.
4. Before every active MCP/script call, apply capability policy and exact target matching.
5. Keep timeline/workitems and sanitized evidence under the case directory.

## Network profile quick reference

| mode | allowed | denied |
|------|---------|--------|
| `offline` | local files, static analysis, simulation | external network |
| `lab_only` | explicitly declared lab/VM targets | production or undeclared IPs |
| `authorized_target_only` | exact `scope.json` targets | everything outside the document |
| `unrestricted_lab` | isolated lab with explicit approval | internet production |

Journal, reports, and examples must not be used to expand this table or infer authorization.
