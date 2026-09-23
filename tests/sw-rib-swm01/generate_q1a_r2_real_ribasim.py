from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import csv
import shutil
import sys

from ribasim import Model
from ribasim.config import Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, tabulated_rating_curve
from shapely.geometry import Point

DURATION_SECONDS = 8.64
DAY = 86400.0
AREA_M2 = 1.0
RATING_TOP_M3_PER_DAY = 0.5


def read_oracle(path: Path):
    rows = []
    with path.open(newline="") as f:
        for row in csv.reader(f):
            if not row or row[0] != "Q1A_CASE":
                continue
            if len(row) != 9:
                raise RuntimeError(f"unexpected oracle row: {row}")
            rows.append(
                {
                    "id": row[1],
                    "initial_storage_cm": float(row[2]),
                    "initial_level_cm": float(row[3]),
                    "drainage_cm_day": float(row[4]),
                    "final_storage_cm": float(row[5]),
                    "final_level_cm": float(row[6]),
                    "discharge_cm_day": float(row[7]),
                    "mass_residual_cm": float(row[8]),
                }
            )
    if [r["id"] for r in rows] != [
        "C0_NO_DISCHARGE",
        "C1_MODERATE_DISCHARGE",
        "C2_HIGH_DISCHARGE",
    ]:
        raise RuntimeError(f"unexpected case set: {[r['id'] for r in rows]}")
    return rows


def build_model(case) -> Model:
    start = datetime(2020, 1, 1)
    model = Model(
        starttime=start,
        endtime=start + timedelta(seconds=DURATION_SECONDS),
        crs="EPSG:28992",
        solver=Solver(saveat=1),
    )

    source = model.flow_boundary.add(
        Node(1, Point(-1.0, 0.0), name="swap_positive_drainage"),
        [
            flow_boundary.Static(
                flow_rate=[case["drainage_cm_day"] * 0.01 * AREA_M2 / DAY]
            )
        ],
    )
    store = model.basin.add(
        Node(2, Point(0.0, 0.0), name="externally_owned_surface_water"),
        [
            basin.Profile(level=[-1.0, 1.0], area=[AREA_M2, AREA_M2]),
            basin.State(level=[case["initial_level_cm"] / 100.0]),
        ],
    )

    # R2 mapping: two points exactly encode the linear above-crest law under
    # Ribasim PCHIP interpolation. Ribasim documents Q=0 below the lowest level.
    weir = model.tabulated_rating_curve.add(
        Node(3, Point(1.0, 0.0), name="linear_fixed_weir"),
        [
            tabulated_rating_curve.Static(
                level=[0.0, 1.0],
                flow_rate=[0.0, RATING_TOP_M3_PER_DAY / DAY],
            )
        ],
    )
    sink = model.terminal.add(Node(4, Point(2.0, 0.0), name="terminal"))

    model.link.add(source, store)
    model.link.add(store, weir)
    model.link.add(weir, sink)
    return model


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: generate_q1a_r2_real_ribasim.py <oracle.csv> <output-root>"
        )
    oracle = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve()
    rows = read_oracle(oracle)

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    for case in rows:
        case_dir = out / case["id"]
        case_dir.mkdir()
        model_path = case_dir / "ribasim.toml"
        build_model(case).write(model_path)
        print(f"SW_RIB_SWM01_Q1A_R2_MODEL_GENERATED case={case['id']} path={model_path}")

    print("SW_RIB_SWM01_Q1A_R2_MODEL_GENERATION=PASS")


if __name__ == "__main__":
    main()
