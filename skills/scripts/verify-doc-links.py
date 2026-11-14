#!/usr/bin/env python3
"""Verify internal (relative) Markdown links resolve to tracked files.

Guard against broken cross-references in the repo's documentation. Only
*local* links are checked: `http(s)`, `mailto:`, `tel:`, protocol-relative,
and pure `#anchor` links are ignored, as are links inside fenced code blocks
(``` / ~~~) and the generated `tool-index.md`. Link targets are resolved
relative to the containing file and matched against the set of git-tracked
files and directories (UTF-8 paths, so CJK filenames compare correctly).
Percent-encoded local paths are decoded once after query strings and
fragments are removed; literal plus signs remain part of the filename.

Markdown is read from the Git index rather than the working tree. This keeps
the check deterministic when antivirus software quarantines a research
payload file after checkout, and it lets the vendored corpus participate in
the same link-integrity check without opening it through the filesystem.

Exit 1 (with a report) if any internal link points at a path that is not
tracked. Run from the repo root:  python3 skills/scripts/verify-doc-links.py
"""
import os
import re
import subprocess
import sys
from urllib.parse import unquote

sys.stdout.reconfigure(encoding="utf-8")

LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
INLINE_CODE = re.compile(r"`[^`]*`")
FENCE = re.compile(r"^\s*(```|~~~)")
SKIP_PREFIX = ("http://", "https://", "mailto:", "tel:", "ftp:", "data:", "//", "#")
SKIP_CHARS = set("{}<>`$*|")


def tracked_paths():
    out = subprocess.run(
        ["git", "-c", "core.quotePath=false", "ls-files", "-z"],
        capture_output=True, check=True,
    ).stdout.decode("utf-8")
    files = {os.path.normpath(p).replace(os.sep, "/") for p in out.split("\0") if p}
    dirs = set()
    for f in files:
        d = os.path.dirname(f)
        while d and d not in dirs:
            dirs.add(d)
            d = os.path.dirname(d)
    return files, dirs


def links_in(path):
    """Yield (lineno, target) for local links outside fenced code blocks."""
    in_fence = False
    result = subprocess.run(
        ["git", "show", f":{path}"], capture_output=True, check=False
    )
    if result.returncode != 0:
        raise RuntimeError(f"cannot read tracked Markdown blob: {path}")
    text = result.stdout.decode("utf-8-sig")
    for lineno, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        for m in LINK.finditer(INLINE_CODE.sub("", line)):
            raw = m.group(1).strip().strip("<>")
            if not raw:
                continue
            target = raw.split()[0].split("#")[0].split("?")[0]
            if not target:
                continue
            if target.lower().startswith(SKIP_PREFIX):
                continue
            if "tool-index" in target or SKIP_CHARS & set(target):
                continue
            yield lineno, target


def resolve(md, target):
    """Resolve the extracted URL path, preserving encoded filename delimiters."""
    target = unquote(target)
    if target.startswith("/"):
        base = target.lstrip("/")
    else:
        base = os.path.join(os.path.dirname(md), target)
    return os.path.normpath(base).replace(os.sep, "/")


def main():
    files, dirs = tracked_paths()
    broken = []
    mds = sorted(p for p in files if p.endswith(".md"))
    for md in mds:
        for lineno, target in links_in(md):
            p = resolve(md, target)
            if p not in files and p not in dirs:
                broken.append((md, lineno, target))

    if broken:
        print(f"FAIL verify-doc-links: {len(broken)} broken internal link(s)")
        for md, lineno, target in broken:
            print(f"  {md}:{lineno} -> {target}")
        return 1
    print("OK verify-doc-links: all internal Markdown links resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
