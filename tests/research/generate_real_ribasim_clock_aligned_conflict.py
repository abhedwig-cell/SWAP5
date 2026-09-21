from __future__ import annotations

from datetime import datetime
from pathlib import Path
import shutil
import sys

from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, level_demand, user_demand
from shapely.geometry import Point

DAY = 86400.0
SUPPLY = 32.0 / DAY
ROOT_DEMAND = 40.0 / DAY
EXTERNAL_DEMAND = 20.0 / DAY
AREA = 1_000_000.0
MIN_LEVEL = 0.99


def build_model(*, root_priority: int, external_priority: int) -> Model:
    model = Model(
        starttime=datetime(2020, 1, 1),
        endtime=datetime(2020, 1, 2),
        crs="EPSG:28992",
        allocation=Allocation(dt=DAY),
        solver=Solver(saveat=DAY),
        experimental=Experimental(allocation=True),
    )

    source = model.flow_boundary.add(
        Node(1, Point(-1.0, 0.0), subnetwork_id=2, name="fixed_32_m3_day"),
        [flow_boundary.Static(flow_rate=[SUPPLY])],
    )
    store = model.basin.add(
        Node(2, Point(0.0, 0.0), subnetwork_id=2, name="large_surface_store"),
        [
            basin.Profile(level=[0.0, 2.0], area=AREA),
            basin.State(level=[1.0]),
        ],
    )
    root = model.user_demand.add(
        Node(3, Point(1.0, 0.5), subnetwork_id=2, name="root_proxy"),
        [
            user_demand.Static(
                demand=[ROOT_DEMAND],
                return_factor=0.0,
                min_level=MIN_LEVEL,
                demand_priority=root_priority,
            )
        ],
    )
    external = model.user_demand.add(
        Node(4, Point(1.0, -0.5), subnetwork_id=2, name="external_demand"),
        [
            user_demand.Static(
                demand=[EXTERNAL_DEMAND],
                return_factor=0.0,
                min_level=MIN_LEVEL,
                demand_priority=external_priority,
            )
        ],
    )
    root_sink = model.terminal.add(
        Node(5, Point(2.0, 0.5), subnetwork_id=2, name="root_sink")
    )
    external_sink = model.terminal.add(
        Node(6, Point(2.0, -0.5), subnetwork_id=2, name="external_sink")
    )
    hold = model.level_demand.add(
        Node(7, Point(0.0, 1.0), subnetwork_id=2, name="forecast_hold_surface_level"),
        [
            level_demand.Static(
                min_level=[1.0],
                max_level=[1.0],
                demand_priority=1,
            )
        ],
    )

    model.link.add(source, store)
    model.link.add(store, root)
    model.link.add(root, root_sink)
    model.link.add(store, external)
    model.link.add(external, external_sink)
    model.link.add(hold, store)

    return model


def write_case(output_root: Path, name: str, root_priority: int, external_priority: int) -> None:
    path = output_root / name
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)
    build_model(
        root_priority=root_priority,
        external_priority=external_priority,
    ).write(path / "ribasim.toml")
    print(f"Generated {name}")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_real_ribasim_clock_aligned_conflict.py <output-root>")
    output_root = Path(sys.argv[1]).resolve()
    output_root.mkdir(parents=True, exist_ok=True)

    write_case(output_root, "swap5_clock_aligned_root_first", 2, 3)
    write_case(output_root, "swap5_clock_aligned_external_first", 3, 2)


if __name__ == "__main__":
    main()
