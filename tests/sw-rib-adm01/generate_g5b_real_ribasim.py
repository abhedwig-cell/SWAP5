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

CASES = [
    ("E1_POSITIVE_DRAINAGE", -0.5, 0.01, "drainage"),
    ("E2_NEGATIVE_INFILTRATION_SUFFICIENT", -0.5, 0.005, "infiltration"),
    ("E3_NEGATIVE_INFILTRATION_LIMITED", -0.998, 0.0051, "infiltration"),
]


def build_model(initial_level_m: float, requested_m3: float, kind: str) -> Model:
    start = datetime(2020, 1, 1)
    model = Model(
        starttime=start,
        endtime=start + timedelta(seconds=DAY),
        crs="EPSG:28992",
        solver=Solver(saveat=DAY),
    )
    kwargs = {kind: [requested_m3 / DAY]}
    model.basin.add(
        Node(1, Point(0.0, 0.0), name="ribasim_owned_surface_water"),
        [
            basin.Profile(level=[-1.0, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[initial_level_m]),
            basin.Static(**kwargs),
        ],
    )
    return model


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_g5b_real_ribasim.py <output-root>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for case_id, initial_level, requested_m3, kind in CASES:
        case_dir = out / case_id
        case_dir.mkdir()
        path = case_dir / "ribasim.toml"
        build_model(initial_level, requested_m3, kind).write(path)
        print(
            f"SW_RIB_ADM01_G5B_MODEL_GENERATED case={case_id} "
            f"initial_level_m={initial_level} requested_m3={requested_m3} path={path}"
        )
    print("SW_RIB_ADM01_G5B_MODEL_GENERATION=PASS")


if __name__ == "__main__":
    main()
