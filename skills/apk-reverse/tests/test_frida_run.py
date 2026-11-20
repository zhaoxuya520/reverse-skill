"""Exercise the Frida launchers offline; no device or instrumentation is used."""

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


class FridaRunTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.capture = self.root / "arguments.json"
        self.script = self.root / "script with spaces.js"
        self.script.write_text("// Offline argument fixture.\n", encoding="utf-8")
        shim = self.root / "capture.py"
        shim.write_text(
            "import json, os, pathlib, sys\n"
            "pathlib.Path(os.environ['FRIDA_TEST_CAPTURE']).write_text(json.dumps(sys.argv[1:]), encoding='utf-8')\n"
            "sys.exit(int(os.environ.get('FRIDA_TEST_EXIT', '0')))\n",
            encoding="utf-8",
        )
        for tool in ("frida", "frida-ps", "frida-ls-devices"):
            if os.name == "nt":
                (self.bin / (tool + ".cmd")).write_text(
                    f'@"{sys.executable}" "{shim}" %*\n', encoding="utf-8"
                )
            else:
                executable = self.bin / tool
                executable.write_text(
                    f"#!{sys.executable}\n" + shim.read_text(encoding="utf-8"), encoding="utf-8"
                )
                executable.chmod(0o755)
        self.env = dict(
            os.environ,
            PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""),
            FRIDA_TEST_CAPTURE=str(self.capture),
        )

    def check_launcher(self, launcher):
        for spawn, pause in ((True, False), (True, True), (False, False)):
            with self.subTest(launcher=launcher, spawn=spawn, pause=pause):
                if launcher == "bash":
                    command = [BASH, str(SCRIPTS / "frida-run.sh"), "--package", "com.example.fixture",
                               "--script", str(self.script), "--usb"]
                    command += ["--spawn"] if spawn else []
                    command += ["--pause"] if pause else []
                else:
                    command = [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                               str(SCRIPTS / "frida-run.ps1"), "-Package", "com.example.fixture",
                               "-ScriptPath", str(self.script), "-Usb"]
                    command += ["-Spawn"] if spawn else []
                    command += ["-Pause"] if pause else []
                result = subprocess.run(command, env=self.env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                arguments = json.loads(self.capture.read_text(encoding="utf-8"))
                self.assertNotIn("--no-pause", arguments)
                self.assertEqual("--pause" in arguments, pause)
                self.assertEqual(arguments[:3], ["-U", "-f" if spawn else "-n", "com.example.fixture"])
                self.assertEqual(arguments[3:5], ["-l", str(self.script)])

    @unittest.skipUnless(BASH, "Bash is unavailable")
    def test_bash_pause_and_resume(self):
        self.check_launcher("bash")

    @unittest.skipUnless(POWERSHELL, "PowerShell is unavailable")
    def test_powershell_pause_and_resume(self):
        self.check_launcher("powershell")


if __name__ == "__main__":
    unittest.main()
