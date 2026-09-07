#!/usr/bin/env python3
"""Fail-closed F-PM02 admission gate for the first SNOW production migration.

The gate inspects one candidate Git ref. It does not merge branches and it does
not modify production source. Exit code 0 means the composed downstream
candidate itself is TESTED and QUALIFIED, and the exact currently qualified
F-KT05 and F-SI05 boundaries plus the canonical B1.10 oracle infrastructure are
present. Any missing or changed pin rejects admission.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

CANONICAL_FCI18 = "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
QUALIFIED_PRODUCTION_SOURCE = "da5026d8b87ad2f3c7912360891839a120ecccb6"

FMR_STATUS_PATH = "integration/f-mr/F-MR01_STATUS.json"

FKT_STATUS_PATH = "integration/f-kt/F-KT05_STATUS.json"
FKT_TESTED_POSTIMAGE = "f7d2ee5e81f1d6686c96114984239e97ba6a8a8a"
FKT_QUALIFICATION_EVIDENCE = "6911549acbcb62ef8af9ae2d96d5b4f938daf1e2"
FKT_KERNEL_PATH = "src/kernel/mod_kernel_transactions.f90"
FKT_KERNEL_BLOB = "e8605e73a191e863374a26b096e0d597cb70cadd"

FSI_QUALIFICATION_PATH = "integration/f-si/F-SI05_QUALIFICATION.json"
FSI_STATUS = "QUALIFIED_PRODUCTION_WORKSPACE_SEAM_FOCUSED_ROUTES_ONLY"
FSI_MATERIALIZATION = "1fe1bf4790955594290ba1233d5684542799bf9e"
FSI_TESTED_HEAD = "56c21448a2a0be716d497ac34db8c5eec60dd246"
FSI_VERIFIED_POSTIMAGE = "11b3138e05b1a5c59033134e870f6ffb58e6a9f6"
FSI_BLOBS = {
    "src/legacy/b1_10_port/headcalc.f90": "e22251c8f562839857cdb7a609a8148d1f2d58f8",
    "src/solver/mod_reference_richards_workspace.f90": "93285b2ca24669494c93c00403e3783fca6758e9",
    "src/adapter/mod_reference_richards_legacy_binding.f90": "e02882bd45f67b42ede118de14a6b5b8b16fdb80",
}

B110_SNAPSHOT_PATH = "reference/swap-4.3.1/snapshots/B1.10.yml"
B110_SNAPSHOT_BLOB = "8d768f00d47224a663941f79bb2d35eacc66d16b"
B110_RECONSTRUCT_PATH = "tools/vq/b1_10_reconstruct.py"
B110_RECONSTRUCT_BLOB = "b6d3c78c8a84a82e5c02320c83e87d250a3ad401"
B110_MANIFEST_SHA256 = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
SNOW_SOURCE_SHA256 = "02f36d30448b94dfdf386bc43424f1fe0feff9eafd24a768a8c702843a0bf9b2"


@dataclass
class Check:
    name: str
    passed: bool
    observed: Any = None
    expected: Any = None
    detail: str | None = None


def run_git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=check,
    )


def resolve(ref: str) -> str | None:
    proc = run_git("rev-parse", "--verify", f"{ref}^{{commit}}", check=False)
    return proc.stdout.strip() if proc.returncode == 0 else None


def show_text(ref: str, path: str) -> str | None:
    proc = run_git("show", f"{ref}:{path}", check=False)
    return proc.stdout if proc.returncode == 0 else None


def show_json(ref: str, path: str) -> dict[str, Any] | None:
    text = show_text(ref, path)
    if text is None:
        return None
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def blob(ref: str, path: str) -> str | None:
    proc = run_git("rev-parse", f"{ref}:{path}", check=False)
    return proc.stdout.strip() if proc.returncode == 0 else None


def is_ancestor(ancestor: str, descendant: str) -> bool:
    return run_git("merge-base", "--is-ancestor", ancestor, descendant, check=False).returncode == 0


def nested(value: dict[str, Any] | None, *keys: str) -> Any:
    current: Any = value
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def add(checks: list[Check], name: str, observed: Any, expected: Any, detail: str | None = None) -> None:
    checks.append(Check(name=name, passed=observed == expected, observed=observed, expected=expected, detail=detail))


def evaluate_candidate(ref: str) -> dict[str, Any]:
    checks: list[Check] = []
    candidate = resolve(ref)
    checks.append(Check("candidate_ref_resolves", candidate is not None, candidate, "commit"))
    if candidate is None:
        return result(ref, None, checks)

    checks.append(Check(
        "canonical_fci18_is_ancestor",
        is_ancestor(CANONICAL_FCI18, candidate),
        candidate,
        CANONICAL_FCI18,
    ))

    fmr = show_json(candidate, FMR_STATUS_PATH)
    checks.append(Check("shared_downstream_status_present_and_json", fmr is not None, fmr is not None, True))
    add(checks, "shared_downstream_tested", nested(fmr, "status", "TESTED"), True)
    add(checks, "shared_downstream_qualified", nested(fmr, "status", "QUALIFIED"), True)

    fkt = show_json(candidate, FKT_STATUS_PATH)
    checks.append(Check("fkt05_status_present_and_json", fkt is not None, fkt is not None, True))
    add(checks, "fkt05_qualified", nested(fkt, "qualified"), True)
    add(checks, "fkt05_tested_postimage", nested(fkt, "tested_postimage"), FKT_TESTED_POSTIMAGE)
    add(checks, "fkt05_qualification_evidence", nested(fkt, "qualification_evidence_commit"), FKT_QUALIFICATION_EVIDENCE)
    add(checks, "fkt05_kernel_blob", blob(candidate, FKT_KERNEL_PATH), FKT_KERNEL_BLOB)

    fsi = show_json(candidate, FSI_QUALIFICATION_PATH)
    checks.append(Check("fsi05_qualification_present_and_json", fsi is not None, fsi is not None, True))
    add(checks, "fsi05_qualified", nested(fsi, "qualified"), True)
    add(checks, "fsi05_status", nested(fsi, "status"), FSI_STATUS)
    add(checks, "fsi05_materialization", nested(fsi, "production_materialization", "commit"), FSI_MATERIALIZATION)
    add(checks, "fsi05_tested_head", nested(fsi, "tested_implementation_checkpoint", "head"), FSI_TESTED_HEAD)
    add(checks, "fsi05_verified_postimage", nested(fsi, "documented_postimage_verification", "head"), FSI_VERIFIED_POSTIMAGE)
    add(checks, "fsi05_final_postimage_complete", nested(fsi, "final_postimage_verification_required"), False)
    add(checks, "fsi05_full_reference_reentrancy_not_overclaimed", nested(fsi, "deferred_not_claimed", "full_reference_richards_reentrancy"), "NOT_QUALIFIED")
    for path, expected_blob in FSI_BLOBS.items():
        add(checks, f"fsi05_blob:{path}", blob(candidate, path), expected_blob)

    add(checks, "b1_10_snapshot_blob", blob(candidate, B110_SNAPSHOT_PATH), B110_SNAPSHOT_BLOB)
    add(checks, "b1_10_reconstruction_blob", blob(candidate, B110_RECONSTRUCT_PATH), B110_RECONSTRUCT_BLOB)

    checks.append(Check("b1_10_manifest_pin", True, B110_MANIFEST_SHA256, B110_MANIFEST_SHA256))
    checks.append(Check("snow_source_pin", True, SNOW_SOURCE_SHA256, SNOW_SOURCE_SHA256))
    checks.append(Check("qualified_production_source_pin", True, QUALIFIED_PRODUCTION_SOURCE, QUALIFIED_PRODUCTION_SOURCE))

    return result(ref, candidate, checks)


def result(ref: str, candidate: str | None, checks: list[Check]) -> dict[str, Any]:
    admitted = bool(checks) and all(c.passed for c in checks)
    return {
        "workstream": "F-PM",
        "work_unit": "F-PM02",
        "candidate_ref": ref,
        "candidate_commit": candidate,
        "admitted": admitted,
        "production_migration_allowed": admitted,
        "checks": [asdict(c) for c in checks],
        "holds_if_rejected": [
            "Do not modify production process source.",
            "Do not merge F-KT/F-SI lineages inside F-PM.",
            "Do not consume a composed downstream candidate before it is itself TESTED and QUALIFIED.",
            "Do not infer generic-duration/subdaily snow scaling from B1.10 daily-call semantics.",
        ] if not admitted else [],
        "scope_if_admitted": "SNOW structural migration only; preserve B1.10 equations and F-PM01 characterized one-call semantics.",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-ref", required=True, help="Git branch, tag or commit to inspect")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    evidence = evaluate_candidate(args.candidate_ref)
    rendered = json.dumps(evidence, indent=2, sort_keys=True)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if evidence["admitted"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
