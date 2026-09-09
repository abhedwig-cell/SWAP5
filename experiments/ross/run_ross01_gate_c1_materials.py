from __future__ import annotations

import hashlib
import json
import math
import multiprocessing as mp
import sys
import time
import warnings
from pathlib import Path

import numpy as np
from scipy.integrate import IntegrationWarning, quad
from scipy.optimize import brentq
from scipy.stats import qmc

N = 129
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
CATALOG_PATH = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")


def mpar(mat):
    return 1.0 - 1.0 / mat["n"]


def s_of_h(h: float, mat) -> float:
    if h >= 0.0:
        return 1.0
    m = mpar(mat)
    return (1.0 + abs(mat["alpha_per_cm"] * h) ** mat["n"]) ** (-m)


def h_of_s(s: float, mat) -> float:
    if s >= 1.0:
        return 0.0
    m = mpar(mat)
    return -((s ** (-1.0 / m) - 1.0) ** (1.0 / mat["n"])) / mat["alpha_per_cm"]


def k_of_h(h: float, mat) -> float:
    s = s_of_h(h, mat)
    ksat = mat["ksatfit_cm_per_day"]
    if s >= 1.0:
        return ksat
    m = mpar(mat)
    term = (1.0 - s ** (1.0 / m)) ** m
    return ksat * s ** mat["lambda"] * (1.0 - term) ** 2


def path_length_for_q(h_above: float, h_below: float, q: float, mat) -> float:
    dh = h_below - h_above
    power = 8

    def transformed(t: float) -> float:
        if t == 0.0:
            return 0.0
        tp = t**power
        h = h_above + dh * tp
        jac = dh * power * t ** (power - 1)
        k = k_of_h(h, mat)
        return jac * k / (k - q)

    with warnings.catch_warnings():
        warnings.simplefilter("ignore", IntegrationWarning)
        value, _ = quad(
            transformed,
            0.0,
            1.0,
            epsabs=2.0e-10,
            epsrel=2.0e-10,
            limit=120,
        )
    return value


def steady_q(h_above: float, h_below: float, mat) -> float:
    if abs(h_above - h_below) <= 2.0e-14 * max(1.0, abs(h_above), abs(h_below)):
        return k_of_h(0.5 * (h_above + h_below), mat)
    dh = h_below - h_above
    if abs(dh - LENGTH_CM) <= 2.0e-13 * max(1.0, LENGTH_CM, abs(dh)):
        return 0.0

    k_above = k_of_h(h_above, mat)
    ksat = mat["ksatfit_cm_per_day"]

    def residual(q: float) -> float:
        return path_length_for_q(h_above, h_below, q, mat) - LENGTH_CM

    if h_below > h_above:
        if dh < LENGTH_CM:
            lo = 0.0
            epsilon = 1.0e-5
            hi = k_above * (1.0 - epsilon)
            f_hi = residual(hi)
            while f_hi < 0.0 and epsilon > 2.0e-15:
                epsilon *= 0.1
                hi = k_above * (1.0 - epsilon)
                f_hi = residual(hi)
            if f_hi < 0.0:
                return k_above
        else:
            hi = 0.0
            lo = -max(ksat, 1.0)
            while residual(lo) > 0.0:
                lo *= 10.0
        return brentq(residual, lo, hi, xtol=2.0e-12, rtol=2.0e-12, maxiter=100)

    epsilon = 1.0e-8
    lo = k_above * (1.0 + epsilon)
    f_lo = residual(lo)
    while f_lo < 0.0 and epsilon > 2.0e-15:
        epsilon *= 0.1
        lo = k_above * (1.0 + epsilon)
        f_lo = residual(lo)
    hi = max(2.0 * k_above, ksat, 1.0)
    while residual(hi) > 0.0:
        hi *= 10.0
    if f_lo < 0.0:
        return k_above
    return brentq(residual, lo, hi, xtol=2.0e-12, rtol=2.0e-12, maxiter=100)


def hydro_mobility(h_above: float, mat) -> float:
    h_below = h_above + LENGTH_CM
    value, _ = quad(
        lambda h: 1.0 / k_of_h(h, mat),
        h_above,
        h_below,
        epsabs=2.0e-10,
        epsrel=2.0e-10,
        limit=100,
    )
    return 1.0 / value


def solve_node(task):
    mat, i, j, ua, ub = task
    h_above = -(10.0**ua)
    h_below = -(10.0**ub)
    driving = LENGTH_CM + h_above - h_below
    q = steady_q(h_above, h_below, mat)
    if abs(driving) <= 1.0e-10 and H_MIN <= h_above + LENGTH_CM <= H_MAX:
        mobility = hydro_mobility(h_above, mat)
    else:
        mobility = q / driving
    if not (mobility > 0.0 and math.isfinite(mobility)):
        raise RuntimeError(("invalid_mobility", mat["sfu"], h_above, h_below, q, driving, mobility))
    return i, j, math.log(mobility)


def solve_ref(task):
    mat, idx, sa, sb = task
    return idx, steady_q(h_of_s(sa, mat), h_of_s(sb, mat), mat)


def seed_for_material(code: str) -> int:
    digest = hashlib.sha256(("F-ROSS01-C1:" + code).encode("ascii")).hexdigest()
    return int(digest[:8], 16)


def build_probes(mat):
    s_min = s_of_h(H_MIN, mat)
    s_max = s_of_h(H_MAX, mat)
    probes = []
    seed = seed_for_material(mat["sfu"])
    ordinary = qmc.Sobol(d=2, scramble=True, seed=seed).random_base2(m=8)
    for a, b in ordinary:
        sa = s_min + (s_max - s_min) * float(a)
        sb = s_min + (s_max - s_min) * float(b)
        probes.append((float(sa), float(sb), "ordinary"))
    for h in -np.geomspace(1.0, 10000.0, 48):
        s = s_of_h(float(h), mat)
        probes.append((float(s), float(s), "equal_head"))
    for h_above in -np.geomspace(11.0, 10000.0, 48):
        h_below = float(h_above) + LENGTH_CM
        probes.append((s_of_h(float(h_above), mat), s_of_h(h_below, mat), "hydrostatic"))
    for h_above in -np.geomspace(21.0, 10000.0, 32):
        for epsilon in (-1.0, 1.0):
            h_below = float(h_above) + LENGTH_CM + epsilon
            probes.append((s_of_h(float(h_above), mat), s_of_h(h_below, mat), "near_hydrostatic"))
    fractions = (0.02, 0.1, 0.5, 0.9, 0.98)
    for a in fractions:
        for b in fractions:
            sa = s_min + (s_max - s_min) * a
            sb = s_min + (s_max - s_min) * b
            probes.append((float(sa), float(sb), "wet_dry_cross"))
    edge_heads = [
        (H_MIN, H_MIN),
        (H_MAX, H_MAX),
        (H_MIN, H_MAX),
        (H_MAX, H_MIN),
        (H_MIN, H_MIN + LENGTH_CM),
        (H_MAX - LENGTH_CM, H_MAX),
    ]
    for ha, hb in edge_heads:
        probes.append((s_of_h(ha, mat), s_of_h(hb, mat), "edge"))
    return probes, seed, s_min, s_max


def generate_full_table(mat):
    axis = np.linspace(0.0, 4.0, N)
    table = np.empty((N, N), dtype=np.float64)
    tasks = [(mat, i, j, float(axis[i]), float(axis[j])) for i in range(N) for j in range(N)]
    failures = []
    start = time.time()
    try:
        with mp.Pool(min(8, mp.cpu_count())) as pool:
            for i, j, log_mobility in pool.imap_unordered(solve_node, tasks, chunksize=4):
                table[i, j] = log_mobility
    except Exception as exc:
        failures.append(repr(exc))
    return axis, table, time.time() - start, failures


def lookup(sa, sb, axis, table, mat, s_min, s_max):
    if not (s_min <= sa <= s_max and s_min <= sb <= s_max):
        raise ValueError("state outside material S envelope")
    h_above = h_of_s(sa, mat)
    h_below = h_of_s(sb, mat)
    if not (H_MIN - 1.0e-8 <= h_above <= H_MAX + 1.0e-8):
        raise ValueError("upper head outside frozen envelope")
    if not (H_MIN - 1.0e-8 <= h_below <= H_MAX + 1.0e-8):
        raise ValueError("lower head outside frozen envelope")
    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return k_of_h(0.5 * (h_above + h_below), mat), h_above, h_below
    ua = math.log10(-h_above)
    ub = math.log10(-h_below)
    xa = (N - 1) * ua / 4.0
    xb = (N - 1) * ub / 4.0
    if not (-1.0e-12 <= xa <= N - 1 + 1.0e-12 and -1.0e-12 <= xb <= N - 1 + 1.0e-12):
        raise ValueError("lookup would extrapolate")
    xa = min(float(N - 1), max(0.0, xa))
    xb = min(float(N - 1), max(0.0, xb))
    ia = min(N - 2, max(0, int(math.floor(xa))))
    ib = min(N - 2, max(0, int(math.floor(xb))))
    fa = xa - ia
    fb = xb - ib
    log_mobility = (
        (1.0 - fa) * (1.0 - fb) * table[ia, ib]
        + fa * (1.0 - fb) * table[ia + 1, ib]
        + (1.0 - fa) * fb * table[ia, ib + 1]
        + fa * fb * table[ia + 1, ib + 1]
    )
    driving = LENGTH_CM + h_above - h_below
    return driving * math.exp(float(log_mobility)), h_above, h_below


def qualify_material(mat, out_dir: Path):
    probes, seed, s_min, s_max = build_probes(mat)
    axis, table, preprocessing_seconds, generation_failures = generate_full_table(mat)
    if generation_failures:
        result = {
            "schema_version": 1,
            "workstream": "F-ROSS",
            "work_unit": "F-ROSS01",
            "gate": "C1_STARINGREEKS_UNIMODAL_MVG_GENERALISATION",
            "material": mat["sfu"],
            "pass": False,
            "decision": "C1_MATERIAL_FAILED_TABLE_GENERATION",
            "generation_failures": generation_failures,
        }
        (out_dir / f"F-ROSS01_C1_{mat['sfu']}.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        return result

    refs = [0.0] * len(probes)
    tasks = [(mat, i, sa, sb) for i, (sa, sb, _) in enumerate(probes)]
    with mp.Pool(min(8, mp.cpu_count())) as pool:
        for idx, q in pool.imap_unordered(solve_ref, tasks, chunksize=1):
            refs[idx] = q

    rows = []
    lookup_failures = 0
    nan_or_inf = 0
    ksat = mat["ksatfit_cm_per_day"]
    sign_ref_threshold = 1.0e-8 * ksat
    for idx, (sa, sb, kind) in enumerate(probes):
        try:
            q_table, h_above, h_below = lookup(sa, sb, axis, table, mat, s_min, s_max)
        except Exception as exc:
            lookup_failures += 1
            rows.append({"kind": kind, "lookup_error": repr(exc)})
            continue
        q_ref = refs[idx]
        if not (math.isfinite(q_ref) and math.isfinite(q_table)):
            nan_or_inf += 1
        hybrid = abs(q_table - q_ref) / (abs(q_ref) + 1.0e-4 * ksat)
        abs_over = abs(q_table - q_ref) / ksat
        wrong_sign = int(abs(q_ref) > sign_ref_threshold and q_ref * q_table < 0.0)
        near_zero_violation = int(abs(q_ref) <= sign_ref_threshold and abs(q_table) / ksat > NEAR_ZERO_TABLE_MAX)
        rows.append({
            "kind": kind,
            "hybrid_metric": hybrid,
            "abs_error_over_ksatfit": abs_over,
            "wrong_sign": wrong_sign,
            "near_zero_violation": near_zero_violation,
            "equal_relative_error": abs(q_table - q_ref) / max(abs(q_ref), 1.0e-300) if kind == "equal_head" else 0.0,
            "hydrostatic_abs_q_over_ksatfit": abs(q_table) / ksat if kind == "hydrostatic" else 0.0,
            "h_above": h_above,
            "h_below": h_below,
            "q_ref": q_ref,
            "q_table": q_table,
        })

    valid = [r for r in rows if "hybrid_metric" in r]
    hybrid_sorted = sorted(r["hybrid_metric"] for r in valid)
    p99 = hybrid_sorted[int(0.99 * (len(hybrid_sorted) - 1))]
    equal = [r["equal_relative_error"] for r in valid if r["kind"] == "equal_head"]
    hydro = [r["hydrostatic_abs_q_over_ksatfit"] for r in valid if r["kind"] == "hydrostatic"]
    observed = {
        "probe_count": len(probes),
        "ordinary_count": sum(1 for _, _, k in probes if k == "ordinary"),
        "seed": seed,
        "max_hybrid_metric": max(r["hybrid_metric"] for r in valid),
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max(r["abs_error_over_ksatfit"] for r in valid),
        "wrong_sign_count": sum(r["wrong_sign"] for r in valid),
        "near_zero_violation_count": sum(r["near_zero_violation"] for r in valid),
        "max_equal_head_relative_error": max(equal),
        "max_hydrostatic_abs_q_over_ksatfit": max(hydro),
        "lookup_failures": lookup_failures,
        "nan_or_inf": nan_or_inf,
        "full_table_entries": int(table.size),
        "full_table_generation_failures": len(generation_failures),
        "shared_table_plus_axis_bytes": int(table.nbytes + axis.nbytes),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256_float64_c_order": hashlib.sha256(table.tobytes(order="C")).hexdigest(),
    }
    passed = (
        observed["max_hybrid_metric"] <= HYBRID_MAX
        and observed["p99_hybrid_metric"] <= HYBRID_P99
        and observed["max_abs_error_over_ksatfit"] <= ABS_KSAT_MAX
        and observed["wrong_sign_count"] == 0
        and observed["near_zero_violation_count"] == 0
        and observed["max_equal_head_relative_error"] <= EQUAL_REL_MAX
        and observed["max_hydrostatic_abs_q_over_ksatfit"] <= HYDRO_MAX
        and observed["lookup_failures"] == 0
        and observed["nan_or_inf"] == 0
        and observed["full_table_entries"] == N * N
        and observed["full_table_generation_failures"] == 0
        and observed["shared_table_plus_axis_bytes"] <= MEMORY_MAX
    )
    worst = max(valid, key=lambda r: r["hybrid_metric"])
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C1_STARINGREEKS_UNIMODAL_MVG_GENERALISATION",
        "material": mat["sfu"],
        "material_parameters": mat,
        "candidate": "V2_LOG_HEAD_LOG_MOBILITY_WITH_EXACT_EQUAL_HEAD_N129",
        "fixture": "NO_KSATEXM_L10_H_-10000_-1",
        "observed": observed,
        "worst_hybrid_probe": worst,
        "pass": passed,
        "decision": "C1_MATERIAL_PASS" if passed else "C1_MATERIAL_FAIL",
        "scope_limit": "Unimodal Mualem-van Genuchten using KSATFIT only; KSATEXM and other hydraulic families remain outside C1.",
    }
    (out_dir / f"F-ROSS01_C1_{mat['sfu']}.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c1_materials.py OUTPUT_DIR MATERIAL1,MATERIAL2,...")
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    requested = [x.strip() for x in sys.argv[2].split(",") if x.strip()]
    catalog = json.loads(CATALOG_PATH.read_text())
    by_code = {row["sfu"]: row for row in catalog["rows"]}
    missing = [code for code in requested if code not in by_code]
    if missing:
        raise SystemExit(f"unknown materials: {missing}")
    results = []
    for code in requested:
        result = qualify_material(by_code[code], out_dir)
        results.append(result)
        print(json.dumps({"material": code, "pass": result["pass"], "decision": result["decision"], "observed": result.get("observed")}, sort_keys=True))
    passed = all(r["pass"] for r in results)
    summary = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C1_STARINGREEKS_UNIMODAL_MVG_GENERALISATION",
        "materials": requested,
        "material_count": len(results),
        "pass_count": sum(1 for r in results if r["pass"]),
        "fail_count": sum(1 for r in results if not r["pass"]),
        "failed_materials": [r["material"] for r in results if not r["pass"]],
        "pass": passed,
        "decision": "C1_GROUP_PASS" if passed else "C1_GROUP_FAIL",
    }
    (out_dir / "F-ROSS01_C1_GROUP_SUMMARY.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, indent=2, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
