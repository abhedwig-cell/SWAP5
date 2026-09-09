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

import run_ross01_gate_c1 as c1

STRESS_MATERIALS = ("O01", "O05", "O14", "B01", "B12", "O13")
CATALOG_PATH = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
LENGTH_CM = 10.0
H_MIN = -10000.0
H_MAX = -1.0
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
NEAR_ZERO_TABLE_MAX = 1.0e-6
EQUAL_REL_MAX = 0.005
HYDRO_MAX = 1.0e-5
MEMORY_MAX = 262144
FIXED_METADATA_BYTES = 32
CTX = mp.get_context("fork")


def seed_for_material(name: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-C1R-CHAR:" + name).encode()).hexdigest()[:8], 16)


def state_pair_from_heads(h_above: float, h_below: float):
    return float(c1.core.s_of_h(h_above)), float(c1.core.s_of_h(h_below))


def build_probes(name: str):
    probes = []
    ordinary = qmc.Sobol(d=2, scramble=True, seed=seed_for_material(name)).random_base2(m=9)
    for a, b in ordinary:
        sa = c1.core.S_MIN + (c1.core.S_MAX - c1.core.S_MIN) * float(a)
        sb = c1.core.S_MIN + (c1.core.S_MAX - c1.core.S_MIN) * float(b)
        probes.append((float(sa), float(sb), "ordinary"))
    for h in -np.geomspace(1.0, 10000.0, 64):
        probes.append((*state_pair_from_heads(float(h), float(h)), "equal_head"))
    for h_above in -np.geomspace(11.0, 10000.0, 64):
        h_below = float(h_above) + LENGTH_CM
        probes.append((*state_pair_from_heads(float(h_above), h_below), "hydrostatic"))
    for h_above in -np.geomspace(21.0, 10000.0, 48):
        for epsilon in (-1.0, 1.0):
            h_below = float(h_above) + LENGTH_CM + epsilon
            probes.append((*state_pair_from_heads(float(h_above), h_below), "near_hydrostatic"))
    for a in (0.01, 0.03, 0.1, 0.5, 0.9, 0.97, 0.99):
        for b in (0.01, 0.03, 0.1, 0.5, 0.9, 0.97, 0.99):
            sa = c1.core.S_MIN + (c1.core.S_MAX - c1.core.S_MIN) * a
            sb = c1.core.S_MIN + (c1.core.S_MAX - c1.core.S_MIN) * b
            probes.append((float(sa), float(sb), "wet_dry_cross"))
    for ha, hb in (
        (H_MIN, H_MIN), (H_MAX, H_MAX), (H_MIN, H_MAX), (H_MAX, H_MIN),
        (H_MIN, H_MIN + LENGTH_CM), (H_MAX - LENGTH_CM, H_MAX),
    ):
        probes.append((*state_pair_from_heads(ha, hb), "edge"))
    return probes


def _safe_node(task):
    try:
        i, j, value = c1.core._solve_v2_node(task)
        return i, j, value, None
    except Exception as exc:
        i, j, _, _ = task
        return i, j, None, repr(exc)


def generate_table(n: int):
    table = np.full((n, n), np.nan, dtype=np.float32)
    tasks = [(i, j, 4.0 * i / (n - 1), 4.0 * j / (n - 1)) for i in range(n) for j in range(n)]
    failures = []
    started = time.time()
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for i, j, value, error in pool.imap_unordered(_safe_node, tasks, chunksize=4):
            if error is None:
                table[i, j] = np.float32(value)
            else:
                failures.append({"i": i, "j": j, "error": error})
    return table, time.time() - started, failures


def endpoint_roundoff_clamp(h: float) -> float:
    tol = 1.0e-10 * max(1.0, abs(h), abs(H_MIN), abs(H_MAX))
    if h > H_MAX and h - H_MAX <= tol:
        return H_MAX
    if h < H_MIN and H_MIN - h <= tol:
        return H_MIN
    return h


def lookup(sa: float, sb: float, table: np.ndarray, n: int):
    s_tol = 64.0 * np.finfo(float).eps
    if not (c1.core.S_MIN - s_tol <= sa <= c1.core.S_MAX + s_tol and c1.core.S_MIN - s_tol <= sb <= c1.core.S_MAX + s_tol):
        raise ValueError("state outside material S envelope")
    sa = min(c1.core.S_MAX, max(c1.core.S_MIN, sa))
    sb = min(c1.core.S_MAX, max(c1.core.S_MIN, sb))
    h_above = endpoint_roundoff_clamp(c1.core.h_of_s(sa))
    h_below = endpoint_roundoff_clamp(c1.core.h_of_s(sb))
    if not (H_MIN <= h_above <= H_MAX and H_MIN <= h_below <= H_MAX):
        raise ValueError("head outside frozen envelope after roundoff check")
    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return c1.core.k_of_h(0.5 * (h_above + h_below)), h_above, h_below
    ua = math.log10(-h_above)
    ub = math.log10(-h_below)
    xa = (n - 1) * ua / 4.0
    xb = (n - 1) * ub / 4.0
    coord_tol = 1.0e-10 * max(1.0, n - 1)
    if not (-coord_tol <= xa <= n - 1 + coord_tol and -coord_tol <= xb <= n - 1 + coord_tol):
        raise ValueError("lookup would extrapolate")
    xa = min(n - 1.0, max(0.0, xa))
    xb = min(n - 1.0, max(0.0, xb))
    ia = min(n - 2, max(0, int(math.floor(xa))))
    ib = min(n - 2, max(0, int(math.floor(xb))))
    fa = xa - ia
    fb = xb - ib
    q00 = float(table[ia, ib])
    q10 = float(table[ia + 1, ib])
    q01 = float(table[ia, ib + 1])
    q11 = float(table[ia + 1, ib + 1])
    log_mobility = (
        (1.0 - fa) * (1.0 - fb) * q00
        + fa * (1.0 - fb) * q10
        + (1.0 - fa) * fb * q01
        + fa * fb * q11
    )
    driving = LENGTH_CM + h_above - h_below
    return driving * math.exp(log_mobility), h_above, h_below


def _safe_ref(task):
    idx, sa, sb = task
    try:
        return idx, c1.core.steady_q(c1.core.h_of_s(sa), c1.core.h_of_s(sb)), None
    except Exception as exc:
        return idx, None, repr(exc)


def run_material(row, n: int):
    c1.configure_core(row)
    name = row["sfu"]
    ksat = c1.core.KSAT
    probes = build_probes(name)
    table, preprocessing_seconds, generation_failures = generate_table(n)
    shared_bytes = int(table.nbytes + FIXED_METADATA_BYTES)
    if generation_failures:
        return {"material": name, "pass": False, "failed_metrics": ["full_table_generation_failures"], "full_table_generation_failures": len(generation_failures)}

    refs = [None] * len(probes)
    ref_failures = 0
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for idx, q, error in pool.imap_unordered(_safe_ref, [(i, sa, sb) for i, (sa, sb, _) in enumerate(probes)], chunksize=1):
            if error is None:
                refs[idx] = q
            else:
                ref_failures += 1

    rows = []
    lookup_failures = 0
    nan_or_inf = 0
    sign_threshold = 1.0e-8 * ksat
    for idx, (sa, sb, kind) in enumerate(probes):
        if refs[idx] is None:
            continue
        try:
            q_table, h_above, h_below = lookup(sa, sb, table, n)
        except Exception:
            lookup_failures += 1
            continue
        q_ref = refs[idx]
        if not (math.isfinite(q_ref) and math.isfinite(q_table)):
            nan_or_inf += 1
            continue
        rows.append({
            "kind": kind,
            "hybrid_metric": abs(q_table - q_ref) / (abs(q_ref) + 1.0e-4 * ksat),
            "abs_error_over_ksatfit": abs(q_table - q_ref) / ksat,
            "wrong_sign": int(abs(q_ref) > sign_threshold and q_ref * q_table < 0.0),
            "near_zero_violation": int(abs(q_ref) <= sign_threshold and abs(q_table) / ksat > NEAR_ZERO_TABLE_MAX),
            "equal_relative_error": abs(q_table - q_ref) / max(abs(q_ref), 1.0e-300) if kind == "equal_head" else 0.0,
            "hydrostatic_abs_q_over_ksatfit": abs(q_table) / ksat if kind == "hydrostatic" else 0.0,
            "h_above": h_above, "h_below": h_below, "q_ref": q_ref, "q_table": q_table,
        })
    hybrids = sorted(r["hybrid_metric"] for r in rows)
    p99 = hybrids[int(0.99 * (len(hybrids) - 1))]
    equal = [r["equal_relative_error"] for r in rows if r["kind"] == "equal_head"]
    hydro = [r["hydrostatic_abs_q_over_ksatfit"] for r in rows if r["kind"] == "hydrostatic"]
    observed = {
        "material": name,
        "seed": seed_for_material(name),
        "probe_count": len(probes),
        "valid_probe_count": len(rows),
        "reference_failures": ref_failures,
        "lookup_failures": lookup_failures,
        "nan_or_inf": nan_or_inf,
        "full_table_entries": int(table.size),
        "full_table_generation_failures": 0,
        "shared_table_plus_metadata_bytes": shared_bytes,
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "max_hybrid_metric": max(hybrids),
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max(r["abs_error_over_ksatfit"] for r in rows),
        "wrong_sign_count": sum(r["wrong_sign"] for r in rows),
        "near_zero_violation_count": sum(r["near_zero_violation"] for r in rows),
        "max_equal_head_relative_error": max(equal),
        "max_hydrostatic_abs_q_over_ksatfit": max(hydro),
        "table_sha256_float32_c_order": hashlib.sha256(table.tobytes(order="C")).hexdigest(),
        "worst_hybrid_probe": max(rows, key=lambda r: r["hybrid_metric"]),
        "worst_abs_probe": max(rows, key=lambda r: r["abs_error_over_ksatfit"]),
    }
    tests = {
        "reference_failures": observed["reference_failures"] == 0,
        "lookup_failures": observed["lookup_failures"] == 0,
        "nan_or_inf": observed["nan_or_inf"] == 0,
        "full_table_generation_failures": observed["full_table_generation_failures"] == 0,
        "max_hybrid_metric": observed["max_hybrid_metric"] <= HYBRID_MAX,
        "p99_hybrid_metric": observed["p99_hybrid_metric"] <= HYBRID_P99,
        "max_abs_error_over_ksatfit": observed["max_abs_error_over_ksatfit"] <= ABS_KSAT_MAX,
        "wrong_sign_count": observed["wrong_sign_count"] == 0,
        "near_zero_violation_count": observed["near_zero_violation_count"] == 0,
        "max_equal_head_relative_error": observed["max_equal_head_relative_error"] <= EQUAL_REL_MAX,
        "max_hydrostatic_abs_q_over_ksatfit": observed["max_hydrostatic_abs_q_over_ksatfit"] <= HYDRO_MAX,
        "shared_table_plus_metadata_bytes": observed["shared_table_plus_metadata_bytes"] <= MEMORY_MAX,
    }
    observed["failed_metrics"] = [key for key, ok in tests.items() if not ok]
    observed["pass"] = all(tests.values())
    return observed


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c1r_characterization.py N OUTPUT.json")
    n = int(sys.argv[1])
    out = Path(sys.argv[2])
    if n not in (225, 241, 255):
        raise SystemExit("N must be one of 225,241,255")
    catalog = json.loads(CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    results = []
    for index, name in enumerate(STRESS_MATERIALS, 1):
        result = run_material(by_name[name], n)
        results.append(result)
        print(json.dumps({"progress": f"{index}/{len(STRESS_MATERIALS)}", "N": n, "material": name, "pass": result["pass"], "failed_metrics": result.get("failed_metrics", [])}), flush=True)
    passed = all(r["pass"] for r in results)
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C1R_BOUNDED_DENSE_TABLE_REFINEMENT_CHARACTERIZATION",
        "candidate": {"N": n, "storage": "float32_log_mobility", "axis": "analytic_uniform_log10_negative_head", "shared_table_plus_metadata_bytes": 4*n*n + FIXED_METADATA_BYTES},
        "stress_materials": list(STRESS_MATERIALS),
        "material_results": results,
        "pass": passed,
        "decision": "C1R_CHARACTERIZATION_CANDIDATE_PASS" if passed else "C1R_CHARACTERIZATION_CANDIDATE_FAIL",
        "scope_limit": "Characterization only. No 36-material qualification claim and no holdout access."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"N": n, "pass": passed, "failed_materials": [r["material"] for r in results if not r["pass"]]}, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
