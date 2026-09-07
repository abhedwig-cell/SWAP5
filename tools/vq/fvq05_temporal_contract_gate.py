#!/usr/bin/env python3
"""F-VQ05 source-bound admission gate for the qualified F-CI14 temporal contract.

This gate deliberately qualifies contract semantics only. It must fail if metadata
tries to turn the normalized threshold or deterministic test limits into a
production B1.10 temporal profile.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FCI14_SOURCE = "da5026d8b87ad2f3c7912360891839a120ecccb6"
FCI14_POSTIMAGE = "c226988ae0782a7d8d0818f5d4aeaab61b696de4"
FCI14_RUN = 34107845964
FCI14_JOB = 101697462464
OVERLAY = "7e87f881af937836a517e2bb957bddd941b769ab"
METRICS = ("h_cm", "theta", "pond_cm", "gwl_cm", "volact_cm", "ldwet_cm", "spev_cm", "saev_cm")
LAGGED = ("hm1_cm", "thetm1", "pondm1_cm", "gwlm1_cm")


def load_json(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def overlay_is_ancestor() -> bool:
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", OVERLAY, "HEAD"], cwd=ROOT
    ).returncode == 0


def changed_paths() -> list[str]:
    out = git("diff", "--name-only", OVERLAY, "HEAD")
    return [p for p in out.splitlines() if p]


def validate_profile(profile: dict) -> dict[str, bool]:
    metrics = profile.get("acceptance_metrics", {})
    return {
        "work_unit_exact": profile.get("work_unit") == "F-CI14",
        "profile_status_unqualified": profile.get("profile_status") == "UNQUALIFIED_NO_NUMERIC_LIMITS",
        "comparison_endpoint_exact": profile.get("comparison") == "full_vs_two_half_endpoint",
        "metric_names_exact": tuple(metrics.keys()) == METRICS,
        "all_numeric_limits_null": all(metrics.get(k) is None for k in METRICS),
        "lagged_metrics_diagnostic_only": tuple(profile.get("diagnostic_only_lagged_metrics", [])) == LAGGED,
        "normalization_exact": profile.get("normalization") == "max(delta_i / limit_i)",
        "normalized_threshold_only": profile.get("acceptance") == "normalized_error <= 1",
        "zero_limit_exact": profile.get("zero_limit_semantics") == "exact_equality_required",
        "optional_scope_blocked": profile.get("optional_process_scope") == "blocked_until_characterized",
    }


def validate_readiness(readiness: dict) -> dict[str, bool]:
    limits = readiness.get("current_numeric_limits", {})
    return {
        "threshold_is_one": readiness.get("normalized_acceptance_threshold") == 1.0,
        "threshold_not_physical_tolerance": "not a physical tolerance" in readiness.get("threshold_semantics", ""),
        "required_metrics_exact": tuple(readiness.get("required_metrics", [])) == METRICS,
        "limits_all_null": all(limits.get(k) is None for k in METRICS),
        "profile_not_qualified": readiness.get("production_temporal_profile_qualified") is False,
        "real_b1_10_not_qualified": readiness.get("real_b1_10_temporal_acceptance_qualified") is False,
        "reference_fail_closed": readiness.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "fixture_values_not_evidence": readiness.get("test_fixture_numeric_limits_are_production_evidence") is False,
        "mass_is_separate_hard_gate": readiness.get("mass_gate_relation") == "SEPARATE_HARD_GATE_NEVER_NORMALIZED_INTO_TEMPORAL_SCORE",
        "solver_policy_separate": readiness.get("solver_convergence_relation") == "SEPARATE_POLICY_NEVER_REUSED_AS_TEMPORAL_LIMIT",
    }


def validate_matrix(matrix: dict) -> dict[str, bool]:
    claims = {c["claim_id"]: c for c in matrix.get("claims", [])}
    target_ids = {f"FVQ05-C{i:02d}" for i in range(1, 13)}
    checks = {
        "claim_set_exact": set(claims) == target_ids,
        "numeric_profile_blocked": claims.get("FVQ05-C08", {}).get("claim_qualified") is False,
        "fixture_limits_not_qualified": claims.get("FVQ05-C09", {}).get("claim_qualified") is False,
        "real_temporal_acceptance_blocked": claims.get("FVQ05-C10", {}).get("claim_qualified") is False,
        "reference_execution_blocked": claims.get("FVQ05-C11", {}).get("claim_qualified") is False,
    }
    for cid, claim in claims.items():
        if claim.get("classification", "").startswith("BLOCKED") or claim.get("classification") == "TEST_FIXTURE_ONLY":
            checks[f"{cid}_not_promoted"] = claim.get("claim_qualified") is False
    return checks


def main() -> int:
    status = load_json("integration/f-ci/F-CI14_STATUS.json")
    profile = load_json("integration/f-ci/F-CI14_TEMPORAL_POLICY_PROFILE.json")
    readiness = load_json("integration/f-vq/F-VQ05_TEMPORAL_PROFILE_READINESS.json")
    matrix = load_json("integration/f-vq/F-VQ05_ADMISSION_MATRIX.json")
    overlay = load_json("integration/f-vq/F-VQ05_CANONICAL_OVERLAY.json")
    policy = read("src/adapter/mod_b1_10_reference_temporal_policy.f90")
    candidate = read("src/adapter/mod_b1_10_reference_policy_candidate_model.f90")
    test = read("tests/fci/test_fci14_reference_temporal_policy.f90")
    fci_gate = read("tools/fci/fci14_reference_temporal_policy_gate.py")
    docs = read("docs/integration/F-CI14_REFERENCE_TEMPORAL_ACCEPTANCE.md")
    paths = changed_paths()

    sections: dict[str, dict[str, bool]] = {}
    sections["provenance"] = {
        "fci14_source_exact": status.get("qualified_source_head") == FCI14_SOURCE,
        "fci14_postimage_exact": status.get("qualified_postimage") == FCI14_POSTIMAGE,
        "fci14_oracle_exact": status.get("b1_oracle") == "B1.10",
        "fci14_ci_exact": status.get("qualification", {}).get("canonical_ci") == f"PASS_RUN_{FCI14_RUN}_JOB_{FCI14_JOB}",
        "fci14_contract_static_pass": status.get("qualification", {}).get("contract_static_gate") == "PASS",
        "fci14_o0_pass": status.get("qualification", {}).get("o0") == "PASS",
        "fci14_o2_pass": status.get("qualification", {}).get("o2") == "PASS",
        "fci14_numeric_profile_not_available": status.get("qualification", {}).get("qualified_numeric_profile") == "NOT_AVAILABLE",
        "fci14_reference_execution_fail_closed": status.get("qualification", {}).get("production_execute_reference_interval") == "FAIL_CLOSED_NOT_ADMITTED",
    }
    sections["profile"] = validate_profile(profile)
    sections["readiness"] = validate_readiness(readiness)
    sections["matrix"] = validate_matrix(matrix)
    sections["production_contract"] = {
        "eight_metric_constants": all(f"B1_10_TEMP_METRIC_{name}" in policy for name in ("H", "THETA", "POND", "GWL", "VOLACT", "LDWET", "SPEV", "SAEV")),
        "negative_defaults_fail_closed": "Negative initial values make an" in policy and "unconfigured policy fail closed" in policy,
        "zero_limit_branch_present": "tolerance <= 0.0_real64" in policy and "ratio = huge(0.0_real64)" in policy,
        "max_ratio_contract_present": "call update_limiting" in policy and "assessment%normalized_error" in policy,
        "threshold_is_normalized_one": "assessment%normalized_error <= 1.0_real64" in policy,
        "lagged_excluded_explicit": "deliberately excluded from this norm" in policy,
        "candidate_defaults_unqualified": "qualified_numeric_profile = .false." in candidate,
        "candidate_binding_does_not_promote": "self%qualified_numeric_profile = .false." in candidate,
        "reference_admission_requires_profile": "admitted = self%qualified_numeric_profile .and. self%temporal_limits_bound" in candidate,
        "policy_source_no_file_io": not any(tok in policy.lower() for tok in (" open(", "read(", "write(", "file=")),
    }
    sections["fixture_boundary"] = {
        "fixture_sets_explicit_limits": "limits%h_cm=0.01_real64" in test and "limits%gwl_cm=0.10_real64" in test,
        "fixture_asserts_profile_unqualified": "numeric profile must remain unqualified" in test,
        "fixture_mass_tolerance_is_separate": "tx_policy%mass_tolerance=1.0e-12_real64" in test,
        "fixture_temporal_threshold_is_normalized": "tx_policy%temporal_tolerance=1.0_real64" in test,
        "fci_gate_requires_no_numeric_defaults": "checks[\"no_numeric_defaults\"]" in fci_gate,
        "fci_gate_keeps_candidate_unqualified": "checks[\"candidate_profile_unqualified\"]" in fci_gate,
        "docs_contract_test_not_numeric_qualification": "This is a contract test, not numerical qualification of a B1.10 temporal tolerance profile." in docs,
        "docs_independent_limits_required": "independent calibration/qualification of the eight endpoint limits" in docs,
    }
    sections["canonical_overlay"] = {
        "overlay_record_exact": overlay.get("integration_overlay_base") == OVERLAY,
        "fci16_not_consumed": overlay.get("consumed_as_fvq05_qualification_basis") is False,
        "qualification_basis_still_fci14": overlay.get("qualification_basis_remains", {}).get("fci14_qualified_postimage") == FCI14_POSTIMAGE,
        "overlay_is_ancestor": overlay_is_ancestor(),
    }
    sections["change_scope"] = {
        "no_src_changes_since_overlay": not any(p.startswith("src/") for p in paths),
        "qualification_paths_only_since_overlay": all(
            p.startswith(("integration/f-vq/", "tools/vq/", "docs/verification/"))
            or p == ".github/workflows/vq-reference.yml"
            for p in paths
        ),
    }

    failed = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ05",
        "oracle": "B1.10",
        "fci14_source_head": FCI14_SOURCE,
        "fci14_qualified_postimage": FCI14_POSTIMAGE,
        "integration_overlay_base": OVERLAY,
        "status": "PASS" if not failed else "FAIL",
        "failed": failed,
        "qualification_scope": "FCI14_TEMPORAL_ACCEPTANCE_CONTRACT_ONLY",
        "contract_semantics_qualifiable": not failed,
        "production_temporal_profile_qualified": False,
        "real_b1_10_temporal_acceptance_qualified": False,
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_source_changed_since_overlay": any(p.startswith("src/") for p in paths),
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
