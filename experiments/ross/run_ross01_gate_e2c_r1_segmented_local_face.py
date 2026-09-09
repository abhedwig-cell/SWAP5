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

CONTRACT = "F-ROSS01_GATE_E2C_R1_LOG_HEAD_SEGMENTED_LOCAL_FACE_PRECOMMIT.json"
MATERIALS = ("B12", "O13", "B01", "O14")
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
GL_SEGMENT_N = 8
MAX_SEGMENTS = 66
MAX_K_EVALS = 530

_x8, _w8 = np.polynomial.legendre.leggauss(GL_SEGMENT_N)
LOG_BREAKS = tuple(-10.0 ** u for u in np.arange(-12.0, 4.0000001, 0.25))


def _unique_sorted(values: list[float]) -> list[float]:
    out: list[float] = []
    for value in sorted(values):
        if not out or value != out[-1]:
            out.append(float(value))
    return out


def segmented_residual_factory(h_above: float, h_below: float):
    lo = min(h_above, h_below)
    hi = max(h_above, h_below)
    points = [float(h_above), float(h_below)]
    if lo < 0.0 < hi or lo == 0.0 or hi == 0.0:
        points.append(0.0)
    for value in LOG_BREAKS:
        if lo < value < hi:
            points.append(value)
    ordered = _unique_sorted(points)
    if h_above > h_below:
        ordered = list(reversed(ordered))
    if len(ordered) - 1 > MAX_SEGMENTS:
        raise RuntimeError(("segment_bound_exceeded", len(ordered) - 1))

    all_k = []
    all_w = []
    for a, b in zip(ordered[:-1], ordered[1:]):
        mid = 0.5 * (a + b)
        half = 0.5 * (b - a)
        heads = mid + half * _x8
        weights = half * _w8
        kvals = np.asarray([e2c.c1.core.k_of_h(float(h)) for h in heads], dtype=np.float64)
        if not np.all(np.isfinite(kvals)) or np.any(kvals <= 0.0):
            raise FloatingPointError("nonfinite_or_nonpositive_constitutive_value")
        all_k.append(kvals)
        all_w.append(weights)

    kvals = np.concatenate(all_k) if all_k else np.empty(0, dtype=np.float64)
    weights = np.concatenate(all_w) if all_w else np.empty(0, dtype=np.float64)
    if len(kvals) > MAX_SEGMENTS * GL_SEGMENT_N:
        raise RuntimeError(("quadrature_lane_bound_exceeded", len(kvals)))

    def residual(q: float) -> float:
        den = kvals - q
        if np.any(den == 0.0):
            return math.copysign(math.inf, float(np.sum(weights)))
        return float(np.sum(weights * kvals / den)) - e2c.LENGTH

    return residual


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2c_r1_segmented_local_face.py OUTPUT.json")
    output = Path(sys.argv[1])

    # Reuse the frozen E2C probe, reference, bracket and metric harness exactly.
    # Only the non-table path integration representation is replaced.
    e2c._fixed_residual_factory = segmented_residual_factory
    e2c.GL_N = MAX_SEGMENTS * GL_SEGMENT_N
    e2c.CONTRACT = CONTRACT

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}
    materials = []
    for i, name in enumerate(MATERIALS, 1):
        result = e2c.run_material(by[name])
        materials.append(result)
        print(json.dumps({
            "progress": f"{i}/{len(MATERIALS)}",
            "material": name,
            "pass": result["pass"],
            "failed_metrics": result["failed_metrics"],
            "max_abs_error_over_ksatfit": result["max_abs_error_over_ksatfit"],
            "bracket_failure_count": result["bracket_failure_count"],
        }, sort_keys=True), flush=True)

    passed = all(r["pass"] for r in materials)
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E2C_R1_DETERMINISTIC_LOG_HEAD_SEGMENTED_LOCAL_FACE_SOLVE",
        "contract": CONTRACT,
        "candidate": "LOG_HEAD_QUARTER_DECADE_GL8_SEGMENTS_PLUS_64_BISECTION",
        "production_implementation": False,
        "qualification_use": False,
        "material_count": len(materials),
        "material_pass_count": sum(r["pass"] for r in materials),
        "materials": materials,
        "segments_per_decade": 4,
        "max_segments_per_face": MAX_SEGMENTS,
        "quadrature_lanes_per_segment": GL_SEGMENT_N,
        "generic_max_constitutive_K_evaluations_precommitted": MAX_K_EVALS,
        "observed_reported_max_constitutive_K_evaluations": max(r["max_constitutive_K_evaluations"] for r in materials),
        "max_root_residual_evaluations": max(r["max_root_residual_evaluations"] for r in materials),
        "max_hybrid_metric": max(r["max_hybrid_metric"] for r in materials),
        "max_p99_hybrid_metric": max(r["p99_hybrid_metric"] for r in materials),
        "max_abs_error_over_ksatfit": max(r["max_abs_error_over_ksatfit"] for r in materials),
        "total_bracket_failures": sum(r["bracket_failure_count"] for r in materials),
        "total_nonfinite_count": sum(r["nonfinite_count"] for r in materials),
        "persistent_per_column_state_bytes": 0,
        "scratch_owner": "worker",
        "table_lookup": False,
        "pass": passed,
        "decision": (
            "QUALIFIED_BOUNDED_SEGMENTED_LOCAL_NEAR_SATURATION_FACE_FALLBACK_READY_FOR_E_SATURATION_TRANSITION_PROTOTYPE"
            if passed else
            "SEGMENTED_LOCAL_FACE_SOLVE_NOT_QUALIFIED_NEAR_SATURATION_FALLBACK_RESEARCH_REQUIRED"
        ),
        "preserved_negative_evidence": [
            "E2A direct-head table rejection",
            "E2A-R1A uniform-S table rejection",
            "E2A-R2A asymptotic-axis table rejection",
            "E2B fixed-node Q2 table rejection",
            "E2C single-panel t8 GL128 bounded local-solve rejection"
        ],
        "hard_nonclaims": [
            "This gate does not admit the segmented local solve as the normal RossFast production face path.",
            "No saturation-transition timestep or column is qualified here.",
            "No runtime or MultiSWAP throughput is qualified here."
        ],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "pass": result["pass"],
        "decision": result["decision"],
        "material_pass_count": result["material_pass_count"],
        "max_abs_error_over_ksatfit": result["max_abs_error_over_ksatfit"],
        "total_bracket_failures": result["total_bracket_failures"],
    }, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
