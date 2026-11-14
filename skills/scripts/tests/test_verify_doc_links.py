"""Exercise Markdown link validation against a real temporary Git index."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


VALIDATOR = Path(__file__).resolve().parents[1] / "verify-doc-links.py"


class VerifyDocLinksTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="reverse-skill-links-")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.git("init", "-q")

    def git(self, *args):
        return subprocess.run(
            ["git", *args], cwd=self.root, check=True,
            capture_output=True, text=True,
        )

    def stage(self, path, text):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text, encoding="utf-8")
        self.git("add", "--", path)

    def validate(self):
        return subprocess.run(
            [sys.executable, str(VALIDATOR)], cwd=self.root,
            capture_output=True, text=True, encoding="utf-8",
        )

    def test_percent_encoded_spaces_and_unicode(self):
        self.stage("docs/example file.md", "# Example\n")
        self.stage("docs/中文.md", "# Unicode\n")
        self.stage("README.md", "[Space](docs/example%20file.md)\n"
                   "[Unicode](docs/%E4%B8%AD%E6%96%87.md)\n")
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipIf(os.name == "nt", "Windows filenames cannot contain question marks")
    def test_encoded_filename_delimiters_before_query_and_fragment(self):
        self.stage("docs/name#part?query.md", "# Delimiters\n")
        self.stage("README.md", "[Example](docs/name%23part%3Fquery.md?download=1#section)\n")
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_decodes_once_and_preserves_literal_plus(self):
        self.stage("docs/literal%20name.md", "# Literal percent\n")
        self.stage("docs/a+b.md", "# Literal plus\n")
        self.stage("README.md", "[Percent](docs/literal%2520name.md)\n"
                   "[Plus](docs/a+b.md)\n")
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_relative_root_and_directory_links(self):
        self.stage("docs/example file.md", "# Example\n")
        self.stage("guides/nested.md", "[Relative](../docs/example%20file.md)\n"
                   "[Root](/docs/example%20file.md)\n[Directory](../docs/)\n")
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_encoded_path_still_fails_with_original_target(self):
        self.stage("README.md", "[Missing](docs/missing%20file.md)\n")
        result = self.validate()
        self.assertEqual(result.returncode, 1)
        self.assertIn("README.md:1 -> docs/missing%20file.md", result.stdout)

    def test_uses_staged_markdown_and_ignores_external_and_fenced_links(self):
        self.stage("docs/example file.md", "# Example\n")
        self.stage("README.md", "[Local](docs/example%20file.md)\n"
                   "[External](https://example.invalid/missing%20file.md)\n"
                   "[Anchor](#missing)\n```md\n[Code](missing.md)\n```\n")
        (self.root / "README.md").write_text("[Unstaged](missing.md)\n", encoding="utf-8")
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
