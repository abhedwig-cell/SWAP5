from __future__ import annotations

import argparse
import copy
import json
import math
import tempfile
from pathlib import Path

import ross01_d3g02_temporal_certificate_adapter as cert
import ross01_d3r_fsi31_duration_adapter as d3r
import run_ross01_d2_fsi31_qualification as d2q
import run_ross01_d3g02_temporal_certificate_calibration as cal
import run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner as d1

REFERENCE_BOUND_EPS = 5.0e-13


def set_dt(req: dict, t0: float, dt: float) -> dict:
    out = copy.deepcopy(req)
    out["forcing_process_requests"]["t0_day"] = float(t0)
    out["forcing_process_requests"]["t1_day"] = float(t0 + dt)
    return out


def contract_values() -> tuple[float, float]:
    payload = json.loads(cert._CONTRACT.read_text())
    cfg = payload["runtime_certificate_candidate"]
    return float(cfg["safety_factor"]), float(cfg["accuracy_tolerance"])


def run_case(attempt: int, material: str, canonical_head: str) -> dict:
    dt = d3r.DURATION_LADDER_DAY[attempt]
    t0 = 91.375 + attempt
    req = d2q.base_request(material, t0=t0, steps=8, perturb=0.0, pre=False)
    req = set_dt(req, t0, dt)
    committed_before = copy.deepcopy(req["committed_state"])
    out = cert.execute_research_trial(req)
    factor, tolerance = contract_values()

    checks = {
        "candidate_ready": out.get("solver_disposition") == "candidate_ready",
        "certificate_available": out.get("temporal_certificate_available") is True,
        "indicator_finite_nonnegative": isinstance(out.get("temporal_indicator"), (int, float)) and math.isfinite(float(out["temporal_indicator"])) and float(out["temporal_indicator"]) >= 0.0,
        "candidate_only": out.get("accepted") is False and out.get("commit_authorized") is False and out.get("accepted_publication_authorized") is False,
        "committed_origin_unchanged": req["committed_state"] == committed_before and out.get("committed_state_mutated") is False,
        "aggregate_mass_hard_gate": isinstance(out.get("unrounded_mass_residual_cm"), (int, float)) and abs(float(out["unrounded_mass_residual_cm"])) <= d3r.HARD_MASS_TOL_CM,
        "full_interval_preserved": (out.get("time_interval") or {}).get("duration_ladder_index") == attempt,
        "refined_candidate_route": (out.get("temporal_certificate") or {}).get("candidate_route") == "REFINED_TWO_HALF",
        "canonical_acceptance_owner_only": (out.get("solver_work_diagnostics") or {}).get("certificate_acceptance_authority") == "CANONICAL_RUNTIME_ONLY",
    }

    raw = None
    reference_error = None
    conservative_bound = None
    implication_ok = False
    independent_reference_ok = False
    if checks["candidate_ready"] and checks["certificate_available"]:
        theta = tuple(float(v) for v in out["candidate_hydraulic_state"]["water_content"])
        table = cal.configure_reference(material)
        theta0 = tuple(float(v) for v in req["committed_state"]["water_content"])
        ext = cal.reference_external(req)
        reference = cal.reference_solve(theta0, table, ext, dt, 64)
        span = float(d1.gate_d.core().THETA_S - d1.gate_d.core().THETA_R)
        reference_error = cal.normalized_linf(theta, reference, span)
        raw = float(out["temporal_certificate"]["raw_estimator"])
        conservative_bound = factor * raw
        independent_reference_ok = math.isfinite(reference_error) and reference_error <= conservative_bound + REFERENCE_BOUND_EPS
        indicator = float(out["temporal_indicator"])
        implication_ok = indicator > 1.0 or reference_error <= tolerance + REFERENCE_BOUND_EPS
        expected_indicator = conservative_bound / tolerance
        checks["indicator_formula_exact"] = math.isclose(indicator, expected_indicator, rel_tol=0.0, abs_tol=max(2.0e-15, 4.0 * math.ulp(expected_indicator)))
    else:
        checks["indicator_formula_exact"] = False
    checks["independent_reference_within_conservative_bound"] = independent_reference_ok
    checks["canonical_indicator_acceptance_implies_reference_error_within_tolerance"] = implication_ok

    return {
        "work_unit": "F-ROSS01 D3G02",
        "kind": "temporal_certificate_qualification_case",
        "live_canonical_head": canonical_head,
        "attempt_index": attempt,
        "material": material,
        "duration_day": dt,
        "pass": all(checks.values()),
        "checks": checks,
        "temporal_indicator": out.get("temporal_indicator"),
        "raw_estimator": raw,
        "safety_factor": factor,
        "accuracy_tolerance": tolerance,
        "independent_reference_error": reference_error,
        "conservative_error_bound": conservative_bound,
        "canonical_would_accept_temporal_certificate": isinstance(out.get("temporal_indicator"), (int, float)) and math.isfinite(float(out["temporal_indicator"])) and 0.0 <= float(out["temporal_indicator"]) <= 1.0,
        "aggregate_mass_residual_cm": out.get("unrounded_mass_residual_cm"),
        "production_source_delta": [],
    }


def negative_tests() -> dict:
    factor, tolerance = contract_values()
    t0 = 211.25
    base = d2q.base_request("B01", t0=t0, steps=8, perturb=0.0, pre=False)

    level9 = set_dt(base, t0, d3r.DURATION_LADDER_DAY[9])
    level9_out = cert.execute_research_trial(level9)

    off_ladder = set_dt(base, t0, d3r.DURATION_LADDER_DAY[0] * 0.9)
    off_ladder_out = cert.execute_research_trial(off_ladder)

    original_contract = cert._CONTRACT
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "unqualified.json"
        payload = json.loads(original_contract.read_text())
        payload["runtime_certificate_candidate"]["safety_factor"] = None
        payload["runtime_certificate_candidate"]["accuracy_tolerance"] = None
        p.write_text(json.dumps(payload))
        cert._CONTRACT = p
        try:
            valid = set_dt(base, t0, d3r.DURATION_LADDER_DAY[0])
            no_constants = cert.execute_research_trial(valid)
        finally:
            cert._CONTRACT = original_contract

    tests = {
        "full_input_level9_fails_closed": level9_out.get("solver_disposition") == "failed" and level9_out.get("failure_classification") == "TIME_OUTSIDE_CERTIFICATE_INPUT_SCOPE" and level9_out.get("temporal_certificate_available") is False,
        "off_ladder_fails_closed": off_ladder_out.get("solver_disposition") == "failed" and off_ladder_out.get("failure_classification") == "TIME_OUTSIDE_DECLARED_SCOPE" and off_ladder_out.get("temporal_certificate_available") is False,
        "unqualified_constants_fail_closed": no_constants.get("solver_disposition") == "failed" and no_constants.get("failure_classification") == "TEMPORAL_CERTIFICATE_CONSTANTS_UNQUALIFIED" and no_constants.get("temporal_certificate_available") is False,
        "qualified_constants_positive": factor > 0.0 and tolerance > 0.0,
    }
    return {
        "pass": all(tests.values()),
        "tests": tests,
        "level9_classification": level9_out.get("failure_classification"),
        "off_ladder_classification": off_ladder_out.get("failure_classification"),
        "no_constants_classification": no_constants.get("failure_classification"),
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--attempt-index", type=int, required=True)
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--include-negative-tests", action="store_true")
    a = p.parse_args()
    if a.attempt_index not in range(d3r.CANONICAL_MAX_RETRIES + 1):
        raise SystemExit("attempt-index outside 0..8")
    if a.material not in d3r.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")
    evidence = run_case(a.attempt_index, a.material, a.canonical_head)
    if a.include_negative_tests:
        evidence["negative_tests"] = negative_tests()
        evidence["pass"] = bool(evidence["pass"] and evidence["negative_tests"]["pass"])
    a.output.write_text(json.dumps(evidence, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"attempt_index": a.attempt_index, "material": a.material, "pass": evidence["pass"], "indicator": evidence["temporal_indicator"], "reference_error": evidence["independent_reference_error"]}, sort_keys=True, allow_nan=False))
    return 0 if evidence["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
