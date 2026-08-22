import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


EVIDENCE_ID = re.compile(r"\bE-[A-Za-z0-9][A-Za-z0-9_-]*\b")
WORKITEM_ID = re.compile(r"\bWI-[A-Za-z0-9][A-Za-z0-9_-]*\b")
FINDING_ID = re.compile(r"\bF-[A-Za-z0-9][A-Za-z0-9_-]*\b")
PATH_ID = re.compile(r"\bP-[A-Za-z0-9][A-Za-z0-9_-]*\b")
FIELD_LINE = re.compile(r"^\s*-\s+([A-Za-z0-9_]+):\s*(.*)$")
SECTION_HEADING = re.compile(r"^#{2,6}\s+(.+?)\s*$")
EVIDENCE_HEADING = re.compile(r"^###\s+(E-[A-Za-z0-9][A-Za-z0-9_-]*)\b", re.MULTILINE)
FINDING_HEADING = re.compile(r"^###\s+(F-[A-Za-z0-9][A-Za-z0-9_-]*)\b", re.MULTILINE)
PATH_HEADING = re.compile(r"^###\s+(P-[A-Za-z0-9][A-Za-z0-9_-]*)\b", re.MULTILINE)

SEVERITIES = {"critical", "high", "medium", "low", "info", "n/a", "n/a_re"}
EVIDENCE_STATUSES = {"observed", "candidate", "validated", "false_positive", "accepted_risk", "superseded"}
WORKITEM_STATUSES = {"pending", "in_progress", "blocked", "done", "completed", "cancelled"}
PATH_TYPES = {"attack", "callflow", "solve"}
NETWORK_MODES = {"offline", "lab_only", "authorized_target_only", "unrestricted_lab"}


def field_value(text, name):
    lines = text.splitlines()
    for index, line in enumerate(lines):
        match = FIELD_LINE.match(line)
        if not match or match.group(1) != name:
            continue
        value = match.group(2).strip()
        if value != "|":
            return value
        block = []
        for continuation in lines[index + 1:]:
            if FIELD_LINE.match(continuation):
                break
            if SECTION_HEADING.match(continuation):
                break
            if continuation.strip():
                block.append(continuation.strip())
        return "\n".join(block).strip()
    return ""


def section_text(text, title):
    pattern = re.compile(
        r"(?ms)^##\s+" + re.escape(title) + r"\s*$\n?(.*?)(?=^##\s|\Z)"
    )
    match = pattern.search(text)
    return match.group(1) if match else ""


def ids_in(value, pattern):
    return sorted(set(pattern.findall(value or "")))


def issue(issues, level, code, message, path=""):
    issues.append({"level": level, "code": code, "message": message, "path": path})


def relative_path(root, path):
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(path)


def split_table_row(line):
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return []
    return [cell.strip() for cell in stripped[1:-1].split("|")]


def parse_workitems(root, issues):
    path = root / "workitems.md"
    records = {}
    references = []
    if not path.is_file():
        issue(issues, "error", "workitems.missing", "workitems.md is missing", "workitems.md")
        return records, references

    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        cells = split_table_row(line)
        if len(cells) < 8 or not WORKITEM_ID.fullmatch(cells[0]):
            continue
        workitem_id = cells[0]
        status = cells[5].lower()
        if status not in WORKITEM_STATUSES:
            issue(
                issues,
                "error",
                "workitem.status",
                "unsupported work item status: " + status,
                "workitems.md:" + str(line_number),
            )
        evidence_ids = ids_in(cells[6], EVIDENCE_ID)
        records[workitem_id] = {"status": status, "evidence_ids": evidence_ids}
        references.extend((evidence_id, "workitems.md:" + str(line_number)) for evidence_id in evidence_ids)

    if not records:
        issue(issues, "warning", "workitems.empty", "no work item rows were found", "workitems.md")
    return records, references


def parse_timeline(root, issues):
    path = root / "timeline.md"
    references = []
    events = 0
    if not path.is_file():
        issue(issues, "error", "timeline.missing", "timeline.md is missing", "timeline.md")
        return events, references

    lines = path.read_text(encoding="utf-8-sig").splitlines()
    for index, line in enumerate(lines):
        if not line.startswith("## ") or "|" not in line:
            continue
        events += 1
        end = len(lines)
        for next_index in range(index + 1, len(lines)):
            if lines[next_index].startswith("## "):
                end = next_index
                break
        body = "\n".join(lines[index:end])
        evidence_ids = ids_in(field_value(body, "evidence_ids"), EVIDENCE_ID)
        references.extend((evidence_id, "timeline.md:" + str(index + 1)) for evidence_id in evidence_ids)

    if events == 0:
        issue(issues, "warning", "timeline.empty", "no append-only timeline events were found", "timeline.md")
    return events, references


def parse_scope(root, issues, strict):
    path = root / "scope.md"
    result = {"auth_status": "", "network_mode": "", "ready_for_act": "", "assets": []}
    if not path.is_file():
        issue(issues, "error", "scope.missing", "scope.md is missing", "scope.md")
        return result

    text = path.read_text(encoding="utf-8-sig")
    auth = section_text(text, "auth")
    scope_section = section_text(text, "in_scope")
    network = section_text(text, "network_profile")
    signoff = section_text(text, "signoff")
    result["auth_status"] = field_value(auth, "status").lower()
    result["network_mode"] = field_value(network, "mode").lower()
    result["ready_for_act"] = field_value(signoff, "ready_for_act").lower()

    # Only a top-level "- field:" ends the assets block. Indented Windows
    # paths such as "  - D:\\repo" contain a colon but are asset values.
    assets_match = re.search(r"(?ms)^\s*-\s+assets:\s*\n(?P<body>.*?)(?=^-\s+[A-Za-z0-9_]+:|\Z)", scope_section)
    if assets_match:
        result["assets"] = [
            line.strip()[2:].strip()
            for line in assets_match.group("body").splitlines()
            if re.match(r"^\s+-\s+\S+", line) and line.strip()[2:].strip() != "[]"
        ]

    if not result["auth_status"]:
        issue(issues, "error", "scope.auth_missing", "auth.status is missing", "scope.md")
    elif result["auth_status"] not in {"pending", "granted", "denied", "unknown"}:
        issue(issues, "error", "scope.auth_invalid", "unsupported auth.status: " + result["auth_status"], "scope.md")

    if not result["network_mode"]:
        issue(issues, "error", "scope.network_missing", "network_profile.mode is missing", "scope.md")
    elif result["network_mode"] not in NETWORK_MODES:
        issue(issues, "error", "scope.network_invalid", "unsupported network mode: " + result["network_mode"], "scope.md")

    if not result["ready_for_act"]:
        issue(issues, "error", "scope.ready_missing", "signoff.ready_for_act is missing", "scope.md")
    elif result["ready_for_act"] not in {"true", "false"}:
        issue(issues, "error", "scope.ready_invalid", "ready_for_act must be true or false", "scope.md")

    if result["network_mode"] != "offline" and not result["assets"]:
        issue(issues, "error", "scope.assets_missing", "in_scope.assets is empty for a network case", "scope.md")

    if result["auth_status"] != "granted" or result["ready_for_act"] != "true":
        message = "scope is not ready for target ACT"
        if strict and result["network_mode"] != "offline":
            issue(issues, "error", "scope.not_ready", message, "scope.md")
        else:
            issue(issues, "warning", "scope.not_ready", message, "scope.md")
    return result


def report_sections(text, heading_pattern):
    matches = list(heading_pattern.finditer(text))
    sections = []
    for index, match in enumerate(matches):
        end = len(text)
        for next_match in re.finditer(r"(?m)^#{1,3}\s+", text[match.end():]):
            end = match.end() + next_match.start()
            break
        sections.append((match.group(1), text[match.start():end]))
    return sections


def parse_reports(root, issues):
    finding_records = []
    path_records = []
    references = []
    report_root = root / "report"
    report_files = sorted(report_root.rglob("*.md")) if report_root.is_dir() else []
    if not report_files:
        issue(issues, "warning", "report.missing", "no Markdown report was found", "report")
        return finding_records, path_records, references

    for report_path in report_files:
        text = report_path.read_text(encoding="utf-8-sig")
        for finding_id, body in report_sections(text, FINDING_HEADING):
            status = field_value(body, "status").lower()
            confidence = field_value(body, "confidence").lower()
            evidence_ids = ids_in(field_value(body, "evidence_ids"), EVIDENCE_ID)
            required = ("severity", "evidence_ids", "confidence", "location", "status")
            for field in required:
                if not field_value(body, field):
                    issue(issues, "error", "finding.field_missing", finding_id + " is missing " + field, relative_path(root, report_path))
            if status not in {"candidate", "validated", "false_positive", "accepted_risk", "superseded"}:
                issue(issues, "error", "finding.status", finding_id + " has unsupported status", relative_path(root, report_path))
            if status == "validated" and confidence == "low":
                issue(issues, "error", "finding.confidence", finding_id + " is validated with low confidence", relative_path(root, report_path))
            if not evidence_ids:
                issue(issues, "error", "finding.evidence_missing", finding_id + " has no evidence_ids", relative_path(root, report_path))
            references.extend((evidence_id, relative_path(root, report_path)) for evidence_id in evidence_ids)
            finding_records.append({"id": finding_id, "status": status, "evidence_ids": evidence_ids, "path": relative_path(root, report_path)})

        for path_id, body in report_sections(text, PATH_HEADING):
            path_type = field_value(body, "path_type").lower()
            evidence_ids = ids_in(body, EVIDENCE_ID)
            if path_type not in PATH_TYPES:
                issue(issues, "error", "path.type", path_id + " has unsupported path_type", relative_path(root, report_path))
            if not evidence_ids:
                issue(issues, "error", "path.evidence_missing", path_id + " has no evidence reference", relative_path(root, report_path))
            references.extend((evidence_id, relative_path(root, report_path)) for evidence_id in evidence_ids)
            path_records.append({"id": path_id, "path_type": path_type, "evidence_ids": evidence_ids, "path": relative_path(root, report_path)})
    return finding_records, path_records, references


def normalize_hash(value):
    normalized = value.strip().lower()
    if normalized.startswith("sha256:"):
        normalized = normalized[7:]
    if re.fullmatch(r"[0-9a-f]{64}", normalized):
        return normalized
    return ""


def is_within(root, path):
    try:
        return os.path.commonpath([str(root), str(path)]) == str(root)
    except ValueError:
        return False


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_artifact(root, artifact_path, expected_hash, issues, display_path):
    if not artifact_path:
        issue(issues, "warning", "artifact.path_missing", "content_hash is recorded without artifact_path", display_path)
        return
    candidate = Path(artifact_path)
    if not candidate.is_absolute():
        candidate = root / candidate
    candidate = candidate.resolve()
    if not is_within(root.resolve(), candidate):
        issue(issues, "warning", "artifact.outside_case", "artifact_path points outside the case root", display_path)
        return
    if not candidate.is_file():
        issue(issues, "error", "artifact.missing", "artifact_path does not exist", display_path)
        return
    digest = sha256_file(candidate)
    if digest != expected_hash:
        issue(issues, "error", "artifact.hash_mismatch", "artifact SHA-256 does not match content_hash", display_path)


def parse_evidence(root, workitems, issues, verify_hashes):
    evidence_root = root / "evidence"
    records = {}
    references = []
    if not evidence_root.is_dir():
        issue(issues, "error", "evidence.dir_missing", "evidence directory is missing", "evidence")
        return records, references

    evidence_files = sorted(path for path in evidence_root.glob("E-*.md") if path.name != "INDEX.md")
    if not evidence_files:
        issue(issues, "warning", "evidence.empty", "no Evidence records were found", "evidence")

    for path in evidence_files:
        evidence_id = path.stem
        text = path.read_text(encoding="utf-8-sig")
        heading = EVIDENCE_HEADING.search(text)
        if not heading:
            issue(issues, "error", "evidence.heading_missing", "Evidence record has no matching heading", relative_path(root, path))
        elif heading.group(1) != evidence_id:
            issue(issues, "error", "evidence.heading_mismatch", "Evidence heading does not match its filename", relative_path(root, path))

        severity = field_value(text, "severity").lower()
        status = field_value(text, "status").lower()
        if status.startswith("superseded by"):
            status = "superseded"
        repro_command = field_value(text, "repro_command")
        notes = field_value(text, "notes").lower()
        linked_workitems = ids_in(field_value(text, "linked_workitem"), WORKITEM_ID)
        content_hash_value = field_value(text, "content_hash")
        artifact_path = field_value(text, "artifact_path")
        if severity not in SEVERITIES:
            issue(issues, "error", "evidence.severity", "unsupported severity: " + severity, relative_path(root, path))
        if status not in EVIDENCE_STATUSES:
            issue(issues, "error", "evidence.status", "unsupported status: " + status, relative_path(root, path))
        offline_note = any(marker in notes for marker in ("offline", "离线", "not applicable"))
        if not repro_command or (repro_command.lower() in {"n/a", "n/a_re"} and not offline_note):
            issue(issues, "error", "evidence.repro_missing", "Evidence requires a reproducible command or documented offline limitation", relative_path(root, path))
        expected_hash = normalize_hash(content_hash_value) if content_hash_value.lower() != "n/a" else ""
        if content_hash_value.lower() != "n/a" and not expected_hash:
            issue(issues, "error", "evidence.hash_invalid", "content_hash must be SHA-256", relative_path(root, path))
        if verify_hashes and expected_hash:
            verify_artifact(root, artifact_path, expected_hash, issues, relative_path(root, path))
        for workitem_id in linked_workitems:
            if workitem_id not in workitems:
                issue(issues, "error", "evidence.workitem_missing", "linked work item does not exist: " + workitem_id, relative_path(root, path))
        records[evidence_id] = {"severity": severity, "status": status, "artifact_path": artifact_path}

    return records, references


def build_traceability(evidence_ids, references):
    graph = {evidence_id: {"workitems": 0, "timeline": 0, "reports": 0} for evidence_id in sorted(evidence_ids)}
    for evidence_id, source in references:
        if evidence_id not in graph:
            continue
        if source.startswith("workitems.md:"):
            graph[evidence_id]["workitems"] += 1
        elif source.startswith("timeline.md:"):
            graph[evidence_id]["timeline"] += 1
        else:
            graph[evidence_id]["reports"] += 1
    return graph


def review_case(case_root, strict=False, verify_hashes=False):
    root = Path(case_root).expanduser().resolve()
    issues = []
    if not root.is_dir():
        issue(issues, "error", "case.missing", "case root does not exist", str(root))
        return {
            "status": "FAIL",
            "case_root": str(root),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "summary": {"errors": 1, "warnings": 0, "evidence": 0, "workitems": 0, "timeline_events": 0, "findings": 0, "paths": 0},
            "issues": issues,
            "traceability": {},
        }

    workitems, workitem_refs = parse_workitems(root, issues)
    timeline_events, timeline_refs = parse_timeline(root, issues)
    scope = parse_scope(root, issues, strict)
    evidence, evidence_refs = parse_evidence(root, workitems, issues, verify_hashes)
    findings, paths, report_refs = parse_reports(root, issues)
    references = workitem_refs + timeline_refs + evidence_refs + report_refs

    for evidence_id, source in references:
        if evidence_id not in evidence:
            issue(issues, "error", "reference.unknown_evidence", "reference points to missing Evidence: " + evidence_id, source)

    traceability = build_traceability(evidence, references)
    for evidence_id, links in traceability.items():
        if not any(links.values()):
            issue(issues, "warning", "evidence.unlinked", "Evidence is not referenced by a work item, timeline, or report", "evidence/" + evidence_id + ".md")

    errors = sum(1 for item in issues if item["level"] == "error")
    warnings = sum(1 for item in issues if item["level"] == "warning")
    status = "FAIL" if errors or (strict and warnings) else "WARN" if warnings else "PASS"
    return {
        "status": status,
        "case_root": str(root),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "scope": scope,
        "summary": {
            "errors": errors,
            "warnings": warnings,
            "evidence": len(evidence),
            "workitems": len(workitems),
            "timeline_events": timeline_events,
            "findings": len(findings),
            "paths": len(paths),
        },
        "issues": issues,
        "traceability": traceability,
    }


def render_markdown(report):
    summary = report["summary"]
    lines = [
        "# Case review",
        "",
        "- status: " + report["status"],
        "- case_root: " + report["case_root"],
        "- generated_at: " + report["generated_at"],
        "",
        "## Summary",
        "",
        "| Metric | Value |",
        "|---|---:|",
    ]
    for key in ("errors", "warnings", "evidence", "workitems", "timeline_events", "findings", "paths"):
        lines.append("| " + key + " | " + str(summary[key]) + " |")

    lines.extend(["", "## Checks", "", "| Level | Code | Location | Detail |", "|---|---|---|---|"])
    if report["issues"]:
        for item in report["issues"]:
            location = item["path"].replace("|", "\\|")
            detail = item["message"].replace("|", "\\|")
            lines.append("| " + item["level"] + " | " + item["code"] + " | " + location + " | " + detail + " |")
    else:
        lines.append("| pass | none | n/a | No review issues found |")

    lines.extend(["", "## Traceability", "", "| Evidence | Work items | Timeline | Reports |", "|---|---:|---:|---:|"])
    if report["traceability"]:
        for evidence_id, links in report["traceability"].items():
            lines.append(
                "| " + evidence_id + " | " + str(links["workitems"]) + " | " + str(links["timeline"]) + " | " + str(links["reports"]) + " |"
            )
    else:
        lines.append("| n/a | 0 | 0 | 0 |")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Review a reverse-skill case for scope and Evidence graph integrity")
    parser.add_argument("case_root", help="Path to a work/<case> directory")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as a failed review")
    parser.add_argument("--verify-hashes", action="store_true", help="Verify SHA-256 content_hash values against artifact_path")
    args = parser.parse_args(argv)
    report = review_case(args.case_root, strict=args.strict, verify_hashes=args.verify_hashes)
    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(report), end="")
    return 1 if report["status"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
