from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

import run_ross01_gate_c2a_r2_hybrid_s_u as r2

c2a = r2.c2a
N = r2.N
SEAM_INDEX = r2.SEAM_INDEX


def state_to_x(s: float) -> tuple[float, str]:
    if s < c2a.core.S_MIN or s > c2a.core.S_MAX:
        raise ValueError("state outside exact material S domain")
    if s >= c2a.S_THR:
        x = r2.WET_INTERVALS * (c2a.core.S_MAX - s) / (c2a.core.S_MAX - c2a.S_THR)
        if s == c2a.S_THR:
            x = float(SEAM_INDEX)
        regime = "wet"
    else:
        u = c2a.v4.state_to_u(s)
        x = SEAM_INDEX + r2.DRY_INTERVALS * (u - r2.U_SEAM) / (4.0 - r2.U_SEAM)
        regime = "dry"
    if not (0.0 <= x <= N - 1 and math.isfinite(x)):
        raise ValueError("R3 coordinate would extrapolate")
    return float(x), regime


def stencil_indices(x: float, regime: str) -> tuple[int, int, int, int]:
    if regime == "wet":
        lo, hi = 0, SEAM_INDEX
    elif regime == "dry":
        lo, hi = SEAM_INDEX, N - 1
    else:
        raise ValueError(regime)
    start = int(math.floor(x)) - 1
    start = min(hi - 3, max(lo, start))
    indices = (start, start + 1, start + 2, start + 3)
    if indices[0] < lo or indices[-1] > hi:
        raise ValueError("cubic stencil crosses constitutive regime boundary")
    return indices


def lagrange_weights(x: float, indices: tuple[int, int, int, int]) -> tuple[float, float, float, float]:
    weights = []
    for i in indices:
        w = 1.0
        for j in indices:
            if j != i:
                w *= (x - j) / (i - j)
        weights.append(w)
    return tuple(weights)  # type: ignore[return-value]


def lookup_r3(sa: float, sb: float, table: np.ndarray, n: int):
    if n != N:
        raise ValueError("R3 is frozen at N=241")
    _, h_above = r2.state_to_head_exact(sa)
    _, h_below = r2.state_to_head_exact(sb)

    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return c2a.core.k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    xa, regime_a = state_to_x(sa)
    xb, regime_b = state_to_x(sb)
    ia = stencil_indices(xa, regime_a)
    ib = stencil_indices(xb, regime_b)
    wa = lagrange_weights(xa, ia)
    wb = lagrange_weights(xb, ib)

    log_mobility = 0.0
    for ai, i in enumerate(ia):
        row_value = 0.0
        for bj, j in enumerate(ib):
            value = float(table[i, j])
            if not math.isfinite(value):
                raise ValueError("non-finite table value in cubic stencil")
            row_value += wb[bj] * value
        log_mobility += wa[ai] * row_value
    if not math.isfinite(log_mobility):
        raise ValueError("non-finite cubic log mobility")

    driving = c2a.v4.base.LENGTH_CM + h_above - h_below
    try:
        mobility = math.exp(log_mobility)
    except OverflowError as exc:
        raise ValueError("cubic log mobility overflow") from exc
    if not math.isfinite(mobility) or mobility <= 0.0:
        raise ValueError("invalid cubic mobility")
    return driving * mobility, h_above, h_below


# Importing R2 installs the frozen hybrid-axis table generator. R3 changes lookup only.
c2a.v4.base.lookup = lookup_r3


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2a_r3_regime_local_cubic.py MATERIAL OUTPUT.json")
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
    result["characterization_probe_set"] = "FROZEN_C2A_KSATEXM_CHARACTERIZATION_REUSED_FOR_R3"
    result["representation"] = {
        "N": N,
        "storage": "float32_log_mobility",
        "coordinate": "R2_hybrid_uniform_S_wet_uniform_u_dry",
        "interpolation": "regime_local_4x4_tensor_cubic_lagrange_log_mobility",
        "table_values_per_lookup": 16,
        "seam_crossing_stencils": False,
        "shared_table_plus_metadata_bytes": int(4 * N * N + r2.FIXED_METADATA_BYTES),
        "axis_persisted": False,
    }
    if not src["pass"]:
        result["pass"] = False
        result.setdefault("failed_metrics", []).append("source_semantics_checks")

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2A_R3_KSATEXM_REGIME_LOCAL_TENSOR_CUBIC_CHARACTERIZATION",
        "material": material,
        "result": result,
        "pass": bool(result["pass"]),
        "decision": "C2A_R3_CHARACTERIZATION_MATERIAL_PASS" if result["pass"] else "C2A_R3_CHARACTERIZATION_MATERIAL_FAIL",
        "no_holdout_access": True,
        "scope_limit": "R3 characterization only; no 36-material KSATEXM claim and no h>-1 cm claim."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material,
        "pass": evidence["pass"],
        "max_hybrid_metric": result.get("max_hybrid_metric"),
        "p99_hybrid_metric": result.get("p99_hybrid_metric"),
        "max_abs_error_over_ksatfit": result.get("max_abs_error_over_ksatfit"),
        "lookup_failures": result.get("lookup_failures"),
        "failed_metrics": result.get("failed_metrics", []),
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
