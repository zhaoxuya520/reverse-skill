#!/usr/bin/env python3
"""Minimal dependency-free PE parser: sections + export table + forwarders.

Highlights:
  1. PE32 (0x10B) ImageBase is at OptionalHeader+28 (opt+24 is BaseOfData),
     while PE32+ (0x20B) ImageBase is 8 bytes at OptionalHeader+24.
  2. Reads OrdinalBase at ExportDirectory+16 so ordinals are reported as
     OrdinalBase + name_ordinal_index (instead of 0-based index).
  3. Guards rva_to_off against virtual-padding overruns (rva - vaddr >= rawsize)
     and unmapped RVAs (None), and detects PE Export Forwarder strings.

Usage:
    python pe_exports.py <pe-file> [--json]
"""
from __future__ import annotations
import json
import struct
import sys


def parse_pe_exports(path: str) -> dict:
    with open(path, "rb") as f:
        d = f.read()
    if len(d) < 0x40 or d[:2] != b"MZ":
        raise ValueError(f"{path}: not a PE (missing MZ)")
    e_lfanew = struct.unpack_from("<I", d, 0x3C)[0]
    if e_lfanew + 24 > len(d) or d[e_lfanew:e_lfanew + 4] != b"PE\0\0":
        raise ValueError(f"{path}: not a PE (missing PE signature)")
    coff = e_lfanew + 4
    machine, nsec = struct.unpack_from("<HH", d, coff)
    opt_size = struct.unpack_from("<H", d, coff + 16)[0]
    opt = coff + 20
    if opt + opt_size > len(d) or opt_size < 28:
        raise ValueError(f"{path}: truncated OptionalHeader")
    magic = struct.unpack_from("<H", d, opt)[0]
    if magic not in (0x10B, 0x20B):
        raise ValueError(f"{path}: unsupported OptionalHeader magic 0x{magic:x}")
    pe32plus = (magic == 0x20B)
    # Fix: PE32+ ImageBase is <Q at opt+24; PE32 ImageBase is <I at opt+28 (opt+24 is BaseOfData)
    image_base = (
        struct.unpack_from("<Q", d, opt + 24)[0]
        if pe32plus
        else struct.unpack_from("<I", d, opt + 28)[0]
    )
    dd_off = opt + (112 if pe32plus else 96)
    exp_rva, exp_size = (0, 0)
    if dd_off + 8 <= opt + opt_size and dd_off + 8 <= len(d):
        exp_rva, exp_size = struct.unpack_from("<II", d, dd_off)

    sec_base = opt + opt_size
    secs = []
    for i in range(nsec):
        o = sec_base + i * 40
        if o + 40 > len(d):
            break
        name = d[o:o + 8].rstrip(b"\0").decode("latin1")
        vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", d, o + 8)
        secs.append({
            "name": name,
            "vaddr": vaddr,
            "vsize": vsize,
            "rawptr": rawptr,
            "rawsize": rawsize,
        })

    def rva_to_off(rva: int) -> int | None:
        for s in secs:
            vaddr, vsize, rawptr, rawsize = s["vaddr"], s["vsize"], s["rawptr"], s["rawsize"]
            span = max(vsize, rawsize)
            if vaddr <= rva < vaddr + span:
                delta = rva - vaddr
                if delta >= rawsize:
                    return None
                off = rawptr + delta
                return off if 0 <= off < len(d) else None
        if 0 < rva < len(d) and not secs:
            return rva
        return None

    exports = []
    ordinal_base = 1
    nfunc = 0
    nname = 0
    if exp_rva:
        eo = rva_to_off(exp_rva)
        if eo is not None and eo + 40 <= len(d):
            ordinal_base, nfunc, nname, addr_funcs, addr_names, addr_ords = struct.unpack_from(
                "<IIIIII", d, eo + 16
            )
            no = rva_to_off(addr_names) if addr_names else None
            ao = rva_to_off(addr_funcs) if addr_funcs else None
            oo = rva_to_off(addr_ords) if addr_ords else None
            if no is not None and ao is not None and oo is not None:
                for i in range(nname):
                    if no + (i + 1) * 4 > len(d) or oo + (i + 1) * 2 > len(d):
                        break
                    name_rva = struct.unpack_from("<I", d, no + i * 4)[0]
                    ord_idx = struct.unpack_from("<H", d, oo + i * 2)[0]
                    if ord_idx >= nfunc or ao + (ord_idx + 1) * 4 > len(d):
                        continue
                    func_rva = struct.unpack_from("<I", d, ao + ord_idx * 4)[0]
                    actual_ord = ordinal_base + ord_idx
                    so = rva_to_off(name_rva)
                    if so is None:
                        exp_name = f"<unmapped_rva_0x{name_rva:x}>"
                    else:
                        end = d.find(b"\0", so)
                        exp_name = d[so:(end if end != -1 else len(d))].decode("utf-8", errors="replace")

                    is_forwarder = (exp_rva <= func_rva < exp_rva + exp_size)
                    forwarder_target = None
                    if is_forwarder:
                        fo = rva_to_off(func_rva)
                        if fo is not None:
                            fend = d.find(b"\0", fo)
                            forwarder_target = d[fo:(fend if fend != -1 else len(d))].decode("latin1", errors="replace")

                    exports.append({
                        "name": exp_name,
                        "ordinal_index": ord_idx,
                        "ordinal": actual_ord,
                        "rva": func_rva,
                        "va": image_base + func_rva,
                        "is_forwarder": is_forwarder,
                        "forwarder": forwarder_target,
                    })

    return {
        "file": path,
        "machine": machine,
        "sections_count": len(secs),
        "magic": magic,
        "pe32plus": pe32plus,
        "image_base": image_base,
        "ordinal_base": ordinal_base,
        "functions_count": nfunc,
        "names_count": nname,
        "sections": secs,
        "exports": exports,
    }


def read(path: str, as_json: bool = False) -> int:
    try:
        info = parse_pe_exports(path)
    except ValueError as exc:
        print(str(exc))
        return 1
    if as_json:
        print(json.dumps(info, ensure_ascii=False, indent=2))
        return 0
    print(f"file={info['file']}")
    print(
        f"machine=0x{info['machine']:04x} sections={info['sections_count']} "
        f"magic=0x{info['magic']:x} image_base=0x{info['image_base']:x}"
    )
    for s in info["sections"]:
        print(
            f"  section {s['name']:8s} rva=0x{s['vaddr']:08x} "
            f"vsize=0x{s['vsize']:x} raw=0x{s['rawptr']:x} rawsize=0x{s['rawsize']:x}"
        )
    if not info["functions_count"] and not info["names_count"]:
        print("no export directory")
        return 0
    print(
        f"exports: functions={info['functions_count']} names={info['names_count']} "
        f"ordinal_base={info['ordinal_base']}"
    )
    for e in info["exports"]:
        if e["is_forwarder"]:
            print(
                f"  {e['name']:40s} ord={e['ordinal']:3d} RVA=0x{e['rva']:08x} "
                f"FORWARDER->{e['forwarder']}"
            )
        else:
            print(
                f"  {e['name']:40s} ord={e['ordinal']:3d} RVA=0x{e['rva']:08x} "
                f"VA=0x{e['va']:x}"
            )
    return 0


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--json"]
    as_json = "--json" in sys.argv[1:]
    if len(args) != 1:
        print(__doc__)
        sys.exit(2)
    sys.exit(read(args[0], as_json=as_json))
