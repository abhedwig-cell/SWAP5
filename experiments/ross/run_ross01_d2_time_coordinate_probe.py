from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import ross01_d2_fsi31_adapter as adapter


def request(t0: float, t1: float) -> dict:
    return {
        "contract_id": adapter.CONTRACT_ID,
        "contract_version": adapter.CONTRACT_VERSION,
        "requested_capabilities": [
            "top.prescribed_flux",
            "bottom.prescribed_flux",
            "bottom_exchange.candidate_flux",
        ],
        "physical_parameters": {
            "material_id": "B01",
            "hydraulic_parameters": copy.deepcopy(adapter.MATERIAL_ROWS["B01"]),
            "constitutive_family": "UNIMODAL_MUALEM_VAN_GENUCHTEN_USING_KSATFIT_WITH_KSATEXM_DISABLED",
            "grid": {"dimension": "1D_VERTICAL", "n_cells": 16, "uniform_dz_cm": 10.0},
            "active_physics": ["unsaturated_soil_water"],
        },
        "committed_state": {
            "pressure_head_cm": [-100.0] * 16,
            "water_content": [0.2] * 16,
            "ponding_depth_cm": None,
            "groundwater_level_cm": None,
        },
        "forcing_process_requests": {
            "t0_day": t0,
            "t1_day": t1,
            "top_boundary": {"mode": "top.prescribed_flux", "q_top_cm_per_day": 0.0},
            "bottom_boundary": {"mode": "bottom.prescribed_flux", "qbot_cm_per_day": 0.0},
            "general_sources_sinks": "none",
            "root_sink": "none",
            "local_terminal_preconditioner": {"requested": False, "required": False},
        },
        "numerical_configuration": {
            "equal_internal_substeps": 4,
            "sigma": 0.5,
            "mass_tolerance_cm": 1e-12,
            "deterministic_replay": "contract_equivalent",
        },
        "worker_job_scratch": {"persistent": False, "warm_start_payload": None},
    }


def main() -> int:
    probes = []
    for t0 in (0.0, 37.125, 12345.75, -4321.5):
        original = request(t0, t0 + adapter.HORIZON_DAY)
        snapshot = copy.deepcopy(original)
        try:
            validated = adapter.validate_request(original)
            passed = (
                validated == original
                and original == snapshot
                and validated["forcing_process_requests"]["t0_day"] == t0
                and validated["forcing_process_requests"]["t1_day"] == t0 + adapter.HORIZON_DAY
            )
            classification = None
        except adapter.RequestError as exc:
            passed = False
            classification = exc.classification
        probes.append({
            "name": f"generic_t0_{t0}",
            "pass": passed,
            "failure_classification": classification,
        })

    t0 = 12345.75
    outside = request(t0, t0 + adapter.HORIZON_DAY + 1.0e-7)
    try:
        adapter.validate_request(outside)
        outside_pass = False
        outside_classification = None
    except adapter.RequestError as exc:
        outside_pass = exc.classification == "TIME_OUTSIDE_DECLARED_SCOPE"
        outside_classification = exc.classification
    probes.append({
        "name": "duration_outside_declared_scope",
        "pass": outside_pass,
        "failure_classification": outside_classification,
    })

    invalid = request(5.0, 5.0)
    try:
        adapter.validate_request(invalid)
        invalid_pass = False
        invalid_classification = None
    except adapter.RequestError as exc:
        invalid_pass = exc.classification == "INVALID_TIME_INTERVAL"
        invalid_classification = exc.classification
    probes.append({
        "name": "t1_not_greater_than_t0",
        "pass": invalid_pass,
        "failure_classification": invalid_classification,
    })

    passed = all(item["pass"] for item in probes)
    evidence = {
        "schema_version": 1,
        "work_unit": "F-ROSS01 D2",
        "qualification_slice": "GENERIC_TIME_COORDINATE_REPRESENTATION",
        "qualified_semantic_duration_day": adapter.HORIZON_DAY,
        "endpoint_ulp_multiplier": adapter.TIME_ENDPOINT_ULP_MULTIPLIER,
        "scope_expansion": False,
        "worker_time_origin_policy": "translate generic absolute coordinate to local zero only after endpoint validation",
        "probes": probes,
        "all_pass": passed,
        "decision": "QUALIFIED_D2_GENERIC_TIME_COORDINATE_REPRESENTATION" if passed else "D2_GENERIC_TIME_COORDINATE_GAPS_IDENTIFIED",
    }
    Path("F-ROSS01_D2_TIME_COORDINATE_EVIDENCE.json").write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n"
    )
    print(json.dumps({"all_pass": passed, "failed": [p["name"] for p in probes if not p["pass"]]}, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
