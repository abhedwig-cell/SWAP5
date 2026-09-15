#!/usr/bin/env python3
"""F-VQ04 fail-closed admission gate for a real B1.10 terminal-failure fixture."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "538d51df4be3780a5bb092767304749dfc800899"
QUAL = "f56c5fe7cdbca36c3403fcd027c5998b0c7578f4"
OVERLAY_BASE = "c226988ae0782a7d8d0818f5d4aeaab61b696de4"
B1_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
B0_ARCHIVE = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
RETRYABLE = "B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git_parent(commit: str) -> str:
    return subprocess.check_output(
        ["git", "rev-parse", f"{commit}^"], cwd=ROOT, text=True
    ).strip()


def is_ancestor(commit: str) -> bool:
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
        cwd=ROOT,
        check=False,
    ).returncode == 0


def changed_paths() -> list[str]:
    out = subprocess.check_output(
        ["git", "diff", "--name-only", OVERLAY_BASE, "HEAD"], cwd=ROOT, text=True
    )
    return [x for x in out.splitlines() if x]


def validate_candidate(candidate: dict) -> dict[str, bool]:
    source = candidate.get("source", {})
    ttutil = candidate.get("ttutil", {})
    case = candidate.get("case", {})
    execution = candidate.get("execution", {})
    policy = candidate.get("policy_integrity", {})

    checks = {
        "work_unit": candidate.get("work_unit") == "F-VQ04",
        "oracle": candidate.get("oracle") == "B1.10",
        "source_head_exact": candidate.get("fci13_source_head") == SOURCE,
        "qualification_commit_exact": candidate.get("fci13_qualification_commit") == QUAL,
        "source_manifest_exact": source.get("source_manifest_sha256") == B1_MANIFEST,
        "b0_archive_exact": source.get("canonical_b0_archive_sha256") == B0_ARCHIVE,
        "production_source_not_modified": policy.get("production_source_modified_for_fixture") is False,
        "solver_tolerances_not_modified": policy.get("solver_tolerances_modified_for_fixture") is False,
        "retry_policy_not_modified": policy.get("retry_policy_modified_for_fixture") is False,
        "fatal_not_reclassified": policy.get("fatal_configuration_reclassified_as_retryable") is False,
        "case_not_modified_to_force_failure": case.get("physical_case_modified_to_force_failure") is False,
    }

    complete_external = (
        source.get("verified_external_source_tree_supplied") is True
        and ttutil.get("verified_external_root_supplied") is True
        and isinstance(ttutil.get("provenance_manifest_sha256"), str)
        and len(ttutil["provenance_manifest_sha256"]) == 64
        and case.get("verified_external_case_supplied") is True
        and isinstance(case.get("case_manifest_sha256"), str)
        and len(case["case_manifest_sha256"]) == 64
    )
    complete_execution = (
        execution.get("real_b1_10_physics_executed_for_terminal_failure") is True
        and execution.get("terminal_minimum_dt_marker_observed") is True
        and execution.get("returned_trial_status") == RETRYABLE
        and execution.get("failed_trial_state_restored") is True
        and execution.get("trial_mass_valid") is False
        and execution.get("rejected_trial_committed") is False
        and isinstance(execution.get("repeat_count"), int)
        and execution.get("repeat_count", 0) >= 2
        and isinstance(execution.get("execution_evidence_path"), str)
        and execution.get("execution_evidence_path")
        and isinstance(execution.get("execution_evidence_sha256"), str)
        and len(execution["execution_evidence_sha256"]) == 64
    )
    evidence_path_ok = False
    if complete_execution:
        p = ROOT / execution["execution_evidence_path"]
        evidence_path_ok = p.is_file() and sha256_file(p) == execution["execution_evidence_sha256"]

    requested = candidate.get("qualification_requested") is True
    claimed = candidate.get("real_terminal_failure_physics_qualified") is True
    if requested or claimed:
        checks["promotion_has_complete_external_identity"] = bool(complete_external)
        checks["promotion_has_complete_execution_observation"] = bool(complete_execution)
        checks["promotion_evidence_file_hash_matches"] = bool(evidence_path_ok)
        checks["promotion_status_qualified"] = candidate.get("status") == "QUALIFIED_REAL_B1_10_TERMINAL_FAILURE"
    else:
        checks["blocked_status_exact"] = candidate.get("status") == "BLOCKED_MISSING_EXTERNAL_EXECUTION_INPUTS"
        checks["real_physics_not_qualified"] = candidate.get("real_terminal_failure_physics_qualified") is False
        checks["no_real_failure_execution_claim"] = execution.get("real_b1_10_physics_executed_for_terminal_failure") is False

    return checks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--candidate",
        default="tools/vq/cases/fvq04-real-failure-fixture-candidate.json",
    )
    args = ap.parse_args()

    requirements = load_json(ROOT / "integration/f-vq/F-VQ04_REAL_FAILURE_FIXTURE_REQUIREMENTS.json")
    overlay = load_json(ROOT / "integration/f-vq/F-VQ04_CANONICAL_OVERLAY.json")
    candidate = load_json(ROOT / args.candidate)
    fci13_status = load_json(ROOT / "integration/f-ci/F-CI13_STATUS.json")
    failure = load_json(ROOT / "integration/f-ci/evidence/F-CI13_FAILURE_CLASSIFICATION.json")
    fci06 = load_json(ROOT / "integration/f-ci/evidence/F-CI06_LOCAL_EXACT_B1_10_GATE.json")
    full_gate = (ROOT / "tests/fci/run_fci07_full_b1_10_gate.sh").read_text(encoding="utf-8")

    paths = changed_paths()
    sections: dict[str, dict[str, bool]] = {}
    sections["provenance"] = {
        "qualification_parent_is_source": git_parent(QUAL) == SOURCE,
        "fci13_status_source_exact": fci13_status.get("qualified_source_head") == SOURCE,
        "fci13_ci_exact": fci13_status.get("qualification", {}).get("canonical_ci") == "PASS_RUN_34104845258_JOB_101687946143",
        "fci13_real_fixture_not_executed": fci13_status.get("qualification", {}).get("real_b1_10_forced_terminal_nonconvergence_fixture") == "NOT_YET_EXECUTED",
        "failure_evidence_source_exact": failure.get("qualified_source_head") == SOURCE,
        "failure_evidence_testdouble_limit_explicit": "deterministic legacy testdouble" in failure.get("qualification_limit", ""),
    }
    sections["canonical_overlay"] = {
        "overlay_base_is_ancestor": is_ancestor(OVERLAY_BASE),
        "overlay_record_exact": overlay.get("integration_overlay_base") == OVERLAY_BASE,
        "overlay_fci14_not_consumed": overlay.get("overlay_work_unit") == "F-CI14" and overlay.get("consumed_as_fvq04_qualification_basis") is False,
        "failure_basis_still_fci13": overlay.get("qualification_basis_remains", {}).get("fci13_source_head") == SOURCE and overlay.get("qualification_basis_remains", {}).get("fci13_qualification_commit") == QUAL,
    }
    sections["known_real_route"] = {
        "fci06_b1_manifest_exact": fci06.get("source", {}).get("source_manifest_sha256") == B1_MANIFEST,
        "fci06_hupsel_case_exact": fci06.get("build_and_run", {}).get("case") == "Hupsel 2002-2004",
        "full_gate_requires_b1_source": "FCI07_B1_10_SOURCE" in full_gate,
        "full_gate_requires_ttutil": "FCI07_TTUTIL_ROOT" in full_gate,
        "full_gate_requires_case": "FCI07_CASE" in full_gate,
        "requirements_record_same_gate": requirements.get("known_real_physics_route", {}).get("gate") == "tests/fci/run_fci07_full_b1_10_gate.sh",
    }
    sections["current_readiness"] = {
        "source_tree_absent": requirements.get("current_readiness", {}).get("repository_contains_complete_b1_10_source_tree") is False,
        "ttutil_absent": requirements.get("current_readiness", {}).get("repository_contains_ttutil_source_root") is False,
        "case_absent": requirements.get("current_readiness", {}).get("repository_contains_hupsel_case_files") is False,
        "fci13_artifacts_absent_recorded": requirements.get("current_readiness", {}).get("fci13_canonical_workflow_artifacts_present") is False,
        "fci11_artifacts_absent_recorded": requirements.get("current_readiness", {}).get("fci11_canonical_workflow_artifacts_present") is False,
        "real_execution_record_absent": requirements.get("current_readiness", {}).get("real_terminal_failure_execution_record_present") is False,
        "status_fail_closed": requirements.get("current_readiness", {}).get("status") == "BLOCKED_MISSING_EXTERNAL_EXECUTION_INPUTS",
    }
    sections["candidate"] = validate_candidate(candidate)
    sections["change_scope"] = {
        "diff_readable": True,
        "no_src_changes_since_overlay": not any(p.startswith("src/") for p in paths),
        "qualification_paths_only_since_overlay": all(
            p.startswith(("integration/f-vq/", "tools/vq/", "docs/verification/"))
            or p == ".github/workflows/vq-reference.yml"
            for p in paths
        ),
    }

    failed = [f"{s}.{k}" for s, checks in sections.items() for k, ok in checks.items() if not ok]
    current_claimed = candidate.get("real_terminal_failure_physics_qualified") is True
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ04",
        "oracle": "B1.10",
        "source_head": SOURCE,
        "integration_overlay_base": OVERLAY_BASE,
        "status": "PASS" if not failed else "FAIL",
        "failed": failed,
        "qualification_scope": "REAL_FAILURE_FIXTURE_ADMISSION_AND_READINESS_ONLY",
        "real_terminal_failure_physics_qualified": current_claimed and not failed,
        "real_failure_fixture_admission": "QUALIFIED" if current_claimed and not failed else "BLOCKED_FAIL_CLOSED",
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_source_changed_since_overlay": any(p.startswith("src/") for p in paths),
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
