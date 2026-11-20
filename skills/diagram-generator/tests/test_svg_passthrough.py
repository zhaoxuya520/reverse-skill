"""Exercise SVG passthrough through the public CLI without renderer dependencies."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "render_diagram.py"
SVG = b'<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><title>fixture</title></svg>\n'


class SvgPassthroughTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.source = self.root / "source diagram.svg"
        self.source.write_bytes(SVG)

    def run_cli(self, *arguments):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(self.source), *map(str, arguments)],
            text=True, capture_output=True,
        )

    def test_default_and_explicit_same_path_reuse_the_svg(self):
        for arguments in ((), ("--out", self.source)):
            with self.subTest(arguments=arguments):
                result = self.run_cli(*arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("rendered svg diagram to", result.stdout)
                self.assertEqual(self.source.read_bytes(), SVG)

    @unittest.skipUnless(hasattr(os, "link"), "hard links are unavailable")
    def test_existing_hard_link_is_the_same_output_file(self):
        alias = self.root / "alias.svg"
        os.link(self.source, alias)
        result = self.run_cli("--out", alias)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(alias.samefile(self.source))
        self.assertEqual(alias.read_bytes(), SVG)

    def test_distinct_output_is_still_copied(self):
        output = self.root / "new directory" / "copy.svg"
        result = self.run_cli("--out", output)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_bytes(), SVG)
        self.assertEqual(self.source.read_bytes(), SVG)
        self.assertFalse(output.samefile(self.source))

    def test_empty_svg_is_still_rejected(self):
        self.source.write_bytes(b"")
        result = self.run_cli()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.source.read_bytes(), b"")

    def test_directory_with_svg_suffix_is_still_rejected(self):
        self.source.unlink()
        self.source.mkdir()
        result = self.run_cli()
        self.assertEqual(result.returncode, 1)
        self.assertTrue(self.source.is_dir())


if __name__ == "__main__":
    unittest.main()
