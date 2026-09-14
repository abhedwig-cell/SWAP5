from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

import ross01_d3g02r_resolution_floor_certificate_adapter as wrapper
import ross01_d3r_fsi31_duration_adapter as d3r
import run_ross01_d2_fsi31_qualification as d2q

MASS_TOL_CM = 1.0e-12
ATTEMPT_INDEX = 1
MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
RESTART_SCHEMA = "ROSSFAST_K_RUNTIME_COMPOSITION_RESTART_V1"


def _canon(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _digest(value) -> str:
    return hashlib.sha256(_canon(value).encode("utf-8")).hexdigest()


def _set_interval(request: dict, t0: float, dt: float) -> dict:
    out = copy.deepcopy(request)
    out["forcing_process_requests"]["t0_day"] = float(t0)
    out["forcing_process_requests"]["t1_day"] = float(t0 + dt)
    return out


def _rebind_state_local_fluxes(request: dict) -> dict:
    out = copy.deepcopy(request)
    row = out["physical_parameters"]["hydraulic_parameters"]
    d2q.d1.j1a.c1r.base.c1.configure_core(row)
    heads = tuple(float(v) for v in out["committed_state"]["pressure_head_cm"])
    ext = d2q.d1.gate_f.fixed_external(heads, "zero")
    out["forcing_process_requests"]["top_boundary"]["q_top_cm_per_day"] = float(ext["q_top"])
    out["forcing_process_requests"]["bottom_boundary"]["qbot_cm_per_day"] = -float(ext["q_bottom"])
    return out


def _positive_candidate(out: dict) -> dict:
    cert = out.get("temporal_certificate") or {}
    diagnostics = out.get("solver_work_diagnostics") or {}
    indicator = out.get("temporal_indicator")
    residual = out.get("unrounded_mass_residual_cm")
    return {
        "candidate_ready": out.get("solver_disposition") == "candidate_ready",
        "certificate_available": out.get("temporal_certificate_available") is True and cert.get("available") is True,
        "certificate_exact_d3r_scope": cert.get("scope") == "EXACT_D3R_QUALIFIED_DOMAIN_ONLY",
        "certificate_refined_two_half": cert.get("candidate_route") == "REFINED_TWO_HALF",
        "certificate_component_trials_recomputed": diagnostics.get("certificate_component_trial_count") == 3,
        "certificate_runtime_only_authority": diagnostics.get("certificate_acceptance_authority") == "CANONICAL_RUNTIME_ONLY",
        "indicator_acceptable": isinstance(indicator, (int, float))
        and math.isfinite(float(indicator))
        and 0.0 <= float(indicator) <= 1.0,
        "mass_hard_gate": isinstance(residual, (int, float))
        and math.isfinite(float(residual))
        and abs(float(residual)) <= MASS_TOL_CM,
        "candidate_only": out.get("accepted") is False
        and out.get("commit_authorized") is False
        and out.get("accepted_publication_authorized") is False,
        "committed_not_mutated": out.get("committed_state_mutated") is False,
        "request_reported_unchanged": out.get("request_object_unchanged") is True,
    }


def qualify(material: str, canonical_head: str) -> dict:
    dt = float(d3r.DURATION_LADDER_DAY[ATTEMPT_INDEX])
    t0 = 811.25

    request_a = d2q.base_request(material, t0=t0, steps=8, perturb=0.0, pre=False)
    request_a = _set_interval(request_a, t0, dt)
    request_a_before = copy.deepcopy(request_a)
    committed_a_before = copy.deepcopy(request_a["committed_state"])
    out_a = wrapper.execute_research_trial(request_a)
    checks_a = _positive_candidate(out_a)
    checks_a["caller_committed_unchanged"] = request_a["committed_state"] == committed_a_before
    checks_a["request_object_exactly_unchanged"] = request_a == request_a_before

    candidate_a = copy.deepcopy(out_a.get("candidate_hydraulic_state"))
    if not isinstance(candidate_a, dict):
        return {
            "workunit": "F-ROSS01_K_RUNTIME",
            "qualification_class": "RESTRICTED_RESEARCH_RUNTIME_COMPOSITION",
            "material": material,
            "canonical_head": canonical_head,
            "pass": False,
            "checks": {f"segment_a::{k}": v for k, v in checks_a.items()},
            "failure": "SEGMENT_A_DID_NOT_PRODUCE_CANDIDATE",
        }

    # This record intentionally models only the RossFast-facing portion of the
    # accepted canonical restart boundary. Canonical F-GC24 owns the actual
    # persistence format and explicitly persists committed physical state only.
    restart_record = {
        "schema": RESTART_SCHEMA,
        "accepted_t1_day": t0 + dt,
        "committed_state": candidate_a,
    }
    restart_text = _canon(restart_record)
    restored = json.loads(restart_text)
    restart_checks = {
        "accepted_candidate_shape_matches_committed_state": set(candidate_a) == set(committed_a_before),
        "restart_contains_committed_state": restored.get("committed_state") == candidate_a,
        "restart_excludes_candidate_container": "candidate_hydraulic_state" not in restart_text,
        "restart_excludes_temporal_certificate": "temporal_certificate" not in restart_text,
        "restart_excludes_temporal_indicator": "temporal_indicator" not in restart_text,
    }

    t0_b = t0 + dt
    request_b = copy.deepcopy(request_a_before)
    request_b["committed_state"] = copy.deepcopy(restored["committed_state"])
    request_b = _set_interval(request_b, t0_b, dt)
    request_b = _rebind_state_local_fluxes(request_b)
    request_b_before = copy.deepcopy(request_b)
    committed_b_before = copy.deepcopy(request_b["committed_state"])

    out_b1 = wrapper.execute_research_trial(copy.deepcopy(request_b))
    out_b2 = wrapper.execute_research_trial(copy.deepcopy(request_b))
    checks_b = _positive_candidate(out_b1)
    checks_b["restart_input_committed_unchanged"] = request_b["committed_state"] == committed_b_before
    checks_b["restart_request_exactly_unchanged"] = request_b == request_b_before
    checks_b["deterministic_restart_replay_candidate"] = (
        out_b1.get("candidate_hydraulic_state") == out_b2.get("candidate_hydraulic_state")
    )
    checks_b["deterministic_restart_replay_certificate"] = (
        out_b1.get("temporal_certificate") == out_b2.get("temporal_certificate")
    )
    checks_b["deterministic_restart_replay_mass"] = (
        out_b1.get("unrounded_mass_residual_cm") == out_b2.get("unrounded_mass_residual_cm")
    )
    checks_b["restart_recomputes_three_component_certificate"] = (
        (out_b1.get("solver_work_diagnostics") or {}).get("certificate_component_trial_count") == 3
        and (out_b2.get("solver_work_diagnostics") or {}).get("certificate_component_trial_count") == 3
    )

    rejected = copy.deepcopy(request_b)
    rejected["forcing_process_requests"]["t1_day"] = t0_b + dt * 0.75
    rejected_before = copy.deepcopy(rejected)
    rejected_out = wrapper.execute_research_trial(rejected)
    rejected_diag = rejected_out.get("solver_work_diagnostics") or {}
    reject_checks = {
        "off_ladder_fails_closed": rejected_out.get("solver_disposition") == "failed",
        "off_ladder_candidate_absent": rejected_out.get("candidate_hydraulic_state") is None,
        "off_ladder_certificate_unavailable": rejected_out.get("temporal_certificate_available") is False,
        "off_ladder_no_component_trials": rejected_diag.get("certificate_component_trial_count") in (None, 0),
        "off_ladder_no_accept_commit": rejected_out.get("accepted") is False
        and rejected_out.get("commit_authorized") is False,
        "off_ladder_committed_not_mutated": rejected_out.get("committed_state_mutated") is False,
        "off_ladder_request_unchanged": rejected == rejected_before,
    }

    all_checks = {
        **{f"segment_a::{k}": v for k, v in checks_a.items()},
        **{f"restart::{k}": v for k, v in restart_checks.items()},
        **{f"segment_b::{k}": v for k, v in checks_b.items()},
        **{f"reject::{k}": v for k, v in reject_checks.items()},
    }
    passed = all(bool(v) for v in all_checks.values())

    return {
        "workunit": "F-ROSS01_K_RUNTIME",
        "qualification_class": "RESTRICTED_RESEARCH_RUNTIME_COMPOSITION",
        "material": material,
        "canonical_head": canonical_head,
        "duration_ladder_index": ATTEMPT_INDEX,
        "duration_day": dt,
        "pass": passed,
        "checks": all_checks,
        "segment_a_candidate_digest": _digest(out_a.get("candidate_hydraulic_state")),
        "restart_committed_digest": _digest(restored.get("committed_state")),
        "segment_b_candidate_digest": _digest(out_b1.get("candidate_hydraulic_state")),
        "segment_a_temporal_indicator": out_a.get("temporal_indicator"),
        "segment_b_temporal_indicator": out_b1.get("temporal_indicator"),
        "segment_a_mass_residual_cm": out_a.get("unrounded_mass_residual_cm"),
        "segment_b_mass_residual_cm": out_b1.get("unrounded_mass_residual_cm"),
        "reject_classification": rejected_out.get("failure_classification"),
        "nonclaims": [
            "NO_PRODUCTION_ADMISSION",
            "NO_RUNTIME_PERFORMANCE_QUALIFICATION",
            "NO_MULTISWAP_QUALIFICATION",
            "NO_GROUNDWATER_SCIENTIFIC_GENERALIZATION",
            "NO_A10_SURFACE_CAP_GENERALIZATION",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--material", required=True, choices=MATERIALS)
    parser.add_argument("--canonical-head", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = qualify(args.material, args.canonical_head)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"material": args.material, "pass": result["pass"]}, sort_keys=True))
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
