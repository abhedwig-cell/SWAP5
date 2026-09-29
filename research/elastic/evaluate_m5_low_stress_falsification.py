#!/usr/bin/env python3
"""F-PE-ELASTIC12D frozen M5 evaluation on five low-stress mechanical targets."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

B0 = -5.213084677584852
BW = 1.0383403589566573
MEAN_ABS_GATE = 0.30
MAX_ABS_GATE = 0.50


def median(xs):
    ys = sorted(xs)
    n = len(ys)
    return ys[n // 2] if n % 2 else 0.5 * (ys[n // 2 - 1] + ys[n // 2])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--predictors", required=True)
    ap.add_argument("--targets", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    predictors = json.loads(Path(a.predictors).read_text())
    targets = json.loads(Path(a.targets).read_text())

    if not isinstance(predictors, list) or len(predictors) != 5:
        raise SystemExit("F_PE_ELASTIC12D_FAIL predictor count")
    if not isinstance(targets, list) or len(targets) != 5:
        raise SystemExit("F_PE_ELASTIC12D_FAIL target count")

    pby = {
        (r["bro_id"], int(r["determination_index"]), int(r["step_index"])): r
        for r in predictors
    }
    tby = {
        (r["bro_id"], int(r["determination_index"]), int(r["step_index"])): r
        for r in targets
    }
    if set(pby) != set(tby):
        raise SystemExit("F_PE_ELASTIC12D_FAIL predictor/target identity mismatch")

    rows = []
    for key in sorted(pby):
        p = pby[key]
        t = tby[key]
        w = float(p["water_content_pct"])
        stress = float(p["stress_midpoint_kpa"])
        obs = float(t["ssk_cm_inv"])
        if not (math.isfinite(w) and w > 0.0):
            raise RuntimeError(f"invalid water predictor {key}")
        if not (math.isfinite(stress) and stress > 0.0):
            raise RuntimeError(f"invalid stress predictor {key}")
        if not (math.isfinite(obs) and obs > 0.0):
            raise RuntimeError(f"invalid target {key}")

        log_pred = B0 + BW * math.log10(w) - math.log10(stress)
        pred = 10.0 ** log_pred
        log_obs = math.log10(obs)
        err = log_pred - log_obs
        ae = abs(err)
        factor = 10.0 ** ae

        rows.append({
            "bro_id": p["bro_id"],
            "determination_index": int(p["determination_index"]),
            "step_index": int(p["step_index"]),
            "route": p["route"],
            "water_content_pct": w,
            "stress_midpoint_kpa": stress,
            "observed_ssk_cm_inv": obs,
            "predicted_ssk_cm_inv": pred,
            "log10_observed": log_obs,
            "log10_predicted": log_pred,
            "signed_log10_error": err,
            "absolute_log10_error": ae,
            "multiplicative_error_factor": factor,
        })

    abses = [r["absolute_log10_error"] for r in rows]
    signed = [r["signed_log10_error"] for r in rows]
    mean_abs = sum(abses) / len(abses)
    med_abs = median(abses)
    max_abs = max(abses)
    mean_signed = sum(signed) / len(signed)
    med_signed = median(signed)
    n030 = sum(x <= 0.30 for x in abses)
    n050 = sum(x <= 0.50 for x in abses)

    supported = mean_abs <= MEAN_ABS_GATE and max_abs <= MAX_ABS_GATE
    classification = (
        "LOW_STRESS_M5_TRANSFER_SUPPORTED"
        if supported
        else "LOW_STRESS_M5_TRANSFER_NOT_QUALIFIED"
    )

    summary = {
        "work_unit": "F-PE-ELASTIC12D",
        "model": {
            "name": "M5",
            "b0": B0,
            "bW": BW,
            "stress_exponent": -1.0,
        },
        "object_count": 5,
        "mean_absolute_log10_error": mean_abs,
        "median_absolute_log10_error": med_abs,
        "maximum_absolute_log10_error": max_abs,
        "mean_signed_log10_error": mean_signed,
        "median_signed_log10_error": med_signed,
        "objects_abs_error_le_0p30": n030,
        "objects_abs_error_le_0p50": n050,
        "gates": {
            "mean_absolute_log10_error_max": MEAN_ABS_GATE,
            "maximum_absolute_log10_error_max": MAX_ABS_GATE,
        },
        "classification": classification,
    }

    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "evaluation.json").write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n")
    (out / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    print(f"F_PE_ELASTIC12D_OBJECTS={len(rows)}")
    print(f"F_PE_ELASTIC12D_MEAN_ABS_LOG10={mean_abs:.12g}")
    print(f"F_PE_ELASTIC12D_MEDIAN_ABS_LOG10={med_abs:.12g}")
    print(f"F_PE_ELASTIC12D_MAX_ABS_LOG10={max_abs:.12g}")
    print(f"F_PE_ELASTIC12D_MEAN_SIGNED_LOG10={mean_signed:.12g}")
    print(f"F_PE_ELASTIC12D_MEDIAN_SIGNED_LOG10={med_signed:.12g}")
    print(f"F_PE_ELASTIC12D_WITHIN_0P30={n030}/5")
    print(f"F_PE_ELASTIC12D_WITHIN_0P50={n050}/5")
    print(f"F_PE_ELASTIC12D_CLASSIFICATION={classification}")
    print("F_PE_ELASTIC12D=PASS")


if __name__ == "__main__":
    main()
