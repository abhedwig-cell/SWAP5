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

import run_ross01_face_table_characterization as core

N = 129
SEED = 88421
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
SIGN_REF_THRESHOLD = 1.0e-8 * core.KSAT
NEAR_ZERO_TABLE_MAX = 1.0e-6
EQUAL_REL_MAX = 0.005
HYDRO_MAX = 1.0e-5
MEMORY_MAX = 262144


def state_pair_from_heads(h_above: float, h_below: float):
    s_above = core.s_of_h(h_above)
    s_below = core.s_of_h(h_below)
    return float(s_above), float(s_below)


def build_holdout():
    probes = []
    ordinary = qmc.Sobol(d=2, scramble=True, seed=SEED).random_base2(m=10)
    for a, b in ordinary:
        sa = core.S_MIN + (core.S_MAX - core.S_MIN) * float(a)
        sb = core.S_MIN + (core.S_MAX - core.S_MIN) * float(b)
        probes.append((float(sa), float(sb), "ordinary"))
    for h in -np.geomspace(1.0, 10000.0, 96):
        sa, sb = state_pair_from_heads(float(h), float(h))
        probes.append((sa, sb, "equal_head"))
    for h_above in -np.geomspace(11.0, 10000.0, 96):
        h_below = float(h_above) + core.LENGTH_CM
        sa, sb = state_pair_from_heads(float(h_above), h_below)
        probes.append((sa, sb, "hydrostatic"))
    for h_above in -np.geomspace(21.0, 10000.0, 64):
        for epsilon in (-1.0, 1.0):
            h_below = float(h_above) + core.LENGTH_CM + epsilon
            sa, sb = state_pair_from_heads(float(h_above), h_below)
            probes.append((sa, sb, "near_hydrostatic"))
    fractions = (0.01, 0.03, 0.1, 0.5, 0.9, 0.97, 0.99)
    for a in fractions:
        for b in fractions:
            sa = core.S_MIN + (core.S_MAX - core.S_MIN) * a
            sb = core.S_MIN + (core.S_MAX - core.S_MIN) * b
            probes.append((float(sa), float(sb), "wet_dry_cross"))
    edge_heads = [
        (core.H_MIN, core.H_MIN),
        (core.H_MAX, core.H_MAX),
        (core.H_MIN, core.H_MAX),
        (core.H_MAX, core.H_MIN),
        (core.H_MIN, core.H_MIN + core.LENGTH_CM),
        (core.H_MAX - core.LENGTH_CM, core.H_MAX),
    ]
    for ha, hb in edge_heads:
        sa, sb = state_pair_from_heads(ha, hb)
        probes.append((sa, sb, "edge"))
    return probes


def generate_full_table():
    axis = np.linspace(0.0, 4.0, N)
    table = np.empty((N, N), dtype=np.float64)
    tasks = [(i, j, float(axis[i]), float(axis[j])) for i in range(N) for j in range(N)]
    start = time.time()
    failures = []
    try:
        with mp.Pool(min(8, mp.cpu_count())) as pool:
            for i, j, log_mobility in pool.imap_unordered(core._solve_v2_node, tasks, chunksize=4):
                table[i, j] = log_mobility
    except Exception as exc:
        failures.append(repr(exc))
    return axis, table, time.time() - start, failures


def lookup(sa: float, sb: float, axis: np.ndarray, table: np.ndarray):
    if not (core.S_MIN <= sa <= core.S_MAX and core.S_MIN <= sb <= core.S_MAX):
        raise ValueError("state outside frozen S envelope")
    h_above = core.h_of_s(sa)
    h_below = core.h_of_s(sb)
    if not (core.H_MIN - 1.0e-8 <= h_above <= core.H_MAX + 1.0e-8):
        raise ValueError("upper head outside frozen envelope")
    if not (core.H_MIN - 1.0e-8 <= h_below <= core.H_MAX + 1.0e-8):
        raise ValueError("lower head outside frozen envelope")
    if sa == sb:
        return core.k_of_h(h_above), h_above, h_below
    ua = math.log10(-h_above)
    ub = math.log10(-h_below)
    xa = (N - 1) * ua / 4.0
    xb = (N - 1) * ub / 4.0
    if not (0.0 <= xa <= N - 1 and 0.0 <= xb <= N - 1):
        raise ValueError("lookup would extrapolate")
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
    driving = core.LENGTH_CM + h_above - h_below
    return driving * math.exp(float(log_mobility)), h_above, h_below


def _solve_holdout_ref(task):
    idx, sa, sb = task
    return idx, core.steady_q(core.h_of_s(sa), core.h_of_s(sb))


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_face_table_holdout.py OUTPUT.json")
    out = Path(sys.argv[1])
    probes = build_holdout()
    axis, table, preprocessing_seconds, generation_failures = generate_full_table()
    if generation_failures:
        evidence = {"schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01","gate":"B_REAL_FACE_TABLE_HOLDOUT","pass":False,"decision":"REAL_FACE_TABLE_HOLDOUT_FAILED_TABLE_GENERATION","generation_failures":generation_failures}
        out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
        print(json.dumps(evidence, indent=2, sort_keys=True))
        raise SystemExit(1)
    refs = [0.0] * len(probes)
    tasks = [(i, sa, sb) for i, (sa, sb, _) in enumerate(probes)]
    with mp.Pool(min(8, mp.cpu_count())) as pool:
        for idx, q in pool.imap_unordered(_solve_holdout_ref, tasks, chunksize=1):
            refs[idx] = q
    rows = []
    lookup_failures = 0
    nan_or_inf = 0
    for idx, (sa, sb, kind) in enumerate(probes):
        try:
            q_table, h_above, h_below = lookup(sa, sb, axis, table)
        except Exception as exc:
            lookup_failures += 1
            rows.append({"kind": kind, "lookup_error": repr(exc)})
            continue
        q_ref = refs[idx]
        if not (math.isfinite(q_ref) and math.isfinite(q_table)):
            nan_or_inf += 1
        hybrid = abs(q_table - q_ref) / (abs(q_ref) + 1.0e-4 * core.KSAT)
        abs_over = abs(q_table - q_ref) / core.KSAT
        wrong_sign = int(abs(q_ref) > SIGN_REF_THRESHOLD and q_ref * q_table < 0.0)
        near_zero_violation = int(abs(q_ref) <= SIGN_REF_THRESHOLD and abs(q_table) / core.KSAT > NEAR_ZERO_TABLE_MAX)
        rows.append({
            "kind":kind,"hybrid_metric":hybrid,"abs_error_over_ksat":abs_over,"wrong_sign":wrong_sign,"near_zero_violation":near_zero_violation,
            "equal_relative_error":abs(q_table-q_ref)/max(abs(q_ref),1.0e-300) if kind=="equal_head" else 0.0,
            "hydrostatic_abs_q_over_ksat":abs(q_table)/core.KSAT if kind=="hydrostatic" else 0.0,
            "h_above":h_above,"h_below":h_below,"q_ref":q_ref,"q_table":q_table})
    valid = [r for r in rows if "hybrid_metric" in r]
    hybrid_sorted = sorted(r["hybrid_metric"] for r in valid)
    p99 = hybrid_sorted[int(0.99 * (len(hybrid_sorted) - 1))]
    equal = [r["equal_relative_error"] for r in valid if r["kind"] == "equal_head"]
    hydro = [r["hydrostatic_abs_q_over_ksat"] for r in valid if r["kind"] == "hydrostatic"]
    observed = {
        "probe_count":len(probes),"ordinary_count":sum(1 for _,_,k in probes if k=="ordinary"),
        "max_hybrid_metric":max(r["hybrid_metric"] for r in valid),"p99_hybrid_metric":p99,
        "max_abs_error_over_ksat":max(r["abs_error_over_ksat"] for r in valid),
        "wrong_sign_count":sum(r["wrong_sign"] for r in valid),"near_zero_violation_count":sum(r["near_zero_violation"] for r in valid),
        "max_equal_head_relative_error":max(equal),"max_hydrostatic_abs_q_over_ksat":max(hydro),
        "lookup_failures":lookup_failures,"nan_or_inf":nan_or_inf,"full_table_entries":int(table.size),
        "full_table_generation_failures":len(generation_failures),"shared_table_plus_axis_bytes":int(table.nbytes+axis.nbytes),
        "preprocessing_seconds_descriptive":preprocessing_seconds,
        "table_sha256_float64_c_order":hashlib.sha256(table.tobytes(order="C")).hexdigest(),
        "axis_sha256_float64_c_order":hashlib.sha256(axis.tobytes(order="C")).hexdigest()}
    passed = (
        observed["max_hybrid_metric"]<=HYBRID_MAX and observed["p99_hybrid_metric"]<=HYBRID_P99 and observed["max_abs_error_over_ksat"]<=ABS_KSAT_MAX
        and observed["wrong_sign_count"]==0 and observed["near_zero_violation_count"]==0 and observed["max_equal_head_relative_error"]<=EQUAL_REL_MAX
        and observed["max_hydrostatic_abs_q_over_ksat"]<=HYDRO_MAX and observed["lookup_failures"]==0 and observed["nan_or_inf"]==0
        and observed["full_table_entries"]==N*N and observed["full_table_generation_failures"]==0 and observed["shared_table_plus_axis_bytes"]<=MEMORY_MAX)
    worst = max(valid, key=lambda r:r["hybrid_metric"])
    evidence = {
        "schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01","gate":"B_REAL_FACE_TABLE_HOLDOUT",
        "candidate":"V2_LOG_HEAD_LOG_MOBILITY_WITH_EXACT_EQUAL_HEAD_N129","fixture":"B01_NO_KSATEXM_L10_H_-10000_-1","holdout_seed":SEED,
        "thresholds":{"max_hybrid_metric":HYBRID_MAX,"p99_hybrid_metric":HYBRID_P99,"max_abs_error_over_ksat":ABS_KSAT_MAX,"wrong_sign_count":0,
                      "near_zero_table_abs_over_ksat":NEAR_ZERO_TABLE_MAX,"max_equal_head_relative_error":EQUAL_REL_MAX,"max_hydrostatic_abs_q_over_ksat":HYDRO_MAX,
                      "shared_table_plus_axis_bytes":MEMORY_MAX},
        "observed":observed,"worst_hybrid_probe":worst,"density_or_representation_changed_after_freeze":False,"pass":passed,
        "decision":"QUALIFIED_REAL_UNSATURATED_HOMOGENEOUS_STEADY_DARCIAN_FACE_TABLE_READY_FOR_PHYSICAL_ROSS_PROTOTYPE" if passed else "REAL_FACE_TABLE_HOLDOUT_FAILED_FAIL_CLOSED",
        "scope_limit":"One B01 homogeneous unsaturated 10-cm face only. No Gate C generalisation, saturation transition, timestep, heterogeneous profile, bottom boundary, groundwater, process, MultiSWAP or FullRichards claim."}
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
