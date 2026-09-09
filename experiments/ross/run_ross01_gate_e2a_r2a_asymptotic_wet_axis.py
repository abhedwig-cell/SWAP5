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

CONTRACT = "F-ROSS01_GATE_E2A_R2A_ASYMPTOTIC_WET_AXIS_WET_DRY_CHARACTERIZATION_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13", "B01", "O14")
CANDIDATES = (("A17_SAT17", 17, 17), ("A33_SAT17", 33, 17))
N_DRY = 241
H_WET_MIN = -1.0
H_WET_MAX = 1.0
H_DRY_MIN = -10000.0
LENGTH = 10.0
FRESH_COUNT = 384
TARGET_WET = (-0.1, -0.01, -0.001, -1.0e-6, -1.0e-9, 0.0, 1.0e-9, 1.0e-6, 0.001, 0.01, 0.1)
TARGET_DRY = (-2.0, -10.0, -100.0, -1000.0)
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
CTX = mp.get_context("fork")
WITNESSES = {
    "B12": ((-0.011933669447898865,-1.994237053678148),(-0.006681255996227264,-2.1627095864411228)),
    "O13": ((-0.007651396095752716,-141.70309854948502),(-0.0064528752118349075,-1348.0887092096832)),
    "B01": ((-0.09409510344266891,-1.2136341101952008),),
    "O14": ((-0.07127580977976322,-1.6563619327833652),),
}


def seed_for(material: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-E2A-R2A:" + material).encode()).hexdigest()[:8], 16)


def configure(row: dict) -> None:
    c1.configure_core(row)
    c1.core.H_MIN = H_DRY_MIN
    c1.core.H_MAX = H_WET_MAX


def loc_uniform(x: float, lo: float, hi: float, n: int):
    z = (n - 1) * (x - lo) / (hi - lo)
    if not (-1.0e-10 <= z <= n - 1 + 1.0e-10):
        raise ValueError(("coordinate_extrapolation", x, lo, hi, n, z))
    z = min(n - 1.0, max(0.0, z))
    i = min(n - 2, max(0, int(math.floor(z))))
    return i, z - i


def dry_bracket(h: float):
    u = math.log10(-h)
    i, f = loc_uniform(u, 0.0, 4.0, N_DRY)
    u0 = 4.0 * i / (N_DRY - 1)
    u1 = 4.0 * (i + 1) / (N_DRY - 1)
    return i, f, -(10.0 ** u0), -(10.0 ** u1)


def asymptotic_t(h: float) -> float:
    if h >= 0.0:
        return 1.0
    exponent = float(c1.core.NPAR) - 1.0
    return 1.0 - (-h) ** exponent


def h_from_t(t: float) -> float:
    if t >= 1.0:
        return 0.0
    exponent = float(c1.core.NPAR) - 1.0
    return -max(0.0, 1.0 - t) ** (1.0 / exponent)


def wet_bracket(h: float, n_unsat: int, n_sat: int):
    if h < 0.0:
        t = asymptotic_t(h)
        i, f = loc_uniform(t, 0.0, 1.0, n_unsat)
        t0 = i / (n_unsat - 1)
        t1 = (i + 1) / (n_unsat - 1)
        return "UNSAT_ASYMPTOTIC", i, f, h_from_t(t0), h_from_t(t1)
    i, f = loc_uniform(h, 0.0, H_WET_MAX, n_sat)
    h0 = H_WET_MAX * i / (n_sat - 1)
    h1 = H_WET_MAX * (i + 1) / (n_sat - 1)
    return "SAT_HEAD", i, f, h0, h1


def build_probes(material: str):
    sob = qmc.Sobol(d=2, scramble=True, seed=seed_for(material)).random_base2(m=9)[:FRESH_COUNT]
    probes = []
    for i, (a, b) in enumerate(sob):
        probes.append({"id": f"sobol_{i:03d}", "kind": "fresh_sobol", "h_above": H_WET_MIN + 2.0 * float(a), "h_below": -(10.0 ** (4.0 * float(b)))})
    for ha in TARGET_WET:
        for hb in TARGET_DRY:
            probes.append({"id": f"target_{ha:.12g}_{hb:.12g}", "kind": "targeted_transition", "h_above": float(ha), "h_below": float(hb)})
    for j, (ha, hb) in enumerate(WITNESSES[material]):
        probes.append({"id": f"known_witness_{j}", "kind": "known_witness", "h_above": float(ha), "h_below": float(hb)})
    return probes


def _safe_q(pair):
    ha, hb = pair
    try:
        return pair, float(c1.core.steady_q(float(ha), float(hb))), None
    except Exception as exc:
        return pair, None, repr(exc)


def mobility(ha: float, hb: float, q: float) -> float:
    driving = LENGTH + ha - hb
    if abs(driving) <= 1.0e-14:
        raise RuntimeError(("unexpected_hydrostatic_wet_dry", ha, hb))
    m = q / driving
    if not (math.isfinite(m) and m > 0.0):
        raise RuntimeError(("invalid_mobility", ha, hb, q, driving, m))
    return m


def logm32(qmap, pair):
    ha, hb = pair
    return float(np.float32(math.log(mobility(ha, hb, qmap[pair]))))


def bilinear(v00, v10, v01, v11, fa, fb):
    return (1.0 - fa) * (1.0 - fb) * v00 + fa * (1.0 - fb) * v10 + (1.0 - fa) * fb * v01 + fa * fb * v11


def prepare_pairs(probes):
    pairs = {(float(p["h_above"]), float(p["h_below"])) for p in probes}
    for p in probes:
        ha, hb = float(p["h_above"]), float(p["h_below"])
        _, _, d0, d1 = dry_bracket(hb)
        for _, nu, ns in CANDIDATES:
            _, _, _, w0, w1 = wet_bracket(ha, nu, ns)
            pairs.update(((w0, d0), (w1, d0), (w0, d1), (w1, d1)))
    return sorted(pairs)


def summarize(rows):
    hy = sorted(r["hybrid_metric"] for r in rows)
    return {
        "valid_probe_count": len(rows),
        "max_hybrid_metric": max(hy),
        "p99_hybrid_metric": hy[int(0.99 * (len(hy) - 1))],
        "max_abs_error_over_ksatfit": max(r["abs_error_over_ksatfit"] for r in rows),
        "wrong_sign_count": sum(r["wrong_sign"] for r in rows),
        "unsaturated_wet_branch_max_hybrid": max((r["hybrid_metric"] for r in rows if r["wet_branch"] == "UNSAT_ASYMPTOTIC"), default=0.0),
        "saturated_wet_branch_max_hybrid": max((r["hybrid_metric"] for r in rows if r["wet_branch"] == "SAT_HEAD"), default=0.0),
        "transition_1e9_max_hybrid": max((r["hybrid_metric"] for r in rows if abs(abs(r["h_above"]) - 1.0e-9) <= 1.0e-20), default=0.0),
        "known_witness_max_hybrid": max((r["hybrid_metric"] for r in rows if r["kind"] == "known_witness"), default=0.0),
        "worst_probe": max(rows, key=lambda r: r["hybrid_metric"]),
    }


def evaluate_material(row):
    configure(row)
    material = row["sfu"]
    ksat = float(c1.core.KSAT)
    probes = build_probes(material)
    pairs = prepare_pairs(probes)
    qmap = {}
    errors = []
    started = time.time()
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for pair, q, error in pool.imap_unordered(_safe_q, pairs, chunksize=4):
            if error is None:
                qmap[pair] = q
            else:
                errors.append({"pair": list(pair), "error": error})
    if errors:
        return {"material": material, "runtime_pass": False, "node_evaluation_failures": len(errors), "failure_examples": errors[:8]}

    candidates = {}
    sign_threshold = 1.0e-8 * ksat
    for cid, nu, ns in CANDIDATES:
        rows = []
        lookup_failures = 0
        nonfinite = 0
        for p in probes:
            ha, hb = float(p["h_above"]), float(p["h_below"])
            try:
                branch, wi, fw, w0, w1 = wet_bracket(ha, nu, ns)
                di, fd, d0, d1 = dry_bracket(hb)
                v00, v10 = logm32(qmap, (w0, d0)), logm32(qmap, (w1, d0))
                v01, v11 = logm32(qmap, (w0, d1)), logm32(qmap, (w1, d1))
                q_ref = qmap[(ha, hb)]
                q_tab = (LENGTH + ha - hb) * math.exp(bilinear(v00, v10, v01, v11, fw, fd))
            except Exception:
                lookup_failures += 1
                continue
            if not (math.isfinite(q_ref) and math.isfinite(q_tab)):
                nonfinite += 1
                continue
            rows.append({
                "probe_id": p["id"], "kind": p["kind"], "h_above": ha, "h_below": hb,
                "wet_branch": branch, "wet_i": wi, "wet_fraction": fw, "dry_i": di, "dry_fraction": fd,
                "q_ref": q_ref, "q_table": q_tab,
                "hybrid_metric": abs(q_tab - q_ref) / (abs(q_ref) + 1.0e-4 * ksat),
                "abs_error_over_ksatfit": abs(q_tab - q_ref) / ksat,
                "wrong_sign": int(abs(q_ref) > sign_threshold and q_ref * q_tab < 0.0),
            })
        s = summarize(rows)
        unique_wet = nu + ns - 1
        conceptual_memory = 4 * unique_wet * N_DRY + 8 * (unique_wet + N_DRY)
        last_nonzero_h = h_from_t((nu - 2) / (nu - 1))
        s.update({
            "candidate": cid,
            "unsaturated_nodes_including_h0": nu,
            "saturated_nodes_including_h0": ns,
            "logical_unique_wet_nodes": unique_wet,
            "last_nonzero_negative_head_cm": last_nonzero_h,
            "lookup_failures": lookup_failures,
            "nan_or_inf": nonfinite,
            "node_evaluation_failures": 0,
            "sparse_node_pair_count_shared_across_candidates": len(pairs),
            "conceptual_full_wet_dry_table_plus_axes_bytes": conceptual_memory,
            "per_column_table_state_bytes": 0,
        })
        tests = {
            "max_hybrid_metric": s["max_hybrid_metric"] <= HYBRID_MAX,
            "p99_hybrid_metric": s["p99_hybrid_metric"] <= HYBRID_P99,
            "max_abs_error_over_ksatfit": s["max_abs_error_over_ksatfit"] <= ABS_KSAT_MAX,
            "wrong_sign_count": s["wrong_sign_count"] == 0,
            "lookup_failures": lookup_failures == 0,
            "nan_or_inf": nonfinite == 0,
            "node_evaluation_failures": True,
        }
        s["tests"] = tests
        s["pass"] = all(tests.values())
        s["failed_metrics"] = [k for k, ok in tests.items() if not ok]
        candidates[cid] = s
    return {
        "material": material,
        "n_parameter": float(c1.core.NPAR),
        "asymptotic_exponent_n_minus_1": float(c1.core.NPAR) - 1.0,
        "seed": seed_for(material),
        "fresh_probe_count": FRESH_COUNT,
        "total_probe_count": len(probes),
        "node_evaluation_failures": 0,
        "candidate_results": candidates,
        "runtime_pass": True,
        "elapsed_seconds_descriptive": time.time() - started,
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2a_r2a_asymptotic_wet_axis.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    by_name = {r["sfu"]: r for r in catalog["rows"]}
    results = []
    started = time.time()
    for i, material in enumerate(MATERIALS, 1):
        r = evaluate_material(by_name[material])
        results.append(r)
        print(json.dumps({
            "progress": f"{i}/{len(MATERIALS)}",
            "material": material,
            "runtime_pass": r["runtime_pass"],
            "candidate_pass": {cid: cr["pass"] for cid, cr in r.get("candidate_results", {}).items()},
        }, sort_keys=True), flush=True)

    runtime_ok = all(r["runtime_pass"] for r in results)
    selected = None
    if runtime_ok:
        for cid, _, _ in CANDIDATES:
            if all(r["candidate_results"][cid]["pass"] for r in results):
                selected = cid
                break
    passed = runtime_ok and selected is not None
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E2A_R2A_ASYMPTOTIC_WET_AXIS_WET_DRY_CHARACTERIZATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": False,
        "candidate_order": [c[0] for c in CANDIDATES],
        "selected_candidate": selected,
        "materials": list(MATERIALS),
        "runtime_ok": runtime_ok,
        "results": results,
        "elapsed_seconds_descriptive": time.time() - started,
        "pass": passed,
        "decision": "ASYMPTOTIC_WET_AXIS_WET_DRY_CHARACTERIZED_READY_FOR_FULL_REGION_R2B" if passed else "ASYMPTOTIC_WET_AXIS_REJECTED_STOP_NEAR_SATURATION_TABLE_LINE_AND_RECONSIDER_FACE_FORMULATION",
        "hard_guard": "Characterization only; no near-saturation face representation is qualified or admitted by R2A.",
    }
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "results"}, sort_keys=True), flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
