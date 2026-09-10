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

import run_ross01_gate_j1b_r1_smooth_regime_column_response as r1

j1b = r1.j1b

CONTRACT = "F-ROSS01_GATE_J1D_SWAP_QBOT_INTERFACE_MAPPING_CONTRACT.json"
TANGENT_TOL = j1b.TANGENT_TOL
CONTINUITY_TOL = j1b.CONTINUITY_TOL
LINEAR_TOL = j1b.LINEAR_TOL
EXPECTED_CASES_PER_MATERIAL = len(r1.GEOMETRIES) * len(j1b.Q_FRACTIONS)
EXPECTED_FD_PER_MATERIAL = EXPECTED_CASES_PER_MATERIAL * len(j1b.FD_FACTORS)


def float_bytes(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def cell_detail(h: float) -> dict:
    i, f, u = j1b.j1a.table_cell(h)
    return {
        "h_cm": h,
        "cell_index": i,
        "cell_fraction": f,
        "u_log10_negative_head": u,
    }


def expected_qbot_routed_switch(
    material: str,
    geometry: str,
    q_fraction_down: float,
    factor: float,
    switch_indices: list[int],
    heads,
    qbot_plus_heads,
    qbot_minus_heads,
) -> bool:
    """Frozen J1B-R1 O01 seam, with plus/minus reversed in qbot coordinates."""
    if not (
        material == "O01"
        and geometry == "long_dry"
        and q_fraction_down == 0.0
        and factor == 3.0e-5
        and switch_indices == [39]
    ):
        return False
    base = cell_detail(heads[39])
    plus = cell_detail(qbot_plus_heads[39])
    minus = cell_detail(qbot_minus_heads[39])
    return (
        base["cell_index"] == 204
        and plus["cell_index"] == 204
        and minus["cell_index"] == 205
    )


def run_case(
    material: str,
    geometry_name: str,
    n_faces: int,
    h_top: float,
    q_fraction_down: float,
    table,
    ksat: float,
) -> dict:
    k_top = float(j1b.j1a.c1r.base.c1.core.k_of_h(h_top))

    # Frozen J1B-R1 physical base state is parameterized by downward-positive flux.
    q_down = q_fraction_down * k_top
    # Native SWAP 4.3.1 interface convention: positive qbot is upward/inflow from below.
    qbot = -q_down

    heads = j1b.generate_profile(h_top, n_faces, q_down, table)
    snapshot = float_bytes(heads)
    signature = j1b.cell_signature(heads)

    lower, diag, upper, residual, faces = j1b.assemble_system(heads, q_down, table)
    factorization = j1b.j0.factor_tridiagonal(lower, diag, upper)

    normal_rhs = [-r for r in residual]
    normal_correction = j1b.j0.solve_factored(factorization, normal_rhs)

    # J1B residual is q_face_down - q_down. Since q_down = -qbot,
    # dF/dqbot = +e_N and J dh/dqbot = -e_N.
    tangent_rhs = [0.0] * n_faces
    tangent_rhs[-1] = -1.0
    qbot_response = j1b.j0.solve_factored(factorization, tangent_rhs)
    tangent_qbot = qbot_response[-1]

    normal_linear_residual = j1b.j0.base.matrix_residual(
        lower, diag, upper, normal_correction, normal_rhs
    )
    tangent_linear_residual = j1b.j0.base.matrix_residual(
        lower, diag, upper, qbot_response, tangent_rhs
    )

    scale_q = max(ksat, abs(q_down), 1.0e-300)
    continuity_scaled = max(abs(face["q"] - q_down) for face in faces) / scale_q

    smooth_metrics: list[float] = []
    fd_rows: list[dict] = []
    routed: list[dict] = []
    unexpected: list[dict] = []
    nonfinite_count = 0

    for factor in j1b.FD_FACTORS:
        q_scale = max(abs(qbot), k_top, 1.0e-12 * ksat)
        dqbot = factor * q_scale

        qbot_plus = qbot + dqbot
        qbot_minus = qbot - dqbot
        q_down_for_qbot_plus = -qbot_plus
        q_down_for_qbot_minus = -qbot_minus

        plus = j1b.generate_profile(
            h_top, n_faces, q_down_for_qbot_plus, table
        )
        minus = j1b.generate_profile(
            h_top, n_faces, q_down_for_qbot_minus, table
        )

        plus_sig = j1b.cell_signature(plus)
        minus_sig = j1b.cell_signature(minus)
        switch_indices = [
            idx
            for idx, (base_cell, plus_cell, minus_cell) in enumerate(
                zip(signature, plus_sig, minus_sig)
            )
            if base_cell != plus_cell or base_cell != minus_cell
        ]

        fd = (plus[-1] - minus[-1]) / (2.0 * dqbot)
        if not math.isfinite(fd) or not math.isfinite(tangent_qbot):
            nonfinite_count += 1

        row = {
            "factor": factor,
            "delta_qbot_cm_per_day": dqbot,
            "qbot_plus_cm_per_day": qbot_plus,
            "qbot_minus_cm_per_day": qbot_minus,
            "q_down_for_qbot_plus_cm_per_day": q_down_for_qbot_plus,
            "q_down_for_qbot_minus_cm_per_day": q_down_for_qbot_minus,
            "tangent_fd_day": fd,
            "switch_indices": switch_indices,
        }

        if switch_indices:
            row["switch_details"] = [
                {
                    "head_index": idx,
                    "base": cell_detail(heads[idx]),
                    "qbot_plus": cell_detail(plus[idx]),
                    "qbot_minus": cell_detail(minus[idx]),
                }
                for idx in switch_indices
            ]
            if expected_qbot_routed_switch(
                material,
                geometry_name,
                q_fraction_down,
                factor,
                switch_indices,
                heads,
                plus,
                minus,
            ):
                row["classification"] = (
                    "ROUTED_KNOWN_TABLE_NODE_TRANSITION_NOT_SMOOTH_FD_METRIC"
                )
                routed.append(row)
            else:
                row["classification"] = "UNEXPECTED_TABLE_CELL_TRANSITION"
                unexpected.append(row)
        else:
            metric = j1b.tangent_metric(tangent_qbot, fd)
            row["classification"] = "SMOOTH_SYMMETRIC_QBOT_FD_ORACLE"
            row["tangent_metric"] = metric
            smooth_metrics.append(metric)

        fd_rows.append(row)

    return {
        "material": material,
        "geometry": geometry_name,
        "n_faces": n_faces,
        "h_top_cm": h_top,
        "h_bottom_cm": heads[-1],
        "q_fraction_down_of_K_top": q_fraction_down,
        "q_down_cm_per_day": q_down,
        "qbot_swap_cm_per_day": qbot,
        "q_down_plus_qbot_zero": q_down + qbot,
        "K_top_cm_per_day": k_top,
        "d_h_bottom_d_qbot_swap_day": tangent_qbot,
        "tangent_sign_positive": tangent_qbot > 0.0,
        "smooth_fd_comparison_count": len(smooth_metrics),
        "routed_fd_comparison_count": len(routed),
        "unexpected_fd_switch_count": len(unexpected),
        "max_smooth_tangent_metric": max(smooth_metrics) if smooth_metrics else None,
        "fd_rows": fd_rows,
        "scaled_base_flux_continuity_residual": continuity_scaled,
        "normal_linear_residual": normal_linear_residual,
        "qbot_tangent_linear_residual": tangent_linear_residual,
        "max_abs_uncommitted_normal_correction_cm": max(abs(x) for x in normal_correction),
        "base_state_bitwise_unchanged": float_bytes(heads) == snapshot,
        "nonfinite_count": nonfinite_count,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "additional_qbot_tangent_backsolves": 1,
        "production_nonlinear_trajectories_for_tangent": 0,
        "qualification_qbot_fd_profile_solves": 2 * len(j1b.FD_FACTORS),
    }


def run_material(row: dict) -> dict:
    j1b.j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    ksat = float(j1b.j1a.c1r.base.c1.core.KSAT)
    table, preprocessing_seconds, generation_failures = j1b.j1a.c1r.base.generate_table(
        j1b.j1a.N
    )

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

    for geometry_name, n_faces, h_top in r1.GEOMETRIES:
        for q_fraction_down in j1b.Q_FRACTIONS:
            try:
                cases.append(
                    run_case(
                        material,
                        geometry_name,
                        n_faces,
                        h_top,
                        q_fraction_down,
                        table,
                        ksat,
                    )
                )
            except Exception as exc:
                errors.append(
                    {
                        "geometry": geometry_name,
                        "n_faces": n_faces,
                        "h_top_cm": h_top,
                        "q_fraction_down_of_K_top": q_fraction_down,
                        "error": repr(exc),
                    }
                )

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    if not cases:
        return {
            "material": material,
            "pass": False,
            "failed_metrics": ["no_valid_cases"],
            "errors": errors,
        }

    smooth_metrics = [
        case["max_smooth_tangent_metric"]
        for case in cases
        if case["max_smooth_tangent_metric"] is not None
    ]

    routed_expected = 1 if material == "O01" else 0
    smooth_expected = EXPECTED_FD_PER_MATERIAL - routed_expected

    observed = {
        "material": material,
        "case_count": len(cases),
        "case_error_count": len(errors),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "finite_difference_comparison_count": sum(
            len(case["fd_rows"]) for case in cases
        ),
        "smooth_fd_comparison_count": sum(
            case["smooth_fd_comparison_count"] for case in cases
        ),
        "routed_fd_comparison_count": sum(
            case["routed_fd_comparison_count"] for case in cases
        ),
        "unexpected_fd_switch_count": sum(
            case["unexpected_fd_switch_count"] for case in cases
        ),
        "max_smooth_tangent_metric": max(smooth_metrics) if smooth_metrics else None,
        "max_abs_q_down_plus_qbot": max(
            abs(case["q_down_plus_qbot_zero"]) for case in cases
        ),
        "max_scaled_base_flux_continuity_residual": max(
            case["scaled_base_flux_continuity_residual"] for case in cases
        ),
        "max_normal_linear_residual": max(
            case["normal_linear_residual"] for case in cases
        ),
        "max_qbot_tangent_linear_residual": max(
            case["qbot_tangent_linear_residual"] for case in cases
        ),
        "nonpositive_qbot_tangent_count": sum(
            not case["tangent_sign_positive"] for case in cases
        ),
        "nonfinite_count": sum(case["nonfinite_count"] for case in cases),
        "base_state_bitwise_unchanged_all": all(
            case["base_state_bitwise_unchanged"] for case in cases
        ),
        "matrix_factorizations_per_case": sorted(
            set(case["matrix_factorizations"] for case in cases)
        ),
        "normal_backsolves_per_case": sorted(
            set(case["normal_backsolves"] for case in cases)
        ),
        "additional_qbot_tangent_backsolves_per_case": sorted(
            set(case["additional_qbot_tangent_backsolves"] for case in cases)
        ),
        "production_nonlinear_trajectories_for_tangent": sorted(
            set(case["production_nonlinear_trajectories_for_tangent"] for case in cases)
        ),
        "worst_smooth_tangent_case": max(
            (
                case
                for case in cases
                if case["max_smooth_tangent_metric"] is not None
            ),
            key=lambda case: case["max_smooth_tangent_metric"],
        ),
        "routed_rows": [
            {
                "geometry": case["geometry"],
                "q_fraction_down_of_K_top": case["q_fraction_down_of_K_top"],
                "fd_row": fd,
            }
            for case in cases
            for fd in case["fd_rows"]
            if fd["classification"]
            == "ROUTED_KNOWN_TABLE_NODE_TRANSITION_NOT_SMOOTH_FD_METRIC"
        ],
        "unexpected_rows": [
            {
                "geometry": case["geometry"],
                "q_fraction_down_of_K_top": case["q_fraction_down_of_K_top"],
                "fd_row": fd,
            }
            for case in cases
            for fd in case["fd_rows"]
            if fd["classification"] == "UNEXPECTED_TABLE_CELL_TRANSITION"
        ],
        "errors": errors,
    }

    tests = {
        "all_frozen_base_cases_valid": (
            observed["case_count"] == EXPECTED_CASES_PER_MATERIAL
            and observed["case_error_count"] == 0
        ),
        "all_frozen_fd_comparisons_present": (
            observed["finite_difference_comparison_count"]
            == EXPECTED_FD_PER_MATERIAL
        ),
        "frozen_routed_count": (
            observed["routed_fd_comparison_count"] == routed_expected
        ),
        "frozen_smooth_count": (
            observed["smooth_fd_comparison_count"] == smooth_expected
        ),
        "no_unexpected_regime_switch": observed["unexpected_fd_switch_count"] == 0,
        "exact_q_down_qbot_mapping": observed["max_abs_q_down_plus_qbot"] == 0.0,
        "smooth_qbot_fd_tangent_metric": (
            observed["max_smooth_tangent_metric"] is not None
            and observed["max_smooth_tangent_metric"] <= TANGENT_TOL
        ),
        "qbot_tangent_positive_all_cases": observed["nonpositive_qbot_tangent_count"] == 0,
        "base_flux_continuity": (
            observed["max_scaled_base_flux_continuity_residual"] <= CONTINUITY_TOL
        ),
        "normal_linear_residual": observed["max_normal_linear_residual"] <= LINEAR_TOL,
        "qbot_tangent_linear_residual": (
            observed["max_qbot_tangent_linear_residual"] <= LINEAR_TOL
        ),
        "all_values_finite": observed["nonfinite_count"] == 0,
        "base_state_bitwise_unchanged": observed["base_state_bitwise_unchanged_all"],
        "table_bitwise_unchanged": observed["table_bitwise_unchanged"],
        "one_factorization": observed["matrix_factorizations_per_case"] == [1],
        "one_normal_backsolve": observed["normal_backsolves_per_case"] == [1],
        "one_additional_qbot_tangent_backsolve": (
            observed["additional_qbot_tangent_backsolves_per_case"] == [1]
        ),
        "no_production_nonlinear_tangent_trajectory": (
            observed["production_nonlinear_trajectories_for_tangent"] == [0]
        ),
    }

    observed["tests"] = tests
    observed["failed_metrics"] = [name for name, ok in tests.items() if not ok]
    observed["pass"] = all(tests.values())
    return observed


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: run_ross01_gate_j1d_swap_qbot_interface_mapping.py MATERIAL OUTPUT.json"
        )

    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(j1b.j1a.CATALOG.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}

    if material not in j1b.j1a.MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {j1b.j1a.MATERIALS}")

    result = run_material(by_name[material])
    result.update(
        {
            "schema_version": 1,
            "workstream": "F-ROSS",
            "work_unit": "F-ROSS01",
            "gate": "J1D_SWAP_QBOT_INTERFACE_MAPPING",
            "contract": CONTRACT,
            "production_implementation": False,
            "qualification_scope": "coordinate_and_sign_mapping_only",
            "primary_quantity": "d_h_bottom_d_qbot_swap",
            "primary_units": "day",
            "qbot_swap_sign": "positive_upward_inflow_from_below",
            "q_down_harness_sign": "positive_downward",
            "coordinate_mapping": "q_down=-qbot_swap",
            "same_factorization_qbot_tangent_rhs_last_entry": -1.0,
            "finite_difference_factors": list(j1b.FD_FACTORS),
            "finite_difference_profile_solves_are_qualification_only": True,
            "legacy_source_authority": {
                "nested_source_zip_sha256": "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151",
                "headcalc_f90_sha256": "db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5",
                "boundbottom_f90_sha256": "5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e",
                "fluxes_f90_sha256": "b28b163520bc2ed873d98d4e0308d7b02a33577ee81b12a7f4bc1bc4cf746550",
            },
            "piecewise_tangent_policy_inherited_from_j1c": {
                "strict_cell_interior": "QUALIFIED_ANALYTIC_DERIVATIVE_AND_SAME_FACTORIZATION_RESPONSE",
                "internal_node_line": "CONTINUOUS_FLUX_PIECEWISE_ONE_SIDED_DERIVATIVE_NO_UNIQUE_SMOOTH_TANGENT",
                "trial_crosses_node": "REGIME_SWITCH_ROUTE_OR_FALLBACK_DO_NOT_AVERAGE",
                "exact_equal_head_shortcut": "SEPARATE_BRANCH_NO_CROSS_BRANCH_TANGENT_CLAIM",
                "head_envelope_endpoint": "NO_UNIQUE_DERIVATIVE_CLAIM",
            },
        }
    )

    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(
        json.dumps(
            {
                key: value
                for key, value in result.items()
                if key
                not in (
                    "worst_smooth_tangent_case",
                    "routed_rows",
                    "unexpected_rows",
                    "errors",
                )
            },
            sort_keys=True,
        ),
        flush=True,
    )
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
