from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

import ross01_d3r_fsi31_duration_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--duration-index", type=int, required=True)
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    if a.duration_index not in range(len(adapter.DURATION_LADDER_DAY)):
        raise SystemExit("duration-index outside 0..9")
    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    duration = adapter.DURATION_LADDER_DAY[a.duration_index]
    t0s = (0.0, 37.125, 12345.75, -4321.5)
    t0 = t0s[a.duration_index % len(t0s)]
    req = d2q.base_request(a.material, t0=0.0, steps=8, perturb=0.0, pre=False)
    req["forcing_process_requests"]["t0_day"] = t0
    req["forcing_process_requests"]["t1_day"] = t0 + duration
    before = copy.deepcopy(req["committed_state"])
    result = adapter.execute_research_trial(req)

    residual = result.get("unrounded_mass_residual_cm")
    mass = result.get("mass_terms") or {}
    try:
        rebuilt = result["storage_change_cm"] - mass["top_boundary_transfer_cm"] - mass["bottom_boundary_transfer_cm"] - mass["source_transfer_cm"] + mass["sink_transfer_cm"]
    except Exception:
        rebuilt = math.nan
    candidate = result.get("candidate_hydraulic_state") or {}
    view = result.get("process_hydraulic_view") or {}
    bottom = result.get("candidate_bottom_flux") or {}
    interval = result.get("time_interval") or {}
    checks = {
        "candidate_ready": result.get("solver_disposition") == "candidate_ready",
        "candidate_only": result.get("accepted") is False and result.get("commit_authorized") is False and result.get("accepted_publication_authorized") is False,
        "committed_exact": req["committed_state"] == before and result.get("committed_state_mutated") is False,
        "request_unchanged": result.get("request_object_unchanged") is True,
        "fresh_worker": result.get("worker_isolation") == "FRESH_PROCESS_PER_TRIAL",
        "d2_launcher_reused": (result.get("solver_work_diagnostics") or {}).get("d2_fresh_process_launcher_reused") is True,
        "duration_child_preflight": (result.get("solver_work_diagnostics") or {}).get("d3r_duration_worker_preflight") is True,
        "hard_mass": isinstance(residual, (int, float)) and math.isfinite(float(residual)) and abs(float(residual)) <= 1e-12,
        "ledger_exact": isinstance(residual, (int, float)) and math.isfinite(rebuilt) and abs(rebuilt - float(residual)) <= 5e-16,
        "process_view": view.get("pressure_head_cm") == candidate.get("pressure_head_cm") and view.get("water_content") == candidate.get("water_content"),
        "candidate_exchange_only": bottom.get("candidate_only") is True and bottom.get("accepted_exchange") is False,
        "duration_metadata": interval.get("duration_day") == duration and interval.get("duration_ladder_index") == a.duration_index,
        "whole_window_not_claimed": (result.get("whole_window_sensitivity") or {}).get("authority") is False,
    }
    passed = all(checks.values())
    evidence = {
        "work_unit": "F-ROSS01 D3R",
        "kind": "duration_material_case",
        "live_canonical_head": a.canonical_head,
        "duration_index": a.duration_index,
        "duration_day": duration,
        "material": a.material,
        "pass": passed,
        "checks": checks,
        "mass_residual_cm": residual,
        "failure_classification": result.get("failure_classification"),
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"duration_index": a.duration_index, "material": a.material, "pass": passed, "mass_residual_cm": residual}, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
