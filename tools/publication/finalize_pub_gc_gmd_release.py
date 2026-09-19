#!/usr/bin/env python3
"""Fail-closed finalization gate for the PUB-GC GMD package.

Default mode verifies repository-controlled publication content while allowing
explicit governance/archive/author fields to remain unresolved.

Strict modes:
  --authority-ready  require governed release + licence authority.
  --archive-ready    additionally require exact checked-out publication commit
                     and a persistent archive PID/DOI.
  --submission-ready additionally require all journal placeholders resolved.

The tool never chooses governance values.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUB = ROOT / "docs" / "publication"

INPUT = PUB / "PUB_GC_GMD_FINALIZATION_INPUT.json"
INV = PUB / "PUB_GC_GMD_PREARCHIVE_INVENTORY.json"
MAN = PUB / "PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md"
META = PUB / "PUB_GC_GMD_SUBMISSION_METADATA_DRAFT.md"
CODE = PUB / "PUB_GC_GMD_CODE_DATA_AVAILABILITY_TEMPLATE.md"
COVER = PUB / "PUB_GC_GMD_COVER_LETTER_DRAFT.md"
E7 = PUB / "PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json"

PLACEHOLDER_RE = re.compile(r"<<[^>]+>>")
HEX40_RE = re.compile(r"^[0-9a-f]{40}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}(?:T.*)?$")


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(data)).encode("ascii") + b"\0" + data
    ).hexdigest()


def current_head() -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def exact_external_zips() -> list[str]:
    hits: list[str] = []
    for path in ROOT.rglob("*.zip"):
        if ".git" in path.parts:
            continue
        if re.match(r"(?i)^SWAP[_ ]4\.3\.1(?:\([^)]*\))?\.zip$", path.name):
            hits.append(str(path.relative_to(ROOT)))
    return sorted(hits)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    ap = argparse.ArgumentParser()
    strict = ap.add_mutually_exclusive_group()
    strict.add_argument("--authority-ready", action="store_true")
    strict.add_argument("--archive-ready", action="store_true")
    strict.add_argument("--submission-ready", action="store_true")
    ap.add_argument("--emit", type=Path)
    args = ap.parse_args()

    authority_required = (
        args.authority_ready or args.archive_ready or args.submission_ready
    )
    archive_required = args.archive_ready or args.submission_ready
    submission_required = args.submission_ready

    errors: list[str] = []
    cfg = json.loads(INPUT.read_text(encoding="utf-8"))
    inv = json.loads(INV.read_text(encoding="utf-8"))
    e7 = json.loads(E7.read_text(encoding="utf-8"))

    # Publication-critical content identity.
    drift = []
    for item in inv["required_publication_assets"]:
        path = ROOT / item["path"]
        if not path.is_file():
            drift.append(f"missing:{item['path']}")
            continue
        actual = git_blob_sha(path)
        if actual != item["blob"]:
            drift.append(
                f"blob:{item['path']}:expected={item['blob']}:actual={actual}"
            )
    if drift:
        for item in drift:
            fail(errors, "publication asset drift: " + item)

    # Scientific E7 guard.
    if e7.get("outcome") != "REALISTIC_COMPONENT_DOMAIN_LIMIT":
        fail(errors, "E7 bounded outcome drift")
    coupled = e7.get("coupled_execution", {})
    for key in (
        "loose_completed_windows",
        "strong_completed_windows",
        "modflow_e7_windows_executed",
    ):
        if coupled.get(key) != 0:
            fail(errors, f"E7 zero-window guard violated: {key}={coupled.get(key)!r}")

    # Historical reference bytes must not enter the public repository package.
    external = exact_external_zips()
    if external:
        for path in external:
            fail(errors, f"externally governed SWAP 4.3.1 zip present in worktree: {path}")

    # R1/L1 authority.
    rid = cfg.get("release_identifier")
    lic = cfg.get("software_license_and_redistribution_statement")
    authority = cfg.get("authority_name_role_or_record")
    effective = cfg.get("effective_date")
    if authority_required:
        if not nonempty(rid):
            fail(errors, "R1 release identifier unresolved")
        elif rid.strip() == "SWAP5-RB1-v1":
            fail(errors, "immutable predecessor SWAP5-RB1-v1 cannot be reused")
        if not nonempty(lic):
            fail(errors, "L1 licence/redistribution statement unresolved")
        if not nonempty(authority):
            fail(errors, "governing authority record unresolved")
        if not nonempty(effective) or not DATE_RE.match(str(effective)):
            fail(errors, "authority effective date unresolved/invalid")

    # Archive binding.
    head = current_head()
    commit = cfg.get("publication_commit")
    pid = cfg.get("archive_pid_or_doi")
    archived_at = cfg.get("archive_created_at")
    if archive_required:
        if not nonempty(commit) or not HEX40_RE.match(str(commit)):
            fail(errors, "exact publication commit unresolved/invalid")
        elif commit != head:
            fail(errors, f"publication commit does not match checked-out HEAD: {commit} != {head}")
        if not nonempty(pid):
            fail(errors, "persistent archive DOI/PID unresolved")
        if not nonempty(archived_at) or not DATE_RE.match(str(archived_at)):
            fail(errors, "archive creation date unresolved/invalid")

    # Final journal-facing metadata.
    placeholders: list[str] = []
    for path in (MAN, META, CODE, COVER):
        content = path.read_text(encoding="utf-8")
        placeholders.extend(
            f"{path.name}:{m.group(0)}" for m in PLACEHOLDER_RE.finditer(content)
        )
    if submission_required:
        if not cfg.get(
            "author_affiliation_contribution_funding_interest_metadata_resolved",
            False,
        ):
            fail(errors, "author/affiliation/contribution/funding/interest metadata unresolved")
        for p in placeholders:
            fail(errors, "unresolved submission placeholder: " + p)
        if nonempty(rid) and str(rid) not in MAN.read_text(encoding="utf-8"):
            fail(errors, "final manuscript does not contain governed release identifier")

    if args.emit and not archive_required:
        fail(errors, "--emit requires --archive-ready or --submission-ready")

    if errors:
        print("PUB_GC_GMD_FINALIZATION=FAIL")
        for error in errors:
            print("ERROR:", error)
        return 2

    blockers = []
    for key in (
        "release_identifier",
        "software_license_and_redistribution_statement",
        "authority_name_role_or_record",
        "effective_date",
        "publication_commit",
        "archive_pid_or_doi",
        "archive_created_at",
    ):
        if not nonempty(cfg.get(key)):
            blockers.append(key)
    if not cfg.get(
        "author_affiliation_contribution_funding_interest_metadata_resolved",
        False,
    ):
        blockers.append("author_affiliation_contribution_funding_interest_metadata")

    print("PUB_GC_GMD_FINALIZATION=PASS")
    print(f"PUB_GC_GMD_PUBLICATION_ASSET_BLOBS={len(inv['required_publication_assets'])}:PASS")
    print("PUB_GC_GMD_E7_REALISTIC_COMPONENT_DOMAIN_LIMIT=PASS")
    print("PUB_GC_GMD_EXTERNAL_SWAP431_ZIP_ABSENT=PASS")
    print("PUB_GC_GMD_CHECKED_OUT_HEAD=" + head)
    print("PUB_GC_GMD_UNRESOLVED=" + (",".join(blockers) if blockers else "NONE"))
    print(f"PUB_GC_GMD_PLACEHOLDERS={len(placeholders)}")

    if args.emit:
        binding = {
            "schema": "pub-gc-gmd-final-archive-binding-v1",
            "release_identifier": rid,
            "publication_commit": commit,
            "software_license_and_redistribution_statement": lic,
            "authority_name_role_or_record": authority,
            "effective_date": effective,
            "archive_pid_or_doi": pid,
            "archive_created_at": archived_at,
            "historical_swap431": {
                "redistributed": False,
                "sha256": inv["exact_external_reference"]["sha256"],
                "size_bytes": inv["exact_external_reference"]["size_bytes"],
                "review_access_statement": cfg.get(
                    "historical_swap431_review_access_statement"
                ),
            },
            "e7": {
                "outcome": "REALISTIC_COMPONENT_DOMAIN_LIMIT",
                "loose_completed_windows": 0,
                "strong_completed_windows": 0,
                "modflow_e7_windows_executed": 0,
            },
            "publication_assets": inv["required_publication_assets"],
        }
        args.emit.write_text(
            json.dumps(binding, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print("PUB_GC_GMD_FINAL_ARCHIVE_BINDING=" + str(args.emit))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
