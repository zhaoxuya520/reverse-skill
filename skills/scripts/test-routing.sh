#!/usr/bin/env bash
# Run the shared routing benchmark through the Bash structured router.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK="$SCRIPT_DIR/../tests/routing-benchmark.json"
ROUTER="$SCRIPT_DIR/master-route.sh"

PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PYTHON="$candidate"
    break
  fi
done
if [[ -z "$PYTHON" ]]; then
  echo 'ERROR: Python 3 is required by the Bash routing benchmark runner.' >&2
  exit 2
fi

# 必须把“正在跑这个脚本的那个 bash”传下去，不能写死裸 `bash`：
# Windows 上 PATH 里的 `bash` 常常先命中 C:\Windows\System32\bash.exe（WSL 空壳），
# 它只会打印「适用于 Linux 的 Windows 子系统没有已安装的分发」然后 exit 1，
# 于是 178 条全红，而报告读起来像路由坏了。
BASH_BIN="${BASH:-bash}"

"$PYTHON" - "$BENCHMARK" "$ROUTER" "$BASH_BIN" <<'PY'
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

benchmark_path = pathlib.Path(sys.argv[1])
router_path = pathlib.Path(sys.argv[2])
bash_bin = sys.argv[3]
benchmark = json.loads(benchmark_path.read_text(encoding="utf-8-sig"))
cases = benchmark["cases"]

failures = []
passed = 0
print(f"=== Bash routing benchmark | {len(cases)} cases ===")

with tempfile.TemporaryDirectory(prefix="rs-routing-bash-") as scratch:
    root = pathlib.Path(scratch)
    for index, case in enumerate(cases):
        hint = case["hint"]
        expected = case["expect"]
        out_dir = root / str(index)
        result = subprocess.run(
            [bash_bin, str(router_path), "--hint", hint, "--out-dir", str(out_dir)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

        got = "ERR"
        scope_path = out_dir / "route-scope.md"
        if result.returncode == 0 and scope_path.is_file():
            match = re.search(
                r"(?m)^- primary:[ \t]*(\S+)[ \t]*$",
                scope_path.read_text(encoding="utf-8"),
            )
            if match:
                got = match.group(1)

        if got == expected:
            passed += 1
        else:
            failures.append(
                f"hint={hint!r} expect={expected} got={got} exit={result.returncode}"
            )

    # Regression: when neither --project-root nor --out-dir is supplied, the
    # Bash router must behave like the PowerShell router and write under the
    # caller's current project, not under the installed reverse-skill package.
    source_skills = router_path.parent.parent
    source_config = source_skills / "config" / "routing.json"
    config = json.loads(source_config.read_text(encoding="utf-8-sig"))
    default_case = cases[0]
    default_skill_rel = pathlib.PurePosixPath(
        config["routes"][default_case["expect"]]["skill"]
    )

    fixture_package = root / "package"
    fixture_router = fixture_package / "skills" / "scripts" / "master-route.sh"
    fixture_config = fixture_package / "skills" / "config" / "routing.json"
    fixture_skill = fixture_package / "skills" / pathlib.Path(*default_skill_rel.parts)
    fixture_router.parent.mkdir(parents=True, exist_ok=True)
    fixture_config.parent.mkdir(parents=True, exist_ok=True)
    fixture_skill.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(router_path, fixture_router)
    shutil.copy2(source_config, fixture_config)
    shutil.copy2(source_skills / pathlib.Path(*default_skill_rel.parts), fixture_skill)

    caller_root = root / "caller-project"
    caller_root.mkdir()
    default_result = subprocess.run(
        [bash_bin, str(fixture_router), "--hint", default_case["hint"]],
        cwd=caller_root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    default_scopes = list((caller_root / "work").glob("master-route-*/route-scope.md"))
    if default_result.returncode != 0:
        failures.append(
            "default-root router failed: "
            f"exit={default_result.returncode} stderr={default_result.stderr.strip()!r}"
        )
    elif len(default_scopes) != 1:
        failures.append(
            "default-root router did not write exactly one route-scope under caller project: "
            f"found={len(default_scopes)}"
        )
    else:
        default_scope = default_scopes[0].read_text(encoding="utf-8")
        project_match = re.search(
            r"(?m)^- project_root:[ \t]*(.+?)[ \t]*$",
            default_scope,
        )
        if not project_match:
            failures.append("default-root route-scope missing project_root")
        elif pathlib.Path(project_match.group(1)).resolve() != caller_root.resolve():
            failures.append(
                "default-root project_root mismatch: "
                f"got={project_match.group(1)!r} expect={str(caller_root.resolve())!r}"
            )
        else:
            print("[PASS] default root -> caller project")

print(f"TOTAL={len(cases)} PASS={passed} FAIL={len(failures)}")
if failures:
    for failure in failures:
        print(f"[FAIL] {failure}", file=sys.stderr)
    raise SystemExit(1)

print(f"OVERALL: ALL PASS ({passed} routing cases + default-root regression)")
PY
