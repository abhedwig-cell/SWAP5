from __future__ import annotations

import argparse
import itertools
import json
import math
import struct
from collections import Counter
from pathlib import Path

NODES = 16
DZ_CM = 10.0
Z_CM = [-5.0 - 10.0 * i for i in range(NODES)]
W_TOL_CM = 1e-4
ROOT30_TOL_CM = 1e-4
DEEP_M1_MIN_CM = 1e-2


def tokens(line: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for token in line.rstrip("\n").split("|")[1:]:
        if "=" in token:
            k, v = token.split("=", 1)
            out[k] = v
    return out


def add_node(store: dict, key: tuple, node: int, h: float, theta: float) -> None:
    assert 1 <= node <= NODES
    assert math.isfinite(h) and math.isfinite(theta)
    ns = store.setdefault(key, {})
    assert node not in ns, (key, node)
    ns[node] = (h, theta)


def parse_d04(path: Path) -> list[dict]:
    nodes: dict[tuple, dict] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("RZM06D04_NODE|"):
            continue
        f = tokens(line)
        required = {"ORIGIN", "CONTROL", "CRANK", "DIDX", "NODE", "H", "THETA"}
        assert required <= set(f), f
        key = ("D04", f["ORIGIN"], f["CONTROL"], int(f["CRANK"]), int(f["DIDX"]))
        add_node(nodes, key, int(f["NODE"]), float(f["H"]), float(f["THETA"]))
    return materialize(nodes)


def parse_e01(path: Path) -> list[dict]:
    nodes: dict[tuple, dict] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("RZM06E01_NODE|"):
            continue
        f = tokens(line)
        required = {"FAMILY", "STEP", "NODE", "H", "THETA"}
        assert required <= set(f), f
        key = ("E01", f["FAMILY"], int(f["STEP"]))
        add_node(nodes, key, int(f["NODE"]), float(f["H"]), float(f["THETA"]))
    return materialize(nodes)


def parse_e03(path: Path) -> list[dict]:
    nodes: dict[tuple, dict] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("RZM06E03_NODE|"):
            continue
        f = tokens(line)
        required = {"FAMILY", "PHASE", "STEP", "NODE", "H", "THETA"}
        assert required <= set(f), f
        key = ("E03", f["FAMILY"], f["PHASE"], int(f["STEP"]))
        add_node(nodes, key, int(f["NODE"]), float(f["H"]), float(f["THETA"]))
    return materialize(nodes)


def parse_candidate_nodes(path: Path, prefix: str, source: str) -> list[dict]:
    nodes: dict[tuple, dict] = {}
    marker = prefix + "_NODE|"
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith(marker):
            continue
        f = tokens(line)
        required = {"FAMILY", "NODE", "H", "THETA"}
        assert required <= set(f), f
        key = (source, f["FAMILY"])
        add_node(nodes, key, int(f["NODE"]), float(f["H"]), float(f["THETA"]))
    return materialize(nodes)


def materialize(nodes: dict[tuple, dict]) -> list[dict]:
    out = []
    for key, ns in nodes.items():
        assert len(ns) == NODES, (key, len(ns))
        h = [ns[i][0] for i in range(1, NODES + 1)]
        theta = [ns[i][1] for i in range(1, NODES + 1)]
        profile = math.fsum(v * DZ_CM for v in theta)
        root = math.fsum(theta[i] * DZ_CM for i in range(3))
        deep = math.fsum(theta[i] * DZ_CM for i in range(3, NODES))
        assert profile > 0.0 and root > 0.0 and deep > 0.0
        deep_m1 = math.fsum(theta[i] * DZ_CM * Z_CM[i] for i in range(3, NODES)) / deep
        root_m1 = math.fsum(theta[i] * DZ_CM * Z_CM[i] for i in range(3)) / root
        out.append(
            {
                "provenance": [str(x) for x in key],
                "pressure_head_cm": h,
                "water_content": theta,
                "profile_water_cm": profile,
                "root30_water_cm": root,
                "deep_water_cm": deep,
                "deep_distribution_centroid_cm": deep_m1,
                "root_distribution_centroid_cm": root_m1,
            }
        )
    return out


def bits_key(state: dict) -> bytes:
    vals = state["pressure_head_cm"] + state["water_content"]
    return b"".join(struct.pack(">d", float(v)) for v in vals)


def pair_metrics(a: dict, b: dict) -> dict:
    return {
        "abs_delta_profile_water_cm": abs(b["profile_water_cm"] - a["profile_water_cm"]),
        "abs_delta_root30_water_cm": abs(b["root30_water_cm"] - a["root30_water_cm"]),
        "abs_delta_deep_water_cm": abs(b["deep_water_cm"] - a["deep_water_cm"]),
        "abs_delta_deep_distribution_centroid_cm": abs(
            b["deep_distribution_centroid_cm"] - a["deep_distribution_centroid_cm"]
        ),
        "abs_delta_root_distribution_centroid_cm": abs(
            b["root_distribution_centroid_cm"] - a["root_distribution_centroid_cm"]
        ),
    }


def compact(state: dict, include_vectors: bool = False) -> dict:
    d = {
        "provenance": state["provenance"],
        "profile_water_cm": state["profile_water_cm"],
        "root30_water_cm": state["root30_water_cm"],
        "deep_water_cm": state["deep_water_cm"],
        "deep_distribution_centroid_cm": state["deep_distribution_centroid_cm"],
        "root_distribution_centroid_cm": state["root_distribution_centroid_cm"],
    }
    if include_vectors:
        d["pressure_head_cm"] = state["pressure_head_cm"]
        d["water_content"] = state["water_content"]
    return d


def summarize_pair(rec: dict | None) -> dict | None:
    if rec is None:
        return None
    return {
        "A": compact(rec["A"]),
        "B": compact(rec["B"]),
        **{k: v for k, v in rec.items() if k.startswith("abs_delta_")},
        "fraction_of_deep_M1_requirement": rec[
            "abs_delta_deep_distribution_centroid_cm"
        ]
        / DEEP_M1_MIN_CM,
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
    assert states, "empty state library"

    source_counts_raw = Counter(s["provenance"][0] for s in states)

    dedup: dict[bytes, dict] = {}
    aliases: dict[bytes, list[list[str]]] = {}
    for state in sorted(states, key=lambda s: tuple(s["provenance"])):
        key = bits_key(state)
        aliases.setdefault(key, []).append(state["provenance"])
        dedup.setdefault(key, state)

    unique = list(dedup.values())
    unique.sort(key=lambda s: tuple(s["provenance"]))
    source_counts_unique = Counter(s["provenance"][0] for s in unique)

    eligible = []
    storage_matched = []
    qualifying = []
    best_deep_any = None
    closest_root_after_profile = None

    for a, b in itertools.combinations(unique, 2):
        m = pair_metrics(a, b)
        rec = {"A": a, "B": b, **m}
        eligible.append(rec)
        if (
            best_deep_any is None
            or m["abs_delta_deep_distribution_centroid_cm"]
            > best_deep_any["abs_delta_deep_distribution_centroid_cm"]
        ):
            best_deep_any = rec
        if m["abs_delta_profile_water_cm"] <= W_TOL_CM:
            if (
                closest_root_after_profile is None
                or m["abs_delta_root30_water_cm"]
                < closest_root_after_profile["abs_delta_root30_water_cm"]
            ):
                closest_root_after_profile = rec
            if m["abs_delta_root30_water_cm"] <= ROOT30_TOL_CM:
                storage_matched.append(rec)
                if (
                    m["abs_delta_deep_distribution_centroid_cm"]
                    >= DEEP_M1_MIN_CM
                ):
                    qualifying.append(rec)

    qualifying.sort(
        key=lambda r: (
            -r["abs_delta_deep_distribution_centroid_cm"],
            r["abs_delta_root30_water_cm"],
            r["abs_delta_profile_water_cm"],
            r["abs_delta_root_distribution_centroid_cm"],
            tuple(r["A"]["provenance"]),
            tuple(r["B"]["provenance"]),
        )
    )
    storage_matched.sort(
        key=lambda r: (
            -r["abs_delta_deep_distribution_centroid_cm"],
            r["abs_delta_root30_water_cm"],
            r["abs_delta_profile_water_cm"],
        )
    )

    selected = None
    disposition = "NO_MATCH"
    if qualifying:
        q = qualifying[0]
        selected = {
            "A": compact(q["A"], include_vectors=True),
            "B": compact(q["B"], include_vectors=True),
            **{k: v for k, v in q.items() if k.startswith("abs_delta_")},
        }
        disposition = "SELECTED_RESPONSE_BLIND_ROOTMATCHED_DEEP_PROFILE_PAIR"

    evidence = {
        "schema": "swap5.gc_rootzone_memory.rzm06e03d.deep_profile_library_census.v1",
        "preregistration_commit": "011d73f42d01dda40efe898483269fdb34deb2aa",
        "production_changes": False,
        "firewall": {
            "response_fields_parsed": False,
            "aggregate_source_fields_parsed": False,
            "state_input": "node H/theta plus provenance only",
        },
        "library": {
            "raw_state_count": len(states),
            "unique_state_count": len(unique),
            "duplicate_state_count": len(states) - len(unique),
            "raw_by_source": dict(sorted(source_counts_raw.items())),
            "unique_by_primary_source": dict(sorted(source_counts_unique.items())),
            "duplicate_alias_groups": sum(1 for v in aliases.values() if len(v) > 1),
        },
        "frozen_gate": {
            "max_abs_profile_water_difference_cm": W_TOL_CM,
            "max_abs_root30_water_difference_cm": ROOT30_TOL_CM,
            "min_abs_deep_distribution_centroid_difference_cm": DEEP_M1_MIN_CM,
        },
        "census": {
            "eligible_pairs": len(eligible),
            "storage_matched_pairs": len(storage_matched),
            "qualifying_pairs": len(qualifying),
            "best_storage_matched_pair": summarize_pair(
                storage_matched[0] if storage_matched else None
            ),
            "closest_root_pair_after_profile_gate": summarize_pair(
                closest_root_after_profile
            ),
            "largest_deep_separation_any_pair": summarize_pair(best_deep_any),
        },
        "selected_pair": selected,
        "disposition": disposition,
        "nonclaims": [
            "E03D performs no fixed-Hc response probe",
            "a selected pair establishes state-space availability only",
            "the deep centroid is a bounded C01 research observable",
        ],
    }
    print(
        "RZM06E03D_CENSUS_JSON",
        json.dumps(evidence, sort_keys=True, separators=(",", ":")),
    )
    print("GC_RZM06E03D_RESPONSE_BLIND_CENSUS=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
