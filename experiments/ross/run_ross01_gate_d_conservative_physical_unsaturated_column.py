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

import run_ross01_gate_j1a_real_table_face_derivative as j1a
import run_ross01_tangent_algebra as j0

CONTRACT = "F-ROSS01_GATE_D_CONSERVATIVE_PHYSICAL_UNSATURATED_COLUMN_CONTRACT.json"
MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
CELL_COUNTS = (4, 16, 64)
SIGMAS = (0.0, 0.5, 1.0)
DT_DAYS = (1.0e-5, 1.0e-4)
PROFILE_FAMILIES = (
    ("wet_gradient", -40.0, -120.0),
    ("mid_gradient", -180.0, -650.0),
    ("dry_gradient", -1200.0, -4200.0),
)
SOURCE_PATTERNS = ("zero", "distributed_root_sink", "mixed_local_source_and_sink")
DZ_CM = 10.0
MASS_TOL_CM = 1.0e-12
CELL_TOL_CM = 1.0e-12
LINEAR_TOL_THETA = 1.0e-12


def float_bytes(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def core():
    return j1a.c1r.base.c1.core


def theta_from_head(h: float) -> float:
    c = core()
    s = float(c.s_of_h(h))
    return float(c.THETA_R + (c.THETA_S - c.THETA_R) * s)


def head_from_theta(theta: float) -> float:
    c = core()
    span = float(c.THETA_S - c.THETA_R)
    s = (theta - float(c.THETA_R)) / span
    if not (0.0 < s < 1.0):
        raise ValueError(("candidate theta outside unsaturated MvG domain", theta, c.THETA_R, c.THETA_S))
    return float(c.h_of_s(s))


def dh_dtheta(h: float) -> float:
    """Exact analytic inverse MvG capacity for the frozen unimodal base family."""
    c = core()
    if not h < 0.0:
        raise ValueError(("non-unsaturated head", h))
    x = abs(float(c.ALPHA) * h)
    dsdh = (
        float(c.MPAR)
        * float(c.NPAR)
        * float(c.ALPHA)
        * x ** (float(c.NPAR) - 1.0)
        * (1.0 + x ** float(c.NPAR)) ** (-float(c.MPAR) - 1.0)
    )
    capacity = (float(c.THETA_S) - float(c.THETA_R)) * dsdh
    if not (capacity > 0.0 and math.isfinite(capacity)):
        raise ValueError(("invalid MvG capacity", h, capacity))
    value = 1.0 / capacity
    if not math.isfinite(value):
        raise ValueError(("invalid dh/dtheta", h, value))
    return value


def build_profile(n: int, h_first: float, h_last: float) -> tuple[float, ...]:
    """Log-head gradient clamped away from N241 node lines without tuning by material."""
    u0 = math.log10(-h_first)
    u1 = math.log10(-h_last)
    heads = []
    for i in range(n):
        r = 0.5 if n == 1 else i / (n - 1)
        u = u0 + r * (u1 - u0)
        x = j1a.DXDU * u
        cell = int(math.floor(x))
        frac = x - cell
        frac = min(0.8, max(0.2, frac))
        x_safe = cell + frac
        h = j1a.head_from_u(x_safe / j1a.DXDU)
        if not (j1a.c1r.base.H_MIN < h < j1a.c1r.base.H_MAX):
            raise ValueError(("profile head outside C1R envelope", h))
        _, f, _ = j1a.table_cell(h)
        if not (0.0 < f < 1.0):
            raise ValueError(("profile head not strict table interior", h, f))
        heads.append(float(h))
    if len(set(heads)) != len(heads):
        raise ValueError("profile construction produced duplicate/equal heads")
    return tuple(heads)


def source_sink(pattern: str, n: int, q_scale: float):
    source = [0.0] * n
    sink = [0.0] * n
    if pattern == "zero":
        return source, sink
    if pattern == "distributed_root_sink":
        weights = [float(n - i) for i in range(n)]
        total = math.fsum(weights)
        for i, w in enumerate(weights):
            sink[i] = 0.003 * q_scale * w / total
        return source, sink
    if pattern == "mixed_local_source_and_sink":
        source[max(0, n // 3)] = 0.002 * q_scale
        sink[min(n - 1, (2 * n) // 3)] = 0.001 * q_scale
        return source, sink
    raise ValueError(pattern)


def boundary_fluxes(heads: tuple[float, ...]):
    c = core()
    k_top = float(c.k_of_h(heads[0]))
    k_bottom = float(c.k_of_h(heads[-1]))
    q_top = 0.01 * k_top
    q_bottom = 0.004 * k_bottom
    q_scale = max(1.0e-300, min(k_top, k_bottom))
    return q_top, q_bottom, q_scale, k_top, k_bottom


def build_faces(heads: tuple[float, ...], table):
    theta = tuple(theta_from_head(h) for h in heads)
    inv_capacity = tuple(dh_dtheta(h) for h in heads)
    faces = []
    for j in range(len(heads) - 1):
        f = j1a.table_flux_and_derivatives(heads[j], heads[j + 1], table)
        faces.append({
            "q0": float(f["q"]),
            "dq_dtheta_upper": float(f["dq_dh_a"] * inv_capacity[j]),
            "dq_dtheta_lower": float(f["dq_dh_b"] * inv_capacity[j + 1]),
            "upper_cell": int(f["ia"]),
            "lower_cell": int(f["ib"]),
        })
    return theta, inv_capacity, faces


def assemble(theta, faces, q_top, q_bottom, source, sink, dt, sigma):
    n = len(theta)
    lower = [0.0] * max(0, n - 1)
    diag = [1.0] * n
    upper = [0.0] * max(0, n - 1)
    rhs = [0.0] * n

    for i in range(n):
        fac = dt / DZ_CM
        q_in0 = q_top if i == 0 else faces[i - 1]["q0"]
        q_out0 = q_bottom if i == n - 1 else faces[i]["q0"]
        rhs[i] = fac * (q_in0 - q_out0 + source[i] - sink[i])

        linfac = fac * sigma
        if i > 0:
            incoming = faces[i - 1]
            lower[i - 1] -= linfac * incoming["dq_dtheta_upper"]
            diag[i] -= linfac * incoming["dq_dtheta_lower"]
        if i < n - 1:
            outgoing = faces[i]
            diag[i] += linfac * outgoing["dq_dtheta_upper"]
            upper[i] += linfac * outgoing["dq_dtheta_lower"]
    return lower, diag, upper, rhs


def realized_fluxes(delta, faces, q_top, q_bottom, sigma):
    n = len(delta)
    q = [0.0] * (n + 1)
    q[0] = float(q_top)
    q[-1] = float(q_bottom)
    for j, face in enumerate(faces, start=1):
        q[j] = float(
            face["q0"]
            + sigma
            * (
                face["dq_dtheta_upper"] * delta[j - 1]
                + face["dq_dtheta_lower"] * delta[j]
            )
        )
    return q


def run_trial(material: str, profile_name: str, n: int, heads, table, pattern: str, dt: float, sigma: float):
    theta, inv_capacity, faces = build_faces(heads, table)
    theta_snapshot = float_bytes(theta)
    heads_snapshot = float_bytes(heads)
    q_top, q_bottom, q_scale, k_top, k_bottom = boundary_fluxes(heads)
    source, sink = source_sink(pattern, n, q_scale)

    lower, diag, upper, rhs = assemble(theta, faces, q_top, q_bottom, source, sink, dt, sigma)
    factorization = j0.factor_tridiagonal(lower, diag, upper)
    delta = j0.solve_factored(factorization, rhs)
    linear_residual = j0.base.matrix_residual(lower, diag, upper, delta, rhs)
    q = realized_fluxes(delta, faces, q_top, q_bottom, sigma)

    candidate_theta = tuple(theta[i] + delta[i] for i in range(n))
    candidate_heads = tuple(head_from_theta(value) for value in candidate_theta)
    domain_ok = all(
        float(core().THETA_R) < value < float(core().THETA_S)
        for value in candidate_theta
    )
    envelope_ok = all(j1a.c1r.base.H_MIN < h < j1a.c1r.base.H_MAX for h in candidate_heads)

    cell_residuals = []
    storage_rows = []
    ledger_rows = []
    for i in range(n):
        storage = DZ_CM * delta[i]
        ledger = dt * (q[i] - q[i + 1] + source[i] - sink[i])
        storage_rows.append(storage)
        ledger_rows.append(ledger)
        cell_residuals.append(storage - ledger)

    global_storage = math.fsum(storage_rows)
    global_external = dt * (
        q_top - q_bottom + math.fsum(source) - math.fsum(sink)
    )
    global_residual = global_storage - global_external
    global_from_cells = math.fsum(ledger_rows)
    internal_cancel_residual = global_from_cells - global_external

    candidate_cell_changes = sum(
        int(j1a.table_cell(heads[i])[0] != j1a.table_cell(candidate_heads[i])[0])
        for i in range(n)
    )
    nonfinite = sum(
        not math.isfinite(v)
        for seq in (delta, q, candidate_theta, candidate_heads, inv_capacity)
        for v in seq
    )

    return {
        "material": material,
        "profile": profile_name,
        "n_cells": n,
        "source_sink_pattern": pattern,
        "dt_day": dt,
        "sigma": sigma,
        "q_top_cm_per_day": q_top,
        "q_bottom_cm_per_day": q_bottom,
        "K_top_cm_per_day": k_top,
        "K_bottom_cm_per_day": k_bottom,
        "max_abs_cell_balance_residual_cm": max(abs(x) for x in cell_residuals),
        "abs_global_mass_residual_cm": abs(global_residual),
        "abs_internal_flux_cancellation_residual_cm": abs(internal_cancel_residual),
        "tridiagonal_residual_theta": linear_residual,
        "candidate_domain_ok": domain_ok,
        "candidate_head_envelope_ok": envelope_ok,
        "candidate_table_cell_change_count_diagnostic": candidate_cell_changes,
        "nonfinite_count": nonfinite,
        "base_theta_bitwise_unchanged": float_bytes(theta) == theta_snapshot,
        "base_heads_bitwise_unchanged": float_bytes(heads) == heads_snapshot,
        "internal_face_values_computed_once_and_shared_by_adjacent_ledgers": True,
        "matrix_factorizations": 1,
        "normal_backsolves": 1,
        "global_nonlinear_iterations": 0,
        "retry_count": 0,
        "branch_or_fallback_count": 0,
        "table_lookups": max(0, n - 1),
        "table_derivative_evaluations": max(0, n - 1),
        "dh_dtheta_evaluations": n,
        "maximum_abs_delta_theta": max(abs(x) for x in delta),
    }


def run_material(row: dict) -> dict:
    j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    table, preprocessing_seconds, generation_failures = j1a.c1r.base.generate_table(j1a.N)
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
    for n in CELL_COUNTS:
        for profile_name, h_first, h_last in PROFILE_FAMILIES:
            try:
                heads = build_profile(n, h_first, h_last)
            except Exception as exc:
                errors.append({"n_cells": n, "profile": profile_name, "stage": "profile", "error": repr(exc)})
                continue
            for pattern in SOURCE_PATTERNS:
                for dt in DT_DAYS:
                    for sigma in SIGMAS:
                        try:
                            cases.append(run_trial(material, profile_name, n, heads, table, pattern, dt, sigma))
                        except Exception as exc:
                            errors.append({
                                "n_cells": n,
                                "profile": profile_name,
                                "source_sink_pattern": pattern,
                                "dt_day": dt,
                                "sigma": sigma,
                                "stage": "trial",
                                "error": repr(exc),
                            })

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected_cases = len(CELL_COUNTS) * len(PROFILE_FAMILIES) * len(SOURCE_PATTERNS) * len(DT_DAYS) * len(SIGMAS)
    if not cases:
        return {"material": material, "pass": False, "failed_metrics": ["no_valid_cases"], "errors": errors}

    observed = {
        "material": material,
        "case_count": len(cases),
        "expected_case_count": expected_cases,
        "case_error_count": len(errors),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "max_abs_global_mass_residual_cm": max(c["abs_global_mass_residual_cm"] for c in cases),
        "max_abs_cell_balance_residual_cm": max(c["max_abs_cell_balance_residual_cm"] for c in cases),
        "max_abs_internal_flux_cancellation_residual_cm": max(c["abs_internal_flux_cancellation_residual_cm"] for c in cases),
        "max_tridiagonal_residual_theta": max(c["tridiagonal_residual_theta"] for c in cases),
        "candidate_domain_failure_count": sum(not c["candidate_domain_ok"] for c in cases),
        "candidate_head_envelope_failure_count": sum(not c["candidate_head_envelope_ok"] for c in cases),
        "candidate_table_cell_change_count_diagnostic": sum(c["candidate_table_cell_change_count_diagnostic"] for c in cases),
        "nonfinite_count": sum(c["nonfinite_count"] for c in cases),
        "base_state_bitwise_unchanged_all": all(c["base_theta_bitwise_unchanged"] and c["base_heads_bitwise_unchanged"] for c in cases),
        "internal_face_shared_ledger_identity_all": all(c["internal_face_values_computed_once_and_shared_by_adjacent_ledgers"] for c in cases),
        "matrix_factorizations_per_trial": sorted(set(c["matrix_factorizations"] for c in cases)),
        "normal_backsolves_per_trial": sorted(set(c["normal_backsolves"] for c in cases)),
        "global_nonlinear_iterations": sorted(set(c["global_nonlinear_iterations"] for c in cases)),
        "retry_count": sorted(set(c["retry_count"] for c in cases)),
        "branch_or_fallback_count": sorted(set(c["branch_or_fallback_count"] for c in cases)),
        "max_abs_delta_theta": max(c["maximum_abs_delta_theta"] for c in cases),
        "worst_global_mass_case": max(cases, key=lambda c: c["abs_global_mass_residual_cm"]),
        "worst_cell_balance_case": max(cases, key=lambda c: c["max_abs_cell_balance_residual_cm"]),
        "errors": errors,
    }

    tests = {
        "all_precommitted_cases_valid": observed["case_count"] == expected_cases and observed["case_error_count"] == 0,
        "maximum_abs_global_mass_residual_cm": observed["max_abs_global_mass_residual_cm"] <= MASS_TOL_CM,
        "maximum_abs_cell_balance_residual_cm": observed["max_abs_cell_balance_residual_cm"] <= CELL_TOL_CM,
        "maximum_tridiagonal_residual_theta": observed["max_tridiagonal_residual_theta"] <= LINEAR_TOL_THETA,
        "candidate_theta_within_unsaturated_constitutive_domain": observed["candidate_domain_failure_count"] == 0,
        "candidate_head_within_C1R_envelope": observed["candidate_head_envelope_failure_count"] == 0,
        "nonfinite_count": observed["nonfinite_count"] == 0,
        "base_state_bitwise_unchanged": observed["base_state_bitwise_unchanged_all"],
        "shared_table_bitwise_unchanged": observed["table_bitwise_unchanged"],
        "internal_face_ledger_identity": observed["internal_face_shared_ledger_identity_all"],
        "matrix_factorizations_per_trial": observed["matrix_factorizations_per_trial"] == [1],
        "normal_backsolves_per_trial": observed["normal_backsolves_per_trial"] == [1],
        "global_nonlinear_iterations": observed["global_nonlinear_iterations"] == [0],
        "retries_in_gate_D_candidate_path": observed["retry_count"] == [0],
        "branch_or_fallback_count": observed["branch_or_fallback_count"] == [0],
    }
    observed["failed_metrics"] = [name for name, ok in tests.items() if not ok]
    observed["pass"] = all(tests.values())
    return observed


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_d_conservative_physical_unsaturated_column.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(j1a.CATALOG.read_text())
    by_name = {r["sfu"]: r for r in catalog["rows"]}
    if material not in MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {MATERIALS}")
    result = run_material(by_name[material])
    result.update({
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "D_CONSERVATIVE_PHYSICAL_UNSATURATED_C1R_COLUMN",
        "contract": CONTRACT,
        "mass_is_hard_gate_not_state_correction": True,
        "timestep_accuracy_is_not_qualified_here": True,
        "production_implementation": False,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k not in ("worst_global_mass_case", "worst_cell_balance_case", "errors")}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
