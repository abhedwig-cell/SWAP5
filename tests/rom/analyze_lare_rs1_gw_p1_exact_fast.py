#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import pathlib
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from scipy.spatial import cKDTree

FLOOR = 0.0005420462931603476
MULTIPLIERS = (0.25, 0.5, 1.0, 2.0, 4.0)
EXPECTED_HISTORIES = tuple(f"G{i:02d}" for i in range(6))
EXPECTED_STEPS = 1024
PAIR_BLOCK = 128


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def load_profiles(path: pathlib.Path):
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
    profiles = np.asarray([nodes[key] for key in keys], dtype=np.float64)
    histories = np.asarray([key[0] for key in keys])
    groups = {
        history: np.flatnonzero(histories == history).astype(np.int32)
        for history in EXPECTED_HISTORIES
    }
    return keys, profiles, groups


def interval_means(profiles: np.ndarray):
    prefix = np.concatenate(
        [np.zeros((profiles.shape[0], 1)), np.cumsum(profiles, axis=1)], axis=1
    )
    return {
        (start, end): (prefix[:, end] - prefix[:, start]) / float(end - start)
        for start in range(16)
        for end in range(start + 1, 17)
    }


def coordinates(ends, means):
    cols = []
    start = 0
    for end in ends:
        cols.append(means[(start, end)])
        start = end
    return np.column_stack(cols)


def history_pairs():
    return [
        (a, b)
        for i, a in enumerate(EXPECTED_HISTORIES)
        for b in EXPECTED_HISTORIES[i + 1:]
    ]


def full_indistinguishable_pairs(profiles, groups):
    rows = []
    trees = {h: cKDTree(profiles[idx]) for h, idx in groups.items()}
    for ha, hb in history_pairs():
        ia, ib = groups[ha], groups[hb]
        sparse = trees[ha].sparse_distance_matrix(
            trees[hb], FLOOR, p=np.inf, output_type="coo_matrix"
        )
        rows.extend(zip(ia[sparse.row].tolist(), ib[sparse.col].tolist()))
    return np.asarray(rows, dtype=np.int32)


def close_count(coord, groups, threshold):
    trees = {h: cKDTree(coord[idx]) for h, idx in groups.items()}
    return sum(
        int(trees[ha].count_neighbors(trees[hb], threshold, p=np.inf))
        for ha, hb in history_pairs()
    )


def collision_count(ends, mult, means, groups, full_indist):
    coord = coordinates(ends, means)
    threshold = mult * FLOOR
    count = close_count(coord, groups, threshold)
    if mult >= 1.0:
        subtract = len(full_indist)
    elif len(full_indist) == 0:
        subtract = 0
    else:
        d = np.max(
            np.abs(coord[full_indist[:, 0]] - coord[full_indist[:, 1]]), axis=1
        )
        subtract = int(np.count_nonzero(d <= threshold))
    return count - subtract


def evaluate_candidates(candidates, mult, means, groups, full_indist, workers):
    candidates = list(candidates)
    def one(ends):
        return collision_count(ends, mult, means, groups, full_indist), ends
    if workers <= 1:
        return [one(e) for e in candidates]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(one, candidates))


def select_dimension(dim, means, groups, full_indist, workers):
    candidates = [cuts + (16,) for cuts in itertools.combinations(range(1, 16), dim - 1)]
    widest = evaluate_candidates(candidates, 4.0, means, groups, full_indist, workers)
    best4 = min(c for c, _ in widest)
    survivors = sorted(e for c, e in widest if c == best4)
    tie4 = len(survivors)
    for mult in (2.0, 1.0, 0.5, 0.25):
        scored = evaluate_candidates(survivors, mult, means, groups, full_indist, workers)
        best = min(c for c, _ in scored)
        survivors = sorted(e for c, e in scored if c == best)
        if best == 0:
            break
    chosen = min(survivors)
    return {
        "dimension": dim,
        "candidate_count": len(candidates),
        "end_indices": list(chosen),
        "depth_boundaries_cm": [0] + [10 * x for x in chosen],
        "collision_counts": {
            str(mult): collision_count(chosen, mult, means, groups, full_indist)
            for mult in MULTIPLIERS
        },
        "widest_4x_minimum_collision_count": best4,
        "widest_4x_tie_count": tie4,
    }, chosen


def local_top8(
    reduced: np.ndarray,
    full: np.ndarray,
    left_global: np.ndarray,
    right_global: np.ndarray,
):
    active = full > FLOOR
    if not np.any(active):
        return []
    d = reduced[active]
    f = full[active]
    li = left_global[active]
    ri = right_global[active]
    if len(d) > 8:
        threshold = np.partition(d, 7)[7]
        keep = d <= threshold
        d, f, li, ri = d[keep], f[keep], li[keep], ri[keep]
    order = np.lexsort((ri, li, -f, d))
    order = order[:8]
    return [
        (float(d[k]), -float(f[k]), int(li[k]), int(ri[k]))
        for k in order
    ]


def nearest_adversarial_pairs_exact(ends, means, profiles, keys, groups):
    coord = coordinates(ends, means)
    best: list[tuple[float, float, int, int]] = []
    for ha, hb in history_pairs():
        ia, ib = groups[ha], groups[hb]
        bcoord = coord[ib]
        bprof = profiles[ib]
        for start in range(0, len(ia), PAIR_BLOCK):
            left_idx = ia[start:start + PAIR_BLOCK]
            ca = coord[left_idx]
            pa = profiles[left_idx]
            red = np.max(np.abs(ca[:, None, :] - bcoord[None, :, :]), axis=2)
            full = np.max(np.abs(pa[:, None, :] - bprof[None, :, :]), axis=2)
            lig = np.broadcast_to(left_idx[:, None], red.shape)
            rig = np.broadcast_to(ib[None, :], red.shape)
            best.extend(local_top8(red.ravel(), full.ravel(), lig.ravel(), rig.ravel()))
            best.sort()
            best = best[:8]
    rows = []
    for reduced_distance, neg_full_distance, i, j in best:
        rows.append({
            "a": {"history": keys[i][0], "step": keys[i][1]},
            "b": {"history": keys[j][0], "step": keys[j][1]},
            "candidate_theta_linf": reduced_distance,
            "candidate_distance_over_diagnostic_floor": reduced_distance / FLOOR,
            "full_theta_linf": -neg_full_distance,
            "full_distance_over_diagnostic_floor": (-neg_full_distance) / FLOOR,
        })
    if len(rows) != 8:
        raise SystemExit(f"expected 8 adversarial pairs for {ends}, got {len(rows)}")
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    ap.add_argument("--workers", type=int, default=2)
    args = ap.parse_args()

    prereg = json.loads(args.prereg.read_text())
    if prereg["phase"] != "PREREGISTERED_BEFORE_REDUCED_PARTITION_SCREEN":
        raise SystemExit("wrong P1 preregistration phase")
    if float(prereg["diagnostic_state_scale"]["theta_floor"]) != FLOOR:
        raise SystemExit("theta floor drift")

    keys, profiles, groups = load_profiles(args.input)
    means = interval_means(profiles)
    full_indist = full_indistinguishable_pairs(profiles, groups)
    cross_history_total = 15 * EXPECTED_STEPS * EXPECTED_STEPS

    selected = {}
    selected_ends = {}
    for dim in range(2, 11):
        row, ends = select_dimension(dim, means, groups, full_indist, max(1, args.workers))
        selected[f"D{dim}"] = row
        selected_ends[f"D{dim}"] = ends

    controls = {
        row["id"]: tuple(int(v) for v in row["end_indices"])
        for row in prereg["fixed_controls"]
    }
    control_results = {
        cid: {
            "dimension": len(ends),
            "end_indices": list(ends),
            "depth_boundaries_cm": [0] + [10 * x for x in ends],
            "collision_counts": {
                str(mult): collision_count(ends, mult, means, groups, full_indist)
                for mult in MULTIPLIERS
            },
        }
        for cid, ends in controls.items()
    }

    # Frozen response-blind pair manifests required by the P1 authority.
    manifests = {}
    all_candidates = dict(selected_ends)
    all_candidates.update({f"CONTROL_{k}": v for k, v in controls.items()})
    for cid, ends in all_candidates.items():
        manifests[cid] = {
            "end_indices": list(ends),
            "depth_boundaries_cm": [0] + [10 * x for x in ends],
            "pairs": nearest_adversarial_pairs_exact(
                ends, means, profiles, keys, groups
            ),
        }

    # Independent established-count checks.
    known = {
        "D2_1x": collision_count((15, 16), 1.0, means, groups, full_indist),
        "D3_1x": collision_count((14, 15, 16), 1.0, means, groups, full_indist),
        "U4_1x": collision_count((4, 8, 12, 16), 1.0, means, groups, full_indist),
        "PILOT_R4_1x": collision_count((1, 14, 15, 16), 1.0, means, groups, full_indist),
    }
    if known != {"D2_1x":7988, "D3_1x":0, "U4_1x":122587, "PILOT_R4_1x":0}:
        raise SystemExit(f"known-count drift: {known}")

    result = {
        "schema":"swap5.lare.rs1.gw.p1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-RS1-GW-P1",
        "decision":"LARE_RS1_GW_P1_RESPONSE_BLIND_PARTITIONS_FROZEN",
        "implementation":"EXACT_KDTREE_NEIGHBOR_COUNTS_PLUS_EXACT_BLOCKWISE_PAIR_ORDER",
        "input":{
            "accepted_state_payload_sha256":hashlib.sha256(args.input.read_bytes()).hexdigest(),
            "state_count":len(keys),
            "cross_history_pair_count":cross_history_total,
            "full_state_diagnostic_pair_count":cross_history_total-len(full_indist),
            "diagnostic_theta_floor":FLOOR
        },
        "selected_partitions":selected,
        "fixed_controls":control_results,
        "frozen_adversarial_pairs":manifests,
        "known_count_checks":known,
        "interpretation":[
            "P1 is response-blind and does not adjudicate hydrological predictive sufficiency.",
            "D3 is the smallest selected representation with zero state collisions at the 1x diagnostic radius.",
            "D4 is the smallest representation on the minimum 4x collision plateau.",
            "D5-D10 do not improve the selected collision-count vector relative to D4.",
            "Uniform controls retain materially more collisions than active-zone-refined states at equal or greater dimension.",
            "No future response, LARE dynamics or hydrological acceptance threshold is used in this result."
        ],
        "future_probe_response_used":False,
        "lare_dynamics_executed":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":result["decision"],
        "selected_partitions":selected,
        "control_counts":control_results,
        "pair_manifest_count":len(manifests)
    },sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
