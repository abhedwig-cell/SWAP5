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
LOWER_M = -0.3
UPPER_M = -0.2
ROUTE_PRIORITY = 10

CASES = [
    ("M1_BELOW_BAND_ADEQUATE", -0.4, 0.2, 0.2),
    ("M2_BELOW_BAND_LIMITED", -0.4, 0.05, 0.2),
    ("M3_INSIDE_BAND", -0.25, 0.2, 0.2),
    ("M4_ABOVE_BAND_ADEQUATE", -0.1, 0.2, 0.2),
    ("M5_ABOVE_BAND_LIMITED", -0.1, 0.2, 0.05),
]


def build_model(
    initial_level_m: float,
    max_supply_m3: float,
    max_discharge_m3: float,
) -> Model:
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
        Node(
            1,
            Point(-2.0, 0.0),
            subnetwork_id=2,
            route_priority=0,
            name="management_supply_source",
        ),
        [level_boundary.Static(level=[1.0])],
    )
    supply = model.pump.add(
        Node(
            2,
            Point(-1.0, 0.0),
            subnetwork_id=2,
            route_priority=ROUTE_PRIORITY,
            name="bounded_management_supply",
        ),
        [
            pump.Static(
                flow_rate=[0.0],
                max_flow_rate=[max_supply_m3 / DAY],
                allocation_controlled=[True],
            )
        ],
    )
    store = model.basin.add(
        Node(
            3,
            Point(0.0, 0.0),
            subnetwork_id=2,
            route_priority=0,
            name="externally_owned_surface_water",
        ),
        [
            basin.Profile(level=[-1.0, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[initial_level_m]),
        ],
    )
    discharge = model.pump.add(
        Node(
            4,
            Point(1.0, 0.0),
            subnetwork_id=2,
            route_priority=ROUTE_PRIORITY,
            name="bounded_management_discharge",
        ),
        [
            pump.Static(
                flow_rate=[0.0],
                max_flow_rate=[max_discharge_m3 / DAY],
                allocation_controlled=[True],
            )
        ],
    )
    sink = model.terminal.add(
        Node(5, Point(2.0, 0.0), subnetwork_id=2, name="management_terminal")
    )
    demand = model.level_demand.add(
        Node(
            6,
            Point(0.0, 1.0),
            subnetwork_id=2,
            route_priority=0,
            name="accepted_wlstar_band",
        ),
        [
            level_demand.Static(
                min_level=[LOWER_M],
                max_level=[UPPER_M],
                demand_priority=[1],
            )
        ],
    )

    model.link.add(source, supply)
    model.link.add(supply, store)
    model.link.add(store, discharge)
    model.link.add(discharge, sink)
    model.link.add(demand, store)
    return model


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_q2b1_real_ribasim.py <output-root>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    for case_id, initial_level, max_supply, max_discharge in CASES:
        case_dir = out / case_id
        case_dir.mkdir()
        path = case_dir / "ribasim.toml"
        build_model(initial_level, max_supply, max_discharge).write(path)
        print(
            "SW_RIB_SWM01_Q2B1_MODEL_GENERATED "
            f"case={case_id} initial_level_m={initial_level} "
            f"max_supply_m3={max_supply} max_discharge_m3={max_discharge} path={path}"
        )

    print("SW_RIB_SWM01_Q2B1_MODEL_GENERATION=PASS")


if __name__ == "__main__":
    main()
