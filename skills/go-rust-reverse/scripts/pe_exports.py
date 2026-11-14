#!/usr/bin/env python3
"""Minimal dependency-free PE parser: sections + export table.

Useful when radare2 / rabin2 are unavailable or stale on the analysis host.
Prints the machine, image base, section table, and every named export with its
exact RVA and VA.

Usage:
    python pe_exports.py <pe-file>
"""
import struct
import sys


def read(path):
    d = open(path, "rb").read()
    if len(d) < 0x40 or d[:2] != b"MZ":
        print(f"{path}: not a PE (missing MZ)")
        return 1
    e_lfanew = struct.unpack_from("<I", d, 0x3C)[0]
    if d[e_lfanew:e_lfanew + 4] != b"PE\0\0":
        print(f"{path}: not a PE (missing PE signature)")
        return 1
    coff = e_lfanew + 4
    machine, nsec = struct.unpack_from("<HH", d, coff)
    opt_size = struct.unpack_from("<H", d, coff + 16)[0]
    opt = coff + 20
    magic = struct.unpack_from("<H", d, opt)[0]
    pe32plus = magic == 0x20B
    dd_off = opt + (112 if pe32plus else 96)
    exp_rva, _exp_size = struct.unpack_from("<II", d, dd_off)
    image_base = struct.unpack_from("<Q" if pe32plus else "<I", d, opt + 24)[0]
    sec = opt + opt_size
    secs = []
    for i in range(nsec):
        o = sec + i * 40
        name = d[o:o + 8].rstrip(b"\0").decode("latin1")
        vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", d, o + 8)
        secs.append((name, vaddr, vsize, rawptr, rawsize))

    def rva_to_off(rva):
        for _name, vaddr, vsize, rawptr, rawsize in secs:
            if vaddr <= rva < vaddr + max(vsize, rawsize):
                return rawptr + (rva - vaddr)
        return None

    print(f"file={path}")
    print(f"machine=0x{machine:04x} sections={nsec} magic=0x{magic:x} image_base=0x{image_base:x}")
    for s in secs:
        print(f"  section {s[0]:8s} rva=0x{s[1]:08x} vsize=0x{s[2]:x} raw=0x{s[3]:x} rawsize=0x{s[4]:x}")
    if not exp_rva:
        print("no export directory")
        return 0
    eo = rva_to_off(exp_rva)
    nfunc, nname = struct.unpack_from("<II", d, eo + 20)
    addr_funcs = struct.unpack_from("<I", d, eo + 28)[0]
    addr_names = struct.unpack_from("<I", d, eo + 32)[0]
    addr_ords = struct.unpack_from("<I", d, eo + 36)[0]
    print(f"exports: functions={nfunc} names={nname}")
    no, ao, oo = rva_to_off(addr_names), rva_to_off(addr_funcs), rva_to_off(addr_ords)
    for i in range(nname):
        name_rva = struct.unpack_from("<I", d, no + i * 4)[0]
        ordinal = struct.unpack_from("<H", d, oo + i * 2)[0]
        func_rva = struct.unpack_from("<I", d, ao + ordinal * 4)[0]
        so = rva_to_off(name_rva)
        end = d.index(b"\0", so)
        print(f"  {d[so:end].decode('latin1'):40s} ord={ordinal:3d} RVA=0x{func_rva:08x} VA=0x{image_base + func_rva:x}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(read(sys.argv[1]))
