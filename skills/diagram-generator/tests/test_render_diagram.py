"""Offline regression coverage for PlantUML source-relative includes."""

import importlib.util
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "render_diagram.py"
SPEC = importlib.util.spec_from_file_location("render_diagram", SCRIPT)
RENDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RENDER)


class PlantUmlTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.sources = self.root / "source with spaces"
        self.sources.mkdir()
        (self.sources / "nested").mkdir()
        self.src = self.sources / "diagram.puml"
        self.src.write_text("@startuml\n!include nested/messages.puml\n@enduml\n", encoding="utf-8")
        (self.sources / "nested" / "messages.puml").write_text(
            "Alice -> Bob : Included successfully\n", encoding="utf-8"
        )
        self.out = self.root / "requested.svg"

    def check_backend(self, backend, named_output):
        jar = self.root / "plantuml.jar"
        jar.write_bytes(b"offline fixture")
        commands = []

        def render(cmd, cwd=None):
            commands.append(cmd)
            source = Path(cmd[-1])
            # The renderer must see includes beside the original source.
            self.assertEqual(source, self.src)
            self.assertEqual(cwd, self.sources)
            self.assertIn("Included successfully", (source.parent / "nested/messages.puml").read_text())
            destination = Path(cmd[cmd.index("-o") + 1])
            self.assertTrue(destination.is_absolute())
            self.assertNotEqual(destination, self.sources)
            if backend == "jar":
                self.assertEqual(Path(cmd[2]), jar.resolve())
            name = "custom-name.svg" if named_output else "diagram.svg"
            (destination / name).write_text("<svg>Included successfully</svg>", encoding="utf-8")

        def which(name):
            if name == "plantuml" and backend == "command":
                return str(self.root / "plantuml")
            if name == "java":
                return str(self.root / "java")
            return None

        original = self.src.read_bytes()
        with patch.object(RENDER.shutil, "which", side_effect=which), \
                patch.object(RENDER, "run", side_effect=render), \
                patch.dict(os.environ, {"PLANTUML_JAR": os.path.relpath(jar)}):
            RENDER.render_plantuml(self.src, self.out, "svg")
        self.assertEqual(len(commands), 1)
        self.assertEqual(self.out.read_text(), "<svg>Included successfully</svg>")
        self.assertEqual(self.src.read_bytes(), original)
        self.assertFalse(list(self.sources.glob("*.svg")))
        self.assertFalse(Path(commands[0][commands[0].index("-o") + 1]).exists())

    def test_command_keeps_local_includes_and_isolates_outputs(self):
        for named in (False, True):
            with self.subTest(named_output=named):
                self.check_backend("command", named)

    def test_jar_keeps_local_includes_and_resolves_relative_jar(self):
        for named in (False, True):
            with self.subTest(named_output=named):
                self.check_backend("jar", named)

    @unittest.skipUnless(os.environ.get("PLANTUML_JAR") and shutil.which("java"),
                         "Set PLANTUML_JAR and install Java to run the local renderer integration")
    def test_real_jar_renders_local_include(self):
        original_which = shutil.which
        with patch.object(RENDER.shutil, "which", side_effect=lambda name: None if name == "plantuml" else original_which(name)):
            RENDER.render_plantuml(self.src, self.out, "svg")
        self.assertIn("Included successfully", self.out.read_text(encoding="utf-8"))
        self.assertFalse(list(self.sources.glob("*.svg")))


if __name__ == "__main__":
    unittest.main()
