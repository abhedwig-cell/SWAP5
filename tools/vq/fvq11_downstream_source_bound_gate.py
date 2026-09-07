#!/usr/bin/env python3
"""F-VQ11 source-bound downstream admission gate."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FVQ10_FINAL = "82e9ec4ec4a3489dec771b8f53caf2c14a5eef20"
FCI18_CLOSEOUT = "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
FKT04_TESTED = "dfe9ac831428a65703e63e9f66673c6288ecc6fc"
FKT04_EVIDENCE = "acd55ecee8802a0a9fb5d854380622f2d20a7503"
FKT04_STATUS_PROMOTION = "65cfa7c855499cf2dba8ecb8ef4ab17548cc5a1c"
FSI04_TESTED = "0cfbefc271447b4b53eeee50c1dfbb2acaf020df"
FSI04_FINAL = "c76f794b93522bea3a80a6880bc95ef5671cb914"
FKT05_OBSERVED = "ed0764126a9febdd8a14ff3f32fdba68e9be9e81"
FKT04_RUN = 34121637946
FKT04_FOCUSED_JOB = 101740791304
FKT04_FCI_JOB = 101740841325
FSI04_RUN = 34122972659
FSI04_JOB = 101745034729
FKT05_FAILED_RUN = 34123331837
FKT05_FAILED_JOB = 101746158356

STATUS_PATH = ROOT / "integration/f-vq/F-VQ11_STATUS.json"
MATRIX_PATH = ROOT / "integration/f-vq/F-VQ11_ADMISSION_MATRIX.json"
CONTRACT_PATH = ROOT / "integration/f-vq/F-VQ11_DOWNSTREAM_SOURCE_BOUND_CONTRACT.json"
EVIDENCE_PATH = ROOT / "integration/f-vq/evidence/F-VQ11_QUALIFICATION.json"
QUALIFIABLE = {f"FVQ11-C{i:02d}" for i in range(1, 6)}
BLOCKED = {f"FVQ11-C{i:02d}" for i in range(6, 11)}
ALLOWED_HEAD_PATHS = (
    "integration/f-vq/",
    "tools/vq/",
    "docs/verification/",
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


def load_json(path: Path) -> dict:
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
        "work_unit": status.get("work_unit") == "F-VQ11",
        "scope_exact": status.get("qualification_scope") == "DOWNSTREAM_SOURCE_BOUND_FKT04_FSI04_ADMISSION_ONLY",
        "decision_state": status.get("decision") == ("QUALIFIED_FKT04_FSI04_SOURCE_BOUND_ADMISSION_ONLY" if qualified else "PENDING_FVQ11_CI"),
        "fkt04_flag": bool(status.get("fkt04_source_bound_admitted")) == qualified,
        "fsi04_flag": bool(status.get("fsi04_source_bound_admitted")) == qualified,
        "fkt05_false": status.get("fkt05_admitted") is False,
        "composition_false": status.get("fkt04_fsi04_composed_runtime_qualified") is False,
        "production_seam_false": status.get("production_workspace_headcalc_seam_qualified") is False,
        "reentrancy_false": status.get("full_reference_solver_reentrancy_qualified") is False,
        "full_mass_false": status.get("full_unrounded_swap_mass_identity_qualified_by_fsi04") is False,
        "reference_blocked": status.get("production_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "multiswap_false": status.get("production_multiswap_admission") is False,
        "no_production_change": status.get("production_source_changed_by_fvq11") is False,
    }


def validate_evidence(status: dict) -> dict[str, bool]:
    if not status.get("qualified"):
        return {"pretest_no_evidence_required": not EVIDENCE_PATH.exists()}
    if not EVIDENCE_PATH.exists():
        return {"evidence_exists": False}
    evidence = load_json(EVIDENCE_PATH)
    run = evidence.get("qualification_run", {})
    return {
        "evidence_exists": True,
        "decision_exact": evidence.get("decision") == "QUALIFIED_FKT04_FSI04_SOURCE_BOUND_ADMISSION_ONLY",
        "tested_matches_status": evidence.get("tested_postimage") == status.get("tested_postimage"),
        "tested_is_ancestor": bool(status.get("tested_postimage")) and is_ancestor(status["tested_postimage"], "HEAD"),
        "run_success": run.get("conclusion") == "success",
        "no_production_change": evidence.get("production_source_changed_by_fvq11") is False,
        "fkt05_false": evidence.get("fkt05_admitted") is False,
        "composition_false": evidence.get("fkt04_fsi04_composed_runtime_qualified") is False,
        "production_seam_false": evidence.get("production_workspace_headcalc_seam_qualified") is False,
        "full_mass_false": evidence.get("full_unrounded_swap_mass_identity_qualified_by_fsi04") is False,
        "reference_blocked": evidence.get("production_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "multiswap_false": evidence.get("production_multiswap_admission") is False,
    }


def validate_all() -> dict:
    status = load_json(STATUS_PATH)
    matrix = load_json(MATRIX_PATH)
    contract = load_json(CONTRACT_PATH)
    fvq10 = load_json(ROOT / "integration/f-vq/F-VQ10_STATUS.json")
    fkt04_status = json_at(FKT04_STATUS_PROMOTION, "integration/f-kt/F-KT04_STATUS.json")
    fkt04_evidence = json_at(FKT04_EVIDENCE, "integration/f-kt/F-KT04_QUALIFICATION_EVIDENCE.json")
    fsi04 = json_at(FSI04_FINAL, "integration/f-si/F-SI04_QUALIFICATION.json")
    fkt05_status = json_at(FKT05_OBSERVED, "integration/f-kt/F-KT05_STATUS.json")

    head_delta = changed(FVQ10_FINAL)
    sections = {
        "basis": {
            "fvq10_exact_ancestor": is_ancestor(FVQ10_FINAL, "HEAD"),
            "fvq10_qualified": fvq10.get("qualified") is True,
            "fci18_to_fkt04": is_ancestor(FCI18_CLOSEOUT, FKT04_TESTED),
            "fci18_to_fsi04": is_ancestor(FCI18_CLOSEOUT, FSI04_TESTED),
            "fkt04_test_to_evidence": is_ancestor(FKT04_TESTED, FKT04_EVIDENCE),
            "fkt04_evidence_to_status": is_ancestor(FKT04_EVIDENCE, FKT04_STATUS_PROMOTION),
            "fsi04_test_to_closeout": is_ancestor(FSI04_TESTED, FSI04_FINAL),
        },
        "fkt04_lineage": {
            "evidence_only_delta": changed(FKT04_TESTED, FKT04_EVIDENCE) == ["integration/f-kt/F-KT04_QUALIFICATION_EVIDENCE.json"],
            "status_only_delta": changed(FKT04_EVIDENCE, FKT04_STATUS_PROMOTION) == ["integration/f-kt/F-KT04_STATUS.json"],
            "status_qualified": fkt04_status.get("qualified") is True and fkt04_status.get("qualification_status") == "QUALIFIED",
            "tested_exact": fkt04_status.get("tested_source_postimage") == FKT04_TESTED,
            "evidence_commit_exact": fkt04_status.get("qualification_evidence_commit") == FKT04_EVIDENCE,
            "run_exact": fkt04_status.get("qualification_run", {}).get("run_id") == FKT04_RUN and fkt04_status.get("qualification_run", {}).get("conclusion") == "success",
            "focused_pass": fkt04_status.get("qualification_run", {}).get("focused_o0_o2") == "PASS",
            "fci_regression_pass": fkt04_status.get("qualification_run", {}).get("fci03_04_08_09_10_11_13_14") == "PASS",
            "evidence_source_exact": fkt04_evidence.get("qualified_source_postimage") == FKT04_TESTED,
            "evidence_jobs_exact": fkt04_evidence.get("qualification_workflow", {}).get("focused_job", {}).get("job_id") == FKT04_FOCUSED_JOB and fkt04_evidence.get("qualification_workflow", {}).get("fci_regression_job", {}).get("job_id") == FKT04_FCI_JOB,
        },
        "fsi04_lineage": {
            "closeout_delta_exact": changed(FSI04_TESTED, FSI04_FINAL) == ["docs/integration/F-SI04_HEADCALC_WORKSPACE.md", "integration/f-si/F-SI04_QUALIFICATION.json"],
            "qualified": fsi04.get("qualified") is True and fsi04.get("status") == "QUALIFIED_SOURCE_BOUND_MAIN_WORKSPACE_REPLAY_ONLY",
            "tested_exact": fsi04.get("tested_postimage") == FSI04_TESTED,
            "run_exact": fsi04.get("qualification_run", {}).get("workflow_run") == FSI04_RUN and fsi04.get("qualification_run", {}).get("job") == FSI04_JOB and fsi04.get("qualification_run", {}).get("conclusion") == "success",
            "generated_candidate": fsi04.get("implementation_form", {}).get("generated_candidate") is True,
            "production_unchanged": fsi04.get("implementation_form", {}).get("canonical_headcalc_modified") is False and fsi04.get("implementation_form", {}).get("production_soilwater_routing_changed") is False,
            "focused_mass_only": fsi04.get("mass_conservation_statement", {}).get("focused_unrounded_residual_identity_qualified") is True and fsi04.get("mass_conservation_statement", {}).get("full_SWAP_water_balance_identity_qualified") is False,
            "production_seam_deferred": fsi04.get("deferred_not_claimed", {}).get("production_workspace_aware_HeadCalc_seam") == "NOT_YET_COMMITTED",
            "reentrancy_deferred": fsi04.get("deferred_not_claimed", {}).get("full_reference_Richards_reentrancy") == "NOT_QUALIFIED",
            "production_reference_false": fsi04.get("deferred_not_claimed", {}).get("production_reference_admission") is False,
            "production_multiswap_false": fsi04.get("deferred_not_claimed", {}).get("production_MultiSWAP_admission") is False,
        },
        "fkt05_negative_admission": {
            "head_exact": contract.get("negative_admission", {}).get("F-KT05", {}).get("observed_head") == FKT05_OBSERVED,
            "run_exact": contract.get("negative_admission", {}).get("F-KT05", {}).get("observed_failed_run") == FKT05_FAILED_RUN,
            "job_exact": contract.get("negative_admission", {}).get("F-KT05", {}).get("observed_failed_job") == FKT05_FAILED_JOB,
            "status_unqualified": fkt05_status.get("tested") is False and fkt05_status.get("qualified") is False,
            "not_admittable": contract.get("negative_admission", {}).get("F-KT05", {}).get("may_be_admitted_by_fvq11") is False,
        },
        "authority": {
            "fkt_commit_authority": "owns commit and rollback authority" in contract.get("authority_contract", {}).get("F-KT", []),
            "fsi_no_commit": "does not gain commit authority" in contract.get("authority_contract", {}).get("F-SI", []),
            "fsi_no_rollback": "does not gain rollback authority" in contract.get("authority_contract", {}).get("F-SI", []),
            "composition_not_implied": "composed F-KT04 + F-SI04 runtime qualification" in contract.get("not_implied_by_admission", []),
            "full_mass_not_implied": "full unrounded SWAP water-balance identity" in contract.get("not_implied_by_admission", []),
        },
        "provenance": {
            "qualification_paths_only": all(any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_HEAD_PATHS) for path in head_delta),
            "no_src_delta": not any(path.startswith("src/") for path in head_delta),
            "no_reference_delta": not any(path.startswith("reference/") for path in head_delta),
        },
        "matrix": validate_matrix(matrix, status),
        "status": validate_status(status),
        "qualification_evidence": validate_evidence(status),
    }
    failures = [f"{section}.{name}" for section, checks in sections.items() for name, passed in checks.items() if not passed]
    return {
        "workstream": "F-VQ",
        "work_unit": "F-VQ11",
        "status": "PASS" if not failures else "FAIL",
        "qualification_scope": status.get("qualification_scope"),
        "fkt04_source_bound_qualifiable": not failures,
        "fsi04_source_bound_qualifiable": not failures,
        "fkt05_admitted": False,
        "composed_runtime_qualified": False,
        "production_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_multiswap_admission": False,
        "sections": sections,
        "failed": failures,
    }


def main() -> int:
    try:
        result = validate_all()
    except Exception as exc:
        result = {"workstream": "F-VQ", "work_unit": "F-VQ11", "status": "FAIL", "failure": str(exc)}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
