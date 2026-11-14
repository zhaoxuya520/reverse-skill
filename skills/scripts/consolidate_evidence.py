import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def mark_superseded(content, finding_id):
    if re.search(r"(?m)^-\s*status:\s*.*$", content):
        return re.sub(r"(?m)^-\s*status:\s*.*$", f"- status: superseded by {finding_id}", content)
    if re.search(r"(?m)^---\s*$", content):
        return re.sub(r"(?m)^---\s*$", f"---\n- status: superseded by {finding_id}", content, count=1)
    return content.rstrip() + f"\n- status: superseded by {finding_id}\n"


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

    case_root = Path(args.case_root)
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
    contents = {}
    for eid in ids:
        f = evidence_dir / f"{eid}.md"
        if not f.is_file():
            print(f"Error: {f} not found", file=sys.stderr)
            return 1
        if f.is_symlink() or not f.resolve().is_relative_to(case_root.resolve()):
            print(f"Error: Evidence must be a case-local regular file: {f}", file=sys.stderr)
            return 1
        contents[eid] = f.read_text(encoding="utf-8-sig")

    heading = re.compile(r"(?m)^###\s+" + re.escape(args.finding_id) + r"(?=\s|$)")
    for report in report_dir.rglob("*.md") if report_dir.is_dir() else []:
        if heading.search(report.read_text(encoding="utf-8-sig")):
            print(f"Error: Finding already exists: {args.finding_id} in {report}", file=sys.stderr)
            return 1

    report_dir.mkdir(exist_ok=True)
    for eid in ids:
        f = evidence_dir / f"{eid}.md"
        content = contents[eid]
        f.write_text(mark_superseded(content, args.finding_id), encoding="utf-8-sig")
        print(f"Marked {eid} as superseded")

    report_file = report_dir / "report.md"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    block = finding_block(
        args.finding_id, args.title, args.severity, args.status,
        args.confidence, args.location, ids, args.description, ts,
    )
    if report_file.exists():
        content = report_file.read_text(encoding="utf-8-sig")
        if "## Findings" not in content:
            content = content.rstrip() + "\n\n## Findings\n"
        report_file.write_text(content.rstrip() + "\n\n" + block, encoding="utf-8-sig")
    else:
        report_file.write_text("# Case Report\n\n## Findings\n\n" + block, encoding="utf-8-sig")
    print(f"Successfully consolidated {len(ids)} evidence items into {args.finding_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
