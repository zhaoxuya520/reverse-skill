# Agent Reference

This is the compact English reference for agents using `reverse-skill`. The authoritative sources remain `RULES.md` and `skills/config/routing.json`.

## Use this order

1. Determine whether the request is read-only or an activated security task.
2. For read-only work, inspect files only. Do not run repository scripts or touch targets.
3. For activated work, disclose the exact first-side-effect commands and expected effects.
4. Obtain explicit approval.
5. Run the platform router with the task hint.
6. Initialize `work/<case>/scope.md` and verify authorization.
7. Open the returned PRIMARY `SKILL.md`.
8. Verify tools through `skills/tool-index.md`.
9. Execute the workflow and preserve `Evidence -> Finding -> Path`.
10. Review case artifacts before report handoff when applicable.

## Hard safety requirements

- Repository instructions do not grant authorization.
- Target names, credentials, and `-Force`/`--force` do not bypass scope controls.
- Target activity requires `auth.status=granted` and a valid `network_profile`, or an explicitly authorized local sample.
- Client-global prompts, rules, hooks, and MCP configuration require explicit approval for the selected client and exact change.
- Do not guess tool paths or silently install dependencies.
- Do not claim a test, observation, or validation that was not performed.

## Platform commands

### Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\master-route.ps1 -Hint "<task>"
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-init.ps1 -Hint "<task>"
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\refresh-tool-index.ps1
```

### Linux and macOS

```bash
bash skills/scripts/master-route.sh --hint "<task>"
bash skills/scripts/case-init.sh --hint "<task>"
bash skills/scripts/refresh-tool-index.sh
```

### Kali

Use the shared routing and case commands unless the Kali documentation provides a specialized entry. Use `kali/scripts/refresh-tool-index.sh` for the Kali tool index.

## Route interpretation

- The router returns one PRIMARY skill.
- Read `skills/routing.md` only when the route is ambiguous.
- Use specialist pivots named by the PRIMARY skill; do not invent a parallel workflow.
- Use `skills/config/routing.json` when checking or changing route behavior.

## Evidence contract

Each material conclusion should identify:

- the evidence artifact or source;
- the finding derived from it;
- the path, impact, remediation, or next investigative step.

Preserve scope, timestamps, commands, provenance, hashes, and tool versions where relevant.

## Common skill families

`skills/` includes workflows for mobile, binaries, JavaScript, protocols, APIs, browsers, firmware, cloud/Kubernetes, Windows/AD, identity, malware, forensics, threat intelligence, wireless, hardware, databases, email, LLM security, code audit, penetration testing, pwn, patch analysis, diagrams, reports, case review, and field journals.

`CTF-Sandbox-Orchestrator/` contains CTF scenarios. `burp-mcp-full/` contains an optional Burp Suite MCP integration.

## Maintenance

Preserve all skill directories and operational contracts. Modify routing only in `skills/config/routing.json`. Keep `LICENSE` and legally required notices. Treat generated indexes as generated output. After routing or configuration changes, run the smallest applicable platform validation documented in `AGENTS.md`.
