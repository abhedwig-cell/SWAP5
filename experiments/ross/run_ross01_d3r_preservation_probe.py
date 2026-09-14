from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

import ross01_d3r_fsi31_duration_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q
import run_ross01_d3r_duration_matrix as dm


def trial(material: str, duration_index: int, steps: int = 8):
    duration = adapter.DURATION_LADDER_DAY[duration_index]
    req = dm.set_interval(d2q.base_request(material, steps=steps, pre=False), 19.25 + duration_index, duration)
    before = copy.deepcopy(req)
    result = adapter.execute_research_trial(req)
    checks = dm.checks(result, req, duration)
    checks["request_exact"] = req == before
    checks["child_preflight"] = (result.get("solver_work_diagnostics") or {}).get("d3r_duration_worker_preflight") is True
    return req, result, checks


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    tests = {
        "duration_ladder_exact": adapter.DURATION_LADDER_DAY == tuple(0.0016 / (2 ** k) for k in range(10)),
        "retry_policy_exact": adapter.CANONICAL_RETRY_SCALE == 0.5 and adapter.CANONICAL_MAX_RETRIES == 8,
        "hard_mass_tolerance_unchanged": adapter.HARD_MASS_TOL_CM == 1e-12,
        "allowed_substeps_unchanged": tuple(adapter.ALLOWED_SUBSTEPS) == (2, 4, 8, 16),
    }

    substeps = []
    residuals = []
    for di in (0, 9):
        for steps in adapter.ALLOWED_SUBSTEPS:
            _, result, checks = trial("B01", di, steps)
            value = result.get("unrounded_mass_residual_cm")
            if isinstance(value, (int, float)):
                residuals.append(abs(float(value)))
            substeps.append({"duration_index": di, "steps": steps, "pass": all(checks.values()), "checks": checks, "mass_residual_cm": value})
    tests["edge_substep_preservation"] = all(x["pass"] for x in substeps)

    replay = []
    fields = ("solver_disposition", "candidate_hydraulic_state", "actual_top_flux", "candidate_bottom_flux", "mass_terms", "unrounded_mass_residual_cm", "whole_window_sensitivity")
    for di in (0, 9):
        duration = adapter.DURATION_LADDER_DAY[di]
        req = dm.set_interval(d2q.base_request("O05", steps=8, pre=False), 77.0 + di, duration)
        r1 = adapter.execute_research_trial(copy.deepcopy(req))
        r2 = adapter.execute_research_trial(copy.deepcopy(req))
        replay.append({"duration_index": di, "pass": all(r1.get(k) == r2.get(k) for k in fields)})
    tests["edge_replay"] = all(x["pass"] for x in replay)

    negatives = []
    for di in (0, 9):
        duration = adapter.DURATION_LADDER_DAY[di]
        for which in ("top", "bottom"):
            req = dm.set_interval(d2q.base_request("B01", pre=False), 5.5 + di, duration)
            before = copy.deepcopy(req)
            if which == "top":
                req["forcing_process_requests"]["top_boundary"]["q_top_cm_per_day"] += 100.0
                expected = "TOP_FLUX_OUTSIDE_DECLARED_SCOPE"
            else:
                req["forcing_process_requests"]["bottom_boundary"]["qbot_cm_per_day"] += 100.0
                expected = "BOTTOM_FLUX_OUTSIDE_DECLARED_SCOPE"
            mutated = copy.deepcopy(req)
            result = adapter.execute_research_trial(req)
            negatives.append({"duration_index": di, "type": which, "pass": result.get("solver_disposition") == "failed" and result.get("failure_classification") == expected and req == mutated and result.get("committed_state_mutated") is not True, "classification": result.get("failure_classification"), "pre_perturbation_snapshot_distinct": before != mutated})

    for label, bad in (("non_ladder_remainder", 0.0012), ("below_minimum", adapter.DURATION_LADDER_DAY[-1] * 0.75)):
        req = dm.set_interval(d2q.base_request("B01", pre=False), 7.0, bad)
        before = copy.deepcopy(req)
        result = adapter.execute_research_trial(req)
        negatives.append({"type": label, "pass": result.get("solver_disposition") == "failed" and result.get("failure_classification") == "TIME_OUTSIDE_DECLARED_SCOPE" and req == before, "classification": result.get("failure_classification")})
    tests["fail_closed_preservation"] = all(x["pass"] for x in negatives)

    qualified = all(tests.values()) and max(residuals, default=0.0) <= 1e-12
    evidence = {
        "work_unit": "F-ROSS01 D3R",
        "kind": "preservation_probe",
        "live_canonical_head": a.canonical_head,
        "qualified": qualified,
        "tests": tests,
        "substep_cases": substeps,
        "replay": replay,
        "negatives": negatives,
        "max_abs_mass_residual_cm": max(residuals, default=0.0),
        "hard_mass_tolerance_cm": 1e-12,
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"qualified": qualified, "max_abs_mass_residual_cm": evidence["max_abs_mass_residual_cm"]}, sort_keys=True))
    return 0 if qualified else 1


if __name__ == "__main__":
    raise SystemExit(main())
