#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import pathlib
from typing import Iterable

import numpy as np


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def load_profiles(path: pathlib.Path, node_prefix: str) -> tuple[list[tuple[str, int]], np.ndarray]:
    nodes: dict[tuple[str, int], dict[int, float]] = {}
    tag = f"{node_prefix}_NODE|"
    for line in path.read_text().splitlines():
        if tag not in line:
            continue
        row = fields(line.split(tag, 1)[1])
        key = (row["HISTORY"], int(row["STEP"]))
        nodes.setdefault(key, {})[int(row["NODE"])] = float(row["THETA"])

    keys = sorted(nodes)
    if not keys:
        raise SystemExit(f"no {node_prefix}_NODE rows in {path}")

    expected_nodes = set(range(1, 17))
    for key in keys:
        if set(nodes[key]) != expected_nodes:
            raise SystemExit(f"incomplete 16-node profile for {key}")

    matrix = np.asarray(
        [[nodes[key][node] for node in range(1, 17)] for key in keys],
        dtype=float,
    )
    return keys, matrix


def cross_history_pairs(
    keys: list[tuple[str, int]], profiles: np.ndarray, theta_floor: float
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    ia: list[int] = []
    ib: list[int] = []
    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            if keys[i][0] == keys[j][0]:
                continue
            ia.append(i)
            ib.append(j)

    ai = np.asarray(ia, dtype=np.int32)
    bi = np.asarray(ib, dtype=np.int32)
    full_distance = np.max(np.abs(profiles[ai] - profiles[bi]), axis=1)
    full_distinguishable = full_distance > theta_floor
    return ai, bi, full_distance, full_distinguishable


def interval_conditions(
    profiles: np.ndarray,
    ia: np.ndarray,
    ib: np.ndarray,
    theta_floor: float,
) -> dict[tuple[int, int], np.ndarray]:
    out: dict[tuple[int, int], np.ndarray] = {}
    for start in range(16):
        for end in range(start + 1, 17):
            mean = np.mean(profiles[:, start:end], axis=1)
            out[(start, end)] = np.abs(mean[ia] - mean[ib]) <= theta_floor
    return out


def partition_collision_count(
    ends: tuple[int, ...],
    relevant: np.ndarray,
    conditions: dict[tuple[int, int], np.ndarray],
) -> int:
    starts = (0,) + ends[:-1]
    collisions = relevant.copy()
    for start, end in zip(starts, ends):
        collisions &= conditions[(start, end)]
        if not np.any(collisions):
            return 0
    return int(np.sum(collisions))


def enumerate_partitions(
    profiles: np.ndarray,
    keys: list[tuple[str, int]],
    theta_floor: float,
    n_min: int,
    n_max: int,
) -> tuple[dict[str, object], set[tuple[int, ...]]]:
    ia, ib, full_distance, relevant = cross_history_pairs(keys, profiles, theta_floor)
    conditions = interval_conditions(profiles, ia, ib, theta_floor)

    by_n: dict[str, object] = {}
    all_zero: set[tuple[int, ...]] = set()
    for nlayer in range(n_min, n_max + 1):
        zero: list[tuple[int, ...]] = []
        best_count: int | None = None
        best_examples: list[tuple[int, ...]] = []
        count = 0

        for cuts in itertools.combinations(range(1, 16), nlayer - 1):
            count += 1
            ends = cuts + (16,)
            collisions = partition_collision_count(ends, relevant, conditions)
            if collisions == 0:
                zero.append(ends)
                all_zero.add(ends)
            if best_count is None or collisions < best_count:
                best_count = collisions
                best_examples = [ends]
            elif collisions == best_count and len(best_examples) < 20:
                best_examples.append(ends)

        by_n[str(nlayer)] = {
            "candidate_partition_count": count,
            "zero_collision_partition_count": len(zero),
            "zero_collision_examples": [list(p) for p in zero[:20]],
            "minimum_collision_count": best_count,
            "minimum_collision_examples": [list(p) for p in best_examples[:20]],
        }

    return (
        {
            "state_count": len(keys),
            "cross_history_pair_count": len(ia),
            "full_state_distinguishable_pair_count": int(np.sum(relevant)),
            "maximum_full_theta_linf": float(np.max(full_distance)),
            "by_layer_count": by_n,
        },
        all_zero,
    )


def selected_stats(
    profiles: np.ndarray,
    keys: list[tuple[str, int]],
    theta_floor: float,
    ends: tuple[int, ...],
) -> dict[str, float | int | list[int]]:
    ia, ib, full_distance, relevant = cross_history_pairs(keys, profiles, theta_floor)
    starts = (0,) + ends[:-1]
    components = []
    for start, end in zip(starts, ends):
        mean = np.mean(profiles[:, start:end], axis=1)
        components.append(np.abs(mean[ia] - mean[ib]))
    induced = np.max(np.vstack(components), axis=0)
    collision = relevant & (induced <= theta_floor)
    minimum = float(np.min(induced[relevant]))
    return {
        "cell_end_indices": list(ends),
        "depth_boundaries_cm": [10 * i for i in (0,) + ends],
        "collision_count": int(np.sum(collision)),
        "minimum_induced_theta_linf_over_full_distinguishable_pairs": minimum,
        "minimum_separation_margin_over_theta_floor": minimum - theta_floor,
        "maximum_hidden_full_theta_linf_among_collisions": (
            float(np.max(full_distance[collision])) if np.any(collision) else 0.0
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--b01", required=True, type=pathlib.Path)
    parser.add_argument("--b14", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--n-min", type=int, default=2)
    parser.add_argument("--n-max", type=int, default=10)
    args = parser.parse_args()

    b01_keys, b01_profiles = load_profiles(args.b01, "ROM1AR2")
    b14_keys, b14_profiles = load_profiles(args.b14, "ROM1X1")

    b01_floor = 0.0005420462931603476
    b14_floor = 0.0000016414144244913942

    b01_result, b01_zero = enumerate_partitions(
        b01_profiles, b01_keys, b01_floor, args.n_min, args.n_max
    )
    b14_result, b14_zero = enumerate_partitions(
        b14_profiles, b14_keys, b14_floor, args.n_min, args.n_max
    )

    cross: dict[str, object] = {}
    for nlayer in range(args.n_min, min(args.n_max, 6) + 1):
        candidates = sorted(
            partition
            for partition in b01_zero & b14_zero
            if len(partition) == nlayer
        )
        cross[str(nlayer)] = {
            "zero_collision_in_both_materials": len(candidates),
            "examples": [list(p) for p in candidates[:30]],
        }

    cross_minimum = None
    for nlayer in range(args.n_min, args.n_max + 1):
        matches = [p for p in b01_zero & b14_zero if len(p) == nlayer]
        if matches:
            cross_minimum = min(matches)
            break

    selected: dict[str, object] = {}
    if cross_minimum is not None:
        selected["cross_material_minimum"] = {
            "B01": selected_stats(
                b01_profiles, b01_keys, b01_floor, cross_minimum
            ),
            "B14": selected_stats(
                b14_profiles, b14_keys, b14_floor, cross_minimum
            ),
        }

    result = {
        "schema": "swap5.lare.rs1.partition-screen.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-RS1-P0",
        "role": "RETROSPECTIVE_PILOT_STATE_INFORMATION_SCREEN_ONLY",
        "inputs": {
            "B01": {
                "path": str(args.b01),
                "sha256": hashlib.sha256(args.b01.read_bytes()).hexdigest(),
                "theta_floor": b01_floor,
            },
            "B14": {
                "path": str(args.b14),
                "sha256": hashlib.sha256(args.b14.read_bytes()).hexdigest(),
                "theta_floor": b14_floor,
            },
        },
        "partition_semantics": {
            "base_cells": 16,
            "base_cell_thickness_cm": 10.0,
            "candidate": "all contiguous fixed partitions of the 16 cells",
            "component": "arithmetic mean theta over each candidate layer, equivalent to layer storage divided by thickness",
            "collision": "full theta L_inf exceeds material-specific frozen Reference floor while maximum candidate-layer mean difference does not",
        },
        "B01": b01_result,
        "B14": b14_result,
        "cross_material": cross,
        "selected": selected,
        "interpretation_limits": [
            "These libraries cover short near-equilibrium perturbations only.",
            "Zero numerical state collisions do not establish hydrological or predictive sufficiency.",
            "No LARE dynamics or closure is tested here.",
            "No production ROM is authorized."
        ],
    }

    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "cross_material": cross,
        "selected": selected,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
