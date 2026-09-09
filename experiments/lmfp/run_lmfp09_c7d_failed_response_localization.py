from __future__ import annotations

import json
import math
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_gate_c_endpoint_pair as ep
import run_lmfp09_gate_c3_anchored_endpoint_axis as c3
import run_lmfp09_gate_c5a_mixed_state_tail as c5a
import run_lmfp09_gate_c7a_catalog_shard as c7a
from lmfp09_staring2018_catalog import CATALOG, b110_material
from run_lmfp09_coordinate_envelope import MaterialFixture

# Post-C7a diagnosis only. These classes and the exact revealed C7a samples are frozen
# by F-LMFP09_C7D_FAILED_RESPONSE_LOCALIZATION_DESIGN.json.
FAILED_CLASSES = (
    ("B10", 10.0), ("B10", 20.0), ("B11", 10.0), ("B11", 20.0),
    ("B12", 10.0), ("B12", 20.0), ("B17", 10.0), ("B17", 20.0),
    ("B18", 10.0), ("B18", 20.0), ("O01", 20.0), ("O05", 20.0),
    ("O07", 10.0), ("O07", 20.0), ("O11", 10.0), ("O11", 20.0),
    ("O13", 10.0), ("O13", 20.0),
)
SHARD_COUNT = 6
CLASSES_PER_SHARD = 3
TOP_N = 20
ERROR_THRESHOLDS = (0.02, 0.10, 0.30)
RELSAT_JUMP = 0.999999


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


def catalog_row(material: str):
    matches = [row for row in CATALOG if row.sfu == material]
    if len(matches) != 1:
        raise RuntimeError(("catalog_material_not_unique", material, len(matches)))
    return matches[0]


def shard_classes(index: int):
    if not 0 <= index < SHARD_COUNT:
        raise ValueError(("invalid_shard", index, SHARD_COUNT))
    start = index * CLASSES_PER_SHARD
    return FAILED_CLASSES[start:start + CLASSES_PER_SHARD]


def sign_regime(h_u: float, h_l: float):
    def sign(h):
        if h < 0.0:
            return "N"
        if h > 0.0:
            return "P"
        return "Z"
    return sign(h_u) + sign(h_l)


def straddles_zero(h_u: float, h_l: float):
    return (h_u < 0.0 <= h_l) or (h_l < 0.0 <= h_u)


def compact_row(mat, row):
    h_u = row["h_u"]
    h_l = row["h_l"]
    se_u = c5a.effective_saturation(mat, h_u)
    se_l = c5a.effective_saturation(mat, h_l)
    return {
        "h_upper_cm": h_u,
        "h_lower_cm": h_l,
        "gradient": row["g"],
        "probe_source": row["probe_source"],
        "q_reference": row["q_ref"],
        "q_candidate": row["q_candidate"],
        "q_plain_mfp": row["q_mfp"],
        "candidate_relative_error": row["candidate_error"],
        "plain_mfp_relative_error": row["mfp_error"],
        "effective_saturation_upper": se_u,
        "effective_saturation_lower": se_l,
        "conductivity_ratio": row["classifier_features"]["k_ratio"],
        "strong_gradient": bool(row["strong_gradient"]),
        "near_saturation": bool(row["near_saturation"]),
        "pressure_head_sign_regime": sign_regime(h_u, h_l),
        "straddles_h_zero": straddles_zero(h_u, h_l),
        "min_abs_endpoint_head_cm": min(abs(h_u), abs(h_l)),
        "min_endpoint_relsat_distance_to_0p999999": min(
            abs(se_u - RELSAT_JUMP), abs(se_l - RELSAT_JUMP)
        ),
    }


def group_counts(rows):
    result = {}
    for threshold in ERROR_THRESHOLDS:
        subset = [row for row in rows if row["candidate_error"] >= threshold]
        key = f"ge_{threshold:g}"
        result[key] = {
            "rows": len(subset),
            "by_probe_source": dict(sorted(Counter(row["probe_source"] for row in subset).items())),
            "by_pressure_head_sign_regime": dict(sorted(Counter(
                sign_regime(row["h_u"], row["h_l"]) for row in subset
            ).items())),
            "by_straddles_h_zero": {
                str(k).lower(): v for k, v in sorted(Counter(
                    straddles_zero(row["h_u"], row["h_l"]) for row in subset
                ).items(), key=lambda x: str(x[0]))
            },
            "by_strong_gradient": {
                str(k).lower(): v for k, v in sorted(Counter(
                    bool(row["strong_gradient"]) for row in subset
                ).items(), key=lambda x: str(x[0]))
            },
            "by_near_saturation": {
                str(k).lower(): v for k, v in sorted(Counter(
                    bool(row["near_saturation"]) for row in subset
                ).items(), key=lambda x: str(x[0]))
            },
        }
    return result


def evaluate_failed_class(material: str, length: float):
    source = catalog_row(material)
    fixture = MaterialFixture(material, b110_material(source))
    mat = fixture.material

    c3.BASE_N = c7a.PROVIDER_BASE_N
    ep.bracket = c3.tolerant_bracket
    view, offline_oracle_solves, _ = c3.build_provider(fixture, length)
    admitted, selection = c7a.select_rows(mat, length)
    evaluated, reference_failures, oracle_before, oracle_after = c7a.reference_and_candidate_rows(
        view, mat, length, admitted
    )

    active = [
        row for row in evaluated
        if not row.get("failed") and row.get("active") and math.isfinite(row["candidate_error"])
    ]
    active.sort(key=lambda row: row["candidate_error"], reverse=True)
    if not active:
        raise RuntimeError(("no_active_rows", material, length))

    top = [compact_row(mat, row) for row in active[:TOP_N]]
    worst_by_source = {}
    for source_name in sorted(set(row["probe_source"] for row in active)):
        source_rows = [row for row in active if row["probe_source"] == source_name]
        source_rows.sort(key=lambda row: row["candidate_error"], reverse=True)
        worst_by_source[source_name] = compact_row(mat, source_rows[0])

    return {
        "class": f"{material}:{length:g}cm",
        "material": material,
        "length_cm": length,
        "source_parameters": {
            "ORES": source.ores,
            "OSAT": source.osat,
            "ALFA": source.alfa,
            "NPAR": source.npar,
            "KSATFIT": source.ksatfit,
            "KSATEXM": source.ksatexm,
            "LEXP": source.lexp,
            "H_ENPR": source.h_enpr,
        },
        "replay": {
            "raw_total": selection["raw_total"],
            "classifier_admitted": selection["classifier_admitted"],
            "active_rows": len(active),
            "reference_oracle_failures": reference_failures,
            "candidate_runtime_oracle_calls": oracle_after - oracle_before,
            "offline_provider_oracle_solves": offline_oracle_solves,
        },
        "error_group_counts": group_counts(active),
        "worst_by_probe_source": worst_by_source,
        "top_20_active_error_rows": top,
        "diagnostic_only": True,
        "qualification": False,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: run_lmfp09_c7d_failed_response_localization.py EVIDENCE_JSON SHARD_INDEX"
        )
    out = Path(sys.argv[1])
    shard_index = int(sys.argv[2])
    classes = shard_classes(shard_index)
    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "gate": "C7D_FAILED_RESPONSE_LOCALIZATION",
        "qualification": False,
        "production_implementation": False,
        "revealed_C7a_rows_reused": True,
        "new_holdout": False,
        "C7a_run": 34325023479,
        "C7a_decision": "NOT_QUALIFIED_FROZEN_N49_FULL_STARING2018_CATALOG_LOCALIZE_WITHOUT_RETUNING",
        "shard_index": shard_index,
        "shard_count": SHARD_COUNT,
        "classes": [],
        "status": "IN_PROGRESS",
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    for material, length in classes:
        evidence["classes"].append(evaluate_failed_class(material, length))
        out.write_text(json.dumps(finite_json(evidence), indent=2, sort_keys=True, allow_nan=False) + "\n")

    evidence["status"] = "COMPLETED"
    evidence["decision"] = "C7D_REVEALED_FAILED_RESPONSE_LOCALIZATION_COMPLETE_NO_QUALIFICATION"
    clean = finite_json(evidence)
    out.write_text(json.dumps(clean, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "shard_index": shard_index,
        "classes": [row["class"] for row in evidence["classes"]],
        "decision": evidence["decision"],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
