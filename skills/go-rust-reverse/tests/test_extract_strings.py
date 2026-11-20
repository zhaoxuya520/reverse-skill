"""Offline coverage of string extraction boundaries, output and memory use."""
import contextlib
import importlib.util
import io
from pathlib import Path
import re
import sys
import tempfile
import tracemalloc
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "extract_strings.py"
SPEC = importlib.util.spec_from_file_location("extract_strings", SCRIPT)
EXTRACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXTRACT)


class ExtractStringsTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.path = Path(self.scratch.name) / "fixture.bin"

    def run_mode(self, mode):
        output = io.StringIO()
        with patch.object(sys, "argv", [str(SCRIPT), str(self.path), mode]), contextlib.redirect_stdout(output):
            self.assertEqual(EXTRACT.main(), 0)
        return output.getvalue()

    def test_chunk_boundaries_match_complete_file_scan(self):
        data = bytes(range(256)) + b"\0short\xff" + b"long-printable-run" * 40 + b"\0tail!"
        self.path.write_bytes(data)
        expected = [match.decode("ascii") for match in re.findall(rb"[\x20-\x7e]{5,}", data)]
        for size in (1, 2, 4, 5, 7, 31, 128, 1024):
            with self.subTest(chunk_size=size):
                self.assertEqual(list(EXTRACT.iter_strings(self.path, chunk_size=size)), expected)
        self.assertEqual(EXTRACT.strings(self.path), expected)

    def test_empty_file_and_minimum_length(self):
        self.path.write_bytes(b"")
        self.assertEqual(EXTRACT.strings(self.path), [])
        self.path.write_bytes(b"abcde\0abcdef\0last-seven")
        self.assertEqual(EXTRACT.strings(self.path, minlen=6), ["abcdef", "last-seven"])

    def test_cli_count_unique_sort_and_filters(self):
        self.path.write_bytes(b"runtime.worker\0CreateFileW\0runtime.worker\0std::panic\0")
        self.assertEqual(self.run_mode("all"), "CreateFileW\nruntime.worker\nstd::panic\n")
        self.assertEqual(self.run_mode("gofunc"), "runtime.worker\n")
        self.assertEqual(self.run_mode("rust"), "std::panic\n")
        self.assertEqual(self.run_mode("winapi"), "CreateFileW\n")
        self.assertEqual(self.run_mode("count"), f"{self.path}: 4 strings, 3 unique\n")

    def test_count_does_not_retain_input_or_duplicate_occurrences(self):
        # The single unique value needs little storage even in a large binary.
        block = (b"runtime.worker\0" * 4096)
        with self.path.open("wb") as destination:
            for _ in range(128):
                destination.write(block)
        tracemalloc.start()
        try:
            output = self.run_mode("count")
            peak = tracemalloc.get_traced_memory()[1]
        finally:
            tracemalloc.stop()
        self.assertEqual(output, f"{self.path}: {4096 * 128} strings, 1 unique\n")
        self.assertLess(peak, 4 * 1024 * 1024)


if __name__ == "__main__":
    unittest.main()
