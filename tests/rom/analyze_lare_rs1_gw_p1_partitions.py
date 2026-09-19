#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import pathlib
from collections import defaultdict

import numpy as np


FLOOR = 0.0005420462931603476
MULTIPLIERS = (0.25, 0.5, 1.0, 2.0, 4.0)
SCORE_ORDER = (4.0, 2.0, 1.0, 0.5, 0.25)
EXPECTED_HISTORIES = tuple(f"G{i:02d}" for i in range(6))
EXPECTED_STEPS = 1024
PAIR_CHUNK = 250_000


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def load_profiles(path: pathlib.Path) -> tuple[list[tuple[str, int]], np.ndarray]:
    nodes: dict[tuple[str, int], list[float | None]] = {}
    for line in path.open(errors="replace"):
        if not line.startswith("LAREGW1_NODE|"):
            continue
        row = fields(line.split("|", 1)[1])
        key = (row["HISTORY"], int(row["STEP"]))
        profile = nodes.setdefault(key, [None] * 16)
        profile[int(row["NODE"]) - 1] = float(row["THETA"])

    keys = sorted(nodes)
    expected = {(h, s) for h in EXPECTED_HISTORIES for s in range(1, EXPECTED_STEPS + 1)}
    if set(keys) != expected:
        raise SystemExit("RS1-GW profile structure mismatch")
    if any(any(value is None for value in nodes[key]) for key in keys):
        raise SystemExit("incomplete 16-cell profile")

    profiles = np.asarray(nodes.values() if False else [nodes[key] for key in keys], dtype=np.float64)
    if profiles.shape != (len(expected), 16) or not np.all(np.isfinite(profiles)):
        raise SystemExit("invalid profile matrix")
    return keys, profiles


def build_cross_history_pairs(keys: list[tuple[str, int]]) -> tuple[np.ndarray, np.ndarray]:
    history = np.asarray([key[0] for key in keys])
    groups = {h: np.flatnonzero(history == h).astype(np.int32) for h in EXPECTED_HISTORIES}
    left: list[np.ndarray] = []
    right: list[np.ndarray] = []
    for ia, ha in enumerate(EXPECTED_HISTORIES):
        for hb in EXPECTED_HISTORIES[ia + 1:]:
            a = groups[ha]
            b = groups[hb]
            left.append(np.repeat(a, len(b)))
            right.append(np.tile(b, len(a)))
    return np.concatenate(left), np.concatenate(right)


def full_relevant_mask(
    profiles: np.ndarray, left: np.ndarray, right: np.ndarray
) -> np.ndarray:
    relevant = np.zeros(len(left), dtype=np.bool_)
    for start in range(0, len(left), PAIR_CHUNK):
        stop = min(len(left), start + PAIR_CHUNK)
        delta = np.max(
            np.abs(profiles[left[start:stop]] - profiles[right[start:stop]]),
            axis=1,
        )
        relevant[start:stop] = delta > FLOOR
    return relevant


def interval_means(profiles: np.ndarray) -> dict[tuple[int, int], np.ndarray]:
    prefix = np.concatenate(
        [np.zeros((profiles.shape[0], 1), dtype=np.float64), np.cumsum(profiles, axis=1)],
        axis=1,
    )
    means: dict[tuple[int, int], np.ndarray] = {}
    for start in range(16):
        for end in range(start + 1, 17):
            means[(start, end)] = (prefix[:, end] - prefix[:, start]) / float(end - start)
    return means


def bool_to_int(bits: np.ndarray) -> int:
    packed = np.packbits(bits, bitorder="little")
    return int.from_bytes(packed.tobytes(), byteorder="little", signed=False)


def build_interval_bitsets(
    means: dict[tuple[int, int], np.ndarray],
    left: np.ndarray,
    right: np.ndarray,
    relevant: np.ndarray,
    threshold: float,
) -> dict[tuple[int, int], int]:
    masks: dict[tuple[int, int], int] = {}
    condition = np.empty(len(left), dtype=np.bool_)
    for interval, values in means.items():
        for start in range(0, len(left), PAIR_CHUNK):
            stop = min(len(left), start + PAIR_CHUNK)
            condition[start:stop] = (
                np.abs(values[left[start:stop]] - values[right[start:stop]]) <= threshold
            ) & relevant[start:stop]
        masks[interval] = bool_to_int(condition)
    return masks


def collision_count_from_masks(
    ends: tuple[int, ...],
    relevant_int: int,
    masks: dict[tuple[int, int], int],
) -> int:
    current = relevant_int
    start = 0
    for end in ends:
        current &= masks[(start, end)]
        if current == 0:
            return 0
        start = end
    return current.bit_count()


def exhaustive_widest_screen(
    relevant_int: int,
    widest_masks: dict[tuple[int, int], int],
) -> dict[int, dict[str, object]]:
    result: dict[int, dict[str, object]] = {}
    for dimension in range(2, 11):
        minimum: int | None = None
        ties: list[tuple[int, ...]] = []
        candidate_count = 0
        for cuts in itertools.combinations(range(1, 16), dimension - 1):
            candidate_count += 1
            ends = cuts + (16,)
            count = collision_count_from_masks(ends, relevant_int, widest_masks)
            if minimum is None or count < minimum:
                minimum = count
                ties = [ends]
            elif count == minimum:
                ties.append(ends)
        result[dimension] = {
            "candidate_count": candidate_count,
            "minimum_collision_count_at_4x": int(minimum if minimum is not None else -1),
            "minimum_tie_count_at_4x": len(ties),
            "ties": ties,
        }
    return result


def candidate_distances_chunk(
    ends: tuple[int, ...],
    means: dict[tuple[int, int], np.ndarray],
    left: np.ndarray,
    right: np.ndarray,
    start: int,
    stop: int,
) -> np.ndarray:
    distance = np.zeros(stop - start, dtype=np.float64)
    layer_start = 0
    for layer_end in ends:
        values = means[(layer_start, layer_end)]
        distance = np.maximum(
            distance,
            np.abs(values[left[start:stop]] - values[right[start:stop]]),
        )
        layer_start = layer_end
    return distance


def candidate_collision_counts(
    ends: tuple[int, ...],
    means: dict[tuple[int, int], np.ndarray],
    left: np.ndarray,
    right: np.ndarray,
    relevant: np.ndarray,
) -> dict[float, int]:
    counts = {mult: 0 for mult in MULTIPLIERS}
    for start in range(0, len(left), PAIR_CHUNK):
        stop = min(len(left), start + PAIR_CHUNK)
        active = relevant[start:stop]
        if not np.any(active):
            continue
        distance = candidate_distances_chunk(ends, means, left, right, start, stop)
        for mult in MULTIPLIERS:
            counts[mult] += int(np.count_nonzero(active & (distance <= mult * FLOOR)))
    return counts


def select_partition(
    widest_row: dict[str, object],
    means: dict[tuple[int, int], np.ndarray],
    left: np.ndarray,
    right: np.ndarray,
    relevant: np.ndarray,
) -> tuple[tuple[int, ...], dict[float, int]]:
    ties = list(widest_row["ties"])
    widest_minimum = int(widest_row["minimum_collision_count_at_4x"])
    if widest_minimum == 0:
        chosen = min(ties)
        return chosen, candidate_collision_counts(chosen, means, left, right, relevant)

    survivors = ties
    cached: dict[tuple[int, ...], dict[float, int]] = {}
    for mult in (2.0, 1.0, 0.5, 0.25):
        scored: list[tuple[int, tuple[int, ...]]] = []
        for ends in survivors:
            if ends not in cached:
                cached[ends] = candidate_collision_counts(ends, means, left, right, relevant)
            scored.append((cached[ends][mult], ends))
        best = min(score for score, _ in scored)
        survivors = [ends for score, ends in scored if score == best]
        if best == 0:
            break

    chosen = min(survivors)
    if chosen not in cached:
        cached[chosen] = candidate_collision_counts(chosen, means, left, right, relevant)
    return chosen, cached[chosen]


def nearest_adversarial_pairs(
    ends: tuple[int, ...],
    means: dict[tuple[int, int], np.ndarray],
    profiles: np.ndarray,
    keys: list[tuple[str, int]],
    left: np.ndarray,
    right: np.ndarray,
    relevant: np.ndarray,
    count: int = 8,
) -> list[dict[str, object]]:
    best: list[tuple[float, int]] = []
    for start in range(0, len(left), PAIR_CHUNK):
        stop = min(len(left), start + PAIR_CHUNK)
        active = relevant[start:stop]
        if not np.any(active):
            continue
        distance = candidate_distances_chunk(ends, means, left, right, start, stop)
        distance = np.where(active, distance, np.inf)
        finite_count = int(np.count_nonzero(np.isfinite(distance)))
        if finite_count == 0:
            continue
        take = min(count, finite_count)
        local = np.argpartition(distance, take - 1)[:take]
        for idx in local:
            if math.isfinite(float(distance[idx])):
                best.append((float(distance[idx]), start + int(idx)))

    best.sort(key=lambda item: (item[0], item[1]))
    rows: list[dict[str, object]] = []
    seen: set[tuple[int, int]] = set()
    for reduced_distance, pair_index in best:
        i = int(left[pair_index])
        j = int(right[pair_index])
        pair = (min(i, j), max(i, j))
        if pair in seen:
            continue
        seen.add(pair)
        full_distance = float(np.max(np.abs(profiles[i] - profiles[j])))
        rows.append({
            "a": {"history": keys[i][0], "step": keys[i][1]},
            "b": {"history": keys[j][0], "step": keys[j][1]},
            "candidate_theta_linf": reduced_distance,
            "candidate_distance_over_diagnostic_floor": reduced_distance / FLOOR,
            "full_theta_linf": full_distance,
            "full_distance_over_diagnostic_floor": full_distance / FLOOR,
        })
        if len(rows) == count:
            break
    if len(rows) != count:
        raise SystemExit(f"only {len(rows)} adversarial pairs found for {ends}")
    return rows


def depth_boundaries(ends: tuple[int, ...]) -> list[int]:
    return [0] + [10 * end for end in ends]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=pathlib.Path)
    parser.add_argument("--prereg", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()

    prereg = json.loads(args.prereg.read_text())
    if prereg["phase"] != "PREREGISTERED_BEFORE_REDUCED_PARTITION_SCREEN":
        raise SystemExit("wrong P1 preregistration phase")
    if prereg["diagnostic_state_scale"]["theta_floor"] != FLOOR:
        raise SystemExit("P1 diagnostic floor drift")
    if prereg["diagnostic_state_scale"]["proximity_multipliers"] != list(MULTIPLIERS):
        raise SystemExit("P1 multiplier drift")
    if prereg["pre_execution_method_clarification"]["before_first_P1_execution"] is not True:
        raise SystemExit("P1 method clarification missing")

    keys, profiles = load_profiles(args.input)
    left, right = build_cross_history_pairs(keys)
    relevant = full_relevant_mask(profiles, left, right)
    relevant_int = bool_to_int(relevant)
    means = interval_means(profiles)

    widest_masks = build_interval_bitsets(
        means, left, right, relevant, SCORE_ORDER[0] * FLOOR
    )
    widest = exhaustive_widest_screen(relevant_int, widest_masks)

    selected: dict[str, object] = {}
    selected_ends: dict[str, tuple[int, ...]] = {}
    for dimension in range(2, 11):
        chosen, counts = select_partition(
            widest[dimension], means, left, right, relevant
        )
        key = f"D{dimension}"
        selected_ends[key] = chosen
        selected[key] = {
            "dimension": dimension,
            "end_indices": list(chosen),
            "depth_boundaries_cm": depth_boundaries(chosen),
            "collision_counts": {str(mult): counts[mult] for mult in MULTIPLIERS},
            "widest_4x_minimum_collision_count": widest[dimension]["minimum_collision_count_at_4x"],
            "widest_4x_tie_count": widest[dimension]["minimum_tie_count_at_4x"],
        }

    controls = {
        row["id"]: tuple(int(value) for value in row["end_indices"])
        for row in prereg["fixed_controls"]
    }
    control_results: dict[str, object] = {}
    for control_id, ends in controls.items():
        counts = candidate_collision_counts(ends, means, left, right, relevant)
        control_results[control_id] = {
            "dimension": len(ends),
            "end_indices": list(ends),
            "depth_boundaries_cm": depth_boundaries(ends),
            "collision_counts": {str(mult): counts[mult] for mult in MULTIPLIERS},
        }

    pair_manifests: dict[str, object] = {}
    all_pair_candidates = dict(selected_ends)
    for control_id, ends in controls.items():
        all_pair_candidates[f"CONTROL_{control_id}"] = ends
    for candidate_id, ends in all_pair_candidates.items():
        pair_manifests[candidate_id] = {
            "end_indices": list(ends),
            "depth_boundaries_cm": depth_boundaries(ends),
            "pairs": nearest_adversarial_pairs(
                ends, means, profiles, keys, left, right, relevant,
                count=prereg["adversarial_pair_freeze"]["pair_count_per_partition"],
            ),
        }

    summary_widest = {
        str(dimension): {
            "candidate_count": widest[dimension]["candidate_count"],
            "minimum_collision_count_at_4x": widest[dimension]["minimum_collision_count_at_4x"],
            "minimum_tie_count_at_4x": widest[dimension]["minimum_tie_count_at_4x"],
        }
        for dimension in range(2, 11)
    }

    result = {
        "schema": "swap5.lare.rs1.gw.p1.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-RS1-GW-P1",
        "decision": "LARE_RS1_GW_P1_RESPONSE_BLIND_PARTITIONS_FROZEN",
        "input": {
            "accepted_state_payload_sha256": hashlib.sha256(args.input.read_bytes()).hexdigest(),
            "state_count": len(keys),
            "cross_history_pair_count": len(left),
            "full_state_diagnostic_pair_count": int(np.count_nonzero(relevant)),
            "diagnostic_theta_floor": FLOOR,
        },
        "widest_4x_exhaustive_screen": summary_widest,
        "selected_partitions": selected,
        "fixed_controls": control_results,
        "frozen_adversarial_pairs": pair_manifests,
        "interpretation": [
            "P1 is a response-blind state-information screen, not a hydrological acceptance test.",
            "The diagnostic theta floor and proximity multipliers do not define application tolerances.",
            "Future probe outputs were not used to select partitions or pairs.",
            "No LARE propagation dynamics or closure was executed."
        ],
        "future_probe_response_used": False,
        "lare_dynamics_executed": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "decision": result["decision"],
        "input": result["input"],
        "widest_4x_exhaustive_screen": summary_widest,
        "selected_partitions": selected,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
