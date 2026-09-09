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

CONTRACT = "F-ROSS01_GATE_E2C_R1B_ENDPOINT_BRACKET_CAUSALITY_DIAGNOSTIC_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13")
EPS_LADDER = (1.0e-8, 1.0e-10, 1.0e-12, 1.0e-14)


def first_lane_distance(h_above: float, h_below: float) -> float:
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
    a, b = ordered[0], ordered[1]
    mid = 0.5 * (a + b)
    half = 0.5 * (b - a)
    heads = mid + half * r1._x8
    return min(abs(float(h) - h_above) for h in heads)


def bracket_meta(h_above: float, h_below: float) -> tuple[str, float, float]:
    dh = h_below - h_above
    k_above = float(e2c.c1.core.k_of_h(h_above))
    ksat = float(e2c.c1.core.KSAT)
    if h_below > h_above:
        if dh < e2c.LENGTH:
            return "Q_BELOW_KABOVE_ENDPOINT", 0.0, k_above * (1.0 - 1.0e-12)
        lo = -ksat * max(0.0, dh / e2c.LENGTH - 1.0)
        return "NEGATIVE_Q", math.nextafter(lo, -math.inf), 0.0
    drop = h_above - h_below
    lo = k_above * (1.0 + 1.0e-12)
    hi = math.nextafter(ksat * (1.0 + drop / e2c.LENGTH), math.inf)
    return "Q_ABOVE_KABOVE_ENDPOINT", lo, hi


def endpoint_q(k_above: float, branch: str, eps: float | None) -> float:
    if branch == "Q_BELOW_KABOVE_ENDPOINT":
        if eps is None:
            return math.nextafter(k_above, -math.inf)
        return k_above * (1.0 - eps)
    if branch == "Q_ABOVE_KABOVE_ENDPOINT":
        if eps is None:
            return math.nextafter(k_above, math.inf)
        return k_above * (1.0 + eps)
    raise ValueError(branch)


def opposite_endpoint_residual(residual, branch: str, lo: float, hi: float) -> float:
    if branch == "Q_BELOW_KABOVE_ENDPOINT":
        return float(residual(lo))
    if branch == "Q_ABOVE_KABOVE_ENDPOINT":
        return float(residual(hi))
    raise ValueError(branch)


def signs_bracket(a: float, b: float) -> bool:
    return math.isfinite(a) and math.isfinite(b) and (a == 0.0 or b == 0.0 or a * b < 0.0)


def percentile(values: list[float], p: float) -> float:
    if not values:
        return math.nan
    x = sorted(values)
    return x[int(p * (len(x) - 1))]


def run_material(row: dict) -> dict:
    e2c.configure(row)
    material = row["sfu"]
    probes = e2c.e2b.build_probes(material)
    failures = []
    for p in probes:
        ha = float(p["h_above"])
        hb = float(p["h_below"])
        scale = max(1.0, abs(ha), abs(hb))
        if abs(ha - hb) <= 2.0e-14 * scale:
            continue
        dh = hb - ha
        if abs(dh - e2c.LENGTH) <= 2.0e-13 * max(1.0, e2c.LENGTH, abs(dh)):
            continue
        residual = r1.segmented_residual_factory(ha, hb)
        branch, lo, hi = bracket_meta(ha, hb)
        f_lo = float(residual(lo))
        f_hi = float(residual(hi))
        if signs_bracket(f_lo, f_hi):
            continue

        q_ref = float(e2c.c1.core.steady_q(ha, hb))
        k_above = float(e2c.c1.core.k_of_h(ha))
        rel_gap = abs(q_ref - k_above) / max(abs(k_above), 1.0e-300)
        record = {
            "probe_id": p["id"],
            "kind": p["kind"],
            "h_above": ha,
            "h_below": hb,
            "branch_class": branch,
            "q_reference": q_ref,
            "K_h_above": k_above,
            "relative_root_gap_to_K_h_above": rel_gap,
            "R1_f_lo": f_lo,
            "R1_f_hi": f_hi,
            "first_quadrature_lane_distance_from_h_above_cm": first_lane_distance(ha, hb),
            "endpoint_tests": {},
        }
        if branch in ("Q_BELOW_KABOVE_ENDPOINT", "Q_ABOVE_KABOVE_ENDPOINT"):
            f_other = opposite_endpoint_residual(residual, branch, lo, hi)
            recovered_at = None
            for eps in EPS_LADDER:
                q = endpoint_q(k_above, branch, eps)
                f = float(residual(q))
                ok = signs_bracket(f_other, f)
                record["endpoint_tests"][f"eps_{eps:.0e}"] = {"q": q, "residual": f, "bracket_recovered": ok}
                if recovered_at is None and ok:
                    recovered_at = eps
            q = endpoint_q(k_above, branch, None)
            try:
                f = float(residual(q))
                ok = signs_bracket(f_other, f)
            except Exception:
                f = math.nan
                ok = False
            record["endpoint_tests"]["nextafter"] = {"q": q, "residual": f, "bracket_recovered": ok}
            record["first_recovered_epsilon"] = recovered_at
            record["nextafter_recovers_bracket"] = ok
        failures.append(record)

    gaps = [f["relative_root_gap_to_K_h_above"] for f in failures]
    endpoint = [f for f in failures if f["branch_class"] != "NEGATIVE_Q"]
    return {
        "material": material,
        "probe_count": len(probes),
        "failure_count": len(failures),
        "branch_counts": {b: sum(f["branch_class"] == b for f in failures) for b in sorted({f["branch_class"] for f in failures})},
        "relative_root_gap": {
            "min": min(gaps) if gaps else 0.0,
            "median": percentile(gaps, 0.5),
            "max": max(gaps) if gaps else 0.0,
            "fraction_below_1e_10": sum(g < 1.0e-10 for g in gaps) / len(gaps) if gaps else 0.0,
            "fraction_below_1e_12": sum(g < 1.0e-12 for g in gaps) / len(gaps) if gaps else 0.0,
        },
        "endpoint_failure_count": len(endpoint),
        "fraction_endpoint_failures_recovered_by_nextafter_q": sum(bool(f.get("nextafter_recovers_bracket")) for f in endpoint) / len(endpoint) if endpoint else 0.0,
        "failure_examples_smallest_gap": sorted(failures, key=lambda f: f["relative_root_gap_to_K_h_above"])[:12],
        "failure_examples_largest_gap": sorted(failures, key=lambda f: f["relative_root_gap_to_K_h_above"], reverse=True)[:12],
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2c_r1b_endpoint_bracket_diagnostic.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}
    results = [run_material(by[m]) for m in MATERIALS]
    total = sum(r["failure_count"] for r in results)
    endpoint_total = sum(r["endpoint_failure_count"] for r in results)
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E2C_R1B_ENDPOINT_BRACKET_CAUSALITY_DIAGNOSTIC",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": False,
        "materials": results,
        "total_R1_bracket_failures_reproduced": total,
        "endpoint_class_failure_count": endpoint_total,
        "causal_support_for_endpoint_clustered_followup": endpoint_total == total and total == 196,
        "decision": "ENDPOINT_CAUSALITY_SUPPORTED_READY_TO_FREEZE_E2C_R2" if endpoint_total == total and total == 196 else "ENDPOINT_CAUSALITY_NOT_FULLY_SUPPORTED_DO_NOT_OPEN_E2C_R2_YET",
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "total_R1_bracket_failures_reproduced": total,
        "endpoint_class_failure_count": endpoint_total,
        "decision": result["decision"],
        "materials": [{"material": r["material"], "failure_count": r["failure_count"], "branch_counts": r["branch_counts"], "relative_root_gap": r["relative_root_gap"]} for r in results],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
