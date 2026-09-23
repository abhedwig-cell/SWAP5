from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import shutil
import sys

from ribasim import Model
from ribasim.config import Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin
from shapely.geometry import Point

DAY = 86400.0
AREA_M2 = 1.0
INFILTRATION_REQUEST_M3 = 0.0051

CASES = [
    ("C0_NO_POSITIVE_DRAINAGE", -0.998, 0.0),
    ("C1_ONE_MM_POSITIVE_DRAINAGE", -0.998, 0.001),
    ("C2_TEN_MM_POSITIVE_DRAINAGE", -0.998, 0.01),
]

def build_model(initial_level_m: float, drainage_m3: float) -> Model:
    start = datetime(2020, 1, 1)
    model = Model(
        starttime=start,
        endtime=start + timedelta(seconds=DAY),
        crs="EPSG:28992",
        solver=Solver(saveat=DAY),
    )
    model.basin.add(
        Node(1, Point(0.0, 0.0), name="ribasim_owned_surface_water"),
        [
            basin.Profile(level=[-1.0, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[initial_level_m]),
            basin.Static(
                drainage=[drainage_m3 / DAY],
                infiltration=[INFILTRATION_REQUEST_M3 / DAY],
            ),
        ],
    )
    return model

def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_q3c_real_ribasim.py <output-root>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for case_id, initial_level, drainage in CASES:
        case_dir = out / case_id
        case_dir.mkdir()
        path = case_dir / "ribasim.toml"
        build_model(initial_level, drainage).write(path)
        print(
            "SW_RIB_SWM01_Q3C_MODEL_GENERATED "
            f"case={case_id} initial_level_m={initial_level} "
            f"positive_drainage_m3={drainage} "
            f"infiltration_request_m3={INFILTRATION_REQUEST_M3} path={path}"
        )
    print("SW_RIB_SWM01_Q3C_MODEL_GENERATION=PASS")

if __name__ == "__main__":
    main()
