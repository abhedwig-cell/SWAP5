from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable
from run_lmfp09_homogeneous_c1_coarse import asymptotic_continuity_test, tolerant_bracket
import run_lmfp09_saturation_aligned_ratio_knots as sat

core.AsinhMFPTable = HermiteMFPTable
core.bracket = tolerant_bracket
core.continuity_test = asymptotic_continuity_test
core.MASTER_NX = 33
core.VIEW_NX = (33,)


def regime_summary(face):
    active = [r for r in face["rows"]
              if not r.get("failed") and abs(r["q_ref"]) >= r["active_floor"]]

    def summarize(rows):
        errors = [r["corrected_error"] for r in rows]
        signs = sum(1 for r in rows if r["q_corrected"] * r["q_ref"] < 0.0)
        return {
            "active_cases": len(rows),
            "p90_rel_error": core.percentile(errors, 0.90) if errors else None,
            "max_rel_error": max(errors) if errors else None,
            "sign_mismatches": signs,
        }

    regimes = {
        "very_dry_both_heads_le_minus1e4_cm": [
            r for r in active if max(r["h_u"], r["h_l"]) <= -1.0e4
        ],
        "ordinary_unsaturated_both_negative_outside_near_sat": [
            r for r in active
            if r["h_u"] < -0.1 and r["h_l"] < -0.1
            and max(r["h_u"], r["h_l"]) > -1.0e4
        ],
        "near_saturation_abs_heads_le_10_cm": [
            r for r in active if max(abs(r["h_u"]), abs(r["h_l"])) <= 10.0
        ],
        "zero_crossing_or_touch": [
            r for r in active if min(r["h_u"], r["h_l"]) <= 0.0 <= max(r["h_u"], r["h_l"])
        ],
        "positive_endpoint": [
            r for r in active if r["h_u"] > 0.0 or r["h_l"] > 0.0
        ],
    }
    return {name: summarize(rows) for name, rows in regimes.items()}


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_saturation_aligned_homogeneous_matrix.py EVIDENCE_JSON")

    mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
    mfp_tables = {f.name: HermiteMFPTable(f.material, mfp_coord, core.MFP_N)
                  for f in core.ACTIVE}

    classes = []
    all_pass = True
    total_base_oracle = 0
    total_extra_oracle = 0
    for fi, fixture in enumerate(core.ACTIVE):
        for li, length in enumerate(core.LENGTHS):
            master = core.RatioMaster(fixture, length, mfp_tables[fixture.name])
            view = sat.SaturationAlignedRatioView(master)
            probes = core.build_probe_rows(fixture, length, 431090100 + 100 * fi + li)
            identity = core.identity_test(view)
            continuity = asymptotic_continuity_test(view)
            fail_closed = core.fail_closed_test(view)
            face = core.metrics_for_view(view, probes)
            class_pass = identity["pass"] and continuity["pass"] and fail_closed["pass"] and face["pass"]
            all_pass = all_pass and class_pass
            total_base_oracle += master.oracle_solves
            total_extra_oracle += view.extra_oracle_solves
            classes.append({
                "material": fixture.name,
                "length_cm": length,
                "pass": class_pass,
                "ratio_head_nodes": view.nx,
                "gradient_nodes": len(core.G_AXIS),
                "inserted_crossing_knots": sum(1 for r in view.crossing_knots if r["inserted"]),
                "memory": view.memory(),
                "base_master_oracle_solves": master.oracle_solves,
                "extra_crossing_knot_oracle_solves": view.extra_oracle_solves,
                "identity": identity,
                "asymptotic_continuity": continuity,
                "fail_closed": fail_closed,
                "face_matrix": face,
                "regimes": regime_summary(face),
            })

    max_bytes = max(c["memory"]["bytes_before_metadata"] for c in classes)
    max_nodes = max(c["ratio_head_nodes"] for c in classes)
    min_nodes = min(c["ratio_head_nodes"] for c in classes)

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "B2_SATURATION_ALIGNED_EXPANDED_HOMOGENEOUS_MATRIX",
        "representation": "CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO_WITH_HLOWER_ZERO_ALIGNED_HEAD_KNOTS",
        "selection_uses_validation_error": False,
        "thresholds_changed_from_B1": False,
        "materials": [f.name for f in core.ACTIVE],
        "material_status": "F-LMFP08_REFERENCE_HYDRAULIC_FIXTURES_NOT_YET_ACTUAL_PRODUCTION_B1_10_CATALOG",
        "face_lengths_cm": list(core.LENGTHS),
        "mfp_material_table": {
            "coordinate": "x=asinh(h/0.01 cm)",
            "nodes": core.MFP_N,
            "head_envelope_cm": [core.MFP_HMIN, core.MFP_HMAX],
            "ownership": "immutable shared per hydraulic material",
        },
        "ratio_representation": {
            "base_head_nodes": 33,
            "actual_head_nodes_range": [min_nodes, max_nodes],
            "gradient_nodes": len(core.G_AXIS),
            "upper_head_envelope_cm": [core.R_HMIN, core.R_HMAX],
            "gradient_envelope": [core.G_AXIS[0], core.G_AXIS[-1]],
            "knot_rule": "add h_upper=-g*L for every fixed gradient node whose h_lower=0 crossing is inside the upper-head envelope",
            "max_bytes_per_material_geometry_class_before_metadata": max_bytes,
            "runtime_oracle_calls": 0,
        },
        "offline_preparation_cost": {
            "base_master_oracle_solves": total_base_oracle,
            "extra_crossing_knot_oracle_solves": total_extra_oracle,
        },
        "classes": classes,
        "structural_pass": all_pass,
        "scope_interpretation": {
            "corrected_face_upper_head_envelope_cm": [core.R_HMIN, core.R_HMAX],
            "deeper_gate_A_mfp_tail_to_minus1e8_cm": "NOT_YET_CORRECTED_FACE_ADMISSION; ratio lookup fails closed below -1e6 cm upper head",
            "near_saturation": "explicitly tested in the homogeneous matrix",
            "h_zero_crossing": "explicitly geometry-aligned and tested",
            "positive_pressure_endpoint": "explicitly sampled in the homogeneous matrix but still reference-fixture evidence only",
            "heterogeneous_interface": "not admitted by this gate",
            "production_material_catalog": "not admitted by this gate",
            "transient": "not rerun by this gate",
            "tangent": "not admitted; local derivative jumps at piecewise-linear knot boundaries remain registered",
            "groundwater": "not admitted",
            "production_solver": "not admitted",
        },
        "architecture": {
            "production_code_changed": False,
            "physics_changed": False,
            "mass_semantics_changed": False,
            "shared_immutable_tables": True,
            "per_column_tables": False,
            "bounded_table_cardinality": True,
            "runtime_lookup_remains_bounded": True,
            "no_silent_extrapolation": True,
            "no_silent_solver_switch": True,
            "fullrichards_reference_preserved": True,
        },
        "decision_if_pass": "QUALIFIED_SATURATION_ALIGNED_EXPANDED_REFERENCE_HOMOGENEOUS_MATRIX_READY_FOR_PRODUCTION_CATALOG_AND_HETEROGENEOUS_INTERFACE_QUALIFICATION",
        "decision_if_fail": "SATURATION_ALIGNED_REFERENCE_HOMOGENEOUS_MATRIX_NOT_QUALIFIED_LOCALIZE_FAILURE_BEFORE_MORE_DENSITY",
    }

    evidence["decision"] = evidence["decision_if_pass"] if all_pass else evidence["decision_if_fail"]
    Path(sys.argv[1]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
