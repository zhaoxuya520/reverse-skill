# Kali pwntools Discovery Completion Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Preserve PR #144 contributor provenance and complete pwntools discovery, version reporting, capability visibility, bootstrap listing, manifest verification, and CI coverage while keeping Kali and client-neutral indexes on the real `pwn version` CLI contract.

**Architecture:** Treat the original PR head as the integration baseline, then drive both real refresh paths through strict hermetic `pwn` stubs that accept only the `version` subcommand and reproduce the real no-terminal warning unless the probe sets `PWNLIB_NOTERM=1`. Make only targeted catalog, client-neutral index, capability-list, help-list, manifest, and workflow changes; avoid broader manifest-generation refactors.

**Tech Stack:** Bash, JSON, Python 3 assertions, GitHub Actions YAML, Git.

---

### Task 1: Preserve the original PR commit

**Objective:** Make the original #144 head an ancestor of the integration branch before maintainer fixes.

**Files:**
- No file edits; merge `review/pr-144` into `integration/pr-144-pwntools-discovery`.

**Step 1: Verify the fetched head**

Run:

```bash
git rev-parse review/pr-144
git diff --stat origin/main...review/pr-144
```

Expected: head `cede1d28...`; one added catalog line.

**Step 2: Merge without squashing**

Run:

```bash
git merge --no-ff review/pr-144 -m "Merge PR #144: catalog pwntools in Kali discovery"
```

Expected: clean merge; original head is the second parent.

**Step 3: Verify ancestry**

Run:

```bash
git merge-base --is-ancestor review/pr-144 HEAD
git show --no-patch --format='%P' HEAD
```

Expected: exit 0; merge commit has two parents.

### Task 2: Add the failing end-to-end regression

**Objective:** Prove that the unmodified #144 change lacks version, capability, bootstrap-list, and manifest integration.

**Files:**
- Create: `kali/scripts/test-pwntools-discovery.sh`
- Modify: `skills/scripts/test-client-neutral-bootstrap.sh`
- Modify: `.github/workflows/ci.yml`

**Step 1: Write the hermetic test**

The test must:

- create a temporary `bin` directory;
- link required host commands (`bash`, `date`, `dirname`, `head`, `mktemp`, `python3`, `uname`, and `jq` when present);
- create a strict stub executable `pwn` that requires exactly one argument equal to `version`, rejects every other invocation with a clear stderr diagnostic and non-zero exit, and writes `[*] Pwntools v4.15.0` to stderr for the valid call;
- run `kali/scripts/refresh-tool-index.sh` into temporary Markdown and JSON files;
- assert exactly one `pwntools` JSON record with `available=true`, the stub path, and version `[*] Pwntools v4.15.0`;
- assert the Markdown capability row marks `pwntools` available and installable through `pip-package`;
- assert `bootstrap-reverse.sh --list` contains the exact token `pwntools`;
- parse both `skills/scripts/bootstrap-manifest.json` and `kali/scripts/bootstrap-manifest.json` and assert `verifyCommand == "pwn"`.

The script must have `set -euo pipefail`, clean its temporary directory with a trap, and perform no package installation or network access.

Extend the existing client-neutral regression with the same strict stub. After its first refresh, assert one and only one pwntools JSON record with `available=true`, the canonical stub path, version `[*] Pwntools v4.15.0`, source `command`, skill `reverse-engineering`, and purpose `CTF pwn exploit development framework`. Use explicit conditions and `SystemExit` for these new checks rather than adding Python `assert` statements.

**Step 2: Wire the test into Ubuntu CI**

Add after Bash syntax validation in `.github/workflows/ci.yml`:

```yaml
      - name: Kali pwntools discovery regression
        shell: bash
        run: bash kali/scripts/test-pwntools-discovery.sh
```

**Step 3: Run to verify RED**

Run:

```bash
bash kali/scripts/test-pwntools-discovery.sh
bash skills/scripts/test-client-neutral-bootstrap.sh
```

Expected: both FAIL because their production refresh catalog invokes the rejected `--version` option instead of `pwn version`, not because of test setup.

**Step 4: Commit the red test**

```bash
git add kali/scripts/test-pwntools-discovery.sh \
  skills/scripts/test-client-neutral-bootstrap.sh \
  .github/workflows/ci.yml
git commit -m "test(kali): cover pwntools discovery integration"
```

### Task 3: Implement the minimum complete behaviour

**Objective:** Make the regression pass without unrelated refactoring.

**Files:**
- Modify: `kali/scripts/lib/tool-discovery.sh`
- Modify: `kali/scripts/refresh-tool-index.sh`
- Modify: `skills/scripts/refresh-tool-index.sh`
- Modify: `kali/scripts/bootstrap-reverse.sh`
- Modify: `kali/scripts/bootstrap-manifest.json`
- Modify: `skills/scripts/bootstrap-manifest.json`

**Step 1: Fix the catalog command and version**

Change the #144 row to:

```bash
"pwntools|reverse-engineering|CTF pwn 利用开发框架|version|pwn"
```

Change the client-neutral catalog version command from `pwn --version` to `pwn version`, and make its version runner pass only populated arguments rather than an extra empty placeholder. Both indexes must invoke the stub with exactly one argument and record the first merged stdout/stderr line from the real CLI contract, `[*] Pwntools v4.15.0`. Preserve the generic runner's previous empty-spec semantics: parse and invoke a version specification only when it is both non-empty and not `none`.

**Step 2: Add capability visibility**

- Add `pwntools` to `CAPABILITY_NAMES`.
- Add a dedicated availability branch:

```bash
pwntools)
    if command -v pwn &>/dev/null; then tool_available="✓"; fi
    ;;
```

- Include `pwntools` in the `pip-package` bootstrap-kind branch.

**Step 3: Add bootstrap discoverability**

- Add `pwntools` to `bootstrap-reverse.sh --list`.
- Add it to the human-readable reverse-analysis/CTF help output.

**Step 4: Correct both manifest verification commands**

Change `verifyCommand` from `pwntools` to `pwn` in both manifests.

**Step 5: Run focused test to verify GREEN**

Run:

```bash
bash kali/scripts/test-pwntools-discovery.sh
bash skills/scripts/test-client-neutral-bootstrap.sh
```

Expected: exit 0 and a final success message.

**Step 6: Commit implementation**

```bash
git add kali/scripts/lib/tool-discovery.sh \
  kali/scripts/refresh-tool-index.sh \
  skills/scripts/refresh-tool-index.sh \
  kali/scripts/bootstrap-reverse.sh \
  kali/scripts/bootstrap-manifest.json \
  skills/scripts/bootstrap-manifest.json
git commit -m "fix(kali): complete pwntools discovery integration"
```

### Task 4: Run complete local verification

**Objective:** Verify focused behaviour and repository-wide gates before any push.

**Files:**
- No production edits unless a test exposes a defect.

**Step 1: Focused and syntax checks**

```bash
bash kali/scripts/test-pwntools-discovery.sh
bash -n kali/scripts/test-pwntools-discovery.sh
bash -n kali/scripts/lib/tool-discovery.sh
bash -n kali/scripts/refresh-tool-index.sh
bash -n kali/scripts/bootstrap-reverse.sh
```

Expected: all exit 0.

**Step 2: Repository regression checks**

```bash
bash skills/scripts/test-bootstrap-manifest.sh
bash skills/scripts/test-client-neutral-bootstrap.sh
bash skills/scripts/test-routing.sh
bash skills/scripts/test-bash-workflow.sh
python3 skills/scripts/verify-repository-security.py
python3 skills/scripts/verify-doc-links.py
```

Expected: all exit 0; routing reports no failures.

**Step 3: Structured-file and encoding checks**

- Parse every tracked JSON file with Python.
- Parse every tracked YAML/YML file with an available Python YAML parser.
- Decode all changed text as UTF-8/UTF-8-SIG.
- Scan changed text for common mojibake markers.
- Preserve any expected PowerShell BOM outside this change set.

Expected: zero parse, decode, or mojibake failures.

**Step 4: Verify history and worktree**

```bash
git status --short
git merge-base --is-ancestor review/pr-144 HEAD
git log --oneline --decorate origin/main..HEAD
```

Expected: clean worktree; #144 head is an ancestor; design, merge, test, and implementation commits are visible.

### Task 4a: Add the no-terminal warning RED regression

**Objective:** Reproduce pwntools 4.15.0's successful no-`TERM` warning path and prove both production version probes must set `PWNLIB_NOTERM=1` locally.

**Files:**
- Modify: `kali/scripts/test-pwntools-discovery.sh`
- Modify: `skills/scripts/test-client-neutral-bootstrap.sh`
- Modify: `docs/superpowers/specs/2026-09-21-pwntools-kali-discovery-design.md`
- Modify: `docs/plans/2026-09-21-pwntools-kali-discovery.md`

**Step 1: Strengthen both strict stubs**

After validating exactly one `version` argument, have each stub emit `Warning: _curses.error: setupterm: could not find terminfo database` to stderr when `${PWNLIB_NOTERM:-}` is not `1`, followed by `[*] Pwntools v4.15.0`. With `PWNLIB_NOTERM=1`, emit only the version line. Continue to reject unknown argument shapes with exit 64. Around the refresh under test, unset inherited `TERM` and `PWNLIB_NOTERM`; this fixes the no-terminal precondition without preventing production from setting `PWNLIB_NOTERM=1` locally on the child probe.

Keep the generated version assertions exactly `[*] Pwntools v4.15.0`; do not accept, strip, or skip the warning in test code.

**Step 2: Verify focused RED**

Run:

```bash
bash kali/scripts/test-pwntools-discovery.sh
PYTHONOPTIMIZE=1 bash kali/scripts/test-pwntools-discovery.sh
bash skills/scripts/test-client-neutral-bootstrap.sh
```

Expected: all three invocations fail because the current production probes capture the warning as the version. The diagnostics must report the warning as the actual value, demonstrating that production needs a probe-local `PWNLIB_NOTERM=1` setting.

**Step 3: Verify non-behavioural gates and commit RED**

Run Bash syntax checks for both changed tests, repository-security and documentation-link checks, parse tracked JSON and YAML, and inspect the diff. Do not change production in this commit. Commit only the four files above as `test: cover pwntools no-terminal version output`.

The later GREEN change must scope `PWNLIB_NOTERM=1` to the real `pwn version` process in both runners. It must not export the variable for ordinary commands or availability checks, and the generic client-neutral runner must retain the empty-version-spec behaviour described in Task 3.

### Task 5: Review, publish, CI, and integrate

**Objective:** Obtain independent review, publish safely, and update `main` only after green CI.

**Files:**
- No code changes unless review or CI identifies a defect.

**Step 1: Independent reviews**

Run two reviews:

1. Spec-compliance review against the approved design.
2. Code-quality review for Bash portability, hermetic testing, false positives, and security boundaries.

Fix any blocker and repeat focused/full verification.

**Step 2: Publish integration branch**

Use a temporary, repository-authorized credential. Push:

```bash
git push <authenticated-remote> HEAD:refs/heads/integration/pr-144-pwntools-discovery
```

No force-push.

**Step 3: Wait for GitHub Actions**

Poll all runs for the integration head until completed. Any failure blocks integration.

**Step 4: Fast-forward main safely**

Fetch `main`, verify it is an ancestor of the integration head, then push `HEAD:main` without force. If remote main advanced incompatibly, stop and re-integrate.

**Step 5: Verify GitHub state and clean credentials**

- Verify remote `main` equals the integration head.
- Verify #144 is marked merged.
- Verify all main-branch Actions runs succeed.
- Delete the temporary integration branch.
- Remove temporary credentials from GitHub and local disk.
