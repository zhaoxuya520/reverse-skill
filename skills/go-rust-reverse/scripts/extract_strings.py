#!/usr/bin/env python3
"""String / Go-pclntab triage helper for go-rust-reverse.

Go binaries retain the runtime function-name table (runtime.pclntab) even when
the PE symbol table is stripped and the Go buildid is removed, so function names
are recoverable without GoReSym. Rust binaries retain panic strings and crate
paths. This prints filtered, deduplicated strings to stdout.

Usage:
    python extract_strings.py <binary> [count|gofunc|rust|kotik|winapi|all]

    count   print total / unique string counts
    gofunc  Go function names and package paths
    rust    Rust panic strings, crate paths, demangle/rustc markers
    kotik   any string containing "kotik" (adjust for your target)
    winapi  Windows API-shaped symbols
    all     every extracted string
"""
import re
import sys

ASCII = re.compile(rb"[\x20-\x7e]{5,}")

FILTERS = {
    "gofunc": re.compile(r"^(main|github\.com/|pkg/|sdk/|runtime\.|internal/|type:|go:|net/|crypto/|os/|sync\.)\S*"),
    "rust": re.compile(r"(::|rust_begin_unwind|panicked at|Cargo\.toml|\.cargo|panic|core::|alloc::|std::|/rustc/)"),
    "kotik": re.compile(r"kotik", re.IGNORECASE),
    "winapi": re.compile(r"^(Get|Set|Create|Open|Read|Write|Load|Virtual|Crypt|BCrypt|NCrypt|DPAPI|Copy|Close)\w+$"),
}


def strings(path, minlen=5):
    data = open(path, "rb").read()
    out = []
    for m in ASCII.finditer(data):
        try:
            s = m.group().decode("ascii")
        except UnicodeDecodeError:
            continue
        if len(s) >= minlen:
            out.append(s)
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    ss = strings(path)
    uniq = sorted(set(ss))
    if which == "count":
        print(f"{path}: {len(ss)} strings, {len(uniq)} unique")
        return 0
    pat = FILTERS.get(which)
    hits = [s for s in uniq if pat.search(s)] if pat else uniq
    for s in hits:
        print(s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
