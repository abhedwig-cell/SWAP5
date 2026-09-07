#!/usr/bin/env python3
"""F-VQ09 gate for the real temporal harness and external asset contract."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FVQ08_FINAL = "0be60f6da7e575eaf992eb049ce600a4a4b35b58"
QUALIFIED_PRODUCTION_SOURCE_HEAD = "da5026d8b87ad2f3c7912360891839a120ecccb6"
QUALIFIED_CANONICAL_POSTIMAGE = "c226988ae0782a7d8d0818f5d4aeaab61b696de4"
QUALIFIED_CANONICAL_CANDIDATE_PATH = "src/adapter/mod_b1_10_reference_policy_candidate_model.f90"
QUALIFIED_CANONICAL_CANDIDATE_BLOB = "594436176333e9fb04121dcf287b507a93723dfe"
B0_SHA = "2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360"
B0_SOURCE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
EXPECTED_METRICS = ["h_cm", "theta", "pond_cm", "gwl_cm", "volact_cm", "ldwet_cm", "spev_cm", "saev_cm"]
EXPECTED_LAGGED = ["hm1_cm", "thetm1", "pondm1_cm", "gwlm1_cm"]
EXPECTED_CLAIMS = {f"FVQ09-C{i:02d}" for i in range(1, 11)}
QUAL_PATHS = ("integration/f-vq/", "tools/vq/", "docs/verification/")


def load_json(rel: str) -> dict:
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def is_ancestor(commit: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=ROOT).returncode == 0


def changed(base: str, head: str = "HEAD") -> list[str]:
    out = git("diff", "--name-only", base, head)
    return [p for p in out.splitlines() if p]


def src_lineage_matches_qualified_canonical() -> bool:
    try:
        src_delta = [p for p in changed(QUALIFIED_PRODUCTION_SOURCE_HEAD) if p.startswith("src/")]
        if src_delta != [QUALIFIED_CANONICAL_CANDIDATE_PATH]:
            return False
        head_blob = git("rev-parse", f"HEAD:{QUALIFIED_CANONICAL_CANDIDATE_PATH}")
        canonical_blob = git("rev-parse", f"{QUALIFIED_CANONICAL_POSTIMAGE}:{QUALIFIED_CANONICAL_CANDIDATE_PATH}")
        return head_blob == QUALIFIED_CANONICAL_CANDIDATE_BLOB and canonical_blob == QUALIFIED_CANONICAL_CANDIDATE_BLOB
    except subprocess.CalledProcessError:
        return False


def validate_contract(data: dict) -> dict[str, bool]:
    chain = data.get("source_chain", {})
    b0 = chain.get("b0_distribution", {})
    b1 = chain.get("b1_10", {})
    f06 = chain.get("fci06_controlled_port", {})
    f11 = chain.get("fci11_interval_mass_port", {})
    f13 = chain.get("fci13_terminal_status_overlay", {})
    tt = data.get("ttutil", {})
    case = data.get("hupsel_case", {})
    manifest = data.get("external_directory_manifest_contract", {})
    return {
        "work_unit": data.get("work_unit") == "F-VQ09",
        "b0_external": b0.get("external_required") is True,
        "b0_size": b0.get("size_bytes") == 8959314,
        "b0_sha": b0.get("sha256") == B0_SHA,
        "b0_nested_sha": b0.get("nested_source_archive_sha256") == B0_SOURCE_SHA,
        "b1_materializer": b1.get("materializer") == "tools/vq/b1_10_reconstruct.py",
        "b1_manifest": b1.get("source_manifest_sha256") == B1_10_MANIFEST,
        "fci06_materializer": f06.get("materializer") == "tools/fci/fci06_apply_controlled_source_port.py",
        "fci06_manifest": f06.get("post_port_manifest_sha256") == "3c4751ebb657a2bb622c9cddd718db451fbae861530353ab83fc3c99e78d7187",
        "fci11_materializer": f11.get("materializer") == "tools/fci/fci11_apply_controlled_interval_mass_port.py",
        "fci11_postimages_exact": f11.get("postimage_sha256") == {
            "integral.f90": "ba5edbde07a478ca4ea5454d9dcc7243f0f06d3f3de59ddc51acfcc2949ac36e",
            "timecontrol.f90": "7f1a34348d758db2c095491bcb55df756ae78ab2b7269e313a2d9b90e600f619",
            "swap.f90": "ec5d44d871c8e5a65e76ead8c698fcc27cef643c9c0f806ab0a9bfd7a938a7a0",
            "swap_main.f90": "100aa651a2c1b13094cc56781404601b2c7efdf3934aa6d280b719874095c76a",
        },
        "fci13_overlay_exact": f13.get("source_head") == "538d51df4be3780a5bb092767304749dfc800899" and f13.get("changed_legacy_file") == "swap.f90" and f13.get("change_scope") == "TERMINAL_STATUS_GUARD_ONLY",
        "production_source_exact": data.get("qualified_production_source_head") == QUALIFIED_PRODUCTION_SOURCE_HEAD,
        "ttutil_external": tt.get("external_required") is True,
        "ttutil_not_admitted": tt.get("admitted_manifest_sha256") is None and tt.get("admitted_file_count") is None,
        "ttutil_anchors": tt.get("required_anchor_files") == ["ttutilprefs.f90", "rdmodulettutil.f90", "outdat.f90", "ttutil.f90"],
        "case_external": case.get("external_required") is True,
        "case_not_admitted": case.get("admitted_manifest_sha256") is None and case.get("admitted_file_count") is None,
        "case_anchor": case.get("required_anchor_files") == ["swap.swp"],
        "candidate_not_admission": manifest.get("candidate_manifest_is_admission") is False,
        "symlinks_forbidden": manifest.get("symlinks_allowed") is False,
        "mutation_forbidden": manifest.get("mutation_after_validation_allowed") is False,
        "bundle_fail_closed": "fail closed" in data.get("bundle_admission_rule", "").lower(),
    }


def validate_schema(data: dict) -> dict[str, bool]:
    mass = data.get("required_mass_fields", {})
    return {
        "record_type": data.get("record_type") == "REAL_B1_10_FULL_VS_TWO_HALF_RAW_OBSERVATION",
        "metrics_exact": data.get("required_endpoint_differences") == EXPECTED_METRICS,
        "lagged_exact": data.get("required_lagged_diagnostics") == EXPECTED_LAGGED,
        "mass_both_paths": set(mass) == {"full_path", "two_half_path"},
        "mass_residual_both": all("residual_cm" in mass.get(k, []) for k in ("full_path", "two_half_path")),
        "hard_mass_exact": data.get("hard_mass_limit_cm") == 1e-6,
        "temporal_limits_null": data.get("temporal_numeric_limits") is None,
        "normalized_score_null": data.get("normalized_temporal_score") is None,
        "raw_not_acceptance": data.get("raw_observation_is_production_temporal_acceptance") is False,
        "mass_separate": data.get("mass_gate_relation") == "SEPARATE_ABSOLUTE_GATE_NEVER_NORMALIZED_OR_RELAXED",
    }


def validate_probe(text: str) -> dict[str, bool]:
    low = text.lower()
    return {
        "uses_recoverable_model": "b1_10_recoverable_reference_model_t" in low,
        "captures_process_state": "capture_b1_10_process_state(day_state)" in low,
        "captures_trial_capsule": "capture_b1_10_legacy_trial_capsule(start_capsule)" in low,
        "full_and_split_same_state": "full_state = start_state" in low and "split_state = start_state" in low,
        "full_restores_capsule": low.find("restore_b1_10_legacy_trial_capsule(start_capsule)") < low.find("model%advance(full_state, char_t0, char_t1"),
        "split_restores_same_capsule": low.count("restore_b1_10_legacy_trial_capsule(start_capsule)") == 2,
        "full_one_step": "model%advance(full_state, char_t0, char_t1, full_out)" in low,
        "split_two_half": "model%advance(split_state, char_t0, tmid, half1_out)" in low and "model%advance(split_state, tmid, char_t1, half2_out)" in low,
        "same_t1": "char_t1 = char_t0 + duration_days" in low,
        "observed_time_not_midnight_assumption": "day_t0 = t1900" in low,
        "characterizes_raw_delta": "characterize_b1_10_temporal_difference(full_state, split_state, delta)" in low,
        "full_mass_formula": "full_residual = storage0 + full_out%mass_in - full_out%mass_out - storage_full" in low,
        "split_mass_formula": "split_residual = storage0 + split_mass_in - split_mass_out - storage_split" in low,
        "hard_mass_parameter": "hard_mass_limit_cm = 1.0e-6_real64" in low,
        "hard_mass_full": "abs(full_residual) > hard_mass_limit_cm" in low,
        "hard_mass_split": "abs(split_residual) > hard_mass_limit_cm" in low,
        "all_metrics_emitted": all(f"'{key}'" in low for key in ["h_cm", "theta", "pond_cm", "gwl_cm", "volact_cm", "ldwet_cm", "spev_cm", "saev_cm", "hm1_cm", "thetm1", "pondm1_cm", "gwlm1_cm"]),
        "scope_flags_emitted": all(key in low for key in ["optional_process_state_present", "process_scope_complete", "allocation_mismatches"]),
        "no_scalar_temporal_acceptance": "temporal_tolerance" not in low and "normalized" not in low,
    }


def validate_materializer(text: str) -> dict[str, bool]:
    low = text.lower()
    return {
        "production_head_pin": QUALIFIED_PRODUCTION_SOURCE_HEAD in text,
        "canonical_postimage_pin": QUALIFIED_CANONICAL_POSTIMAGE in text,
        "canonical_candidate_blob_pin": QUALIFIED_CANONICAL_CANDIDATE_BLOB in text,
        "src_lineage_delta_guard": "src_delta != [qualified_canonical_candidate_path]" in low,
        "src_lineage_blob_guard": "head_blob != qualified_canonical_candidate_blob" in low and "canonical_blob != qualified_canonical_candidate_blob" in low,
        "uses_b1_10_reconstructor": "tools/vq/b1_10_reconstruct.py" in text,
        "uses_fci06": "tools/fci/fci06_apply_controlled_source_port.py" in text,
        "uses_fci11": "tools/fci/fci11_apply_controlled_interval_mass_port.py" in text,
        "uses_fci13_gate": "tools/fci/fci13_recoverable_status_gate.py" in text,
        "fci13_guard_exact_once": "post_lf.count(insert) != 1" in text,
        "fci13_only_delta": "post_lf.replace(insert, b\"\", 1) != pre_lf" in text,
        "writes_fci13_swap": '(fci11 / "swap.f90").write_bytes(assemble_fci13_swap(fci11))' in text,
        "candidate_source_manifest_recorded": "materialized_source_manifest_sha256" in text,
    }


def validate_runner(text: str) -> dict[str, bool]:
    low = text.lower()
    validate_pos = low.find("fvq09_asset_bundle.py\" validate-bundle")
    materialize_pos = low.find("fvq09_materialize_production_source.py")
    first_gfortran = low.find("gfortran --version")
    return {
        "requires_b0": "fvq09_b0_distribution:?" in low,
        "requires_ttutil": "fvq09_ttutil_root:?" in low,
        "requires_case": "fvq09_case:?" in low,
        "validates_before_materialize": 0 <= validate_pos < materialize_pos,
        "validates_before_compile": 0 <= validate_pos < first_gfortran,
        "blocked_exit_preserved": "exit \"$bundle_rc\"" in low,
        "uses_exact_materializer": "fvq09_materialize_production_source.py" in low,
        "o0_o2": "for opt in 0 2" in low,
        "uses_recoverable_executor": "mod_b1_10_recoverable_interval_executor.f90" in low,
        "uses_recoverable_model": "mod_b1_10_recoverable_reference_model.f90" in low,
        "uses_probe": "fvq09_real_b1_10_temporal_probe.f90" in low,
        "writes_observation": "fvq09_observation.py" in low,
        "case_copy_after_validation": low.find('cp -a "$fvq09_case"') > validate_pos,
        "swcsv_only_observer_adjustment": "swcsv = 0" in low,
        "real_pass_marker": "fvq09_real_temporal_harness_pass" in low,
    }


def validate_observation_builder(text: str) -> dict[str, bool]:
    low = text.lower()
    return {
        "requires_admitted_bundle": "bundle_not_admitted" in low,
        "requires_materialized_source": "physical_source_not_materialized" in low,
        "hard_mass_exact": "hard_limit != 1.0e-6" in low,
        "rejects_mass_failure": "hard_mass_gate_failed" in low,
        "requires_compatible_water": "water_endpoint_states_incompatible" in low,
        "preserves_optional_scope_boundary": "qualified_hupsel_optional_process_scope_boundary_changed" in low,
        "numeric_limits_null": '"temporal_numeric_limits": none' in low,
        "normalized_score_null": '"normalized_temporal_score": none' in low,
        "raw_not_acceptance": '"raw_observation_is_production_temporal_acceptance": false' in low,
    }


def validate_matrix(data: dict, qualified: bool) -> dict[str, bool]:
    claims = {c.get("claim_id"): c for c in data.get("claims", [])}
    qualifiable = [claims.get(f"FVQ09-C{i:02d}", {}) for i in range(1, 6)]
    blocked = [claims.get(f"FVQ09-C{i:02d}", {}) for i in range(6, 11)]
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
    contract = load_json("integration/f-vq/F-VQ09_ASSET_BUNDLE_CONTRACT.json")
    schema = load_json("integration/f-vq/F-VQ09_OBSERVATION_SCHEMA.json")
    matrix = load_json("integration/f-vq/F-VQ09_ADMISSION_MATRIX.json")
    status = load_json("integration/f-vq/F-VQ09_STATUS.json")
    fci18 = load_json("integration/f-ci/F-CI18_STATUS.json")
    qualified = status.get("qualified") is True
    delta = changed(FVQ08_FINAL)

    sections = {
        "contract": validate_contract(contract),
        "schema": validate_schema(schema),
        "probe": validate_probe(read("tools/vq/fvq09_real_b1_10_temporal_probe.f90")),
        "materializer": validate_materializer(read("tools/vq/fvq09_materialize_production_source.py")),
        "runner": validate_runner(read("tools/vq/run_fvq09_real_temporal_probe.sh")),
        "observation_builder": validate_observation_builder(read("tools/vq/fvq09_observation.py")),
        "matrix": validate_matrix(matrix, qualified),
        "source_lineage": {
            "fci18_qualified_exit": fci18.get("status") == "QUALIFIED_EXIT",
            "fci18_production_source_exact": fci18.get("qualified_production_source_head") == QUALIFIED_PRODUCTION_SOURCE_HEAD,
            "qualified_production_is_ancestor": is_ancestor(QUALIFIED_PRODUCTION_SOURCE_HEAD),
            "production_src_plus_qualified_candidate_exact": src_lineage_matches_qualified_canonical(),
        },
        "provenance": {
            "fvq08_exact_ancestor": is_ancestor(FVQ08_FINAL),
            "no_src_delta": not any(p.startswith("src/") for p in delta),
            "no_reference_delta": not any(p.startswith("reference/swap-4.3.1/") for p in delta),
            "qualification_paths_only": all(p.startswith(QUAL_PATHS) or p == ".github/workflows/vq-reference.yml" for p in delta),
        },
        "status_boundary": {
            "work_unit": status.get("work_unit") == "F-VQ09",
            "production_source_false": status.get("production_source_changed_by_fvq09") is False,
            "real_characterization_false": status.get("real_b1_10_temporal_characterization_qualified") is False,
            "production_profile_false": status.get("production_temporal_profile_qualified") is False,
            "reference_blocked": status.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
            "optional_scope_false": status.get("complete_optional_process_scope_qualified") is False,
            "mass_absolute": status.get("mass_conservation_policy") == "SEPARATE_ABSOLUTE_HARD_GATE",
        },
    }

    if qualified:
        ep = ROOT / "integration/f-vq/evidence/F-VQ09_QUALIFICATION.json"
        if not ep.exists():
            sections["qualification_evidence"] = {"evidence_exists": False}
        else:
            ev = load_json("integration/f-vq/evidence/F-VQ09_QUALIFICATION.json")
            tested = ev.get("tested_postimage")
            sections["qualification_evidence"] = {
                "evidence_exists": True,
                "decision_exact": ev.get("decision") == "QUALIFIED_REAL_TEMPORAL_HARNESS_CONTRACT_ONLY",
                "tested_matches_status": bool(tested) and tested == status.get("tested_postimage"),
                "tested_is_ancestor": bool(tested) and is_ancestor(tested),
                "run_success": ev.get("qualification_run", {}).get("conclusion") == "success",
                "no_production_change": ev.get("production_source_changed_by_fvq09") is False,
                "real_characterization_false": ev.get("real_b1_10_temporal_characterization_qualified") is False,
                "production_profile_false": ev.get("production_temporal_profile_qualified") is False,
                "reference_blocked": ev.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
                "optional_scope_false": ev.get("complete_optional_process_scope_qualified") is False,
            }

    failed = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ09",
        "oracle": "B1.10",
        "status": "PASS" if not failed else "FAIL",
        "failed": failed,
        "qualification_scope": "REAL_B1_10_TEMPORAL_HARNESS_AND_EXTERNAL_ASSET_BUNDLE_CONTRACT_ONLY",
        "harness_contract_qualifiable": not failed,
        "harness_contract_qualified": qualified and not failed,
        "external_ttutil_case_assets_admitted": False,
        "real_b1_10_temporal_characterization_qualified": False,
        "production_temporal_profile_qualified": False,
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "complete_optional_process_scope_qualified": False,
        "production_source_changed_by_fvq09": any(p.startswith("src/") for p in delta),
        "sections": sections,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
