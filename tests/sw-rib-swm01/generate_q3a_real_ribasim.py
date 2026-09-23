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
ZBOT_CM = -150.0
GWLINF_CM = -200.0
RDRAIN_DAY = 10.0
RINFI_DAY = 20.0

CASES = [
    ("X1_POSITIVE_DRAINAGE", -0.5, -40.0),
    ("X2_NEGATIVE_INFILTRATION_SUFFICIENT", -0.5, -60.0),
    ("X3_NEGATIVE_INFILTRATION_AVAILABILITY_LIMITED", -0.998, -110.0),
]


def swap_requested_exchange_cm_day(level_m: float, gwl_cm: float) -> float:
    wl_cm = 100.0 * level_m
    if not (wl_cm > ZBOT_CM + 0.001):
        raise RuntimeError("Q3A frozen route requires wet control head")
    effective = gwl_cm - wl_cm
    if effective > 0.0:
        return effective / RDRAIN_DAY
    return effective / RINFI_DAY


def build_model(initial_level_m: float, gwl_cm: float) -> tuple[Model, float]:
    q_cm_day = swap_requested_exchange_cm_day(initial_level_m, gwl_cm)
    transfer_m3_day = abs(q_cm_day) * 0.01 * AREA_M2

    start = datetime(2020, 1, 1)
    model = Model(
        starttime=start,
        endtime=start + timedelta(seconds=DAY),
        crs="EPSG:28992",
        solver=Solver(saveat=DAY),
    )

    kwargs = {}
    if q_cm_day > 0.0:
        kwargs["drainage"] = [transfer_m3_day / DAY]
    elif q_cm_day < 0.0:
        kwargs["infiltration"] = [transfer_m3_day / DAY]
    else:
        raise RuntimeError("Q3A does not use a zero-exchange case")

    model.basin.add(
        Node(1, Point(0.0, 0.0), name="ribasim_owned_surface_water"),
        [
            basin.Profile(level=[-1.0, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[initial_level_m]),
            basin.Static(**kwargs),
        ],
    )
    return model, q_cm_day


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_q3a_real_ribasim.py <output-root>")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    for case_id, initial_level, gwl_cm in CASES:
        model, q_cm_day = build_model(initial_level, gwl_cm)
        case_dir = out / case_id
        case_dir.mkdir()
        path = case_dir / "ribasim.toml"
        model.write(path)
        print(
            "SW_RIB_SWM01_Q3A_MODEL_GENERATED "
            f"case={case_id} initial_level_m={initial_level} gwl_cm={gwl_cm} "
            f"q_swap_cm_day={q_cm_day:.17g} path={path}"
        )

    print("SW_RIB_SWM01_Q3A_MODEL_GENERATION=PASS")


if __name__ == "__main__":
    main()
