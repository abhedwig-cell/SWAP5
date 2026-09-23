from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import shutil
import sys

from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, user_demand
from shapely.geometry import Point

WINDOW_S = 8.64
AREA_M2 = 1.0
REQUEST_DEPTH_CM = 0.0036
DEMAND_M3_PER_DAY = 0.36
DAY_S = 86400.0


def build_model() -> Model:
    start = datetime(2020, 1, 1)
    end = start + timedelta(seconds=WINDOW_S)
    model = Model(
        starttime=start,
        endtime=end,
        crs="EPSG:28992",
        allocation=Allocation(dt=WINDOW_S),
        solver=Solver(saveat=float("inf")),
        experimental=Experimental(allocation=True),
    )
    source = model.flow_boundary.add(
        Node(1, Point(-1.0, 0.0), subnetwork_id=2, name="rm13_surface_supply"),
        [flow_boundary.Static(flow_rate=[DEMAND_M3_PER_DAY / DAY_S])],
    )
    store = model.basin.add(
        Node(2, Point(0.0, 0.0), subnetwork_id=2, name="rm13_surface_store"),
        [
            basin.Profile(level=[0.0, 2.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[1.0]),
        ],
    )
    demand = model.user_demand.add(
        Node(3, Point(1.0, 0.0), subnetwork_id=2, name="swap_irrigation"),
        [
            user_demand.Static(
                demand=[DEMAND_M3_PER_DAY / DAY_S],
                return_factor=0.0,
                min_level=0.9,
                demand_priority=2,
            )
        ],
    )
    sink = model.terminal.add(Node(4, Point(2.0, 0.0), subnetwork_id=2, name="irrigation_sink"))
    model.link.add(source, store)
    model.link.add(store, demand)
    model.link.add(demand, sink)
    return model


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_rm13_real_ribasim.py <output-dir>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    path = out / "ribasim.toml"
    build_model().write(path)
    expected_volume = REQUEST_DEPTH_CM / 100.0 * AREA_M2
    print(
        f"RM13B_MODEL_GENERATED path={path} window_s={WINDOW_S:.17g} "
        f"request_depth_cm={REQUEST_DEPTH_CM:.17g} expected_volume_m3={expected_volume:.17g}"
    )


if __name__ == "__main__":
    main()
