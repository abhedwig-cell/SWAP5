from __future__ import annotations

import json
import math
import random
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c3_anchored_endpoint_axis as c3
import run_lmfp09_gate_c6a_admissible_envelope_classifier as c6a
import run_lmfp09_homogeneous_face_matrix as core
from lmfp09_staring2018_catalog import CATALOG, b110_material
from run_lmfp09_coordinate_envelope import MaterialFixture

# Frozen by F-LMFP09_GATE_C7A_PRODUCTION_CATALOG_COVERAGE_DESIGN.json.
SHARD_COUNT = 12
MATERIALS_PER_SHARD = 3
LENGTHS_CM = (10.0, 20.0)
PROVIDER_BASE_N = 33
EXPECTED_AXIS_NODES = 49
EXPECTED_TABLE_VALUES = 2401
EXPECTED_BYTES = 19208
SE_MIN = 1.0e-6
G_MAX = 10000.0
DH_MAX = 100000.0
KR_MAX = 1000000.0
GRADIENT_SEED = 17161301231784269399
HEAD_PAIR_SEED = 12392949708496324958
GRADIENT_RAW_CASES = 240
HEAD_PAIR_RAW_CASES = 360
MIN_ADMITTED = 100
MIN_ACTIVE_ADMITTED = 60


def finite_json(value):
    if isinstance(value, dict):
        return {k: finite_json(v) for k, v in value.items()}
    if isinstance(value, list):
        return [finite_json(v) for v in value]
    if isinstance(value, tuple):
        return [finite_json(v) for v in value]
    if isinstance(value, float) and not math.isfinite(value):
        return None
    return value


def shard_rows(shard_index: int):
    if not 0 <= shard_index < SHARD_COUNT:
        raise ValueError(("invalid_shard", shard_index, SHARD_COUNT))
    start = shard_index * MATERIALS_PER_SHARD
    stop = start + MATERIALS_PER_SHARD
    rows = CATALOG[start:stop]
    if len(rows) != MATERIALS_PER_SHARD:
        raise RuntimeError(("catalog_shard_size_mismatch", shard_index, len(rows)))
    return rows


def raw_gradient_family(length: float):
    rng = random.Random(GRADIENT_SEED)
    coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.R_HMIN, hmax=core.R_HMAX)
    rows = []
    for _ in range(GRADIENT_RAW_CASES):
        h_u = coord.h(rng.uniform(coord.xmin, coord.xmax))
        if rng.random() < 0.5:
            g = rng.uniform(-6.0, 8.0)
        else:
            g = rng.uniform(-24.0, 24.0)
        h_l = h_u + g * length
        rows.append({
            "h_u": h_u,
            "h_l": h_l,
            "g": g,
            "probe_source": "C7A_UNSEEN_GRADIENT_FAMILY",
        })
    return rows


def raw_head_pair_family(length: float):
    rng = random.Random(HEAD_PAIR_SEED)
    coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.R_HMIN, hmax=core.R_HMAX)
    rows = []
    for _ in range(HEAD_PAIR_RAW_CASES):
        h_u = coord.h(rng.uniform(coord.xmin, coord.xmax))
        h_l = coord.h(rng.uniform(coord.xmin, coord.xmax))
        rows.append({
            "h_u": h_u,
            "h_l": h_l,
            "g": (h_l - h_u) / length,
            "probe_source": "C7A_UNSEEN_HEAD_PAIR_FAMILY",
        })
    return rows


def inside_provider_head_envelope(row):
    return (
        core.R_HMIN <= row["h_u"] <= core.R_HMAX
        and core.R_HMIN <= row["h_l"] <= core.R_HMAX
    )


def classifier_reasons(features):
    reasons = []
    if features["min_se"] < SE_MIN:
        reasons.append("min_se")
    if features["abs_g"] > G_MAX:
        reasons.append("abs_g")
    if features["abs_dh"] > DH_MAX:
        reasons.append("abs_dh")
    if features["k_ratio"] > KR_MAX:
        reasons.append("k_ratio")
    return reasons


def select_rows(mat, length):
    raw = raw_gradient_family(length) + raw_head_pair_family(length)
    admitted = []
    counts = {
        "raw_total": len(raw),
        "raw_gradient_family": GRADIENT_RAW_CASES,
        "raw_head_pair_family": HEAD_PAIR_RAW_CASES,
        "outside_provider_head_envelope": 0,
        "inside_provider_head_envelope": 0,
        "classifier_rejected": 0,
        "classifier_admitted": 0,
    }
    reason_counts = Counter()
    combination_counts = Counter()
    source_counts = {}
    for row in raw:
        src = row["probe_source"]
        sc = source_counts.setdefault(
            src,
            {"raw": 0, "outside_provider": 0, "classifier_rejected": 0, "admitted": 0},
        )
        sc["raw"] += 1
        if not inside_provider_head_envelope(row):
            counts["outside_provider_head_envelope"] += 1
            sc["outside_provider"] += 1
            continue
        counts["inside_provider_head_envelope"] += 1
        feat = c6a.features(mat, row)
        reasons = classifier_reasons(feat)
        if reasons:
            counts["classifier_rejected"] += 1
            sc["classifier_rejected"] += 1
            for reason in reasons:
                reason_counts[reason] += 1
            combination_counts["+".join(sorted(reasons))] += 1
            continue
        counts["classifier_admitted"] += 1
        sc["admitted"] += 1
        admitted.append({**row, "classifier_features": feat})
    counts["source_counts"] = source_counts
    counts["classifier_rejection_reason_counts_nonexclusive"] = dict(sorted(reason_counts.items()))
    counts["classifier_rejection_combinations"] = dict(sorted(combination_counts.items()))
    return admitted, counts


def reference_and_candidate_rows(view, mat, length, admitted):
    evaluated = []
    reference_failures = 0
    active_floor = 1.0e-8 * max(mat.conductivity(0.0), 1.0)
    oracle_before_runtime = view.oracle_solves
    for row in admitted:
        base = {
            **row,
            "active_floor": active_floor,
            "strong_gradient": abs(row["g"]) >= 5.0,
            "near_saturation": max(abs(row["h_u"]), abs(row["h_l"])) <= 10.0,
        }
        try:
            q_ref = core.direct_flux(mat, row["h_u"], row["h_l"], length)
        except Exception as exc:
            reference_failures += 1
            evaluated.append({
                **base,
                "failed": True,
                "error": "reference_oracle:" + type(exc).__name__ + ":" + str(exc),
            })
            continue
        evaluated.extend(c6a.evaluate_rows(view, [{**base, "q_ref": q_ref}]))
    oracle_after_runtime = view.oracle_solves
    return evaluated, reference_failures, oracle_before_runtime, oracle_after_runtime


def evaluate_class(row, length):
    fixture = MaterialFixture(row.sfu, b110_material(row))
    mat = fixture.material
    class_key = f"{row.sfu}:{length:g}cm"
    result = {
        "class": class_key,
        "material": row.sfu,
        "length_cm": length,
        "source_parameters": {
            "ORES": row.ores,
            "OSAT": row.osat,
            "ALFA": row.alfa,
            "NPAR": row.npar,
            "KSATFIT": row.ksatfit,
            "KSATEXM": row.ksatexm,
            "LEXP": row.lexp,
            "H_ENPR": row.h_enpr,
        },
        "pass": False,
        "stage": "PROVIDER_BUILD",
    }
    try:
        c3.BASE_N = PROVIDER_BASE_N
        ep.bracket = c3.tolerant_bracket
        view, offline_oracle_solves, _ = c3.build_provider(fixture, length)
    except Exception as exc:
        result["failure"] = "provider_build:" + type(exc).__name__ + ":" + str(exc)
        return result

    memory = view.memory()
    structural = {
        "provider_build_succeeds": True,
        "actual_axis_nodes_eq_49": view.nx == EXPECTED_AXIS_NODES,
        "table_values_eq_2401": memory["values"] == EXPECTED_TABLE_VALUES,
        "bytes_before_metadata_eq_19208": memory["bytes_before_metadata"] == EXPECTED_BYTES,
    }
    result["provider"] = {
        "family": "ANCHORED_HEAD_PAIR",
        "base_n": PROVIDER_BASE_N,
        "actual_axis_nodes": view.nx,
        "table_values": memory["values"],
        "bytes_before_metadata": memory["bytes_before_metadata"],
        "offline_oracle_solves": offline_oracle_solves,
    }
    result["stage"] = "FROZEN_CLASSIFICATION"
    admitted, selection = select_rows(mat, length)
    result["selection"] = selection

    result["stage"] = "REFERENCE_AND_CANDIDATE_EVALUATION"
    evaluated, reference_failures, oracle_before, oracle_after = reference_and_candidate_rows(
        view, mat, length, admitted
    )
    metrics = c6a.summarize(evaluated)
    runtime_oracle_unchanged = oracle_after == oracle_before
    structural.update({
        "candidate_runtime_oracle_calls_eq_0": runtime_oracle_unchanged,
        "all_admitted_candidate_fluxes_finite": metrics["failures"] == reference_failures,
    })
    count_checks = {
        "admitted_cases_ge_100": len(admitted) >= MIN_ADMITTED,
        "active_admitted_cases_ge_60": metrics["active_cases"] >= MIN_ACTIVE_ADMITTED,
    }
    class_pass = all(structural.values()) and all(count_checks.values()) and metrics["pass"]
    result.update({
        "reference_oracle_failures": reference_failures,
        "provider_runtime_oracle_counter_before": oracle_before,
        "provider_runtime_oracle_counter_after": oracle_after,
        "structural_checks": structural,
        "evidence_sufficiency_checks": count_checks,
        "metrics": metrics,
        "pass": class_pass,
        "stage": "COMPLETE",
        "decision": (
            "C7A_CATALOG_CLASS_QUALIFIED"
            if class_pass
            else "C7A_CATALOG_CLASS_NOT_QUALIFIED_NO_RETUNING_ON_THIS_HOLDOUT"
        ),
    })
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_lmfp09_gate_c7a_catalog_shard.py EVIDENCE_JSON SHARD_INDEX")
    out = Path(sys.argv[1])
    shard_index = int(sys.argv[2])
    materials = shard_rows(shard_index)
    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C7A_PRODUCTION_CATALOG_COVERAGE",
        "qualification": True,
        "production_implementation": False,
        "shard_index": shard_index,
        "shard_count": SHARD_COUNT,
        "materials": [row.sfu for row in materials],
        "lengths_cm": list(LENGTHS_CM),
        "provider": {
            "family": "ANCHORED_HEAD_PAIR",
            "base_n": PROVIDER_BASE_N,
            "expected_actual_axis_nodes": EXPECTED_AXIS_NODES,
        },
        "classifier": {
            "min_se": SE_MIN,
            "g_max": G_MAX,
            "dh_max_cm": DH_MAX,
            "k_ratio_max": KR_MAX,
        },
        "holdout": {
            "gradient_seed": GRADIENT_SEED,
            "gradient_raw_cases_per_class": GRADIENT_RAW_CASES,
            "head_pair_seed": HEAD_PAIR_SEED,
            "head_pair_raw_cases_per_class": HEAD_PAIR_RAW_CASES,
            "C6a_or_C6b_rows_reused": False,
        },
        "thresholds_changed_from_C6a_or_C6b": False,
        "status": "IN_PROGRESS",
        "classes": [],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(finite_json(evidence), indent=2, sort_keys=True, allow_nan=False) + "\n")

    for material in materials:
        for length in LENGTHS_CM:
            evidence["classes"].append(evaluate_class(material, length))
            out.write_text(json.dumps(finite_json(evidence), indent=2, sort_keys=True, allow_nan=False) + "\n")

    evidence["classes_passed"] = sum(bool(row.get("pass")) for row in evidence["classes"])
    evidence["classes_total"] = len(evidence["classes"])
    evidence["pass"] = evidence["classes_passed"] == evidence["classes_total"]
    evidence["status"] = "COMPLETED"
    evidence["decision"] = (
        "C7A_SHARD_ALL_CLASSES_QUALIFIED"
        if evidence["pass"]
        else "C7A_SHARD_HAS_UNQUALIFIED_CLASSES_AGGREGATE_WITHOUT_RETUNING"
    )
    clean = finite_json(evidence)
    out.write_text(json.dumps(clean, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "shard_index": shard_index,
        "materials": evidence["materials"],
        "classes_passed": evidence["classes_passed"],
        "classes_total": evidence["classes_total"],
        "decision": evidence["decision"],
        "failed_classes": [row["class"] for row in evidence["classes"] if not row.get("pass")],
    }, indent=2, sort_keys=True))
    # Scientific class failures are aggregated by the C7a finalizer. Technical failures
    # that prevent this file from being produced still fail the shard job naturally.


if __name__ == "__main__":
    main()
