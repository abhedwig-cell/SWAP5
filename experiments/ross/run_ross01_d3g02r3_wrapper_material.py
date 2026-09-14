from __future__ import annotations

import argparse
import copy
import json
import math
import tempfile
from pathlib import Path

import ross01_d3g02r_resolution_floor_certificate_adapter as wrapper
import ross01_d3r_fsi31_duration_adapter as d3r
import run_ross01_d2_fsi31_qualification as d2q

EXPECTED_FLOOR = 1.0e-10
EXPECTED_TOLERANCE = 1.0e-5
MASS_TOL_CM = 1.0e-12


def _set_dt(req: dict, t0: float, dt: float) -> dict:
    out = copy.deepcopy(req)
    out["forcing_process_requests"]["t0_day"] = float(t0)
    out["forcing_process_requests"]["t1_day"] = float(t0 + dt)
    return out


def _close(a: float, b: float) -> bool:
    tol = max(2.0e-15, 4.0 * math.ulp(float(b)))
    return math.isclose(float(a), float(b), rel_tol=0.0, abs_tol=tol)


def _no_component_execution(out: dict) -> bool:
    diagnostics = out.get("solver_work_diagnostics") or {}
    return (
        "candidate_hydraulic_state" not in out
        and diagnostics.get("certificate_component_trial_count") in (None, 0)
        and out.get("temporal_certificate_available") is False
    )


def run_case(material: str, attempt: int, canonical_head: str) -> dict:
    dt = float(d3r.DURATION_LADDER_DAY[attempt])
    t0 = 317.125 + 0.75 * attempt
    req = d2q.base_request(material, t0=t0, steps=8, perturb=0.0, pre=False)
    req = _set_dt(req, t0, dt)
    req_before = copy.deepcopy(req)
    committed_before = copy.deepcopy(req["committed_state"])
    out = wrapper.execute_research_trial(req)

    cert = out.get("temporal_certificate") or {}
    indicator = out.get("temporal_indicator")
    raw = cert.get("raw_estimator")
    bound = cert.get("candidate_error_bound")
    expected_bound = None
    expected_indicator = None
    if isinstance(raw, (int, float)) and math.isfinite(float(raw)) and float(raw) >= 0.0:
        expected_bound = max(float(raw), EXPECTED_FLOOR)
        expected_indicator = expected_bound / EXPECTED_TOLERANCE

    ti = out.get("time_interval") or {}
    diagnostics = out.get("solver_work_diagnostics") or {}
    checks = {
        "candidate_ready": out.get("solver_disposition") == "candidate_ready",
        "certificate_available": out.get("temporal_certificate_available") is True and cert.get("available") is True,
        "indicator_finite_nonnegative_le_one": isinstance(indicator, (int, float)) and math.isfinite(float(indicator)) and 0.0 <= float(indicator) <= 1.0,
        "indicator_formula_exact": expected_indicator is not None and isinstance(indicator, (int, float)) and _close(float(indicator), expected_indicator),
        "bound_formula_exact": expected_bound is not None and isinstance(bound, (int, float)) and _close(float(bound), expected_bound),
        "resolution_floor_exact": cert.get("preexisting_resolution_floor") == EXPECTED_FLOOR,
        "accuracy_tolerance_exact": cert.get("accuracy_tolerance") == EXPECTED_TOLERANCE,
        "candidate_route_refined_two_half": cert.get("candidate_route") == "REFINED_TWO_HALF",
        "three_component_trials_diagnosed": diagnostics.get("certificate_component_trial_count") == 3,
        "canonical_accept_commit_owner_only": diagnostics.get("certificate_acceptance_authority") == "CANONICAL_RUNTIME_ONLY",
        "aggregate_mass_hard_gate": isinstance(out.get("unrounded_mass_residual_cm"), (int, float)) and abs(float(out["unrounded_mass_residual_cm"])) <= MASS_TOL_CM,
        "committed_state_unchanged": req.get("committed_state") == committed_before and out.get("committed_state_mutated") is False,
        "candidate_only": out.get("accepted") is False and out.get("commit_authorized") is False and out.get("accepted_publication_authorized") is False,
        "request_object_unchanged": req == req_before and out.get("request_object_unchanged") is True,
        "full_interval_projected": ti.get("duration_ladder_index") == attempt and _close(float(ti.get("t0_day")), t0) and _close(float(ti.get("t1_day")), t0 + dt) and _close(float(ti.get("duration_day")), dt),
        "scope_exact_d3r": cert.get("scope") == "EXACT_D3R_QUALIFIED_DOMAIN_ONLY",
    }
    return {
        "attempt_index": attempt,
        "material": material,
        "duration_day": dt,
        "live_canonical_head": canonical_head,
        "pass": all(checks.values()),
        "checks": checks,
        "raw_estimator": raw,
        "candidate_error_bound": bound,
        "temporal_indicator": indicator,
        "aggregate_mass_residual_cm": out.get("unrounded_mass_residual_cm"),
        "bound_branch": cert.get("bound_branch"),
    }


def _temporary_authority(payload: dict):
    td = tempfile.TemporaryDirectory()
    p = Path(td.name) / "authority.json"
    p.write_text(json.dumps(payload), encoding="utf-8")
    return td, p


def negative_tests() -> dict:
    t0 = 509.25
    base = d2q.base_request("B01", t0=t0, steps=8, perturb=0.0, pre=False)
    valid = _set_dt(base, t0, float(d3r.DURATION_LADDER_DAY[0]))
    original_authority = wrapper._AUTHORITY

    with tempfile.TemporaryDirectory() as td:
        wrapper._AUTHORITY = Path(td) / "missing.json"
        try:
            missing = wrapper.execute_research_trial(copy.deepcopy(valid))
        finally:
            wrapper._AUTHORITY = original_authority

    base_authority = json.loads(original_authority.read_text(encoding="utf-8"))

    wrong_floor_payload = copy.deepcopy(base_authority)
    wrong_floor_payload["resolution_floor"] = 2.0e-10
    td_floor, p_floor = _temporary_authority(wrong_floor_payload)
    wrapper._AUTHORITY = p_floor
    try:
        wrong_floor = wrapper.execute_research_trial(copy.deepcopy(valid))
    finally:
        wrapper._AUTHORITY = original_authority
        td_floor.cleanup()

    wrong_tol_payload = copy.deepcopy(base_authority)
    wrong_tol_payload["accuracy_tolerance"] = 2.0e-5
    td_tol, p_tol = _temporary_authority(wrong_tol_payload)
    wrapper._AUTHORITY = p_tol
    try:
        wrong_tol = wrapper.execute_research_trial(copy.deepcopy(valid))
    finally:
        wrapper._AUTHORITY = original_authority
        td_tol.cleanup()

    level9_req = _set_dt(base, t0, float(d3r.DURATION_LADDER_DAY[9]))
    level9 = wrapper.execute_research_trial(level9_req)

    off_ladder_req = _set_dt(base, t0, float(d3r.DURATION_LADDER_DAY[0]) * 0.9)
    off_ladder = wrapper.execute_research_trial(off_ladder_req)

    checks = {
        "bound_authority_missing_fails_closed_before_solver": missing.get("solver_disposition") == "failed" and missing.get("failure_classification") == "TEMPORAL_CERTIFICATE_POLICY_UNQUALIFIED" and _no_component_execution(missing),
        "wrong_resolution_floor_fails_closed_before_solver": wrong_floor.get("solver_disposition") == "failed" and wrong_floor.get("failure_classification") == "TEMPORAL_CERTIFICATE_POLICY_UNQUALIFIED" and _no_component_execution(wrong_floor),
        "wrong_accuracy_tolerance_fails_closed_before_solver": wrong_tol.get("solver_disposition") == "failed" and wrong_tol.get("failure_classification") == "TEMPORAL_CERTIFICATE_POLICY_UNQUALIFIED" and _no_component_execution(wrong_tol),
        "full_attempt_level9_fails_closed_before_solver": level9.get("solver_disposition") == "failed" and level9.get("failure_classification") == "TIME_OUTSIDE_CERTIFICATE_INPUT_SCOPE" and _no_component_execution(level9),
        "off_ladder_fails_closed": off_ladder.get("solver_disposition") == "failed" and off_ladder.get("failure_classification") == "TIME_OUTSIDE_DECLARED_SCOPE" and off_ladder.get("temporal_certificate_available") is False,
    }
    return {
        "pass": all(checks.values()),
        "checks": checks,
        "classifications": {
            "missing": missing.get("failure_classification"),
            "wrong_floor": wrong_floor.get("failure_classification"),
            "wrong_tolerance": wrong_tol.get("failure_classification"),
            "level9": level9.get("failure_classification"),
            "off_ladder": off_ladder.get("failure_classification"),
        },
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--include-negative-tests", action="store_true")
    a = p.parse_args()
    if a.material not in d3r.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    cases = [run_case(a.material, attempt, a.canonical_head) for attempt in range(d3r.CANONICAL_MAX_RETRIES + 1)]
    evidence = {
        "schema_version": 1,
        "work_unit": "F-ROSS01 D3G02R3",
        "kind": "FAIL_CLOSED_RUNTIME_CERTIFICATE_WRAPPER_MATERIAL_EVIDENCE",
        "material": a.material,
        "canonical_head": a.canonical_head,
        "case_count": len(cases),
        "cases": cases,
        "positive_matrix_pass": all(c["pass"] for c in cases),
        "max_temporal_indicator": max(float(c["temporal_indicator"]) for c in cases if isinstance(c.get("temporal_indicator"), (int, float))),
        "max_abs_mass_residual_cm": max(abs(float(c["aggregate_mass_residual_cm"])) for c in cases if isinstance(c.get("aggregate_mass_residual_cm"), (int, float))),
        "production_source_delta": [],
    }
    if a.include_negative_tests:
        evidence["negative_tests"] = negative_tests()
    evidence["pass"] = bool(evidence["positive_matrix_pass"] and evidence.get("negative_tests", {"pass": True})["pass"])
    a.output.write_text(json.dumps(evidence, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"material": a.material, "cases": len(cases), "pass": evidence["pass"], "max_temporal_indicator": evidence["max_temporal_indicator"], "max_abs_mass_residual_cm": evidence["max_abs_mass_residual_cm"]}, sort_keys=True, allow_nan=False))
    return 0 if evidence["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
