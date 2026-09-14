from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

import ross01_d3r_fsi31_duration_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q


def set_dt(req: dict, t0: float, dt: float) -> dict:
    out = copy.deepcopy(req)
    out["forcing_process_requests"]["t0_day"] = float(t0)
    out["forcing_process_requests"]["t1_day"] = float(t0 + dt)
    return out


def mass_ok(result: dict) -> bool:
    value = result.get("unrounded_mass_residual_cm")
    return isinstance(value, (int, float)) and math.isfinite(float(value)) and abs(float(value)) <= 1e-12


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--attempt-index", type=int, required=True)
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    if a.attempt_index not in range(adapter.CANONICAL_MAX_RETRIES + 1):
        raise SystemExit("attempt-index outside 0..8")
    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    full_dt = adapter.DURATION_LADDER_DAY[a.attempt_index]
    half_dt = adapter.DURATION_LADDER_DAY[a.attempt_index + 1]
    t0 = 37.125 + a.attempt_index
    base = d2q.base_request(a.material, steps=8, perturb=0.0, pre=False)
    committed_before = copy.deepcopy(base["committed_state"])
    full_req = set_dt(base, t0, full_dt)
    half1_req = set_dt(base, t0, half_dt)
    full = adapter.execute_research_trial(copy.deepcopy(full_req))
    half1 = adapter.execute_research_trial(copy.deepcopy(half1_req))

    half2_req = set_dt(base, t0 + half_dt, half_dt)
    if half1.get("solver_disposition") == "candidate_ready":
        half2_req["committed_state"] = copy.deepcopy(half1["candidate_hydraulic_state"])
    half2 = adapter.execute_research_trial(copy.deepcopy(half2_req))

    results = (full, half1, half2)
    ready = all(x.get("solver_disposition") == "candidate_ready" for x in results)
    mass = all(mass_ok(x) for x in results)
    immutable = base["committed_state"] == committed_before and all(x.get("committed_state_mutated") is False for x in results)
    candidate_only = all(x.get("accepted") is False and x.get("commit_authorized") is False and x.get("accepted_publication_authorized") is False for x in results)
    worker = all(x.get("worker_isolation") == "FRESH_PROCESS_PER_TRIAL" for x in results)
    child_preflight = all((x.get("solver_work_diagnostics") or {}).get("d3r_duration_worker_preflight") is True for x in results)
    same_forcing = half1_req["forcing_process_requests"]["top_boundary"] == half2_req["forcing_process_requests"]["top_boundary"] and half1_req["forcing_process_requests"]["bottom_boundary"] == half2_req["forcing_process_requests"]["bottom_boundary"]
    whole_window_not_claimed = all((x.get("whole_window_sensitivity") or {}).get("authority") is False for x in results)

    head_delta = None
    theta_delta = None
    if ready:
        fh = full["candidate_hydraulic_state"]["pressure_head_cm"]
        hh = half2["candidate_hydraulic_state"]["pressure_head_cm"]
        ft = full["candidate_hydraulic_state"]["water_content"]
        ht = half2["candidate_hydraulic_state"]["water_content"]
        head_delta = max(abs(float(x) - float(y)) for x, y in zip(fh, hh))
        theta_delta = max(abs(float(x) - float(y)) for x, y in zip(ft, ht))

    residuals = [abs(float(x["unrounded_mass_residual_cm"])) for x in results if isinstance(x.get("unrounded_mass_residual_cm"), (int, float))]
    checks = {
        "all_candidates_ready": ready,
        "hard_mass_all_three": mass,
        "committed_origin_unchanged": immutable,
        "candidate_only_all_three": candidate_only,
        "fresh_worker_all_three": worker,
        "duration_child_preflight_all_three": child_preflight,
        "forcing_unchanged_between_halves": same_forcing,
        "whole_window_sensitivity_not_claimed": whole_window_not_claimed,
    }
    passed = all(checks.values())
    evidence = {
        "work_unit": "F-ROSS01 D3R",
        "kind": "two_half_chain_case",
        "live_canonical_head": a.canonical_head,
        "attempt_index": a.attempt_index,
        "material": a.material,
        "full_duration_day": full_dt,
        "half_duration_day": half_dt,
        "pass": passed,
        "checks": checks,
        "max_abs_mass_residual_cm": max(residuals, default=0.0),
        "full_vs_two_half_head_delta_cm": head_delta,
        "full_vs_two_half_theta_delta": theta_delta,
        "external_temporal_error_semantics_qualified": False,
        "temporal_error_disposition": "DIAGNOSTIC_STATE_DELTAS_ONLY_NO_ACCEPTANCE_METRIC_OR_TOLERANCE_CLAIM",
        "production_source_delta": []
    }
    a.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"attempt_index": a.attempt_index, "material": a.material, "pass": passed, "max_abs_mass_residual_cm": evidence["max_abs_mass_residual_cm"], "head_delta_cm": head_delta, "theta_delta": theta_delta}, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
