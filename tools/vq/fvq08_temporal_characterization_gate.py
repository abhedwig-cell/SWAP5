#!/usr/bin/env python3
"""F-VQ08 fail-closed gate for real B1.10 temporal-characterization readiness."""
from __future__ import annotations
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FVQ07_FINAL = "4ae2fc87970d46ff2103553930e583dd05a59f0b"
EXPECTED_METRICS = ["h_cm", "theta", "pond_cm", "gwl_cm", "volact_cm", "ldwet_cm", "spev_cm", "saev_cm"]
EXPECTED_LAGGED = ["hm1_cm", "thetm1", "pondm1_cm", "gwlm1_cm"]
EXPECTED_PROFILE = {"SWCROP":1,"SWIRFIX":1,"SWMACRO":0,"SWSNOW":0,"SWDRA":1,"SWHEA":1,"SWSOLU":1}
EXPECTED_CLAIMS = {f"FVQ08-C{i:02d}" for i in range(1, 10)}
QUAL_PATHS = ("integration/f-vq/", "tools/vq/", "docs/verification/")

def load_json(rel): return json.loads((ROOT / rel).read_text(encoding="utf-8"))
def read(rel): return (ROOT / rel).read_text(encoding="utf-8")
def git(*args): return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
def is_ancestor(commit): return subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=ROOT).returncode == 0
def changed(base, head="HEAD"):
    out = git("diff", "--name-only", base, head)
    return [p for p in out.splitlines() if p]

def validate_fvq05(data):
    limits = data.get("current_numeric_limits", {})
    return {
        "oracle": data.get("oracle") == "B1.10",
        "comparison": data.get("comparison") == "full_vs_two_half_endpoint",
        "metrics_exact": data.get("required_metrics") == EXPECTED_METRICS,
        "lagged_exact": data.get("diagnostic_only_lagged_metrics") == EXPECTED_LAGGED,
        "numeric_limit_keys_exact": set(limits) == set(EXPECTED_METRICS),
        "numeric_limits_all_null": len(limits) == len(EXPECTED_METRICS) and all(v is None for v in limits.values()),
        "threshold_not_physical": "not a physical tolerance" in data.get("threshold_semantics", ""),
        "production_profile_false": data.get("production_temporal_profile_qualified") is False,
        "real_acceptance_false": data.get("real_b1_10_temporal_acceptance_qualified") is False,
        "reference_blocked": data.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "mass_separate_hard": data.get("mass_gate_relation") == "SEPARATE_HARD_GATE_NEVER_NORMALIZED_INTO_TEMPORAL_SCORE",
        "solver_tolerance_separate": data.get("solver_convergence_relation") == "SEPARATE_POLICY_NEVER_REUSED_AS_TEMPORAL_LIMIT",
    }

def validate_readiness(data):
    ev = data.get("existing_source_bound_evidence", {}); rr = data.get("real_full_runner", {}); adm = data.get("current_admission", {})
    return {
        "oracle": data.get("oracle") == "B1.10",
        "comparison": data.get("comparison") == "full_vs_two_half_endpoint",
        "metrics_exact": data.get("required_endpoint_metrics") == EXPECTED_METRICS,
        "lagged_exact": data.get("required_lagged_diagnostics") == EXPECTED_LAGGED,
        "numeric_limits_null": data.get("production_numeric_limits") is None,
        "normalized_threshold_not_physical": data.get("normalized_acceptance_threshold_is_physical_tolerance") is False,
        "fci11_temporal_metric_false": ev.get("fci11_temporal_error_metric_qualified") is False,
        "fci11_raw_matrix_not_git": ev.get("fci11_raw_local_matrix_in_canonical_git") is False,
        "profile_exact": data.get("qualified_hupsel_profile") == EXPECTED_PROFILE,
        "process_scope_incomplete": data.get("optional_process_scope_complete") is False,
        "runner_path_exact": rr.get("path") == "tests/fci/run_fci07_full_b1_10_gate.sh",
        "runner_external_source": rr.get("requires_external_source_path") is True,
        "runner_external_ttutil": rr.get("requires_ttutil_root") is True,
        "runner_external_case": rr.get("requires_case_directory") is True,
        "runner_env_exact": rr.get("required_environment") == ["FCI07_B1_10_SOURCE", "FCI07_TTUTIL_ROOT", "FCI07_CASE"],
        "runner_assets_not_self_contained": rr.get("all_required_real_run_assets_self_contained_in_repository") is False,
        "runner_not_temporal_probe": rr.get("runner_is_temporal_full_vs_two_half_probe") is False,
        "real_characterization_false": adm.get("real_b1_10_temporal_characterization_qualified") is False,
        "complete_process_false": adm.get("complete_process_scope_qualified") is False,
        "production_profile_false": adm.get("production_temporal_profile_qualified") is False,
        "reference_blocked": adm.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "requirements_present": len(data.get("promotion_requirements", [])) >= 7,
    }

def validate_source_evidence(fci10, fci11):
    p10 = fci10.get("qualified_profile", {}); g11 = fci11.get("generic_interval", {}); sb10 = fci10.get("source_basis", {}); sb11 = fci11.get("source_basis", {})
    return {
        "fci10_classified": fci10.get("classification") == "QUALIFIED_TEST_OR_CONTRACT",
        "fci10_profile_exact": p10 == {"case":"Hupselbrook", **EXPECTED_PROFILE},
        "fci10_mass_hard_pass": abs(float(fci10.get("max_abs_residual_cm", 1e99))) <= float(fci10.get("hard_mass_limit_cm", 0.0)),
        "fci10_o0_o2": fci10.get("o0_o2_identity") is True,
        "fci11_classified": fci11.get("classification") == "QUALIFIED_TEST_OR_CONTRACT",
        "fci11_generic_nonmidnight": g11.get("includes_non_midnight") is True,
        "fci11_generic_crossday": g11.get("includes_cross_calendar_day") is True,
        "fci11_temporal_metric_not_qualified": fci11.get("temporal_error_metric_qualified") is False,
        "fci11_state_identity_not_qualified": fci11.get("full_vs_two_half_state_identity_required") is False,
        "fci11_raw_matrix_external": "raw local run matrix remains outside canonical Git" in fci11.get("note", ""),
        "fci11_mass_hard_pass": abs(float(fci11.get("max_abs_residual_cm", 1e99))) <= float(fci11.get("hard_mass_limit_cm", 0.0)),
        "source_archive_identity_matches": sb10.get("official_source_archive_sha256") == sb11.get("official_source_archive_sha256") == "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151",
        "b1_10_manifest_matches": sb10.get("b1_10_manifest_sha256") == sb11.get("b1_10_manifest_sha256") == "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1",
    }

def validate_runner(text):
    return {
        "requires_source_env": '${FCI07_B1_10_SOURCE:?' in text,
        "requires_ttutil_env": '${FCI07_TTUTIL_ROOT:?' in text,
        "requires_case_env": '${FCI07_CASE:?' in text,
        "uses_controlled_source_port": "fci06_apply_controlled_source_port.py" in text,
        "uses_external_ttutil_sources": '"$TT"/*.for' in text and '"$TT"/*.f90' in text,
        "copies_external_case": 'cp -a "$FCI07_CASE"' in text,
        "is_physical_rerun_gate": "test_fci07_b1_10_physical_rerun.f90" in text,
        "not_full_two_half_probe": "two_half" not in text.lower() and "two-half" not in text.lower(),
    }

def validate_matrix(data, qualified):
    claims = {c.get("claim_id"): c for c in data.get("claims", [])}
    targets = [claims.get(f"FVQ08-C{i:02d}", {}).get("claim_qualified") for i in range(1,5)]
    blocked = [claims.get(f"FVQ08-C{i:02d}", {}).get("claim_qualified") for i in range(5,10)]
    return {
        "claim_set_exact": set(claims) == EXPECTED_CLAIMS,
        "qualifiable_targets_follow_status": all(x is qualified for x in targets),
        "blocked_and_prohibited_false": all(x is False for x in blocked),
        "all_blockers_present": all(bool(c.get("blocker")) for c in claims.values()),
        "c09_prohibited": claims.get("FVQ08-C09", {}).get("target") == "PROHIBITED",
    }

def main():
    readiness = load_json("integration/f-vq/F-VQ08_TEMPORAL_CHARACTERIZATION_READINESS.json")
    matrix = load_json("integration/f-vq/F-VQ08_ADMISSION_MATRIX.json")
    status = load_json("integration/f-vq/F-VQ08_STATUS.json")
    fvq05 = load_json("integration/f-vq/F-VQ05_TEMPORAL_PROFILE_READINESS.json")
    fci10 = load_json("integration/f-ci/evidence/F-CI10_LOCAL_HUPSEL_MASS_CANDIDATE.json")
    fci11 = load_json("integration/f-ci/evidence/F-CI11_LOCAL_GENERIC_INTERVAL_GATE.json")
    runner = read("tests/fci/run_fci07_full_b1_10_gate.sh")
    qualified = status.get("qualified") is True
    delta = changed(FVQ07_FINAL)

    sections = {
        "fvq05_contract": validate_fvq05(fvq05),
        "readiness": validate_readiness(readiness),
        "source_evidence": validate_source_evidence(fci10, fci11),
        "real_runner": validate_runner(runner),
        "matrix": validate_matrix(matrix, qualified),
        "provenance": {
            "fvq07_exact_ancestor": is_ancestor(FVQ07_FINAL),
            "no_src_delta": not any(p.startswith("src/") for p in delta),
            "no_reference_delta": not any(p.startswith("reference/swap-4.3.1/") for p in delta),
            "qualification_paths_only": all(p.startswith(QUAL_PATHS) or p == ".github/workflows/vq-reference.yml" for p in delta),
        },
        "status_boundary": {
            "work_unit": status.get("work_unit") == "F-VQ08",
            "production_source_false": status.get("production_source_changed") is False,
            "real_characterization_false": status.get("real_b1_10_temporal_characterization_qualified") is False,
            "production_profile_false": status.get("production_temporal_profile_qualified") is False,
            "reference_blocked": status.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
            "optional_scope_false": status.get("complete_optional_process_scope_qualified") is False,
        },
    }

    if qualified:
        ep = ROOT / "integration/f-vq/evidence/F-VQ08_QUALIFICATION.json"
        if not ep.exists():
            sections["qualification_evidence"] = {"evidence_exists": False}
        else:
            ev = load_json("integration/f-vq/evidence/F-VQ08_QUALIFICATION.json")
            tested = ev.get("tested_postimage")
            sections["qualification_evidence"] = {
                "evidence_exists": True,
                "decision_exact": ev.get("decision") == "QUALIFIED_TEMPORAL_CHARACTERIZATION_READINESS_ONLY",
                "tested_matches_status": bool(tested) and tested == status.get("tested_postimage"),
                "tested_is_ancestor": bool(tested) and is_ancestor(tested),
                "run_success": ev.get("qualification_run", {}).get("conclusion") == "success",
                "no_production_change": ev.get("production_source_changed") is False,
                "real_characterization_false": ev.get("real_b1_10_temporal_characterization_qualified") is False,
                "production_profile_false": ev.get("production_temporal_profile_qualified") is False,
                "reference_blocked": ev.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
                "optional_scope_false": ev.get("complete_optional_process_scope_qualified") is False,
            }

    failed = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    result = {
        "workstream": "F-VQ", "work_unit": "F-VQ08", "oracle": "B1.10",
        "status": "PASS" if not failed else "FAIL", "failed": failed,
        "qualification_scope": "TEMPORAL_CHARACTERIZATION_PREREQUISITES_AND_FAIL_CLOSED_BOUNDARY",
        "readiness_boundary_qualifiable": not failed,
        "readiness_boundary_qualified": qualified and not failed,
        "real_b1_10_temporal_characterization_qualified": False,
        "production_temporal_profile_qualified": False,
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "complete_optional_process_scope_qualified": False,
        "production_source_changed": any(p.startswith("src/") for p in delta),
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1

if __name__ == "__main__": sys.exit(main())
