from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable
from run_lmfp09_homogeneous_c1_coarse import asymptotic_continuity_test, tolerant_bracket
import run_lmfp09_adaptive_ratio_refinement as adaptive

FIXTURE = next(f for f in core.ACTIVE if f.name == "reference_sand")
LENGTH = 20.0
PROBE_SEED = 431090101
TARGET_INTERVAL = adaptive.KNOWN_OUTLIER_INTERVAL

# This is an attribution/characterization experiment. The target interval is
# known from persisted B1 validation evidence and MUST NOT be interpreted as a
# production adaptive-selection rule.
core.AsinhMFPTable = HermiteMFPTable
core.bracket = tolerant_bracket
core.continuity_test = asymptotic_continuity_test


def evaluate(view, probes):
    identity = core.identity_test(view)
    continuity = asymptotic_continuity_test(view)
    fail_closed = core.fail_closed_test(view)
    face = core.metrics_for_view(view, probes)
    return {
        "pass": identity["pass"] and continuity["pass"] and fail_closed["pass"] and face["pass"],
        "identity": identity,
        "asymptotic_continuity": continuity,
        "fail_closed": fail_closed,
        "face_matrix": face,
        "memory": view.memory(),
    }


def target_interval(scores):
    matches = [r for r in scores if adaptive.same_interval(
        (r["h_left_cm"], r["h_right_cm"]), TARGET_INTERVAL)]
    if len(matches) != 1:
        raise RuntimeError(("target_interval_not_unique", TARGET_INTERVAL, len(matches)))
    return matches[0]


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_ratio_resolution_characterization.py EVIDENCE_JSON")

    mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
    mfp = HermiteMFPTable(FIXTURE.material, mfp_coord, core.MFP_N)
    probes = core.build_probe_rows(FIXTURE, LENGTH, PROBE_SEED)

    core.MASTER_NX = 33
    core.VIEW_NX = (33,)
    master33 = core.RatioMaster(FIXTURE, LENGTH, mfp)
    base33 = core.RatioView(master33, 33)
    base_result = evaluate(base33, probes)

    scores = adaptive.interval_scores(master33)
    target = target_interval(scores)
    targeted34 = adaptive.AdaptiveRatioView(master33, target)
    targeted_result = evaluate(targeted34, probes)

    core.MASTER_NX = 65
    core.VIEW_NX = (65,)
    master65 = core.RatioMaster(FIXTURE, LENGTH, mfp)
    uniform65 = core.RatioView(master65, 65)
    uniform65_result = evaluate(uniform65, probes)

    expected_base_max = 0.45162180968031085
    expected_base_p90 = 0.012189041242335137
    base_face = base_result["face_matrix"]["corrected_active_rel_error"]
    baseline_reproduced = (
        math.isclose(base_face["maximum"], expected_base_max, rel_tol=1.0e-12, abs_tol=1.0e-14)
        and math.isclose(base_face["p90"], expected_base_p90, rel_tol=1.0e-12, abs_tol=1.0e-14)
    )

    if targeted_result["pass"] and uniform65_result["pass"]:
        decision = "LOCAL_RATIO_HEAD_RESOLUTION_DEFICIT_CONFIRMED_SINGLE_SOURCE_BOUND_MIDPOINT_RESOLVES_B1_C1"
    elif (not targeted_result["pass"]) and uniform65_result["pass"]:
        decision = "RATIO_HEAD_RESOLUTION_DEFICIT_CONFIRMED_MORE_THAN_ONE_LOCAL_SPLIT_REQUIRED"
    elif not uniform65_result["pass"]:
        decision = "HEAD_DENSITY_ALONE_NOT_SUFFICIENT_REASSESS_RATIO_OR_GRADIENT_GEOMETRY"
    else:
        decision = "CHARACTERIZATION_INCONSISTENT_REVIEW_HARNESS"

    invariants_pass = all(
        r["identity"]["pass"] and r["asymptotic_continuity"]["pass"] and r["fail_closed"]["pass"]
        for r in (base_result, targeted_result, uniform65_result)
    )
    characterization_complete = baseline_reproduced and invariants_pass

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "subgate": "B1_C1_RATIO_HEAD_RESOLUTION_ATTRIBUTION",
        "material": FIXTURE.name,
        "face_length_cm": LENGTH,
        "probe_seed": PROBE_SEED,
        "purpose": "Distinguish local ratio-head resolution from deeper representation geometry by comparing the unchanged 33-node baseline, one source-bound diagnostic midpoint, and a 65-node class-only density control.",
        "production_selector_admission": False,
        "validation_driven_target_is_diagnostic_only": True,
        "thresholds_changed": False,
        "mfp_material_table_nodes": core.MFP_N,
        "gradient_nodes": len(core.G_AXIS),
        "target_interval_cm": list(TARGET_INTERVAL),
        "target_interval_score": target,
        "targeted_midpoint": {"x": targeted34.inserted_x, "h_cm": targeted34.inserted_h},
        "baseline_33": base_result,
        "targeted_34": targeted_result,
        "uniform_65_control": uniform65_result,
        "oracle_cost": {
            "base_33_master_oracle_solves": master33.oracle_solves,
            "targeted_extra_midpoint_oracle_solves": targeted34.extra_oracle_solves,
            "uniform_65_control_oracle_solves": master65.oracle_solves,
            "runtime_oracle_calls": 0,
        },
        "memory_bytes_per_material_geometry_class_before_metadata": {
            "base_33": base_result["memory"]["bytes_before_metadata"],
            "targeted_34": targeted_result["memory"]["bytes_before_metadata"],
            "uniform_65": uniform65_result["memory"]["bytes_before_metadata"],
        },
        "baseline_reproduced": baseline_reproduced,
        "hard_identity_and_fail_closed_invariants_pass": invariants_pass,
        "characterization_complete": characterization_complete,
        "decision": decision,
        "next_step": {
            "if_single_midpoint_resolves": "Design and test a validation-independent local selector, preferably based on interpolation defect or curvature, before any broader matrix claim.",
            "if_only_65_resolves": "Bound the minimum local ratio density needed in the active region before selector design; do not globalize 65 nodes to every class without cardinality evidence.",
            "if_65_fails": "Do not add head nodes blindly; investigate gradient-axis density or a different continuous representation geometry.",
        },
        "architecture": {
            "production_code_changed": False,
            "physics_changed": False,
            "mass_semantics_changed": False,
            "shared_immutable_class_representation_preserved": True,
            "per_column_tables": False,
            "fullrichards_reference_preserved": True,
            "groundwater_admission": False,
            "production_admission": False,
        },
    }

    Path(sys.argv[1]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if characterization_complete else 1)


if __name__ == "__main__":
    main()
