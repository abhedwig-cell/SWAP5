#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
VOLUME_TOL = 0.05
LEVEL_TOL = 5.0e-8
TIME_TOL = 1.0e-6
MIN_SEPARATION = 8.0

REFS = {
    "A5_S24": {
        "root": [4.001270619481194, 8.004878887695051, 12.0108669999443, 16.019258389454414],
        "external": [0.0, 0.0, 0.0, 0.0],
        "level": [1.0000039987293805, 1.0000079951211123, 1.000011989133, 1.0000159807416105],
        "allocation_seconds": [0.0],
    },
    "A6_S24": {
        "root": [4.001270619481194, 9.005178625966796, 14.010112381509137, 19.0156248969841],
        "external": [0.0, 1.000145795011281, 2.99945445979664, 5.49738186538438],
        "level": [1.0000039987293805, 1.000005994675579, 1.0000069904331588, 1.0000074869932376],
        "allocation_seconds": [0.0, 21600.0, 43200.0, 64800.0],
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load(root: Path, case: str) -> dict:
    return json.loads((root / f"{case}.json").read_text(encoding="utf-8"))


def check_case(case: str, payload: dict) -> None:
    ref = REFS[case]
    states = payload["states"]
    require(len(states) == 4, f"{case}: expected four product states")
    for i, endpoint in enumerate(ENDPOINTS):
        state = states[i]
        require(abs(state["endpoint_s"] - endpoint) <= TIME_TOL, f"{case}: endpoint mismatch")
        require(abs(state["root_cumulative_m3"] - ref["root"][i]) <= VOLUME_TOL,
                f"{case}: root reference mismatch at {endpoint}")
        require(abs(state["external_cumulative_m3"] - ref["external"][i]) <= VOLUME_TOL,
                f"{case}: external reference mismatch at {endpoint}")
        require(abs(state["level_m"] - ref["level"][i]) <= LEVEL_TOL,
                f"{case}: level reference mismatch at {endpoint}")

    observed = payload["allocation"]["seconds"]
    expected = ref["allocation_seconds"]
    require(len(observed) == len(expected),
            f"{case}: allocation record count {len(observed)} != {len(expected)}")
    for a, b in zip(observed, expected):
        require(abs(a - b) <= TIME_TOL, f"{case}: allocation record time {a} != {b}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result-root", required=True)
    args = parser.parse_args()
    root = Path(args.result_root).resolve()

    a5 = load(root, "A5_S24")
    a6 = load(root, "A6_S24")
    check_case("A5_S24", a5)
    check_case("A6_S24", a6)

    final_a5 = a5["states"][-1]["total_cumulative_m3"]
    final_a6 = a6["states"][-1]["total_cumulative_m3"]
    separation = final_a6 - final_a5
    require(separation > MIN_SEPARATION,
            f"noncommensurate clock effect too small: {separation}")

    require(a5["allocation"]["root_m3_per_day"] == [32.0],
            f"A5 initial/stale root allocation changed: {a5['allocation']['root_m3_per_day']}")
    require(all(abs(x) <= VOLUME_TOL for x in a5["allocation"]["external_m3_per_day"]),
            "A5 external allocation unexpectedly nonzero")

    print(
        "RIBASIM_REAL_20H10_CLOCK_ALIASING "
        f"A5_alloc_seconds={a5['allocation']['seconds']} "
        f"A6_alloc_seconds={a6['allocation']['seconds']} "
        f"A5_total_m3={final_a5} A6_total_m3={final_a6} separation_m3={separation}"
    )
    print("RIBASIM_REAL_20H10_NONCOMMENSURATE_ALLOCATION_CLOCK_ALIASING=PASS")


if __name__ == "__main__":
    main()
