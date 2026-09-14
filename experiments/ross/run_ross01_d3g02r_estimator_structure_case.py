from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import run_ross01_d2_fsi31_qualification as d2q
import run_ross01_d3g02_temporal_certificate_calibration as cal
import run_ross01_d3g02r_estimator_structure_material as material_probe
import ross01_d3r_fsi31_duration_adapter as adapter

PERTURBATIONS = dict(material_probe.PERTURBATIONS)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--material", required=True)
    p.add_argument("--forcing-variant", required=True)
    p.add_argument("--attempt", type=int, required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")
    if a.forcing_variant not in PERTURBATIONS:
        raise SystemExit("forcing variant outside frozen D3G02R holdout set")
    if a.attempt < 0 or a.attempt > adapter.CANONICAL_MAX_RETRIES:
        raise SystemExit("attempt index outside frozen D3R retry family")

    perturb = float(PERTURBATIONS[a.forcing_variant])
    table = cal.configure_reference(a.material)
    row = adapter.base.MATERIAL_ROWS[a.material]
    span = float(row["theta_s"] - row["theta_r"])

    ref_base = d2q.base_request(a.material, t0=137.125, steps=8, perturb=perturb, pre=False)
    theta0 = tuple(float(v) for v in ref_base["committed_state"]["water_content"])
    ext = cal.reference_external(ref_base)
    refs = (
        material_probe.reference_trajectory(theta0, table, ext, 32),
        material_probe.reference_trajectory(theta0, table, ext, 64),
    )

    case = material_probe.run_case(
        a.material,
        a.forcing_variant,
        perturb,
        a.attempt,
        refs,
        span,
    )

    payload = {
        "work_unit": "F-ROSS01 D3G02R",
        "kind": "estimator_structure_single_holdout_case",
        "live_canonical_head": a.canonical_head,
        "material": a.material,
        "forcing_variant": a.forcing_variant,
        "attempt_index": a.attempt,
        "case_count": 1,
        "expected_case_count": 1,
        "numerical_pass": case["numerical_pass"] is True,
        "structural_signal": case["structural_signal"] is True,
        "certificate_available": False,
        "d3_g02_closed": False,
        "production_source_delta": [],
        "cases": [case],
    }
    a.output.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n")

    tm = case.get("temporal_metrics") or {}
    ratio = tm.get("two_half8_error_to_raw_ratio")
    if isinstance(ratio, float) and not math.isfinite(ratio):
        ratio = None
    print(json.dumps({
        "material": a.material,
        "forcing_variant": a.forcing_variant,
        "attempt_index": a.attempt,
        "numerical_pass": payload["numerical_pass"],
        "structural_signal": payload["structural_signal"],
        "two_half8_error_to_raw_ratio": ratio,
        "max_abs_mass_residual_cm": case["max_abs_mass_residual_cm"],
    }, sort_keys=True, allow_nan=False))

    # Structural failure is scientific evidence for the aggregate. Only an
    # invalid numerical/reference/ownership case fails this shard itself.
    return 0 if payload["numerical_pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
