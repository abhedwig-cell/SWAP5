#!/usr/bin/env python3
"""Validate the PUB-GC GMD pre-submission package.

Default mode validates all repository-controlled content while allowing
explicit governance/archive/author placeholders. --submission-ready additionally
requires those external fields to be resolved.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUB = ROOT / "docs" / "publication"

INV = PUB / "PUB_GC_GMD_PREARCHIVE_INVENTORY.json"
META = PUB / "PUB_GC_GMD_SUBMISSION_METADATA_DRAFT.md"
CODE = PUB / "PUB_GC_GMD_CODE_DATA_AVAILABILITY_TEMPLATE.md"
COVER = PUB / "PUB_GC_GMD_COVER_LETTER_DRAFT.md"
MAN = PUB / "PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md"
FIG = PUB / "PUB_GC_GMD_FIGURE_EXPORT_PLAN.json"
E7 = PUB / "PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json"
READY = PUB / "PUB_GC_SUBMISSION_READINESS.md"


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(data)).encode("ascii") + b"\0" + data
    ).hexdigest()


def fail(errors: list[str], msg: str) -> None:
    errors.append(msg)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--submission-ready", action="store_true")
    args = ap.parse_args()

    errors: list[str] = []

    inv = json.loads(INV.read_text(encoding="utf-8"))
    for item in inv["required_publication_assets"]:
        path = ROOT / item["path"]
        if not path.is_file():
            fail(errors, f"missing governed publication asset: {item['path']}")
            continue
        actual = git_blob_sha(path)
        if actual != item["blob"]:
            fail(
                errors,
                f"publication asset blob drift: {item['path']} "
                f"expected={item['blob']} actual={actual}",
            )

    man = MAN.read_text(encoding="utf-8")
    if "# 7. Code and data availability" not in man:
        fail(errors, "GMD availability heading missing")
    if "# 7. Code, evidence and reproducibility" in man:
        fail(errors, "stale pre-GMD section heading remains")
    if "REALISTIC_COMPONENT_DOMAIN_LIMIT" not in man:
        fail(errors, "E7 bounded outcome missing from manuscript")

    e7 = json.loads(E7.read_text(encoding="utf-8"))
    if e7.get("outcome") != "REALISTIC_COMPONENT_DOMAIN_LIMIT":
        fail(errors, "E7 outcome drift")
    coupled = e7.get("coupled_execution", {})
    for key in (
        "loose_completed_windows",
        "strong_completed_windows",
        "modflow_e7_windows_executed",
    ):
        if coupled.get(key) != 0:
            fail(errors, f"E7 zero-window guard violated: {key}={coupled.get(key)!r}")

    fig = json.loads(FIG.read_text(encoding="utf-8"))
    if len(fig.get("figures", [])) != 7:
        fail(errors, "figure export plan must contain seven figures")
    rule = fig.get("upload_rule", {})
    if rule.get("max_pdf_figure_mb") != 2:
        fail(errors, "GMD PDF figure limit must be 2 MB in export plan")
    if rule.get("max_other_figure_mb") != 5:
        fail(errors, "GMD non-PDF figure limit must be 5 MB in export plan")
    if rule.get("max_total_submission_mb_excluding_supplements") != 30:
        fail(errors, "GMD total non-supplement limit must be 30 MB")
    if rule.get("svg_direct_upload") is not False:
        fail(errors, "SVG must remain governed source, not direct production upload")
    for i, item in enumerate(fig.get("figures", []), 1):
        if item.get("target") != f"f{i:02d}.pdf":
            fail(errors, f"figure target mismatch for F{i}")
        src = ROOT / item.get("source", "")
        if not src.is_file():
            fail(errors, f"missing figure source: {item.get('source')}")

    meta = META.read_text(encoding="utf-8")
    m = re.search(
        r"Current candidate, below the 500-character GMD limit:\n\n> ([^\n]+)",
        meta,
    )
    if not m:
        fail(errors, "GMD short-summary candidate missing")
        summary_len = -1
    else:
        summary_len = len(m.group(1))
        if summary_len > 500:
            fail(errors, f"GMD short summary too long: {summary_len}")

    ready = READY.read_text(encoding="utf-8")
    if "CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT" not in ready:
        fail(errors, "submission readiness does not preserve E7 closure")

    required_new = [
        "PUB_GC_GMD_RELEASE_LICENSE_AUTHORITY_AUDIT.md",
        "PUB_GC_GMD_GOVERNANCE_DECISION_REQUEST.md",
        "PUB_GC_GMD_FIGURE_EXPORT_PLAN.md",
        "PUB_GC_GMD_FORMATTING_HANDOFF.md",
        "PUB_GC_GMD_MANUSCRIPT_PREPARATION_AUDIT.md",
        "PUB_GC_GMD_PRE_SUBMISSION_CHECKLIST.md",
        "PUB_GC_GMD_COVER_LETTER_DRAFT.md",
    ]
    for name in required_new:
        if not (PUB / name).is_file():
            fail(errors, f"missing GMD preparation asset: {name}")

    unresolved = [
        k for k, v in inv["final_archive_fields"].items() if not v
    ]

    placeholders: list[str] = []
    for path in (META, CODE, COVER):
        text = path.read_text(encoding="utf-8")
        placeholders.extend(
            f"{path.name}:{m.group(0)}"
            for m in re.finditer(r"<<[^>]+>>", text)
        )

    if errors:
        print("PUB_GC_GMD_CURRENT_PRESUBMISSION=FAIL")
        for e in errors:
            print("ERROR:", e)
        return 2

    print("PUB_GC_GMD_CURRENT_PRESUBMISSION=PASS")
    print(f"PUB_GC_GMD_REQUIRED_ASSET_BLOBS={len(inv['required_publication_assets'])}:PASS")
    print("PUB_GC_GMD_E7_ZERO_WINDOW_GUARD=PASS")
    print("PUB_GC_GMD_AVAILABILITY_HEADING=PASS")
    print("PUB_GC_GMD_FIGURE_EXPORT_POLICY=PASS")
    print(f"PUB_GC_GMD_SHORT_SUMMARY_CHARS={summary_len}")

    if unresolved:
        print("PUB_GC_GMD_ARCHIVAL_FIELDS=BLOCKED:" + ",".join(unresolved))
    else:
        print("PUB_GC_GMD_ARCHIVAL_FIELDS=RESOLVED")
    print(f"PUB_GC_GMD_PLACEHOLDER_COUNT={len(placeholders)}")

    if args.submission_ready and (unresolved or placeholders):
        print("PUB_GC_GMD_SUBMISSION_READY=FAIL")
        for u in unresolved:
            print("UNRESOLVED:", u)
        for p in placeholders:
            print("PLACEHOLDER:", p)
        return 3

    print(
        "PUB_GC_GMD_SUBMISSION_READY="
        + ("PASS" if not unresolved and not placeholders else "BLOCKED_GOVERNANCE_ARCHIVE_AUTHOR_METADATA")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
