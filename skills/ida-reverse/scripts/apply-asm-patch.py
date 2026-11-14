#!/usr/bin/env python3
"""Validate and apply an ASM/byte patch plan to a live ida-pro-mcp session.

Prompt-driven workflow helper for ida-reverse (issue #136):
  1. Agent/user produces a patch plan JSON (addresses + asm or bytes).
  2. This script validates the plan offline (safe default).
  3. Optional --apply POSTs tools/call to ida-pro-mcp HTTP (default 127.0.0.1:13337).

Usage:
  python3 apply-asm-patch.py --plan patch_plan.json --dry-run
  python3 apply-asm-patch.py --plan patch_plan.json --apply [--database SESSION_ID]
  python3 apply-asm-patch.py --plan patch_plan.json --apply --endpoint http://127.0.0.1:13337/mcp

Plan schema (JSON object or array):
  {
    "database": "optional-session-id",
    "items": [
      {"addr": "0x401050", "asm": "nop"},
      {"addr": "0x401060", "bytes": "9090"}
    ]
  }

Authorization: only patch samples you own or are explicitly authorized to
modify. This tool does not bypass reverse-skill case-guard / scope.md gates.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ADDR_RE = re.compile(r"^(0x[0-9a-fA-F]+|[0-9]+)$")
BYTES_RE = re.compile(r"^([0-9a-fA-F]{2})+$")
ASM_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_\. ]*$")
# Keep patches conservative: no shell-looking payloads in asm text.
FORBIDDEN_ASM = re.compile(r"[;|&<>$\n\r`]|rm\s|shutdown|reboot", re.I)


def fail(msg: str) -> None:
    print(f"ERR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def load_plan(path: Path) -> dict[str, Any]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"plan not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"plan is not valid JSON: {exc}")

    if isinstance(raw, list):
        raw = {"items": raw}
    if not isinstance(raw, dict):
        fail("plan must be a JSON object or array")
    items = raw.get("items")
    if not isinstance(items, list) or not items:
        fail("plan.items must be a non-empty array")
    plan: dict[str, Any] = {"items": items}
    if raw.get("database"):
        plan["database"] = str(raw["database"])
    return plan


def normalize_item(item: Any, index: int) -> dict[str, Any]:
    if not isinstance(item, dict):
        fail(f"items[{index}] must be an object")
    addr = item.get("addr")
    if not isinstance(addr, str) or not ADDR_RE.match(addr):
        fail(f"items[{index}].addr must look like 0x401050 or a decimal integer")
    asm = item.get("asm")
    nbytes = item.get("bytes")
    if bool(asm) == bool(nbytes):
        fail(f"items[{index}] must set exactly one of asm|bytes")
    out: dict[str, Any] = {"addr": addr}
    if asm is not None:
        if not isinstance(asm, str) or not ASM_RE.match(asm.strip()):
            fail(f"items[{index}].asm is not a simple instruction string: {asm!r}")
        if FORBIDDEN_ASM.search(asm):
            fail(f"items[{index}].asm rejected (forbidden characters/pattern)")
        out["asm"] = asm.strip()
    if nbytes is not None:
        if not isinstance(nbytes, str) or not BYTES_RE.match(nbytes.replace(" ", "")):
            fail(f"items[{index}].bytes must be even-length hex")
        out["bytes"] = nbytes.replace(" ", "")
    return out


def validate_plan(plan: dict[str, Any]) -> dict[str, Any]:
    items = [normalize_item(it, i) for i, it in enumerate(plan["items"])]
    validated: dict[str, Any] = {"items": items}
    if plan.get("database"):
        validated["database"] = plan["database"]
    return validated


def mcp_call(endpoint: str, tool_names: list[str], arguments: dict[str, Any], timeout: float) -> tuple[str, dict[str, Any]]:
    """Try tool name aliases (HTTP short vs idapro_* client prefix)."""
    last_err = ""
    for tool in tool_names:
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {"name": tool, "arguments": arguments},
        }
        req = urllib.request.Request(
            endpoint,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:400]
            last_err = f"ida-pro-mcp HTTP {exc.code} for tool {tool}: {detail}"
            # Unknown tool / method-not-found → try the next alias.
            if exc.code in (400, 404, 422) or "not found" in detail.lower() or "unknown" in detail.lower():
                continue
            fail(last_err)
        except urllib.error.URLError as exc:
            fail(f"ida-pro-mcp unreachable at {endpoint}: {exc.reason}")
        try:
            result = json.loads(body)
        except json.JSONDecodeError:
            fail(f"ida-pro-mcp returned non-JSON for {tool}: {body[:400]}")
        err = result.get("error")
        if err and "not found" in json.dumps(err).lower():
            last_err = f"tool {tool} not found: {err}"
            continue
        return tool, result
    fail(last_err or f"no usable tool name among {tool_names}")
    raise AssertionError("unreachable")


def apply_plan(plan: dict[str, Any], endpoint: str, timeout: float) -> None:
    items = plan["items"]
    database = plan.get("database")

    asm_items = [it for it in items if "asm" in it]
    byte_items = [it for it in items if "bytes" in it]

    if asm_items:
        args: dict[str, Any] = {"items": asm_items}
        if database:
            args["database"] = database
        tool, result = mcp_call(endpoint, ["patch_asm", "idapro_patch_asm"], args, timeout)
        print(json.dumps({"tool": tool, "result": result}, ensure_ascii=False, indent=2))

    if byte_items:
        args = {"patches": byte_items}
        if database:
            args["database"] = database
        tool, result = mcp_call(endpoint, ["patch", "idapro_patch"], args, timeout)
        print(json.dumps({"tool": tool, "result": result}, ensure_ascii=False, indent=2))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--plan", required=True, type=Path, help="patch plan JSON path")
    parser.add_argument(
        "--endpoint",
        default="http://127.0.0.1:13337/mcp",
        help="ida-pro-mcp Streamable HTTP endpoint (default 127.0.0.1:13337/mcp)",
    )
    parser.add_argument("--database", default=None, help="session/database id (overrides plan.database)")
    parser.add_argument("--timeout", type=float, default=30.0, help="HTTP timeout seconds")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="validate only and print the plan (default if --apply is omitted)",
    )
    mode.add_argument("--apply", action="store_true", help="POST the validated plan to ida-pro-mcp")
    args = parser.parse_args(argv)

    plan = validate_plan(load_plan(args.plan))
    if args.database:
        plan["database"] = args.database

    print(json.dumps({"status": "validated", "plan": plan}, ensure_ascii=False, indent=2))
    if not args.apply:
        print("NOTE: dry-run only; re-run with --apply to send to ida-pro-mcp", file=sys.stderr)
        return 0

    apply_plan(plan, args.endpoint, args.timeout)
    print("OK: patch plan submitted", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
