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
ACCEPTED_LEVEL = 1.000007990372381


def build_model() -> Model:
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
        [flow_boundary.Static(flow_rate=[32.0 / DAY])],
    )
    store = model.basin.add(
        Node(2, Point(0.0, 0.0), subnetwork_id=2, name="accepted_t24_store"),
        [
            basin.Profile(level=[0.0, 2.0], area=[1_000_000.0, 1_000_000.0]),
            basin.State(level=[ACCEPTED_LEVEL]),
        ],
    )
    root = model.user_demand.add(
        Node(3, Point(1.0, 0.5), subnetwork_id=2, name="root"),
        [
            user_demand.Static(
                demand=[40.0 / DAY],
                return_factor=0.0,
                min_level=0.99,
                demand_priority=2,
            )
        ],
    )
    external = model.user_demand.add(
        Node(4, Point(1.0, -0.5), subnetwork_id=2, name="external"),
        [
            user_demand.Static(
                demand=[20.0 / DAY],
                return_factor=0.0,
                min_level=0.99,
                demand_priority=3,
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
        Node(7, Point(0.0, 1.0), subnetwork_id=2, name="forecast_hold"),
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


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_ribasim_dummy_20h6_next_boundary.py <output-dir>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    build_model().write(out / "ribasim.toml")
    print(f"Generated {out / 'ribasim.toml'}")


if __name__ == "__main__":
    main()
