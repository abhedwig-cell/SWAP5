#!/usr/bin/env python3
"""Validate the bounded F-DOC17 post-closure Status-A reconciliation.

This gate qualifies only the internal consistency and scope discipline of the
reconciliation artifact. It does not certify WUR Status A or Status AA.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATUS = ROOT / "integration/f-doc/F-DOC17_STATUS.json"
REPORT = ROOT / "docs/development/f-doc17-post-closure-status-a-reconciliation.md"

ALLOWED_CHANGED_FILES = {
    ".github/workflows/fdoc17-post-closure-status-a-reconciliation.yml",
    "docs/development/f-doc17-post-closure-status-a-reconciliation.md",
    "integration/f-doc/F-DOC17_STATUS.json",
    "tools/docs/validate_fdoc17_post_closure_status_a.py",
}

EXPECTED_COUNTS = {
    "SATISFIED": 2,
    "EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE": 0,
    "DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE": 3,
    "PARTIAL": 13,
    "MISSING": 4,
    "NOT_APPLICABLE_WITH_RATIONALE": 0,
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"F-DOC17 validation failed: {message}")


def changed_files(base_sha: str) -> set[str]:
    output = subprocess.check_output(
        ["git", "diff", "--name-only", f"{base_sha}...HEAD"],
        cwd=ROOT,
        text=True,
    )
    return {line.strip() for line in output.splitlines() if line.strip()}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    args = parser.parse_args()

    require(STATUS.is_file(), "status JSON missing")
    require(REPORT.is_file(), "reconciliation report missing")

    data = json.loads(STATUS.read_text(encoding="utf-8"))
    report = REPORT.read_text(encoding="utf-8")

    require(data["schema"] == "swap5.fdoc17.status.v1", "unexpected schema")
    require(data["work_unit"] == "F-DOC17", "unexpected work unit")
    require(
        data["decision"]
        == "QUALIFIED_POST_CLOSURE_RECONCILIATION_STATUS_A_FORMAL_ASSESSMENT_NOT_YET_JUSTIFIED",
        "unexpected qualification decision",
    )
    require(data["formal_status_a_certified"] is False, "Status A may not be certified")
    require(data["formal_status_aa_certified"] is False, "Status AA may not be certified")
    require(
        data["baseline"]["canonical_commit"] == args.base_sha,
        "status baseline does not equal PR base SHA",
    )
    require(
        data["qualification"]["exact_head_authority"] == "GITHUB_PULL_REQUEST_HEAD",
        "exact-head authority must be supplied by the workflow event, not self-pinned in the status file",
    )
    require(
        data["qualification"]["gate"] == "F-DOC17 Post-Closure Status-A Reconciliation",
        "unexpected qualification gate name",
    )
    require(
        data["qualification"]["valid_only_when_gate_passes_exact_head"] is True,
        "qualification must remain conditional on the exact-head gate",
    )
    require(
        data["wur_criterion_gate"]["controlled_full_text_established"] is False,
        "controlled WR-QA-2024 text must remain unresolved unless separately evidenced",
    )
    require(data["wur_criterion_gate"]["formal_assessment_blocked"] is True, "formal assessment must remain blocked")

    counts = data["public_22_readiness_counts"]
    for key, expected in EXPECTED_COUNTS.items():
        require(counts[key] == expected, f"unexpected count for {key}")
    require(sum(counts[key] for key in EXPECTED_COUNTS) == 22, "public readiness denominator is not 22")
    require(counts["counts_are_compliance_percentage"] is False, "counts may not be relabelled as compliance percentage")

    required_report_phrases = [
        "does not certify Status A or Status AA",
        "F-DOC18 is not an ancestor of the live canonical head",
        "F-DOC19",
        "hard mass closure is not a T12 validation study",
        "CURRENT_CANONICAL_MATERIALLY_STRONGER_STATUS_A_FORMAL_ASSESSMENT_NOT_YET_JUSTIFIED",
    ]
    for phrase in required_report_phrases:
        require(phrase in report, f"required report boundary missing: {phrase}")

    actual_changed = changed_files(args.base_sha)
    require(
        actual_changed == ALLOWED_CHANGED_FILES,
        f"workunit diff escaped bounded documentation scope: {sorted(actual_changed)}",
    )

    forbidden_prefixes = ("src/", "reference/", "tests/")
    require(
        not any(path.startswith(forbidden_prefixes) for path in actual_changed),
        "production/reference/test source changed",
    )

    print("F-DOC17 bounded reconciliation validation: PASS")
    print(f"base={args.base_sha}")
    print(f"head={args.head_sha}")
    print("changed_files=" + ",".join(sorted(actual_changed)))


if __name__ == "__main__":
    main()
