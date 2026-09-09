from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import MaterialFixture
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable
from run_lmfp09_homogeneous_c1_coarse import asymptotic_continuity_test, tolerant_bracket
import run_lmfp09_saturation_aligned_ratio_knots as sat
import run_lmfp09_saturation_aligned_homogeneous_matrix as b2
from lmfp09_staring2018_catalog import CATALOG, b110_material

SHARD_COUNT = 6
MATERIALS_PER_SHARD = 6

core.AsinhMFPTable = HermiteMFPTable
core.bracket = tolerant_bracket
core.continuity_test = asymptotic_continuity_test
core.MASTER_NX = 33
core.VIEW_NX = (33,)


def shard_rows(shard_index: int):
    if not 0 <= shard_index < SHARD_COUNT:
        raise ValueError(("invalid_shard", shard_index, SHARD_COUNT))
    start = shard_index * MATERIALS_PER_SHARD
    stop = start + MATERIALS_PER_SHARD
    return CATALOG[start:stop]


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp09_staring2018_catalog_shard.py EVIDENCE_JSON SHARD_INDEX")
    evidence_path = Path(sys.argv[1])
    shard_index = int(sys.argv[2])
    rows = shard_rows(shard_index)
    fixtures = [MaterialFixture(row.sfu, b110_material(row)) for row in rows]

    mfp_coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
    mfp_tables = {f.name: HermiteMFPTable(f.material, mfp_coord, core.MFP_N) for f in fixtures}

    classes = []
    all_pass = True
    total_base_oracle = 0
    total_extra_oracle = 0
    for local_index, (row, fixture) in enumerate(zip(rows, fixtures)):
        global_index = shard_index * MATERIALS_PER_SHARD + local_index
        for li, length in enumerate(core.LENGTHS):
            master = core.RatioMaster(fixture, length, mfp_tables[fixture.name])
            view = sat.SaturationAlignedRatioView(master)
            probes = core.build_probe_rows(fixture, length, 431091000 + 10 * global_index + li)
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
                "source_parameters": {
                    "ORES": row.ores, "OSAT": row.osat, "ALFA": row.alfa, "NPAR": row.npar,
                    "KSATFIT": row.ksatfit, "KSATEXM": row.ksatexm, "LEXP": row.lexp, "H_ENPR": row.h_enpr,
                },
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
                "regimes": b2.regime_summary(face),
            })

    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "B3_STARING2018_PRODUCTION_CATALOG_HOMOGENEOUS_SHARD",
        "shard_index": shard_index,
        "shard_count": SHARD_COUNT,
        "materials": [row.sfu for row in rows],
        "material_status": "ACTUAL_SWAP_4_3_1_DISTRIBUTED_STARINGREEKS_2018_CATALOG",
        "face_lengths_cm": list(core.LENGTHS),
        "representation": "CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO_WITH_HLOWER_ZERO_ALIGNED_HEAD_KNOTS",
        "selection_uses_validation_error": False,
        "thresholds_changed_from_B2": False,
        "mfp_material_table": {
            "coordinate": "x=asinh(h/0.01 cm)", "nodes": core.MFP_N,
            "head_envelope_cm": [core.MFP_HMIN, core.MFP_HMAX], "ownership": "immutable shared per hydraulic material",
        },
        "ratio_representation": {
            "base_head_nodes": 33, "gradient_nodes": len(core.G_AXIS),
            "upper_head_envelope_cm": [core.R_HMIN, core.R_HMAX],
            "gradient_envelope": [core.G_AXIS[0], core.G_AXIS[-1]],
            "knot_rule": "add h_upper=-g*L for every fixed gradient node whose h_lower=0 crossing is inside the upper-head envelope",
            "runtime_oracle_calls": 0,
        },
        "offline_preparation_cost": {
            "base_master_oracle_solves": total_base_oracle,
            "extra_crossing_knot_oracle_solves": total_extra_oracle,
        },
        "classes": classes,
        "structural_pass": all_pass,
        "scope": {
            "corrected_face_upper_head_envelope_cm": [core.R_HMIN, core.R_HMAX],
            "deeper_gate_A_mfp_tail_to_minus1e8_cm": "NOT_CORRECTED_FACE_ADMISSION",
            "positive_pressure_endpoint": "EXPLICITLY_SAMPLED_PER_CATALOG_MATERIAL",
            "heterogeneous_interface": "NOT_ADMITTED_BY_THIS_GATE",
            "transient": "NOT_RERUN_BY_THIS_GATE",
            "groundwater": "NOT_ADMITTED",
            "production_solver": "NOT_ADMITTED",
        },
        "decision": (
            "STARING2018_CATALOG_SHARD_QUALIFIED"
            if all_pass else
            "STARING2018_CATALOG_SHARD_FAILED_LOCALIZE_BEFORE_ANY_THRESHOLD_OR_DENSITY_CHANGE"
        ),
    }
    evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
