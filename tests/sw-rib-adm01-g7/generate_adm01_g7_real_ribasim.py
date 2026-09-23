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

DURATION_SECONDS = 21600.0
AREA_M2 = 100.0

CASES = [
    ("E1_POSITIVE_DRAINAGE", -0.1225, -1.0, 0.0025, "drainage"),
    ("E2_NEGATIVE_INFILTRATION_SUFFICIENT", 0.0775, -1.0, 0.0025, "infiltration"),
    ("E3_NEGATIVE_INFILTRATION_LIMITED", 0.0775, 0.0675, 0.0025, "infiltration"),
]


def build_model(initial_level: float, bottom: float, requested_m3: float, kind: str) -> Model:
    start = datetime(2020, 1, 1)
    model = Model(
        starttime=start,
        endtime=start + timedelta(seconds=DURATION_SECONDS),
        crs="EPSG:28992",
        solver=Solver(saveat=DURATION_SECONDS),
    )
    kwargs = {kind: [requested_m3 / DURATION_SECONDS]}
    model.basin.add(
        Node(1, Point(0.0, 0.0), name="ribasim_owned_surface_water"),
        [
            basin.Profile(level=[bottom, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[initial_level]),
            basin.Static(**kwargs),
        ],
    )
    return model


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_adm01_g7_real_ribasim.py <output-root>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    for case_id, initial, bottom, request, kind in CASES:
        case_dir = out / case_id
        case_dir.mkdir()
        path = case_dir / "ribasim.toml"
        build_model(initial, bottom, request, kind).write(path)
        print(
            "SW_RIB_ADM01_G7_MODEL_GENERATED "
            f"case={case_id} initial_level_m={initial} bottom_m={bottom} "
            f"requested_m3={request} forcing={kind} path={path}"
        )
    print("SW_RIB_ADM01_G7_MODEL_GENERATION=PASS")


if __name__ == "__main__":
    main()
