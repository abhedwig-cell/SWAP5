#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib


def dimension_from_id(candidate_id: str) -> int:
    if not candidate_id.startswith("D"):
        raise ValueError(candidate_id)
    return int(candidate_id[1:])


def history_index(label: str) -> int:
    if len(label) != 3 or not label.startswith("G"):
        raise ValueError(label)
    value = int(label[1:])
    if value < 0 or value > 5:
        raise ValueError(label)
    return value + 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--p1", required=True, type=pathlib.Path)
    ap.add_argument("--p2-prereg", required=True, type=pathlib.Path)
    ap.add_argument("--starts", required=True, type=pathlib.Path)
    ap.add_argument("--selection", required=True, type=pathlib.Path)
    args = ap.parse_args()

    p1 = json.loads(args.p1.read_text())
    p2 = json.loads(args.p2_prereg.read_text())

    if p1["decision"] != "LARE_RS1_GW_P1_RESPONSE_BLIND_PARTITIONS_FROZEN":
        raise SystemExit("formal P1 result not qualified")
    if p1.get("future_probe_response_used") is not False:
        raise SystemExit("P1 was not response blind")
    if p2["phase"] != "PREREGISTERED_BEFORE_FORMAL_P1_PAIR_FUTURE_RESPONSE_EXECUTION":
        raise SystemExit("wrong P2 preregistration phase")

    partitions = p1["selected_partitions"]
    ordered = sorted(partitions, key=lambda cid: dimension_from_id(cid))

    separating = [
        cid for cid in ordered
        if int(partitions[cid]["collision_counts"]["1.0"]) == 0
    ]
    if not separating:
        raise SystemExit("no state-separating P1 representation")
    state_id = separating[0]
    state_dim = dimension_from_id(state_id)

    aggressive_dim = max(2, state_dim - 1)
    aggressive_id = f"D{aggressive_dim}"
    if aggressive_id not in partitions:
        raise SystemExit("aggressive representation absent")

    minimum_4x = min(
        int(partitions[cid]["widest_4x_minimum_collision_count"])
        for cid in ordered
    )
    robust = [
        cid for cid in ordered
        if int(partitions[cid]["widest_4x_minimum_collision_count"]) == minimum_4x
    ]
    robust_id = robust[0]

    roles: dict[str, list[str]] = {}
    for role, cid in (
        ("D_AGGRESSIVE", aggressive_id),
        ("D_STATE_SEPARATING", state_id),
        ("D_ROBUST_PLATEAU", robust_id),
    ):
        roles.setdefault(cid, []).append(role)

    controls = [
        row for row in p2["representation_selection_rule"]["controls"]
    ]
    for control in controls:
        cid = f"CONTROL_{control}"
        if cid not in p1["frozen_adversarial_pairs"]:
            raise SystemExit(f"missing formal P1 pair manifest {cid}")
        roles.setdefault(cid, []).append(f"CONTROL_{control}")

    selected = []
    starts: set[tuple[int, int]] = set()

    for cid in sorted(
        roles,
        key=lambda value: (
            0 if value.startswith("D") else 1,
            dimension_from_id(value) if value.startswith("D") else value,
        ),
    ):
        manifest = p1["frozen_adversarial_pairs"][cid]
        pairs = manifest["pairs"]
        if len(pairs) != 8:
            raise SystemExit(f"{cid} does not have exactly eight frozen P1 pairs")
        for pair in pairs:
            for side in ("a", "b"):
                label = pair[side]["history"]
                step = int(pair[side]["step"])
                starts.add((history_index(label), step))
        if cid.startswith("D"):
            representation = partitions[cid]
        else:
            base = cid.removeprefix("CONTROL_")
            representation = p1["fixed_controls"][base]
        selected.append({
            "candidate_id": cid,
            "roles": roles[cid],
            "dimension": int(representation["dimension"]),
            "end_indices": representation["end_indices"],
            "depth_boundaries_cm": representation["depth_boundaries_cm"],
            "collision_counts": representation["collision_counts"],
            "pairs": pairs,
        })

    args.starts.write_text(
        "".join(f"{ih} {step}\n" for ih, step in sorted(starts))
    )
    selection = {
        "schema": "swap5.lare.rs1.gw.p2.selection.v1",
        "source_p1_decision": p1["decision"],
        "response_used_for_selection": False,
        "selection_rule_result": {
            "D_AGGRESSIVE": aggressive_id,
            "D_STATE_SEPARATING": state_id,
            "D_ROBUST_PLATEAU": robust_id,
            "minimum_4x_collision_count": minimum_4x,
        },
        "representations": selected,
        "unique_start_state_count": len(starts),
        "start_rows": [
            {"history_index": ih, "history": f"G{ih-1:02d}", "step": step}
            for ih, step in sorted(starts)
        ],
        "pair_reselection": False,
        "future_response_used": False,
    }
    args.selection.write_text(json.dumps(selection, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": selection["schema"],
        "selection_rule_result": selection["selection_rule_result"],
        "representation_count": len(selected),
        "unique_start_state_count": len(starts),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
