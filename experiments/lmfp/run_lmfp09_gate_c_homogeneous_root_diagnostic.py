from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_corrected_interface as gate
from run_lmfp09_coordinate_envelope import MaterialFixture
from run_lmfp06_darcian_reference import solve_steady_flux
from lmfp09_staring2018_catalog import CATALOG_BY_ID, b110_material

MATERIALS = ("B06", "B12")
HALVES = (5.0, 10.0)
H_UPPER = (-100.0, -10.0, -1.0, 0.0)
TOTAL_G = (-5.0, 0.0, 0.5, 1.0, 2.0, 5.0)
TRACE_KEEP = 12


def write_evidence(path, evidence):
    path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")


def root_trace(view_u, view_l, h_u, h_l):
    lo, hi = gate.feasible_interface_interval(view_u, view_l, h_u, h_l)

    def evaluate(h_i):
        q_u = view_u.flux(h_u, h_i)
        q_l = view_l.flux(h_i, h_l)
        residual = q_u - q_l
        scale = max(1.0, abs(q_u), abs(q_l))
        return {
            "h_interface": h_i,
            "q_upper": q_u,
            "q_lower": q_l,
            "residual": residual,
            "scaled_residual": abs(residual) / scale,
            "g_upper": (h_i - h_u) / view_u.length,
            "g_lower": (h_l - h_i) / view_l.length,
        }

    left = evaluate(lo)
    right = evaluate(hi)
    initial = {"left": dict(left), "right": dict(right)}
    iterations = []
    termination = None

    for iteration in range(1, gate.ROOT_MAX + 1):
        mid = 0.5 * (lo + hi)
        sample = evaluate(mid)
        sample["iteration"] = iteration
        sample["bracket_lo"] = lo
        sample["bracket_hi"] = hi
        sample["bracket_width"] = hi - lo
        sample["mid_equals_lo"] = mid == lo
        sample["mid_equals_hi"] = mid == hi
        iterations.append(sample)

        if sample["scaled_residual"] <= gate.ROOT_TOL:
            termination = "accepted"
            break
        if left["residual"] * sample["residual"] <= 0.0:
            hi = mid
            right = sample
        else:
            lo = mid
            left = sample

    final_mid = 0.5 * (lo + hi)
    final_sample = evaluate(final_mid)
    final = {
        "lo": lo,
        "hi": hi,
        "width": hi - lo,
        "mid": final_mid,
        "mid_equals_lo": final_mid == lo,
        "mid_equals_hi": final_mid == hi,
        "left": left,
        "right": right,
        "mid_sample": final_sample,
        "opposite_endpoint_signs": left["residual"] * right["residual"] <= 0.0,
        "endpoint_residual_jump": right["residual"] - left["residual"],
        "endpoint_flux_jump_upper": right["q_upper"] - left["q_upper"],
        "endpoint_flux_jump_lower": right["q_lower"] - left["q_lower"],
    }

    if termination is None:
        tiny_width = final["width"] <= 64.0 * math.ulp(max(abs(final_mid), 1.0))
        finite_jump = all(
            math.isfinite(v)
            for v in (
                final["endpoint_residual_jump"],
                final["endpoint_flux_jump_upper"],
                final["endpoint_flux_jump_lower"],
            )
        )
        if tiny_width and finite_jump and final["opposite_endpoint_signs"]:
            classification = "VALUE_DISCONTINUITY_OR_FLOATING_BRANCH_AT_COLLAPSED_BRACKET"
        elif final["mid_equals_lo"] or final["mid_equals_hi"]:
            classification = "FLOATING_POINT_BRACKET_STAGNATION"
        else:
            classification = "UNRESOLVED_NONCONVERGENCE"
    else:
        classification = "ROOT_ACCEPTED"

    return {
        "initial_bracket": initial,
        "termination": termination or "iteration_cap",
        "classification": classification,
        "iterations_total": len(iterations),
        "iterations_first": iterations[:TRACE_KEEP],
        "iterations_last": iterations[-TRACE_KEEP:],
        "minimum_scaled_residual": min(s["scaled_residual"] for s in iterations),
        "final": final,
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit(
            "usage: run_lmfp09_gate_c_homogeneous_root_diagnostic.py EVIDENCE_JSON"
        )

    out_path = Path(sys.argv[1])
    fixtures = {
        name: MaterialFixture(name, b110_material(CATALOG_BY_ID[name]))
        for name in MATERIALS
    }

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "subgate": "C1_HOMOGENEOUS_ROOT_DIAGNOSTIC",
        "purpose": (
            "Localize Gate-C homogeneous-reduction root failures without changing "
            "representation, thresholds, physics, or root acceptance."
        ),
        "materials": list(MATERIALS),
        "half_lengths_cm": list(HALVES),
        "root_tolerance": gate.ROOT_TOL,
        "root_iteration_cap": gate.ROOT_MAX,
        "cases": [],
        "failures": [],
        "production_admission": False,
        "thresholds_changed": False,
        "root_semantics_changed": False,
        "architecture": {
            "production_code_changed": False,
            "persistent_column_state_added": False,
            "diagnostic_only": True,
            "reference_richards_preserved": True,
        },
        "status": "PREPARING_PROVIDERS",
    }
    write_evidence(out_path, evidence)

    providers = {}
    for name, fixture in fixtures.items():
        for half in HALVES:
            providers[(name, half)] = gate.build_provider(fixture, half)[0]
    evidence["status"] = "RUNNING_CASES"
    write_evidence(out_path, evidence)

    for name in MATERIALS:
        fixture = fixtures[name]
        mat = fixture.material
        for half in HALVES:
            upper = providers[(name, half)]
            lower = providers[(name, half)]
            full = gate.build_provider(fixture, 2.0 * half)[0]
            for h_u in H_UPPER:
                for g_total in TOTAL_G:
                    h_l = h_u + g_total * 2.0 * half
                    if not gate.core.R_HMIN <= h_l <= gate.core.R_HMAX:
                        continue
                    case = {
                        "material": name,
                        "half_length_cm": half,
                        "h_u": h_u,
                        "h_l": h_l,
                        "g_total": g_total,
                    }
                    try:
                        fit = gate.corrected_interface_flux(
                            upper, lower, h_u, h_l
                        )
                        q_full = full.flux(h_u, h_l)
                        q_ref = solve_steady_flux(
                            mat, mat, h_u, h_l, half, half
                        )[0]
                        case.update(
                            {
                                "pass_root": True,
                                "q_composed": fit.q,
                                "h_interface": fit.h_interface,
                                "root_iterations": fit.iterations,
                                "equal_flux_scaled_residual": fit.scaled_residual,
                                "q_full_candidate": q_full,
                                "q_ref": q_ref,
                            }
                        )
                    except Exception as exc:
                        case.update(
                            {
                                "pass_root": False,
                                "error_type": type(exc).__name__,
                                "error": str(exc),
                            }
                        )
                        try:
                            case["root_trace"] = root_trace(
                                upper, lower, h_u, h_l
                            )
                        except Exception as trace_exc:
                            case["trace_error"] = (
                                type(trace_exc).__name__ + ":" + str(trace_exc)
                            )
                        evidence["failures"].append(dict(case))
                    evidence["cases"].append(case)
                    write_evidence(out_path, evidence)

    evidence["status"] = "COMPLETE"
    evidence["case_count"] = len(evidence["cases"])
    evidence["failure_count"] = len(evidence["failures"])
    evidence["decision"] = (
        "NO_HOMOGENEOUS_ROOT_FAILURES"
        if not evidence["failures"]
        else "HOMOGENEOUS_ROOT_FAILURES_LOCALIZED"
    )
    write_evidence(out_path, evidence)
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if not evidence["failures"] else 1)


if __name__ == "__main__":
    main()
