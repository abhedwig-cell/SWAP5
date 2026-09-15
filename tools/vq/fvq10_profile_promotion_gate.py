#!/usr/bin/env python3
"""Executable F-VQ10 gate for temporal-profile promotion method and fail-closed boundaries."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from . import fvq10_profile_promotion as promo

ROOT = Path(__file__).resolve().parents[2]
FVQ09_FINAL = "7af5b30ec1707ac064a93f3af84bff403a203a6d"
FCI18_CLOSEOUT = "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
FCI14_POSTIMAGE = "c226988ae0782a7d8d0818f5d4aeaab61b696de4"
PROFILE_PATH = "integration/f-ci/F-CI14_TEMPORAL_POLICY_PROFILE.json"
QUAL_PATHS = ("integration/f-vq/", "tools/vq/", "docs/verification/")
EXPECTED_CLAIMS = {f"FVQ10-C{i:02d}" for i in range(1, 11)}
EXPECTED_LAGGED = ["hm1_cm", "thetm1", "pondm1_cm", "gwlm1_cm"]


def load_json(rel: str) -> dict:
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def is_ancestor(commit: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=ROOT).returncode == 0


def changed(base: str, head: str = "HEAD") -> list[str]:
    out = git("diff", "--name-only", base, head)
    return [line for line in out.splitlines() if line]


def validate_contract(data: dict) -> dict[str, bool]:
    partition = data.get("evidence_partition", {})
    origin = data.get("limit_origin_policy", {})
    validation = data.get("validation_semantics", {})
    optional = data.get("optional_process_policy", {})
    promotion = data.get("promotion_requirements", {})
    req = data.get("candidate_profile_requirements", {})
    return {
        "work_unit": data.get("work_unit") == "F-VQ10",
        "record_type": data.get("source_observation_record_type") == promo.RAW_RECORD_TYPE,
        "metric_units_exact": data.get("acceptance_metrics") == promo.METRIC_UNITS,
        "lagged_exact": data.get("diagnostic_only_lagged_metrics") == EXPECTED_LAGGED,
        "all_limits_required": req.get("all_eight_metric_limits_required") is True,
        "limits_nonnegative": req.get("limits_nonnegative") is True,
        "units_required": req.get("units_must_match_metric_contract") is True,
        "zero_exact": req.get("zero_limit_semantics") == "EXACT_EQUALITY_REQUIRED",
        "rationale_required": req.get("per_metric_rationale_required") is True,
        "evidence_refs_required": req.get("per_metric_evidence_references_required") is True,
        "profile_hash_before_validation": req.get("candidate_profile_hash_required_before_validation") is True,
        "calibration_required": partition.get("calibration_set_required") is True,
        "validation_required": partition.get("validation_set_required") is True,
        "sets_nonempty": partition.get("sets_must_be_nonempty") is True,
        "overlap_forbidden": partition.get("calibration_validation_overlap_allowed") is False,
        "frozen_before_validation": partition.get("limits_must_be_frozen_before_validation") is True,
        "validation_no_retune": partition.get("validation_may_not_change_limits") is True,
        "change_invalidates_validation": partition.get("any_limit_or_scope_change_invalidates_prior_validation") is True,
        "solver_tolerance_forbidden": origin.get("solver_convergence_tolerance_may_be_reused") is False,
        "mass_tolerance_forbidden": origin.get("hard_mass_tolerance_may_be_reused") is False,
        "single_max_insufficient": origin.get("single_observed_maximum_is_sufficient_justification") is False,
        "validation_tuning_forbidden": origin.get("validation_results_may_be_used_to_tune_limits") is False,
        "independent_rationale_required": origin.get("independent_scientific_or_accuracy_rationale_required") is True,
        "normalization_exact": validation.get("normalization") == "max(delta_i / limit_i)",
        "acceptance_exact": validation.get("acceptance") == "normalized_error <= 1",
        "validation_all_pass": validation.get("every_validation_observation_must_pass") is True,
        "mass_separate": validation.get("hard_mass_gate_relation") == "SEPARATE_ABSOLUTE_GATE_NEVER_NORMALIZED_OR_RELAXED",
        "validation_not_sufficient": validation.get("passing_validation_is_necessary_but_not_by_itself_production_promotion") is True,
        "water_not_complete_optional": optional.get("water_only_profile_may_not_claim_complete_optional_process_scope") is True,
        "uncovered_fail_closed": optional.get("uncovered_configurations_remain_fail_closed") is True,
        "independent_decision": promotion.get("independent_qualification_decision_required") is True,
        "immutable_hash": promotion.get("immutable_candidate_profile_hash_required") is True,
        "mass_evidence": promotion.get("separate_hard_mass_pass_evidence_required") is True,
        "no_profile_write": promotion.get("production_profile_file_must_not_be_modified_by_fvq10") is True,
        "no_numeric_limits": data.get("fvq10_produces_numeric_limits") is False,
        "no_profile_promotion": data.get("fvq10_promotes_production_profile") is False,
        "reference_blocked": data.get("canonical_reference_admission_after_fvq10") == "BLOCKED_FAIL_CLOSED",
    }


def validate_matrix(data: dict, qualified: bool) -> dict[str, bool]:
    claims = {c.get("claim_id"): c for c in data.get("claims", [])}
    qualifiable = [claims.get(f"FVQ10-C{i:02d}", {}) for i in range(1, 6)]
    blocked = [claims.get(f"FVQ10-C{i:02d}", {}) for i in range(6, 11)]
    return {
        "claim_set_exact": set(claims) == EXPECTED_CLAIMS,
        "qualifiable_targets": all(c.get("target") == "QUALIFIABLE" for c in qualifiable),
        "qualifiable_flags_follow_status": all(c.get("claim_qualified") is qualified for c in qualifiable),
        "blocked_targets": all(c.get("target") == "BLOCKED_FAIL_CLOSED" for c in blocked),
        "blocked_flags_false": all(c.get("claim_qualified") is False for c in blocked),
        "blocked_have_blockers": all(bool(c.get("blocker")) for c in blocked),
        "pretest_qualifiable_have_blockers": qualified or all(bool(c.get("blocker")) for c in qualifiable),
    }


def main() -> int:
    contract = load_json("integration/f-vq/F-VQ10_PROMOTION_CONTRACT.json")
    status = load_json("integration/f-vq/F-VQ10_STATUS.json")
    matrix = load_json("integration/f-vq/F-VQ10_ADMISSION_MATRIX.json")
    fvq09 = load_json("integration/f-vq/F-VQ09_STATUS.json")
    fci14_profile = load_json(PROFILE_PATH)
    qualified = status.get("qualified") is True
    delta = changed(FVQ09_FINAL)
    profile_delta = subprocess.run(["git", "diff", "--quiet", FVQ09_FINAL, "HEAD", "--", PROFILE_PATH], cwd=ROOT).returncode == 0

    sections = {
        "contract": validate_contract(contract),
        "matrix": validate_matrix(matrix, qualified),
        "basis": {
            "fvq09_exact_ancestor": is_ancestor(FVQ09_FINAL),
            "fci18_closeout_ancestor": is_ancestor(FCI18_CLOSEOUT),
            "fvq09_decision": fvq09.get("decision") == "QUALIFIED_REAL_TEMPORAL_HARNESS_CONTRACT_ONLY",
            "fvq09_qualified": fvq09.get("qualified") is True,
            "fvq09_real_characterization_false": fvq09.get("real_b1_10_temporal_characterization_qualified") is False,
            "fvq09_profile_false": fvq09.get("production_temporal_profile_qualified") is False,
            "fvq09_reference_blocked": fvq09.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
        },
        "fci14_profile": {
            "status_unqualified": fci14_profile.get("profile_status") == "UNQUALIFIED_NO_NUMERIC_LIMITS",
            "metric_set_exact": set(fci14_profile.get("acceptance_metrics", {})) == set(promo.METRICS),
            "all_limits_null": all(value is None for value in fci14_profile.get("acceptance_metrics", {}).values()),
            "normalization_exact": fci14_profile.get("normalization") == "max(delta_i / limit_i)",
            "acceptance_exact": fci14_profile.get("acceptance") == "normalized_error <= 1",
            "zero_exact": fci14_profile.get("zero_limit_semantics") == "exact_equality_required",
            "optional_blocked": fci14_profile.get("optional_process_scope") == "blocked_until_characterized",
            "profile_unchanged_by_fvq10": profile_delta,
        },
        "provenance": {
            "no_src_delta": not any(path.startswith("src/") for path in delta),
            "no_reference_delta": not any(path.startswith("reference/swap-4.3.1/") for path in delta),
            "qualification_paths_only": all(path.startswith(QUAL_PATHS) or path == ".github/workflows/vq-reference.yml" for path in delta),
        },
        "status_boundary": {
            "work_unit": status.get("work_unit") == "F-VQ10",
            "production_source_false": status.get("production_source_changed_by_fvq10") is False,
            "real_characterization_false": status.get("real_b1_10_temporal_characterization_qualified") is False,
            "production_profile_false": status.get("production_temporal_profile_qualified") is False,
            "reference_blocked": status.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
            "optional_scope_false": status.get("complete_optional_process_scope_qualified") is False,
            "numeric_limits_false": status.get("numeric_limits_introduced_by_fvq10") is False,
            "mass_absolute": status.get("mass_conservation_policy") == "SEPARATE_ABSOLUTE_HARD_GATE",
        },
    }

    if qualified:
        evidence_path = ROOT / "integration/f-vq/evidence/F-VQ10_QUALIFICATION.json"
        if not evidence_path.exists():
            sections["qualification_evidence"] = {"evidence_exists": False}
        else:
            evidence = load_json("integration/f-vq/evidence/F-VQ10_QUALIFICATION.json")
            tested = evidence.get("tested_postimage")
            sections["qualification_evidence"] = {
                "evidence_exists": True,
                "decision_exact": evidence.get("decision") == "QUALIFIED_TEMPORAL_PROFILE_PROMOTION_CONTRACT_ONLY",
                "tested_matches_status": bool(tested) and tested == status.get("tested_postimage"),
                "tested_is_ancestor": bool(tested) and is_ancestor(tested),
                "run_success": evidence.get("qualification_run", {}).get("conclusion") == "success",
                "production_source_false": evidence.get("production_source_changed_by_fvq10") is False,
                "real_characterization_false": evidence.get("real_b1_10_temporal_characterization_qualified") is False,
                "production_profile_false": evidence.get("production_temporal_profile_qualified") is False,
                "reference_blocked": evidence.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
                "optional_scope_false": evidence.get("complete_optional_process_scope_qualified") is False,
                "numeric_limits_false": evidence.get("numeric_limits_introduced_by_fvq10") is False,
            }

    failed = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ10",
        "oracle": "B1.10",
        "status": "PASS" if not failed else "FAIL",
        "failed": failed,
        "qualification_scope": "TEMPORAL_PROFILE_QUALIFICATION_AND_PROMOTION_CONTRACT_ONLY",
        "promotion_contract_qualifiable": not failed,
        "promotion_contract_qualified": qualified and not failed,
        "real_b1_10_temporal_characterization_qualified": False,
        "production_temporal_profile_qualified": False,
        "numeric_limits_introduced_by_fvq10": False,
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "complete_optional_process_scope_qualified": False,
        "production_source_changed_by_fvq10": any(path.startswith("src/") for path in delta),
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
