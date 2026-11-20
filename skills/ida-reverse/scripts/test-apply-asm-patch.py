#!/usr/bin/env python3
"""Offline regression for apply-asm-patch.py plan validation (no IDA required)."""
from __future__ import annotations

import json
import contextlib
import importlib.util
import io
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parent / "apply-asm-patch.py"
FAILURES = 0

SPEC = importlib.util.spec_from_file_location("apply_asm_patch", SCRIPT)
PATCHER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCHER)


def run(args: list[str]) -> tuple[int, str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def expect(name: str, ok: bool, detail: str = "") -> None:
    global FAILURES
    if ok:
        print(f"PASS {name}")
    else:
        FAILURES += 1
        print(f"FAIL {name} {detail}")


def test_mcp_responses() -> None:
    """Exercise response handling without contacting IDA or any network endpoint."""
    failures = [
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32602, "message": "Invalid address"}},
        {"jsonrpc": "2.0", "id": 1, "result": {"isError": True, "content": [{"type": "text", "text": "Patch failed"}]}},
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32000, "message": "Database not found"}},
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32000, "message": "Tool patch_asm failed: database not found"}},
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32603, "message": "Patch failed: unknown tool: disassemble"}},
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32603, "message": "Patch failed", "data": {"previous_error": "Unknown tool: patch_asm"}}},
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32603, "message": "Unknown tool: patch_asm"}},
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32602, "message": "Unknown tool: disassemble"}},
        {"jsonrpc": "2.0", "id": 1, "result": {"isError": True, "content": [{"type": "text", "text": "Method 'disassemble' not found"}]}},
        {"jsonrpc": "2.0", "id": 1, "result": {"isError": True, "content": [{"type": "text", "text": "Patch failed: Method 'patch_asm' not found"}]}},
        {"jsonrpc": "2.0", "id": 1, "result": {"isError": True, "content": [{"type": "text", "text": "Method 'patch_asm' not found"}], "structuredContent": {"error": "patch failed"}}},
        {"jsonrpc": "2.0", "id": 1},
    ]
    plan = {"items": [{"addr": "0x401000", "asm": "nop"}, {"addr": "0x401001", "bytes": "90"}]}
    for index, response in enumerate(failures):
        output, errors = io.StringIO(), io.StringIO()
        with patch.object(PATCHER.urllib.request, "urlopen", return_value=io.BytesIO(json.dumps(response).encode())) as request:
            rejected = False
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                try:
                    PATCHER.apply_plan(plan, "http://unused.invalid/mcp", 1)
                except SystemExit as exc:
                    rejected = exc.code != 0
                except Exception:
                    pass
            expect(f"MCP failure {index} stops before later patches", rejected and request.call_count == 1, errors.getvalue())

    success = {"jsonrpc": "2.0", "id": 1, "result": {"content": [{"type": "text", "text": "patched"}], "isError": False}}
    for message in ("Unknown tool: patch_asm", 'Tool "patch_asm" not found', "Tool 'patch_asm' not found"):
        missing = {"jsonrpc": "2.0", "id": 1, "error": {"code": -32602, "message": message}}
        replies = [io.BytesIO(json.dumps(item).encode()) for item in (missing, success)]
        with patch.object(PATCHER.urllib.request, "urlopen", side_effect=replies) as request:
            try:
                tool, response = PATCHER.mcp_call("http://unused.invalid/mcp", ["patch_asm", "idapro_patch_asm"], {}, 1)
                expect(f"missing tool retries its alias: {message}", tool == "idapro_patch_asm" and response == success and request.call_count == 2)
            except SystemExit:
                expect(f"missing tool retries its alias: {message}", False)

    with patch.object(PATCHER.urllib.request, "urlopen", return_value=io.BytesIO(json.dumps(success).encode())) as request:
        tool, response = PATCHER.mcp_call("http://unused.invalid/mcp", ["patch_asm", "idapro_patch_asm"], {}, 1)
        expect("successful MCP response is preserved", tool == "patch_asm" and response == success and request.call_count == 1)

    # Recorded from bootstrap-manifest.json's ida-pro-mcp pin f82e6e2:
    # zeromcp/jsonrpc.py emits -32601; zeromcp/mcp.py wraps its message here.
    legacy_missing = {"jsonrpc": "2.0", "id": 1, "result": {
        "content": [{"type": "text", "text": "Method 'patch_asm' not found"}], "isError": True,
    }}
    replies = [io.BytesIO(json.dumps(item).encode()) for item in (legacy_missing, success)]
    with patch.object(PATCHER.urllib.request, "urlopen", side_effect=replies) as request:
        tool, response = PATCHER.mcp_call("http://unused.invalid/mcp", ["patch_asm", "idapro_patch_asm"], {}, 1)
        expect("pinned zeromcp missing method retries its alias", tool == "idapro_patch_asm" and response == success and request.call_count == 2)

    for code in (400, 404, 422):
        error = PATCHER.urllib.error.HTTPError("http://unused.invalid/mcp", code, "rejected", {}, io.BytesIO(b"Database not found"))
        with patch.object(PATCHER.urllib.request, "urlopen", side_effect=error) as request:
            rejected = False
            with contextlib.redirect_stderr(io.StringIO()):
                try:
                    PATCHER.mcp_call("http://unused.invalid/mcp", ["patch_asm", "idapro_patch_asm"], {}, 1)
                except SystemExit as exc:
                    rejected = exc.code != 0
            expect(f"HTTP {code} does not retry a failed patch", rejected and request.call_count == 1)

    for message, code, data, should_retry in (
        ('Tool "patch_asm" not found', -32602, {}, True),
        ("Patch failed: unknown tool: disassemble", -32603, {}, False),
        ("Patch failed", -32603, {"previous_error": "Unknown tool: patch_asm"}, False),
    ):
        encoded = json.dumps({"error": {"code": code, "message": message, "data": data}}).encode()
        error = PATCHER.urllib.error.HTTPError("http://unused.invalid/mcp", 400, "rejected", {}, io.BytesIO(encoded))
        with patch.object(PATCHER.urllib.request, "urlopen", side_effect=[error, io.BytesIO(json.dumps(success).encode())]) as request:
            accepted = False
            with contextlib.redirect_stderr(io.StringIO()):
                try:
                    tool, _ = PATCHER.mcp_call("http://unused.invalid/mcp", ["patch_asm", "idapro_patch_asm"], {}, 1)
                    accepted = tool == "idapro_patch_asm"
                except SystemExit:
                    pass
            expect(f"HTTP JSON error uses only the current tool message: {message}",
                   accepted == should_retry and request.call_count == (2 if should_retry else 1))


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)

        good = td_path / "good.json"
        good.write_text(
            json.dumps(
                {
                    "database": "sess-1",
                    "items": [
                        {"addr": "0x401050", "asm": "nop"},
                        {"addr": "0x401060", "asm": "jmp 0x401080"},
                        {"addr": "4198400", "bytes": "90 90"},
                    ],
                }
            ),
            encoding="utf-8",
        )
        code, out, err = run(["--plan", str(good), "--dry-run"])
        expect("valid plan dry-run", code == 0 and "validated" in out, err)

        bad_addr = td_path / "bad_addr.json"
        bad_addr.write_text(
            json.dumps({"items": [{"addr": "not-an-addr", "asm": "nop"}]}),
            encoding="utf-8",
        )
        code, _, err = run(["--plan", str(bad_addr), "--dry-run"])
        expect("reject bad addr", code != 0 and "addr" in err, err)

        both = td_path / "both.json"
        both.write_text(
            json.dumps({"items": [{"addr": "0x401000", "asm": "nop", "bytes": "90"}]}),
            encoding="utf-8",
        )
        code, _, err = run(["--plan", str(both), "--dry-run"])
        expect("reject asm+bytes", code != 0 and "exactly one" in err, err)

        shellish = td_path / "shellish.json"
        shellish.write_text(
            json.dumps({"items": [{"addr": "0x401000", "asm": "nop; rm -rf /"}]}),
            encoding="utf-8",
        )
        code, _, err = run(["--plan", str(shellish), "--dry-run"])
        expect("reject shell-like asm", code != 0, err)

        empty = td_path / "empty.json"
        empty.write_text(json.dumps({"items": []}), encoding="utf-8")
        code, _, err = run(["--plan", str(empty), "--dry-run"])
        expect("reject empty items", code != 0, err)

        array_form = td_path / "array.json"
        array_form.write_text(
            json.dumps([{"addr": "0x401000", "asm": "ret"}]),
            encoding="utf-8",
        )
        code, out, err = run(["--plan", str(array_form), "--dry-run"])
        expect("accept bare array plan", code == 0 and "validated" in out, err)

    test_mcp_responses()

    if FAILURES:
        print(f"TOTAL FAIL={FAILURES}")
        return 1
    print("TOTAL FAIL=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
