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
from itertools import islice

ASCII = re.compile(rb"[\x20-\x7e]{5,}")
ASCII_RUN = re.compile(rb"[\x20-\x7e]+")
NON_ASCII = re.compile(rb"[^\x20-\x7e]")

FILTERS = {
    "gofunc": re.compile(r"^(main|github\.com/|pkg/|sdk/|runtime\.|internal/|type:|go:|net/|crypto/|os/|sync\.)\S*"),
    "rust": re.compile(r"(::|rust_begin_unwind|panicked at|Cargo\.toml|\.cargo|panic|core::|alloc::|std::|/rustc/)"),
    "kotik": re.compile(r"kotik", re.IGNORECASE),
    "winapi": re.compile(r"^(Get|Set|Create|Open|Read|Write|Load|Virtual|Crypt|BCrypt|NCrypt|DPAPI|Copy|Close)\w+$"),
}


def iter_strings(path, minlen=5, chunk_size=256 * 1024):
    """Yield complete ASCII runs, including strings crossing read boundaries.

    Working storage is bounded by the current chunk and its matches, plus the
    longest unfinished string.
    Keep the original extractor's minimum of five printable bytes.
    """
    if chunk_size <= 0:
        raise ValueError("chunk_size must be positive")
    minimum = max(5, minlen)
    pending = bytearray()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(chunk_size), b""):
            offset = 0
            if pending:
                prefix = ASCII_RUN.match(chunk)
                if prefix:
                    pending.extend(prefix.group())
                    offset = prefix.end()
                    if offset == len(chunk):
                        continue
                if len(pending) >= minimum:
                    yield pending.decode("ascii")
                pending.clear()
            end = len(chunk)
            if 0x20 <= chunk[-1] <= 0x7e:
                # Exclude the unfinished suffix once per chunk, so complete
                # strings can be scanned together without per-match boundary checks.
                delimiter = NON_ASCII.search(chunk[::-1])
                end = len(chunk) - delimiter.start() if delimiter else 0
                del delimiter
            values = ASCII.findall(chunk, offset, end)
            if minimum > 5:
                values = (value for value in values if len(value) >= minimum)
            yield from map(bytes.decode, values)
            pending.extend(chunk[end:])
    if len(pending) >= minimum:
        yield pending.decode("ascii")


def strings(path, minlen=5):
    """Compatibility wrapper for callers that need every occurrence as a list."""
    return list(iter_strings(path, minlen=minlen))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    if which == "count":
        count = 0
        uniq = set()
        values = iter_strings(path)
        while True:
            batch = list(islice(values, 8192))
            if not batch:
                break
            count += len(batch)
            uniq.update(batch)
            del batch
        print(f"{path}: {count} strings, {len(uniq)} unique")
        return 0
    pat = FILTERS.get(which)
    values = iter_strings(path)
    hits = set(filter(pat.search, values) if pat else values)
    for s in sorted(hits):
        print(s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
