from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c3_anchored_endpoint_axis as c3
import run_lmfp09_gate_c6a_admissible_envelope_classifier as c6a
import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import FIXTURES

PROVIDER_BASE_N = 33
EXPECTED_AXIS_NODES = 49
SE_MIN = 1.0e-6
G_MAX = 10000.0
DH_MAX = 100000.0
KR_MAX = 1000000.0
GRADIENT_SEED = 7092026
GRADIENT_RAW_CASES = 240
HEAD_PAIR_SEED = 9102026
HEAD_PAIR_RAW_CASES = 360
MIN_ADMITTED = 100
MIN_ACTIVE_ADMITTED = 60
ALLOWED_CLASSES = (("reference_sand", 10.0), ("very_fast", 5.0))


def raw_gradient_family(length):
    rng = random.Random(GRADIENT_SEED)
    coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.R_HMIN, hmax=core.R_HMAX)
    rows = []
    for _ in range(GRADIENT_RAW_CASES):
        hu = coord.h(rng.uniform(coord.xmin, coord.xmax))
        if rng.random() < 0.5:
            g = rng.uniform(-6.0, 8.0)
        else:
            g = rng.uniform(-24.0, 24.0)
        hl = hu + g * length
        rows.append({"h_u": hu, "h_l": hl, "g": g,
                     "probe_source": "C6B_UNSEEN_GRADIENT_FAMILY"})
    return rows


def raw_head_pair_family(length):
    rng = random.Random(HEAD_PAIR_SEED)
    coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.R_HMIN, hmax=core.R_HMAX)
    rows = []
    for _ in range(HEAD_PAIR_RAW_CASES):
        hu = coord.h(rng.uniform(coord.xmin, coord.xmax))
        hl = coord.h(rng.uniform(coord.xmin, coord.xmax))
        rows.append({"h_u": hu, "h_l": hl, "g": (hl - hu) / length,
                     "probe_source": "C6B_UNSEEN_HEAD_PAIR_FAMILY"})
    return rows


def inside_provider_head_envelope(row):
    return (core.R_HMIN <= row["h_u"] <= core.R_HMAX and
            core.R_HMIN <= row["h_l"] <= core.R_HMAX)


def classifier_accepts(mat, row):
    feat = c6a.features(mat, row)
    return (feat["min_se"] >= SE_MIN and feat["abs_g"] <= G_MAX and
            feat["abs_dh"] <= DH_MAX and feat["k_ratio"] <= KR_MAX), feat


def form_reference_row(mat, row):
    q_ref = core.direct_flux(mat, row["h_u"], row["h_l"], CURRENT_LENGTH)
    return {
        **row,
        "q_ref": q_ref,
        "active_floor": 1.0e-8 * max(mat.conductivity(0.0), 1.0),
        "strong_gradient": abs(row["g"]) >= 5.0,
        "near_saturation": max(abs(row["h_u"]), abs(row["h_l"])) <= 10.0,
    }


def select_holdout(mat, length):
    raw = raw_gradient_family(length) + raw_head_pair_family(length)
    counts = {
        "raw_total": len(raw),
        "raw_gradient_family": GRADIENT_RAW_CASES,
        "raw_head_pair_family": HEAD_PAIR_RAW_CASES,
        "outside_provider_head_envelope": 0,
        "inside_provider_head_envelope": 0,
        "classifier_rejected": 0,
        "classifier_admitted": 0,
    }
    admitted = []
    family_counts = {}
    for row in raw:
        src = row["probe_source"]
        fc = family_counts.setdefault(src, {"raw": 0, "outside_provider": 0,
                                             "classifier_rejected": 0, "admitted": 0})
        fc["raw"] += 1
        if not inside_provider_head_envelope(row):
            counts["outside_provider_head_envelope"] += 1
            fc["outside_provider"] += 1
            continue
        counts["inside_provider_head_envelope"] += 1
        ok, _ = classifier_accepts(mat, row)
        if not ok:
            counts["classifier_rejected"] += 1
            fc["classifier_rejected"] += 1
            continue
        counts["classifier_admitted"] += 1
        fc["admitted"] += 1
        admitted.append(form_reference_row(mat, row))
    counts["family_counts"] = family_counts
    return admitted, counts


def worst_active_rows(evaluated, n=10):
    rows = [r for r in evaluated if not r.get("failed") and r.get("active")]
    rows.sort(key=lambda r: r.get("candidate_error", -math.inf), reverse=True)
    return [{
        "h_u": r["h_u"], "h_l": r["h_l"], "g": r["g"],
        "probe_source": r["probe_source"], "q_ref": r["q_ref"],
        "q_candidate": r["q_candidate"], "candidate_error": r["candidate_error"],
        "classifier_features": r["classifier_features"],
    } for r in rows[:n]]


def main():
    global CURRENT_LENGTH
    if len(sys.argv) != 4:
        raise SystemExit("usage: run_lmfp09_gate_c6b_unseen_core_envelope.py EVIDENCE_JSON MATERIAL HALF_FACE_LENGTH_CM")
    out = Path(sys.argv[1])
    material_name = sys.argv[2]
    length = float(sys.argv[3])
    CURRENT_LENGTH = length
    if (material_name, length) not in ALLOWED_CLASSES:
        raise SystemExit(("unsupported_precommitted_class", material_name, length))

    fixture = {f.name: f for f in FIXTURES}[material_name]
    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C6B_UNSEEN_CORE_ENVELOPE_HOLDOUT",
        "qualification": True,
        "material": material_name,
        "half_face_length_cm": length,
        "provider": {"family": "ANCHORED_HEAD_PAIR", "base_n": PROVIDER_BASE_N,
                     "expected_actual_axis_nodes": EXPECTED_AXIS_NODES},
        "classifier": {"min_se": SE_MIN, "g_max": G_MAX,
                       "dh_max_cm": DH_MAX, "k_ratio_max": KR_MAX},
        "holdout_design": {
            "gradient_seed": GRADIENT_SEED,
            "gradient_raw_cases": GRADIENT_RAW_CASES,
            "head_pair_seed": HEAD_PAIR_SEED,
            "head_pair_raw_cases": HEAD_PAIR_RAW_CASES,
            "revealed_C6a_or_C3b_rows_reused": False,
        },
        "minimum_counts": {"admitted_cases": MIN_ADMITTED,
                           "active_admitted_cases": MIN_ACTIVE_ADMITTED},
        "thresholds_changed_from_C6a": False,
        "status": "IN_PROGRESS",
        "stage": "PROVIDER_PREPARATION",
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    c3.BASE_N = PROVIDER_BASE_N
    ep.bracket = c3.tolerant_bracket
    view, oracle_solves, _ = c3.build_provider(fixture, length)
    provider_memory = view.memory()
    evidence["provider"].update({
        "actual_axis_nodes": view.nx,
        "table_values": provider_memory["values"],
        "bytes_before_metadata": provider_memory["bytes_before_metadata"],
        "offline_oracle_solves": oracle_solves,
    })
    provider_shape_ok = view.nx == EXPECTED_AXIS_NODES
    evidence["provider"]["shape_matches_precommit"] = provider_shape_ok
    evidence["stage"] = "UNSEEN_HOLDOUT_GENERATION_AND_CLASSIFICATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    admitted, selection = select_holdout(fixture.material, length)
    evidence["selection"] = selection
    evidence["stage"] = "ADMITTED_REFERENCE_EVALUATION"
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    evaluated = c6a.evaluate_rows(view, admitted)
    metrics = c6a.summarize(evaluated)
    count_checks = {
        "admitted_cases_ge_100": len(admitted) >= MIN_ADMITTED,
        "active_admitted_cases_ge_60": metrics["active_cases"] >= MIN_ACTIVE_ADMITTED,
    }
    pass_gate = provider_shape_ok and all(count_checks.values()) and metrics["pass"]
    evidence.update({
        "metrics": metrics,
        "count_checks": count_checks,
        "worst_10_active_rows": worst_active_rows(evaluated),
        "pass": pass_gate,
        "status": "COMPLETED",
        "stage": "COMPLETE",
        "decision": ("C6B_CLASS_QUALIFIED_WITHIN_FROZEN_CORE_ENVELOPE"
                     if pass_gate else
                     "C6B_CLASS_FAILED_DO_NOT_CHANGE_PROVIDER_OR_CLASSIFIER_ON_THIS_HOLDOUT"),
        "scope_limit": "Hydraulic homogeneous-face representation only. This does not qualify transient solving, process sinks, drainage, groundwater coupling, MODFLOW coupling, response tangents or production use.",
    })
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": material_name,
        "half_face_length_cm": length,
        "provider": evidence["provider"],
        "selection": selection,
        "count_checks": count_checks,
        "metrics": {k: v for k, v in metrics.items() if k not in ("source_counts", "saturation_regime_counts")},
        "decision": evidence["decision"],
    }, indent=2, sort_keys=True))
    raise SystemExit(0 if pass_gate else 1)


CURRENT_LENGTH = None

if __name__ == "__main__":
    main()
