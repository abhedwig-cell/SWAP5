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
import run_ross01_gate_e2c_r2_endpoint_clustered_local_face as r2

CONTRACT = "F-ROSS01_GATE_E2C_R2B_ENDPOINT_CLUSTER_EXPONENT_DIAGNOSTIC_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13")
EXPONENTS = (8, 12, 16, 24, 32)

_t = 0.5 * (r1._x8 + 1.0)
_w = 0.5 * r1._w8


def segment_points(h_above: float, h_below: float) -> list[float]:
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
    return ordered


def residual_factory(h_above: float, h_below: float, exponent: int):
    ordered = segment_points(h_above, h_below)
    all_k = []
    all_w = []
    first_lane_distance = None
    for seg_index, (a, b) in enumerate(zip(ordered[:-1], ordered[1:])):
        if seg_index == 0:
            dh = b - a
            heads = a + dh * (_t ** exponent)
            weights = _w * (dh * exponent * (_t ** (exponent - 1)))
            first_lane_distance = min(abs(float(h) - h_above) for h in heads)
        else:
            mid = 0.5 * (a + b)
            half = 0.5 * (b - a)
            heads = mid + half * r1._x8
            weights = half * r1._w8
        kvals = np.asarray([e2c.c1.core.k_of_h(float(h)) for h in heads], dtype=np.float64)
        all_k.append(kvals)
        all_w.append(weights)
    kvals = np.concatenate(all_k)
    weights = np.concatenate(all_w)

    def residual(q: float) -> float:
        den = kvals - q
        if np.any(den == 0.0):
            return math.copysign(math.inf, float(np.sum(weights)))
        return float(np.sum(weights * kvals / den)) - e2c.LENGTH

    return residual, float(first_lane_distance), abs(ordered[1] - ordered[0])


def bracket_status(h_above: float, h_below: float, exponent: int) -> dict:
    residual, lane_distance, segment_length = residual_factory(h_above, h_below, exponent)
    k_above = float(e2c.c1.core.k_of_h(h_above))
    ksat = float(e2c.c1.core.KSAT)
    drop = h_above - h_below
    lo = math.nextafter(k_above, math.inf)
    hi = math.nextafter(ksat * (1.0 + drop / e2c.LENGTH), math.inf)
    try:
        f_lo = float(residual(lo))
        f_hi = float(residual(hi))
        finite = math.isfinite(f_lo) and math.isfinite(f_hi)
        bracket = finite and (f_lo == 0.0 or f_hi == 0.0 or f_lo * f_hi < 0.0)
    except Exception:
        f_lo = math.nan
        f_hi = math.nan
        finite = False
        bracket = False
    return {
        "exponent": exponent,
        "first_segment_length_cm": segment_length,
        "nearest_first_segment_lane_distance_cm": lane_distance,
        "f_lo": f_lo,
        "f_hi": f_hi,
        "finite": finite,
        "bracket_restored": bracket,
    }


def is_r2_failure(h_above: float, h_below: float) -> bool:
    try:
        _q, _meta = r2.candidate_q_r2(h_above, h_below)
        return False
    except RuntimeError as exc:
        return bool(exc.args and isinstance(exc.args[0], tuple) and exc.args[0] and exc.args[0][0] == "bracket_failure")


def run_material(row: dict) -> dict:
    e2c.configure(row)
    material = row["sfu"]
    failures = []
    probes = e2c.e2b.build_probes(material)
    for p in probes:
        ha = float(p["h_above"])
        hb = float(p["h_below"])
        scale = max(1.0, abs(ha), abs(hb))
        if abs(ha - hb) <= 2.0e-14 * scale:
            continue
        dh = hb - ha
        if abs(dh - e2c.LENGTH) <= 2.0e-13 * max(1.0, e2c.LENGTH, abs(dh)):
            continue
        if not is_r2_failure(ha, hb):
            continue
        q_ref = float(e2c.c1.core.steady_q(ha, hb))
        k_above = float(e2c.c1.core.k_of_h(ha))
        statuses = [bracket_status(ha, hb, exponent) for exponent in EXPONENTS]
        restored = [s["exponent"] for s in statuses if s["bracket_restored"]]
        failures.append({
            "probe_id": p["id"],
            "kind": p["kind"],
            "h_above": ha,
            "h_below": hb,
            "q_reference": q_ref,
            "K_h_above": k_above,
            "relative_root_gap_to_K_h_above": abs(q_ref - k_above) / max(abs(k_above), 1e-300),
            "smallest_restoring_exponent": min(restored) if restored else None,
            "exponents": statuses,
        })
    return {"material": material, "failure_count": len(failures), "failures": failures}


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2c_r2b_endpoint_exponent_diagnostic.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {row["sfu"]: row for row in catalog["rows"]}
    materials = [run_material(by[m]) for m in MATERIALS]
    all_failures = [f for m in materials for f in m["failures"]]
    counts = {str(e): sum(any(s["exponent"] == e and s["bracket_restored"] for s in f["exponents"]) for f in all_failures) for e in EXPONENTS}
    common = [e for e in EXPONENTS if counts[str(e)] == len(all_failures)]
    decision = (
        "ENDPOINT_CLUSTER_EXPONENT_CAUSAL_ROUTE_SUPPORTED_READY_TO_FREEZE_R3_WITH_SMALLEST_COMMON_FIXED_EXPONENT"
        if common and len(all_failures) == 28 else
        "FIXED_EXPONENT_CLUSTERING_INSUFFICIENT_DO_NOT_OPEN_R3_AS_SIMPLE_EXPONENT_CHANGE"
    )
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E2C_R2B_ENDPOINT_CLUSTER_EXPONENT_DIAGNOSTIC",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": False,
        "R2_failure_count_reproduced": len(all_failures),
        "fixed_endpoint_exponents": list(EXPONENTS),
        "restored_count_by_exponent": counts,
        "smallest_common_fixed_exponent": min(common) if common else None,
        "materials": materials,
        "decision": decision,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "R2_failure_count_reproduced": result["R2_failure_count_reproduced"],
        "restored_count_by_exponent": counts,
        "smallest_common_fixed_exponent": result["smallest_common_fixed_exponent"],
        "decision": decision,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
