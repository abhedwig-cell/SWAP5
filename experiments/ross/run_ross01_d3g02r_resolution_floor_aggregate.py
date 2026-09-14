from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

EXPECTED_MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
EXPECTED_CASES = 54
RESOLUTION_FLOOR = 1.0e-10
ACCURACY_TOLERANCE = 1.0e-5
MASS_TOL_CM = 1.0e-12
REFERENCE_SELF_TOL = 1.0e-9


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--artifacts", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    files = sorted(a.artifacts.glob("**/F-ROSS01_D3G02R_MATERIAL_*.json"))
    docs = [json.loads(path.read_text()) for path in files]
    materials = sorted(str(d.get("material")) for d in docs)
    cases = [case for doc in docs for case in doc.get("cases", [])]

    max_mass = max((float(c["max_abs_mass_residual_cm"]) for c in cases), default=math.inf)
    max_self = max((float(c["reference"]["self_delta_span_normalized_linf"]) for c in cases), default=math.inf)
    max_refined = max((float(c["temporal_metrics"]["refined_reference_error"]) for c in cases), default=math.inf)
    max_raw = max((float(c["temporal_metrics"]["raw_full_vs_two_half_estimator"]) for c in cases), default=math.inf)
    max_bound = max((float(c["temporal_metrics"]["candidate_error_bound"]) for c in cases), default=math.inf)
    max_indicator = max((float(c["temporal_metrics"]["temporal_indicator"]) for c in cases), default=math.inf)
    max_refined_over_bound = max((
        float(c["temporal_metrics"]["refined_reference_error"]) / float(c["temporal_metrics"]["candidate_error_bound"])
        for c in cases if float(c["temporal_metrics"]["candidate_error_bound"]) > 0.0
    ), default=math.inf)

    floor_cases = sum(c["temporal_metrics"]["bound_branch"] == "PREEXISTING_GATE_F_RESOLUTION_FLOOR" for c in cases)
    raw_cases = sum(c["temporal_metrics"]["bound_branch"] == "RAW_ESTIMATOR" for c in cases)
    live_heads = sorted(set(str(d.get("live_canonical_head")) for d in docs))

    checks = {
        "six_material_artifacts_present": materials == list(EXPECTED_MATERIALS),
        "exact_54_cases": len(cases) == EXPECTED_CASES,
        "all_material_payloads_pass": len(docs) == 6 and all(bool(d.get("pass")) for d in docs),
        "all_case_payloads_pass": len(cases) == EXPECTED_CASES and all(bool(c.get("pass")) for c in cases),
        "single_live_canonical_head": len(live_heads) == 1,
        "hard_mass_gate": math.isfinite(max_mass) and max_mass <= MASS_TOL_CM,
        "reference_self_gate": math.isfinite(max_self) and max_self <= REFERENCE_SELF_TOL,
        "refined_error_bounded": math.isfinite(max_refined_over_bound) and max_refined_over_bound <= 1.0,
        "bound_within_accuracy_tolerance": math.isfinite(max_bound) and max_bound <= ACCURACY_TOLERANCE,
        "indicator_le_one": math.isfinite(max_indicator) and max_indicator <= 1.0,
        "bound_partition_complete": floor_cases + raw_cases == EXPECTED_CASES,
    }
    passed = all(checks.values())
    result = {
        "work_unit": "F-ROSS01 D3G02R",
        "kind": "resolution_floor_temporal_certificate_aggregate",
        "qualification_pass": passed,
        "decision": (
            "QUALIFIED_RESOLUTION_FLOOR_BOUND_READY_FOR_FAIL_CLOSED_WRAPPER_QUALIFICATION"
            if passed else
            "NEGATIVE_RESOLUTION_FLOOR_BOUND_LEAVE_D3_G02_OPEN"
        ),
        "checks": checks,
        "material_count": len(docs),
        "materials": materials,
        "case_count": len(cases),
        "live_canonical_heads": live_heads,
        "resolution_floor": RESOLUTION_FLOOR,
        "accuracy_tolerance": ACCURACY_TOLERANCE,
        "floor_bound_case_count": floor_cases,
        "raw_bound_case_count": raw_cases,
        "max_abs_mass_residual_cm": max_mass,
        "max_reference_self_delta_span": max_self,
        "max_raw_estimator": max_raw,
        "max_refined_reference_error": max_refined,
        "max_candidate_error_bound": max_bound,
        "max_temporal_indicator": max_indicator,
        "max_refined_error_over_candidate_bound": max_refined_over_bound,
        "certificate_runtime_authority": false,
        "d3_g02_closed": false,
        "production_admission": false,
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps(result, sort_keys=True, allow_nan=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
