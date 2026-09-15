#!/usr/bin/env python3
"""F-VQ12 source-bound F-KT05/F-SI05 admission gate."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FVQ11_FINAL = "efdc11f35e2251eebbab888e05d74085892e05fd"
FCI18 = "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
FKT05_TESTED = "f7d2ee5e81f1d6686c96114984239e97ba6a8a8a"
FKT05_EVIDENCE = "6911549acbcb62ef8af9ae2d96d5b4f938daf1e2"
FKT05_STATUS = "f50b8cd20221fac27a2059b6c6192ed0b7384be8"
FSI05_TESTED = "56c21448a2a0be716d497ac34db8c5eec60dd246"
FSI05_DOCUMENTED = "11b3138e05b1a5c59033134e870f6ffb58e6a9f6"
FSI05_FINAL = "0227ae94edc3364b013f831f1efa6aaccac29b11"
FKT05_RUN = 34125537033
FKT05_FOCUSED_JOB = 101753225852
FKT05_FCI_JOB = 101753290988
FSI05_TEST_RUN = 34124675751
FSI05_TEST_JOB = 101750448325
FSI05_DOC_RUN = 34125047417
FSI05_DOC_JOB = 101751648325

STATUS_PATH = ROOT / "integration/f-vq/F-VQ12_STATUS.json"
MATRIX_PATH = ROOT / "integration/f-vq/F-VQ12_ADMISSION_MATRIX.json"
SCOPE_PATH = ROOT / "integration/f-vq/F-VQ12_SCOPE.json"
EVIDENCE_PATH = ROOT / "integration/f-vq/evidence/F-VQ12_QUALIFICATION.json"
QUALIFIABLE = {f"FVQ12-C{i:02d}" for i in range(1, 6)}
BLOCKED = {f"FVQ12-C{i:02d}" for i in range(6, 12)}
ALLOWED_HEAD_PATHS = (
    "integration/f-vq/",
    "tools/vq/",
    "docs/verification/",
    ".github/workflows/fvq11-downstream.yml",
    ".github/workflows/fvq12-downstream.yml",
    ".github/workflows/vq-reference.yml",
)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def is_ancestor(base: str, head: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", base, head], cwd=ROOT).returncode == 0


def changed(base: str, head: str = "HEAD") -> list[str]:
    out = git("diff", "--name-only", base, head)
    return [line for line in out.splitlines() if line]


def json_at(commit: str, path: str) -> dict:
    return json.loads(git("show", f"{commit}:{path}"))


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_matrix(matrix: dict, status: dict) -> dict[str, bool]:
    claims = {c.get("claim_id"): c for c in matrix.get("claims", [])}
    qualified = bool(status.get("qualified"))
    return {
        "claim_set_exact": set(claims) == QUALIFIABLE | BLOCKED,
        "qualifiable_targets": all(claims.get(cid, {}).get("target") == "QUALIFIABLE" for cid in QUALIFIABLE),
        "blocked_targets": all(claims.get(cid, {}).get("target") == "BLOCKED_FAIL_CLOSED" for cid in BLOCKED),
        "qualifiable_flags_follow_status": all(bool(claims.get(cid, {}).get("claim_qualified")) == qualified for cid in QUALIFIABLE),
        "blocked_flags_false": all(claims.get(cid, {}).get("claim_qualified") is False for cid in BLOCKED),
        "pretest_qualifiable_have_blockers": qualified or all(bool(claims.get(cid, {}).get("blocker")) for cid in QUALIFIABLE),
        "qualified_qualifiable_clear_blockers": (not qualified) or all(claims.get(cid, {}).get("blocker") is None for cid in QUALIFIABLE),
        "blocked_have_blockers": all(bool(claims.get(cid, {}).get("blocker")) for cid in BLOCKED),
    }


def validate_status(status: dict) -> dict[str, bool]:
    qualified = bool(status.get("qualified"))
    return {
        "work_unit": status.get("work_unit") == "F-VQ12",
        "scope": status.get("qualification_scope") == "DOWNSTREAM_SOURCE_BOUND_FKT05_FSI05_ADMISSION_WITH_CONTRACTUAL_NONCONFLICT_ONLY",
        "decision": status.get("decision") == ("QUALIFIED_FKT05_FSI05_SOURCE_BOUND_NONCONFLICT_ONLY" if qualified else "PENDING_FVQ12_CI"),
        "fkt05": bool(status.get("fkt05_source_bound_admitted")) == qualified,
        "fsi05": bool(status.get("fsi05_source_bound_admitted")) == qualified,
        "nonconflict": bool(status.get("fkt05_fsi05_contractual_nonconflict_qualified")) == qualified,
        "composition_false": status.get("fkt05_fsi05_composed_runtime_qualified") is False,
        "reentrancy_false": status.get("full_reference_solver_reentrancy_qualified") is False,
        "parallel_false": status.get("parallel_real_headcalc_workers_qualified") is False,
        "mass_false": status.get("full_unrounded_swap_mass_identity_qualified") is False,
        "reference_blocked": status.get("production_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "multiswap_false": status.get("production_multiswap_admission") is False,
        "optional_false": status.get("optional_workspace_paths_complete") is False,
        "production_unchanged": status.get("production_source_changed_by_fvq12") is False,
        "reference_unchanged": status.get("reference_source_changed_by_fvq12") is False,
    }


def validate_evidence(status: dict) -> dict[str, bool]:
    if not status.get("qualified"):
        return {"pretest_no_evidence_required": not EVIDENCE_PATH.exists()}
    if not EVIDENCE_PATH.exists():
        return {"evidence_exists": False}
    evidence = load(EVIDENCE_PATH)
    run = evidence.get("qualification_run", {})
    return {
        "evidence_exists": True,
        "decision": evidence.get("decision") == "QUALIFIED_FKT05_FSI05_SOURCE_BOUND_NONCONFLICT_ONLY",
        "tested_matches": evidence.get("tested_postimage") == status.get("tested_postimage"),
        "tested_ancestor": bool(status.get("tested_postimage")) and is_ancestor(status["tested_postimage"], "HEAD"),
        "run_success": run.get("conclusion") == "success",
        "composition_false": evidence.get("fkt05_fsi05_composed_runtime_qualified") is False,
        "reentrancy_false": evidence.get("full_reference_solver_reentrancy_qualified") is False,
        "mass_false": evidence.get("full_unrounded_swap_mass_identity_qualified") is False,
        "reference_blocked": evidence.get("production_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "multiswap_false": evidence.get("production_multiswap_admission") is False,
        "production_unchanged": evidence.get("production_source_changed_by_fvq12") is False,
    }


def validate_all() -> dict:
    status = load(STATUS_PATH)
    matrix = load(MATRIX_PATH)
    scope = load(SCOPE_PATH)
    fvq11 = json_at(FVQ11_FINAL, "integration/f-vq/F-VQ11_STATUS.json")
    fkt_status = json_at(FKT05_STATUS, "integration/f-kt/F-KT05_STATUS.json")
    fkt_evidence = json_at(FKT05_EVIDENCE, "qualification/f-kt/F-KT05_QUALIFICATION.json")
    fsi = json_at(FSI05_FINAL, "integration/f-si/F-SI05_QUALIFICATION.json")
    head_delta = changed(FVQ11_FINAL)

    fkt_fsi = fkt_evidence.get("closeout_external_boundaries", {}).get("fsi05", {})
    fsi_materialization = fsi.get("production_materialization", {})
    fsi_policy = fsi.get("physics_and_policy", {})
    fsi_deferred = fsi.get("deferred_not_claimed", {})
    fsi_mass = fsi.get("mass_conservation_statement", {})

    sections = {
        "basis": {
            "fvq11_ancestor": is_ancestor(FVQ11_FINAL, "HEAD"),
            "fvq11_qualified": fvq11.get("qualified") is True and fvq11.get("decision") == "QUALIFIED_FKT04_FSI04_SOURCE_BOUND_ADMISSION_ONLY",
            "fci18_to_fkt05": is_ancestor(FCI18, FKT05_TESTED),
            "fci18_to_fsi05": is_ancestor(FCI18, FSI05_TESTED),
            "fkt_test_to_evidence": is_ancestor(FKT05_TESTED, FKT05_EVIDENCE),
            "fkt_evidence_to_status": is_ancestor(FKT05_EVIDENCE, FKT05_STATUS),
            "fsi_test_to_documented": is_ancestor(FSI05_TESTED, FSI05_DOCUMENTED),
            "fsi_documented_to_final": is_ancestor(FSI05_DOCUMENTED, FSI05_FINAL),
        },
        "fkt05": {
            "evidence_only_delta": changed(FKT05_TESTED, FKT05_EVIDENCE) == ["qualification/f-kt/F-KT05_QUALIFICATION.json"],
            "status_only_delta": changed(FKT05_EVIDENCE, FKT05_STATUS) == ["integration/f-kt/F-KT05_STATUS.json"],
            "qualified": fkt_status.get("qualified") is True and fkt_status.get("qualification_status") == "QUALIFIED",
            "tested_exact": fkt_status.get("tested_postimage") == FKT05_TESTED,
            "evidence_commit_exact": fkt_status.get("qualification_evidence_commit") == FKT05_EVIDENCE,
            "run_exact": fkt_status.get("qualification_run", {}).get("run_id") == FKT05_RUN and fkt_status.get("qualification_run", {}).get("conclusion") == "success",
            "jobs_exact": fkt_status.get("qualification_run", {}).get("focused_job_id") == FKT05_FOCUSED_JOB and fkt_status.get("qualification_run", {}).get("fci_regression_job_id") == FKT05_FCI_JOB,
            "checkpoint_owner": fkt_evidence.get("checkpoint_contract", {}).get("checkpoint_owner") == "F-KT",
            "same_state_replay": fkt_evidence.get("time_and_replay", {}).get("same_committed_state_replay_qualified") is True,
            "failclosed_provenance": all(fkt_evidence.get("checkpoint_contract", {}).get(k) is True for k in ("stale_revision_fails_closed", "cross_lineage_fails_closed", "time_mismatch_fails_closed", "rejection_precedes_physical_execution")),
            "checkpoint_no_publish_restore": fkt_evidence.get("checkpoint_contract", {}).get("checkpoint_can_restore_committed_state") is False and fkt_evidence.get("checkpoint_contract", {}).get("checkpoint_can_publish_committed_state") is False,
            "mass_not_promoted": fkt_evidence.get("mass_conservation", {}).get("full_reference_swap_water_balance_newly_qualified_by_fkt05") is False,
        },
        "fsi05": {
            "closeout_delta": changed(FSI05_TESTED, FSI05_DOCUMENTED) == ["docs/integration/F-SI05_PRODUCTION_WORKSPACE_SEAM.md", "integration/f-si/F-SI05_QUALIFICATION.json"],
            "final_record_only": changed(FSI05_DOCUMENTED, FSI05_FINAL) == ["integration/f-si/F-SI05_QUALIFICATION.json"],
            "qualified": fsi.get("qualified") is True and fsi.get("status") == "QUALIFIED_PRODUCTION_WORKSPACE_SEAM_FOCUSED_ROUTES_ONLY",
            "tested_exact": fsi.get("tested_implementation_checkpoint", {}).get("head") == FSI05_TESTED,
            "test_run_exact": fsi.get("tested_implementation_checkpoint", {}).get("workflow_run") == FSI05_TEST_RUN and fsi.get("tested_implementation_checkpoint", {}).get("job") == FSI05_TEST_JOB and fsi.get("tested_implementation_checkpoint", {}).get("conclusion") == "success",
            "documented_run_exact": fsi.get("documented_postimage_verification", {}).get("head") == FSI05_DOCUMENTED and fsi.get("documented_postimage_verification", {}).get("workflow_run") == FSI05_DOC_RUN and fsi.get("documented_postimage_verification", {}).get("job") == FSI05_DOC_JOB and fsi.get("documented_postimage_verification", {}).get("conclusion") == "success",
            "workspace_owned_by_worker": all(v == "WORKER_OR_ACTIVE_SOLVE_JOB" for k, v in fsi.get("workspace_ownership", {}).items() if k in {"main_newton_jacobian_scratch", "band_matrix", "band_aux", "band_rhs", "band_pivots"}),
            "persistent_state_no_scratch": fsi.get("workspace_ownership", {}).get("persistent_column_state_contains_solver_scratch") is False,
            "main_and_band_routes": fsi.get("qualified_checks", {}).get("FSI05_T05_main_route_preimage_vs_production_O0_byte_identity") == "PASS" and fsi.get("qualified_checks", {}).get("FSI05_T07_forced_band_fallback_preimage_vs_production_O0_byte_identity") == "PASS",
            "focused_mass_only": fsi_mass.get("focused_unrounded_equation_residual_identity_qualified") is True and fsi_mass.get("full_swap_water_balance_identity_qualified") is False,
        },
        "nonconflict": {
            "fkt_observes_fsi05_exact": fkt_fsi.get("qualification_head") == FSI05_FINAL and fkt_fsi.get("tested_implementation_head") == FSI05_TESTED,
            "fkt_observes_transaction_unchanged": fkt_fsi.get("transaction_semantics_changed") is False and fkt_fsi.get("generic_time_semantics_changed") is False and fkt_fsi.get("shared_fkt_type_changed") is False,
            "fsi_transaction_unchanged": fsi_materialization.get("transaction_source_changed") is False and fsi_materialization.get("shared_fkt_type_changed") is False and fsi_policy.get("transaction_semantics_changed") is False and fsi_policy.get("generic_time_semantics_changed") is False,
            "fsi_common_contract_unchanged": fsi_materialization.get("common_solver_contract_changed") is False,
            "composition_not_claimed": scope.get("positive_admission_targets") is not None and "one composed F-KT05 + F-SI05 executable production postimage" in scope.get("not_implied", []),
        },
        "negative_scope": {
            "fsi_reentrancy_deferred": fsi_deferred.get("full_reference_richards_reentrancy") == "NOT_QUALIFIED",
            "fsi_parallel_deferred": fsi_deferred.get("parallel_real_headcalc_1_2_4_8_workers") == "NOT_QUALIFIED",
            "fsi_optional_paths_deferred": all(fsi_deferred.get(k) == "DEFERRED" for k in ("macropore_path", "implicit_conductivity_path", "minimum_timestep_path", "non_free_drainage_bottom_modes")),
            "fsi_multiswap_false": fsi_deferred.get("production_multiswap_admission") is False,
            "fkt_reference_blocked": fkt_evidence.get("reference_policy", {}).get("production_reference_admission") == "BLOCKED_FAIL_CLOSED",
        },
        "provenance": {
            "qualification_paths_only": all(any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_HEAD_PATHS) for path in head_delta),
            "no_src_delta": not any(path.startswith("src/") for path in head_delta),
            "no_reference_delta": not any(path.startswith("reference/") for path in head_delta),
        },
        "matrix": validate_matrix(matrix, status),
        "status": validate_status(status),
        "evidence": validate_evidence(status),
    }
    failures = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    return {
        "workstream": "F-VQ",
        "work_unit": "F-VQ12",
        "status": "PASS" if not failures else "FAIL",
        "qualification_scope": status.get("qualification_scope"),
        "fkt05_source_bound_qualifiable": not failures,
        "fsi05_source_bound_qualifiable": not failures,
        "contractual_nonconflict_qualifiable": not failures,
        "composed_runtime_qualified": False,
        "full_reference_solver_reentrancy_qualified": False,
        "full_unrounded_swap_mass_identity_qualified": False,
        "production_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_multiswap_admission": False,
        "sections": sections,
        "failed": failures,
    }


def main() -> int:
    try:
        result = validate_all()
    except Exception as exc:
        result = {"workstream": "F-VQ", "work_unit": "F-VQ12", "status": "FAIL", "failure": str(exc)}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
