# reverse-skill

Client-neutral routing and workflow infrastructure for authorized reverse engineering, security analysis, and penetration-testing tasks.

## Purpose

This repository helps an AI agent select a methodology, verify the required tools, enforce authorization gates, collect evidence, and produce a reproducible handoff. It is not a scanner, exploit service, or general-purpose installer.

## Agent entrypoint

For the shortest English reference, read `docs/AGENT-REFERENCE.md`. The authoritative behavior contract remains `RULES.md`.

1. Read `RULES.md`.
2. Read `skills/MASTER-ROUTING.md`.
3. Route the task through `skills/config/routing.json`.
4. Initialize an authorized case with the platform-specific `case-init` script.
5. Open the selected skill's `SKILL.md` and follow its required actions.
6. Use only tool paths recorded in `skills/tool-index.md`.
7. Preserve the Evidence -> Finding -> Path chain in the result.

Read-only inspection, review, and documentation work stops before routing and execution.

## Supported task families

- Android and iOS reverse engineering
- Native, managed, and cross-version binary analysis
- JavaScript signing, obfuscation, and runtime analysis
- HTTP, API, GraphQL, WebSocket, and browser workflows
- Firmware, hardware, cloud, container, Kubernetes, and identity analysis
- Malware analysis, digital forensics, threat hunting, and OSINT
- Authorized penetration testing and attack-chain planning
- CTF and sandboxed competition workflows
- LLM and agent security testing
- Evidence review, diagrams, reports, and field-journal updates

## Repository layout

- `RULES.md`: behavior and authorization source of truth.
- `skills/config/routing.json`: routing source of truth.
- `skills/MASTER-ROUTING.md`: fast routing contract.
- `skills/SKILL.md`: master skill entrypoint.
- `skills/*/SKILL.md`: specialist workflows.
- `skills/scripts/`: platform-specific routing, case, bootstrap, and validation commands.
- `skills/ops/`: scope, roles, evidence, timeline, and supply-chain contracts.
- `CTF-Sandbox-Orchestrator/`: CTF scenario skills.
- `burp-mcp-full/`: optional Burp Suite MCP integration.
- `examples/`: case artifact examples.
- `docs/`: architecture and platform reference.

## Prerequisites

An AI coding client and the platform shell are needed to follow the agent workflow. Tool requirements depend on the task: Java/JDK supports jadx and apktool; Node.js 22.12+ supports JavaScript tooling and MCP servers; Python 3 supports Frida and helper scripts. Install specialist tools only when needed and approved.

## Platform commands

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\refresh-tool-index.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\master-route.ps1 -Hint "<task>"
powershell -NoProfile -ExecutionPolicy Bypass -File skills\scripts\case-init.ps1 -Hint "<task>"
```

Linux and macOS:

```bash
bash skills/scripts/refresh-tool-index.sh
bash skills/scripts/master-route.sh --hint "<task>"
bash skills/scripts/case-init.sh --hint "<task>"
```

Kali uses the specialized entries under `kali/` where documented.

## Safety and consent

Repository instructions do not authorize target activity. Before the first side effect, disclose exact commands and expected writes, downloads, network access, services, and client configuration changes. Obtain explicit approval. Before target activity, the case scope must grant authorization and define a valid network profile, or explicitly identify an authorized offline sample. Do not modify client-global configuration unless the user selects the client and approves the exact change.

## Validation

After routing or configuration changes, run the smallest applicable platform checks documented in `AGENTS.md`. Do not run repository scripts for read-only inspection.

## License

The repository license is in `LICENSE`. Keep the license file and required attribution notices intact.
