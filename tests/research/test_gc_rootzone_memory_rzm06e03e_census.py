from __future__ import annotations

import argparse
import itertools
from collections import Counter
from pathlib import Path
import json

from test_gc_rootzone_memory_rzm06e03d_census import (
    bits_key,
    parse_candidate_nodes,
    parse_d04,
    parse_e01,
    parse_e03,
)

W_TOL_CM = 1e-4
ROOT30_TOL_CM = 1e-4
H16_MIN_CM = 1e-2


def state_summary(s: dict, include_vectors: bool = False) -> dict:
    out = {
        "provenance": s["provenance"],
        "profile_water_cm": s["profile_water_cm"],
        "root30_water_cm": s["root30_water_cm"],
        "bottom_node_pressure_head_cm": s["pressure_head_cm"][15],
        "bottom_node_water_content": s["water_content"][15],
        "root_distribution_centroid_cm": s["root_distribution_centroid_cm"],
    }
    if include_vectors:
        out["pressure_head_cm"] = s["pressure_head_cm"]
        out["water_content"] = s["water_content"]
    return out


def pair_metrics(a: dict, b: dict) -> dict:
    return {
        "abs_delta_profile_water_cm": abs(b["profile_water_cm"] - a["profile_water_cm"]),
        "abs_delta_root30_water_cm": abs(b["root30_water_cm"] - a["root30_water_cm"]),
        "abs_delta_bottom_node_pressure_head_cm": abs(
            b["pressure_head_cm"][15] - a["pressure_head_cm"][15]
        ),
        "abs_delta_bottom_node_water_content": abs(
            b["water_content"][15] - a["water_content"][15]
        ),
        "abs_delta_root_distribution_centroid_cm": abs(
            b["root_distribution_centroid_cm"] - a["root_distribution_centroid_cm"]
        ),
    }


def pair_summary(rec: dict | None) -> dict | None:
    if rec is None:
        return None
    return {
        "A": state_summary(rec["A"]),
        "B": state_summary(rec["B"]),
        **{k: v for k, v in rec.items() if k.startswith("abs_delta_")},
        "fraction_of_H16_requirement": rec[
            "abs_delta_bottom_node_pressure_head_cm"
        ]
        / H16_MIN_CM,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--d04", required=True)
    ap.add_argument("--e01", required=True)
    ap.add_argument("--e03", required=True)
    ap.add_argument("--e03b", required=True)
    ap.add_argument("--e03c", required=True)
    args = ap.parse_args()

    states = []
    states.extend(parse_d04(Path(args.d04)))
    states.extend(parse_e01(Path(args.e01)))
    states.extend(parse_e03(Path(args.e03)))
    states.extend(parse_candidate_nodes(Path(args.e03b), "RZM06E03B", "E03B"))
    states.extend(parse_candidate_nodes(Path(args.e03c), "RZM06E03C", "E03C"))
    assert states

    raw_by_source = Counter(s["provenance"][0] for s in states)
    dedup: dict[bytes, dict] = {}
    for s in sorted(states, key=lambda x: tuple(x["provenance"])):
        dedup.setdefault(bits_key(s), s)
    unique = sorted(dedup.values(), key=lambda x: tuple(x["provenance"]))
    unique_by_source = Counter(s["provenance"][0] for s in unique)

    storage_matched = []
    qualifying = []
    max_h16_any = None

    for a, b in itertools.combinations(unique, 2):
        m = pair_metrics(a, b)
        rec = {"A": a, "B": b, **m}
        if (
            max_h16_any is None
            or m["abs_delta_bottom_node_pressure_head_cm"]
            > max_h16_any["abs_delta_bottom_node_pressure_head_cm"]
        ):
            max_h16_any = rec
        if (
            m["abs_delta_profile_water_cm"] <= W_TOL_CM
            and m["abs_delta_root30_water_cm"] <= ROOT30_TOL_CM
        ):
            storage_matched.append(rec)
            if m["abs_delta_bottom_node_pressure_head_cm"] >= H16_MIN_CM:
                qualifying.append(rec)

    storage_matched.sort(
        key=lambda r: (
            -r["abs_delta_bottom_node_pressure_head_cm"],
            r["abs_delta_root30_water_cm"],
            r["abs_delta_profile_water_cm"],
            -r["abs_delta_bottom_node_water_content"],
            tuple(r["A"]["provenance"]),
            tuple(r["B"]["provenance"]),
        )
    )
    qualifying.sort(
        key=lambda r: (
            -r["abs_delta_bottom_node_pressure_head_cm"],
            r["abs_delta_root30_water_cm"],
            r["abs_delta_profile_water_cm"],
            -r["abs_delta_bottom_node_water_content"],
            tuple(r["A"]["provenance"]),
            tuple(r["B"]["provenance"]),
        )
    )

    selected = None
    disposition = "NO_MATCH"
    if qualifying:
        q = qualifying[0]
        selected = {
            "A": state_summary(q["A"], include_vectors=True),
            "B": state_summary(q["B"], include_vectors=True),
            **{k: v for k, v in q.items() if k.startswith("abs_delta_")},
        }
        disposition = "SELECTED_RESPONSE_BLIND_STORAGE_MATCHED_INTERFACE_STATE_PAIR"

    evidence = {
        "schema": "swap5.gc_rootzone_memory.rzm06e03e.interface_adjacent_state_census.v1",
        "preregistration_commit": "446300e92b135c8dffee833f7f5b85876bb75ca2",
        "production_changes": False,
        "firewall": {
            "response_fields_parsed": False,
            "aggregate_source_fields_parsed": False,
            "state_input": "node H/theta plus provenance only",
        },
        "library": {
            "raw_state_count": len(states),
            "unique_state_count": len(unique),
            "raw_by_source": dict(sorted(raw_by_source.items())),
            "unique_by_primary_source": dict(sorted(unique_by_source.items())),
        },
        "frozen_gate": {
            "max_abs_profile_water_difference_cm": W_TOL_CM,
            "max_abs_root30_water_difference_cm": ROOT30_TOL_CM,
            "min_abs_bottom_node_pressure_head_difference_cm": H16_MIN_CM,
        },
        "census": {
            "storage_matched_pairs": len(storage_matched),
            "qualifying_pairs": len(qualifying),
            "largest_H16_separation_storage_matched_pair": pair_summary(
                storage_matched[0] if storage_matched else None
            ),
            "largest_H16_separation_any_pair": pair_summary(max_h16_any),
        },
        "selected_pair": selected,
        "disposition": disposition,
        "nonclaims": [
            "E03E performs no fixed-Hc response probe",
            "H16 is a mechanistic state screen, not an admitted reduced state variable",
            "selection alone does not establish response causality",
        ],
    }
    print(
        "RZM06E03E_CENSUS_JSON",
        json.dumps(evidence, sort_keys=True, separators=(",", ":")),
    )
    print("GC_RZM06E03E_RESPONSE_BLIND_CENSUS=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
