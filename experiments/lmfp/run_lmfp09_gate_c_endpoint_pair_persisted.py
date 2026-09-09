from __future__ import annotations

import json
import math
import sys
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c_corrected_interface as gatec


def tolerant_endpoint_bracket(axis, x):
    """Bracket x while accepting only floating-point reconstruction at exact endpoints."""
    lo = axis[0]
    hi = axis[-1]
    lo_tol = 8.0 * math.ulp(max(1.0, abs(lo)))
    hi_tol = 8.0 * math.ulp(max(1.0, abs(hi)))
    if x < lo:
        if lo - x <= lo_tol:
            x = lo
        else:
            raise ValueError(("axis_out_of_range", x, lo, hi))
    if x > hi:
        if x - hi <= hi_tol:
            x = hi
        else:
            raise ValueError(("axis_out_of_range", x, lo, hi))
    if x >= hi:
        return len(axis) - 2, len(axis) - 1
    import bisect
    i = bisect.bisect_right(axis, x) - 1
    return max(0, i), min(len(axis) - 1, i + 1)


def compact_provider_row(row):
    return {
        "material": row["material"],
        "length_cm": row["length_cm"],
        "pass": row["pass"],
        "identity_pass": row["identity"]["pass"],
        "continuity_pass": row["continuity"]["pass"],
        "fail_closed_pass": row["fail_closed"]["pass"],
        "face_matrix_pass": row["face_matrix"]["pass"],
        "face_matrix_metrics": {
            k: v for k, v in row["face_matrix"].items() if k != "rows"
        },
        "memory": row["memory"],
    }


def persist(path: Path, evidence: dict) -> None:
    path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_gate_c_endpoint_pair_persisted.py EVIDENCE_JSON")

    out_path = Path(sys.argv[1])
    ep.bracket = tolerant_endpoint_bracket
    fixtures, pairs = gatec.material_group("synthetic")

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C2_BOUNDED_TRANSFORMED_ENDPOINT_PAIR_SYNTHETIC_QUALIFICATION",
        "candidate": "BOUNDED_TRANSFORMED_ENDPOINT_PAIR_LOG_RATIO",
        "coordinates": ["x_upper=asinh(h_upper/0.01cm)", "x_lower=asinh(h_lower/0.01cm)"],
        "ratio_head_envelope_cm": [ep.core.R_HMIN, ep.core.R_HMAX],
        "axis_base_nodes": ep.AXIS_N,
        "zero_knot_inserted": True,
        "thresholds_changed_from_gate_c1": False,
        "pair_selection_uses_validation_error": False,
        "boundary_roundoff_policy": {
            "kind": "ULP_SCALE_ENDPOINT_RECONSTRUCTION_CLAMP_ONLY",
            "max_ulps": 8,
            "interior_interpolation_changed": False,
            "physical_head_envelope_changed": False,
        },
        "status": "IN_PROGRESS",
        "stage": "INITIALIZED",
        "provider_preparation": {
            "classes": [],
            "shared_bytes_before_metadata_for_tested_classes": 0,
            "offline_oracle_solves": 0,
            "runtime_oracle_calls": 0,
            "pair_specific_table_classes": 0,
        },
        "catalog_admission": False,
        "catalog_blocker": "B110 near-saturation conductivity jump is separately localized and not solved by this coordinate candidate",
        "architecture": {
            "production_code_changed": False,
            "persistent_column_state_added": False,
            "pair_specific_tables": False,
            "shared_immutable_material_geometry_data": True,
            "worker_local_root_scratch": True,
            "single_realized_face_flux": True,
            "mass_compatible": True,
            "no_silent_extrapolation": True,
            "no_silent_solver_switch": True,
            "fullrichards_reference_preserved": True,
        },
    }
    persist(out_path, evidence)

    providers = {}
    try:
        evidence["stage"] = "PROVIDER_PREPARATION"
        persist(out_path, evidence)
        for name, fixture in fixtures.items():
            for length in gatec.HALF_LENGTHS:
                evidence["active_case"] = {"material": name, "half_face_length_cm": length}
                persist(out_path, evidence)
                view, calls, _ = ep.build_provider(fixture, length)
                providers[(name, length)] = view
                memory = view.memory()["bytes_before_metadata"]
                evidence["provider_preparation"]["shared_bytes_before_metadata_for_tested_classes"] += memory
                evidence["provider_preparation"]["offline_oracle_solves"] += calls
                evidence["provider_preparation"]["classes"].append({
                    "material": name,
                    "half_face_length_cm": length,
                    "upper_axis_nodes": view.nx,
                    "lower_axis_nodes": view.nx,
                    "values": view.memory()["values"],
                    "bytes_before_metadata": memory,
                    "oracle_solves": calls,
                })
                persist(out_path, evidence)
        evidence.pop("active_case", None)

        gatec.corrected_interface_flux = ep.corrected_interface_flux
        gatec.build_provider = ep.build_provider

        evidence["stage"] = "PROVIDER_SELF_CHECK"
        persist(out_path, evidence)
        provider_check = ep.provider_self_check(fixtures, providers)
        evidence["provider_self_check"] = provider_check
        evidence["provider_self_check_summary"] = {
            "pass": provider_check["pass"],
            "rows": [compact_provider_row(row) for row in provider_check["rows"]],
        }
        persist(out_path, evidence)

        evidence["stage"] = "HETEROGENEOUS_INTERFACE_MATRIX"
        persist(out_path, evidence)
        interface = gatec.interface_matrix(fixtures, pairs, providers)
        evidence["interface_matrix"] = interface
        persist(out_path, evidence)

        evidence["stage"] = "EXPLICIT_FAIL_CLOSED"
        persist(out_path, evidence)
        fail_closed = gatec.explicit_fail_closed(fixtures, providers)
        evidence["explicit_fail_closed"] = fail_closed
        persist(out_path, evidence)

        evidence["stage"] = "COMPOSED_CONTINUITY"
        persist(out_path, evidence)
        continuity = gatec.continuity_checks(fixtures, pairs, providers)
        evidence["continuity"] = continuity
        persist(out_path, evidence)

        evidence["stage"] = "HOMOGENEOUS_REDUCTION"
        persist(out_path, evidence)
        reduction = gatec.homogeneous_reduction(fixtures, providers, "synthetic")
        evidence["homogeneous_reduction"] = reduction
        persist(out_path, evidence)

        evidence["structural_pass"] = all((
            provider_check["pass"],
            interface["pass"],
            fail_closed["pass"],
            continuity["pass"],
            reduction["pass"],
        ))
        evidence["status"] = "COMPLETED"
        evidence["stage"] = "COMPLETE"
        evidence["decision"] = (
            "GATE_C2_SYNTHETIC_ENDPOINT_PAIR_QUALIFIED"
            if evidence["structural_pass"]
            else "GATE_C2_SYNTHETIC_ENDPOINT_PAIR_FAILED_LOCALIZE_WITHOUT_THRESHOLD_RELAXATION"
        )
        persist(out_path, evidence)
        print(json.dumps(evidence, indent=2, sort_keys=True))
        raise SystemExit(0 if evidence["structural_pass"] else 1)
    except SystemExit:
        raise
    except Exception as exc:
        evidence["status"] = "FAILED_WITH_PERSISTED_DIAGNOSTIC"
        evidence["failure"] = {
            "stage": evidence.get("stage"),
            "active_case": evidence.get("active_case"),
            "exception_type": type(exc).__name__,
            "exception": str(exc),
            "traceback": traceback.format_exc(),
        }
        evidence["decision"] = "GATE_C2_EXECUTION_FAILED_LOCALIZE_BEFORE_INTERPRETATION"
        persist(out_path, evidence)
        raise


if __name__ == "__main__":
    main()
