from __future__ import annotations

from decimal import Decimal, localcontext
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
import run_ross01_gate_j1a_r1_head_coordinate_oracle_repair as r1

CONTRACT = "F-ROSS01_GATE_J1A_R2_HIGH_PRECISION_FD_ORACLE_CONTRACT.json"
DECIMAL_DIGITS = 80
BASE_EQUIV_TOL = 1.0e-12
D = Decimal


def decimal_from_float(x: float) -> Decimal:
    return D.from_float(float(x))


def high_precision_flux(h_a_float: float, h_b_float: float, table: np.ndarray) -> Decimal:
    """Flux-only evaluation of the frozen C1R face law in 80-digit arithmetic."""
    ia, _, _ = j1a.table_cell(h_a_float)
    ib, _, _ = j1a.table_cell(h_b_float)
    with localcontext() as ctx:
        ctx.prec = DECIMAL_DIGITS
        h_a = decimal_from_float(h_a_float)
        h_b = decimal_from_float(h_b_float)
        u_a = (-h_a).log10()
        u_b = (-h_b).log10()
        x_a = D(j1a.N - 1) * u_a / D(4)
        x_b = D(j1a.N - 1) * u_b / D(4)
        f_a = x_a - D(ia)
        f_b = x_b - D(ib)
        one = D(1)
        l00 = decimal_from_float(float(table[ia, ib]))
        l10 = decimal_from_float(float(table[ia + 1, ib]))
        l01 = decimal_from_float(float(table[ia, ib + 1]))
        l11 = decimal_from_float(float(table[ia + 1, ib + 1]))
        ell = (
            (one - f_a) * (one - f_b) * l00
            + f_a * (one - f_b) * l10
            + (one - f_a) * f_b * l01
            + f_a * f_b * l11
        )
        driving = decimal_from_float(j1a.c1r.base.LENGTH_CM) + h_a - h_b
        return +(driving * ell.exp())


def high_precision_fd(h_a: float, h_b: float, da: float, db: float, table: np.ndarray) -> tuple[float, float]:
    with localcontext() as ctx:
        ctx.prec = DECIMAL_DIGITS
        qa_plus = high_precision_flux(h_a + da, h_b, table)
        qa_minus = high_precision_flux(h_a - da, h_b, table)
        qb_plus = high_precision_flux(h_a, h_b + db, table)
        qb_minus = high_precision_flux(h_a, h_b - db, table)
        den_a = D(2) * decimal_from_float(da)
        den_b = D(2) * decimal_from_float(db)
        return float((qa_plus - qa_minus) / den_a), float((qb_plus - qb_minus) / den_b)


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
    hp_metrics = []
    binary64_metrics = []
    hp_abs = []
    base_equiv = []
    rows = []
    cell_change_count = 0
    nonfinite_count = 0

    for h_a, h_b in j1a.build_probes(name):
        analytic = j1a.table_flux_and_derivatives(h_a, h_b, table)
        q_hp = float(high_precision_flux(h_a, h_b, table))
        q_prod = j1a.actual_lookup_flux(h_a, h_b, table)
        base_equiv.append(abs(q_hp - q_prod) / max(abs(q_hp), abs(q_prod), ksat, 1.0e-300))

        for factor in j1a.FD_FACTORS:
            da = j1a.fd_step(h_a, h_b, factor)
            db = j1a.fd_step(h_b, h_a, factor)
            if not j1a.same_cell_after_perturb(h_a, da) or not j1a.same_cell_after_perturb(h_b, db):
                cell_change_count += 1
                continue

            hp_a, hp_b = high_precision_fd(h_a, h_b, da, db, table)
            d64_a, d64_b = r1.fd_pair(lambda a, b: r1.direct_head_flux(a, b, table), h_a, h_b, da, db)
            values = (analytic["dq_dh_a"], analytic["dq_dh_b"], hp_a, hp_b, d64_a, d64_b)
            if not all(math.isfinite(v) for v in values):
                nonfinite_count += 1
                continue

            hp_ma = j1a.derivative_metric(analytic["dq_dh_a"], hp_a, ksat)
            hp_mb = j1a.derivative_metric(analytic["dq_dh_b"], hp_b, ksat)
            d64_ma = j1a.derivative_metric(analytic["dq_dh_a"], d64_a, ksat)
            d64_mb = j1a.derivative_metric(analytic["dq_dh_b"], d64_b, ksat)
            hp_metrics.extend((hp_ma, hp_mb))
            binary64_metrics.extend((d64_ma, d64_mb))
            hp_abs.extend((abs(analytic["dq_dh_a"] - hp_a), abs(analytic["dq_dh_b"] - hp_b)))
            rows.append({
                "h_a": h_a,
                "h_b": h_b,
                "fd_factor": factor,
                "dq_dh_a_analytic": analytic["dq_dh_a"],
                "dq_dh_b_analytic": analytic["dq_dh_b"],
                "dq_dh_a_high_precision_fd": hp_a,
                "dq_dh_b_high_precision_fd": hp_b,
                "dq_dh_a_binary64_direct_fd": d64_a,
                "dq_dh_b_binary64_direct_fd": d64_b,
                "high_precision_metric_a": hp_ma,
                "high_precision_metric_b": hp_mb,
                "binary64_direct_metric_a": d64_ma,
                "binary64_direct_metric_b": d64_mb,
            })

    table_after = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    if not hp_metrics:
        raise RuntimeError("J1A-R2 produced no valid comparisons")
    hp_sorted = sorted(hp_metrics)
    d64_sorted = sorted(binary64_metrics)
    worst_hp = max(rows, key=lambda r: max(r["high_precision_metric_a"], r["high_precision_metric_b"]))
    tests = {
        "table_bitwise_unchanged": table_before == table_after,
        "cell_change_count": cell_change_count == 0,
        "nonfinite_derivative_count": nonfinite_count == 0,
        "base_high_precision_vs_production_lookup_scaled_error": max(base_equiv) <= BASE_EQUIV_TOL,
        "max_high_precision_self_consistency_metric": max(hp_metrics) <= j1a.SELF_TOL,
    }
    return {
        "material": name,
        "seed": j1a.seed_for_material(name),
        "probe_count": j1a.PROBES_PER_MATERIAL,
        "comparison_count": len(hp_metrics),
        "preprocessing_seconds_descriptive": preprocessing_seconds,
        "decimal_precision_digits": DECIMAL_DIGITS,
        "table_sha256": table_before,
        "table_bitwise_unchanged": table_before == table_after,
        "cell_change_count": cell_change_count,
        "nonfinite_derivative_count": nonfinite_count,
        "max_base_high_precision_vs_production_lookup_scaled_error": max(base_equiv),
        "max_high_precision_self_consistency_metric": max(hp_metrics),
        "p99_high_precision_self_consistency_metric": hp_sorted[int(0.99 * (len(hp_sorted) - 1))],
        "max_binary64_direct_self_consistency_metric_diagnostic": max(binary64_metrics),
        "p99_binary64_direct_self_consistency_metric_diagnostic": d64_sorted[int(0.99 * (len(d64_sorted) - 1))],
        "max_high_precision_absolute_derivative_difference": max(hp_abs),
        "worst_high_precision_row": worst_hp,
        "failed_metrics": [k for k, ok in tests.items() if not ok],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_j1a_r2_high_precision_fd_oracle.py MATERIAL OUTPUT.json")
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
        "gate": "J1A_R2_HIGH_PRECISION_FD_ORACLE",
        "contract": CONTRACT,
        "fd_factors_unchanged_from_original_j1a": list(j1a.FD_FACTORS),
        "table_and_analytic_derivative_unchanged": True,
        "production_implementation": False,
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "worst_high_precision_row"}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
