"""Exercise PE metadata with synthetic binaries, without a toolchain or samples."""
import contextlib
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "pe_exports.py"
SPEC = importlib.util.spec_from_file_location("pe_exports", SCRIPT)
PE_EXPORTS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PE_EXPORTS)


def pe_fixture(pe32plus=False, ordinal_base=1, ordinal_index=0):
    data = bytearray(0x400)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\0\0"
    optional_size = 240 if pe32plus else 224
    struct.pack_into("<HH", data, 0x84, 0x8664 if pe32plus else 0x14C, 1)
    struct.pack_into("<H", data, 0x94, optional_size)
    optional = 0x98
    struct.pack_into("<H", data, optional, 0x20B if pe32plus else 0x10B)
    image_base = 0x140000000 if pe32plus else 0x400000
    if pe32plus:
        struct.pack_into("<Q", data, optional + 24, image_base)
    else:
        struct.pack_into("<II", data, optional + 24, 0x2000, image_base)
    struct.pack_into("<I", data, optional + (108 if pe32plus else 92), 16)
    struct.pack_into("<II", data, optional + (112 if pe32plus else 96), 0x1000, 0x100)
    section = optional + optional_size
    data[section:section + 8] = b".edata\0\0"
    struct.pack_into("<IIII", data, section + 8, 0x200, 0x1000, 0x200, 0x200)
    struct.pack_into("<IIIIII", data, 0x210, ordinal_base, 3, 1, 0x1040, 0x1050, 0x1060)
    struct.pack_into("<III", data, 0x240, 0x2000, 0x2010, 0x2020)
    struct.pack_into("<I", data, 0x250, 0x1070)
    struct.pack_into("<H", data, 0x260, ordinal_index)
    data[0x270:0x278] = b"example\0"
    return data, image_base


class PeExportsTests(unittest.TestCase):
    def read_fixture(self, data):
        with tempfile.TemporaryDirectory() as scratch:
            path = Path(scratch) / "fixture.dll"
            path.write_bytes(data)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(PE_EXPORTS.read(path), 0)
            return output.getvalue()

    def test_image_base_and_virtual_address_for_pe32_and_pe32plus(self):
        for pe32plus in (False, True):
            with self.subTest(pe32plus=pe32plus):
                data, image_base = pe_fixture(pe32plus=pe32plus)
                output = self.read_fixture(data)
                self.assertIn(f"image_base=0x{image_base:x}", output)
                self.assertIn(f"VA=0x{image_base + 0x2000:x}", output)

    def test_public_ordinal_includes_base_but_lookup_uses_index(self):
        for base in (0, 1, 100):
            with self.subTest(base=base):
                data, image_base = pe_fixture(pe32plus=True, ordinal_base=base, ordinal_index=2)
                output = self.read_fixture(data)
                self.assertIn(f"ord={base + 2:3d}", output)
                self.assertIn("RVA=0x00002020", output)
                self.assertIn(f"VA=0x{image_base + 0x2020:x}", output)


if __name__ == "__main__":
    unittest.main()
