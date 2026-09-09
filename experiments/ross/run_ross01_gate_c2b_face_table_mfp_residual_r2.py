from __future__ import annotations

import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np
from scipy.integrate import quad

import run_ross01_gate_c2b_face_table_seam_aligned_r1 as seam

N = seam.N
AXIS = seam.AXIS
LENGTH_CM = seam.base.LENGTH_CM
PHI_TABLE: np.ndarray | None = None

face = seam.face
base = seam.base
core = seam.core

# Count the material-shared float64 Phi table in the same memory gate used by
# the inherited C1R characterization harness.
base.FIXED_METADATA_BYTES = 32 + 8 * N


def build_phi_table() -> np.ndarray:
    heads = -(10.0 ** AXIS)
    phi = np.zeros(N, dtype=np.float64)
    # AXIS increases from h=-1 to h=-10000. Define Phi(-10000)=0 and
    # integrate back toward the wet endpoint. The seam-aligned axis contains
    # h=-40 and h=-4 exactly, so no quadrature segment straddles either C0 join.
    for i in range(N - 2, -1, -1):
        lo = float(heads[i + 1])
        hi = float(heads[i])
        value, _ = quad(
            face.c2b_k_of_h,
            lo,
            hi,
            epsabs=1.0e-10,
            epsrel=1.0e-11,
            limit=120,
        )
        if not (value > 0.0 and math.isfinite(value)):
            raise RuntimeError(("invalid_phi_increment", i, lo, hi, value))
        phi[i] = phi[i + 1] + value
    if not np.all(np.isfinite(phi)):
        raise RuntimeError("non-finite Phi table")
    if not np.all(phi[:-1] > phi[1:]):
        raise RuntimeError("Phi table is not strictly monotone in the frozen u axis")
    return phi


def phi_at_u(u: float) -> float:
    if PHI_TABLE is None:
        raise RuntimeError("Phi table not initialized")
    x = seam.u_to_x(u)
    x = min(N - 1.0, max(0.0, x))
    i = min(N - 2, max(0, int(math.floor(x))))
    f = x - i
    return (1.0 - f) * float(PHI_TABLE[i]) + f * float(PHI_TABLE[i + 1])


def mfp_reference_mobility_from_values(
    h_above: float,
    h_below: float,
    phi_above: float,
    phi_below: float,
) -> float:
    dh = h_below - h_above
    close = abs(dh) <= 2.0e-10 * max(1.0, abs(h_above), abs(h_below))
    if close:
        value = face.c2b_k_of_h(0.5 * (h_above + h_below)) / LENGTH_CM
    else:
        value = (phi_below - phi_above) / (LENGTH_CM * dh)
    if not (value > 0.0 and math.isfinite(value)):
        raise RuntimeError(("invalid_mfp_reference_mobility", h_above, h_below, value))
    return value


def mfp_reference_mobility_runtime(
    ua: float,
    h_above: float,
    ub: float,
    h_below: float,
) -> float:
    return mfp_reference_mobility_from_values(
        h_above,
        h_below,
        phi_at_u(ua),
        phi_at_u(ub),
    )


def _safe_residual_node(task):
    i, j, ua, ub = task
    try:
        if PHI_TABLE is None:
            raise RuntimeError("Phi table not initialized in worker")
        _, _, log_mobility = core._solve_v2_node(task)
        h_above = -(10.0 ** ua)
        h_below = -(10.0 ** ub)
        m_ref = mfp_reference_mobility_from_values(
            h_above,
            h_below,
            float(PHI_TABLE[i]),
            float(PHI_TABLE[j]),
        )
        residual = log_mobility - math.log(m_ref)
        if not math.isfinite(residual):
            raise RuntimeError(("nonfinite_log_residual", i, j, residual))
        return i, j, residual, None
    except Exception as exc:
        return i, j, None, repr(exc)


def generate_table(n: int):
    global PHI_TABLE
    if n != N:
        raise ValueError("R2 is frozen at N241")
    PHI_TABLE = build_phi_table()
    table = np.full((N, N), np.nan, dtype=np.float32)
    tasks = [(i, j, float(AXIS[i]), float(AXIS[j])) for i in range(N) for j in range(N)]
    failures = []
    started = time.time()
    with base.CTX.Pool(min(8, base.mp.cpu_count())) as pool:
        for i, j, value, error in pool.imap_unordered(_safe_residual_node, tasks, chunksize=4):
            if error is None:
                table[i, j] = np.float32(value)
            else:
                failures.append({"i": i, "j": j, "error": error})
    return table, time.time() - started, failures


def lookup(sa: float, sb: float, table: np.ndarray, n: int):
    if n != N:
        raise ValueError("R2 is frozen at N241")
    ua, h_above = face.state_to_head_c2b(sa)
    ub, h_below = face.state_to_head_c2b(sb)

    if abs(h_above - h_below) <= 2.0e-13 * max(1.0, abs(h_above), abs(h_below)):
        return face.c2b_k_of_h(0.5 * (h_above + h_below)), h_above, h_below

    xa = seam.u_to_x(ua)
    xb = seam.u_to_x(ub)
    coord_tol = 1.0e-10 * (N - 1)
    if not (-coord_tol <= xa <= N - 1 + coord_tol and -coord_tol <= xb <= N - 1 + coord_tol):
        raise ValueError("MFP-residual lookup would extrapolate")
    xa = min(N - 1.0, max(0.0, xa))
    xb = min(N - 1.0, max(0.0, xb))
    ia = min(N - 2, max(0, int(math.floor(xa))))
    ib = min(N - 2, max(0, int(math.floor(xb))))
    fa = xa - ia
    fb = xb - ib
    r00 = float(table[ia, ib])
    r10 = float(table[ia + 1, ib])
    r01 = float(table[ia, ib + 1])
    r11 = float(table[ia + 1, ib + 1])
    log_residual = (
        (1.0 - fa) * (1.0 - fb) * r00
        + fa * (1.0 - fb) * r10
        + (1.0 - fa) * fb * r01
        + fa * fb * r11
    )
    m_ref = mfp_reference_mobility_runtime(ua, h_above, ub, h_below)
    driving = LENGTH_CM + h_above - h_below
    return driving * m_ref * math.exp(log_residual), h_above, h_below


base.generate_table = generate_table
base.lookup = lookup


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_c2b_face_table_mfp_residual_r2.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in face.STRESS_MATERIALS:
        raise SystemExit(f"material must be one of {face.STRESS_MATERIALS}")

    catalog = json.loads(face.CATALOG_PATH.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    row = by_name[material]
    result = base.run_material(row, N)
    if PHI_TABLE is None:
        raise RuntimeError("Phi table absent after characterization")

    evidence = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "C2B_HENPR_SVG2006_N241_MFP_RESIDUAL_FACE_CHARACTERIZATION_R2",
        "contract": "F-ROSS01_GATE_C2B_FACE_TABLE_MFP_RESIDUAL_R2_CONTRACT.json",
        "material": material,
        "candidate": {
            "N": N,
            "two_dimensional_storage": "float32_log_mobility_residual_over_mfp_secant",
            "phi_storage": "float64_241_node_cumulative_mfp",
            "coordinate": "piecewise_uniform_u_with_exact_nodes_at_log10_4_and_log10_40",
            "axis_sha256_float64_c_order": hashlib.sha256(AXIS.tobytes(order="C")).hexdigest(),
            "phi_sha256_float64_c_order": hashlib.sha256(PHI_TABLE.tobytes(order="C")).hexdigest(),
            "shared_table_plus_phi_plus_metadata_bytes": 4 * N * N + 8 * N + 32,
            "runtime_quadrature": False,
            "runtime_nonlinear_iterations": 0
        },
        "physical_closure": "SWAP5_HENPR_SVG2006_LOGK_BRIDGE_V1",
        "result": result,
        "pass": bool(result["pass"]),
        "decision": "C2B_MFP_RESIDUAL_N241_R2_MATERIAL_PASS" if result["pass"] else "C2B_MFP_RESIDUAL_N241_R2_MATERIAL_FAIL",
        "scope_guard": "Characterization only; no fresh holdout, transient, groundwater or production claim."
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material,
        "pass": evidence["pass"],
        "shared_bytes": evidence["candidate"]["shared_table_plus_phi_plus_metadata_bytes"],
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
