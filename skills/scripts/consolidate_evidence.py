import argparse
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def mark_superseded(content, finding_id):
    newline = "\r\n" if "\r\n" in content else "\n"
    if re.search(r"(?m)^-[ \t]*status:[^\r\n]*", content):
        return re.sub(r"(?m)^-[ \t]*status:[^\r\n]*", f"- status: superseded by {finding_id}", content)
    if re.search(r"(?m)^---[ \t]*(?=\r?$)", content):
        return re.sub(r"(?m)^---[ \t]*(?=\r?$)", f"---{newline}- status: superseded by {finding_id}", content, count=1)
    return content.rstrip() + f"{newline}- status: superseded by {finding_id}{newline}"


def encode_record(content, original):
    encoding = "utf-8-sig" if original is None or original.startswith(b"\xef\xbb\xbf") else "utf-8"
    return content.encode(encoding)


def copy_windows_dacl(source, destination):
    """Protect an empty staging file before putting case content in it."""
    import ctypes
    from ctypes import wintypes

    advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    pointer = ctypes.POINTER(wintypes.LPVOID)
    get_security = advapi.GetNamedSecurityInfoW
    get_security.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD] + [pointer] * 5
    get_security.restype = wintypes.DWORD
    get_control = advapi.GetSecurityDescriptorControl
    get_control.argtypes = [wintypes.LPVOID, ctypes.POINTER(wintypes.WORD), ctypes.POINTER(wintypes.DWORD)]
    get_control.restype = wintypes.BOOL
    set_security = advapi.SetNamedSecurityInfoW
    set_security.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD] + [wintypes.LPVOID] * 4
    set_security.restype = wintypes.DWORD
    local_free = kernel.LocalFree
    local_free.argtypes = [wintypes.LPVOID]
    local_free.restype = wintypes.LPVOID
    descriptor, dacl = wintypes.LPVOID(), wintypes.LPVOID()
    # SE_FILE_OBJECT = 1; request only the DACL, without owner/SACL privileges.
    error = get_security(str(source), 1, 4, None, None, ctypes.byref(dacl), None, ctypes.byref(descriptor))
    if error:
        raise ctypes.WinError(error)
    try:
        control, revision = wintypes.WORD(), wintypes.DWORD()
        if not get_control(descriptor, ctypes.byref(control), ctypes.byref(revision)):
            raise ctypes.WinError(ctypes.get_last_error())
        # Preserve SE_DACL_PROTECTED using the named-security API's flags.
        protection = 0x80000000 if control.value & 0x1000 else 0x20000000
        error = set_security(str(destination), 1, 4 | protection, None, None, dacl, None)
        if error:
            raise ctypes.WinError(error)
    finally:
        local_free(descriptor)


def replace_record(source, destination, backup=None):
    # ReplaceFile preserves the existing Windows destination's ACL. On POSIX,
    # copy2 below preserves the mode before the atomic rename.
    if os.name == "nt" and destination.exists():
        import ctypes
        from ctypes import wintypes

        replace = ctypes.WinDLL("kernel32", use_last_error=True).ReplaceFileW
        replace.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.LPCWSTR,
                            wintypes.DWORD, wintypes.LPVOID, wintypes.LPVOID]
        replace.restype = wintypes.BOOL
        if not replace(str(destination), str(source), str(backup) if backup is not None else None, 0, None, None):
            raise ctypes.WinError(ctypes.get_last_error())
    else:
        os.replace(source, destination)


def publish_consolidation(records):
    """Publish report first; recover caught I/O failures, not process crashes."""
    temporary = []
    retained = set()
    attempted = []
    publication_handled = False

    def retain_backup(backup):
        if backup is None:
            return ""
        retained.add(backup)
        if backup.is_file():
            return f"; original bytes retained at {backup}"
        return f"; backup unavailable at {backup}, inspect the destination before retrying"

    def stage(path, data):
        descriptor, name = tempfile.mkstemp(prefix=f".{path.name}.consolidate-", dir=path.parent)
        os.close(descriptor)
        staged = Path(name)
        temporary.append(staged)
        if path.exists():
            if os.name == "nt":
                copy_windows_dacl(path, staged)
                os.chmod(staged, path.stat().st_mode)
            else:
                original_stat, staged_stat = path.stat(), staged.stat()
                if (original_stat.st_uid, original_stat.st_gid) != (staged_stat.st_uid, staged_stat.st_gid):
                    raise OSError(f"Cannot safely preserve file ownership while staging {path}")
                shutil.copy2(path, staged)
        staged.write_bytes(data)
        return staged

    try:
        prepared = []
        for path, data, original in records:
            pending = stage(path, data)
            backup = stage(path, original) if original is not None else None
            prepared.append((path, pending, backup))

        try:
            for record in prepared:
                # Include a failed replacement in recovery: native APIs may
                # report a metadata error after changing a destination.
                attempted.append(record)
                replace_record(record[1], record[0], record[2])
            publication_handled = True
        except OSError as error:
            recovery_errors = []
            report_path = records[0][0]
            for path, pending, backup in reversed(attempted):
                if path == report_path and recovery_errors:
                    recovery_errors.append(f"Kept Finding in {path}; restore Evidence before restoring the report"
                                           + retain_backup(backup))
                    continue
                try:
                    if backup is None:
                        path.unlink(missing_ok=True)
                    else:
                        replace_record(backup, path)
                except OSError as recovery_error:
                    recovery_errors.append(f"Could not restore {path}" + retain_backup(backup) + f": {recovery_error}")
            detail = "; ".join(recovery_errors) if recovery_errors else "Original records restored."
            publication_handled = True
            raise OSError(f"Consolidation failed: {error}. {detail}") from error
    finally:
        if attempted and not publication_handled:
            # Do not discard the only original copies on KeyboardInterrupt or
            # another non-I/O exception; leave recovery to the caller.
            for path, pending, backup in attempted:
                if backup is not None:
                    print(f"Warning: publication interrupted for {path}" + retain_backup(backup), file=sys.stderr)
        for path in temporary:
            if path not in retained:
                try:
                    path.unlink(missing_ok=True)
                except OSError as cleanup_error:
                    print(f"Warning: could not remove temporary file {path}: {cleanup_error}", file=sys.stderr)


def finding_block(finding_id, title, severity, status, confidence, location, ids, description, ts):
    return (
        f"### {finding_id}\n"
        f"- title: {title}\n"
        f"- severity: {severity}\n"
        f"- status: {status}\n"
        f"- confidence: {confidence}\n"
        f"- location: {location}\n"
        f"- evidence_ids: {', '.join(ids)}\n"
        f"- consolidated_at: {ts}\n\n"
        f"{description}\n"
    )


def main():
    parser = argparse.ArgumentParser(description="Consolidate Evidence into Finding")
    parser.add_argument("--case-root", required=True)
    parser.add_argument("--evidence-ids", required=True, help="Comma-separated E-xxx")
    parser.add_argument("--finding-id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--severity", default="medium")
    parser.add_argument("--status", default="validated")
    parser.add_argument("--confidence", default="medium")
    parser.add_argument("--location", default="see evidence_ids")
    args = parser.parse_args()

    case_root = Path(args.case_root).resolve()
    evidence_dir = case_root / "evidence"
    report_dir = case_root / "report"

    ids = list(dict.fromkeys(i.strip() for i in args.evidence_ids.split(",") if i.strip()))
    if not ids:
        print("Error: no Evidence IDs provided", file=sys.stderr)
        return 1
    if not re.fullmatch(r"F-[A-Za-z0-9][A-Za-z0-9_-]*", args.finding_id) or any(
        not re.fullmatch(r"E-[A-Za-z0-9][A-Za-z0-9_-]*", eid) for eid in ids
    ):
        print("Error: expected plain E-... and F-... record IDs", file=sys.stderr)
        return 1
    originals = {}
    contents = {}
    for eid in ids:
        f = evidence_dir / f"{eid}.md"
        if not f.is_file():
            print(f"Error: {f} not found", file=sys.stderr)
            return 1
        if f.is_symlink() or not f.resolve().is_relative_to(case_root.resolve()):
            print(f"Error: Evidence must be a case-local regular file: {f}", file=sys.stderr)
            return 1
        originals[eid] = f.read_bytes()
        contents[eid] = originals[eid].decode("utf-8-sig")

    heading = re.compile(r"(?m)^###\s+" + re.escape(args.finding_id) + r"(?=\s|$)")
    for report in report_dir.rglob("*.md") if report_dir.is_dir() else []:
        if heading.search(report.read_text(encoding="utf-8-sig")):
            print(f"Error: Finding already exists: {args.finding_id} in {report}", file=sys.stderr)
            return 1

    report_file = (report_dir / "report.md").resolve()
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    block = finding_block(
        args.finding_id, args.title, args.severity, args.status,
        args.confidence, args.location, ids, args.description, ts,
    )
    if report_file.exists():
        report_original = report_file.read_bytes()
        content = report_original.decode("utf-8-sig")
        newline = "\r\n" if "\r\n" in content else "\n"
        if "## Findings" not in content:
            content = content.rstrip() + newline * 2 + "## Findings" + newline
        report_content = content.rstrip() + newline * 2 + block.replace("\r\n", "\n").replace("\n", newline)
    else:
        report_original = None
        report_content = "# Case Report\n\n## Findings\n\n" + block
    records = [(report_file, encode_record(report_content, report_original), report_original)]
    records.extend((evidence_dir / f"{eid}.md", encode_record(mark_superseded(contents[eid], args.finding_id),
                                                           originals[eid]), originals[eid]) for eid in ids)
    try:
        report_dir.mkdir(exist_ok=True)
        publish_consolidation(records)
    except OSError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    for eid in ids:
        print(f"Marked {eid} as superseded")
    print(f"Successfully consolidated {len(ids)} evidence items into {args.finding_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
