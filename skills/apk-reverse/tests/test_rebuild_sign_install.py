"""Offline rebuild/sign launcher regressions with recording build tools."""

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

TOOL = """import json, os, pathlib, shutil, sys
name = pathlib.Path(sys.argv[0]).stem
args = sys.argv[1:]
with open(os.environ['APK_TEST_LOG'], 'a', encoding='utf-8') as log:
    log.write(json.dumps([name, args]) + '\\n')
if name == 'keytool':
    pathlib.Path(args[args.index('-keystore') + 1]).write_bytes(b'fixture-key')
elif name == 'apktool':
    pathlib.Path(args[args.index('-o') + 1]).write_bytes(b'unsigned-fixture')
elif name == 'zipalign':
    shutil.copyfile(args[-2], args[-1])
elif name == 'apksigner' and args[0] == 'sign':
    pathlib.Path(args[args.index('--out') + 1]).write_bytes(pathlib.Path(args[-1]).read_bytes() + b'-signed')
elif name == 'apksigner' and args[0] == 'verify':
    assert pathlib.Path(args[-1]).read_bytes().endswith(b'-signed')
"""


class RebuildSigningTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.project = self.root / "project"
        self.project.mkdir()
        self.out = self.root / "output"
        self.log = self.root / "tools.jsonl"
        for tool in ("apktool", "zipalign", "apksigner", "keytool", "adb"):
            if os.name == "nt":
                script = self.bin / (tool + ".py")
                script.write_text(TOOL, encoding="utf-8")
                (self.bin / (tool + ".cmd")).write_text(f'@"{sys.executable}" "{script}" %*\n', encoding="utf-8")
            else:
                script = self.bin / tool
                script.write_text(f"#!{sys.executable}\n" + TOOL, encoding="utf-8")
                script.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""),
                        APK_TEST_LOG=str(self.log), APK_TEST_DISCOVERY=str(self.root / "adb-discovery.txt"),
                        USERPROFILE=str(self.root / "profile"), LOCALAPPDATA=str(self.root / "local-app-data"))

    def run_launcher(self, launcher, keystore, install=False, forbid_adb=False):
        if launcher == "bash":
            command = [BASH, str(SCRIPTS / "rebuild-sign-install.sh"), str(self.project),
                       "--out", str(self.out), "--keystore", str(keystore)]
            if install:
                command += ["--install", "--device", "offline-fixture"]
        else:
            harness = self.root / "invoke.ps1"
            harness.write_text("""$ErrorActionPreference = 'Stop'
function powershell.exe { throw 'Bootstrap is disabled in the offline fixture.' }
if ($env:APK_TEST_FORBID_ADB -eq '1') {
    function Get-Command {
        [CmdletBinding()]
        param([string]$Name)
        if ($Name -eq 'adb') {
            [System.IO.File]::WriteAllText($env:APK_TEST_DISCOVERY, 'requested')
            return
        }
        Microsoft.PowerShell.Core\\Get-Command -Name $Name -ErrorAction SilentlyContinue
    }
}
$parameters = @{
    ProjectDir = $env:APK_TEST_PROJECT
    OutDir = $env:APK_TEST_OUT
    KeystorePath = $env:APK_TEST_KEYSTORE
}
if ($env:APK_TEST_INSTALL -eq '1') {
    $parameters.Install = $true
    $parameters.DeviceSerial = 'offline-fixture'
}
& $env:APK_TEST_SCRIPT @parameters
exit $LASTEXITCODE
""", encoding="utf-8")
            self.env.update(APK_TEST_FORBID_ADB=str(int(forbid_adb)), APK_TEST_INSTALL=str(int(install)),
                            APK_TEST_PROJECT=str(self.project), APK_TEST_OUT=str(self.out),
                            APK_TEST_KEYSTORE=str(keystore), APK_TEST_SCRIPT=str(SCRIPTS / "rebuild-sign-install.ps1"))
            command = [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(harness)]
        result = subprocess.run(command, cwd=self.root, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.out / "project-signed.apk").read_bytes(), b"unsigned-fixture-signed")
        calls = [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]
        self.assertEqual([name for name, _ in calls].count("adb"), int(install))
        if forbid_adb:
            self.assertFalse((self.root / "adb-discovery.txt").exists(), "offline rebuild looked up adb")
        if install:
            self.assertEqual(calls[-1], ["adb", ["-s", "offline-fixture", "install", str(self.out / "project-signed.apk")]])

    @unittest.skipUnless(BASH, "Bash is unavailable")
    def test_bash_creates_nested_keystore_parent(self):
        keystore = self.root / "new keys" / "nested" / "debug.keystore"
        self.run_launcher("bash", keystore)
        self.assertEqual(keystore.read_bytes(), b"fixture-key")

    @unittest.skipUnless(POWERSHELL, "PowerShell is unavailable")
    def test_powershell_accepts_bare_relative_keystore(self):
        self.run_launcher("powershell", "debug.keystore")
        self.assertEqual((self.root / "debug.keystore").read_bytes(), b"fixture-key")

    @unittest.skipUnless(POWERSHELL, "PowerShell is unavailable")
    def test_powershell_signs_without_discovering_adb(self):
        keystore = self.root / "existing.keystore"
        keystore.write_bytes(b"existing-key")
        self.run_launcher("powershell", keystore, forbid_adb=True)
        self.assertEqual(keystore.read_bytes(), b"existing-key")

    @unittest.skipUnless(POWERSHELL, "PowerShell is unavailable")
    def test_powershell_keeps_explicit_install(self):
        keystore = self.root / "existing.keystore"
        keystore.write_bytes(b"existing-key")
        self.run_launcher("powershell", keystore, install=True)


if __name__ == "__main__":
    unittest.main()
