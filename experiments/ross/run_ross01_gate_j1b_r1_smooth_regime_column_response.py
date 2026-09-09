from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_j1b_same_factorization_column_response as j1b

CONTRACT = "F-ROSS01_GATE_J1B_R1_SMOOTH_REGIME_COLUMN_RESPONSE_CONTRACT.json"
GEOMETRIES = (
    ("wet_short", 2, -50.0),
    ("mid", 4, -200.0),
    ("dry_midcell", 16, -1019.3734859388727),
    ("long_dry", 64, -3000.0),
)
EXPECTED_BASE_CASES = 72
EXPECTED_FD_COMPARISONS = 144
EXPECTED_ROUTED = 1
EXPECTED_SMOOTH = 143


def float_bytes(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def cell_detail(h: float) -> dict:
    i, f, u = j1b.j1a.table_cell(h)
    return {"h_cm": h, "cell_index": i, "cell_fraction": f, "u_log10_negative_head": u}


def expected_routed_switch(material: str, geometry: str, q_fraction: float,
                           factor: float, switch_indices: list[int],
                           heads, plus, minus) -> bool:
    if not (
        material == "O01"
        and geometry == "long_dry"
        and q_fraction == 0.0
        and factor == 3.0e-5
        and switch_indices == [39]
    ):
        return False
    b = cell_detail(heads[39])
    p = cell_detail(plus[39])
    m = cell_detail(minus[39])
    return (
        b["cell_index"] == 204
        and m["cell_index"] == 204
        and p["cell_index"] == 205
    )


def run_case(material: str, geometry_name: str, n_faces: int, h_top: float,
             q_fraction: float, table, ksat: float):
    k_top = float(j1b.j1a.c1r.base.c1.core.k_of_h(h_top))
    q_bottom = q_fraction * k_top
    heads = j1b.generate_profile(h_top, n_faces, q_bottom, table)
    snapshot = float_bytes(heads)
    signature = j1b.cell_signature(heads)
    lower, diag, upper, residual, faces = j1b.assemble_system(heads, q_bottom, table)
    factorization = j1b.j0.factor_tridiagonal(lower, diag, upper)

    normal_rhs = [-r for r in residual]
    normal_correction = j1b.j0.solve_factored(factorization, normal_rhs)
    tangent_rhs = [0.0] * n_faces
    tangent_rhs[-1] = 1.0
    response = j1b.j0.solve_factored(factorization, tangent_rhs)
    tangent = response[-1]

    normal_linear_residual = j1b.j0.base.matrix_residual(lower, diag, upper, normal_correction, normal_rhs)
    tangent_linear_residual = j1b.j0.base.matrix_residual(lower, diag, upper, response, tangent_rhs)
    scale_q = max(ksat, abs(q_bottom), 1.0e-300)
    continuity_scaled = max(abs(f["q"] - q_bottom) for f in faces) / scale_q

    smooth_metrics = []
    fd_rows = []
    routed = []
    unexpected = []
    nonfinite_count = 0

    for factor in j1b.FD_FACTORS:
        q_scale = max(abs(q_bottom), k_top, 1.0e-12 * ksat)
        dq = factor * q_scale
        plus = j1b.generate_profile(h_top, n_faces, q_bottom + dq, table)
        minus = j1b.generate_profile(h_top, n_faces, q_bottom - dq, table)
        plus_sig = j1b.cell_signature(plus)
        minus_sig = j1b.cell_signature(minus)
        switch_indices = [
            idx for idx, (b, p, m) in enumerate(zip(signature, plus_sig, minus_sig))
            if b != p or b != m
        ]
        fd = (plus[-1] - minus[-1]) / (2.0 * dq)
        if not math.isfinite(fd) or not math.isfinite(tangent):
            nonfinite_count += 1

        row = {
            "factor": factor,
            "delta_q_cm_per_day": dq,
            "tangent_fd_day": fd,
            "switch_indices": switch_indices,
        }
        if switch_indices:
            row["switch_details"] = [
                {
                    "head_index": idx,
                    "base": cell_detail(heads[idx]),
                    "plus": cell_detail(plus[idx]),
                    "minus": cell_detail(minus[idx]),
                }
                for idx in switch_indices
            ]
            if expected_routed_switch(
                material, geometry_name, q_fraction, factor,
                switch_indices, heads, plus, minus
            ):
                row["classification"] = "ROUTED_KNOWN_TABLE_NODE_TRANSITION_NOT_SMOOTH_FD_METRIC"
                routed.append(row)
            else:
                row["classification"] = "UNEXPECTED_TABLE_CELL_TRANSITION"
                unexpected.append(row)
        else:
            metric = j1b.tangent_metric(tangent, fd)
            row["classification"] = "SMOOTH_SYMMETRIC_FD_ORACLE"
            row["tangent_metric"] = metric
            smooth_metrics.append(metric)
        fd_rows.append(row)

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
        "smooth_fd_comparison_count": len(smooth_metrics),
        "routed_fd_comparison_count": len(routed),
        "unexpected_fd_switch_count": len(unexpected),
        "max_smooth_tangent_metric": max(smooth_metrics) if smooth_metrics else None,
        "fd_rows": fd_rows,
        "scaled_base_flux_continuity_residual": continuity_scaled,
        "normal_linear_residual": normal_linear_residual,
        "tangent_linear_residual": tangent_linear_residual,
        "max_abs_uncommitted_normal_correction_cm": max(abs(x) for x in normal_correction),
        "base_state_bitwise_unchanged": float_bytes(heads) == snapshot,
        "nonfinite_count": nonfinite_count,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "additional_tangent_backsolves": 1,
        "table_derivative_evaluations": n_faces,
        "production_table_lookup_work": n_faces,
        "production_fallback_or_branch_count": 0,
        "production_nonlinear_trajectories_for_tangent": 0,
        "qualification_fd_profile_solves": 2 * len(j1b.FD_FACTORS),
    }


def run_material(row: dict) -> dict:
    j1b.j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    ksat = float(j1b.j1a.c1r.base.c1.core.KSAT)
    table, preprocessing_seconds, generation_failures = j1b.j1a.c1r.base.generate_table(j1b.j1a.N)
    if generation_failures:
        return {
            "material": material,
            "pass": False,
            "failed_metrics": ["table_generation_failures"],
            "table_generation_failures": len(generation_failures),
        }
    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    cases = []
    errors = []
    for geometry_name, n_faces, h_top in GEOMETRIES:
        for q_fraction in j1b.Q_FRACTIONS:
            try:
                cases.append(run_case(
                    material, geometry_name, n_faces, h_top,
                    q_fraction, table, ksat
                ))
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
        return {
            "material": material,
            "pass": False,
            "failed_metrics": ["no_valid_cases"],
            "errors": errors,
        }

    smooth_metrics = [
        c["max_smooth_tangent_metric"] for c in cases
        if c["max_smooth_tangent_metric"] is not None
    ]
    observed = {
        "material": material,
        "case_count": len(cases),
        "case_error_count": len(errors),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "smooth_fd_comparison_count": sum(c["smooth_fd_comparison_count"] for c in cases),
        "routed_fd_comparison_count": sum(c["routed_fd_comparison_count"] for c in cases),
        "unexpected_fd_switch_count": sum(c["unexpected_fd_switch_count"] for c in cases),
        "max_smooth_tangent_metric": max(smooth_metrics) if smooth_metrics else None,
        "max_scaled_base_flux_continuity_residual": max(c["scaled_base_flux_continuity_residual"] for c in cases),
        "max_normal_linear_residual": max(c["normal_linear_residual"] for c in cases),
        "max_tangent_linear_residual": max(c["tangent_linear_residual"] for c in cases),
        "nonnegative_tangent_count": sum(not c["tangent_sign_negative"] for c in cases),
        "nonfinite_count": sum(c["nonfinite_count"] for c in cases),
        "base_state_bitwise_unchanged_all": all(c["base_state_bitwise_unchanged"] for c in cases),
        "matrix_factorizations_per_case": sorted(set(c["matrix_factorizations"] for c in cases)),
        "normal_backsolves_per_case": sorted(set(c["normal_backsolves"] for c in cases)),
        "additional_tangent_backsolves_per_case": sorted(set(c["additional_tangent_backsolves"] for c in cases)),
        "table_derivative_evaluations_by_geometry": {
            name: n for name, n, _ in GEOMETRIES
        },
        "production_table_lookup_work_by_geometry": {
            name: n for name, n, _ in GEOMETRIES
        },
        "production_fallback_or_branch_count": sum(c["production_fallback_or_branch_count"] for c in cases),
        "production_nonlinear_trajectories_for_tangent": sorted(set(c["production_nonlinear_trajectories_for_tangent"] for c in cases)),
        "worst_smooth_tangent_case": max(
            (c for c in cases if c["max_smooth_tangent_metric"] is not None),
            key=lambda c: c["max_smooth_tangent_metric"],
        ),
        "routed_rows": [
            {
                "geometry": c["geometry"],
                "q_fraction_of_K_top": c["q_fraction_of_K_top"],
                "fd_row": fd,
            }
            for c in cases for fd in c["fd_rows"]
            if fd["classification"] == "ROUTED_KNOWN_TABLE_NODE_TRANSITION_NOT_SMOOTH_FD_METRIC"
        ],
        "unexpected_rows": [
            {
                "geometry": c["geometry"],
                "q_fraction_of_K_top": c["q_fraction_of_K_top"],
                "fd_row": fd,
            }
            for c in cases for fd in c["fd_rows"]
            if fd["classification"] == "UNEXPECTED_TABLE_CELL_TRANSITION"
        ],
        "errors": errors,
    }
    expected_material_cases = len(GEOMETRIES) * len(j1b.Q_FRACTIONS)
    expected_routed_material = 1 if material == "O01" else 0
    expected_smooth_material = 2 * expected_material_cases - expected_routed_material
    tests = {
        "all_base_cases_valid": observed["case_count"] == expected_material_cases and observed["case_error_count"] == 0,
        "table_bitwise_unchanged": observed["table_bitwise_unchanged"],
        "smooth_fd_count": observed["smooth_fd_comparison_count"] == expected_smooth_material,
        "known_routed_switch_count": observed["routed_fd_comparison_count"] == expected_routed_material,
        "unexpected_fd_switch_count": observed["unexpected_fd_switch_count"] == 0,
        "max_smooth_tangent_metric": observed["max_smooth_tangent_metric"] is not None and observed["max_smooth_tangent_metric"] <= j1b.TANGENT_TOL,
        "max_scaled_base_flux_continuity_residual": observed["max_scaled_base_flux_continuity_residual"] <= j1b.CONTINUITY_TOL,
        "max_normal_linear_residual": observed["max_normal_linear_residual"] <= j1b.LINEAR_TOL,
        "max_tangent_linear_residual": observed["max_tangent_linear_residual"] <= j1b.LINEAR_TOL,
        "tangent_sign_negative_all_cases": observed["nonnegative_tangent_count"] == 0,
        "nonfinite_count": observed["nonfinite_count"] == 0,
        "base_state_bitwise_unchanged_all": observed["base_state_bitwise_unchanged_all"],
        "cost_factorization": observed["matrix_factorizations_per_case"] == [1],
        "cost_normal_backsolve": observed["normal_backsolves_per_case"] == [1],
        "cost_tangent_backsolve": observed["additional_tangent_backsolves_per_case"] == [1],
        "cost_no_fallback_or_branch": observed["production_fallback_or_branch_count"] == 0,
        "no_production_nonlinear_tangent_trajectory": observed["production_nonlinear_trajectories_for_tangent"] == [0],
    }
    observed["failed_metrics"] = [k for k, ok in tests.items() if not ok]
    observed["pass"] = all(tests.values())
    return observed


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_j1b_r1_smooth_regime_column_response.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(j1b.j1a.CATALOG.read_text())
    by_name = {r["sfu"]: r for r in catalog["rows"]}
    if material not in j1b.j1a.MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {j1b.j1a.MATERIALS}")
    result = run_material(by_name[material])
    result.update({
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "J1B_R1_SMOOTH_REGIME_C1R_COLUMN_RESPONSE_TANGENT",
        "contract": CONTRACT,
        "primary_quantity": "d_h_bottom_d_q_bottom",
        "primary_units": "day",
        "q_bottom_sign": "positive_downward",
        "finite_difference_factors_unchanged": list(j1b.FD_FACTORS),
        "finite_difference_profile_solves_are_qualification_only": True,
        "production_implementation": False,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        k: v for k, v in result.items()
        if k not in ("worst_smooth_tangent_case", "routed_rows", "unexpected_rows", "errors")
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
