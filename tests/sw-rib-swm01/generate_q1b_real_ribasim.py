from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import shutil
import sys

from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, level_boundary, level_demand, pump
from shapely.geometry import Point

DAY = 86400.0
AREA_M2 = 1.0
TARGET_LEVEL_M = -0.2
CASES = [
    ("B1_ALREADY_ABOVE_SUPPLY_TARGET", -0.1, 0.3),
    ("B2_CAPACITY_SUFFICIENT", -0.4, 0.3),
    ("B3_CAPACITY_LIMITED", -0.4, 0.1),
]


def build_model(initial_level_m: float, max_supply_m3_per_day: float) -> Model:
    start = datetime(2020, 1, 1)
    model = Model(
        starttime=start,
        endtime=start + timedelta(seconds=DAY),
        crs="EPSG:28992",
        allocation=Allocation(dt=DAY),
        experimental=Experimental(allocation=True),
        solver=Solver(saveat=DAY),
    )

    source = model.level_boundary.add(
        Node(1, Point(-2.0, 0.0), subnetwork_id=2, route_priority=0, name="supply_source"),
        [level_boundary.Static(level=[1.0])],
    )
    supply = model.pump.add(
        Node(2, Point(-1.0, 0.0), subnetwork_id=2, route_priority=10, name="bounded_supply"),
        [
            pump.Static(
                flow_rate=[0.0],
                max_flow_rate=[max_supply_m3_per_day / DAY],
                allocation_controlled=[True],
            )
        ],
    )
    store = model.basin.add(
        Node(3, Point(0.0, 0.0), subnetwork_id=2, route_priority=0, name="surface_water"),
        [
            basin.Profile(level=[-1.0, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[initial_level_m]),
        ],
    )
    demand = model.level_demand.add(
        Node(4, Point(0.0, 1.0), subnetwork_id=2, route_priority=0, name="legacy_wldip_equivalent"),
        [
            # One-sided demand: max_level intentionally omitted. The pinned
            # Ribasim release defines missing max_level as +Inf.
            level_demand.Static(min_level=[TARGET_LEVEL_M], demand_priority=[1])
        ],
    )

    model.link.add(source, supply)
    model.link.add(supply, store)
    model.link.add(demand, store)
    return model


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_q1b_real_ribasim.py <output-root>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    for case_id, initial_level, max_supply in CASES:
        case_dir = out / case_id
        case_dir.mkdir()
        path = case_dir / "ribasim.toml"
        build_model(initial_level, max_supply).write(path)
        print(
            "SW_RIB_SWM01_Q1B_MODEL_GENERATED "
            f"case={case_id} initial_level_m={initial_level} "
            f"max_supply_m3_per_day={max_supply} path={path}"
        )

    print("SW_RIB_SWM01_Q1B_MODEL_GENERATION=PASS")


if __name__ == "__main__":
    main()
