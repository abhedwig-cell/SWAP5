from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_j1a_real_table_face_derivative as j1a

CONTRACT = "F-ROSS01_GATE_J1C_BOUNDARY_DERIVATIVE_CHARACTERIZATION_CONTRACT.json"
NODE_INDICES = (1, 60, 120, 180, 205, 239)
OTHER_U = 2.345
HIGH_K_U_PAIRS = ((0.025, 0.075), (0.075, 0.025))
DRY_U_PAIRS = ((3.925, 3.975), (3.975, 3.925))
EQUAL_U = (0.5083333333333333, 1.5083333333333333, 2.5083333333333333, 3.5083333333333333)
HYDRO_U_A = (1.5083333333333333, 2.5083333333333333, 3.5083333333333333)
NODE_FLUX_TOL = 1.0e-12
HYDRO_TOL = 1.0e-12


def h_from_u(u: float) -> float:
    return -(10.0 ** u)


def cell_from_u(u: float) -> tuple[int, float]:
    x = j1a.DXDU * u
    i = min(j1a.N - 2, max(0, int(math.floor(x))))
    return i, x - i


def eval_cell_coordinates(h_a: float, h_b: float, ia: int, fa: float,
                          ib: int, fb: float, table) -> dict:
    l00 = float(table[ia, ib])
    l10 = float(table[ia + 1, ib])
    l01 = float(table[ia, ib + 1])
    l11 = float(table[ia + 1, ib + 1])
    ell = (
        (1.0 - fa) * (1.0 - fb) * l00
        + fa * (1.0 - fb) * l10
        + (1.0 - fa) * fb * l01
        + fa * fb * l11
    )
    dell_du_a = j1a.DXDU * ((1.0 - fb) * (l10 - l00) + fb * (l11 - l01))
    dell_du_b = j1a.DXDU * ((1.0 - fa) * (l01 - l00) + fa * (l11 - l10))
    mobility = math.exp(ell)
    g = j1a.c1r.base.LENGTH_CM + h_a - h_b
    q = g * mobility
    dq_a = mobility * (1.0 + g * dell_du_a / (j1a.LN10 * h_a))
    dq_b = mobility * (-1.0 + g * dell_du_b / (j1a.LN10 * h_b))
    return {
        "q": q,
        "dq_dh_a": dq_a,
        "dq_dh_b": dq_b,
        "mobility": mobility,
    }


def scaled_difference(a: float, b: float, scale: float) -> float:
    return abs(a - b) / max(abs(a), abs(b), scale, 1.0e-300)


def node_rows(table, ksat: float) -> list[dict]:
    rows = []
    other_h = h_from_u(OTHER_U)
    other_i, other_f = cell_from_u(OTHER_U)
    for node in NODE_INDICES:
        u_node = node / j1a.DXDU
        h_node = h_from_u(u_node)
        for axis in ("a", "b"):
            if axis == "a":
                left = eval_cell_coordinates(
                    h_node, other_h,
                    node - 1, 1.0, other_i, other_f, table
                )
                right = eval_cell_coordinates(
                    h_node, other_h,
                    node, 0.0, other_i, other_f, table
                )
                crossing_left = left["dq_dh_a"]
                crossing_right = right["dq_dh_a"]
                transverse_left = left["dq_dh_b"]
                transverse_right = right["dq_dh_b"]
            else:
                left = eval_cell_coordinates(
                    other_h, h_node,
                    other_i, other_f, node - 1, 1.0, table
                )
                right = eval_cell_coordinates(
                    other_h, h_node,
                    other_i, other_f, node, 0.0, table
                )
                crossing_left = left["dq_dh_b"]
                crossing_right = right["dq_dh_b"]
                transverse_left = left["dq_dh_a"]
                transverse_right = right["dq_dh_a"]
            rows.append({
                "node_index": node,
                "axis": axis,
                "u_node": u_node,
                "h_node_cm": h_node,
                "other_u": OTHER_U,
                "other_h_cm": other_h,
                "q_left": left["q"],
                "q_right": right["q"],
                "scaled_flux_jump": scaled_difference(left["q"], right["q"], 1.0e-12 * ksat),
                "crossing_derivative_left": crossing_left,
                "crossing_derivative_right": crossing_right,
                "crossing_derivative_jump_metric": scaled_difference(crossing_left, crossing_right, 1.0e-8 * ksat),
                "transverse_derivative_left": transverse_left,
                "transverse_derivative_right": transverse_right,
                "transverse_derivative_jump_metric": scaled_difference(transverse_left, transverse_right, 1.0e-8 * ksat),
            })
    return rows


def tail_rows(table) -> list[dict]:
    rows = []
    for label, pairs in (("high_conductivity_side", HIGH_K_U_PAIRS), ("dry_tail", DRY_U_PAIRS)):
        for ua, ub in pairs:
            ha, hb = h_from_u(ua), h_from_u(ub)
            value = j1a.table_flux_and_derivatives(ha, hb, table)
            rows.append({
                "kind": label,
                "u_a": ua,
                "u_b": ub,
                "h_a_cm": ha,
                "h_b_cm": hb,
                "q": value["q"],
                "dq_dh_a": value["dq_dh_a"],
                "dq_dh_b": value["dq_dh_b"],
                "cell_a": value["ia"],
                "cell_b": value["ib"],
            })
    return rows


def equal_head_rows(table, ksat: float) -> list[dict]:
    rows = []
    for u in EQUAL_U:
        h = h_from_u(u)
        generic = j1a.table_flux_and_derivatives(h, h, table)
        shortcut = float(j1a.c1r.base.c1.core.k_of_h(h))
        state = float(j1a.c1r.base.c1.core.s_of_h(h))
        production_q, prod_ha, prod_hb = j1a.c1r.lookup(state, state, table, j1a.N)
        rows.append({
            "u": u,
            "h_cm": h,
            "generic_bilinear_limit_q": generic["q"],
            "production_equal_head_shortcut_q": float(production_q),
            "constitutive_K_q": shortcut,
            "shortcut_vs_K_relative_error": abs(float(production_q) - shortcut) / max(abs(shortcut), 1.0e-300),
            "generic_limit_vs_shortcut_relative_gap": abs(generic["q"] - shortcut) / max(abs(shortcut), 1.0e-300),
            "generic_dq_dh_a": generic["dq_dh_a"],
            "generic_dq_dh_b": generic["dq_dh_b"],
            "generic_diagonal_derivative_sum": generic["dq_dh_a"] + generic["dq_dh_b"],
            "reconstructed_equal_heads_identical": prod_ha == prod_hb,
            "scaled_generic_q": abs(generic["q"]) / max(ksat, 1.0e-300),
        })
    return rows


def hydro_rows(table, ksat: float) -> list[dict]:
    rows = []
    for ua in HYDRO_U_A:
        ha = h_from_u(ua)
        hb = ha + j1a.c1r.base.LENGTH_CM
        value = j1a.table_flux_and_derivatives(ha, hb, table)
        antisym = abs(value["dq_dh_a"] + value["dq_dh_b"]) / max(
            abs(value["dq_dh_a"]), abs(value["dq_dh_b"]), 1.0e-8 * ksat, 1.0e-300
        )
        rows.append({
            "u_a": ua,
            "h_a_cm": ha,
            "h_b_cm": hb,
            "q": value["q"],
            "scaled_abs_q": abs(value["q"]) / max(ksat, 1.0e-300),
            "dq_dh_a": value["dq_dh_a"],
            "dq_dh_b": value["dq_dh_b"],
            "scaled_derivative_antisymmetry": antisym,
        })
    return rows


def all_finite(rows: list[dict]) -> bool:
    for row in rows:
        for value in row.values():
            if isinstance(value, float) and not math.isfinite(value):
                return False
    return True


def run_material(row: dict) -> dict:
    j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    ksat = float(j1a.c1r.base.c1.core.KSAT)
    table, preprocessing_seconds, generation_failures = j1a.c1r.base.generate_table(j1a.N)
    if generation_failures:
        return {
            "material": material,
            "pass": False,
            "failed_metrics": ["table_generation_failures"],
            "table_generation_failures": len(generation_failures),
        }
    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()

    nodes = node_rows(table, ksat)
    tails = tail_rows(table)
    equal = equal_head_rows(table, ksat)
    hydro = hydro_rows(table, ksat)

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    max_node_flux = max(r["scaled_flux_jump"] for r in nodes)
    max_cross_jump = max(r["crossing_derivative_jump_metric"] for r in nodes)
    max_trans_jump = max(r["transverse_derivative_jump_metric"] for r in nodes)
    max_equal_gap = max(r["generic_limit_vs_shortcut_relative_gap"] for r in equal)
    max_shortcut_err = max(r["shortcut_vs_K_relative_error"] for r in equal)
    max_hydro_q = max(r["scaled_abs_q"] for r in hydro)
    max_hydro_antisym = max(r["scaled_derivative_antisymmetry"] for r in hydro)
    finite = all_finite(nodes + tails + equal + hydro)

    tests = {
        "table_bitwise_unchanged": table_before == table_after,
        "node_flux_continuity": max_node_flux <= NODE_FLUX_TOL,
        "all_characterization_values_finite": finite,
        "hydrostatic_flux": max_hydro_q <= HYDRO_TOL,
        "hydrostatic_derivative_antisymmetry": max_hydro_antisym <= HYDRO_TOL,
        "production_equal_head_shortcut_matches_K": max_shortcut_err <= 1.0e-12,
    }
    return {
        "material": material,
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "node_case_count": len(nodes),
        "tail_case_count": len(tails),
        "equal_head_case_count": len(equal),
        "hydrostatic_case_count": len(hydro),
        "max_scaled_internal_node_flux_jump": max_node_flux,
        "max_crossing_derivative_jump_metric_characterization": max_cross_jump,
        "max_transverse_derivative_jump_metric_characterization": max_trans_jump,
        "max_equal_head_generic_limit_vs_shortcut_relative_gap_characterization": max_equal_gap,
        "max_equal_head_shortcut_vs_K_relative_error": max_shortcut_err,
        "max_hydrostatic_scaled_abs_q": max_hydro_q,
        "max_hydrostatic_scaled_derivative_antisymmetry": max_hydro_antisym,
        "node_rows": nodes,
        "tail_rows": tails,
        "equal_head_rows": equal,
        "hydrostatic_rows": hydro,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "all_characterization_values_finite": finite,
        "localized_O01_transition_node_in_node_set": 205 in NODE_INDICES,
        "derivative_smoothing_or_averaging_used": False,
        "head_envelope_endpoint_derivative_claim": "EXCLUDED_FAIL_CLOSED_OR_EXPLICIT_ONE_SIDED_POLICY_REQUIRED",
        "failed_metrics": [k for k, ok in tests.items() if not ok],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_j1c_boundary_derivative_characterization.py MATERIAL OUTPUT.json")
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
        "gate": "J1C_C1R_BOUNDARY_DERIVATIVE_CHARACTERIZATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "piecewise_tangent_policy": {
            "strict_cell_interior": "QUALIFIED_ANALYTIC_DERIVATIVE_AND_SAME_FACTORIZATION_RESPONSE",
            "internal_node_line": "CONTINUOUS_FLUX_PIECEWISE_ONE_SIDED_DERIVATIVE_NO_UNIQUE_SMOOTH_TANGENT",
            "trial_crosses_node": "REGIME_SWITCH_ROUTE_OR_FALLBACK_DO_NOT_AVERAGE",
            "exact_equal_head_shortcut": "SEPARATE_BRANCH_NO_CROSS_BRANCH_TANGENT_CLAIM",
            "head_envelope_endpoint": "NO_UNIQUE_DERIVATIVE_CLAIM",
        },
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        k: v for k, v in result.items()
        if k not in ("node_rows", "tail_rows", "equal_head_rows", "hydrostatic_rows")
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
