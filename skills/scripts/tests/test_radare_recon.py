"""Exercise the PowerShell recon entry point with inert native tool fixtures."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


PWSH = os.environ.get("REVERSE_TEST_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")
SCRIPT = Path(__file__).resolve().parents[2] / "radare2/scripts/recon.ps1"
STAGES = ["-I", "-S", "-i", "-E", "-zz", "-A"]

DISCOVERY = r"""
Set-StrictMode -Version Latest
function Resolve-ReverseToolSpec {
    param([string]$Name)
    if ($Name -notin @('rabin2', 'r2')) { throw 'Unexpected tool discovery' }
    [IO.File]::AppendAllText($env:RECON_TEST_DISCOVERY, $Name + "`n")
    $available = $env:RECON_TEST_BOOTSTRAP -eq 'none' -or (Test-Path -LiteralPath $env:RECON_TEST_INSTALLED)
    return [pscustomobject]@{
        Name = $Name
        Available = $available
        Command = $env:RECON_TEST_PYTHON
        PrefixArgs = @($env:RECON_TEST_NATIVE, $Name)
    }
}
function powershell.exe {
    param([switch]$NoProfile, [string]$ExecutionPolicy, [string]$File, [string[]]$Capability, [switch]$SkipRefresh)
    if ($env:RECON_TEST_BOOTSTRAP -eq 'success') {
        [IO.File]::WriteAllText($env:RECON_TEST_INSTALLED, 'inert install fixture')
        $global:LASTEXITCODE = 0
        Write-Output 'bootstrap fixture completed'
    } else {
        $global:LASTEXITCODE = 17
        Write-Output 'bootstrap fixture did not install a tool'
    }
}
"""

NATIVE_TOOL = r"""
import json
import os
from pathlib import Path
import sys
import time

tool, stage = sys.argv[1:3]
log_path = Path(os.environ['RECON_TEST_CALLS'])
def record(event, **fields):
    with log_path.open('a', encoding='utf-8') as log:
        log.write(json.dumps({'event': event, 'tool': tool, 'stage': stage, **fields}) + '\n')

record('started', arguments=sys.argv[2:])
limited = stage in ('-i', '-zz')
line_count = 1000 if limited else 6
for index in range(line_count):
    print(f'{tool}:{stage}:line-{index + 1}', flush=True)
    if limited and index == 2:
        # The display limit is reached before the native process finishes.
        time.sleep(0.03)
exit_code = 17 if stage == os.environ['RECON_TEST_FAIL_STAGE'] else 0
record('completed', lines=line_count, exit_code=exit_code)
if stage == os.environ['RECON_TEST_WARN_STAGE']:
    print('ERROR: optional format database unavailable (fixture)', file=sys.stderr, flush=True)
if exit_code:
    print(f'{tool}: synthetic {stage} failure (exit 17)', file=sys.stderr, flush=True)
sys.exit(exit_code)
"""


@unittest.skipUnless(PWSH, "PowerShell is required for the native recon workflow")
class RadareReconTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="radare-recon-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.script = self.root / "skills/radare2/scripts/recon.ps1"
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(SCRIPT, self.script)
        discovery = self.root / "skills/scripts/lib/ToolDiscovery.ps1"
        discovery.parent.mkdir(parents=True)
        discovery.write_text(DISCOVERY, encoding="utf-8")
        (self.root / "skills/scripts/bootstrap-reverse.ps1").write_text(
            "throw 'The real bootstrap must not be executed by this fixture'\n", encoding="utf-8"
        )
        self.native = self.root / "native-tool.py"
        self.native.write_text(NATIVE_TOOL, encoding="utf-8")
        self.target = self.root / "input [fixture] with spaces.bin"
        self.target.write_text("Inert data; the native fixture never analyzes this file.", encoding="utf-8")
        self.call_log = self.root / "calls.jsonl"
        self.discovery_log = self.root / "discovery.txt"
        self.installed = self.root / "installed"

    def run_recon(self, fail_stage="", bootstrap="none", analyze=True, imports_limit=2, strings_limit=3,
                  warn_stage=""):
        environment = {
            **os.environ,
            "POWERSHELL_TELEMETRY_OPTOUT": "true",
            "RECON_TEST_PYTHON": sys.executable,
            "RECON_TEST_NATIVE": str(self.native),
            "RECON_TEST_CALLS": str(self.call_log),
            "RECON_TEST_DISCOVERY": str(self.discovery_log),
            "RECON_TEST_INSTALLED": str(self.installed),
            "RECON_TEST_FAIL_STAGE": fail_stage,
            "RECON_TEST_WARN_STAGE": warn_stage,
            "RECON_TEST_BOOTSTRAP": bootstrap,
        }
        command = [
            PWSH, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.script),
            "-TargetPath", str(self.target), "-ImportsLimit", str(imports_limit), "-StringsLimit", str(strings_limit),
        ]
        if analyze:
            command.append("-RunAnalysis")
        result = subprocess.run(command, env=environment, capture_output=True, encoding="utf-8", timeout=30)
        self.events = [json.loads(line) for line in self.call_log.read_text().splitlines()] if self.call_log.exists() else []
        return result

    def started_stages(self):
        return [event["stage"] for event in self.events if event["event"] == "started"]

    def completed_stages(self):
        return [event["stage"] for event in self.events if event["event"] == "completed"]

    def assert_failure(self, stage, **options):
        result = self.run_recon(fail_stage=stage, **options)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("exit code 17", result.stderr)
        self.assertIn(f"synthetic {stage} failure", result.stderr)
        expected = STAGES[:STAGES.index(stage) + 1]
        self.assertEqual(self.started_stages(), expected)
        self.assertEqual(self.completed_stages(), expected)
        failed = [event for event in self.events if event["event"] == "completed"][-1]
        self.assertEqual(failed["exit_code"], 17)
        return result

    def test_success_preserves_output_limits_and_all_native_stages(self):
        result = self.run_recon()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.started_stages(), STAGES)
        self.assertEqual(self.completed_stages(), STAGES)
        for stage, limit in (("-i", 2), ("-zz", 3)):
            lines = [line for line in result.stdout.splitlines() if line.startswith(f"rabin2:{stage}:")]
            self.assertEqual(lines, [f"rabin2:{stage}:line-{i + 1}" for i in range(limit)])
        for event in self.events:
            if event["event"] == "started":
                self.assertEqual(event["arguments"][-2], "--")
                self.assertTrue(Path(event["arguments"][-1]).samefile(self.target))

    def test_basic_information_failure_stops_recon(self):
        self.assert_failure("-I")

    def test_stderr_warning_with_zero_exit_code_remains_success(self):
        result = self.run_recon(warn_stage="-i")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ERROR: optional format database unavailable", result.stderr)
        self.assertEqual(self.started_stages(), STAGES)
        self.assertEqual(self.completed_stages(), STAGES)

    def test_sections_failure_stops_recon(self):
        self.assert_failure("-S")

    def test_imports_failure_after_display_limit_stops_recon(self):
        result = self.assert_failure("-i")
        self.assertEqual(sum(line.startswith("rabin2:-i:") for line in result.stdout.splitlines()), 2)

    def test_exports_failure_stops_recon(self):
        self.assert_failure("-E")

    def test_strings_failure_after_display_limit_stops_recon(self):
        result = self.assert_failure("-zz")
        self.assertEqual(sum(line.startswith("rabin2:-zz:") for line in result.stdout.splitlines()), 3)

    def test_analysis_failure_is_not_success(self):
        self.assert_failure("-A")

    def test_bootstrap_diagnostics_do_not_pollute_the_tool_spec(self):
        result = self.run_recon(bootstrap="success")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.installed.exists())
        self.assertIn("INFO: rabin2 not found", result.stdout)
        self.assertIn("bootstrap fixture completed", result.stdout)
        self.assertEqual(self.started_stages(), STAGES)

    def test_failed_bootstrap_does_not_run_native_tools(self):
        result = self.run_recon(bootstrap="failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.installed.exists())
        self.assertEqual(self.started_stages(), [])
        self.assertIn("rabin2", result.stderr)

    def test_failure_after_successful_bootstrap_is_reported(self):
        self.assert_failure("-i", bootstrap="success")
        self.assertTrue(self.installed.exists())

    def test_default_mode_does_not_resolve_or_run_analysis(self):
        result = self.run_recon(analyze=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.started_stages(), STAGES[:-1])
        self.assertEqual(self.discovery_log.read_text().splitlines(), ["rabin2"])

    def test_zero_display_limit_still_observes_native_failure(self):
        result = self.assert_failure("-i", imports_limit=0)
        self.assertFalse(any(line.startswith("rabin2:-i:") for line in result.stdout.splitlines()))


if __name__ == "__main__":
    unittest.main()
