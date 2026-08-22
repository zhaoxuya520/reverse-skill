import argparse
import os
import re
from datetime import datetime, timezone
from pathlib import Path

def main( ):
    parser = argparse.ArgumentParser(description="Consolidate Evidence into Finding")
    parser.add_argument("--case-root", required=True)
    parser.add_argument("--evidence-ids", required=True, help="Comma-separated E-xxx")
    parser.add_argument("--finding-id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--severity", default="medium")
    parser.add_argument("--status", default="validated")
    args = parser.parse_args()

    case_root = Path(args.case_root)
    evidence_dir = case_root / "evidence"
    report_dir = case_root / "report"
    report_dir.mkdir(exist_ok=True)

    ids = [i.strip() for i in args.evidence_ids.split(",") if i.strip()]
    for eid in ids:
        f = evidence_dir / f"{eid}.md"
        if not f.exists():
            print(f"Error: {f} not found")
            return
            
    for eid in ids:
        f = evidence_dir / f"{eid}.md"
        content = f.read_text(encoding="utf-8-sig")
        if re.search(r"(?m)^-\s*status:\s*.*$", content):
            content = re.sub(r"(?m)^-\s*status:\s*.*$", f"- status: superseded by {args.finding_id}", content)
        else:
            content = re.sub(r"(?m)^---$", f"---\n- status: superseded by {args.finding_id}", content, count=1)
        f.write_text(content, encoding="utf-8-sig")
        print(f"Marked {eid} as superseded")

    report_file = report_dir / "report.md"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    
    finding_block = f"""
### {args.finding_id}
- title: {args.title}
- severity: {args.severity}
- status: {args.status}
- confidence: high
- location: Multiple locations
- evidence_ids: {', '.join(ids)}
- consolidated_at: {ts}

{args.description}
"""
    if report_file.exists():
        content = report_file.read_text(encoding="utf-8-sig")
        if "## Findings" not in content:
            with report_file.open("a", encoding="utf-8-sig") as f:
                f.write("\n## Findings\n")
        with report_file.open("a", encoding="utf-8-sig") as f:
            f.write(finding_block)
    else:
        report_file.write_text(f"# Case Report\n\n## Findings\n{finding_block}", encoding="utf-8-sig")
    
    print(f"Successfully consolidated {len(ids)} evidence items into {args.finding_id}")

if __name__ == "__main__":
    main()
