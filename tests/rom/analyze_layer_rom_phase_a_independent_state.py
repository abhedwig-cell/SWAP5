#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import pathlib
from typing import Any

import numpy as np

EXPECTED_HISTORIES = ("F00", "F01", "F02", "H00", "H01", "H02")
EXPECTED_STEPS = 1024
DIAGNOSTIC_FLOOR = 0.0005420462931603476
MULTIPLIERS = (0.25, 0.5, 1.0, 2.0, 4.0)


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
        if not line.startswith("LAYERR1_NODE|"):
            continue
        row = fields(line.split("|", 1)[1])
        key = (row["HISTORY"], int(row["STEP"]))
        profile = nodes.setdefault(key, [None] * 16)
        profile[int(row["NODE"]) - 1] = float(row["THETA"])

    expected = {(h, s) for h in EXPECTED_HISTORIES for s in range(1, EXPECTED_STEPS + 1)}
    if set(nodes) != expected:
        raise SystemExit("Layer-ROM independent input structure mismatch")
    keys = sorted(nodes)
    if any(any(value is None for value in nodes[key]) for key in keys):
        raise SystemExit("Layer-ROM independent input contains incomplete fine profiles")
    profiles = np.asarray([nodes[key] for key in keys], dtype=np.float64)
    if profiles.shape != (6144, 16) or not np.all(np.isfinite(profiles)):
        raise SystemExit("Layer-ROM independent input profile matrix invalid")
    return keys, profiles


def boundaries_to_ends(boundaries_cm: list[int]) -> tuple[int, ...]:
    if boundaries_cm[0] != 0 or boundaries_cm[-1] != 160:
        raise ValueError("representation must span 0..160 cm")
    if any(value % 10 for value in boundaries_cm):
        raise ValueError("Phase A retrospective replay requires 10-cm aligned boundaries")
    ends = tuple(value // 10 for value in boundaries_cm[1:])
    if tuple(sorted(set(ends))) != ends or ends[-1] != 16:
        raise ValueError("invalid contiguous representation")
    return ends


def project(profiles: np.ndarray, ends: tuple[int, ...]) -> np.ndarray:
    cols = []
    start = 0
    for end in ends:
        cols.append(np.mean(profiles[:, start:end], axis=1))
        start = end
    return np.column_stack(cols)


def pair_counts(
    keys: list[tuple[str, int]],
    fine: np.ndarray,
    candidates: dict[str, np.ndarray],
) -> tuple[int, dict[str, dict[str, int]], dict[str, dict[str, Any]]]:
    history_indices = {
        h: np.asarray([i for i, key in enumerate(keys) if key[0] == h], dtype=np.int32)
        for h in EXPECTED_HISTORIES
    }
    counts = {name: {str(mult): 0 for mult in MULTIPLIERS} for name in candidates}
    nearest: dict[str, list[tuple[float, float, tuple[str, int], tuple[str, int]]]] = {
        name: [] for name in candidates
    }
    relevant_pairs = 0

    for ia, ha in enumerate(EXPECTED_HISTORIES):
        a = history_indices[ha]
        for hb in EXPECTED_HISTORIES[ia + 1:]:
            b = history_indices[hb]
            fine_distance = np.max(
                np.abs(fine[a, None, :] - fine[b, :, :]),
                axis=2,
            )
            relevant = fine_distance > DIAGNOSTIC_FLOOR
            relevant_pairs += int(np.count_nonzero(relevant))
            if not np.any(relevant):
                continue

            for name, coord in candidates.items():
                distance = np.max(
                    np.abs(coord[a, None, :] - coord[b, :, :]),
                    axis=2,
                )
                for mult in MULTIPLIERS:
                    counts[name][str(mult)] += int(
                        np.count_nonzero(relevant & (distance <= mult * DIAGNOSTIC_FLOOR))
                    )

                masked = np.where(relevant, distance, np.inf)
                take = min(8, int(np.count_nonzero(np.isfinite(masked))))
                if take:
                    flat = masked.ravel()
                    idx = np.argpartition(flat, take - 1)[:take]
                    for pos in idx:
                        i, j = np.unravel_index(int(pos), masked.shape)
                        nearest[name].append(
                            (
                                float(masked[i, j]),
                                float(fine_distance[i, j]),
                                keys[int(a[i])],
                                keys[int(b[j])],
                            )
                        )

    nearest_out: dict[str, dict[str, Any]] = {}
    for name, rows in nearest.items():
        rows.sort(key=lambda row: (row[0], row[1], row[2], row[3]))
        unique = []
        seen = set()
        for reduced_distance, full_distance, ka, kb in rows:
            sig = (ka, kb)
            if sig in seen:
                continue
            seen.add(sig)
            unique.append(
                {
                    "a": {"history": ka[0], "step": ka[1]},
                    "b": {"history": kb[0], "step": kb[1]},
                    "candidate_theta_linf": reduced_distance,
                    "candidate_distance_over_floor": reduced_distance / DIAGNOSTIC_FLOOR,
                    "full_theta_linf": full_distance,
                    "full_distance_over_floor": full_distance / DIAGNOSTIC_FLOOR,
                }
            )
            if len(unique) == 8:
                break
        nearest_out[name] = {
            "pairs": unique,
            "minimum_candidate_distance_over_floor": (
                unique[0]["candidate_distance_over_floor"] if unique else None
            ),
        }

    return relevant_pairs, counts, nearest_out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=pathlib.Path, required=True)
    parser.add_argument("--prereg", type=pathlib.Path, required=True)
    parser.add_argument("--state-prereg", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()

    prereg = json.loads(args.prereg.read_text())
    if prereg["phase"] != "FROZEN_BEFORE_LAYER_ROM_SPECIFIC_REANALYSIS_OR_NEW_REFERENCE_EXECUTION":
        raise SystemExit("Layer-ROM preregistration phase mismatch")
    state_prereg = json.loads(args.state_prereg.read_text())
    if state_prereg["phase"] != "PREREGISTERED_BEFORE_INDEPENDENT_REFERENCE_RESULT_EXPOSURE":
        raise SystemExit("Layer-ROM state-response preregistration phase mismatch")
    if state_prereg["diagnostic_state_scale"]["theta_floor"] != DIAGNOSTIC_FLOOR:
        raise SystemExit("Layer-ROM diagnostic floor drift")
    if state_prereg["diagnostic_state_scale"]["multipliers"] != list(MULTIPLIERS):
        raise SystemExit("Layer-ROM diagnostic multiplier drift")

    keys, profiles = load_profiles(args.input)
    matrix = prereg["representation_matrix"]
    definitions: dict[str, dict[str, Any]] = {}
    definitions.update(matrix["smart"])
    definitions.update(matrix["uniform_controls"])

    candidates: dict[str, np.ndarray] = {}
    for name, row in definitions.items():
        ends = boundaries_to_ends(row["boundaries_cm"])
        if len(ends) != int(row["dimension"]):
            raise SystemExit(f"dimension mismatch for {name}")
        candidates[name] = project(profiles, ends)

    relevant_pairs, counts, nearest = pair_counts(keys, profiles, candidates)

    same_dimension = {}
    for dim in (2, 3, 4, 6):
        smart = f"L{dim}"
        uniform = f"U{dim}"
        same_dimension[str(dim)] = {
            "smart": smart,
            "uniform": uniform,
            "collision_count_1x": {
                smart: counts[smart]["1.0"],
                uniform: counts[uniform]["1.0"],
            },
            "collision_count_2x": {
                smart: counts[smart]["2.0"],
                uniform: counts[uniform]["2.0"],
            },
            "smart_minus_uniform_1x": counts[smart]["1.0"] - counts[uniform]["1.0"],
            "smart_minus_uniform_2x": counts[smart]["2.0"] - counts[uniform]["2.0"],
        }

    result = {
        "schema": "swap5.layer-rom.phase-a.independent-state-result.v1",
        "workstream": "F-ROM-LAYER",
        "work_unit": "LAYER-ROM-PHASE-A-STATE1",
        "decision": "INDEPENDENT_STATE_INFORMATION_SCREEN_COMPLETE",
        "evidence_class": "INDEPENDENT_REFERENCE_STATE_SCREEN",
        "input": {
            "source": "Layer-ROM Phase A independent Reference stdout",
            "stdout_sha256": hashlib.sha256(args.input.read_bytes()).hexdigest(),
            "state_count": len(keys),
            "history_count": len(EXPECTED_HISTORIES),
            "cross_history_full_state_distinguishable_pair_count": relevant_pairs,
            "diagnostic_theta_floor": DIAGNOSTIC_FLOOR,
            "diagnostic_floor_is_application_tolerance": False,
        },
        "representations": {
            name: {
                "boundaries_cm": definitions[name]["boundaries_cm"],
                "dimension": definitions[name]["dimension"],
                "collision_counts": counts[name],
                "nearest_adversarial": nearest[name],
            }
            for name in definitions
        },
        "same_dimension_controls": same_dimension,
        "interpretation_rules": [
            "The representation matrix was frozen before the independent Reference execution.",
            "The diagnostic floor and radius ladder were frozen before the independent result was inspected.",
            "Collision counts diagnose state information only; they do not evaluate future-response sufficiency or a propagation closure.",
            "Zero collision at the inherited numerical diagnostic floor does not establish hydrological or application sufficiency.",
            "Same-dimension smart-versus-uniform differences are interpreted only as relative state-information evidence."
        ],
        "future_response_executed": False,
        "closure_executed": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": result["decision"],
        "relevant_pairs": relevant_pairs,
        "same_dimension_controls": same_dimension,
        "collision_counts_1x": {name: counts[name]["1.0"] for name in definitions},
        "collision_counts_2x": {name: counts[name]["2.0"] for name in definitions},
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
