"""Replay the first measured Andelst/MF6 trial without a head corrector."""

import argparse
import json
from pathlib import Path


def replay(evidence):
    run = next(
        run for run in evidence["coupled_runs"]
        if run["corrector"] == "fixed_point" and run["max_step_days"] == 0.002
    )
    if any(int(row[0]) == 1 for row in run["temporal_rejections"]):
        raise ValueError("The first donor trial was rejected")
    imposed, endpoint, inward, storage_outward = run["correctors"][0]
    defects = run["temporal_water_defects_cm"][0]
    initial_head = -0.493
    mean_head = (initial_head + endpoint) / 2
    return {
        "mode": "offline_replay_of_native_output",
        "swap_imposed_head_m": imposed,
        "modflow_initial_head_m": initial_head,
        "modflow_endpoint_head_m": endpoint,
        "modflow_linear_mean_head_m": mean_head,
        "signed_volume_into_modflow_m3": inward,
        "native_budget_residual_m3": inward + storage_outward,
        "native_vs_analytic_endpoint_m": endpoint - (initial_head + inward / 0.15),
        "endpoint_head_residual_m": endpoint - imposed,
        "mean_head_residual_m": mean_head - imposed,
        "temporal_gate_passed": max(defects) <= run["water_metric_tolerance_cm"],
        "original_endpoint_head_gate_passed": abs(endpoint - imposed) <= run["head_tolerance_m"],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()
    print(json.dumps(replay(json.loads(args.evidence.read_text())), indent=2))
