#!/usr/bin/env python3
from __future__ import annotations

import argparse
import itertools
import json
import pathlib
from concurrent.futures import ThreadPoolExecutor
from typing import Iterable

import numpy as np
from scipy.spatial import cKDTree

FLOOR = 0.0005420462931603476
MULTIPLIERS = (0.25, 0.5, 1.0, 2.0, 4.0)
EXPECTED_HISTORIES = tuple(f"G{i:02d}" for i in range(6))
EXPECTED_STEPS = 1024


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def load_profiles(path: pathlib.Path) -> tuple[list[tuple[str, int]], np.ndarray, dict[str, np.ndarray]]:
    nodes: dict[tuple[str, int], list[float | None]] = {}
    for line in path.open(errors="replace"):
        if not line.startswith("LAREGW1_NODE|"):
            continue
        row = fields(line.split("|", 1)[1])
        key = (row["HISTORY"], int(row["STEP"]))
        profile = nodes.setdefault(key, [None] * 16)
        profile[int(row["NODE"]) - 1] = float(row["THETA"])

    keys = sorted(nodes)
    expected = {(h, step) for h in EXPECTED_HISTORIES for step in range(1, EXPECTED_STEPS + 1)}
    if set(keys) != expected:
        raise SystemExit("RS1-GW profile structure mismatch")
    if any(any(value is None for value in nodes[key]) for key in keys):
        raise SystemExit("incomplete 16-cell profile")

    profiles = np.asarray([nodes[key] for key in keys], dtype=np.float64)
    histories = np.asarray([key[0] for key in keys])
    groups = {
        history: np.flatnonzero(histories == history).astype(np.int32)
        for history in EXPECTED_HISTORIES
    }
    return keys, profiles, groups


def interval_means(profiles: np.ndarray) -> dict[tuple[int, int], np.ndarray]:
    prefix = np.concatenate(
        [np.zeros((profiles.shape[0], 1), dtype=np.float64), np.cumsum(profiles, axis=1)],
        axis=1,
    )
    return {
        (start, end): (prefix[:, end] - prefix[:, start]) / float(end - start)
        for start in range(16)
        for end in range(start + 1, 17)
    }


def coordinates(ends: tuple[int, ...], means: dict[tuple[int, int], np.ndarray]) -> np.ndarray:
    layers = []
    start = 0
    for end in ends:
        layers.append(means[(start, end)])
        start = end
    return np.column_stack(layers)


def cross_history_pairs(groups: dict[str, np.ndarray]) -> list[tuple[str, str]]:
    return [
        (left, right)
        for i, left in enumerate(EXPECTED_HISTORIES)
        for right in EXPECTED_HISTORIES[i + 1:]
    ]


def full_indistinguishable_pairs(
    profiles: np.ndarray,
    groups: dict[str, np.ndarray],
) -> np.ndarray:
    rows: list[tuple[int, int]] = []
    trees = {history: cKDTree(profiles[index]) for history, index in groups.items()}
    for left_history, right_history in cross_history_pairs(groups):
        left_index = groups[left_history]
        right_index = groups[right_history]
        sparse = trees[left_history].sparse_distance_matrix(
            trees[right_history], FLOOR, p=np.inf, output_type="coo_matrix"
        )
        rows.extend(
            zip(
                left_index[sparse.row].tolist(),
                right_index[sparse.col].tolist(),
            )
        )
    return np.asarray(rows, dtype=np.int32)


def close_cross_history_count(
    coordinate: np.ndarray,
    groups: dict[str, np.ndarray],
    threshold: float,
) -> int:
    trees = {
        history: cKDTree(coordinate[index])
        for history, index in groups.items()
    }
    total = 0
    for left_history, right_history in cross_history_pairs(groups):
        total += int(
            trees[left_history].count_neighbors(
                trees[right_history], threshold, p=np.inf
            )
        )
    return total


def collision_count(
    ends: tuple[int, ...],
    multiplier: float,
    means: dict[tuple[int, int], np.ndarray],
    groups: dict[str, np.ndarray],
    full_indist: np.ndarray,
) -> int:
    coordinate = coordinates(ends, means)
    threshold = multiplier * FLOOR
    close_count = close_cross_history_count(coordinate, groups, threshold)

    # Layer averaging is non-expansive under L_inf. Therefore every pair whose
    # full 16-cell theta L_inf is <= FLOOR is necessarily within every candidate
    # coordinate threshold >= FLOOR and can be subtracted as one constant set.
    if multiplier >= 1.0:
        subtract = len(full_indist)
    elif len(full_indist) == 0:
        subtract = 0
    else:
        projected = np.max(
            np.abs(coordinate[full_indist[:, 0]] - coordinate[full_indist[:, 1]]),
            axis=1,
        )
        subtract = int(np.count_nonzero(projected <= threshold))
    return close_count - subtract


def count_many(
    candidates: Iterable[tuple[int, ...]],
    multiplier: float,
    means: dict[tuple[int, int], np.ndarray],
    groups: dict[str, np.ndarray],
    full_indist: np.ndarray,
    workers: int,
) -> list[tuple[int, tuple[int, ...]]]:
    candidate_list = list(candidates)

    def evaluate(ends: tuple[int, ...]) -> tuple[int, tuple[int, ...]]:
        return (
            collision_count(ends, multiplier, means, groups, full_indist),
            ends,
        )

    if workers <= 1:
        return [evaluate(ends) for ends in candidate_list]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(evaluate, candidate_list))


def select_dimension(
    dimension: int,
    means: dict[tuple[int, int], np.ndarray],
    groups: dict[str, np.ndarray],
    full_indist: np.ndarray,
    workers: int,
) -> dict[str, object]:
    candidates = [
        cuts + (16,)
        for cuts in itertools.combinations(range(1, 16), dimension - 1)
    ]
    widest = count_many(candidates, 4.0, means, groups, full_indist, workers)
    minimum_4x = min(count for count, _ in widest)
    survivors = sorted(ends for count, ends in widest if count == minimum_4x)
    tie_count_4x = len(survivors)

    selection_path = {"4.0": minimum_4x}
    for multiplier in (2.0, 1.0, 0.5, 0.25):
        scored = count_many(survivors, multiplier, means, groups, full_indist, workers)
        best = min(count for count, _ in scored)
        survivors = sorted(ends for count, ends in scored if count == best)
        selection_path[str(multiplier)] = best
        if best == 0:
            break

    chosen = min(survivors)
    all_counts = {
        str(multiplier): collision_count(
            chosen, multiplier, means, groups, full_indist
        )
        for multiplier in MULTIPLIERS
    }
    return {
        "dimension": dimension,
        "candidate_count": len(candidates),
        "minimum_collision_count_at_4x": minimum_4x,
        "minimum_tie_count_at_4x": tie_count_4x,
        "selected_end_indices": list(chosen),
        "selected_depth_boundaries_cm": [0] + [10 * value for value in chosen],
        "selected_collision_counts": all_counts,
        "selection_path": selection_path,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=pathlib.Path)
    parser.add_argument("--prereg", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--workers", type=int, default=2)
    args = parser.parse_args()

    prereg = json.loads(args.prereg.read_text())
    if prereg["phase"] != "PREREGISTERED_BEFORE_REDUCED_PARTITION_SCREEN":
        raise SystemExit("wrong P1 preregistration phase")
    if float(prereg["diagnostic_state_scale"]["theta_floor"]) != FLOOR:
        raise SystemExit("diagnostic floor drift")
    if prereg["diagnostic_state_scale"]["proximity_multipliers"] != list(MULTIPLIERS):
        raise SystemExit("proximity multiplier drift")

    keys, profiles, groups = load_profiles(args.input)
    means = interval_means(profiles)
    full_indist = full_indistinguishable_pairs(profiles, groups)

    cross_history_total = 15 * EXPECTED_STEPS * EXPECTED_STEPS
    full_relevant_count = cross_history_total - len(full_indist)

    full_trees = {
        history: cKDTree(profiles[index])
        for history, index in groups.items()
    }
    full_close_counts = {}
    for multiplier in (1.0, 2.0, 4.0):
        threshold = multiplier * FLOOR
        count = 0
        for left_history, right_history in cross_history_pairs(groups):
            count += int(
                full_trees[left_history].count_neighbors(
                    full_trees[right_history], threshold, p=np.inf
                )
            )
        full_close_counts[str(multiplier)] = count
    full_state_relevant_near_pair_lower_bound = {
        str(multiplier): full_close_counts[str(multiplier)] - len(full_indist)
        for multiplier in (1.0, 2.0, 4.0)
    }

    selected = {
        f"D{dimension}": select_dimension(
            dimension, means, groups, full_indist, max(1, args.workers)
        )
        for dimension in range(2, 11)
    }

    for row in selected.values():
        row["excess_reduction_collisions_over_full_state_lower_bound"] = {
            str(multiplier): (
                row["selected_collision_counts"][str(multiplier)]
                - full_state_relevant_near_pair_lower_bound[str(multiplier)]
            )
            for multiplier in (1.0, 2.0, 4.0)
        }

    controls = {}
    for control in prereg["fixed_controls"]:
        ends = tuple(int(value) for value in control["end_indices"])
        counts = {
            str(multiplier): collision_count(
                ends, multiplier, means, groups, full_indist
            )
            for multiplier in MULTIPLIERS
        }
        controls[control["id"]] = {
            "end_indices": list(ends),
            "depth_boundaries_cm": [0] + [10 * value for value in ends],
            "collision_counts": counts,
            "excess_reduction_collisions_over_full_state_lower_bound": {
                str(multiplier): (
                    counts[str(multiplier)]
                    - full_state_relevant_near_pair_lower_bound[str(multiplier)]
                )
                for multiplier in (1.0, 2.0, 4.0)
            },
        }

    # Independent exact checks against already established 1x results. These
    # checks are not used to choose a representation.
    checks = {
        "D2_0_150_150_160_at_1x": collision_count(
            (15, 16), 1.0, means, groups, full_indist
        ),
        "D3_0_140_140_150_150_160_at_1x": collision_count(
            (14, 15, 16), 1.0, means, groups, full_indist
        ),
        "U4_at_1x": collision_count(
            (4, 8, 12, 16), 1.0, means, groups, full_indist
        ),
        "pilot_R4_at_1x": collision_count(
            (1, 14, 15, 16), 1.0, means, groups, full_indist
        ),
    }
    expected_checks = {
        "D2_0_150_150_160_at_1x": 7988,
        "D3_0_140_140_150_150_160_at_1x": 0,
        "U4_at_1x": 122587,
        "pilot_R4_at_1x": 0,
    }
    if checks != expected_checks:
        raise SystemExit(f"independent exact-check drift: {checks}")

    result = {
        "schema": "swap5.lare.rs1.gw.p1.kdtree-crosscheck.v1",
        "role": "INDEPENDENT_EXACT_IMPLEMENTATION_CROSSCHECK",
        "scientific_selection_authority": "LARE_RS1_GW_P1_PREREGISTRATION.json",
        "future_probe_response_used": False,
        "input": {
            "state_count": len(keys),
            "cross_history_pair_count": cross_history_total,
            "full_state_indistinguishable_pair_count_at_floor": len(full_indist),
            "full_state_diagnostic_pair_count": full_relevant_count,
            "diagnostic_theta_floor": FLOOR,
            "full_state_close_pair_count": full_close_counts,
            "full_state_relevant_near_pair_lower_bound": full_state_relevant_near_pair_lower_bound,
        },
        "selected_partitions": selected,
        "fixed_controls": controls,
        "independent_known_count_checks": checks,
        "method": (
            "Exact cKDTree L_inf cross-history neighbor counts. For thresholds "
            "at or above the full-state floor, full-state-indistinguishable pairs "
            "form a constant subset because fixed-layer averaging is non-expansive "
            "under L_inf. Below the floor, that subset is evaluated explicitly. "
            "The reported excess-reduction collision count subtracts the unavoidable "
            "full-state near-pair lower bound at the same diagnostic radius."
        ),
        "hydrological_acceptance_adjudicated": False,
        "lare_dynamics_executed": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "input": result["input"],
        "selected_partitions": selected,
        "fixed_controls": controls,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())