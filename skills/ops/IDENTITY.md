# reverse-skill identity

This file defines the package boundary. `reverse-skill` adopts useful evidence, scope, role, and timeline concepts without becoming a platform runtime.

## What this package is

| Dimension | Definition |
|---|---|
| Form | Client-neutral skill router, methodology library, and tool bootstrap contract. |
| Entry | `RULES.md` -> `MASTER-ROUTING.md` / platform router -> specialist skill. |
| Tool source | `tool-index.md` and `bootstrap-manifest.json`; never guess local paths. |
| Learning | Sanitized reusable lessons in `field-journal/`. |
| Output | Markdown reports and a local `work/<case>/` evidence directory. |
| Deployment | Clone the repository; no mandatory database, UI, container pool, or hosted service. |

## What this package is not

It is not a React operations console, FastAPI control plane, PostgreSQL evidence store, LightRAG service, Docker host pool, VNC controller, or multi-agent runtime. It provides role-to-skill mapping and handoff contracts instead.

## Core concepts

- Authorization and project boundaries: `ops/scope-contract.md` and each case `scope.md`.
- Traceability: `ops/evidence-finding-path.md` and report templates.
- Specialist delegation: `ops/role-map.md`.
- Replayability: append-only case timelines and work items.
- Tool profiles: `ops/sandbox-profile.md` and the bootstrap manifest.
- Outbound control: `network_profile` values such as `offline`, `lab`, and `authorized`.

## Required characteristics

1. Three-axis routing: target type, user intent, and toolchain.
2. On-demand tool bootstrap across Windows, Kali, Linux, and macOS.
3. Optional MCP integrations for tools such as IDA, Burp, browser hooks, and traffic analyzers.
4. Sanitized field-journal reuse.
5. Explicit action-required steps, completion checks, and no false claims of completion.

## Boundary with external platforms

External platforms may consume these skills through adapters. The core remains standalone, client-neutral, and usable without those platforms. Do not add large external skill libraries as submodules. Maintain `references/community-security-skills.md` as a curated index and use `domain-coverage-map.md` to evaluate coverage. External skill installation must follow `ops/skill-supply-chain.md`, use curated sources, and receive explicit approval.
