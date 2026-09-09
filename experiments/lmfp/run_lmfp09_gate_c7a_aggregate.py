from __future__ import annotations

import json
import math
import sys
from collections import Counter
from pathlib import Path

EXPECTED_SHARDS = 12
EXPECTED_MATERIALS = [
    *(f"B{i:02d}" for i in range(1, 19)),
    *(f"O{i:02d}" for i in range(1, 19)),
]
EXPECTED_LENGTHS = [10.0, 20.0]
EXPECTED_CLASSES = {f"{m}:{length:g}cm" for m in EXPECTED_MATERIALS for length in EXPECTED_LENGTHS}


def finite_json(value):
    if isinstance(value, dict):
        return {k: finite_json(v) for k, v in value.items()}
    if isinstance(value, list):
        return [finite_json(v) for v in value]
    if isinstance(value, float) and not math.isfinite(value):
        return None
    return value


def metric_value(row, *keys):
    value = row
    for key in keys:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: run_lmfp09_gate_c7a_aggregate.py RESULT_JSON SHARD_JSON...")
    out = Path(sys.argv[1])
    shard_paths = [Path(p) for p in sys.argv[2:]]
    shards = [json.loads(path.read_text()) for path in shard_paths]

    shard_indexes = sorted(row.get("shard_index") for row in shards)
    shard_index_ok = shard_indexes == list(range(EXPECTED_SHARDS))
    configs_ok = all(
        row.get("gate") == "C7A_PRODUCTION_CATALOG_COVERAGE"
        and row.get("shard_count") == EXPECTED_SHARDS
        and row.get("lengths_cm") == EXPECTED_LENGTHS
        and row.get("provider", {}).get("family") == "ANCHORED_HEAD_PAIR"
        and row.get("provider", {}).get("base_n") == 33
        and row.get("provider", {}).get("expected_actual_axis_nodes") == 49
        and row.get("classifier") == {
            "min_se": 1.0e-6,
            "g_max": 10000.0,
            "dh_max_cm": 100000.0,
            "k_ratio_max": 1000000.0,
        }
        and row.get("holdout", {}).get("gradient_seed") == 17161301231784269399
        and row.get("holdout", {}).get("head_pair_seed") == 12392949708496324958
        and row.get("thresholds_changed_from_C6a_or_C6b") is False
        for row in shards
    )

    classes = []
    material_occurrences = Counter()
    for shard in shards:
        for material in shard.get("materials", []):
            material_occurrences[material] += 1
        classes.extend(shard.get("classes", []))
    class_keys = [row.get("class") for row in classes]
    class_key_set = set(class_keys)
    exact_class_coverage = (
        len(classes) == len(EXPECTED_CLASSES)
        and len(class_key_set) == len(EXPECTED_CLASSES)
        and class_key_set == EXPECTED_CLASSES
    )
    exact_material_sharding = (
        set(material_occurrences) == set(EXPECTED_MATERIALS)
        and all(material_occurrences[m] == 1 for m in EXPECTED_MATERIALS)
    )

    failed = [row for row in classes if not row.get("pass")]
    qualified = shard_index_ok and configs_ok and exact_class_coverage and exact_material_sharding and not failed

    rejection_reasons = Counter()
    rejection_combinations = Counter()
    totals = Counter()
    for row in classes:
        selection = row.get("selection", {})
        for key in (
            "raw_total",
            "outside_provider_head_envelope",
            "inside_provider_head_envelope",
            "classifier_rejected",
            "classifier_admitted",
        ):
            value = selection.get(key)
            if isinstance(value, int):
                totals[key] += value
        for reason, n in selection.get("classifier_rejection_reason_counts_nonexclusive", {}).items():
            rejection_reasons[reason] += n
        for combo, n in selection.get("classifier_rejection_combinations", {}).items():
            rejection_combinations[combo] += n

    failure_checks = Counter()
    for row in failed:
        for name, passed in row.get("structural_checks", {}).items():
            if passed is False:
                failure_checks["structural:" + name] += 1
        for name, passed in row.get("evidence_sufficiency_checks", {}).items():
            if passed is False:
                failure_checks["evidence:" + name] += 1
        for name, passed in row.get("metrics", {}).get("checks", {}).items():
            if passed is False:
                failure_checks["accuracy:" + name] += 1
        if row.get("failure"):
            failure_checks["execution:" + row["failure"].split(":", 1)[0]] += 1

    active_rows = sum(
        value for value in (metric_value(row, "metrics", "active_cases") for row in classes)
        if isinstance(value, int)
    )
    dormant_rows = sum(
        value for value in (metric_value(row, "metrics", "dormant_cases") for row in classes)
        if isinstance(value, int)
    )
    oracle_failures = sum(
        value for value in (row.get("reference_oracle_failures") for row in classes)
        if isinstance(value, int)
    )
    sign_mismatches = sum(
        value for value in (metric_value(row, "metrics", "sign_mismatches") for row in classes)
        if isinstance(value, int)
    )

    def worst(metric_path, n=12):
        rows = []
        for row in classes:
            value = metric_value(row, *metric_path)
            if isinstance(value, (int, float)) and math.isfinite(float(value)):
                rows.append({"class": row.get("class"), "value": value})
        rows.sort(key=lambda x: x["value"], reverse=True)
        return rows[:n]

    result = {
        "schema_version": 1,
        "workstream": "F-LMFP",
        "work_unit": "F-LMFP09",
        "gate": "C7A_PRODUCTION_CATALOG_COVERAGE",
        "qualification": qualified,
        "production_implementation": False,
        "precommit": "integration/f-lmfp/F-LMFP09_GATE_C7A_PRODUCTION_CATALOG_COVERAGE_DESIGN.json",
        "provider": {
            "family": "ANCHORED_HEAD_PAIR",
            "base_n": 33,
            "actual_axis_nodes": 49,
            "classifier": "se=1e-06|g=10000|dh=100000|kr=1e+06",
            "thresholds_changed_from_C6a_or_C6b": False,
        },
        "coverage_checks": {
            "shard_indexes_exact_0_to_11": shard_index_ok,
            "shard_configs_match_precommit": configs_ok,
            "all_36_materials_exactly_once_across_shards": exact_material_sharding,
            "all_72_material_geometry_classes_exactly_once": exact_class_coverage,
        },
        "catalog": {
            "materials_expected": 36,
            "face_lengths_cm": EXPECTED_LENGTHS,
            "classes_expected": 72,
            "classes_observed": len(classes),
            "classes_qualified": len(classes) - len(failed),
            "classes_not_qualified": len(failed),
        },
        "holdout_totals": dict(totals),
        "classifier_rejection_reason_counts_nonexclusive": dict(sorted(rejection_reasons.items())),
        "classifier_rejection_combinations": dict(sorted(rejection_combinations.items())),
        "evaluated_rows": {
            "active": active_rows,
            "dormant": dormant_rows,
            "reference_oracle_failures": oracle_failures,
            "active_sign_mismatches": sign_mismatches,
        },
        "failure_check_counts": dict(sorted(failure_checks.items())),
        "failed_classes": [
            {
                "class": row.get("class"),
                "material": row.get("material"),
                "length_cm": row.get("length_cm"),
                "failure": row.get("failure"),
                "structural_checks": row.get("structural_checks"),
                "evidence_sufficiency_checks": row.get("evidence_sufficiency_checks"),
                "accuracy_checks": row.get("metrics", {}).get("checks"),
                "selection": row.get("selection"),
                "metrics": row.get("metrics"),
            }
            for row in failed
        ],
        "worst_active_p90_rel_error": worst(("metrics", "corrected_active_rel_error", "p90")),
        "worst_active_p99_rel_error": worst(("metrics", "corrected_active_rel_error", "p99")),
        "worst_active_max_rel_error": worst(("metrics", "corrected_active_rel_error", "maximum")),
        "worst_strong_gradient_p90_rel_error": worst(("metrics", "strong_gradient_corrected_p90_rel_error")),
        "worst_near_saturation_p90_rel_error": worst(("metrics", "near_saturation_corrected_p90_rel_error")),
        "decision": (
            "QUALIFIED_FROZEN_N49_FULL_STARING2018_HOMOGENEOUS_CATALOG_READY_FOR_SEPARATE_TRANSIENT_PRECOMMIT"
            if qualified
            else "NOT_QUALIFIED_FROZEN_N49_FULL_STARING2018_CATALOG_LOCALIZE_WITHOUT_RETUNING"
        ),
        "next_gate": (
            "C7B_TRANSIENT_ENVELOPE_QUALIFICATION_PRECOMMIT_REQUIRED"
            if qualified
            else "NO_C7B_UNTIL_C7A_FAILURES_HAVE_A_NEW_PRECOMMITTED_HYPOTHESIS"
        ),
        "scope_limit": "Homogeneous hydraulic face provider only. No heterogeneous interface, transient solver, process sink, drainage, groundwater, MODFLOW, response tangent or production solver admission.",
        "VZAA_D0A_used": False,
    }
    clean = finite_json(result)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(clean, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "decision": result["decision"],
        "catalog": result["catalog"],
        "coverage_checks": result["coverage_checks"],
        "failure_check_counts": result["failure_check_counts"],
        "failed_classes": [row["class"] for row in failed],
    }, indent=2, sort_keys=True))
    raise SystemExit(0 if qualified else 1)


if __name__ == "__main__":
    main()
