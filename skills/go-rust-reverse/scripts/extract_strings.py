#!/usr/bin/env python3
"""String / Go-pclntab / UTF-16LE / Arabic-UTF8 triage helper for go-rust-reverse.

Highlights:
  1. Extracts ASCII, Windows UTF-16LE wide strings, and valid UTF-8 multilingual
     strings (including Arabic [\u0600-\u06FF] and CJK [\u4E00-\u9FFF]).
  2. Adds an 'arabic' filter in addition to count|gofunc|rust|kotik|winapi|all.

Usage:
    python extract_strings.py <binary> [count|gofunc|rust|kotik|winapi|arabic|all]
"""
from __future__ import annotations
import re
import sys

ASCII_RE = re.compile(rb"[\x20-\x7e]{5,}")
UTF16LE_ASCII_RE = re.compile(rb"(?:[\x20-\x7e]\x00){5,}")
UTF8_ARABIC_CJK_RE = re.compile(
    rb"(?:[\x20-\x7e]|\xd8[\x80-\xbf]|\xd9[\x80-\xbf]|\xda[\x80-\xbf]|\xdb[\x80-\xbf]|"
    rb"[\xe4-\xe9][\x80-\xbf]{2}){4,}"
)

FILTERS = {
    "gofunc": re.compile(r"^(main|github\.com/|pkg/|sdk/|runtime\.|internal/|type:|go:|net/|crypto/|os/|sync\.)\S*"),
    "rust": re.compile(r"(::|rust_begin_unwind|panicked at|Cargo\.toml|\.cargo|panic|core::|alloc::|std::|/rustc/)"),
    "kotik": re.compile(r"kotik", re.IGNORECASE),
    "winapi": re.compile(r"^(Get|Set|Create|Open|Read|Write|Load|Virtual|Crypt|BCrypt|NCrypt|DPAPI|Copy|Close)\w+$"),
    "arabic": re.compile(r"[\u0600-\u06FF]{2,}"),
}


def strings(path: str, minlen: int = 5) -> list[str]:
    with open(path, "rb") as f:
        data = f.read()
    out: list[str] = []
    seen: set[str] = set()

    def _add(s: str) -> None:
        s_clean = s.strip()
        if len(s_clean) >= minlen and s_clean not in seen:
            seen.add(s_clean)
            out.append(s_clean)

    for m in ASCII_RE.finditer(data):
        try:
            _add(m.group().decode("ascii"))
        except UnicodeDecodeError:
            continue

    for m in UTF16LE_ASCII_RE.finditer(data):
        try:
            _add(m.group().decode("utf-16le"))
        except UnicodeDecodeError:
            continue

    for m in UTF8_ARABIC_CJK_RE.finditer(data):
        raw = m.group()
        if any(b >= 0x80 for b in raw):
            try:
                decoded = raw.decode("utf-8")
                if re.search(r"[\u0600-\u06FF\u4E00-\u9FFF]", decoded):
                    _add(decoded)
            except UnicodeDecodeError:
                continue

    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    ss = strings(path, minlen=3 if which == "arabic" else 5)
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
