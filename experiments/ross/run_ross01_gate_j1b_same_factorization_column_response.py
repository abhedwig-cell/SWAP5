from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import brentq

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_j1a_real_table_face_derivative as j1a
import run_ross01_gate_j1a_r1_head_coordinate_oracle_repair as r1
import run_ross01_tangent_algebra as j0

CONTRACT = "F-ROSS01_GATE_J1B_SAME_FACTORIZATION_COLUMN_RESPONSE_CONTRACT.json"
GEOMETRIES = (
    ("wet_short", 2, -50.0),
    ("mid", 4, -200.0),
    ("dry", 16, -1000.0),
    ("long_dry", 64, -3000.0),
)
Q_FRACTIONS = (-0.02, 0.0, 0.02)
FD_FACTORS = (1.0e-5, 3.0e-5)
TANGENT_TOL = 1.0e-5
CONTINUITY_TOL = 1.0e-10
LINEAR_TOL = 1.0e-11
TANGENT_FLOOR_DAY = 1.0e-10


def float_bytes(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def solve_face_for_flux(h_upper: float, q_target: float, table: np.ndarray) -> float:
    length = j1a.c1r.base.LENGTH_CM
    h_hydro = h_upper + length
    h_min = j1a.c1r.base.H_MIN
    h_max = j1a.c1r.base.H_MAX
    if not (h_min < h_upper < h_max and h_min < h_hydro < h_max):
        raise ValueError(("profile leaves frozen head envelope", h_upper, h_hydro))

    def residual(h_lower: float) -> float:
        return r1.direct_head_flux(h_upper, h_lower, table) - q_target

    if q_target == 0.0:
        return h_hydro
    if q_target > 0.0:
        lo, hi = h_upper, h_hydro
    else:
        lo, hi = h_hydro, h_max
    f_lo = residual(lo)
    f_hi = residual(hi)
    if f_lo == 0.0:
        return lo
    if f_hi == 0.0:
        return hi
    if f_lo * f_hi > 0.0:
        raise RuntimeError(("face root not bracketed", h_upper, q_target, lo, hi, f_lo, f_hi))
    return float(brentq(residual, lo, hi, xtol=1.0e-10, rtol=1.0e-12, maxiter=200))


def generate_profile(h_top: float, n_faces: int, q_bottom: float, table: np.ndarray) -> tuple[float, ...]:
    heads = [h_top]
    for _ in range(n_faces):
        heads.append(solve_face_for_flux(heads[-1], q_bottom, table))
    return tuple(heads)


def cell_signature(heads: tuple[float, ...]) -> tuple[int, ...]:
    return tuple(j1a.table_cell(h)[0] for h in heads)


def assemble_system(heads: tuple[float, ...], q_bottom: float, table: np.ndarray):
    n = len(heads) - 1
    faces = [j1a.table_flux_and_derivatives(heads[j], heads[j + 1], table) for j in range(n)]
    lower = [0.0] * max(0, n - 1)
    diag = [0.0] * n
    upper = [0.0] * max(0, n - 1)
    residual = [0.0] * n
    for j in range(n - 1):
        left = faces[j]
        right = faces[j + 1]
        residual[j] = left["q"] - right["q"]
        if j > 0:
            lower[j - 1] = left["dq_dh_a"]
        diag[j] = left["dq_dh_b"] - right["dq_dh_a"]
        upper[j] = -right["dq_dh_b"]
    last = faces[-1]
    residual[-1] = last["q"] - q_bottom
    if n > 1:
        lower[-1] = last["dq_dh_a"]
    diag[-1] = last["dq_dh_b"]
    return lower, diag, upper, residual, faces


def tangent_metric(a: float, b: float) -> float:
    return abs(a - b) / max(abs(a), abs(b), TANGENT_FLOOR_DAY)


def run_case(material: str, geometry_name: str, n_faces: int, h_top: float,
             q_fraction: float, table: np.ndarray, ksat: float):
    k_top = float(j1a.c1r.base.c1.core.k_of_h(h_top))
    q_bottom = q_fraction * k_top
    heads = generate_profile(h_top, n_faces, q_bottom, table)
    snapshot = float_bytes(heads)
    signature = cell_signature(heads)
    lower, diag, upper, residual, faces = assemble_system(heads, q_bottom, table)
    factorization = j0.factor_tridiagonal(lower, diag, upper)

    normal_rhs = [-r for r in residual]
    normal_correction = j0.solve_factored(factorization, normal_rhs)
    tangent_rhs = [0.0] * n_faces
    tangent_rhs[-1] = 1.0
    response = j0.solve_factored(factorization, tangent_rhs)
    tangent = response[-1]

    normal_linear_residual = j0.base.matrix_residual(lower, diag, upper, normal_correction, normal_rhs)
    tangent_linear_residual = j0.base.matrix_residual(lower, diag, upper, response, tangent_rhs)
    scale_q = max(ksat, abs(q_bottom), 1.0e-300)
    face_fluxes = [f["q"] for f in faces]
    continuity_scaled = max(abs(q - q_bottom) for q in face_fluxes) / scale_q

    fd_rows = []
    cell_switch_count = 0
    for factor in FD_FACTORS:
        q_scale = max(abs(q_bottom), k_top, 1.0e-12 * ksat)
        dq = factor * q_scale
        plus = generate_profile(h_top, n_faces, q_bottom + dq, table)
        minus = generate_profile(h_top, n_faces, q_bottom - dq, table)
        sig_plus = cell_signature(plus)
        sig_minus = cell_signature(minus)
        switches = sum(int(a != b or a != c) for a, b, c in zip(signature, sig_plus, sig_minus))
        cell_switch_count += switches
        fd = (plus[-1] - minus[-1]) / (2.0 * dq)
        fd_rows.append({
            "factor": factor,
            "delta_q_cm_per_day": dq,
            "tangent_fd_day": fd,
            "tangent_metric": tangent_metric(tangent, fd),
            "cell_switches": switches,
        })

    unchanged = float_bytes(heads) == snapshot
    return {
        "material": material,
        "geometry": geometry_name,
        "n_faces": n_faces,
        "h_top_cm": h_top,
        "h_bottom_cm": heads[-1],
        "q_fraction_of_K_top": q_fraction,
        "q_bottom_cm_per_day": q_bottom,
        "K_top_cm_per_day": k_top,
        "d_h_bottom_d_q_bottom_day": tangent,
        "tangent_sign_negative": tangent < 0.0,
        "max_tangent_metric": max(r["tangent_metric"] for r in fd_rows),
        "fd_rows": fd_rows,
        "cell_switch_count": cell_switch_count,
        "scaled_base_flux_continuity_residual": continuity_scaled,
        "normal_linear_residual": normal_linear_residual,
        "tangent_linear_residual": tangent_linear_residual,
        "max_abs_uncommitted_normal_correction_cm": max(abs(x) for x in normal_correction),
        "base_state_bitwise_unchanged": unchanged,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "additional_tangent_backsolves": 1,
        "table_derivative_evaluations": n_faces,
        "production_nonlinear_trajectories_for_tangent": 0,
        "qualification_fd_profile_solves": 2 * len(FD_FACTORS),
    }


def run_material(row: dict) -> dict:
    j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    ksat = float(j1a.c1r.base.c1.core.KSAT)
    table, preprocessing_seconds, generation_failures = j1a.c1r.base.generate_table(j1a.N)
    if generation_failures:
        return {"material": material, "pass": False, "failed_metrics": ["table_generation_failures"]}
    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    cases = []
    errors = []
    for geometry_name, n_faces, h_top in GEOMETRIES:
        for q_fraction in Q_FRACTIONS:
            try:
                cases.append(run_case(material, geometry_name, n_faces, h_top, q_fraction, table, ksat))
            except Exception as exc:
                errors.append({
                    "geometry": geometry_name,
                    "n_faces": n_faces,
                    "h_top_cm": h_top,
                    "q_fraction_of_K_top": q_fraction,
                    "error": repr(exc),
                })
    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    if not cases:
        return {"material": material, "pass": False, "failed_metrics": ["no_valid_cases"], "errors": errors}
    observed = {
        "material": material,
        "case_count": len(cases),
        "case_error_count": len(errors),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "max_tangent_metric": max(c["max_tangent_metric"] for c in cases),
        "max_scaled_base_flux_continuity_residual": max(c["scaled_base_flux_continuity_residual"] for c in cases),
        "max_normal_linear_residual": max(c["normal_linear_residual"] for c in cases),
        "max_tangent_linear_residual": max(c["tangent_linear_residual"] for c in cases),
        "cell_switch_count": sum(c["cell_switch_count"] for c in cases),
        "nonnegative_tangent_count": sum(not c["tangent_sign_negative"] for c in cases),
        "base_state_bitwise_unchanged_all": all(c["base_state_bitwise_unchanged"] for c in cases),
        "matrix_factorizations_per_case": sorted(set(c["matrix_factorizations"] for c in cases)),
        "normal_backsolves_per_case": sorted(set(c["normal_backsolves"] for c in cases)),
        "additional_tangent_backsolves_per_case": sorted(set(c["additional_tangent_backsolves"] for c in cases)),
        "production_nonlinear_trajectories_for_tangent": sorted(set(c["production_nonlinear_trajectories_for_tangent"] for c in cases)),
        "worst_tangent_case": max(cases, key=lambda c: c["max_tangent_metric"]),
        "errors": errors,
    }
    tests = {
        "all_precommitted_cases_valid": observed["case_count"] == len(GEOMETRIES) * len(Q_FRACTIONS) and observed["case_error_count"] == 0,
        "table_bitwise_unchanged": observed["table_bitwise_unchanged"],
        "max_tangent_metric": observed["max_tangent_metric"] <= TANGENT_TOL,
        "max_scaled_base_flux_continuity_residual": observed["max_scaled_base_flux_continuity_residual"] <= CONTINUITY_TOL,
        "max_normal_linear_residual": observed["max_normal_linear_residual"] <= LINEAR_TOL,
        "max_tangent_linear_residual": observed["max_tangent_linear_residual"] <= LINEAR_TOL,
        "cell_switch_count": observed["cell_switch_count"] == 0,
        "tangent_sign_negative_all_cases": observed["nonnegative_tangent_count"] == 0,
        "base_state_bitwise_unchanged_all": observed["base_state_bitwise_unchanged_all"],
        "cost_factorization": observed["matrix_factorizations_per_case"] == [1],
        "cost_normal_backsolve": observed["normal_backsolves_per_case"] == [1],
        "cost_tangent_backsolve": observed["additional_tangent_backsolves_per_case"] == [1],
        "no_production_nonlinear_tangent_trajectory": observed["production_nonlinear_trajectories_for_tangent"] == [0],
    }
    observed["failed_metrics"] = [k for k, ok in tests.items() if not ok]
    observed["pass"] = all(tests.values())
    return observed


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_j1b_same_factorization_column_response.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(j1a.CATALOG.read_text())
    by_name = {r["sfu"]: r for r in catalog["rows"]}
    if material not in j1a.MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {j1a.MATERIALS}")
    result = run_material(by_name[material])
    result.update({
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "J1B_SAME_FACTORIZATION_C1R_COLUMN_RESPONSE_TANGENT",
        "contract": CONTRACT,
        "primary_quantity": "d_h_bottom_d_q_bottom",
        "primary_units": "day",
        "q_bottom_sign": "positive_downward",
        "finite_difference_factors": list(FD_FACTORS),
        "finite_difference_profile_solves_are_qualification_only": True,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k not in ("worst_tangent_case", "errors")}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
