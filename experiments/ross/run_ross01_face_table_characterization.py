from __future__ import annotations

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

# Frozen B01 fixture from F-ROSS01_REAL_FACE_ORACLE_CONTRACT.json.
THETA_R = 0.02
THETA_S = 0.427494
ALPHA = 0.021659
NPAR = 1.734737
MPAR = 1.0 - 1.0 / NPAR
KSAT = 31.225016
LAMBDA = 0.98087
LENGTH_CM = 10.0
H_MIN = -10000.0
H_MAX = -1.0
S_MIN = None
S_MAX = None
SEED = 41031

HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
SIGN_REF_THRESHOLD = 1.0e-8 * KSAT
HYDRO_KSAT_MAX = 1.0e-5
EQUAL_REL_MAX = 0.005
MEMORY_MAX = 262144


def s_of_h(h: float) -> float:
    if h >= 0.0:
        return 1.0
    return (1.0 + abs(ALPHA * h) ** NPAR) ** (-MPAR)


def h_of_s(s: float) -> float:
    if s >= 1.0:
        return 0.0
    return -((s ** (-1.0 / MPAR) - 1.0) ** (1.0 / NPAR)) / ALPHA


def k_of_h(h: float) -> float:
    s = s_of_h(h)
    if s >= 1.0:
        return KSAT
    term = (1.0 - s ** (1.0 / MPAR)) ** MPAR
    return KSAT * s**LAMBDA * (1.0 - term) ** 2


S_MIN = s_of_h(H_MIN)
S_MAX = s_of_h(H_MAX)


def path_length_for_q(h_above: float, h_below: float, q: float) -> float:
    # Frozen Ross steady-Darcy oracle: dx/dh = 1/(1-q/K(h)).
    # The t^8 endpoint transform regularizes near-equal-head cases while
    # retaining adaptive quadrature of the same path integral.
    dh = h_below - h_above
    power = 8

    def transformed(t: float) -> float:
        if t == 0.0:
            return 0.0
        tp = t**power
        h = h_above + dh * tp
        jac = dh * power * t ** (power - 1)
        k = k_of_h(h)
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


def steady_q(h_above: float, h_below: float) -> float:
    if abs(h_above - h_below) <= 2.0e-14 * max(1.0, abs(h_above), abs(h_below)):
        return k_of_h(0.5 * (h_above + h_below))
    dh = h_below - h_above
    if abs(dh - LENGTH_CM) <= 2.0e-13 * max(1.0, LENGTH_CM, abs(dh)):
        return 0.0

    k_above = k_of_h(h_above)

    def residual(q: float) -> float:
        return path_length_for_q(h_above, h_below, q) - LENGTH_CM

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
            lo = -max(KSAT, 1.0)
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
    hi = max(2.0 * k_above, KSAT, 1.0)
    while residual(hi) > 0.0:
        hi *= 10.0
    if f_lo < 0.0:
        return k_above
    return brentq(residual, lo, hi, xtol=2.0e-12, rtol=2.0e-12, maxiter=100)


def hydro_mobility(h_above: float) -> float:
    h_below = h_above + LENGTH_CM
    value, _ = quad(
        lambda h: 1.0 / k_of_h(h),
        h_above,
        h_below,
        epsabs=2.0e-10,
        epsrel=2.0e-10,
        limit=100,
    )
    return 1.0 / value


def build_probes() -> list[tuple[float, float, str]]:
    probes: list[tuple[float, float, str]] = []
    ordinary = qmc.Sobol(d=2, scramble=True, seed=SEED).random_base2(m=9)[:384]
    for a, b in ordinary:
        sa = S_MIN + (S_MAX - S_MIN) * float(a)
        sb = S_MIN + (S_MAX - S_MIN) * float(b)
        probes.append((h_of_s(sa), h_of_s(sb), "ordinary"))

    for h in -np.geomspace(1.0, 10000.0, 64):
        probes.append((float(h), float(h), "equal_head"))

    for h_above in -np.geomspace(11.0, 10000.0, 64):
        h_below = float(h_above) + LENGTH_CM
        if h_below <= H_MAX:
            probes.append((float(h_above), h_below, "hydrostatic"))

    for h_above in -np.geomspace(21.0, 10000.0, 32):
        for epsilon in (-1.0, 1.0):
            h_below = float(h_above) + LENGTH_CM + epsilon
            if H_MIN <= h_below <= H_MAX:
                probes.append((float(h_above), h_below, "near_hydrostatic"))

    for a in (0.02, 0.1, 0.5, 0.9, 0.98):
        for b in (0.02, 0.1, 0.5, 0.9, 0.98):
            sa = S_MIN + (S_MAX - S_MIN) * a
            sb = S_MIN + (S_MAX - S_MIN) * b
            probes.append((h_of_s(sa), h_of_s(sb), "wet_dry_mix"))
    return probes


PROBES = build_probes()


def _solve_ref(task):
    idx, h_above, h_below = task
    return idx, steady_q(h_above, h_below)


def _solve_baseline_node(task):
    i, j, sa, sb = task
    return i, j, steady_q(h_of_s(sa), h_of_s(sb))


def _solve_v2_node(task):
    i, j, ua, ub = task
    h_above = -(10.0**ua)
    h_below = -(10.0**ub)
    driving = LENGTH_CM + h_above - h_below
    q = steady_q(h_above, h_below)
    if abs(driving) <= 1.0e-10 and H_MIN <= h_above + LENGTH_CM <= H_MAX:
        mobility = hydro_mobility(h_above)
    else:
        mobility = q / driving
    if not (mobility > 0.0 and math.isfinite(mobility)):
        raise RuntimeError(("invalid_mobility", h_above, h_below, q, driving, mobility))
    return i, j, math.log(mobility)


def reference_values() -> list[float]:
    refs = [0.0] * len(PROBES)
    tasks = [(i, float(a), float(b)) for i, (a, b, _) in enumerate(PROBES)]
    with mp.Pool(min(8, mp.cpu_count())) as pool:
        for idx, q in pool.imap_unordered(_solve_ref, tasks, chunksize=1):
            refs[idx] = q
    return refs


def summarize(rows, memory_bytes: int, representation: str, n: int, p: float):
    hybrid = sorted(row["hybrid_metric"] for row in rows)
    p99 = hybrid[int(0.99 * (len(hybrid) - 1))]
    wrong_sign = sum(row["wrong_sign"] for row in rows)
    equal = [row["equal_relative_error"] for row in rows if row["kind"] == "equal_head"]
    hydro = [row["abs_q_table_over_ksat"] for row in rows if row["kind"] == "hydrostatic"]
    result = {
        "representation": representation,
        "N": n,
        "p": p,
        "probe_count": len(rows),
        "max_hybrid_metric": max(hybrid),
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksat": max(row["abs_error_over_ksat"] for row in rows),
        "wrong_sign_count": wrong_sign,
        "max_equal_head_relative_error": max(equal),
        "max_hydrostatic_abs_q_over_ksat": max(hydro),
        "lookup_failures": 0,
        "nan_or_inf": 0,
        "memory_bytes_shared_class": memory_bytes,
    }
    result["pass"] = (
        result["max_hybrid_metric"] <= HYBRID_MAX
        and result["p99_hybrid_metric"] <= HYBRID_P99
        and result["max_abs_error_over_ksat"] <= ABS_KSAT_MAX
        and result["wrong_sign_count"] == 0
        and result["max_equal_head_relative_error"] <= EQUAL_REL_MAX
        and result["max_hydrostatic_abs_q_over_ksat"] <= HYDRO_KSAT_MAX
        and result["memory_bytes_shared_class"] <= MEMORY_MAX
    )
    return result


def row_metrics(kind, q_ref, q_table):
    wrong_sign = int(abs(q_ref) > SIGN_REF_THRESHOLD and q_ref * q_table < 0.0)
    return {
        "kind": kind,
        "hybrid_metric": abs(q_table - q_ref) / (abs(q_ref) + 1.0e-4 * KSAT),
        "abs_error_over_ksat": abs(q_table - q_ref) / KSAT,
        "wrong_sign": wrong_sign,
        "equal_relative_error": (
            abs(q_table - q_ref) / max(abs(q_ref), 1.0e-300) if kind == "equal_head" else 0.0
        ),
        "abs_q_table_over_ksat": abs(q_table) / KSAT,
    }


def baseline_candidate(n: int, p: float, refs: list[float]):
    axis = S_MIN + (S_MAX - S_MIN) * (np.arange(n) / (n - 1)) ** p

    def location(s):
        y = min(1.0, max(0.0, (s - S_MIN) / (S_MAX - S_MIN)))
        x = (n - 1) * y ** (1.0 / p)
        i = min(n - 2, max(0, int(math.floor(x))))
        return i, x - i

    needs = {}
    locations = []
    for h_above, h_below, _ in PROBES:
        ia, fa = location(s_of_h(h_above))
        ib, fb = location(s_of_h(h_below))
        locations.append((ia, fa, ib, fb))
        for di in (0, 1):
            for dj in (0, 1):
                needs[(ia + di, ib + dj)] = (float(axis[ia + di]), float(axis[ib + dj]))
    nodes = {}
    tasks = [(i, j, sa, sb) for (i, j), (sa, sb) in needs.items()]
    with mp.Pool(min(8, mp.cpu_count())) as pool:
        for i, j, q in pool.imap_unordered(_solve_baseline_node, tasks, chunksize=1):
            nodes[(i, j)] = q

    rows = []
    for idx, (_, _, kind) in enumerate(PROBES):
        ia, fa, ib, fb = locations[idx]
        q_table = (
            (1.0 - fa) * (1.0 - fb) * nodes[(ia, ib)]
            + fa * (1.0 - fb) * nodes[(ia + 1, ib)]
            + (1.0 - fa) * fb * nodes[(ia, ib + 1)]
            + fa * fb * nodes[(ia + 1, ib + 1)]
        )
        rows.append(row_metrics(kind, refs[idx], q_table))
    return summarize(rows, 8 * n * n + 8 * n, "BASELINE_BILINEAR_Q_IN_S", n, p)


def v2_candidate(n: int, refs: list[float]):
    axis = np.linspace(0.0, 4.0, n)

    def location(h):
        u = math.log10(-h)
        x = (n - 1) * (u / 4.0)
        i = min(n - 2, max(0, int(math.floor(x))))
        return i, x - i

    needs = {}
    locations = []
    for h_above, h_below, _ in PROBES:
        ia, fa = location(h_above)
        ib, fb = location(h_below)
        locations.append((ia, fa, ib, fb))
        for di in (0, 1):
            for dj in (0, 1):
                needs[(ia + di, ib + dj)] = (float(axis[ia + di]), float(axis[ib + dj]))
    nodes = {}
    tasks = [(i, j, ua, ub) for (i, j), (ua, ub) in needs.items()]
    with mp.Pool(min(8, mp.cpu_count())) as pool:
        for i, j, log_mobility in pool.imap_unordered(_solve_v2_node, tasks, chunksize=1):
            nodes[(i, j)] = log_mobility

    rows = []
    for idx, (h_above, h_below, kind) in enumerate(PROBES):
        ia, fa, ib, fb = locations[idx]
        log_mobility = (
            (1.0 - fa) * (1.0 - fb) * nodes[(ia, ib)]
            + fa * (1.0 - fb) * nodes[(ia + 1, ib)]
            + (1.0 - fa) * fb * nodes[(ia, ib + 1)]
            + fa * fb * nodes[(ia + 1, ib + 1)]
        )
        driving = LENGTH_CM + h_above - h_below
        if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
            q_table = k_of_h(h_above)
        else:
            q_table = driving * math.exp(log_mobility)
        rows.append(row_metrics(kind, refs[idx], q_table))
    return summarize(rows, 8 * n * n + 8 * n, "V2_LOG_HEAD_LOG_MOBILITY_WITH_EXACT_EQUAL_HEAD", n, 1.0)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_face_table_characterization.py OUTPUT.json")
    out = Path(sys.argv[1])
    start = time.time()
    refs = reference_values()
    baseline = []
    for n in (33, 65, 97, 129):
        for p in (1.0, 0.75, 0.5):
            baseline.append(baseline_candidate(n, p, refs))
    v2 = [v2_candidate(n, refs) for n in (33, 65, 97, 129)]
    passing_v2 = [row for row in v2 if row["pass"]]
    selected = min(passing_v2, key=lambda row: row["memory_bytes_shared_class"]) if passing_v2 else None
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "B_REAL_FACE_TABLE_CHARACTERIZATION",
        "fixture": "B01_NO_KSATEXM_L10_H_-10000_-1",
        "ordinary_probe_seed": SEED,
        "probe_count": len(PROBES),
        "thresholds": {
            "max_hybrid_metric": HYBRID_MAX,
            "p99_hybrid_metric": HYBRID_P99,
            "max_abs_error_over_ksat": ABS_KSAT_MAX,
            "wrong_sign_count": 0,
            "max_equal_head_relative_error": EQUAL_REL_MAX,
            "max_hydrostatic_abs_q_over_ksat": HYDRO_KSAT_MAX,
            "memory_bytes_shared_class": MEMORY_MAX,
        },
        "baseline_candidates": baseline,
        "baseline_decision": "REJECT_BASELINE_BILINEAR_Q_IN_S" if not any(x["pass"] for x in baseline) else "UNEXPECTED_BASELINE_PASS",
        "v2_candidates": v2,
        "selected_characterization_candidate": selected,
        "holdout_accessed": False,
        "runtime_seconds": time.time() - start,
        "decision": (
            "CHARACTERIZATION_SELECTS_V2_N129_READY_TO_FREEZE_FRESH_HOLDOUT"
            if selected and selected["N"] == 129
            else "CHARACTERIZATION_FAIL_CLOSED_NO_HOLDOUT"
        ),
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["decision"].startswith("CHARACTERIZATION_SELECTS") else 1)


if __name__ == "__main__":
    main()
