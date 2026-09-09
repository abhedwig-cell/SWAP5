from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e2c_bounded_local_face_solve as e2c
import run_ross01_gate_e2c_r1_segmented_local_face as r1

CONTRACT = "F-ROSS01_GATE_E2C_R2_ENDPOINT_CLUSTERED_SEGMENTED_LOCAL_FACE_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13", "B01", "O14")
MAX_K_EVALS = 530
MAX_ROOT_EVALS = 66

_t8 = 0.5 * (r1._x8 + 1.0)
_wt8 = 0.5 * r1._w8


def endpoint_clustered_residual_factory(h_above: float, h_below: float):
    lo = min(h_above, h_below)
    hi = max(h_above, h_below)
    points = [float(h_above), float(h_below)]
    if lo < 0.0 < hi or lo == 0.0 or hi == 0.0:
        points.append(0.0)
    for value in r1.LOG_BREAKS:
        if lo < value < hi:
            points.append(value)
    ordered = r1._unique_sorted(points)
    if h_above > h_below:
        ordered = list(reversed(ordered))
    if len(ordered) - 1 > r1.MAX_SEGMENTS:
        raise RuntimeError(("segment_bound_exceeded", len(ordered) - 1))

    all_k = []
    all_w = []
    for seg_index, (a, b) in enumerate(zip(ordered[:-1], ordered[1:])):
        if seg_index == 0:
            dh = b - a
            heads = a + dh * (_t8 ** 8)
            weights = _wt8 * (dh * 8.0 * (_t8 ** 7))
        else:
            mid = 0.5 * (a + b)
            half = 0.5 * (b - a)
            heads = mid + half * r1._x8
            weights = half * r1._w8
        kvals = np.asarray([e2c.c1.core.k_of_h(float(h)) for h in heads], dtype=np.float64)
        if not np.all(np.isfinite(kvals)) or np.any(kvals <= 0.0):
            raise FloatingPointError("nonfinite_or_nonpositive_constitutive_value")
        all_k.append(kvals)
        all_w.append(weights)

    kvals = np.concatenate(all_k) if all_k else np.empty(0, dtype=np.float64)
    weights = np.concatenate(all_w) if all_w else np.empty(0, dtype=np.float64)
    if len(kvals) > r1.MAX_SEGMENTS * r1.GL_SEGMENT_N:
        raise RuntimeError(("quadrature_lane_bound_exceeded", len(kvals)))

    def residual(q: float) -> float:
        den = kvals - q
        if np.any(den == 0.0):
            return math.copysign(math.inf, float(np.sum(weights)))
        value = float(np.sum(weights * kvals / den)) - e2c.LENGTH
        return value

    residual.k_eval_count = int(len(kvals))
    return residual


def candidate_q_r2(h_above: float, h_below: float) -> tuple[float, dict]:
    scale = max(1.0, abs(h_above), abs(h_below))
    if abs(h_above - h_below) <= 2.0e-14 * scale:
        q = float(e2c.c1.core.k_of_h(0.5 * (h_above + h_below)))
        return q, {"branch": "EQUAL_HEAD_EXACT", "root_residual_evaluations": 0, "constitutive_K_evaluations": 1}

    dh = h_below - h_above
    if abs(dh - e2c.LENGTH) <= 2.0e-13 * max(1.0, e2c.LENGTH, abs(dh)):
        return 0.0, {"branch": "HYDROSTATIC_EXACT", "root_residual_evaluations": 0, "constitutive_K_evaluations": 0}

    residual = endpoint_clustered_residual_factory(h_above, h_below)
    k_above = float(e2c.c1.core.k_of_h(h_above))
    ksat = float(e2c.c1.core.KSAT)

    if h_below > h_above:
        if dh < e2c.LENGTH:
            lo = 0.0
            hi = k_above * (1.0 - 1.0e-12)
        else:
            lo = -ksat * max(0.0, dh / e2c.LENGTH - 1.0)
            lo = math.nextafter(lo, -math.inf)
            hi = 0.0
    else:
        drop = h_above - h_below
        lo = math.nextafter(k_above, math.inf)
        hi = math.nextafter(ksat * (1.0 + drop / e2c.LENGTH), math.inf)

    f_lo = residual(lo)
    f_hi = residual(hi)
    evals = 2
    if not (math.isfinite(f_lo) and math.isfinite(f_hi)):
        raise FloatingPointError(("nonfinite_bracket_residual", f_lo, f_hi))
    if f_lo == 0.0:
        return lo, {"branch": "GENERIC_FIXED_BISECTION", "root_residual_evaluations": evals, "constitutive_K_evaluations": residual.k_eval_count + 2}
    if f_hi == 0.0:
        return hi, {"branch": "GENERIC_FIXED_BISECTION", "root_residual_evaluations": evals, "constitutive_K_evaluations": residual.k_eval_count + 2}
    if f_lo * f_hi > 0.0:
        raise RuntimeError(("bracket_failure", h_above, h_below, lo, hi, f_lo, f_hi))

    for _ in range(e2c.BISECTION_STEPS):
        mid = 0.5 * (lo + hi)
        f_mid = residual(mid)
        evals += 1
        if not math.isfinite(f_mid):
            raise FloatingPointError(("nonfinite_mid_residual", mid, f_mid))
        if f_mid == 0.0:
            lo = hi = mid
            break
        if f_lo * f_mid <= 0.0:
            hi = mid
            f_hi = f_mid
        else:
            lo = mid
            f_lo = f_mid
    q = 0.5 * (lo + hi)
    if not math.isfinite(q):
        raise FloatingPointError("nonfinite_candidate_flux")
    return q, {"branch": "GENERIC_FIXED_BISECTION", "root_residual_evaluations": evals, "constitutive_K_evaluations": residual.k_eval_count + 2}


def run_material(row: dict) -> dict:
    original_candidate = e2c._candidate_q
    try:
        e2c._candidate_q = candidate_q_r2
        result = e2c.run_material(row)
    finally:
        e2c._candidate_q = original_candidate

    result["tests"]["constitutive_K_evaluation_bound"] = result["max_constitutive_K_evaluations"] <= MAX_K_EVALS
    result["tests"]["root_residual_evaluation_bound"] = result["max_root_residual_evaluations"] <= MAX_ROOT_EVALS
    result["failed_metrics"] = [k for k, ok in result["tests"].items() if not ok]
    result["pass"] = all(result["tests"].values())
    return result


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2c_r2_endpoint_clustered_local_face.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {row["sfu"]: row for row in catalog["rows"]}
    materials = []
    for i, material in enumerate(MATERIALS, 1):
        result = run_material(by[material])
        materials.append(result)
        print(json.dumps({
            "progress": f"{i}/{len(MATERIALS)}",
            "material": material,
            "pass": result["pass"],
            "failed_metrics": result["failed_metrics"],
            "bracket_failure_count": result["bracket_failure_count"],
            "max_abs_error_over_ksatfit": result["max_abs_error_over_ksatfit"],
            "max_constitutive_K_evaluations": result["max_constitutive_K_evaluations"],
        }, sort_keys=True), flush=True)

    passed = all(m["pass"] for m in materials)
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E2C_R2_ENDPOINT_CLUSTERED_SEGMENTED_LOCAL_FACE_SOLVE",
        "contract": CONTRACT,
        "candidate": "R1_QUARTER_DECADE_GL8_WITH_FIRST_SEGMENT_T8_ENDPOINT_CLUSTERING_AND_NEXTAFTER_Q_BRACKET",
        "production_implementation": False,
        "qualification_use": False,
        "material_count": len(materials),
        "material_pass_count": sum(m["pass"] for m in materials),
        "materials": materials,
        "total_bracket_failures": sum(m["bracket_failure_count"] for m in materials),
        "total_nonfinite_count": sum(m["nonfinite_count"] for m in materials),
        "max_hybrid_metric": max(m["max_hybrid_metric"] for m in materials),
        "max_p99_hybrid_metric": max(m["p99_hybrid_metric"] for m in materials),
        "max_abs_error_over_ksatfit": max(m["max_abs_error_over_ksatfit"] for m in materials),
        "max_root_residual_evaluations": max(m["max_root_residual_evaluations"] for m in materials),
        "max_constitutive_K_evaluations": max(m["max_constitutive_K_evaluations"] for m in materials),
        "persistent_per_column_state_bytes": 0,
        "scratch_owner": "worker",
        "table_lookup": False,
        "pass": passed,
        "decision": "QUALIFIED_BOUNDED_ENDPOINT_CLUSTERED_LOCAL_NEAR_SATURATION_FACE_FALLBACK_READY_FOR_E_SATURATION_TRANSITION_PROTOTYPE" if passed else "ENDPOINT_CLUSTERED_LOCAL_FACE_SOLVE_NOT_QUALIFIED_RESEARCH_REQUIRED",
        "preserved_negative_evidence": [
            "E2A direct-head table rejection",
            "E2A-R1A uniform-S table rejection",
            "E2A-R2A asymptotic-axis table rejection",
            "E2B fixed-node Q2 table rejection",
            "E2C single-panel t8 GL128 local-solve rejection",
            "E2C-R1 segmented direct-GL8 endpoint bracket rejection"
        ],
        "hard_nonclaims": [
            "No normal production face-path admission.",
            "No saturation-transition timestep or column qualification.",
            "No runtime or MultiSWAP throughput qualification."
        ]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": passed,
        "decision": result["decision"],
        "material_pass_count": result["material_pass_count"],
        "total_bracket_failures": result["total_bracket_failures"],
        "max_abs_error_over_ksatfit": result["max_abs_error_over_ksatfit"],
        "max_constitutive_K_evaluations": result["max_constitutive_K_evaluations"],
    }, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
