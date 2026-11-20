"""Offline APK decode status tests; no SDK, installation, or device is used."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
POWERSHELL = (shutil.which("powershell") if os.name == "nt" else None) or shutil.which("pwsh") or shutil.which("powershell")
BASH = shutil.which("bash") if os.name != "nt" else None

DISCOVERY = r"""
function Resolve-ReverseToolSpec {
    param([string]$Name)
    if ($Name -notin @('jadx', 'apktool')) { throw 'Unexpected fixture tool' }
    return [pscustomobject]@{
        Name = $Name
        Available = $true
        Command = $env:APK_DECODE_TEST_PYTHON
        PrefixArgs = @($env:APK_DECODE_TEST_TOOL, $Name)
    }
}
"""

TOOL = r"""
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).stem
args = sys.argv[1:]
if name == 'fake-tool':
    name = args.pop(0)
with open(os.environ['APK_DECODE_TEST_LOG'], 'a', encoding='utf-8') as log:
    log.write(json.dumps([name, args]) + '\n')
exit_code = int(os.environ['APK_DECODE_TEST_' + name.upper() + '_EXIT'])
if name == 'jadx':
    out = Path(args[args.index('-d') + 1])
    out.mkdir(parents=True)
    (out / 'Fixture.java').write_text('class Fixture {}\n', encoding='utf-8')
elif name == 'apktool' and exit_code == 0:
    out = Path(args[args.index('-o') + 1])
    out.mkdir(parents=True)
    (out / 'AndroidManifest.xml').write_text('<manifest package="fixture.app"><application/></manifest>', encoding='utf-8')
    (out / 'smali').mkdir()
if exit_code:
    print(name + ': synthetic decode failure', file=sys.stderr)
sys.exit(exit_code)
"""


class DecodeExitStatusTests(unittest.TestCase):
    def launchers(self):
        result = [name for name, executable in (("bash", BASH), ("powershell", POWERSHELL)) if executable]
        if not result:
            self.skipTest("Neither Bash nor PowerShell is available")
        return result

    def run_decode(self, launcher, jadx_exit=0, apktool_exit=0, skip_apktool=False):
        with tempfile.TemporaryDirectory(prefix="apk decode fixture ") as temporary:
            root = Path(temporary)
            scripts = root / "skills/apk-reverse/scripts"
            scripts.mkdir(parents=True)
            for filename in ("decode.sh", "decode.ps1"):
                shutil.copyfile(SCRIPTS / filename, scripts / filename)
            discovery = root / "skills/scripts/lib/ToolDiscovery.ps1"
            discovery.parent.mkdir(parents=True)
            discovery.write_text(DISCOVERY, encoding="utf-8")
            (root / "skills/scripts/bootstrap-reverse.ps1").write_text("throw 'Bootstrap is disabled in this offline fixture'\n", encoding="utf-8")
            bootstrap = root / "kali/scripts/bootstrap-reverse.sh"
            bootstrap.parent.mkdir(parents=True)
            bootstrap.write_text("#!/usr/bin/env bash\necho 'Unexpected fixture bootstrap' >&2\nexit 99\n", encoding="utf-8")
            bootstrap.chmod(0o755)
            fake = root / "fake-tool.py"
            fake.write_text(TOOL, encoding="utf-8")
            bin_dir = root / "bin"
            bin_dir.mkdir()
            for name in ("jadx", "apktool"):
                tool = bin_dir / name
                tool.write_text(f"#!{sys.executable}\n" + TOOL, encoding="utf-8")
                tool.chmod(0o755)
            apk = root / "input with spaces.apk"
            apk.write_bytes(b"inert fixture, never opened by a real APK tool")
            out = root / "output"
            log = root / "calls.jsonl"
            env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ.get("PATH", ""),
                       POWERSHELL_TELEMETRY_OPTOUT="true", APK_DECODE_TEST_PYTHON=sys.executable,
                       APK_DECODE_TEST_TOOL=str(fake), APK_DECODE_TEST_LOG=str(log),
                       APK_DECODE_TEST_JADX_EXIT=str(jadx_exit), APK_DECODE_TEST_APKTOOL_EXIT=str(apktool_exit))
            if launcher == "bash":
                command = [BASH, str(scripts / "decode.sh"), str(apk), "--name", "fixture", "--out", str(out)]
                if skip_apktool:
                    command.append("--skip-apktool")
            else:
                command = [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(scripts / "decode.ps1"),
                           "-ApkPath", str(apk), "-Name", "fixture", "-OutRoot", str(out)]
                if skip_apktool:
                    command.append("-SkipApktool")
            result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0 if skip_apktool else apktool_exit, result.stdout + result.stderr)
            self.assertIn("jadx_exit_code=" + str(jadx_exit), result.stdout)
            self.assertIn("java_files=1", result.stdout)
            self.assertEqual((out / "fixture/jadx/Fixture.java").read_text(), "class Fixture {}\n")
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual([name for name, _ in calls], ["jadx"] if skip_apktool else ["jadx", "apktool"])
            if not skip_apktool:
                self.assertIn("apktool_exit_code=" + str(apktool_exit), result.stdout)
                self.assertEqual((out / "fixture/apktool/AndroidManifest.xml").exists(), apktool_exit == 0)
            if jadx_exit and launcher == "powershell":
                self.assertIn("warning=jadx returned non-zero exit code", result.stdout)

    def test_apktool_failure_has_a_failure_status_and_keeps_the_summary(self):
        for launcher in self.launchers():
            with self.subTest(launcher=launcher):
                self.run_decode(launcher, apktool_exit=17)

    def test_apktool_failure_keeps_partial_jadx_artifacts(self):
        for launcher in self.launchers():
            with self.subTest(launcher=launcher):
                self.run_decode(launcher, jadx_exit=2, apktool_exit=17)

    def test_partial_jadx_with_successful_apktool_remains_successful(self):
        for launcher in self.launchers():
            with self.subTest(launcher=launcher):
                self.run_decode(launcher, jadx_exit=2)

    def test_successful_decode_remains_successful(self):
        for launcher in self.launchers():
            with self.subTest(launcher=launcher):
                self.run_decode(launcher)

    def test_explicitly_skipping_apktool_remains_successful(self):
        for launcher in self.launchers():
            with self.subTest(launcher=launcher):
                self.run_decode(launcher, jadx_exit=2, apktool_exit=17, skip_apktool=True)


if __name__ == "__main__":
    unittest.main()
