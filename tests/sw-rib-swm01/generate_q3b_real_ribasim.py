from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import shutil
import sys

from ribasim import Model
from ribasim.config import Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, pump
from shapely.geometry import Point

DAY = 86400.0
AREA_M2 = 1.0

CASES = [
    ("T1_INCOMING_SPLIT", -0.5, 0.005, 0.004, 0.0, 0.0),
    ("T2_OUTGOING_SPLIT", -0.5, 0.0, 0.0, 0.004, 0.003),
    ("T3_MIXED_IDENTITIES", -0.5, 0.005, 0.002, 0.003, 0.001),
    ("T4_TOP_INUNDATION_AVAILABILITY_LIMITED", -0.998, 0.0, 0.0, 0.0, 0.0051),
]

def build_model(initial_level, drainage_m3, runoff_m3, infiltration_m3, top_out_m3):
    start = datetime(2020, 1, 1)
    model = Model(
        starttime=start,
        endtime=start + timedelta(seconds=DAY),
        crs="EPSG:28992",
        solver=Solver(saveat=DAY),
    )
    store = model.basin.add(
        Node(1, Point(0.0, 0.0), name="ribasim_owned_surface_water"),
        [
            basin.Profile(level=[-1.0, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[initial_level]),
            basin.Static(
                drainage=[drainage_m3 / DAY],
                surface_runoff=[runoff_m3 / DAY],
                infiltration=[infiltration_m3 / DAY],
            ),
        ],
    )
    top = model.pump.add(
        Node(2, Point(1.0, 0.0), name="swap_top_inundation_transfer"),
        [pump.Static(flow_rate=[top_out_m3 / DAY], min_flow_rate=[0.0])],
    )
    sink = model.terminal.add(Node(3, Point(2.0, 0.0), name="swap_top_boundary_sink"))
    model.link.add(store, top)
    model.link.add(top, sink)
    return model

def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_q3b_real_ribasim.py <output-root>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    for case in CASES:
        case_id, initial_level, drainage, runoff, infiltration, top_out = case
        case_dir = out / case_id
        case_dir.mkdir()
        path = case_dir / "ribasim.toml"
        build_model(initial_level, drainage, runoff, infiltration, top_out).write(path)
        print(
            "SW_RIB_SWM01_Q3B_MODEL_GENERATED "
            f"case={case_id} initial_level_m={initial_level} drainage_m3={drainage} "
            f"surface_runoff_m3={runoff} infiltration_m3={infiltration} "
            f"top_inundation_request_m3={top_out} path={path}"
        )
    print("SW_RIB_SWM01_Q3B_MODEL_GENERATION=PASS")

if __name__ == "__main__":
    main()
