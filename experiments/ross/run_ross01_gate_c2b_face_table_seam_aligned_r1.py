from __future__ import annotations

import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np

import run_ross01_gate_c2b_face_table_characterization as face

N = 241
U4 = math.log10(4.0)
U40 = math.log10(40.0)
SEGMENT_INTERVALS = (36, 60, 144)

base = face.base
core = face.core


def seam_axis() -> np.ndarray:
    a = np.linspace(0.0, U4, SEGMENT_INTERVALS[0] + 1)
    b = np.linspace(U4, U40, SEGMENT_INTERVALS[1] + 1)[1:]
    c = np.linspace(U40, 4.0, SEGMENT_INTERVALS[2] + 1)[1:]
    axis = np.concatenate((a, b, c))
    if len(axis) != N:
        raise RuntimeError(("invalid_axis_length", len(axis)))
    if axis[36] != U4 or axis[96] != U40:
        raise RuntimeError(("join_nodes_not_exact", axis[36], axis[96], U4, U40))
    return axis


AXIS = seam_axis()


def u_to_x(u: float) -> float:
    if not (0.0 <= u <= 4.0 and math.isfinite(u)):
        raise ValueError("u outside frozen C2B face envelope")
    if u <= U4:
        return SEGMENT_INTERVALS[0] * u / U4
    if u <= U40:
        return SEGMENT_INTERVALS[0] + SEGMENT_INTERVALS[1] * (u - U4) / (U40 - U4)
    return (
        SEGMENT_INTERVALS[0]
        + SEGMENT_INTERVALS[1]
        + SEGMENT_INTERVALS[2] * (u - U40) / (4.0 - U40)
    )


def generate_table(n: int):
    if n != N:
        raise ValueError("R1 is frozen at N241")
    table = np.full((N, N), np.nan, dtype=np.float32)
    tasks = [(i, j, float(AXIS[i]), float(AXIS[j])) for i in range(N) for j in range(N)]
    failures = []
    started = time.time()
    with base.CTX.Pool(min(8, base.mp.cpu_count())) as pool:
        for i, j, value, error in pool.imap_unordered(base._safe_node, tasks, chunksize=4):
            if error is None:
                table[i, j] = np.float32(value)
            else:
                failures.append({"i": i, "j": j, "error": error})
    return table, time.time() - started, failures


def lookup(sa: float, sb: float, table: np.ndarray, n: int):
    if n != N:
        raise ValueError("R1 is frozen at N241")
    ua, h_above = face.state_to_head_c2b(sa)
    ub, h_below = face.state_to_head_c2b(sb)

    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return face.c2b_k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    xa = u_to_x(ua)
    xb = u_to_x(ub)
    coord_tol = 1.0e-10 * (N - 1)
    if not (-coord_tol <= xa <= N - 1 + coord_tol and -coord_tol <= xb <= N - 1 + coord_tol):
        raise ValueError("seam-aligned lookup would extrapolate")
    xa = min(N - 1.0, max(0.0, xa))
    xb = min(N - 1.0, max(0.0, xb))
    ia = min(N - 2, max(0, int(math.floor(xa))))
    ib = min(N - 2, max(0, int(math.floor(xb))))
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
    driving = base.LENGTH_CM + h_above - h_below
    return driving * math.exp(log_mobility), h_above, h_below


base.generate_table = generate_table
base.lookup = lookup


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2b_face_table_seam_aligned_r1.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in face.STRESS_MATERIALS:
        raise SystemExit(f"material must be one of {face.STRESS_MATERIALS}")

    catalog = json.loads(face.CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    row = by_name[material]
    result = base.run_material(row, N)

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_HENPR_SVG2006_N241_SEAM_ALIGNED_FACE_CHARACTERIZATION_R1",
        "contract": "F-ROSS01_GATE_C2B_FACE_TABLE_SEAM_ALIGNED_R1_CONTRACT.json",
        "material": material,
        "candidate": {
            "N": N,
            "storage": "float32_log_mobility",
            "coordinate": "piecewise_uniform_u_with_exact_nodes_at_log10_4_and_log10_40",
            "segment_intervals": list(SEGMENT_INTERVALS),
            "join_node_indices": [36, 96],
            "join_u": [U4, U40],
            "axis_sha256_float64_c_order": hashlib.sha256(AXIS.tobytes(order="C")).hexdigest(),
            "shared_table_plus_metadata_bytes": 4 * N * N + base.FIXED_METADATA_BYTES
        },
        "physical_closure": "SWAP5_HENPR_SVG2006_LOGK_BRIDGE_V1",
        "result": result,
        "pass": bool(result["pass"]),
        "decision": "C2B_SEAM_ALIGNED_N241_R1_MATERIAL_PASS" if result["pass"] else "C2B_SEAM_ALIGNED_N241_R1_MATERIAL_FAIL",
        "scope_guard": "Characterization only; no fresh holdout, transient, groundwater or production claim."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material,
        "pass": evidence["pass"],
        "max_hybrid_metric": result.get("max_hybrid_metric"),
        "p99_hybrid_metric": result.get("p99_hybrid_metric"),
        "max_abs_error_over_ksatfit": result.get("max_abs_error_over_ksatfit"),
        "wrong_sign_count": result.get("wrong_sign_count"),
        "near_zero_violation_count": result.get("near_zero_violation_count"),
        "worst_hybrid_probe": result.get("worst_hybrid_probe"),
        "worst_abs_probe": result.get("worst_abs_probe"),
        "failed_metrics": result.get("failed_metrics", [])
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if evidence["pass"] else 1)


if __name__ == "__main__":
    main()
