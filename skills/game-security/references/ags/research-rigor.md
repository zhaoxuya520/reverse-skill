> **reverse-skill adapter** - AGS `game-security-research-rigor` under PRIMARY `game-security/` (routing **R43**). Not a second PRIMARY.
>
> **Gates that already exist (do not add more here):** reverse-skill `case-init` / `auth.status=granted` before ACT; AGS Ethical Use / authorized-testing text in this file if the upstream skill has it.
> **Handoff:** map Observation/Finding/Attribution/Decision onto ``ops/evidence-finding-path.md`` (Evidence->Finding->Path).
> **Fetch:** [fetch-upstream.md](fetch-upstream.md). Wiki: `wiki/overviews/overview.md`.
> **Distill:** duplicated Data Source footer only. Taxonomy and workflows kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).
---
name: game-security-research-rigor
description: Guide for evidence-grounded game-security research, citation verification, uncertainty, reproducible analysis, and detector evaluation. Use when validating technical claims, synthesizing README or wiki resources, comparing security techniques, assessing telemetry or models, or deciding whether evidence supports an anti-cheat conclusion.
---

# Game Security Research Rigor

## Purpose

Use this skill with the relevant domain skill. Its job is to keep conclusions
no stronger than the evidence and to make factual, empirical, and operational
claims independently checkable.

## Separate the reasoning layers

Never collapse these layers:

1. **Observation** — the raw artifact or measurement.
2. **Finding** — a rule, baseline, or invariant was violated.
3. **Attribution** — a hypothesis about cause or actor intent.
4. **Decision** — a risk-based response to the supported conclusion.

An anomaly, hash mismatch, or invariant violation establishes a finding only
under the stated measurement assumptions. It does not by itself prove cheating,
malicious intent, or the responsible actor.

## Research workflow

1. **Scope the question**
   - Identify object, platform, game/build, mode, timeframe, trust boundaries,
     available evidence, and the consequence of a wrong conclusion.
   - State what is outside scope.
2. **Acquire evidence**
   - Prefer primary artifacts for version-specific behavior: source code,
     specifications, raw telemetry, traces, binaries, and official changelogs.
   - Use peer-reviewed or independently reproduced work for generalization.
   - Treat vendor posts and community reports as claim-bearing sources, not
     automatic proof.
3. **Verify every citation**
   - Confirm the URL or DOI resolves.
   - Match title, authors, venue, and year to authoritative metadata.
   - Read enough of the source to confirm it supports the exact claim.
   - A venue name, search result, bibliography entry, or source count is not
     evidence by itself.
4. **Build a claim ledger**
   - Record claim, supporting artifact, source/version/date, method, assumptions,
     counterevidence, uncertainty, and remaining verification work.
   - Label statements as observed, reproduced, sourced, inferred, or unknown.
5. **Test alternatives**
   - Look for benign explanations, measurement error, stale schemas, version
     drift, selection bias, and contradictory evidence.
6. **Reproduce and validate**
   - Preserve inputs, transforms, tool/model versions, configuration, timestamps,
     and commands needed to reproduce the result.
   - Re-run against negative controls and changed conditions.
7. **Conclude narrowly**
   - Use one of: supported, suspicious, no signal observed within scope, or
     inconclusive.
   - Never turn missing data into a clean result.

## Detector and telemetry evaluation

- Do not copy universal thresholds across games or populations. Calibrate for
  the title, build, mode, rank, input method, platform, region, and telemetry
  pipeline where the detector will operate.
- Split evaluation data by player/session and, where appropriate, by time.
  Prevent the same player or near-duplicate session from leaking across train,
  calibration, and test sets.
- Include representative legitimate users, top-skill players, accessibility
  tools, unusual hardware, and controlled or independently adjudicated positive
  cases.
- Report prevalence and a confusion matrix with uncertainty: false-positive
  rate, false-negative rate, precision/positive predictive value, recall, and
  calibration. Use PR-oriented metrics for rare events.
- Evaluate the deployed decision volume, not only per-event error rates. A small
  per-test false-positive rate can still create many false alerts when applied
  repeatedly across large populations, time windows, features, or models.
  Report expected alert and review counts; control repeated-testing and
  false-discovery effects where applicable.
- A score in `[0, 1]` is not a probability or calibrated confidence unless this
  interpretation has been validated on held-out representative data.
- Derive minimum sample requirements empirically. Round numbers such as 40 or 50
  samples are not general stability guarantees.
- Model signal dependence. Taking the maximum score or counting several
  correlated signals does not guarantee corroboration or a lower joint
  false-positive rate.
- Revalidate after patches, balance changes, input changes, and population
  drift. Version thresholds, features, models, and schemas.
- Document label origin, adjudication criteria, reviewer disagreement, and
  uncertainty. Separate controlled positives from suspected cases; check
  training and evaluation data for contamination, duplication, and poisoning.

## Invariant checks

Before treating an invariant violation as strong evidence:

1. Confirm the invariant is actually guaranteed for that state and build.
2. Confirm the observation came from an authoritative, correctly ordered source.
3. Exclude replication delay, rollback, retries, reconnects, transitions,
   administrator/test paths, legitimate teleports or grants, schema errors,
   stale baselines, and game bugs.
4. Distinguish a state-integrity violation from attribution of exploitation.

An invariant can justify containment or investigation sooner than a soft
behavioral anomaly, but attribution and punitive action still require evidence
appropriate to their impact.

## Data and decision governance

- Collect only telemetry needed for a declared detection purpose. Define field
  ownership, access controls, retention, deletion, and incident-response rules.
- Prefer pseudonymous identifiers in analysis data and keep re-identification
  material separately protected. Do not place secrets or unnecessary personal
  data in evidence logs.
- Protect evidence integrity with immutable references, hashes where useful,
  schema validation, ordering information, and an auditable access trail.
- Evaluate performance for relevant populations and legitimate edge cases,
  including accessibility tools and unusual hardware, without assuming that a
  population difference implies abuse.
- Keep detector output separate from enforcement policy. Record who or what made
  the final decision, preserve counterevidence, and make consequential outcomes
  reviewable and appealable.

## Quality gates

- **Scope:** versions, trust boundaries, and decision stakes are explicit.
- **Identity:** citation metadata and source identity were verified.
- **Support:** each material claim is supported by the cited content.
- **Alternatives:** plausible benign causes and contradictory evidence were
  considered.
- **Validity:** empirical claims include representative evaluation and suitable
  metrics.
- **Reproducibility:** inputs, configuration, and transformations are traceable.
- **Calibration:** conclusion wording matches evidence strength and scope.
- **Action:** response is proportional, reviewable, and preserves an appeal path
  for consequential enforcement.

If a gate fails, narrow the claim or return inconclusive. Never auto-fill a
missing source, fabricate a citation, or raise confidence to satisfy a template.

## What tests establish

- Unit and fixture tests establish implementation behavior.
- Calibration tests establish an operating threshold on a defined population.
- Held-out, temporal, and external tests assess generalization.
- Shadow/canary monitoring assesses production drift and operational impact.

A green suite built from hand-authored threshold-triggering fixtures does not
establish detector validity, low false-positive rates, or production readiness.

## Source roles

| Source | Strongest appropriate use | Main limitation |
|---|---|---|
| Primary artifact or raw trace | What this exact version did | May be incomplete or untrusted |
| Official specification/documentation | Intended behavior and interfaces | May omit implementation details |
| Peer-reviewed study | Evidence under its study design | External validity may be limited |
| Independent reproduction | Corroboration and failure discovery | Often version-specific |
| Vendor/community report | Leads and operational context | Bias and unverifiable details |

Do not assign a universal quality tier solely from publication venue or source
type. Judge authority, directness, methodology, independence, recency, and
claim fit separately.
