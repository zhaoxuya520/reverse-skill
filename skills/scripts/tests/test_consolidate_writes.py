"""Consolidation keeps a recoverable case when a write fails."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1]
PWSH = os.environ.get("REVERSE_TEST_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")
SPEC = importlib.util.spec_from_file_location("consolidate_evidence", SCRIPTS / "consolidate_evidence.py")
CONSOLIDATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONSOLIDATE)

# Extract the actual transaction functions, then replace only their filesystem
# boundary for deterministic failures. Complete CLI success and OS permission
# failures are tested separately without replacing any production function.
PS_FAULT_DRIVER = r"""
param([string]$Script, [string]$Config)
$ErrorActionPreference = 'Stop'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($Script, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors -join '; ') }
foreach ($statement in $ast.EndBlock.Statements) {
    if ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) {
        . ([ScriptBlock]::Create($statement.Extent.Text))
    }
}
$configData = Get-Content -LiteralPath $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$records = @($configData.records | ForEach-Object {
    $original = $null
    if ($null -ne $_.original) { $original = [Text.Encoding]::UTF8.GetBytes($_.original) }
    [pscustomobject]@{ Path = $_.path; Data = [Text.Encoding]::UTF8.GetBytes($_.data); Original = $original }
})
$script:fault = $configData.fault
$script:fired = $false
$script:realReplace = (Get-Item Function:Replace-ConsolidationRecord).ScriptBlock
$script:realStage = (Get-Item Function:New-ConsolidationTemporaryFile).ScriptBlock
function Replace-ConsolidationRecord([string]$Source, [string]$Destination, [string]$Backup) {
    $leaf = [IO.Path]::GetFileName($Destination)
    if ($script:fault -eq 'inspect-acls') {
        $script:fired = $true
        $access = [Security.AccessControl.AccessControlSections]::Access
        $expected = (Get-Acl -LiteralPath $Destination).GetSecurityDescriptorSddlForm($access)
        foreach ($staged in @($Source, $Backup)) {
            if ($staged -and (Get-Acl -LiteralPath $staged).GetSecurityDescriptorSddlForm($access) -cne $expected) {
                throw "Staged file DACL differs before publication: $staged"
            }
        }
    }
    if (-not $script:fired -and $leaf -eq 'E-002.md' -and $script:fault -ne 'stage') {
        $script:fired = $true
        if ($script:fault -eq 'after-replace') { & $script:realReplace $Source $Destination $Backup }
        throw [IO.IOException]::new('controlled second Evidence replacement failure')
    }
    if ($script:fired -and (($script:fault -eq 'restore-evidence' -and $leaf -eq 'E-001.md') -or
                          ($script:fault -eq 'restore-consumed' -and $leaf -eq 'E-001.md') -or
                          ($script:fault -eq 'restore-report' -and $leaf -eq 'report.md'))) {
        if ($script:fault -eq 'restore-consumed') { & $script:realReplace $Source $Destination $Backup }
        throw [IO.IOException]::new('controlled restoration failure')
    }
    & $script:realReplace $Source $Destination $Backup
}
function New-ConsolidationTemporaryFile([string]$Path, [byte[]]$Data, [Collections.Generic.List[string]]$Temporary) {
    if ($script:fault -eq 'stage' -and [IO.Path]::GetFileName($Path) -eq 'E-002.md') {
        $script:fired = $true
        throw [IO.IOException]::new('controlled staging failure')
    }
    & $script:realStage $Path $Data $Temporary
}
function Get-Item {
    [CmdletBinding()]
    param([string]$LiteralPath, [switch]$Force)
    $item = Microsoft.PowerShell.Management\Get-Item @PSBoundParameters
    if ($script:fault -eq 'ownership' -and [IO.Path]::GetFileName($LiteralPath) -eq 'E-002.md') {
        $script:fired = $true
        return [pscustomobject]@{ UnixStat = [pscustomobject]@{ UserId = $item.UnixStat.UserId + 1; GroupId = $item.UnixStat.GroupId } }
    }
    return $item
}
$failure = $null
try { Publish-Consolidation $records } catch { $failure = $_.Exception.Message }
[pscustomobject]@{ fired = $script:fired; error = $failure } | ConvertTo-Json -Compress
"""


class ConsolidateWriteTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="consolidate-write-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def fixture(self, name, existing_report=False):
        case = self.root / name
        (case / "evidence").mkdir(parents=True)
        (case / "report").mkdir()
        records = {
            case / "evidence/E-001.md": b"\xef\xbb\xbf# E-001\r\n- status: raw\r\n- observation: first\r\n",
            case / "evidence/E-002.md": b"# E-002\n- status: raw\n- observation: second\n",
        }
        if existing_report:
            records[case / "report/report.md"] = b"\xef\xbb\xbf# Existing report\r\n\r\n## Findings\r\n\r\n### F-OLD\r\nKeep this.\r\n"
        for number, (path, data) in enumerate(records.items()):
            path.write_bytes(data)
            if os.name != "nt":
                path.chmod(0o640 if number % 2 == 0 else 0o600)
        return case, records

    def runtimes(self):
        return ("python", "powershell") if PWSH else ("python",)

    def cli(self, runtime, case, description="inert fixture"):
        if runtime == "python":
            command = [sys.executable, str(SCRIPTS / "consolidate_evidence.py"), "--case-root", str(case),
                       "--evidence-ids", "E-001,E-002", "--finding-id", "F-NEW", "--title", "fixture", "--description", description]
        else:
            command = [PWSH, "-NoLogo", "-NoProfile", "-File", str(SCRIPTS / "consolidate-evidence.ps1"),
                       "-CaseRoot", str(case), "-EvidenceIds", "E-001,E-002", "-FindingId", "F-NEW",
                       "-Title", "fixture", "-Description", description]
        return subprocess.run(command, capture_output=True, text=True, encoding="utf-8", timeout=30,
                              env=dict(os.environ, POWERSHELL_TELEMETRY_OPTOUT="true"))

    def assert_originals(self, originals, modes):
        for path, data in originals.items():
            self.assertEqual(path.read_bytes(), data, str(path))
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), modes[path], str(path))

    def assert_no_temporary_files(self, case):
        self.assertEqual(list(case.rglob("*.consolidate-*")), [])

    def test_real_clis_preserve_existing_bytes_format_and_modes(self):
        for runtime in self.runtimes():
            for existing in (False, True):
                with self.subTest(runtime=runtime, existing_report=existing):
                    case, originals = self.fixture(f"success-{runtime}-{existing}", existing)
                    modes = {p: stat.S_IMODE(p.stat().st_mode) for p in originals}
                    result = self.cli(runtime, case, description="first line\r\nsecond line")
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    for path, before in originals.items():
                        after = path.read_bytes()
                        if path.parent.name == "evidence":
                            self.assertEqual(after, before.replace(b"status: raw", b"status: superseded by F-NEW"))
                        else:
                            self.assertTrue(after.startswith(before.rstrip() + b"\r\n\r\n"))
                            self.assertNotIn(b"\n", after.replace(b"\r\n", b""))
                            self.assertNotIn(b"\r\r\n", after)
                        self.assertEqual(stat.S_IMODE(path.stat().st_mode), modes[path])
                    report = (case / "report/report.md").read_text(encoding="utf-8-sig")
                    self.assertEqual(report.count("### F-NEW"), 1)
                    self.assertIn("evidence_ids: E-001, E-002", report)
                    self.assertIn("first line\nsecond line", report)
                    self.assert_no_temporary_files(case)

    @unittest.skipIf(os.name == "nt" or (hasattr(os, "geteuid") and os.geteuid() == 0), "requires ordinary POSIX permissions")
    def test_real_clis_leave_evidence_unchanged_when_report_directory_is_read_only(self):
        for runtime in self.runtimes():
            with self.subTest(runtime=runtime):
                case, originals = self.fixture(f"permission-{runtime}")
                modes = {p: stat.S_IMODE(p.stat().st_mode) for p in originals}
                report_dir = case / "report"
                report_dir.chmod(0o500)
                try:
                    result = self.cli(runtime, case)
                finally:
                    report_dir.chmod(0o700)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Marked E-", result.stdout)
                self.assert_originals(originals, modes)
                self.assertFalse((report_dir / "report.md").exists())
                self.assert_no_temporary_files(case)

    def transaction(self, runtime, case, originals, fault):
        report = case / "report/report.md"
        records = [(report, (originals.get(report, b"# Report\n") + b"\n### F-NEW\n"), originals.get(report))]
        records.extend((path, data.replace(b"status: raw", b"status: superseded by F-NEW"), data)
                       for path, data in originals.items() if path.parent.name == "evidence")
        if runtime == "powershell":
            driver = self.root / "fault-driver.ps1"
            driver.write_text(PS_FAULT_DRIVER, encoding="utf-8-sig")
            config = self.root / "fault.json"
            config.write_text(json.dumps({"fault": fault, "records": [
                {"path": str(path), "data": data.decode("utf-8"),
                 "original": None if original is None else original.decode("utf-8")}
                for path, data, original in records]}), encoding="utf-8")
            result = subprocess.run([PWSH, "-NoLogo", "-NoProfile", "-File", str(driver), "-Script",
                                     str(SCRIPTS / "consolidate-evidence.ps1"), "-Config", str(config)],
                                    capture_output=True, text=True, encoding="utf-8", timeout=30,
                                    env=dict(os.environ, POWERSHELL_TELEMETRY_OPTOUT="true"))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observation = json.loads(result.stdout)
            self.assertTrue(observation["fired"], result.stdout + result.stderr)
            return observation["error"]
        real_replace = CONSOLIDATE.replace_record
        real_write = Path.write_bytes
        real_stat = Path.stat
        fired = False

        def replace(source, destination, backup=None):
            nonlocal fired
            if fault == "inspect-acls":
                fired = True
                observer = self.root / "inspect-staged-acls.ps1"
                observer.write_text("""param([string]$Source, [string]$Destination, [string]$Backup)
$ErrorActionPreference = 'Stop'
$access = [Security.AccessControl.AccessControlSections]::Access
$expected = (Get-Acl -LiteralPath $Destination).GetSecurityDescriptorSddlForm($access)
foreach ($staged in @($Source, $Backup)) {
    if ($staged -and (Get-Acl -LiteralPath $staged).GetSecurityDescriptorSddlForm($access) -cne $expected) {
        throw "Staged file DACL differs before publication: $staged"
    }
}
""", encoding="utf-8-sig")
                command = [PWSH, "-NoLogo", "-NoProfile", "-File", str(observer),
                           "-Source", str(source), "-Destination", str(destination)]
                if backup is not None:
                    command.extend(["-Backup", str(backup)])
                result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", timeout=30,
                                        env=dict(os.environ, POWERSHELL_TELEMETRY_OPTOUT="true"))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            if not fired and destination.name == "E-002.md" and fault != "stage":
                fired = True
                if fault == "after-replace":
                    real_replace(source, destination, backup)
                raise OSError("controlled second Evidence replacement failure")
            if fired and ((fault == "restore-evidence" and destination.name == "E-001.md") or
                          (fault == "restore-consumed" and destination.name == "E-001.md") or
                          (fault == "restore-report" and destination.name == "report.md")):
                if fault == "restore-consumed":
                    real_replace(source, destination, backup)
                raise OSError("controlled restoration failure")
            real_replace(source, destination, backup)

        def write(path, data):
            nonlocal fired
            if fault == "stage" and path.name.startswith(".E-002.md.consolidate-"):
                fired = True
                raise OSError("controlled staging failure")
            return real_write(path, data)

        def changed_owner(path, *args, **kwargs):
            nonlocal fired
            result = real_stat(path, *args, **kwargs)
            if fault == "ownership" and path.name == "E-002.md":
                fired = True
                fields = list(result)
                fields[4] += 1
                return os.stat_result(fields)
            return result

        with patch.object(CONSOLIDATE, "replace_record", replace), patch.object(Path, "write_bytes", write), patch.object(Path, "stat", changed_owner):
            if fault == "inspect-acls":
                CONSOLIDATE.publish_consolidation(records)
                self.assertTrue(fired)
                return None
            with self.assertRaises(OSError) as raised:
                CONSOLIDATE.publish_consolidation(records)
        self.assertTrue(fired)
        return str(raised.exception)

    @unittest.skipIf(os.name == "nt", "POSIX ownership boundary")
    def test_changed_ownership_is_rejected_before_publication(self):
        for runtime in self.runtimes():
            with self.subTest(runtime=runtime):
                case, originals = self.fixture(f"ownership-{runtime}", existing_report=True)
                modes = {p: stat.S_IMODE(p.stat().st_mode) for p in originals}
                self.assertIn("Cannot safely preserve file ownership", self.transaction(runtime, case, originals, "ownership"))
                self.assert_originals(originals, modes)
                self.assert_no_temporary_files(case)

    def test_staging_and_publish_failures_restore_existing_and_new_reports(self):
        for runtime in self.runtimes():
            for existing in (False, True):
                for fault in ("stage", "replace", "after-replace"):
                    with self.subTest(runtime=runtime, existing_report=existing, fault=fault):
                        case, originals = self.fixture(f"recovery-{runtime}-{existing}-{fault}", existing)
                        modes = {p: stat.S_IMODE(p.stat().st_mode) for p in originals}
                        error = self.transaction(runtime, case, originals, fault)
                        self.assertIn("controlled", error)
                        self.assert_originals(originals, modes)
                        if not existing:
                            self.assertFalse((case / "report/report.md").exists())
                        self.assert_no_temporary_files(case)

    def test_failed_evidence_restoration_keeps_finding_and_exact_backups(self):
        for runtime in self.runtimes():
            for existing in (False, True):
                with self.subTest(runtime=runtime, existing_report=existing):
                    case, originals = self.fixture(f"restore-evidence-{runtime}-{existing}", existing)
                    error = self.transaction(runtime, case, originals, "restore-evidence")
                    self.assertIn("Could not restore", error)
                    self.assertIn("Kept Finding", error)
                    self.assertIn(b"superseded by F-NEW", (case / "evidence/E-001.md").read_bytes())
                    self.assertEqual((case / "evidence/E-002.md").read_bytes(), originals[case / "evidence/E-002.md"])
                    self.assertIn(b"### F-NEW", (case / "report/report.md").read_bytes())
                    backups = list(case.rglob("*.consolidate-*"))
                    expected = [originals[case / "evidence/E-001.md"]]
                    if existing:
                        expected.append(originals[case / "report/report.md"])
                    self.assertCountEqual([p.read_bytes() for p in backups], expected)
                    for path in backups:
                        self.assertIn(str(path), error)

    def test_failed_report_restoration_retains_its_original_bytes(self):
        for runtime in self.runtimes():
            with self.subTest(runtime=runtime):
                case, originals = self.fixture(f"restore-report-{runtime}", existing_report=True)
                error = self.transaction(runtime, case, originals, "restore-report")
                self.assertIn("Could not restore", error)
                for path, data in originals.items():
                    if path.parent.name == "evidence":
                        self.assertEqual(path.read_bytes(), data)
                backups = list(case.rglob("*.consolidate-*"))
                self.assertEqual(len(backups), 1)
                self.assertEqual(backups[0].read_bytes(), originals[case / "report/report.md"])
                self.assertIn(str(backups[0]), error)

    def test_consumed_backup_is_not_reported_as_available(self):
        for runtime in self.runtimes():
            with self.subTest(runtime=runtime):
                case, originals = self.fixture(f"restore-consumed-{runtime}", existing_report=True)
                error = self.transaction(runtime, case, originals, "restore-consumed")
                self.assertIn("backup unavailable at", error)
                for path, data in originals.items():
                    if path.parent.name == "evidence":
                        self.assertEqual(path.read_bytes(), data)
                backups = list(case.rglob("*.consolidate-*"))
                self.assertEqual(len(backups), 1)
                self.assertEqual(backups[0].read_bytes(), originals[case / "report/report.md"])
                self.assertEqual(error.count("original bytes retained at "), 1)
                self.assertIn("original bytes retained at " + str(backups[0]), error)

    def test_keyboard_interrupt_keeps_backups_for_attempted_records(self):
        case, originals = self.fixture("interrupted", existing_report=True)
        report = case / "report/report.md"
        records = [(report, originals[report] + b"\r\n### F-NEW\r\n", originals[report])]
        records.extend((path, data.replace(b"status: raw", b"status: superseded by F-NEW"), data)
                       for path, data in originals.items() if path.parent.name == "evidence")
        real_replace = CONSOLIDATE.replace_record

        def interrupt(source, destination, backup=None):
            if destination.name == "E-002.md":
                raise KeyboardInterrupt
            real_replace(source, destination, backup)

        diagnostics = io.StringIO()
        with patch.object(CONSOLIDATE, "replace_record", interrupt), contextlib.redirect_stderr(diagnostics):
            with self.assertRaises(KeyboardInterrupt):
                CONSOLIDATE.publish_consolidation(records)
        backups = list(case.rglob("*.consolidate-*"))
        self.assertCountEqual([p.read_bytes() for p in backups], list(originals.values()))
        for path in backups:
            self.assertIn(str(path), diagnostics.getvalue())
        self.assertIn(b"### F-NEW", report.read_bytes())
        self.assertIn(b"superseded by F-NEW", (case / "evidence/E-001.md").read_bytes())
        self.assertEqual((case / "evidence/E-002.md").read_bytes(), originals[case / "evidence/E-002.md"])

    @unittest.skipUnless(os.name == "nt" and PWSH, "requires native Windows ACLs")
    def test_native_windows_clis_keep_protected_destination_acls(self):
        script = self.root / "acl.ps1"
        script.write_text("""param([string]$Case, [switch]$Protect)
$ErrorActionPreference = 'Stop'
$result = @{}
Get-ChildItem -LiteralPath $Case -Recurse -File | ForEach-Object {
    $acl = Get-Acl -LiteralPath $_.FullName
    if ($Protect) {
        $acl.SetAccessRuleProtection($true, $true)
        Set-Acl -LiteralPath $_.FullName -AclObject $acl
        $acl = Get-Acl -LiteralPath $_.FullName
    }
    $result[$_.FullName] = @{ sddl = $acl.Sddl; protected = $acl.AreAccessRulesProtected }
}
$result | ConvertTo-Json -Compress
""", encoding="utf-8-sig")

        def acls(case, protect=False):
            command = [PWSH, "-NoLogo", "-NoProfile", "-File", str(script), "-Case", str(case)]
            if protect:
                command.append("-Protect")
            result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", timeout=30,
                                    env=dict(os.environ, POWERSHELL_TELEMETRY_OPTOUT="true"))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return json.loads(result.stdout)

        for runtime in self.runtimes():
            for operation in ("success", "staging", "rollback"):
                with self.subTest(runtime=runtime, operation=operation):
                    case, originals = self.fixture(f"windows-acl-{runtime}-{operation}", existing_report=True)
                    before = acls(case, protect=True)
                    self.assertTrue(all(value["protected"] for value in before.values()))
                    if operation == "success":
                        result = self.cli(runtime, case)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    elif operation == "staging":
                        self.assertIsNone(self.transaction(runtime, case, originals, "inspect-acls"))
                    else:
                        self.assertIn("Original records restored", self.transaction(runtime, case, originals, "replace"))
                        for path, data in originals.items():
                            self.assertEqual(path.read_bytes(), data)
                    self.assertEqual(acls(case), before)

        # Use the real native API error path without changing an existing record.
        destination = self.root / "not-created.md"
        source = next(iter(originals))
        before = source.read_bytes()
        with self.assertRaises(OSError):
            CONSOLIDATE.copy_windows_dacl(source, destination)
        self.assertEqual(source.read_bytes(), before)
        self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
