from __future__ import annotations

import glob
import json
import sys
from collections import Counter
from pathlib import Path

EXPECTED_CLASSES = {
    "B10:10cm", "B10:20cm", "B11:10cm", "B11:20cm", "B12:10cm", "B12:20cm",
    "B17:10cm", "B17:20cm", "B18:10cm", "B18:20cm", "O01:20cm", "O05:20cm",
    "O07:10cm", "O07:20cm", "O11:10cm", "O11:20cm", "O13:10cm", "O13:20cm",
}
EXPECTED_SHARDS = set(range(6))


def add_nested_counts(target, source):
    for group, values in source.items():
        g = target.setdefault(group, Counter())
        for key, value in values.items():
            g[key] += value


def main():
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: aggregate_lmfp09_c7d_failed_response_localization.py INPUT_GLOB OUTPUT_JSON"
        )
    pattern = sys.argv[1]
    out = Path(sys.argv[2])
    paths = sorted(glob.glob(pattern, recursive=True))
    if not paths:
        raise RuntimeError(("no_C7D_shards", pattern))

    shard_indexes = set()
    classes = []
    for path in paths:
        data = json.load(open(path))
        if data.get("gate") != "C7D_FAILED_RESPONSE_LOCALIZATION":
            continue
        shard_indexes.add(int(data["shard_index"]))
        classes.extend(data["classes"])

    class_keys = [row["class"] for row in classes]
    coverage = {
        "shards_exact_0_to_5": shard_indexes == EXPECTED_SHARDS,
        "classes_exact_18": len(class_keys) == 18 and set(class_keys) == EXPECTED_CLASSES,
        "classes_unique": len(class_keys) == len(set(class_keys)),
    }
    if not all(coverage.values()):
        raise RuntimeError(("C7D_coverage_mismatch", coverage, sorted(shard_indexes), sorted(class_keys)))

    global_rows = []
    aggregate_threshold_groups = {}
    for cls in classes:
        for row in cls["top_20_active_error_rows"]:
            global_rows.append({"class": cls["class"], **row})
        for threshold_key, groups in cls["error_group_counts"].items():
            agg = aggregate_threshold_groups.setdefault(threshold_key, {
                "rows": 0,
                "by_probe_source": Counter(),
                "by_pressure_head_sign_regime": Counter(),
                "by_straddles_h_zero": Counter(),
                "by_strong_gradient": Counter(),
                "by_near_saturation": Counter(),
            })
            agg["rows"] += groups["rows"]
            for group_name in (
                "by_probe_source", "by_pressure_head_sign_regime", "by_straddles_h_zero",
                "by_strong_gradient", "by_near_saturation"
            ):
                agg[group_name].update(groups[group_name])

    global_rows.sort(key=lambda row: row["candidate_relative_error"], reverse=True)
    threshold_clean = {}
    for threshold_key, groups in aggregate_threshold_groups.items():
        threshold_clean[threshold_key] = {
            "rows": groups["rows"],
            **{
                name: dict(sorted(groups[name].items()))
                for name in (
                    "by_probe_source", "by_pressure_head_sign_regime", "by_straddles_h_zero",
                    "by_strong_gradient", "by_near_saturation"
                )
            },
        }

    result = {
        "schema_version": 1,
        "workstream": "F-LMFP",
        "work_unit": "F-LMFP09",
        "gate": "C7D_FAILED_RESPONSE_LOCALIZATION",
        "qualification": False,
        "production_implementation": False,
        "revealed_C7a_rows_reused": True,
        "new_holdout": False,
        "coverage_checks": coverage,
        "classes": sorted(classes, key=lambda row: row["class"]),
        "aggregate_error_threshold_groups": threshold_clean,
        "global_top_60_active_error_rows": global_rows[:60],
        "decision": "C7D_DIAGNOSTIC_AGGREGATE_COMPLETE_NO_QUALIFICATION",
        "status": "COMPLETED",
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "classes": len(classes),
        "coverage_checks": coverage,
        "aggregate_error_threshold_groups": threshold_clean,
        "decision": result["decision"],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
