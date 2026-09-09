from __future__ import annotations

import hashlib
import json
import math
import multiprocessing as mp
import sys
import time
from pathlib import Path

import numpy as np
from scipy.stats import qmc

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_c1 as c1

CONTRACT = "F-ROSS01_GATE_E2A_R0_CROSS_REGION_INTERPOLATION_CAUSALITY_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13", "B01", "O14")
N_WET = 33
N_DRY_LOG = (241, 481, 961)
N_DRY_S = 241
H_WET_MIN = -1.0
H_WET_MAX = 1.0
H_DRY_MIN = -10000.0
H_DRY_MAX = -1.0
LENGTH = 10.0
PROBE_COUNT = 192
E2A_P99_THRESHOLD = 0.002
CTX = mp.get_context("fork")

PARENT_WORST = {
    "B12": {"h_above": -0.011933669447898865, "h_below": -1.994237053678148, "region": "WET_DRY"},
    "O13": {"h_above": -0.007651396095752716, "h_below": -141.70309854948502, "region": "WET_DRY"},
    "B01": {"h_above": 0.011916283518075943, "h_below": -0.15130172669887543, "region": "WET_WET"},
    "O14": {"h_above": 0.037352437153458595, "h_below": -0.14340071566402912, "region": "WET_WET"},
}


def seed_for(material: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-E2A-R0:" + material).encode()).hexdigest()[:8], 16)


def configure(row: dict) -> None:
    c1.configure_core(row)
    c1.core.H_MIN = H_DRY_MIN
    c1.core.H_MAX = H_WET_MAX


def build_probes(material: str):
    sob = qmc.Sobol(d=2, scramble=True, seed=seed_for(material)).random_base2(m=8)[:PROBE_COUNT]
    probes = []
    for i, (a, b) in enumerate(sob):
        ha = H_WET_MIN + (H_WET_MAX - H_WET_MIN) * float(a)
        u = 4.0 * float(b)
        hb = -(10.0 ** u)
        probes.append({"id": f"sobol_{i:03d}", "h_above": ha, "h_below": hb, "kind": "fresh_sobol"})
    parent = PARENT_WORST[material]
    if parent["region"] == "WET_DRY":
        probes.append({"id": "parent_e2a_worst_wet_dry", "h_above": float(parent["h_above"]), "h_below": float(parent["h_below"]), "kind": "parent_worst_witness"})
    return probes


def loc_uniform(x: float, lo: float, hi: float, n: int):
    z = (n - 1) * (x - lo) / (hi - lo)
    if not (-1.0e-10 <= z <= n - 1 + 1.0e-10):
        raise ValueError(("coordinate_extrapolation", x, lo, hi, n, z))
    z = min(n - 1.0, max(0.0, z))
    i = min(n - 2, max(0, int(math.floor(z))))
    return i, z - i


def wet_bracket(h: float):
    i, f = loc_uniform(h, H_WET_MIN, H_WET_MAX, N_WET)
    step = (H_WET_MAX - H_WET_MIN) / (N_WET - 1)
    return i, f, H_WET_MIN + step * i, H_WET_MIN + step * (i + 1)


def dry_log_bracket(h: float, n: int):
    u = math.log10(-h)
    i, f = loc_uniform(u, 0.0, 4.0, n)
    u0 = 4.0 * i / (n - 1)
    u1 = 4.0 * (i + 1) / (n - 1)
    return i, f, -(10.0 ** u0), -(10.0 ** u1)


def dry_s_bracket(h: float, n: int):
    s_min = float(c1.core.s_of_h(H_DRY_MIN))
    s_max = float(c1.core.s_of_h(H_DRY_MAX))
    s = float(c1.core.s_of_h(h))
    i, f = loc_uniform(s, s_min, s_max, n)
    s0 = s_min + (s_max - s_min) * i / (n - 1)
    s1 = s_min + (s_max - s_min) * (i + 1) / (n - 1)
    return i, f, float(c1.core.h_of_s(s0)), float(c1.core.h_of_s(s1))


def _safe_q(pair):
    ha, hb = pair
    try:
        return pair, float(c1.core.steady_q(float(ha), float(hb))), None
    except Exception as exc:
        return pair, None, repr(exc)


def mobility_from_q(ha: float, hb: float, q: float) -> float:
    driving = LENGTH + ha - hb
    if abs(driving) <= 1.0e-14:
        raise RuntimeError(("unexpected_hydrostatic_wet_dry_pair", ha, hb))
    m = q / driving
    if not (math.isfinite(m) and m > 0.0):
        raise RuntimeError(("invalid_mobility", ha, hb, q, driving, m))
    return m


def stored_logm(qmap, pair):
    ha, hb = pair
    return float(np.float32(math.log(mobility_from_q(ha, hb, qmap[pair]))))


def stored_m(qmap, pair):
    ha, hb = pair
    return float(np.float32(mobility_from_q(ha, hb, qmap[pair])))


def bilinear(v00, v10, v01, v11, fa, fb):
    return (1.0 - fa) * (1.0 - fb) * v00 + fa * (1.0 - fb) * v10 + (1.0 - fa) * fb * v01 + fa * fb * v11


def linear(v0, v1, f):
    return (1.0 - f) * v0 + f * v1


def prepare_pairs(probes):
    pairs = set()
    for p in probes:
        ha = float(p["h_above"])
        hb = float(p["h_below"])
        pairs.add((ha, hb))
        _, _, w0, w1 = wet_bracket(ha)
        pairs.add((w0, hb))
        pairs.add((w1, hb))
        for n in N_DRY_LOG:
            _, _, d0, d1 = dry_log_bracket(hb, n)
            pairs.update(((ha, d0), (ha, d1), (w0, d0), (w1, d0), (w0, d1), (w1, d1)))
        _, _, d0s, d1s = dry_s_bracket(hb, N_DRY_S)
        pairs.update(((ha, d0s), (ha, d1s), (w0, d0s), (w1, d0s), (w0, d1s), (w1, d1s)))
    return sorted(pairs)


def summarize(values):
    if not values:
        return {"max_hybrid_metric": math.inf, "p99_hybrid_metric": math.inf, "max_abs_error_over_ksatfit": math.inf}
    hy = sorted(v["hybrid_metric"] for v in values)
    return {
        "count": len(values),
        "max_hybrid_metric": max(hy),
        "p99_hybrid_metric": hy[int(0.99 * (len(hy) - 1))],
        "max_abs_error_over_ksatfit": max(v["abs_error_over_ksatfit"] for v in values),
        "worst": max(values, key=lambda v: v["hybrid_metric"]),
    }


def metric_row(probe, q_ref, q_cand, ksat, method, cell):
    return {
        "probe_id": probe["id"], "kind": probe["kind"], "method": method,
        "h_above": probe["h_above"], "h_below": probe["h_below"],
        "q_ref": q_ref, "q_candidate": q_cand,
        "hybrid_metric": abs(q_cand - q_ref) / (abs(q_ref) + 1.0e-4 * ksat),
        "abs_error_over_ksatfit": abs(q_cand - q_ref) / ksat,
        "cell": cell,
    }


def evaluate_material(row):
    configure(row)
    material = row["sfu"]
    ksat = float(c1.core.KSAT)
    probes = build_probes(material)
    pairs = prepare_pairs(probes)
    started = time.time()
    qmap = {}
    errors = []
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for pair, q, error in pool.imap_unordered(_safe_q, pairs, chunksize=4):
            if error is None:
                qmap[pair] = q
            else:
                errors.append({"pair": list(pair), "error": error})
    if errors:
        return {"material": material, "pass_runtime": False, "oracle_error_count": len(errors), "oracle_error_examples": errors[:8], "elapsed_seconds_descriptive": time.time() - started}

    methods = {"WET_ONLY_LOGM": [], "FULL_BILINEAR_M_U241": [], "DRY_ONLY_LOGM_S241": [], "FULL_BILINEAR_LOGM_S241": []}
    for n in N_DRY_LOG:
        methods[f"DRY_ONLY_LOGM_U{n}"] = []
        methods[f"FULL_BILINEAR_LOGM_U{n}"] = []

    for p in probes:
        ha, hb = float(p["h_above"]), float(p["h_below"])
        q_ref = qmap[(ha, hb)]
        driving = LENGTH + ha - hb
        wi, fw, w0, w1 = wet_bracket(ha)

        l0, l1 = stored_logm(qmap, (w0, hb)), stored_logm(qmap, (w1, hb))
        q = driving * math.exp(linear(l0, l1, fw))
        methods["WET_ONLY_LOGM"].append(metric_row(p, q_ref, q, ksat, "WET_ONLY_LOGM", {"wet_i": wi, "wet_fraction": fw, "dry_coordinate": "exact"}))

        for n in N_DRY_LOG:
            di, fd, d0, d1 = dry_log_bracket(hb, n)
            a, b = stored_logm(qmap, (ha, d0)), stored_logm(qmap, (ha, d1))
            q_dry = driving * math.exp(linear(a, b, fd))
            methods[f"DRY_ONLY_LOGM_U{n}"].append(metric_row(p, q_ref, q_dry, ksat, f"DRY_ONLY_LOGM_U{n}", {"wet_coordinate": "exact", "dry_i": di, "dry_fraction": fd}))
            v00, v10 = stored_logm(qmap, (w0, d0)), stored_logm(qmap, (w1, d0))
            v01, v11 = stored_logm(qmap, (w0, d1)), stored_logm(qmap, (w1, d1))
            q_full = driving * math.exp(bilinear(v00, v10, v01, v11, fw, fd))
            methods[f"FULL_BILINEAR_LOGM_U{n}"].append(metric_row(p, q_ref, q_full, ksat, f"FULL_BILINEAR_LOGM_U{n}", {"wet_i": wi, "wet_fraction": fw, "dry_i": di, "dry_fraction": fd}))
            if n == 241:
                m00, m10 = stored_m(qmap, (w0, d0)), stored_m(qmap, (w1, d0))
                m01, m11 = stored_m(qmap, (w0, d1)), stored_m(qmap, (w1, d1))
                q_m = driving * bilinear(m00, m10, m01, m11, fw, fd)
                methods["FULL_BILINEAR_M_U241"].append(metric_row(p, q_ref, q_m, ksat, "FULL_BILINEAR_M_U241", {"wet_i": wi, "wet_fraction": fw, "dry_i": di, "dry_fraction": fd}))

        di, fd, d0, d1 = dry_s_bracket(hb, N_DRY_S)
        a, b = stored_logm(qmap, (ha, d0)), stored_logm(qmap, (ha, d1))
        q_dry_s = driving * math.exp(linear(a, b, fd))
        methods["DRY_ONLY_LOGM_S241"].append(metric_row(p, q_ref, q_dry_s, ksat, "DRY_ONLY_LOGM_S241", {"wet_coordinate": "exact", "dry_i": di, "dry_fraction": fd}))
        v00, v10 = stored_logm(qmap, (w0, d0)), stored_logm(qmap, (w1, d0))
        v01, v11 = stored_logm(qmap, (w0, d1)), stored_logm(qmap, (w1, d1))
        q_full_s = driving * math.exp(bilinear(v00, v10, v01, v11, fw, fd))
        methods["FULL_BILINEAR_LOGM_S241"].append(metric_row(p, q_ref, q_full_s, ksat, "FULL_BILINEAR_LOGM_S241", {"wet_i": wi, "wet_fraction": fw, "dry_i": di, "dry_fraction": fd}))

    summaries = {name: summarize(vals) for name, vals in methods.items()}
    p_wet = summaries["WET_ONLY_LOGM"]["p99_hybrid_metric"]
    p_dry_241 = summaries["DRY_ONLY_LOGM_U241"]["p99_hybrid_metric"]
    p_full_241 = summaries["FULL_BILINEAR_LOGM_U241"]["p99_hybrid_metric"]
    p_full_961 = summaries["FULL_BILINEAR_LOGM_U961"]["p99_hybrid_metric"]
    p_dry_s = summaries["DRY_ONLY_LOGM_S241"]["p99_hybrid_metric"]
    p_direct_m = summaries["FULL_BILINEAR_M_U241"]["p99_hybrid_metric"]

    signatures = []
    if p_dry_241 >= 10.0 * max(p_wet, 1.0e-300) and p_full_241 >= 4.0 * max(p_full_961, 1.0e-300): signatures.append("DRY_AXIS_RESOLUTION_DOMINANT")
    if p_dry_241 >= 4.0 * max(p_dry_s, 1.0e-300) and p_wet <= E2A_P99_THRESHOLD: signatures.append("DRY_COORDINATE_CONDITIONING_DOMINANT")
    if p_full_241 >= 4.0 * max(p_direct_m, 1.0e-300): signatures.append("LOG_MOBILITY_TRANSFORM_DOMINANT")
    if p_wet >= 10.0 * max(p_dry_241, 1.0e-300): signatures.append("WET_AXIS_DOMINANT")
    classification = signatures[0] if len(signatures) == 1 else ("MULTIPLE_DOMINANT_SIGNATURES" if signatures else "MIXED_OR_NONSEPARABLE")

    parent = PARENT_WORST[material]
    return {
        "material": material, "seed": seed_for(material), "fresh_probe_count": PROBE_COUNT,
        "evaluated_probe_count": len(probes), "oracle_pair_count": len(pairs), "oracle_error_count": 0,
        "parent_e2a_worst_witness": {**parent, "evaluated_in_r0": parent["region"] == "WET_DRY", "reason_if_not_evaluated": None if parent["region"] == "WET_DRY" else "parent E2A worst probe is outside frozen R0 WET_DRY causal scope"},
        "method_summaries": summaries,
        "diagnostic_ratios": {
            "dry_only_u241_over_wet_only_p99": p_dry_241 / max(p_wet, 1.0e-300),
            "full_u241_over_full_u961_p99": p_full_241 / max(p_full_961, 1.0e-300),
            "dry_only_u241_over_s241_p99": p_dry_241 / max(p_dry_s, 1.0e-300),
            "full_logm_u241_over_direct_m_u241_p99": p_full_241 / max(p_direct_m, 1.0e-300),
            "wet_only_over_dry_only_u241_p99": p_wet / max(p_dry_241, 1.0e-300),
        },
        "matched_dominant_signatures": signatures, "classification": classification,
        "pass_runtime": True, "elapsed_seconds_descriptive": time.time() - started,
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2a_r0_cross_region_interpolation_causality.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    results = []
    started = time.time()
    for i, material in enumerate(MATERIALS, 1):
        result = evaluate_material(by_name[material])
        results.append(result)
        print(json.dumps({"progress": f"{i}/{len(MATERIALS)}", "material": material, "classification": result.get("classification"), "pass_runtime": result["pass_runtime"], "oracle_error_count": result.get("oracle_error_count")}, sort_keys=True), flush=True)
    runtime_ok = all(r["pass_runtime"] for r in results)
    result = {
        "schema_version": 1, "workstream": "F-ROSS", "work_unit": "F-ROSS01",
        "gate": "E2A_R0_CROSS_REGION_INTERPOLATION_CAUSALITY_DIAGNOSTIC", "contract": CONTRACT,
        "production_implementation": False, "qualification_use": False, "materials": list(MATERIALS),
        "fresh_probe_count_per_material": PROBE_COUNT, "precommitted_dry_log_node_counts": list(N_DRY_LOG),
        "precommitted_dry_s_node_count": N_DRY_S, "wet_node_count": N_WET, "runtime_ok": runtime_ok,
        "structural_failure_classifications": {r["material"]: r.get("classification") for r in results if r["material"] in ("B12", "O13")},
        "results": results, "elapsed_seconds_descriptive": time.time() - started,
        "decision": "CROSS_REGION_CAUSALITY_CLASSIFIED_READY_TO_FREEZE_SEPARATE_E2A_R1_REPRESENTATION_RESEARCH" if runtime_ok else "CROSS_REGION_CAUSALITY_DIAGNOSTIC_RUNTIME_FAILURE_RECONCILE_BEFORE_R1",
        "hard_guard": "No result in R0 qualifies a replacement face representation; E2A failure remains authoritative negative evidence.",
    }
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "results"}, sort_keys=True), flush=True)
    raise SystemExit(0 if runtime_ok else 1)


if __name__ == "__main__":
    main()
