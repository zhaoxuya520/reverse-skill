#!/usr/bin/env python3
"""Offline regression for apply-asm-patch.py plan validation (no IDA required)."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "apply-asm-patch.py"
FAILURES = 0


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

    if FAILURES:
        print(f"TOTAL FAIL={FAILURES}")
        return 1
    print("TOTAL FAIL=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
