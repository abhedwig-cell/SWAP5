from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.stats import qmc

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_c1r_characterization_v4 as c1r

CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
N = 241
DXDU = (N - 1) / 4.0
LN10 = math.log(10.0)
SELF_TOL = 1.0e-6
SELF_SCALE = 1.0e-8
FD_FACTORS = (1.0e-6, 3.0e-6)
MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
PROBES_PER_MATERIAL = 256


def seed_for_material(name: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-J1A:" + name).encode()).hexdigest()[:8], 16)


def head_from_u(u: float) -> float:
    return -(10.0 ** u)


def u_from_head(h: float) -> float:
    return math.log10(-h)


def table_cell(h: float) -> tuple[int, float, float]:
    u = u_from_head(h)
    x = DXDU * u
    i = min(N - 2, max(0, int(math.floor(x))))
    f = x - i
    return i, f, u


def table_flux_and_derivatives(h_a: float, h_b: float, table: np.ndarray):
    ia, fa, ua = table_cell(h_a)
    ib, fb, ub = table_cell(h_b)
    if not (0.0 < fa < 1.0 and 0.0 < fb < 1.0):
        raise ValueError("J1A analytic derivative requires strict cell interior")

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
    dell_du_a = DXDU * ((1.0 - fb) * (l10 - l00) + fb * (l11 - l01))
    dell_du_b = DXDU * ((1.0 - fa) * (l01 - l00) + fa * (l11 - l10))
    mobility = math.exp(ell)
    g = c1r.base.LENGTH_CM + h_a - h_b
    q = g * mobility
    dq_dh_a = mobility * (1.0 + g * dell_du_a / (LN10 * h_a))
    dq_dh_b = mobility * (-1.0 + g * dell_du_b / (LN10 * h_b))
    return {
        "q": q,
        "dq_dh_a": dq_dh_a,
        "dq_dh_b": dq_dh_b,
        "ia": ia,
        "ib": ib,
        "fa": fa,
        "fb": fb,
        "u_a": ua,
        "u_b": ub,
        "mobility": mobility,
    }


def state_from_head(h: float) -> float:
    return float(c1r.base.c1.core.s_of_h(h))


def actual_lookup_flux(h_a: float, h_b: float, table: np.ndarray) -> float:
    q, _, _ = c1r.lookup(state_from_head(h_a), state_from_head(h_b), table, N)
    return float(q)


def oracle_flux(h_a: float, h_b: float) -> float:
    return float(c1r.base.c1.core.steady_q(h_a, h_b))


def nearest_cell_boundary_distance(h: float) -> float:
    i, f, _ = table_cell(h)
    if not (0.0 < f < 1.0):
        return 0.0
    h0 = head_from_u(i / DXDU)
    h1 = head_from_u((i + 1) / DXDU)
    return min(abs(h - h0), abs(h - h1))


def fd_step(h: float, other_h: float, factor: float) -> float:
    nominal = factor * max(1.0, abs(h))
    cell_cap = 0.05 * nearest_cell_boundary_distance(h)
    branch_cap = 0.05 * abs(h - other_h)
    step = min(nominal, cell_cap, branch_cap)
    if not (step > 0.0 and math.isfinite(step)):
        raise ValueError("invalid J1A finite-difference step")
    return step


def derivative_metric(a: float, b: float, ksat: float) -> float:
    return abs(a - b) / max(abs(a), abs(b), SELF_SCALE * ksat)


def physical_metric(a: float, b: float, ksat: float) -> float:
    return abs(a - b) / max(abs(a), abs(b), 1.0e-6 * ksat)


def build_probes(name: str):
    sobol = qmc.Sobol(d=4, scramble=True, seed=seed_for_material(name))
    raw = sobol.random_base2(m=10)
    probes = []
    for x0, x1, x2, x3 in raw:
        ia = 2 + min(235, int(float(x0) * 236.0))
        ib = 2 + min(235, int(float(x1) * 236.0))
        fa = 0.2 + 0.6 * float(x2)
        fb = 0.2 + 0.6 * float(x3)
        ua = (ia + fa) / DXDU
        ub = (ib + fb) / DXDU
        h_a = head_from_u(ua)
        h_b = head_from_u(ub)
        if abs(h_a - h_b) <= 1.0e-5 * max(1.0, abs(h_a), abs(h_b)):
            continue
        probes.append((h_a, h_b))
        if len(probes) == PROBES_PER_MATERIAL:
            break
    if len(probes) != PROBES_PER_MATERIAL:
        raise RuntimeError("insufficient deterministic strict-interior J1A probes")
    return probes


def same_cell_after_perturb(h: float, step: float) -> bool:
    i0, _, _ = table_cell(h)
    im, _, _ = table_cell(h - step)
    ip, _, _ = table_cell(h + step)
    return i0 == im == ip


def run_material(row: dict) -> dict:
    c1r.base.c1.configure_core(row)
    name = row["sfu"]
    ksat = float(c1r.base.c1.core.KSAT)
    table, preprocessing_seconds, generation_failures = c1r.base.generate_table(N)
    if generation_failures:
        return {
            "material": name,
            "pass": False,
            "failed_metrics": ["table_generation_failures"],
            "table_generation_failures": len(generation_failures),
        }
    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    probes = build_probes(name)

    self_metrics = []
    physical_metrics = []
    physical_abs_norm = []
    physical_step_disagreement = []
    q_consistency = []
    rows = []
    cell_change_count = 0
    nonfinite_count = 0

    for h_a, h_b in probes:
        analytic = table_flux_and_derivatives(h_a, h_b, table)
        q_lookup = actual_lookup_flux(h_a, h_b, table)
        q_consistency.append(abs(analytic["q"] - q_lookup) / max(ksat, abs(q_lookup), 1.0e-300))

        physical_by_endpoint = {"a": [], "b": []}
        for factor in FD_FACTORS:
            da = fd_step(h_a, h_b, factor)
            db = fd_step(h_b, h_a, factor)
            if not same_cell_after_perturb(h_a, da) or not same_cell_after_perturb(h_b, db):
                cell_change_count += 1
                continue

            fd_table_a = (actual_lookup_flux(h_a + da, h_b, table) - actual_lookup_flux(h_a - da, h_b, table)) / (2.0 * da)
            fd_table_b = (actual_lookup_flux(h_a, h_b + db, table) - actual_lookup_flux(h_a, h_b - db, table)) / (2.0 * db)
            fd_phys_a = (oracle_flux(h_a + da, h_b) - oracle_flux(h_a - da, h_b)) / (2.0 * da)
            fd_phys_b = (oracle_flux(h_a, h_b + db) - oracle_flux(h_a, h_b - db)) / (2.0 * db)

            values = (analytic["dq_dh_a"], analytic["dq_dh_b"], fd_table_a, fd_table_b, fd_phys_a, fd_phys_b)
            if not all(math.isfinite(v) for v in values):
                nonfinite_count += 1
                continue

            self_a = derivative_metric(analytic["dq_dh_a"], fd_table_a, ksat)
            self_b = derivative_metric(analytic["dq_dh_b"], fd_table_b, ksat)
            phys_a = physical_metric(analytic["dq_dh_a"], fd_phys_a, ksat)
            phys_b = physical_metric(analytic["dq_dh_b"], fd_phys_b, ksat)
            self_metrics.extend((self_a, self_b))
            physical_metrics.extend((phys_a, phys_b))
            physical_abs_norm.extend((abs(analytic["dq_dh_a"] - fd_phys_a) / ksat, abs(analytic["dq_dh_b"] - fd_phys_b) / ksat))
            physical_by_endpoint["a"].append(fd_phys_a)
            physical_by_endpoint["b"].append(fd_phys_b)
            rows.append({
                "h_a": h_a,
                "h_b": h_b,
                "fd_factor": factor,
                "dq_dh_a_analytic": analytic["dq_dh_a"],
                "dq_dh_b_analytic": analytic["dq_dh_b"],
                "dq_dh_a_table_fd": fd_table_a,
                "dq_dh_b_table_fd": fd_table_b,
                "dq_dh_a_oracle_fd": fd_phys_a,
                "dq_dh_b_oracle_fd": fd_phys_b,
                "self_metric_a": self_a,
                "self_metric_b": self_b,
                "physical_metric_a": phys_a,
                "physical_metric_b": phys_b,
            })

        for endpoint in ("a", "b"):
            vals = physical_by_endpoint[endpoint]
            if len(vals) == 2:
                physical_step_disagreement.append(
                    abs(vals[0] - vals[1]) / max(abs(vals[0]), abs(vals[1]), 1.0e-6 * ksat)
                )

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    if not self_metrics or not physical_metrics:
        raise RuntimeError("J1A produced no valid derivative comparisons")
    self_sorted = sorted(self_metrics)
    phys_sorted = sorted(physical_metrics)
    observed = {
        "material": name,
        "seed": seed_for_material(name),
        "probe_count": len(probes),
        "self_comparison_count": len(self_metrics),
        "physical_comparison_count": len(physical_metrics),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "cell_change_count": cell_change_count,
        "nonfinite_derivative_count": nonfinite_count,
        "max_q_formula_vs_lookup_scaled_error": max(q_consistency),
        "max_self_consistency_metric": max(self_metrics),
        "p99_self_consistency_metric": self_sorted[int(0.99 * (len(self_sorted) - 1))],
        "max_physical_oracle_derivative_metric_characterization": max(physical_metrics),
        "p99_physical_oracle_derivative_metric_characterization": phys_sorted[int(0.99 * (len(phys_sorted) - 1))],
        "median_physical_oracle_derivative_metric_characterization": phys_sorted[len(phys_sorted) // 2],
        "max_abs_physical_derivative_error_over_ksatfit_per_cm_characterization": max(physical_abs_norm),
        "max_oracle_fd_step_disagreement_characterization": max(physical_step_disagreement) if physical_step_disagreement else None,
        "worst_self_row": max(rows, key=lambda r: max(r["self_metric_a"], r["self_metric_b"])),
        "worst_physical_row": max(rows, key=lambda r: max(r["physical_metric_a"], r["physical_metric_b"])),
    }
    tests = {
        "table_bitwise_unchanged": observed["table_bitwise_unchanged"],
        "cell_change_count": observed["cell_change_count"] == 0,
        "nonfinite_derivative_count": observed["nonfinite_derivative_count"] == 0,
        "q_formula_matches_lookup": observed["max_q_formula_vs_lookup_scaled_error"] <= 1.0e-13,
        "max_self_consistency_metric": observed["max_self_consistency_metric"] <= SELF_TOL,
    }
    observed["failed_metrics"] = [k for k, ok in tests.items() if not ok]
    observed["pass"] = all(tests.values())
    return observed


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_j1a_real_table_face_derivative.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(CATALOG.read_text())
    by_name = {r["sfu"]: r for r in catalog["rows"]}
    if material not in MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {MATERIALS}")
    result = run_material(by_name[material])
    result.update({
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "J1A_REAL_C1R_TABLE_FACE_DERIVATIVE",
        "contract": "F-ROSS01_GATE_J1A_REAL_TABLE_FACE_DERIVATIVE_CONTRACT.json",
        "physical_oracle_derivative_is_characterization_only": True,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k not in ("worst_self_row", "worst_physical_row")}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
