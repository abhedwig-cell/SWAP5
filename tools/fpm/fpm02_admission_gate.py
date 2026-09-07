#!/usr/bin/env python3
"""Fail-closed F-PM02 admission gate for first SNOW production migration.

This gate inspects one candidate Git ref. It never merges branches and never
modifies production source. Admission requires:
  * F-CI18 ancestry;
  * a composed downstream candidate that is TESTED and QUALIFIED;
  * explicit physical SWAP admission, not merely deterministic runtime tests;
  * the qualified F-KT05 minimum transaction boundary;
  * one explicitly accepted source-bound F-SI lineage (currently F-SI05/06);
  * byte-identical B1.10 oracle infrastructure.

Unknown/newer solver lineages fail closed until their qualification evidence is
read and explicitly admitted by F-PM.
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
FMR_QUALIFICATION_PATH = "integration/f-mr/F-MR01_QUALIFICATION_EVIDENCE.json"

FKT_STATUS_PATH = "integration/f-kt/F-KT05_STATUS.json"
FKT_TESTED_POSTIMAGE = "f7d2ee5e81f1d6686c96114984239e97ba6a8a8a"
FKT_QUALIFICATION_EVIDENCE = "6911549acbcb62ef8af9ae2d96d5b4f938daf1e2"
FKT_KERNEL_PATH = "src/kernel/mod_kernel_transactions.f90"
FKT_KERNEL_BLOB = "e8605e73a191e863374a26b096e0d597cb70cadd"

B110_SNAPSHOT_PATH = "reference/swap-4.3.1/snapshots/B1.10.yml"
B110_SNAPSHOT_BLOB = "8d768f00d47224a663941f79bb2d35eacc66d16b"
B110_RECONSTRUCT_PATH = "tools/vq/b1_10_reconstruct.py"
B110_RECONSTRUCT_BLOB = "b6d3c78c8a84a82e5c02320c83e87d250a3ad401"
B110_MANIFEST_SHA256 = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
SNOW_SOURCE_SHA256 = "02f36d30448b94dfdf386bc43424f1fe0feff9eafd24a768a8c702843a0bf9b2"

SOLVER_VARIANTS = [
    {
        "id": "F-SI06",
        "qualification_path": "integration/f-si/F-SI06_QUALIFICATION.json",
        "status": "QUALIFIED_HISTORY_ISOLATION_PARALLEL_BINDING_BLOCKED",
        "final_kind": "verified_head",
        "verified_head": "2fa63c41a4d7248ab7f4b5af46f72caddfda4f29",
        "blobs": {
            "src/legacy/b1_10_port/headcalc.f90": "38de52dd9f13b70a61f418c29a5c2e4bc9a449a9",
            "src/legacy/b1_10_port/soilwater.f90": "aa072804768b7a982b275d3a7d6988bfed6b9faa",
            "src/solver/mod_reference_richards_workspace.f90": "93285b2ca24669494c93c00403e3783fca6758e9",
            "src/adapter/mod_reference_richards_legacy_binding.f90": "f60f7ef2d60ccb8cc78e80d56ef88a739e50ab2e",
        },
    },
    {
        "id": "F-SI05",
        "qualification_path": "integration/f-si/F-SI05_QUALIFICATION.json",
        "status": "QUALIFIED_PRODUCTION_WORKSPACE_SEAM_FOCUSED_ROUTES_ONLY",
        "final_kind": "no_verification_required",
        "blobs": {
            "src/legacy/b1_10_port/headcalc.f90": "e22251c8f562839857cdb7a609a8148d1f2d58f8",
            "src/solver/mod_reference_richards_workspace.f90": "93285b2ca24669494c93c00403e3783fca6758e9",
            "src/adapter/mod_reference_richards_legacy_binding.f90": "e02882bd45f67b42ede118de14a6b5b8b16fdb80",
        },
    },
]


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


def evaluate_solver_variant(candidate: str, variant: dict[str, Any]) -> tuple[bool, list[Check]]:
    checks: list[Check] = []
    qual = show_json(candidate, variant["qualification_path"])
    checks.append(Check(
        f'{variant["id"]}:qualification_present_and_json',
        qual is not None,
        qual is not None,
        True,
    ))
    add(checks, f'{variant["id"]}:qualified', nested(qual, "qualified"), True)
    add(checks, f'{variant["id"]}:status', nested(qual, "status"), variant["status"])

    if variant["final_kind"] == "verified_head":
        add(checks, f'{variant["id"]}:final_verified', nested(qual, "final_postimage_verification", "verified"), True)
        add(
            checks,
            f'{variant["id"]}:final_verified_head',
            nested(qual, "final_postimage_verification", "head"),
            variant["verified_head"],
        )
    elif variant["final_kind"] == "no_verification_required":
        add(
            checks,
            f'{variant["id"]}:final_postimage_complete',
            nested(qual, "final_postimage_verification_required"),
            False,
        )

    for path, expected_blob in variant["blobs"].items():
        add(checks, f'{variant["id"]}:blob:{path}', blob(candidate, path), expected_blob)

    return all(c.passed for c in checks), checks


def evaluate_candidate(ref: str) -> dict[str, Any]:
    checks: list[Check] = []
    candidate = resolve(ref)
    checks.append(Check("candidate_ref_resolves", candidate is not None, candidate, "commit"))
    if candidate is None:
        return result(ref, None, checks, None, [])

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
    add(checks, "shared_downstream_physical_swap_runtime", nested(fmr, "downstream_release", "physical_swap_runtime"), True)

    fmrq = show_json(candidate, FMR_QUALIFICATION_PATH)
    checks.append(Check("shared_downstream_qualification_present_and_json", fmrq is not None, fmrq is not None, True))
    add(checks, "shared_downstream_qualification_status", nested(fmrq, "qualification_status"), "QUALIFIED")
    add(checks, "shared_downstream_physical_swap_admission", nested(fmrq, "admission_scope", "physical_swap_admission"), True)

    fkt = show_json(candidate, FKT_STATUS_PATH)
    checks.append(Check("fkt05_status_present_and_json", fkt is not None, fkt is not None, True))
    add(checks, "fkt05_qualified", nested(fkt, "qualified"), True)
    add(checks, "fkt05_tested_postimage", nested(fkt, "tested_postimage"), FKT_TESTED_POSTIMAGE)
    add(checks, "fkt05_qualification_evidence", nested(fkt, "qualification_evidence_commit"), FKT_QUALIFICATION_EVIDENCE)
    add(checks, "fkt05_kernel_blob", blob(candidate, FKT_KERNEL_PATH), FKT_KERNEL_BLOB)

    solver_attempts: list[dict[str, Any]] = []
    accepted_solver: str | None = None
    for variant in SOLVER_VARIANTS:
        passed, variant_checks = evaluate_solver_variant(candidate, variant)
        solver_attempts.append({
            "id": variant["id"],
            "passed": passed,
            "checks": [asdict(c) for c in variant_checks],
        })
        if passed and accepted_solver is None:
            accepted_solver = variant["id"]

    checks.append(Check(
        "accepted_qualified_solver_lineage",
        accepted_solver is not None,
        accepted_solver,
        "one of F-SI05/F-SI06 exact qualified postimages",
        "Unknown/newer solver postimages fail closed until explicitly admitted.",
    ))

    add(checks, "b1_10_snapshot_blob", blob(candidate, B110_SNAPSHOT_PATH), B110_SNAPSHOT_BLOB)
    add(checks, "b1_10_reconstruction_blob", blob(candidate, B110_RECONSTRUCT_PATH), B110_RECONSTRUCT_BLOB)
    checks.append(Check("b1_10_manifest_pin", True, B110_MANIFEST_SHA256, B110_MANIFEST_SHA256))
    checks.append(Check("snow_source_pin", True, SNOW_SOURCE_SHA256, SNOW_SOURCE_SHA256))
    checks.append(Check("qualified_production_source_pin", True, QUALIFIED_PRODUCTION_SOURCE, QUALIFIED_PRODUCTION_SOURCE))

    return result(ref, candidate, checks, accepted_solver, solver_attempts)


def result(
    ref: str,
    candidate: str | None,
    checks: list[Check],
    accepted_solver: str | None,
    solver_attempts: list[dict[str, Any]],
) -> dict[str, Any]:
    admitted = bool(checks) and all(c.passed for c in checks)
    return {
        "schema_version": 3,
        "workstream": "F-PM",
        "work_unit": "F-PM02",
        "candidate_ref": ref,
        "candidate_commit": candidate,
        "admitted": admitted,
        "production_migration_allowed": admitted,
        "accepted_solver_lineage": accepted_solver,
        "checks": [asdict(c) for c in checks],
        "solver_lineage_attempts": solver_attempts,
        "holds_if_rejected": [
            "Do not modify production process source.",
            "Do not merge F-KT/F-SI/F-MR lineages inside F-PM.",
            "Do not treat deterministic runtime qualification as physical SWAP admission.",
            "Do not consume unknown/newer F-SI postimages without explicit source-bound qualification review.",
            "Do not infer generic-duration/subdaily snow scaling from B1.10 one-call semantics.",
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
