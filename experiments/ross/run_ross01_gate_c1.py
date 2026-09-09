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
LENGTH_CM = 10.0
H_MIN = -10000.0
H_MAX = -1.0
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
EQUAL_REL_MAX = 0.005
HYDRO_MAX = 1.0e-5
NEAR_ZERO_TABLE_MAX = 1.0e-6
MEMORY_MAX = 262144
CATALOG_PATH = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
CTX = mp.get_context("fork")


def configure_core(row):
    core.THETA_R = float(row["theta_r"])
    core.THETA_S = float(row["theta_s"])
    core.ALPHA = float(row["alpha_per_cm"])
    core.NPAR = float(row["n"])
    core.MPAR = 1.0 - 1.0 / core.NPAR
    core.KSAT = float(row["ksatfit_cm_per_day"])
    core.LAMBDA = float(row["lambda"])
    core.LENGTH_CM = LENGTH_CM
    core.H_MIN = H_MIN
    core.H_MAX = H_MAX
    core.S_MIN = core.s_of_h(H_MIN)
    core.S_MAX = core.s_of_h(H_MAX)


def seed_for_material(name):
    return int(hashlib.sha256(("F-ROSS01-C1:" + name).encode()).hexdigest()[:8], 16)


def state_pair_from_heads(h_above, h_below):
    return float(core.s_of_h(h_above)), float(core.s_of_h(h_below))


def build_probes(name):
    probes = []
    ordinary = qmc.Sobol(d=2, scramble=True, seed=seed_for_material(name)).random_base2(m=8)
    for a, b in ordinary:
        sa = core.S_MIN + (core.S_MAX - core.S_MIN) * float(a)
        sb = core.S_MIN + (core.S_MAX - core.S_MIN) * float(b)
        probes.append((float(sa), float(sb), "ordinary"))
    for h in -np.geomspace(1.0, 10000.0, 48):
        sa, sb = state_pair_from_heads(float(h), float(h))
        probes.append((sa, sb, "equal_head"))
    for h_above in -np.geomspace(11.0, 10000.0, 48):
        h_below = float(h_above) + LENGTH_CM
        sa, sb = state_pair_from_heads(float(h_above), h_below)
        probes.append((sa, sb, "hydrostatic"))
    for h_above in -np.geomspace(21.0, 10000.0, 32):
        for epsilon in (-1.0, 1.0):
            h_below = float(h_above) + LENGTH_CM + epsilon
            sa, sb = state_pair_from_heads(float(h_above), h_below)
            probes.append((sa, sb, "near_hydrostatic"))
    for a in (0.02, 0.1, 0.5, 0.9, 0.98):
        for b in (0.02, 0.1, 0.5, 0.9, 0.98):
            sa = core.S_MIN + (core.S_MAX - core.S_MIN) * a
            sb = core.S_MIN + (core.S_MAX - core.S_MIN) * b
            probes.append((float(sa), float(sb), "wet_dry_cross"))
    for ha, hb in (
        (H_MIN, H_MIN), (H_MAX, H_MAX), (H_MIN, H_MAX), (H_MAX, H_MIN),
        (H_MIN, H_MIN + LENGTH_CM), (H_MAX - LENGTH_CM, H_MAX),
    ):
        sa, sb = state_pair_from_heads(ha, hb)
        probes.append((sa, sb, "edge"))
    return probes


def _safe_node(task):
    try:
        i, j, value = core._solve_v2_node(task)
        return i, j, value, None
    except Exception as exc:
        i, j, _, _ = task
        return i, j, None, repr(exc)


def generate_table():
    axis = np.linspace(0.0, 4.0, N)
    table = np.full((N, N), np.nan, dtype=np.float64)
    tasks = [(i, j, float(axis[i]), float(axis[j])) for i in range(N) for j in range(N)]
    failures = []
    started = time.time()
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for i, j, value, error in pool.imap_unordered(_safe_node, tasks, chunksize=4):
            if error is None:
                table[i, j] = value
            else:
                failures.append({"i": i, "j": j, "error": error})
    return axis, table, time.time() - started, failures


def lookup(sa, sb, table):
    if not (core.S_MIN <= sa <= core.S_MAX and core.S_MIN <= sb <= core.S_MAX):
        raise ValueError("state outside frozen S envelope")
    h_above = core.h_of_s(sa)
    h_below = core.h_of_s(sb)
    if not (H_MIN - 1.0e-8 <= h_above <= H_MAX + 1.0e-8):
        raise ValueError("upper head outside frozen envelope")
    if not (H_MIN - 1.0e-8 <= h_below <= H_MAX + 1.0e-8):
        raise ValueError("lower head outside frozen envelope")
    if sa == sb:
        return core.k_of_h(h_above), h_above, h_below
    ua = math.log10(-h_above)
    ub = math.log10(-h_below)
    xa = (N - 1) * ua / 4.0
    xb = (N - 1) * ub / 4.0
    if not (-1.0e-10 <= xa <= N - 1 + 1.0e-10 and -1.0e-10 <= xb <= N - 1 + 1.0e-10):
        raise ValueError("lookup would extrapolate")
    xa = min(N - 1.0, max(0.0, xa))
    xb = min(N - 1.0, max(0.0, xb))
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


def _safe_ref(task):
    idx, sa, sb = task
    try:
        return idx, core.steady_q(core.h_of_s(sa), core.h_of_s(sb)), None
    except Exception as exc:
        return idx, None, repr(exc)


def run_material(row):
    configure_core(row)
    name = row["sfu"]
    ksat = core.KSAT
    probes = build_probes(name)
    axis, table, preprocessing_seconds, generation_failures = generate_table()
    base = {
        "material": name,
        "seed": seed_for_material(name),
        "probe_count": len(probes),
        "full_table_entries": int(table.size),
        "full_table_generation_failures": len(generation_failures),
        "shared_table_plus_axis_bytes": int(table.nbytes + axis.nbytes),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "s_min": core.S_MIN,
        "s_max": core.S_MAX,
    }
    if generation_failures:
        base.update({"pass": False, "failure_class": "TABLE_GENERATION_FAILURE", "generation_failure_examples": generation_failures[:8]})
        return base

    refs = [None] * len(probes)
    ref_errors = []
    tasks = [(i, sa, sb) for i, (sa, sb, _) in enumerate(probes)]
    with CTX.Pool(min(8, mp.cpu_count())) as pool:
        for idx, q, error in pool.imap_unordered(_safe_ref, tasks, chunksize=1):
            if error is None:
                refs[idx] = q
            else:
                ref_errors.append({"index": idx, "error": error})

    rows = []
    lookup_failures = 0
    nan_or_inf = 0
    sign_threshold = 1.0e-8 * ksat
    for idx, (sa, sb, kind) in enumerate(probes):
        if refs[idx] is None:
            continue
        try:
            q_table, h_above, h_below = lookup(sa, sb, table)
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

    if not rows:
        base.update({"pass": False, "failure_class": "NO_VALID_PROBES", "reference_failures": len(ref_errors)})
        return base
    hybrids = sorted(r["hybrid_metric"] for r in rows)
    p99 = hybrids[int(0.99 * (len(hybrids) - 1))]
    equal = [r["equal_relative_error"] for r in rows if r["kind"] == "equal_head"]
    hydro = [r["hydrostatic_abs_q_over_ksatfit"] for r in rows if r["kind"] == "hydrostatic"]
    observed = {
        **base,
        "reference_failures": len(ref_errors),
        "lookup_failures": lookup_failures,
        "nan_or_inf": nan_or_inf,
        "valid_probe_count": len(rows),
        "max_hybrid_metric": max(hybrids),
        "p99_hybrid_metric": p99,
        "max_abs_error_over_ksatfit": max(r["abs_error_over_ksatfit"] for r in rows),
        "wrong_sign_count": sum(r["wrong_sign"] for r in rows),
        "near_zero_violation_count": sum(r["near_zero_violation"] for r in rows),
        "max_equal_head_relative_error": max(equal),
        "max_hydrostatic_abs_q_over_ksatfit": max(hydro),
        "table_sha256_float64_c_order": hashlib.sha256(table.tobytes(order="C")).hexdigest(),
        "axis_sha256_float64_c_order": hashlib.sha256(axis.tobytes(order="C")).hexdigest(),
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
        "shared_table_plus_axis_bytes": observed["shared_table_plus_axis_bytes"] <= MEMORY_MAX,
    }
    observed["pass"] = all(tests.values())
    observed["failed_metrics"] = [key for key, ok in tests.items() if not ok]
    observed["worst_hybrid_probe"] = max(rows, key=lambda r: r["hybrid_metric"])
    return observed


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_c1.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG_PATH.read_text())
    results = []
    started = time.time()
    for index, row in enumerate(catalog["rows"], 1):
        result = run_material(row)
        results.append(result)
        print(json.dumps({
            "progress": f"{index}/{len(catalog['rows'])}",
            "material": row["sfu"],
            "pass": result["pass"],
            "failed_metrics": result.get("failed_metrics", [result.get("failure_class")]),
        }), flush=True)
    failed = [r for r in results if not r["pass"]]
    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C1_STARINGREEKS_UNIMODAL_MVG_GENERALISATION",
        "candidate": "V2_LOG_HEAD_LOG_MOBILITY_WITH_EXACT_EQUAL_HEAD_N129",
        "material_count": len(results),
        "passed_material_count": len(results) - len(failed),
        "failed_material_count": len(failed),
        "failed_materials": [r["material"] for r in failed],
        "thresholds": {
            "max_hybrid_metric": HYBRID_MAX,
            "p99_hybrid_metric": HYBRID_P99,
            "max_abs_error_over_ksatfit": ABS_KSAT_MAX,
            "wrong_sign_count": 0,
            "near_zero_violation_count": 0,
            "max_equal_head_relative_error": EQUAL_REL_MAX,
            "max_hydrostatic_abs_q_over_ksatfit": HYDRO_MAX,
            "shared_table_plus_axis_bytes_max": MEMORY_MAX,
        },
        "representation_or_density_changed_from_gate_b": False,
        "ksatexm_enabled": False,
        "elapsed_seconds_descriptive": time.time() - started,
        "materials": results,
        "pass": len(failed) == 0,
        "decision": (
            "C1_STARINGREEKS_UNIMODAL_MVG_GENERALISATION_QUALIFIED_READY_FOR_KSATEXM_AND_OTHER_HYDRAULIC_FAMILIES"
            if not failed else
            "C1_GENERALISATION_FAILED_GATE_B_REPRESENTATION_NOT_UNIVERSAL_ACROSS_STARINGREEKS_MVG"
        ),
        "scope_limit": "C1 only: 36 frozen Staringreeks 2018 unimodal MvG materials using KSATFIT with KSATEXM disabled, homogeneous unsaturated 10-cm faces over h=[-10000,-1] cm. No claim for other hydraulic laws or later Ross gates.",
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k != "materials"}, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
