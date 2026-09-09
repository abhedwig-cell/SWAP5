from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_j1a_real_table_face_derivative as j1a

CONTRACT = "F-ROSS01_GATE_J1A_R1_HEAD_COORDINATE_ORACLE_REPAIR_CONTRACT.json"
BASE_EQUIV_TOL = 1.0e-12


def direct_head_flux(h_a: float, h_b: float, table: np.ndarray) -> float:
    """Independent flux-only evaluation of the frozen C1R table law in head coordinates."""
    u_a = math.log10(-h_a)
    u_b = math.log10(-h_b)
    x_a = j1a.DXDU * u_a
    x_b = j1a.DXDU * u_b
    i_a = min(j1a.N - 2, max(0, int(math.floor(x_a))))
    i_b = min(j1a.N - 2, max(0, int(math.floor(x_b))))
    f_a = x_a - i_a
    f_b = x_b - i_b
    l00 = float(table[i_a, i_b])
    l10 = float(table[i_a + 1, i_b])
    l01 = float(table[i_a, i_b + 1])
    l11 = float(table[i_a + 1, i_b + 1])
    ell = (
        (1.0 - f_a) * (1.0 - f_b) * l00
        + f_a * (1.0 - f_b) * l10
        + (1.0 - f_a) * f_b * l01
        + f_a * f_b * l11
    )
    driving = j1a.c1r.base.LENGTH_CM + h_a - h_b
    return driving * math.exp(ell)


def fd_pair(flux_fn, h_a: float, h_b: float, da: float, db: float) -> tuple[float, float]:
    d_a = (flux_fn(h_a + da, h_b) - flux_fn(h_a - da, h_b)) / (2.0 * da)
    d_b = (flux_fn(h_a, h_b + db) - flux_fn(h_a, h_b - db)) / (2.0 * db)
    return d_a, d_b


def run_material(row: dict) -> dict:
    j1a.c1r.base.c1.configure_core(row)
    name = row["sfu"]
    ksat = float(j1a.c1r.base.c1.core.KSAT)
    table, preprocessing_seconds, generation_failures = j1a.c1r.base.generate_table(j1a.N)
    if generation_failures:
        return {
            "material": name,
            "pass": False,
            "failed_metrics": ["table_generation_failures"],
            "table_generation_failures": len(generation_failures),
        }

    table_before = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    repaired_metrics = []
    original_roundtrip_metrics = []
    base_equiv = []
    repaired_abs = []
    rows = []
    cell_change_count = 0
    nonfinite_count = 0

    for h_a, h_b in j1a.build_probes(name):
        analytic = j1a.table_flux_and_derivatives(h_a, h_b, table)
        q_direct = direct_head_flux(h_a, h_b, table)
        q_prod = j1a.actual_lookup_flux(h_a, h_b, table)
        base_equiv.append(abs(q_direct - q_prod) / max(abs(q_direct), abs(q_prod), ksat, 1.0e-300))

        for factor in j1a.FD_FACTORS:
            da = j1a.fd_step(h_a, h_b, factor)
            db = j1a.fd_step(h_b, h_a, factor)
            if not j1a.same_cell_after_perturb(h_a, da) or not j1a.same_cell_after_perturb(h_b, db):
                cell_change_count += 1
                continue

            repaired_a, repaired_b = fd_pair(lambda a, b: direct_head_flux(a, b, table), h_a, h_b, da, db)
            original_a, original_b = fd_pair(lambda a, b: j1a.actual_lookup_flux(a, b, table), h_a, h_b, da, db)
            values = (
                analytic["dq_dh_a"], analytic["dq_dh_b"],
                repaired_a, repaired_b, original_a, original_b,
            )
            if not all(math.isfinite(v) for v in values):
                nonfinite_count += 1
                continue

            rep_a = j1a.derivative_metric(analytic["dq_dh_a"], repaired_a, ksat)
            rep_b = j1a.derivative_metric(analytic["dq_dh_b"], repaired_b, ksat)
            old_a = j1a.derivative_metric(analytic["dq_dh_a"], original_a, ksat)
            old_b = j1a.derivative_metric(analytic["dq_dh_b"], original_b, ksat)
            repaired_metrics.extend((rep_a, rep_b))
            original_roundtrip_metrics.extend((old_a, old_b))
            repaired_abs.extend((abs(analytic["dq_dh_a"] - repaired_a), abs(analytic["dq_dh_b"] - repaired_b)))
            rows.append({
                "h_a": h_a,
                "h_b": h_b,
                "fd_factor": factor,
                "dq_dh_a_analytic": analytic["dq_dh_a"],
                "dq_dh_b_analytic": analytic["dq_dh_b"],
                "dq_dh_a_repaired_fd": repaired_a,
                "dq_dh_b_repaired_fd": repaired_b,
                "dq_dh_a_original_roundtrip_fd": original_a,
                "dq_dh_b_original_roundtrip_fd": original_b,
                "repaired_metric_a": rep_a,
                "repaired_metric_b": rep_b,
                "original_roundtrip_metric_a": old_a,
                "original_roundtrip_metric_b": old_b,
            })

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    if not repaired_metrics:
        raise RuntimeError("J1A-R1 produced no valid comparisons")
    repaired_sorted = sorted(repaired_metrics)
    original_sorted = sorted(original_roundtrip_metrics)
    worst_repaired = max(rows, key=lambda r: max(r["repaired_metric_a"], r["repaired_metric_b"]))
    tests = {
        "table_bitwise_unchanged": table_before == table_after,
        "cell_change_count": cell_change_count == 0,
        "nonfinite_derivative_count": nonfinite_count == 0,
        "base_direct_head_vs_production_lookup_scaled_error": max(base_equiv) <= BASE_EQUIV_TOL,
        "max_repaired_self_consistency_metric": max(repaired_metrics) <= j1a.SELF_TOL,
    }
    return {
        "material": name,
        "seed": j1a.seed_for_material(name),
        "probe_count": j1a.PROBES_PER_MATERIAL,
        "comparison_count": len(repaired_metrics),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "cell_change_count": cell_change_count,
        "nonfinite_derivative_count": nonfinite_count,
        "max_base_direct_head_vs_production_lookup_scaled_error": max(base_equiv),
        "max_repaired_self_consistency_metric": max(repaired_metrics),
        "p99_repaired_self_consistency_metric": repaired_sorted[int(0.99 * (len(repaired_sorted) - 1))],
        "max_original_roundtrip_self_consistency_metric_diagnostic": max(original_roundtrip_metrics),
        "p99_original_roundtrip_self_consistency_metric_diagnostic": original_sorted[int(0.99 * (len(original_sorted) - 1))],
        "max_repaired_absolute_derivative_difference": max(repaired_abs),
        "worst_repaired_row": worst_repaired,
        "failed_metrics": [k for k, ok in tests.items() if not ok],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_j1a_r1_head_coordinate_oracle_repair.py MATERIAL OUTPUT.json")
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
        "gate": "J1A_R1_HEAD_COORDINATE_ORACLE_REPAIR",
        "contract": CONTRACT,
        "fd_factors_unchanged_from_original_j1a": list(j1a.FD_FACTORS),
        "table_and_analytic_derivative_unchanged": True,
        "production_implementation": False,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "worst_repaired_row"}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
