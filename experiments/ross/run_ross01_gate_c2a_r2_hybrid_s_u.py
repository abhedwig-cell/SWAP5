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
SEAM_INDEX = 18
WET_INTERVALS = 18
DRY_INTERVALS = 222
U_SEAM = math.log10(2.0)
FIXED_METADATA_BYTES = c2a.v4.base.FIXED_METADATA_BYTES


def wet_state_at_index(i: int) -> float:
    if not 0 <= i <= SEAM_INDEX:
        raise IndexError(i)
    return c2a.core.S_MAX - (c2a.core.S_MAX - c2a.S_THR) * i / WET_INTERVALS


def u_at_index(i: int) -> float:
    if not 0 <= i < N:
        raise IndexError(i)
    if i == 0:
        return 0.0
    if i == SEAM_INDEX:
        return U_SEAM
    if i < SEAM_INDEX:
        return c2a.v4.state_to_u(wet_state_at_index(i))
    return U_SEAM + (4.0 - U_SEAM) * (i - SEAM_INDEX) / DRY_INTERVALS


def state_to_u_exact(s: float) -> float:
    if s == c2a.S_THR:
        return U_SEAM
    return c2a.v4.state_to_u(s)


def state_to_head_exact(s: float) -> tuple[float, float]:
    u = state_to_u_exact(s)
    if u == U_SEAM:
        return u, c2a.H_THR
    return u, c2a.v4.u_to_head(u)


def locate_state(s: float) -> tuple[int, float]:
    if s < c2a.core.S_MIN or s > c2a.core.S_MAX:
        raise ValueError("state outside exact material S domain")
    if s == c2a.S_THR:
        return SEAM_INDEX, 0.0
    if s > c2a.S_THR:
        x = WET_INTERVALS * (c2a.core.S_MAX - s) / (c2a.core.S_MAX - c2a.S_THR)
    else:
        u = c2a.v4.state_to_u(s)
        x = SEAM_INDEX + DRY_INTERVALS * (u - U_SEAM) / (4.0 - U_SEAM)
    if not (0.0 <= x <= N - 1 and math.isfinite(x)):
        raise ValueError("hybrid S-u coordinate would extrapolate")
    i = min(N - 2, max(0, int(math.floor(x))))
    return i, x - i


def generate_table_r2(n: int):
    if n != N:
        raise ValueError("R2 is frozen at N=241")
    table = np.full((N, N), np.nan, dtype=np.float32)
    axis = [u_at_index(i) for i in range(N)]
    if any(b <= a for a, b in zip(axis[:-1], axis[1:])):
        raise ValueError("R2 material-specific physical axis is not strictly increasing in u")
    tasks = [(i, j, axis[i], axis[j]) for i in range(N) for j in range(N)]
    failures = []
    started = time.time()
    with c2a.v4.base.CTX.Pool(min(8, c2a.v4.base.mp.cpu_count())) as pool:
        for i, j, value, error in pool.imap_unordered(c2a.v4.base._safe_node, tasks, chunksize=4):
            if error is None:
                table[i, j] = np.float32(value)
            else:
                failures.append({"i": i, "j": j, "error": error})
    return table, time.time() - started, failures


def lookup_r2(sa: float, sb: float, table: np.ndarray, n: int):
    if n != N:
        raise ValueError("R2 is frozen at N=241")
    _, h_above = state_to_head_exact(sa)
    _, h_below = state_to_head_exact(sb)

    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return c2a.core.k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    ia, fa = locate_state(sa)
    ib, fb = locate_state(sb)
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


# R2 changes only the candidate table axis and locator.
c2a.v4.base.generate_table = generate_table_r2
c2a.v4.base.lookup = lookup_r2


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2a_r2_hybrid_s_u.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in c2a.STRESS_MATERIALS:
        raise SystemExit(f"material must be one of {c2a.STRESS_MATERIALS}")

    catalog = json.loads(c2a.CATALOG_PATH.read_text())
    row = {entry["sfu"]: entry for entry in catalog["rows"]}[material]
    result = c2a.v4.base.run_material(row, N)
    src = c2a.source_checks(row)
    result["source_checks"] = src
    result["ksatexm_enabled"] = True
    result["h_enpr_enabled"] = False
    result["characterization_probe_set"] = "FROZEN_C2A_KSATEXM_CHARACTERIZATION_REUSED_FOR_R2"
    axis = np.asarray([u_at_index(i) for i in range(N)], dtype=np.float64)
    wet_states = np.asarray([wet_state_at_index(i) for i in range(SEAM_INDEX + 1)], dtype=np.float64)
    result["representation"] = {
        "N": N,
        "storage": "float32_log_mobility",
        "coordinate": "hybrid_uniform_S_wet_uniform_u_dry",
        "seam_node_index": SEAM_INDEX,
        "wet_intervals": WET_INTERVALS,
        "dry_intervals": DRY_INTERVALS,
        "shared_table_plus_metadata_bytes": int(4 * N * N + FIXED_METADATA_BYTES),
        "axis_persisted": False,
    }
    result["axis_sha256_float64_materialization"] = hashlib.sha256(axis.tobytes(order="C")).hexdigest()
    result["wet_state_nodes_sha256_float64_materialization"] = hashlib.sha256(wet_states.tobytes(order="C")).hexdigest()
    if not src["pass"]:
        result["pass"] = False
        result.setdefault("failed_metrics", []).append("source_semantics_checks")

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2A_R2_KSATEXM_HYBRID_S_U_CHARACTERIZATION",
        "material": material,
        "result": result,
        "pass": bool(result["pass"]),
        "decision": "C2A_R2_CHARACTERIZATION_MATERIAL_PASS" if result["pass"] else "C2A_R2_CHARACTERIZATION_MATERIAL_FAIL",
        "no_holdout_access": True,
        "scope_limit": "R2 characterization only; no 36-material KSATEXM claim and no h>-1 cm claim."
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
