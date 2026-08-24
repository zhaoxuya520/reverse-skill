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
    report_dir.mkdir(exist_ok=True)

    ids = [i.strip() for i in args.evidence_ids.split(",") if i.strip()]
    if not ids:
        print("Error: no Evidence IDs provided", file=sys.stderr)
        return 1
    for eid in ids:
        f = evidence_dir / f"{eid}.md"
        if not f.exists():
            print(f"Error: {f} not found", file=sys.stderr)
            return 1

    for eid in ids:
        f = evidence_dir / f"{eid}.md"
        content = f.read_text(encoding="utf-8-sig")
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