#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generated", required=True, type=pathlib.Path)
    parser.add_argument("--expected", required=True, type=pathlib.Path)
    args = parser.parse_args()

    generated = json.loads(args.generated.read_text())
    expected = json.loads(args.expected.read_text())

    assert generated["schema"] == "swap5.lare.rs1.partition-screen.v1"
    assert expected["schema"] == "swap5.lare.rs1.partition-screen-result.v1"

    assert generated["inputs"]["B01"]["sha256"] == expected["inputs"]["B01"]["o0_state_library_sha256"]
    assert generated["inputs"]["B14"]["sha256"] == expected["inputs"]["B14"]["o0_state_library_sha256"]

    for material in ("B01", "B14"):
        for nlayer, row in expected["partition_search"][material].items():
            got = generated[material]["by_layer_count"][nlayer]
            assert got["candidate_partition_count"] == row["candidate_count"], (material, nlayer, got, row)
            assert got["zero_collision_partition_count"] == row["zero_collision_count"], (material, nlayer, got, row)
            assert got["minimum_collision_count"] == row["minimum_collision_count"], (material, nlayer, got, row)

    for nlayer, row in expected["partition_search"]["cross_material"].items():
        got = generated["cross_material"][nlayer]
        assert got["zero_collision_in_both_materials"] == row["zero_collision_in_both"], (nlayer, got, row)

    selected = generated["selected"]["cross_material_minimum"]
    exp = expected["cross_material_minimum_partition"]
    assert selected["B01"]["depth_boundaries_cm"] == [0, 10, 140, 150, 160]
    assert selected["B14"]["depth_boundaries_cm"] == [0, 10, 140, 150, 160]
    for material in ("B01", "B14"):
        assert selected[material]["collision_count"] == exp[material]["collision_count"]
        assert selected[material]["minimum_induced_theta_linf_over_full_distinguishable_pairs"] == exp[material]["minimum_induced_theta_linf"]
        assert selected[material]["minimum_separation_margin_over_theta_floor"] == exp[material]["minimum_margin_over_floor"]

    print("LARE_RS1_PARTITION_REPLAY=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
