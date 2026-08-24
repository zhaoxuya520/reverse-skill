# 2026-08-24 Ableton Extension Host cooperative-yield smoke

## Scenario classification

Other: Windows desktop application acceptance and Extension Host compatibility.

## Target overview

Verify that a packaged audio-analysis extension can yield between large decode and measurement chunks without relying on a Node global absent from its host runtime.

## Complete execution chain

1. Reproduced the failure at 16,385 frames with the host global removed.
2. Replaced `setImmediate` with a zero-delay timer while preserving the chunk loop and abort checks.
3. Added public-decoder and complete-workflow regressions, including the 192,000-frame acceptance signal.
4. Ran 79 tests, typecheck, production build, package verification, and a two-axis code review.
5. Compared the installed bundle hash with the verified package before opening the desktop application.
6. Checked the application window title before restart and paused when it showed unsaved work.
7. After a safe restart, ran the packaged workflow manually because OpenReverse was unavailable.
8. Preserved the report screenshot, checked the restarted host log, and scanned likely render roots while the report remained open.

## Pitfalls

| Problem | Cause | Resolution | Time |
| --- | --- | --- | --- |
| Short fixtures passed but normal renders failed | The first cooperative yield occurred only after 16,384 frames, where the host lacked `setImmediate` | Add a 16,385-frame regression with the global removed | Short |
| Restarting the host risked user work | The desktop application showed an unsaved Set in its window title | Stop before restart and resume only after the user confirms the Set is safe | Short |
| Desktop control was unavailable | OpenReverse was not installed and its module marks installation as manual | Open the exact fixture in Explorer and reduce the human action to one smoke run | Short |
| The smoke report showed 16 seconds for a four-second file | The selection extended past the file and rendered silence | Record the selection honestly; use the exact 192,000-frame automated regression for measurement equality | Short |

## Toolchain findings

- PowerShell can prove package and installed-bundle identity with SHA-256 before a manual smoke.
- The existing acceptance wizard can check commit evidence, package hash, and installed archive contents without driving the UI.
- A post-condition scan while the report is open is useful because this workflow deletes the render before opening the report.
- OpenReverse remains a manual, optional dependency. The browser-automation route correctly falls back to a short human step when it is absent.

## Key commands

```powershell
$built = (Get-FileHash -Algorithm SHA256 .\dist\extension.js).Hash
$installed = (Get-FileHash -Algorithm SHA256 "$env:LOCALAPPDATA\Ableton\Extensions\{extension_id}\dist\extension.js").Hash
$built -eq $installed

$cutoff = (Get-Date).AddMinutes(-15)
Get-ChildItem $env:TEMP -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -ge $cutoff -and $_.Extension -match '^\.(wav|aif|aiff)$' }
```

```bash
bash scripts/live-acceptance-wizard.sh --check {run_id}
```

## Package improvement suggestions

No routing or bootstrap change is needed. Desktop automation already routes to OpenReverse, and the tool documentation already states that OpenReverse requires manual installation.

## Reusable pattern

For host-runtime compatibility bugs, place the regression one unit beyond the cooperative-work boundary. Remove the unsupported global inside the test process, restore it in `finally`, and cover the same behavior once through the complete workflow. Before desktop acceptance, compare the packaged and installed bundle hashes and inspect the target window title for unsaved state.

## Evolution actions

- [ ] Updated routing matrix
- [ ] Updated tool index
- [ ] Updated bootstrap manifest
- [ ] Updated sub-skill documentation
- [x] Added a pitfall record
- [ ] No update needed

## Environment

- OS: Windows 11 Pro 10.0.26200
- Tools: Node.js 26.2.0, Ableton Extensions SDK and CLI 1.0.0-beta.1, PowerShell
- Target platform: Ableton Live 12.4.5b11, Extension Host 1.0.0

## Sanitization check

- No username, email, credential, token, network target, or private URL is present.
- Local installation paths use environment variables or placeholders.
- The sample itself is not stored in this journal.

## Index synchronization

The scenario, reusable pattern, target feature, statistics, and pitfall were added to `_index.md`.

---
<!-- [Evolution statistics] Package total projects: 31 | New patterns: 1 | Toolchain fixes: 0 -->
<!-- [Community contribution] Ask whether to contribute this sanitized field-journal file. -->
