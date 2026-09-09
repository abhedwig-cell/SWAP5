from __future__ import annotations

import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np

import run_ross01_gate_c2a_ksatexm_characterization as c2a

N = 241
U_SEAM = math.log10(2.0)
SEAM_INDEX = 18
WET_INTERVALS = 18
DRY_INTERVALS = 222
FIXED_METADATA_BYTES = c2a.v4.base.FIXED_METADATA_BYTES


def u_at_index(i: int) -> float:
    if not 0 <= i < N:
        raise IndexError(i)
    if i <= SEAM_INDEX:
        return U_SEAM * i / WET_INTERVALS
    return U_SEAM + (4.0 - U_SEAM) * (i - SEAM_INDEX) / DRY_INTERVALS


def state_to_u_r1(s: float) -> float:
    # S_thr is an immutable source-defined material boundary, not a tolerance.
    if s == c2a.S_THR:
        return U_SEAM
    return c2a.v4.state_to_u(s)


def u_to_head_r1(u: float) -> float:
    if u == 0.0:
        return c2a.v4.base.H_MAX
    if u == 4.0:
        return c2a.v4.base.H_MIN
    if u == U_SEAM:
        return c2a.H_THR
    return -(10.0 ** u)


def locate_u(u: float) -> tuple[int, float]:
    if not (0.0 <= u <= 4.0 and math.isfinite(u)):
        raise ValueError("u outside frozen R1 envelope")
    if u == U_SEAM:
        return SEAM_INDEX, 0.0
    if u < U_SEAM:
        x = WET_INTERVALS * u / U_SEAM
    else:
        x = SEAM_INDEX + DRY_INTERVALS * (u - U_SEAM) / (4.0 - U_SEAM)
    if not (0.0 <= x <= N - 1):
        raise ValueError("piecewise coordinate would extrapolate")
    i = min(N - 2, max(0, int(math.floor(x))))
    return i, x - i


def generate_table_r1(n: int):
    if n != N:
        raise ValueError("R1 is frozen at N=241")
    table = np.full((N, N), np.nan, dtype=np.float32)
    tasks = [(i, j, u_at_index(i), u_at_index(j)) for i in range(N) for j in range(N)]
    failures = []
    started = time.time()
    with c2a.v4.base.CTX.Pool(min(8, c2a.v4.base.mp.cpu_count())) as pool:
        for i, j, value, error in pool.imap_unordered(c2a.v4.base._safe_node, tasks, chunksize=4):
            if error is None:
                table[i, j] = np.float32(value)
            else:
                failures.append({"i": i, "j": j, "error": error})
    return table, time.time() - started, failures


def lookup_r1(sa: float, sb: float, table: np.ndarray, n: int):
    if n != N:
        raise ValueError("R1 is frozen at N=241")
    ua = state_to_u_r1(sa)
    ub = state_to_u_r1(sb)
    h_above = u_to_head_r1(ua)
    h_below = u_to_head_r1(ub)

    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return c2a.core.k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    ia, fa = locate_u(ua)
    ib, fb = locate_u(ub)
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
    driving = c2a.v4.base.LENGTH_CM + h_above - h_below
    return driving * math.exp(log_mobility), h_above, h_below


# R1 changes only table node placement and locator. Physics, oracle and probes stay C2A-frozen.
c2a.v4.base.generate_table = generate_table_r1
c2a.v4.base.lookup = lookup_r1


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2a_r1_seam_aligned.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in c2a.STRESS_MATERIALS:
        raise SystemExit(f"material must be one of {c2a.STRESS_MATERIALS}")

    catalog = json.loads(c2a.CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    row = by_name[material]
    result = c2a.v4.base.run_material(row, N)
    src = c2a.source_checks(row)
    result["source_checks"] = src
    result["ksatexm_enabled"] = True
    result["h_enpr_enabled"] = False
    result["characterization_probe_set"] = "FROZEN_C2A_KSATEXM_CHARACTERIZATION_REUSED_FOR_R1"
    result["representation"] = {
        "N": N,
        "storage": "float32_log_mobility",
        "coordinate": "piecewise_uniform_u_with_exact_h_minus_2_seam_node",
        "u_seam": U_SEAM,
        "seam_node_index": SEAM_INDEX,
        "wet_intervals": WET_INTERVALS,
        "dry_intervals": DRY_INTERVALS,
        "shared_table_plus_metadata_bytes": int(4 * N * N + FIXED_METADATA_BYTES),
        "axis_persisted": False,
    }
    result["axis_sha256_float64_analytic_materialization"] = hashlib.sha256(
        np.asarray([u_at_index(i) for i in range(N)], dtype=np.float64).tobytes(order="C")
    ).hexdigest()
    if not src["pass"]:
        result["pass"] = False
        result.setdefault("failed_metrics", []).append("source_semantics_checks")

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2A_R1_KSATEXM_SEAM_ALIGNED_CHARACTERIZATION",
        "material": material,
        "result": result,
        "pass": bool(result["pass"]),
        "decision": "C2A_R1_CHARACTERIZATION_MATERIAL_PASS" if result["pass"] else "C2A_R1_CHARACTERIZATION_MATERIAL_FAIL",
        "no_holdout_access": True,
        "scope_limit": "R1 characterization only; no 36-material KSATEXM claim and no h>-1 cm claim."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material,
        "pass": evidence["pass"],
        "max_hybrid_metric": result.get("max_hybrid_metric"),
        "p99_hybrid_metric": result.get("p99_hybrid_metric"),
        "max_abs_error_over_ksatfit": result.get("max_abs_error_over_ksatfit"),
        "failed_metrics": result.get("failed_metrics", []),
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
