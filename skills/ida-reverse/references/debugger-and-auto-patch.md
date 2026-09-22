# IDA debugger + prompt-driven ASM patch

Supports issue #136: **IDA debugger + auto ASM patch by prompt**.

This is a *workflow contract* for agents that already have `ida-pro-mcp` (server name `idapro`) running. It does **not** invent a new router, grant authorization, or replace `case-init` / `scope.md`.

## ACTION REQUIRED

1. `NOW`: Confirm the sample is authorized (`../field-journal/precedent-reverse.md` + case `auth.status=granted`).
2. `NOW`: Start MCP — `scripts/start.ps1` (headless) or `scripts/start-gui.ps1` (GUI debugger path).
3. `NOW`: Open the binary — `scripts/open.ps1 -Path <sample>` and keep the `session_id`.
4. `NEXT`: Follow **Debugger enablement** below if the user asks for dynamic debugging.
5. `ACT`: Convert the user prompt into a **patch plan JSON**, validate with `scripts/apply-asm-patch.py --dry-run`, then apply via MCP or `--apply`.

## Debugger enablement (ida-pro-mcp `?ext=dbg`)

Debugger tools are hidden by default in ida-pro-mcp. Enable them on the client MCP URL:

```text
http://127.0.0.1:13337/mcp?ext=dbg
```

Notes:

| Topic | Contract |
|---|---|
| Who owns the debugger | **GUI IDA** (not headless idalib). Use `start-gui.ps1` / portable `Launch-IDA-Pro.cmd`. |
| Client registration | Register `idapro` as remote/HTTP with `?ext=dbg` when the task needs breakpoints or process control. |
| Static-only tasks | Keep the default URL **without** `ext=dbg` — smaller tool surface. |
| Tool names | Version-dependent (`debug_start`, `debug_breakpoint`, …). Probe with `tools/list` after enabling; do not hardcode a frozen inventory. |
| Authorization | Debugger still runs under the same case gate. No target ACT until `auth.status=granted` + valid `network_profile` / offline sample. |

Typical debugger prompt flow:

```text
1. start-gui.ps1 + open sample in GUI → Output shows [MCP] port=13337
2. Client URL includes ?ext=dbg
3. tools/list → discover debugger tools
4. Set breakpoint on validate/check function
5. Run until hit; read registers/locals
6. Build patch plan from observed branch/return
7. Save IDB after patches (idb_save)
```

## Auto ASM patch by prompt

### Prompt → plan → apply

1. **Read the prompt intent** (e.g. “always return true on license check”).
2. **Locate evidence first** — `find_regex` / `xrefs_to` / `analyze_function` / `disasm`. Do not patch without an address.
3. **Emit a patch plan JSON** (never free-form shell):

```json
{
  "database": "<session_id from open.ps1>",
  "items": [
    { "addr": "0x401050", "asm": "nop" },
    { "addr": "0x401060", "asm": "jmp 0x401080" },
    { "addr": "0x401000", "asm": "mov eax, 1" },
    { "addr": "0x401005", "asm": "ret" }
  ]
}
```

Byte patches use `"bytes": "909090"` instead of `"asm"`.

4. **Validate offline** (no IDA required):

```bash
python3 skills/ida-reverse/scripts/apply-asm-patch.py --plan patch_plan.json --dry-run
```

5. **Apply** either:
   - via MCP tools the agent already has: `idapro_patch_asm` / `idapro_patch`
   - or via helper (needs live server):

```bash
python3 skills/ida-reverse/scripts/apply-asm-patch.py \
  --plan patch_plan.json \
  --apply \
  --endpoint http://127.0.0.1:13337/mcp
```

6. **Verify** — re-`disasm` the patched range; if debugger is on, re-run the branch. Record Evidence (`E-patch-*.md`) with before/after bytes and the prompt intent.
7. **Persist** — `idb_save` / `open.ps1` session keep-alive; never delete `.i64`/`.idb`.

### Hard rules (MUST)

- MUST locate addresses from analysis (or an explicit user-supplied address). MUST NOT invent offsets.
- MUST dry-run the plan before `--apply` when the helper is used.
- MUST use simple instruction strings / hex bytes only; helper rejects shell-like asm text.
- MUST NOT patch outside the authorized sample / case scope.
- MUST NOT treat `case-guard --force` as authorization.
- MUST record Evidence for every applied patch that changes control flow.

### Anti-patterns

| Anti-pattern | Correct |
|---|---|
| “Patch whatever looks like a check” | `xrefs_to` + `analyze_function` first |
| Silent multi-instruction rewrites | One plan, dry-run, explicit Evidence |
| Using GUI debugger while claiming headless | Choose path A or path B explicitly |
| Closing IDA between patch iterations | Keep session; use recover.ps1 only on stall |

## Mapping to MCP tools

| Plan field | MCP tool |
|---|---|
| `items[].asm` | `idapro_patch_asm` (HTTP alias `patch_asm`) |
| `items[].bytes` | `idapro_patch` (HTTP alias `patch`) |
| `database` | session id required by most `idapro_*` tools |
| comments after patch | `idapro_set_comments` |
| rename hook points | `idapro_rename` |

`apply-asm-patch.py` tries HTTP short names first, then `idapro_*` prefixed names.

Full tool list: [ida-mcp-cheatsheet.md](ida-mcp-cheatsheet.md). Entry skill: [../SKILL.md](../SKILL.md).

## Task completion checklist

- [ ] Authorized scope confirmed (`scope.md` / precedent) before any patch.
- [ ] Debugger URL uses `?ext=dbg` only when dynamic debugging is in scope.
- [ ] Patch plan validated with `apply-asm-patch.py --dry-run`.
- [ ] Applied patches re-disassembled / debug-verified.
- [ ] Evidence written; IDB saved.
