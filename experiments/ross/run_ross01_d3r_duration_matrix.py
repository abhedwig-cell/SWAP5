from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

import ross01_d3r_fsi31_duration_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q


def set_interval(req: dict, t0: float, duration: float) -> dict:
    req = copy.deepcopy(req)
    req["forcing_process_requests"]["t0_day"] = float(t0)
    req["forcing_process_requests"]["t1_day"] = float(t0 + duration)
    return req


def checks(result: dict, req: dict, duration: float) -> dict:
    mass = result.get("mass_terms") or {}
    residual = result.get("unrounded_mass_residual_cm")
    try:
        rebuilt = result["storage_change_cm"] - mass["top_boundary_transfer_cm"] - mass["bottom_boundary_transfer_cm"] - mass["source_transfer_cm"] + mass["sink_transfer_cm"]
    except Exception:
        rebuilt = math.nan
    candidate = result.get("candidate_hydraulic_state") or {}
    view = result.get("process_hydraulic_view") or {}
    bottom = result.get("candidate_bottom_flux") or {}
    interval = result.get("time_interval") or {}
    return {
        "ready": result.get("solver_disposition") == "candidate_ready",
        "candidate_only": result.get("accepted") is False and result.get("commit_authorized") is False and result.get("accepted_publication_authorized") is False,
        "immutable": result.get("committed_state_mutated") is False and result.get("request_object_unchanged") is True,
        "worker_isolated": result.get("worker_isolation") == "FRESH_PROCESS_PER_TRIAL",
        "launcher_reused": (result.get("solver_work_diagnostics") or {}).get("d2_fresh_process_launcher_reused") is True,
        "mass": isinstance(residual, (int, float)) and math.isfinite(float(residual)) and abs(float(residual)) <= 1e-12,
        "ledger": isinstance(residual, (int, float)) and math.isfinite(rebuilt) and abs(rebuilt - float(residual)) <= 5e-16,
        "view": view.get("pressure_head_cm") == candidate.get("pressure_head_cm") and view.get("water_content") == candidate.get("water_content"),
        "exchange_candidate": bottom.get("candidate_only") is True and bottom.get("accepted_exchange") is False,
        "duration": interval.get("duration_day") == duration,
        "no_whole_window": (result.get("whole_window_sensitivity") or {}).get("authority") is False,
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--duration-index", type=int)
    a = p.parse_args()

    expected = tuple(0.0016 / (2 ** k) for k in range(10))
    tests = {
        "duration_ladder_exact": adapter.DURATION_LADDER_DAY == expected,
        "retry_policy_exact": adapter.CANONICAL_RETRY_SCALE == 0.5 and adapter.CANONICAL_MAX_RETRIES == 8,
    }
    indices = range(len(adapter.DURATION_LADDER_DAY)) if a.duration_index is None else (a.duration_index,)
    if any(i < 0 or i >= len(adapter.DURATION_LADDER_DAY) for i in indices):
        raise SystemExit("duration-index outside 0..9")

    cases, replay, negatives, step_cases = [], [], [], []
    max_mass = 0.0
    t0s = (0.0, 37.125, 12345.75, -4321.5)

    for di in indices:
        duration = adapter.DURATION_LADDER_DAY[di]
        for material in adapter.MATERIAL_IDS:
            for label, steps, perturb in (("baseline", 4, 0.0), ("bounded_flux", 8, 0.01)):
                req = set_interval(d2q.base_request(material, steps=steps, perturb=perturb, pre=False), t0s[di % 4], duration)
                before = copy.deepcopy(req["committed_state"])
                result = adapter.execute_research_trial(req)
                c = checks(result, req, duration)
                c["input_exact"] = req["committed_state"] == before
                residual = result.get("unrounded_mass_residual_cm")
                if isinstance(residual, (int, float)):
                    max_mass = max(max_mass, abs(float(residual)))
                cases.append({"duration_index": di, "duration_day": duration, "material": material, "case": label, "steps": steps, "pass": all(c.values()), "checks": c, "mass_residual_cm": residual, "classification": result.get("failure_classification")})

        req = set_interval(d2q.base_request("O05", steps=8, pre=False), 100.0 + di, duration)
        r1 = adapter.execute_research_trial(copy.deepcopy(req))
        r2 = adapter.execute_research_trial(copy.deepcopy(req))
        fields = ("solver_disposition", "candidate_hydraulic_state", "actual_top_flux", "candidate_bottom_flux", "mass_terms", "unrounded_mass_residual_cm", "whole_window_sensitivity")
        replay.append({"duration_index": di, "duration_day": duration, "pass": all(r1.get(k) == r2.get(k) for k in fields)})

    tests["six_material_matrix"] = all(x["pass"] for x in cases)
    tests["hard_mass_gate"] = max_mass <= 1e-12
    tests["replay"] = all(x["pass"] for x in replay)

    # Expensive policy-preservation/negative probes only live on the two edge
    # shards. Together they cover longest and shortest admitted durations.
    edge_indices = set(indices).intersection({0, len(adapter.DURATION_LADDER_DAY) - 1})
    for di in sorted(edge_indices):
        duration = adapter.DURATION_LADDER_DAY[di]
        for steps in adapter.ALLOWED_SUBSTEPS:
            req = set_interval(d2q.base_request("B01", steps=steps, pre=False), 9.25, duration)
            result = adapter.execute_research_trial(req)
            c = checks(result, req, duration)
            step_cases.append({"duration_index": di, "duration_day": duration, "steps": steps, "pass": all(c.values())})
        for which in ("top", "bottom"):
            req = set_interval(d2q.base_request("B01", pre=False), 5.5, duration)
            if which == "top":
                req["forcing_process_requests"]["top_boundary"]["q_top_cm_per_day"] += 100.0
                expected_class = "TOP_FLUX_OUTSIDE_DECLARED_SCOPE"
            else:
                req["forcing_process_requests"]["bottom_boundary"]["qbot_cm_per_day"] += 100.0
                expected_class = "BOTTOM_FLUX_OUTSIDE_DECLARED_SCOPE"
            result = adapter.execute_research_trial(req)
            negatives.append({"type": which, "duration_index": di, "pass": result.get("solver_disposition") == "failed" and result.get("failure_classification") == expected_class, "classification": result.get("failure_classification")})

    if 0 in indices:
        bad = 0.0012
        req = set_interval(d2q.base_request("B01", pre=False), 7.0, bad)
        before = copy.deepcopy(req["committed_state"]); result = adapter.execute_research_trial(req)
        negatives.append({"type": "duration_long", "pass": result.get("solver_disposition") == "failed" and result.get("failure_classification") == "TIME_OUTSIDE_DECLARED_SCOPE" and req["committed_state"] == before, "classification": result.get("failure_classification")})
    if len(adapter.DURATION_LADDER_DAY) - 1 in indices:
        bad = adapter.DURATION_LADDER_DAY[-1] * 0.75
        req = set_interval(d2q.base_request("B01", pre=False), 7.0, bad)
        before = copy.deepcopy(req["committed_state"]); result = adapter.execute_research_trial(req)
        negatives.append({"type": "duration_short", "pass": result.get("solver_disposition") == "failed" and result.get("failure_classification") == "TIME_OUTSIDE_DECLARED_SCOPE" and req["committed_state"] == before, "classification": result.get("failure_classification")})

    tests["edge_substep_policy"] = all(x["pass"] for x in step_cases) if step_cases else True
    tests["edge_negative_fail_closed"] = all(x["pass"] for x in negatives) if negatives else True
    qualified = all(bool(v) for v in tests.values())
    evidence = {
        "work_unit": "F-ROSS01 D3R",
        "kind": "duration_matrix_shard" if a.duration_index is not None else "duration_matrix",
        "live_canonical_head": a.canonical_head,
        "duration_index": a.duration_index,
        "duration_ladder": adapter.duration_ladder_metadata(),
        "shard_qualified": qualified,
        "max_abs_mass_residual_cm": max_mass,
        "tests": tests,
        "positive_case_count": len(cases),
        "positive_cases": cases,
        "step_cases": step_cases,
        "replay": replay,
        "negatives": negatives,
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"duration_index": a.duration_index, "shard_qualified": qualified, "max_abs_mass_residual_cm": max_mass, "positive_case_count": len(cases)}, sort_keys=True))
    return 0 if qualified else 1


if __name__ == "__main__":
    raise SystemExit(main())
