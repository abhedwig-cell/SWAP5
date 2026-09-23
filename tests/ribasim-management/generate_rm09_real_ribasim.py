from __future__ import annotations

from datetime import datetime
from pathlib import Path
import shutil
import sys

from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, user_demand
from shapely.geometry import Point

DAY = 86400.0
AREA_M2 = 1000.0
SUPPLY_M3_PER_DAY = 25.0


def build_model(request_depth_cm: float) -> Model:
    demand_m3_per_day = request_depth_cm / 100.0 * AREA_M2
    model = Model(
        starttime=datetime(2020, 1, 1),
        endtime=datetime(2020, 1, 2),
        crs="EPSG:28992",
        allocation=Allocation(dt=DAY),
        solver=Solver(saveat=DAY),
        experimental=Experimental(allocation=True),
    )

    source = model.flow_boundary.add(
        Node(1, Point(-1.0, 0.0), subnetwork_id=2, name="rm09_supply"),
        [flow_boundary.Static(flow_rate=[SUPPLY_M3_PER_DAY / DAY])],
    )
    store = model.basin.add(
        Node(2, Point(0.0, 0.0), subnetwork_id=2, name="rm09_store"),
        [
            basin.Profile(level=[0.0, 2.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[1.0]),
        ],
    )
    demand = model.user_demand.add(
        Node(3, Point(1.0, 0.0), subnetwork_id=2, name="swap_irrigation"),
        [
            user_demand.Static(
                demand=[demand_m3_per_day / DAY],
                return_factor=0.0,
                min_level=0.90,
                demand_priority=2,
            )
        ],
    )
    sink = model.terminal.add(
        Node(4, Point(2.0, 0.0), subnetwork_id=2, name="irrigation_sink")
    )

    model.link.add(source, store)
    model.link.add(store, demand)
    model.link.add(demand, sink)
    return model


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: generate_rm09_real_ribasim.py <output-dir> <request-depth-cm>"
        )
    output = Path(sys.argv[1]).resolve()
    request_depth_cm = float(sys.argv[2])
    if not (request_depth_cm > 0.0):
        raise SystemExit("RM09 requires a positive SWAP management request")
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    model_path = output / "ribasim.toml"
    build_model(request_depth_cm).write(model_path)
    print(
        f"RM09_MODEL_GENERATED path={model_path} "
        f"request_depth_cm={request_depth_cm:.17g} area_m2={AREA_M2:.17g} "
        f"supply_m3_day={SUPPLY_M3_PER_DAY:.17g}"
    )


if __name__ == "__main__":
    main()
