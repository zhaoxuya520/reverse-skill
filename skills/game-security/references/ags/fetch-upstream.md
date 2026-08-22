# AGS fetch recipes (one home)

Upstream: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).

**Skill pin** (SSoT): [UPSTREAM.txt](UPSTREAM.txt) — currently `bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2`. Refresh the ten `ags/*.md` bodies with `../scripts/install-ags-refs.ps1`. README / wiki / archive below can use the same SHA for a frozen snapshot, or `main` for latest discovery.

reverse-skill **does not vendor** the ~4250-bullet README, `wiki/`, `archive/`, or `description/` trees. Those stay fetch-on-demand. All ten AGS agent skills already live under this directory (taxonomy kept; this footer was stripped from each skill so it is not copied ten times).

## Priority when answering about a specific repo

1. Local skill in this folder (technique / workflow).
2. Wiki entity/overview on upstream `main`.
3. Description (short English summary).
4. Archive (`code2prompt` snapshot) when implementation detail is required.
5. README entry as fallback.

## Wiki (compiled overviews)

```
https://raw.githubusercontent.com/gmh5225/awesome-game-security/bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2/wiki/index.md
https://raw.githubusercontent.com/gmh5225/awesome-game-security/bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2/wiki/AGENTS.md
https://raw.githubusercontent.com/gmh5225/awesome-game-security/bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2/wiki/overviews/<topic>.md

Latest (unpinned): replace the SHA with `refs/heads/main`.
```

`<topic>` matches the local file stem: `game-hacking`, `anti-cheat`, `dma-attack`, `game-engine`, `graphics-api`, `mobile-security`, `overview`, `reverse-engineering`, `windows-kernel`.

## README (link index)

```
https://raw.githubusercontent.com/gmh5225/awesome-game-security/refs/heads/main/README.md
```

Fetch a section when the user names a tool or repo that is not already in `../tools.md` / this folder. Do not copy the whole README into reverse-skill.

## Archive

```
https://raw.githubusercontent.com/gmh5225/awesome-game-security/refs/heads/main/archive/{owner}/{repo}.txt
```

Examples: `ufrisk/pcileech`, `000-aki-000/GameDebugMenu`. HTTP 404 means not archived; fall back to GitHub.

## Description

```
https://raw.githubusercontent.com/gmh5225/awesome-game-security/refs/heads/main/description/{owner}/{repo}/description_en.txt
```

## Evidence bound

README / wiki / archive / description are **discovery**. They are not L1 of a live sample. Convert claims with `research-rigor.md` and `ops/evidence-finding-path.md`.
