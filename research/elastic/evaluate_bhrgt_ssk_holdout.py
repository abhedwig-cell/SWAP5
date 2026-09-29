#!/usr/bin/env python3
"""F-PE-ELASTIC11D frozen BHR-GT mechanical-model holdout evaluation."""
from __future__ import annotations

import argparse
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path

HOLDOUT = {
    "BHR000000462646",
    "BHR000000456023",
    "BHR000000356940",
    "BHR000000453775",
    "BHR000000380281",
    "BHR000000466469",
    "BHR000000353614",
    "BHR000000470064",
}
TARGET_KEYS = ("bro_id", "determination_index", "step_index", "route")

# Frozen in F-PE-ELASTIC11D_HOLDOUT_PREREGISTRATION.md.
M5_B0 = -5.213084677584852
M5_BW = 1.0383403589566573
M0 = -5.300865461580213

LOG_STRESS_MIN = 1.7871769924705538
LOG_STRESS_MAX = 2.6651446013599136
LOG_WATER_MIN = 1.3654879848908996
LOG_WATER_MAX = 2.656577291396114

GATES = {
    "mean_object_mae_max": 0.50,
    "median_object_mae_max": 0.40,
    "max_object_mae_max": 1.20,
    "objects_mae_le_0p50_min": 6,
    "mean_object_mae_improvement_over_m0_min": 0.05,
}


def key(row):
    return tuple(row[k] for k in TARGET_KEYS)


def mae(xs):
    return statistics.fmean(abs(x) for x in xs)


def median_abs(xs):
    return statistics.median(abs(x) for x in xs)


def object_metrics(errors):
    return {
        "n": len(errors),
        "mae": mae(errors),
        "median_abs_error": median_abs(errors),
        "median_signed_error": statistics.median(errors),
        "max_abs_error": max(abs(x) for x in errors),
    }


def aggregate_object_metrics(metrics_by_object):
    values = list(metrics_by_object.values())
    maes = [m["mae"] for m in values]
    return {
        "objects": len(values),
        "mean_object_mae": statistics.fmean(maes),
        "median_object_mae": statistics.median(maes),
        "max_object_mae": max(maes),
        "objects_mae_le_0p50": sum(x <= 0.50 for x in maes),
        "mean_object_median_signed_error": statistics.fmean(
            m["median_signed_error"] for m in values
        ),
    }


def row_summary(rows):
    if not rows:
        return {"n": 0}
    errors = [r["error_m5"] for r in rows]
    return {
        "n": len(rows),
        "mae": mae(errors),
        "median_abs_error": median_abs(errors),
        "median_signed_error": statistics.median(errors),
        "mean_signed_error": statistics.fmean(errors),
        "max_abs_error": max(abs(x) for x in errors),
        "median_multiplicative_error_factor": 10.0 ** statistics.median(abs(x) for x in errors),
        "max_multiplicative_error_factor": 10.0 ** max(abs(x) for x in errors),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--predictors", required=True)
    ap.add_argument("--targets", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    predictors = json.loads(Path(args.predictors).read_text())
    targets = json.loads(Path(args.targets).read_text())

    ph = [r for r in predictors if r.get("group") == "HOLDOUT"]
    if len(ph) != 25:
        raise RuntimeError(f"holdout predictor row drift: {len(ph)}")
    if {r["bro_id"] for r in ph} != HOLDOUT:
        raise RuntimeError("holdout predictor object set drift")
    pmap = {key(r): r for r in ph}
    if len(pmap) != len(ph):
        raise RuntimeError("duplicate holdout predictor identity")

    # This is the single frozen target opening. Calibration target values are ignored.
    th = []
    for r in targets:
        bro = r["bro_id"]
        if bro in HOLDOUT:
            th.append(r)
    if len(th) != 25:
        raise RuntimeError(f"holdout target row drift: {len(th)}")
    if {r["bro_id"] for r in th} != HOLDOUT:
        raise RuntimeError("holdout target object set drift")
    tmap = {key(r): r for r in th}
    if len(tmap) != len(th):
        raise RuntimeError("duplicate holdout target identity")
    if set(pmap) != set(tmap):
        raise RuntimeError(
            f"holdout predictor/target identity mismatch p={len(pmap)} t={len(tmap)}"
        )

    rows = []
    by_object_m5 = defaultdict(list)
    by_object_m0 = defaultdict(list)

    for k in sorted(pmap):
        p = pmap[k]
        t = tmap[k]
        water = float(p["water_content_pct"])
        stress = float(p["stress_midpoint_kpa"])
        observed = float(t["ssk_cm_inv"])
        if not all(math.isfinite(x) and x > 0.0 for x in (water, stress, observed)):
            raise RuntimeError(f"invalid holdout value for {k}")

        log_water = math.log10(water)
        log_stress = math.log10(stress)
        y = math.log10(observed)
        pred_m5 = M5_B0 + M5_BW * log_water - log_stress
        pred_m0 = M0
        if not all(math.isfinite(x) for x in (pred_m5, pred_m0)):
            raise RuntimeError(f"nonfinite prediction for {k}")

        error_m5 = pred_m5 - y
        error_m0 = pred_m0 - y
        in_domain = (
            LOG_STRESS_MIN <= log_stress <= LOG_STRESS_MAX
            and LOG_WATER_MIN <= log_water <= LOG_WATER_MAX
        )
        row = {
            "bro_id": p["bro_id"],
            "determination_index": p["determination_index"],
            "step_index": p["step_index"],
            "route": p["route"],
            "stress_midpoint_kpa": stress,
            "water_content_pct": water,
            "observed_log10_ssk_cm_inv": y,
            "predicted_log10_ssk_cm_inv_m5": pred_m5,
            "predicted_log10_ssk_cm_inv_m0": pred_m0,
            "error_m5": error_m5,
            "error_m0": error_m0,
            "abs_error_m5": abs(error_m5),
            "multiplicative_error_factor_m5": 10.0 ** abs(error_m5),
            "in_calibration_predictor_domain": in_domain,
        }
        rows.append(row)
        by_object_m5[p["bro_id"]].append(error_m5)
        by_object_m0[p["bro_id"]].append(error_m0)

    m5_obj = {bro: object_metrics(errs) for bro, errs in sorted(by_object_m5.items())}
    m0_obj = {bro: object_metrics(errs) for bro, errs in sorted(by_object_m0.items())}
    m5_agg = aggregate_object_metrics(m5_obj)
    m0_agg = aggregate_object_metrics(m0_obj)
    improvement = m0_agg["mean_object_mae"] - m5_agg["mean_object_mae"]

    gates = {
        "finite_predictions": all(math.isfinite(r["predicted_log10_ssk_cm_inv_m5"]) for r in rows),
        "all_8_objects": len(m5_obj) == 8,
        "mean_object_mae": m5_agg["mean_object_mae"] <= GATES["mean_object_mae_max"],
        "median_object_mae": m5_agg["median_object_mae"] <= GATES["median_object_mae_max"],
        "max_object_mae": m5_agg["max_object_mae"] <= GATES["max_object_mae_max"],
        "objects_mae_le_0p50": m5_agg["objects_mae_le_0p50"] >= GATES["objects_mae_le_0p50_min"],
        "improvement_over_m0": improvement >= GATES["mean_object_mae_improvement_over_m0_min"],
    }
    passed = all(gates.values())

    in_domain = [r for r in rows if r["in_calibration_predictor_domain"]]
    extrap = [r for r in rows if not r["in_calibration_predictor_domain"]]
    route = {
        name: row_summary([r for r in rows if r["route"] == name])
        for name in ("R2", "R3")
    }

    in_domain_by_object = defaultdict(list)
    for r in in_domain:
        in_domain_by_object[r["bro_id"]].append(r["error_m5"])
    in_domain_obj = {
        bro: object_metrics(errs) for bro, errs in sorted(in_domain_by_object.items())
    }

    out = {
        "status": "PASS" if passed else "FAIL",
        "frozen_model": {
            "name": "M5",
            "b0": M5_B0,
            "bW": M5_BW,
            "stress_exponent": -1.0,
        },
        "frozen_baseline": {"name": "M0", "intercept": M0},
        "frozen_gates": GATES,
        "population": {
            "rows": len(rows),
            "objects": len(m5_obj),
            "in_domain_rows": len(in_domain),
            "extrapolation_rows": len(extrap),
        },
        "m5_object_metrics": m5_obj,
        "m0_object_metrics": m0_obj,
        "m5_aggregate": m5_agg,
        "m0_aggregate": m0_agg,
        "mean_object_mae_improvement_over_m0": improvement,
        "gates": gates,
        "route_diagnostics": route,
        "in_domain_row_diagnostics": row_summary(in_domain),
        "extrapolation_row_diagnostics": row_summary(extrap),
        "in_domain_object_metrics": in_domain_obj,
        "rows": rows,
    }

    path = Path(args.out)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")

    print("F_PE_ELASTIC11D_HOLDOUT_ROWS=25")
    print("F_PE_ELASTIC11D_HOLDOUT_OBJECTS=8")
    print(f"F_PE_ELASTIC11D_IN_DOMAIN_ROWS={len(in_domain)}")
    print(f"F_PE_ELASTIC11D_EXTRAPOLATION_ROWS={len(extrap)}")
    print("F_PE_ELASTIC11D_M5=" + json.dumps(m5_agg, separators=(",", ":"), sort_keys=True))
    print("F_PE_ELASTIC11D_M0=" + json.dumps(m0_agg, separators=(",", ":"), sort_keys=True))
    print(f"F_PE_ELASTIC11D_IMPROVEMENT_OVER_M0={improvement:.15g}")
    for name in ("R2", "R3"):
        print("F_PE_ELASTIC11D_ROUTE=" + name + "|METRICS=" +
              json.dumps(route[name], separators=(",", ":"), sort_keys=True))
    print("F_PE_ELASTIC11D_GATES=" + json.dumps(gates, separators=(",", ":"), sort_keys=True))
    print("F_PE_ELASTIC11D=" + ("PASS" if passed else "FAIL"))


if __name__ == "__main__":
    main()
