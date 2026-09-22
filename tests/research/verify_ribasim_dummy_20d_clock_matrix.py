#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

DAY = 86400.0
AREA = 1_000_000.0
ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
VOLUME_TOL = 0.05
LEVEL_TOL = 5.0e-8
SEPARATION = 5.0

REFS = {
    "A24": {
        "root": [4.001199759954048, 8.00479808014741, 12.010793520398778, 16.019184640970934],
        "external": [0.0, 0.0, 0.0, 0.0],
        "total": [4.001199759954048, 8.00479808014741, 12.010793520398778, 16.019184640970934],
    },
    "A6": {
        "root": [4.001199760004028, 9.004947510764467, 14.009817152853525, 19.01524636786452],
        "external": [0.0, 1.0001492206460414, 2.9995462301238116, 5.497574062835911],
        "total": [4.001199760004028, 10.005096731410507, 17.009363382977337, 24.51282043070043],
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load(root: Path, case: str) -> dict:
    return json.loads((root / f"{case}.json").read_text(encoding="utf-8"))


def expected_level(endpoint: float, total: float) -> float:
    inflow = 32.0 * endpoint / DAY
    return 1.0 + (inflow - total) / AREA


def check_reference(case: str, payload: dict) -> None:
    family = "A24" if case.startswith("A24") else "A6"
    ref = REFS[family]
    states = payload["states"]
    require(len(states) == 4, f"{case}: expected four product states")
    for i, endpoint in enumerate(ENDPOINTS):
        state = states[i]
        require(abs(state["endpoint_s"] - endpoint) <= 1.0e-6, f"{case}: endpoint mismatch")
        require(abs(state["root_cumulative_m3"] - ref["root"][i]) <= VOLUME_TOL, f"{case}: root reference mismatch at {endpoint}")
        require(abs(state["external_cumulative_m3"] - ref["external"][i]) <= VOLUME_TOL, f"{case}: external reference mismatch at {endpoint}")
        require(abs(state["total_cumulative_m3"] - ref["total"][i]) <= VOLUME_TOL, f"{case}: total reference mismatch at {endpoint}")
        level_ref = expected_level(endpoint, ref["total"][i])
        require(abs(state["level_m"] - level_ref) <= LEVEL_TOL, f"{case}: level reference mismatch at {endpoint}")


def check_pair(a: dict, b: dict, label: str) -> None:
    for i, endpoint in enumerate(ENDPOINTS):
        sa, sb = a["states"][i], b["states"][i]
        require(abs(sa["root_cumulative_m3"] - sb["root_cumulative_m3"]) <= VOLUME_TOL, f"{label}: root saveat difference at {endpoint}")
        require(abs(sa["external_cumulative_m3"] - sb["external_cumulative_m3"]) <= VOLUME_TOL, f"{label}: external saveat difference at {endpoint}")
        require(abs(sa["total_cumulative_m3"] - sb["total_cumulative_m3"]) <= VOLUME_TOL, f"{label}: total saveat difference at {endpoint}")
        require(abs(sa["level_m"] - sb["level_m"]) <= LEVEL_TOL, f"{label}: level saveat difference at {endpoint}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result-root", required=True)
    args = parser.parse_args()
    root = Path(args.result_root).resolve()

    cases = {name: load(root, name) for name in ("A24_S24", "A24_S1", "A6_S24", "A6_S1")}
    for name, payload in cases.items():
        check_reference(name, payload)

    check_pair(cases["A24_S24"], cases["A24_S1"], "A24")
    check_pair(cases["A6_S24"], cases["A6_S1"], "A6")

    final_a24 = cases["A24_S24"]["states"][-1]["total_cumulative_m3"]
    final_a6 = cases["A6_S24"]["states"][-1]["total_cumulative_m3"]
    require(final_a6 - final_a24 > SEPARATION, "allocation.dt classes are not materially separated")

    print(
        "RIBASIM_REAL_20D_SEPARATION "
        f"A24_total_m3={final_a24} A6_total_m3={final_a6} difference_m3={final_a6-final_a24}"
    )
    print("RIBASIM_REAL_20D_REAL_RIBAMOD_RUNTIME_CLOCK_OWNERSHIP_MATRIX=PASS")


if __name__ == "__main__":
    main()
