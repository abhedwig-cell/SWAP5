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

CONTRACT = "F-ROSS01_GATE_E2A_NEAR_SATURATION_FACE_CHARACTERIZATION_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
STRESS = ("O01", "O05", "O14", "B01", "B12", "O13")
NU = 241
NW_HIGH = 33
NW_LOW = 17
LENGTH = 10.0
H_DRY_MIN = -10000.0
H_SEAM = -1.0
H_WET_MAX = 1.0
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
EQUAL_REL_MAX = 0.005
HYDRO_MAX = 1.0e-5
NEAR_ZERO_TABLE_MAX = 1.0e-6
MEMORY_INCREMENT_MAX = 73728
ZERO_SEAM_EPS = 1.0e-6
CTX = mp.get_context("fork")


def seed(name: str, family: str) -> int:
    return int(hashlib.sha256((f"F-ROSS01-E2A:{name}:{family}").encode()).hexdigest()[:8], 16)


def configure(row: dict) -> None:
    c1.configure_core(row)
    c1.core.H_MIN = H_DRY_MIN
    c1.core.H_MAX = H_WET_MAX


def log_mobility(h_above: float, h_below: float) -> float:
    driving = LENGTH + h_above - h_below
    q = float(c1.core.steady_q(h_above, h_below))
    if abs(driving) <= 1.0e-12:
        mobility = float(c1.core.hydro_mobility(h_above))
    else:
        mobility = q / driving
    if not (math.isfinite(mobility) and mobility > 0.0):
        raise RuntimeError(("invalid_mobility", h_above, h_below, q, driving, mobility))
    return math.log(mobility)


def _safe_node(task):
    region, i, j, ha, hb = task
    try:
        return region, i, j, np.float32(log_mobility(ha, hb)), None
    except Exception as exc:
        return region, i, j, None, repr(exc)


def generate_high_tables():
    dry_u = np.linspace(0.0, 4.0, NU, dtype=np.float64)
    wet_h = np.linspace(H_SEAM, H_WET_MAX, NW_HIGH, dtype=np.float64)
    dry_h = -(10.0 ** dry_u)
    ww = np.full((NW_HIGH, NW_HIGH), np.nan, dtype=np.float32)
    dw = np.full((NU, NW_HIGH), np.nan, dtype=np.float32)
    wd = np.full((NW_HIGH, NU), np.nan, dtype=np.float32)
    tasks = []
    for i, ha in enumerate(wet_h):
        for j, hb in enumerate(wet_h):
            tasks.append(("ww", i, j, float(ha), float(hb)))
    for i, ha in enumerate(dry_h):
        for j, hb in enumerate(wet_h):
            tasks.append(("dw", i, j, float(ha), float(hb)))
    for i, ha in enumerate(wet_h):
        for j, hb in enumerate(dry_h):
            tasks.append(("wd", i, j, float(ha), float(hb)))
    failures = []
    started = time.time()
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for region, i, j, value, error in pool.imap_unordered(_safe_node, tasks, chunksize=4):
            if error is not None:
                failures.append({"region": region, "i": i, "j": j, "error": error})
                continue
            if region == "ww":
                ww[i, j] = value
            elif region == "dw":
                dw[i, j] = value
            else:
                wd[i, j] = value
    return dry_u, wet_h, ww, dw, wd, time.time() - started, failures


def _loc_uniform(x: float, lo: float, hi: float, n: int):
    z = (n - 1) * (x - lo) / (hi - lo)
    if not (-1.0e-10 <= z <= n - 1 + 1.0e-10):
        raise ValueError(("coordinate_extrapolation", x, lo, hi, n, z))
    z = min(n - 1.0, max(0.0, z))
    i = min(n - 2, max(0, int(math.floor(z))))
    return i, z - i


def _loc_dry(h: float):
    if not (H_DRY_MIN <= h <= H_SEAM):
        raise ValueError(("dry_head_outside", h))
    return _loc_uniform(math.log10(-h), 0.0, 4.0, NU)


def _bilinear(table, ia, fa, ib, fb):
    return (
        (1.0 - fa) * (1.0 - fb) * float(table[ia, ib])
        + fa * (1.0 - fb) * float(table[ia + 1, ib])
        + (1.0 - fa) * fb * float(table[ia, ib + 1])
        + fa * fb * float(table[ia + 1, ib + 1])
    )


def candidate_views(nwet: int, wet_high, ww_high, dw_high, wd_high):
    if nwet == NW_HIGH:
        wet = wet_high
        ww, dw, wd = ww_high, dw_high, wd_high
    elif nwet == NW_LOW:
        idx = np.arange(0, NW_HIGH, 2)
        wet = wet_high[idx]
        ww = ww_high[np.ix_(idx, idx)]
        dw = dw_high[:, idx]
        wd = wd_high[idx, :]
    else:
        raise ValueError(nwet)
    return wet, ww, dw, wd


def lookup(ha: float, hb: float, nwet: int, wet_high, ww_high, dw_high, wd_high):
    if not (H_DRY_MIN <= ha <= H_WET_MAX and H_DRY_MIN <= hb <= H_WET_MAX):
        raise ValueError("head outside E2A envelope")
    if ha < H_SEAM and hb < H_SEAM:
        raise ValueError("dry-dry delegated to C1R")
    if abs(ha - hb) <= 2.0e-14 * max(1.0, abs(ha), abs(hb)):
        return float(c1.core.k_of_h(0.5 * (ha + hb))), "equal_head"
    wet, ww, dw, wd = candidate_views(nwet, wet_high, ww_high, dw_high, wd_high)
    if ha >= H_SEAM and hb >= H_SEAM:
        ia, fa = _loc_uniform(ha, H_SEAM, H_WET_MAX, nwet)
        ib, fb = _loc_uniform(hb, H_SEAM, H_WET_MAX, nwet)
        logm = _bilinear(ww, ia, fa, ib, fb)
        region = "WET_WET"
    elif ha < H_SEAM and hb >= H_SEAM:
        ia, fa = _loc_dry(ha)
        ib, fb = _loc_uniform(hb, H_SEAM, H_WET_MAX, nwet)
        logm = _bilinear(dw, ia, fa, ib, fb)
        region = "DRY_WET"
    else:
        ia, fa = _loc_uniform(ha, H_SEAM, H_WET_MAX, nwet)
        ib, fb = _loc_dry(hb)
        logm = _bilinear(wd, ia, fa, ib, fb)
        region = "WET_DRY"
    driving = LENGTH + ha - hb
    if abs(driving) <= 2.0e-13 * max(1.0, LENGTH, abs(ha), abs(hb)):
        return 0.0, region
    return driving * math.exp(logm), region


def build_probes(name: str):
    probes = []
    sob = qmc.Sobol(d=2, scramble=True, seed=seed(name, "ww")).random_base2(m=8)
    for a, b in sob:
        probes.append((H_SEAM + 2.0 * float(a), H_SEAM + 2.0 * float(b), "wet_wet"))
    sob = qmc.Sobol(d=2, scramble=True, seed=seed(name, "dw")).random_base2(m=8)
    for a, b in sob:
        ha = -(10.0 ** (4.0 * float(a)))
        hb = H_SEAM + 2.0 * float(b)
        probes.append((ha, hb, "dry_wet"))
    sob = qmc.Sobol(d=2, scramble=True, seed=seed(name, "wd")).random_base2(m=8)
    for a, b in sob:
        ha = H_SEAM + 2.0 * float(a)
        hb = -(10.0 ** (4.0 * float(b)))
        probes.append((ha, hb, "wet_dry"))
    for h in np.linspace(H_SEAM, H_WET_MAX, 65):
        probes.append((float(h), float(h), "equal_head"))
    for ha in np.linspace(-11.0, -9.0, 33):
        probes.append((float(ha), float(ha + LENGTH), "hydrostatic"))
    for ha in np.linspace(-10.98, -9.02, 33):
        for eps in (-0.01, 0.01):
            probes.append((float(ha), float(ha + LENGTH + eps), "near_hydrostatic"))
    for hd in -np.geomspace(1.0, 10000.0, 20):
        probes.append((float(hd), H_SEAM, "minus1_seam"))
        probes.append((H_SEAM, float(hd), "minus1_seam"))
    for other in np.linspace(H_SEAM, H_WET_MAX, 10):
        for seam_h in (-ZERO_SEAM_EPS, ZERO_SEAM_EPS):
            probes.append((float(seam_h), float(other), "zero_seam"))
            probes.append((float(other), float(seam_h), "zero_seam"))
    edges = (
        (H_SEAM, H_SEAM), (H_SEAM, H_WET_MAX), (H_WET_MAX, H_SEAM), (H_WET_MAX, H_WET_MAX),
        (H_DRY_MIN, H_SEAM), (H_DRY_MIN, H_WET_MAX), (H_SEAM, H_DRY_MIN), (H_WET_MAX, H_DRY_MIN),
        (-11.0, H_SEAM), (-9.0, H_WET_MAX), (H_SEAM, -11.0), (H_WET_MAX, -9.0),
    )
    probes.extend((float(a), float(b), "edge") for a, b in edges)
    return probes


def _safe_ref(task):
    idx, ha, hb = task
    try:
        return idx, float(c1.core.steady_q(ha, hb)), None
    except Exception as exc:
        return idx, None, repr(exc)


def seam_node_difference(dry_u, ww, dw, wd):
    # E2A wet axis first node is h=-1. Recompute the corresponding C1R
    # boundary nodes with the identical physical node law and float32 storage.
    max_diff = 0.0
    for i, u in enumerate(dry_u):
        hd = -(10.0 ** float(u))
        expected_dw = np.float32(log_mobility(float(hd), H_SEAM))
        expected_wd = np.float32(log_mobility(H_SEAM, float(hd)))
        max_diff = max(max_diff, abs(float(dw[i, 0]) - float(expected_dw)))
        max_diff = max(max_diff, abs(float(wd[0, i]) - float(expected_wd)))
    expected_ww = np.float32(log_mobility(H_SEAM, H_SEAM))
    max_diff = max(max_diff, abs(float(ww[0, 0]) - float(expected_ww)))
    return max_diff


def summarize_candidate(nwet: int, probes, refs, wet_high, ww_high, dw_high, wd_high, seam_diff):
    rows = []
    lookup_failures = 0
    nan_or_inf = 0
    ksat = float(c1.core.KSAT)
    sign_threshold = 1.0e-8 * ksat
    for idx, (ha, hb, kind) in enumerate(probes):
        q_ref = refs[idx]
        if q_ref is None:
            continue
        try:
            q_tab, region = lookup(ha, hb, nwet, wet_high, ww_high, dw_high, wd_high)
        except Exception:
            lookup_failures += 1
            continue
        if not (math.isfinite(q_ref) and math.isfinite(q_tab)):
            nan_or_inf += 1
            continue
        rows.append({
            "kind": kind,
            "region": region,
            "h_above": ha,
            "h_below": hb,
            "q_ref": q_ref,
            "q_table": q_tab,
            "hybrid_metric": abs(q_tab - q_ref) / (abs(q_ref) + 1.0e-4 * ksat),
            "abs_error_over_ksatfit": abs(q_tab - q_ref) / ksat,
            "wrong_sign": int(abs(q_ref) > sign_threshold and q_ref * q_tab < 0.0),
            "near_zero_violation": int(abs(q_ref) <= sign_threshold and abs(q_tab) / ksat > NEAR_ZERO_TABLE_MAX),
            "equal_relative_error": abs(q_tab - q_ref) / max(abs(q_ref), 1.0e-300) if kind == "equal_head" else 0.0,
            "hydrostatic_abs_q_over_ksatfit": abs(q_tab) / ksat if kind == "hydrostatic" else 0.0,
        })
    hybrids = sorted(r["hybrid_metric"] for r in rows)
    p99 = hybrids[int(0.99 * (len(hybrids) - 1))] if hybrids else math.inf
    wet, ww, dw, wd = candidate_views(nwet, wet_high, ww_high, dw_high, wd_high)
    memory = int(ww.nbytes + dw.nbytes + wd.nbytes + np.linspace(0.0, 4.0, NU).nbytes + wet.nbytes)
    equal = [r["equal_relative_error"] for r in rows if r["kind"] == "equal_head"]
    hydro = [r["hydrostatic_abs_q_over_ksatfit"] for r in rows if r["kind"] == "hydrostatic"]
    result = {
        "nwet": nwet,
        "valid_probe_count": len(rows),
        "lookup_failures": lookup_failures,
        "nan_or_inf": nan_or_inf,
        "max_hybrid_metric": max(hybrids) if hybrids else math.inf,
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max((r["abs_error_over_ksatfit"] for r in rows), default=math.inf),
        "wrong_sign_count": sum(r["wrong_sign"] for r in rows),
        "near_zero_violation_count": sum(r["near_zero_violation"] for r in rows),
        "max_equal_head_relative_error": max(equal, default=0.0),
        "max_hydrostatic_abs_q_over_ksatfit": max(hydro, default=0.0),
        "minus1_boundary_node_logmobility_max_abs_difference": seam_diff,
        "incremental_shared_table_plus_axis_bytes": memory,
        "worst_probe": max(rows, key=lambda r: r["hybrid_metric"]) if rows else None,
    }
    tests = {
        "lookup_failures": lookup_failures == 0,
        "nan_or_inf": nan_or_inf == 0,
        "max_hybrid_metric": result["max_hybrid_metric"] <= HYBRID_MAX,
        "p99_hybrid_metric": p99 <= HYBRID_P99,
        "max_abs_error_over_ksatfit": result["max_abs_error_over_ksatfit"] <= ABS_KSAT_MAX,
        "wrong_sign_count": result["wrong_sign_count"] == 0,
        "near_zero_violation_count": result["near_zero_violation_count"] == 0,
        "max_equal_head_relative_error": result["max_equal_head_relative_error"] <= EQUAL_REL_MAX,
        "max_hydrostatic_abs_q_over_ksatfit": result["max_hydrostatic_abs_q_over_ksatfit"] <= HYDRO_MAX,
        "minus1_boundary_node_logmobility_max_abs_difference": seam_diff == 0.0,
        "incremental_shared_table_plus_axis_bytes": memory <= MEMORY_INCREMENT_MAX,
    }
    result["tests"] = tests
    result["pass"] = all(tests.values())
    result["failed_metrics"] = [k for k, ok in tests.items() if not ok]
    return result


def run_material(row: dict):
    configure(row)
    name = row["sfu"]
    probes = build_probes(name)
    dry_u, wet_h, ww, dw, wd, prep_seconds, generation_failures = generate_high_tables()
    base = {
        "material": name,
        "probe_count": len(probes),
        "preprocessing_seconds_descriptive": prep_seconds,
        "table_generation_failures": len(generation_failures),
        "generation_failure_examples": generation_failures[:8],
    }
    if generation_failures:
        base.update({"pass": False, "candidates": {}, "failure_class": "TABLE_GENERATION_FAILURE"})
        return base
    seam_diff = seam_node_difference(dry_u, ww, dw, wd)
    refs = [None] * len(probes)
    ref_errors = []
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        tasks = [(i, ha, hb) for i, (ha, hb, _) in enumerate(probes)]
        for idx, q, error in pool.imap_unordered(_safe_ref, tasks, chunksize=1):
            if error is None:
                refs[idx] = q
            else:
                ref_errors.append({"index": idx, "error": error})
    candidates = {}
    for nwet in (NW_LOW, NW_HIGH):
        cand = summarize_candidate(nwet, probes, refs, wet_h, ww, dw, wd, seam_diff)
        cand["reference_failures"] = len(ref_errors)
        if ref_errors:
            cand["pass"] = False
            cand["failed_metrics"] = sorted(set(cand["failed_metrics"] + ["reference_failures"]))
        candidates[str(nwet)] = cand
    base.update({
        "reference_failures": len(ref_errors),
        "reference_failure_examples": ref_errors[:8],
        "minus1_boundary_node_logmobility_max_abs_difference": seam_diff,
        "candidates": candidates,
        "pass": candidates[str(NW_HIGH)]["pass"],
    })
    return base


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e2a_near_saturation_face_characterization.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    results = []
    started = time.time()
    for i, name in enumerate(STRESS, 1):
        result = run_material(by_name[name])
        results.append(result)
        print(json.dumps({
            "progress": f"{i}/{len(STRESS)}",
            "material": name,
            "n17_pass": result.get("candidates", {}).get("17", {}).get("pass"),
            "n33_pass": result.get("candidates", {}).get("33", {}).get("pass"),
            "n17_failed": result.get("candidates", {}).get("17", {}).get("failed_metrics"),
            "n33_failed": result.get("candidates", {}).get("33", {}).get("failed_metrics"),
        }), flush=True)
    selected = None
    if all(r.get("candidates", {}).get("17", {}).get("pass", False) for r in results):
        selected = 17
    elif all(r.get("candidates", {}).get("33", {}).get("pass", False) for r in results):
        selected = 33
    max_metrics = {}
    for nwet in (17, 33):
        cs = [r.get("candidates", {}).get(str(nwet), {}) for r in results]
        max_metrics[str(nwet)] = {
            "pass_count": sum(bool(c.get("pass")) for c in cs),
            "max_hybrid_metric": max((c.get("max_hybrid_metric", math.inf) for c in cs), default=math.inf),
            "max_p99_hybrid_metric": max((c.get("p99_hybrid_metric", math.inf) for c in cs), default=math.inf),
            "max_abs_error_over_ksatfit": max((c.get("max_abs_error_over_ksatfit", math.inf) for c in cs), default=math.inf),
            "max_incremental_shared_table_plus_axis_bytes": max((c.get("incremental_shared_table_plus_axis_bytes", 0) for c in cs), default=0),
        }
    passed = selected is not None
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E2A_NEAR_SATURATION_FACE_CHARACTERIZATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "stress_materials": list(STRESS),
        "candidate_wet_node_counts": [17, 33],
        "selected_wet_node_count": selected,
        "max_metrics": max_metrics,
        "results": results,
        "elapsed_seconds_descriptive": time.time() - started,
        "pass": passed,
        "decision": (
            "NEAR_SATURATION_FACE_REPRESENTATION_CHARACTERIZED_READY_FOR_FRESH_E2B_HOLDOUT"
            if passed else
            "DIRECT_HEAD_NEAR_SATURATION_FACE_REPRESENTATION_REJECTED"
        ),
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k not in ("results",)}, sort_keys=True), flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
