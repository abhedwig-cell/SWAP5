from __future__ import annotations

import json
import math
import sys
from pathlib import Path

PANEL = (
    "B10", "B11", "B12", "B17", "B18",
    "O01", "O05", "O07", "O11", "O13",
    "B01", "B05", "O02", "O16", "O18",
)
FAMILIES = ("A_ALPHA_NORMALIZED_ENDPOINTS", "B_H50_NORMALIZED_ENDPOINTS")

TAIL_CLASSES = (
    "B10:10cm", "B10:20cm",
    "B17:10cm", "B17:20cm",
    "B18:10cm", "B18:20cm",
    "O07:10cm", "O07:20cm",
    "O11:10cm", "O11:20cm",
)
GEOMETRY_CLASSES = ("O01:20cm", "O05:20cm")
CONTROL_CLASSES = (
    "B01:10cm", "B01:20cm",
    "B05:10cm", "B05:20cm",
    "O02:10cm", "O02:20cm",
    "O16:10cm", "O16:20cm",
    "O18:10cm", "O18:20cm",
)
OWNER_CLASSES = (
    "B11:10cm", "B11:20cm",
    "B12:10cm", "B12:20cm",
    "O13:10cm", "O13:20cm",
)


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


def percentile(values, p):
    values = sorted(values)
    if not values:
        return math.nan
    return values[min(len(values) - 1, int(p * len(values)))]


def ratio(a, b):
    return a / max(abs(b), 1.0e-15)


def load_classes(paths):
    materials = {}
    classes = {}
    for path in paths:
        data = json.loads(Path(path).read_text())
        if data.get("work_unit") != "F-LMFP10" or data.get("gate") != "A0_MATERIAL_SCALE_COORDINATE_SCREEN":
            raise RuntimeError(("wrong_artifact", str(path)))
        material = data.get("material")
        if material in materials:
            raise RuntimeError(("duplicate_material", material))
        materials[material] = data
        result = data.get("result", {})
        for row in result.get("classes", []):
            key = row.get("class")
            if key in classes:
                raise RuntimeError(("duplicate_class", key))
            classes[key] = row
    expected = {f"{m}:{length}cm" for m in PANEL for length in (10, 20)}
    if set(materials) != set(PANEL):
        raise RuntimeError(("panel_material_mismatch", sorted(materials), sorted(PANEL)))
    if set(classes) != expected:
        raise RuntimeError(("panel_class_mismatch", sorted(classes), sorted(expected)))
    return materials, classes


def class_metric(row, family, metric, subset="frozen_classifier_slice"):
    block = row["candidates"][family][subset]
    if metric == "max":
        return block["corrected_active_rel_error"]["maximum"]
    if metric == "p90":
        return block["corrected_active_rel_error"]["p90"]
    if metric == "strong_p90":
        return block["strong_gradient_corrected_p90_rel_error"]
    if metric == "near_p90":
        return block["near_saturation_corrected_p90_rel_error"]
    raise KeyError(metric)


def baseline_metric(row, metric, subset="frozen_classifier_slice"):
    block = row["n49_baseline"][subset]
    if metric == "max":
        return block["corrected_active_rel_error"]["maximum"]
    if metric == "p90":
        return block["corrected_active_rel_error"]["p90"]
    if metric == "strong_p90":
        return block["strong_gradient_corrected_p90_rel_error"]
    if metric == "near_p90":
        return block["near_saturation_corrected_p90_rel_error"]
    raise KeyError(metric)


def structural_summary(classes, family):
    identities = []
    fail_closed = []
    continuities = []
    runtime = []
    node_counts = []
    sign_mismatches = 0
    for row in classes.values():
        cand = row["candidates"][family]
        identities.append(bool(cand["structural"]["identity"]["pass"]))
        fail_closed.append(bool(cand["structural"]["fail_closed"]["pass"]))
        continuities.append(bool(cand["structural"]["continuity"]["pass"]))
        runtime.append(bool(cand["structural"]["runtime_oracle_calls_eq_0"]))
        node_counts.append(cand["axis_nodes"])
        sign_mismatches += cand["frozen_classifier_slice"]["sign_mismatches"]
    required = (
        all(identities)
        and all(fail_closed)
        and all(runtime)
        and set(node_counts) == {49}
        and sign_mismatches == 0
    )
    return {
        "required_for_nomination_pass": required,
        "identity_all_pass": all(identities),
        "fail_closed_all_pass": all(fail_closed),
        "continuity_all_pass_diagnostic": all(continuities),
        "runtime_oracle_calls_zero_all": all(runtime),
        "endpoint_axis_node_counts": sorted(set(node_counts)),
        "active_sign_mismatches": sign_mismatches,
    }


def candidate_scores(classes, family):
    tail_ratios = [
        ratio(class_metric(classes[key], family, "max"), baseline_metric(classes[key], "max"))
        for key in TAIL_CLASSES
    ]
    geometry_ratios = [
        ratio(class_metric(classes[key], family, "strong_p90"), baseline_metric(classes[key], "strong_p90"))
        for key in GEOMETRY_CLASSES
    ]
    control_ratios = [
        ratio(class_metric(classes[key], family, "p90"), baseline_metric(classes[key], "p90"))
        for key in CONTROL_CLASSES
    ]
    active_common = 0
    better = 0
    for key in TAIL_CLASSES:
        comp = classes[key]["candidates"][family]["versus_n49_frozen_classifier_slice"]
        active_common += comp["active_common_rows"]
        better += comp["candidate_better_rows"]
    owner = {
        key: {
            "candidate_max": class_metric(classes[key], family, "max"),
            "n49_max": baseline_metric(classes[key], "max"),
            "max_ratio": ratio(class_metric(classes[key], family, "max"), baseline_metric(classes[key], "max")),
            "candidate_p99": classes[key]["candidates"][family]["frozen_classifier_slice"]["corrected_active_rel_error"]["p99"],
            "n49_p99": classes[key]["n49_baseline"]["frozen_classifier_slice"]["corrected_active_rel_error"]["p99"],
            "candidate_near_p90": class_metric(classes[key], family, "near_p90"),
            "n49_near_p90": baseline_metric(classes[key], "near_p90"),
        }
        for key in OWNER_CLASSES
    }
    scores = {
        "tail_score": percentile(tail_ratios, 0.50),
        "geometry_score": max(geometry_ratios),
        "control_score": percentile(control_ratios, 0.50),
        "R4_tail_class_ratios": dict(zip(TAIL_CLASSES, tail_ratios)),
        "R3_geometry_class_ratios": dict(zip(GEOMETRY_CLASSES, geometry_ratios)),
        "control_class_ratios": dict(zip(CONTROL_CLASSES, control_ratios)),
        "tail_active_common_rows": active_common,
        "tail_candidate_better_rows": better,
        "tail_row_better_fraction": better / active_common if active_common else math.nan,
        "owner_overlap_diagnostic": owner,
    }
    structural = structural_summary(classes, family)
    coherent_checks = {
        "structural_required": structural["required_for_nomination_pass"],
        "tail_score_lt_1": scores["tail_score"] < 1.0,
        "geometry_score_lt_1": scores["geometry_score"] < 1.0,
        "control_score_le_1p25": scores["control_score"] <= 1.25,
        "tail_row_better_fraction_gt_0p5": scores["tail_row_better_fraction"] > 0.5,
    }
    return {
        "structural": structural,
        "scores": scores,
        "coherent_checks": coherent_checks,
        "coherent": all(coherent_checks.values()),
    }


def decide(results):
    coherent = [f for f in FAMILIES if results[f]["coherent"]]
    if len(coherent) == 0:
        return "A0_NO_COHERENT_SCALE_NORMALIZED_CANDIDATE", None
    if len(coherent) == 1:
        fam = coherent[0]
        decision = (
            "A0_NOMINATE_ALPHA_NORMALIZED_FOR_A1"
            if fam == "A_ALPHA_NORMALIZED_ENDPOINTS"
            else "A0_NOMINATE_H50_NORMALIZED_FOR_A1"
        )
        return decision, fam

    a, b = coherent
    sa = results[a]["scores"]
    sb = results[b]["scores"]

    def dominates(x, y):
        return (
            x["tail_score"] <= y["tail_score"]
            and x["geometry_score"] <= y["geometry_score"]
            and x["control_score"] <= y["control_score"]
            and (
                x["tail_score"] < y["tail_score"]
                or x["geometry_score"] < y["geometry_score"]
            )
        )

    if dominates(sa, sb):
        return "A0_NOMINATE_ALPHA_NORMALIZED_FOR_A1", a
    if dominates(sb, sa):
        return "A0_NOMINATE_H50_NORMALIZED_FOR_A1", b
    return "A0_AMBIGUOUS_TRADEOFF_PRECOMMIT_DISCRIMINATOR_REQUIRED", None


def compact_class_table(classes):
    rows = []
    for key in sorted(classes):
        row = classes[key]
        item = {
            "class": key,
            "n49": {
                "p90": baseline_metric(row, "p90"),
                "max": baseline_metric(row, "max"),
                "strong_p90": baseline_metric(row, "strong_p90"),
                "near_p90": baseline_metric(row, "near_p90"),
            },
            "candidates": {},
        }
        for family in FAMILIES:
            item["candidates"][family] = {
                "p90": class_metric(row, family, "p90"),
                "max": class_metric(row, family, "max"),
                "strong_p90": class_metric(row, family, "strong_p90"),
                "near_p90": class_metric(row, family, "near_p90"),
                "fraction_better_than_n49": row["candidates"][family]["versus_n49_frozen_classifier_slice"]["fraction_candidate_better"],
            }
        rows.append(item)
    return rows


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: run_lmfp10_a0_aggregate.py RESULT_JSON MATERIAL_JSON...")
    out = Path(sys.argv[1])
    materials, classes = load_classes(sys.argv[2:])
    results = {family: candidate_scores(classes, family) for family in FAMILIES}
    decision, nominated = decide(results)
    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP10",
        "gate": "A0_MATERIAL_SCALE_COORDINATE_SCREEN",
        "qualification": False,
        "characterization_only": True,
        "contract": "integration/f-lmfp/F-LMFP10_CONTRACT.json",
        "nomination_precommit": "integration/f-lmfp/F-LMFP10_A0_NOMINATION_PRECOMMIT.json",
        "panel_materials": list(PANEL),
        "classes": 30,
        "candidate_results": results,
        "class_table": compact_class_table(classes),
        "decision": decision,
        "nominated_candidate": nominated,
        "next_gate": (
            "A1_GEOMETRY_AXIS_CHARACTERIZATION_PRECOMMIT_REQUIRED"
            if nominated is not None
            else (
                "SEPARATE_DISCRIMINATOR_PRECOMMIT_REQUIRED"
                if decision == "A0_AMBIGUOUS_TRADEOFF_PRECOMMIT_DISCRIMINATOR_REQUIRED"
                else "NO_A1_DO_NOT_TUNE_A0_NODES_FORMULATE_MATERIALLY_DIFFERENT_HYPOTHESIS"
            )
        ),
        "fresh_holdout_used": False,
        "production_admission": False,
        "transient_admission": False,
        "status": "COMPLETED",
    }
    clean = finite_json(evidence)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(clean, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "decision": decision,
        "nominated_candidate": nominated,
        "candidate_scores": {
            family: {
                "coherent": results[family]["coherent"],
                "tail_score": results[family]["scores"]["tail_score"],
                "geometry_score": results[family]["scores"]["geometry_score"],
                "control_score": results[family]["scores"]["control_score"],
                "tail_row_better_fraction": results[family]["scores"]["tail_row_better_fraction"],
                "structural": results[family]["structural"],
            }
            for family in FAMILIES
        },
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
