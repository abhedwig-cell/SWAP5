#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

import numpy as np

import run_lare_dyn0a_ode as dyn


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    dyn.PARTITIONS["D4"] = np.array([130.0, 10.0, 10.0, 10.0], dtype=float)
    cases = [
        dyn.Case("D4", se0, forcing_id, "FIXED_FLUX")
        for se0 in dyn.INITIAL_SE
        for forcing_id in dyn.TOP_SEQUENCES
    ]

    results = {}
    max_ledger = 0.0
    qualified = 0
    outside = 0
    numerical = 0
    equilibrium_max_change = 0.0

    for case in cases:
        refinements = {}
        failures = {}
        for dt in dyn.HEUN_DT:
            key = f"{dt:.7f}"
            try:
                refinements[key] = dyn.solve_heun(case, dt)
                max_ledger = max(
                    max_ledger,
                    float(refinements[key]["max_abs_water_ledger_cm"]),
                )
            except (ValueError, RuntimeError, FloatingPointError) as exc:
                failures[key] = f"{type(exc).__name__}: {exc}"

        finest_key = f"{dyn.HEUN_DT[-1]:.7f}"
        finest = refinements.get(finest_key)
        failure = failures.get(finest_key, "")
        if finest is not None:
            status = "QUALIFIED"
            qualified += 1
        elif "OUTSIDE_QUALIFIED_DOMAIN" in failure:
            status = "OUTSIDE_QUALIFIED_DOMAIN"
            outside += 1
        else:
            status = "NUMERICAL_BLOCKED"
            numerical += 1

        if finest is not None and case.forcing_id == "EQ":
            total = np.asarray(finest["total_storage_cm"], dtype=float)
            equilibrium_max_change = max(
                equilibrium_max_change,
                float(np.max(np.abs(total - total[0]))),
            )

        pairwise = {}
        keys = [f"{dt:.7f}" for dt in dyn.HEUN_DT]
        for left, right in zip(keys[:-1], keys[1:]):
            if left in refinements and right in refinements:
                pairwise[f"dt_{left}_vs_{right}"] = dyn.compare(
                    refinements[left], refinements[right]
                )

        results[case.id] = {
            "case": {
                "partition": "D4",
                "layer_thickness_cm": [130.0, 10.0, 10.0, 10.0],
                "initial_effective_saturation": case.se0,
                "forcing_id": case.forcing_id,
                "bottom_boundary": case.bottom,
            },
            "status": status,
            "finest_reference": finest,
            "heun_refinements": refinements,
            "heun_failures": failures,
            "heun_pairwise_numerical_floor": pairwise,
            "heun_max_corrector_iterations": {
                key: value["max_corrector_iterations"]
                for key, value in refinements.items()
            },
        }

    payload = {
        "schema": "swap5.lare.dyn0a.d4.ode-reference.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-DYN0A-D4",
        "decision": "LARE_DYN0A_D4_HEUN_REFINEMENT_CHARACTERIZED",
        "model": {
            "partition": "D4",
            "layer_thickness_cm": [130.0, 10.0, 10.0, 10.0],
            "interface_closure": "HE2021_EQ24_ADJACENT_FIXED_LAYER_EXTENSION",
            "bottom_boundary": "FIXED_FLUX",
            "observation_dt_day": dyn.OBS_DT,
            "steps": dyn.STEPS,
            "heun_refinement_dt_day": list(dyn.HEUN_DT),
        },
        "case_count": len(cases),
        "qualified_case_count": qualified,
        "outside_qualified_domain_count": outside,
        "numerical_blocked_count": numerical,
        "max_abs_water_ledger_cm": max_ledger,
        "max_abs_equilibrium_total_storage_change_cm": equilibrium_max_change,
        "cases": results,
        "fine_richards_executed": False,
        "coarse_richards_executed": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": payload["schema"],
        "decision": payload["decision"],
        "qualified": qualified,
        "outside_domain": outside,
        "numerical_blocked": numerical,
        "max_abs_water_ledger_cm": max_ledger,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
