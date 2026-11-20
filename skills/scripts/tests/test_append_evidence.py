"""Exercise multiline Evidence fields through the actual PowerShell CLI."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


PWSH = os.environ.get("REVERSE_TEST_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")
SCRIPT = Path(__file__).resolve().parents[1] / "append-evidence.ps1"


@unittest.skipUnless(PWSH, "PowerShell is required for the actual Evidence writer")
class AppendEvidenceTests(unittest.TestCase):
    def run_append(self, root, **fields):
        arguments = [PWSH, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
                     "-CaseRoot", str(root), "-Id", "E-001", "-Title", "fixture", "-ReproCommand", "offline fixture"]
        for name, value in fields.items():
            arguments.extend(["-" + name, str(value)])
        return subprocess.run(arguments, capture_output=True, text=True, timeout=30,
                              env={**os.environ, "POWERSHELL_TELEMETRY_OPTOUT": "true"})

    def assert_block(self, text, name, value, following):
        normalized = value.replace("\r\n", "\n")
        expected = "\n".join("    " + line for line in normalized.split("\n"))
        self.assertIn(f"- {name}: |\n{expected}" + following, text)

    def test_file_fields_preserve_all_lines_and_metadata_boundaries(self):
        for newline in ("\n", "\r\n"):
            with self.subTest(newline=repr(newline)), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                values = {
                    "ReproCommandFile": "python inspect.py \\\n  --offline\n",
                    "RawExcerptFile": "Traceback:\n  File 'fixture.py'\n\nValueError: 中文\n",
                    "NotesFile": "Quoted observation:\n- status: pending\n\nFollow-up remains local.",
                }
                paths = {}
                for name, value in values.items():
                    source = root / f"{name}.txt"
                    source.write_bytes(value.replace("\n", newline).encode("utf-8"))
                    paths[name] = source
                result = self.run_append(root, **paths)
                self.assertEqual(result.returncode, 0, result.stderr)
                record = (root / "evidence/E-001.md").read_text(encoding="utf-8-sig")
                self.assert_block(record, "repro_command", values["ReproCommandFile"], "\n- raw_excerpt: |")
                self.assert_block(record, "raw_excerpt", values["RawExcerptFile"], "\n- linked_workitem: n/a")
                self.assert_block(record, "notes", values["NotesFile"], "")
                self.assertEqual([line for line in record.splitlines() if line.startswith("- status:")],
                                 ["- status: observed"])

    def test_inline_excerpt_keeps_blank_lines_and_existing_indentation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            excerpt = "first\n\n  indented second\nlast"
            result = self.run_append(root, RawExcerpt=excerpt)
            self.assertEqual(result.returncode, 0, result.stderr)
            record = (root / "evidence/E-001.md").read_text(encoding="utf-8-sig")
            self.assert_block(record, "raw_excerpt", excerpt, "\n- linked_workitem: n/a")

    def test_single_line_defaults_and_immutable_record_are_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.run_append(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            record_path = root / "evidence/E-001.md"
            index_path = root / "evidence/INDEX.md"
            original = record_path.read_bytes()
            original_index = index_path.read_bytes()
            record = original.decode("utf-8-sig").replace("\r\n", "\n")
            self.assert_block(record, "repro_command", "offline fixture", "\n- raw_excerpt: |")
            self.assert_block(record, "raw_excerpt", "n/a", "\n- linked_workitem: n/a")
            self.assert_block(record, "notes", "n/a", "")
            repeated = self.run_append(root, RawExcerpt="changed\nexcerpt")
            self.assertNotEqual(repeated.returncode, 0)
            self.assertEqual(record_path.read_bytes(), original)
            self.assertEqual(index_path.read_bytes(), original_index)


if __name__ == "__main__":
    unittest.main()
