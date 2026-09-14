from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import run_ross01_d2_fsi31_qualification as d2q
import run_ross01_d3g02_temporal_certificate_calibration as cal
import run_ross01_d3g02_temporal_certificate_calibration_material as parent
import run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner as d1
import ross01_d3r_fsi31_duration_adapter as adapter

RESOLUTION_FLOOR = 1.0e-10
ACCURACY_TOLERANCE = 1.0e-5


def qualify_case(case: dict) -> dict:
    out = dict(case)
    temporal = dict(out["temporal_metrics"])
    raw = float(temporal["raw_full_vs_two_half_estimator"])
    refined = float(temporal["refined_reference_error"])
    reference_self = float(out["reference"]["self_delta_span_normalized_linf"])
    bound = max(raw, RESOLUTION_FLOOR)
    indicator = bound / ACCURACY_TOLERANCE
    checks = dict(out["checks"])
    checks.update({
        "reference_self_within_frozen_tolerance": math.isfinite(reference_self) and reference_self <= cal.REFERENCE_SELF_TOL_SPAN,
        "raw_estimator_finite_nonnegative": math.isfinite(raw) and raw >= 0.0,
        "refined_reference_error_finite_nonnegative": math.isfinite(refined) and refined >= 0.0,
        "resolution_floor_bound_finite_nonnegative": math.isfinite(bound) and bound >= 0.0,
        "refined_reference_error_le_resolution_floor_bound": refined <= bound,
        "resolution_floor_bound_le_accuracy_tolerance": bound <= ACCURACY_TOLERANCE,
        "temporal_indicator_finite_nonnegative": math.isfinite(indicator) and indicator >= 0.0,
        "temporal_indicator_le_one": indicator <= 1.0,
    })
    temporal.update({
        "preexisting_resolution_floor_span_normalized": RESOLUTION_FLOOR,
        "candidate_error_bound": bound,
        "accuracy_tolerance": ACCURACY_TOLERANCE,
        "temporal_indicator": indicator,
        "bound_branch": "RAW_ESTIMATOR" if raw >= RESOLUTION_FLOOR else "PREEXISTING_GATE_F_RESOLUTION_FLOOR",
    })
    out["checks"] = checks
    out["temporal_metrics"] = temporal
    out["pass"] = all(bool(v) for v in checks.values())
    out["certificate_available"] = bool(out["pass"])
    out["certificate_disposition"] = (
        "QUALIFICATION_CANDIDATE_AVAILABLE_NOT_RUNTIME_AUTHORITY"
        if out["pass"] else
        "FAIL_CLOSED_NO_CERTIFICATE"
    )
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    base = d2q.base_request(a.material, t0=37.125, steps=8, perturb=0.0, pre=False)
    table = cal.configure_reference(a.material)
    theta0 = tuple(float(v) for v in base["committed_state"]["water_content"])
    ext = cal.reference_external(base)
    span = float(d1.gate_d.core().THETA_S - d1.gate_d.core().THETA_R)
    ref32 = parent.reference_trajectory(theta0, table, ext, 32)
    ref64 = parent.reference_trajectory(theta0, table, ext, 64)

    cases = [
        qualify_case(parent.run_case(a.material, attempt, base, ref32, ref64, span))
        for attempt in range(adapter.CANONICAL_MAX_RETRIES + 1)
    ]
    payload = {
        "work_unit": "F-ROSS01 D3G02R",
        "kind": "resolution_floor_temporal_certificate_material_qualification",
        "live_canonical_head": a.canonical_head,
        "material": a.material,
        "case_count": len(cases),
        "pass": len(cases) == 9 and all(c["pass"] for c in cases),
        "precommitted_resolution_floor": RESOLUTION_FLOOR,
        "precommitted_accuracy_tolerance": ACCURACY_TOLERANCE,
        "bound_expression": "max(raw_full_vs_two_half_estimator, 1e-10)",
        "reference_reuse": "TWO_FRESH_FULL_WINDOW_DOP853_TRAJECTORIES_EVALUATED_AT_ALL_NINE_RETRY_ENDPOINTS",
        "cases": cases,
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "material": a.material,
        "pass": payload["pass"],
        "case_count": len(cases),
        "max_refined_error": max(float(c["temporal_metrics"]["refined_reference_error"]) for c in cases),
        "max_bound": max(float(c["temporal_metrics"]["candidate_error_bound"]) for c in cases),
        "max_indicator": max(float(c["temporal_metrics"]["temporal_indicator"]) for c in cases),
    }, sort_keys=True, allow_nan=False))
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
