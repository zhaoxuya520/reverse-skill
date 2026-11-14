# reverse-skill All-in-One Docker environment

Addresses issue **#129**: a ready-to-use container so agents and humans can run reverse-skill without hand-installing every CLI on the host.

This image is an **execution shell + package mount**, not a second routing core. Routing, case-init, and authorization contracts stay in `skills/` and `kali/`.

## Security / authorization (read first)

- Use only for **lawful** reverse engineering, CTF, and systems you own or are **explicitly authorized** to test.
- The container does **not** grant `auth.status=granted`. Initialize cases with `case-init` inside the container as usual.
- Do **not** mount the host Docker socket into this image.
- Commercial tools (IDA Pro, JEB, Burp Pro) are **not** baked in; install them on the host and point tool-index at licensed paths if needed.

## Quick start

From the repository root:

```bash
# Build
docker compose -f docker/docker-compose.yml build

# Interactive shell with repo mounted at /opt/reverse-skill
docker compose -f docker/docker-compose.yml run --rm reverse-skill

# Inside the container
bash skills/scripts/refresh-tool-index.sh   # generic Linux path
# or, when targeting the Kali capability set:
# bash kali/scripts/refresh-tool-index.sh
bash skills/scripts/master-route.sh --hint "apk reverse with jadx"
```

Plain Docker (no compose):

```bash
docker build -t reverse-skill:local -f docker/Dockerfile .
docker run --rm -it \
  -v "$PWD":/opt/reverse-skill \
  -v reverse-skill-work:/home/analyst/work \
  -w /opt/reverse-skill \
  reverse-skill:local
```

## What you get out of the box

| Layer | Contents |
|---|---|
| Base OS | `kalilinux/kali-rolling` |
| Runtimes | Python 3 + pipx, Node.js/npm, OpenJDK 17, git, jq |
| Apt analysis CLIs | binwalk, apktool, adb, radare2, seclists, nmap, sqlmap, hashcat, hydra, gobuster, ffuf |
| pipx tools | `frida-tools==14.10.4` (manifest pin) |
| Package source | This repo mounted at `/opt/reverse-skill` (live code, no stale bake) |
| Cases | Named volume `work/` for `work/<case>/` artifacts |
| Bootstrap | Optional `BOOTSTRAP=true` build-arg runs Kali tool-index refresh at image build |

**Not baked in** (licensed or GitHub-release only) — use in-repo bootstrap / manual install:

| Capability | Path |
|---|---|
| jadx | `kali/scripts/bootstrap-reverse.sh jadx` (GitHub release pin) |
| IDA Pro / idalib-mcp | manual license install; see `skills/ida-reverse/LOCAL-SETUP.md` |
| JEB Pro / Binary Ninja | manual license install |
| nuclei / agent-browser / MCP servers | bootstrap manifest or client registration |

```bash
bash kali/scripts/bootstrap-reverse.sh --list
bash kali/scripts/bootstrap-reverse.sh <capability>
```

## Layout

```text
/opt/reverse-skill/     # bind-mounted repository
/home/analyst/work/     # case workdirs (compose volume reverse-skill-work)
```

## Client AI agents

The image is **client-neutral**. Point Claude Code / Codex / Cursor / OpenCode at the mounted repo inside or outside the container. Do not bake client-global rule injection into the image; follow `README_AI.md` consent rules on the host client.

## Build options

| Build-arg | Default | Effect |
|---|---|---|
| `BOOTSTRAP` | `false` | `true` runs `kali/scripts/refresh-tool-index.sh` during build (slow; network required) |

```bash
docker build -f docker/Dockerfile --build-arg BOOTSTRAP=true -t reverse-skill:local .
```

## Verification

```bash
# Syntax / link guards from repo root (no Docker required for these)
bash skills/scripts/test-bash-workflow.sh
bash skills/scripts/test-routing.sh
python3 skills/scripts/verify-doc-links.py

# Container smoke
docker compose -f docker/docker-compose.yml config
docker compose -f docker/docker-compose.yml run --rm reverse-skill \
  bash -lc 'test -d /opt/reverse-skill/skills && test -d /opt/reverse-skill/kali && echo DOCKER_LAYOUT_OK'
```

## Non-goals

- Not a multi-GB “every binary compiled from source” appliance.
- Not a bypass for supply-chain pins in `skills/scripts/bootstrap-manifest.json`.
- Not a hosted C2 / attack platform. Scope stays the reverse-skill router contract.

Related docs: [kali/README-kali.md](../kali/README-kali.md) · [docs/platforms/linux.md](../docs/platforms/linux.md) · [AGENTS.md](../AGENTS.md)
