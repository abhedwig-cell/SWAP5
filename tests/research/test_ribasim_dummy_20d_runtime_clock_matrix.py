#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd
import tomli
import tomli_w
import xarray as xr
from shapely.geometry import Point

from imod import mf6
from imod_coupler.config import BaseConfig
from imod_coupler.drivers.driver import get_driver
from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, level_demand, user_demand

DAY = 86400.0
ENDPOINTS_S = [21600.0, 43200.0, 64800.0, 86400.0]
VOLUME_TOL = 0.05
LEVEL_TOL = 5.0e-8
PAIR_VOLUME_TOL = 0.05
PAIR_LEVEL_TOL = 5.0e-8
MIN_FINAL_SEPARATION = 5.0
TIME_TOL = 1.0e-6

CASES = {
    "A24_S24": (86400.0, 86400.0),
    "A24_S1": (86400.0, 3600.0),
    "A6_S24": (21600.0, 86400.0),
    "A6_S1": (21600.0, 3600.0),
}

REF_24_ROOT = [
    4.001199759954048,
    8.00479808014741,
    12.010793520398778,
    16.019184640970934,
]
REF_24_EXT = [0.0, 0.0, 0.0, 0.0]
REF_24_TOTAL = [
    4.001199759954048,
    8.00479808014741,
    12.010793520398778,
    16.019184640970934,
]
REF_24_FINAL_LEVEL = 1.000015980815359

REF_6_ROOT = [
    4.001199760004028,
    9.004947510764467,
    14.009817152853525,
    19.01524636786452,
]
REF_6_EXT = [
    0.0,
    1.0001492206460414,
    2.9995462301238116,
    5.497574062835911,
]
REF_6_TOTAL = [
    4.001199760004028,
    10.005096731410507,
    17.009363382977337,
    24.51282043070043,
]
REF_6_FINAL_LEVEL = 1.0000074871795686


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def build_ribasim(allocation_dt: float, saveat: float) -> Model:
    model = Model(
        starttime=datetime(2020, 1, 1),
        endtime=datetime(2020, 1, 2),
        crs="EPSG:28992",
        allocation=Allocation(dt=allocation_dt),
        solver=Solver(saveat=saveat),
        experimental=Experimental(allocation=True),
    )
    source = model.flow_boundary.add(
        Node(1, Point(-1.0, 0.0), subnetwork_id=2, name="fixed_32_m3_day"),
        [flow_boundary.Static(flow_rate=[32.0 / DAY])],
    )
    store = model.basin.add(
        Node(2, Point(0.0, 0.0), subnetwork_id=2, name="store"),
        [
            basin.Profile(level=[0.0, 2.0], area=[1_000_000.0, 1_000_000.0]),
            basin.State(level=[1.0]),
            basin.Subgrid(
                subgrid_id=[1, 1],
                basin_level=[0.0, 2.0],
                subgrid_level=[0.0, 2.0],
            ),
        ],
    )
    root = model.user_demand.add(
        Node(3, Point(1.0, 0.5), subnetwork_id=2, name="root"),
        [user_demand.Static(
            demand=[40.0 / DAY],
            return_factor=0.0,
            min_level=0.99,
            demand_priority=2,
        )],
    )
    external = model.user_demand.add(
        Node(4, Point(1.0, -0.5), subnetwork_id=2, name="external"),
        [user_demand.Static(
            demand=[20.0 / DAY],
            return_factor=0.0,
            min_level=0.99,
            demand_priority=3,
        )],
    )
    root_sink = model.terminal.add(Node(5, Point(2.0, 0.5), subnetwork_id=2))
    external_sink = model.terminal.add(Node(6, Point(2.0, -0.5), subnetwork_id=2))
    hold = model.level_demand.add(
        Node(7, Point(0.0, 1.0), subnetwork_id=2, name="forecast_hold"),
        [level_demand.Static(min_level=[1.0], max_level=[1.0], demand_priority=1)],
    )

    model.link.add(source, store)
    model.link.add(store, root)
    model.link.add(root, root_sink)
    model.link.add(store, external)
    model.link.add(external, external_sink)
    model.link.add(hold, store)
    return model


def build_modflow() -> mf6.Modflow6Simulation:
    idomain = xr.DataArray(
        np.ones((1, 1, 1), dtype=np.int32),
        dims=("layer", "y", "x"),
        coords={"layer": [1], "y": [0.0], "x": [0.0]},
    )
    bottom = xr.DataArray([0.0], dims=("layer",), coords={"layer": [1]})
    gwf = mf6.GroundwaterFlowModel()
    gwf["dis"] = mf6.StructuredDiscretization(idomain=idomain, top=1.0, bottom=bottom)
    gwf["npf"] = mf6.NodePropertyFlow(icelltype=0, k=1.0, k33=1.0, save_flows=True)
    gwf["ic"] = mf6.InitialConditions(start=0.5)
    gwf["sto"] = mf6.SpecificStorage(
        specific_storage=1.0e-3,
        specific_yield=0.1,
        transient=True,
        convertible=0,
    )
    head = xr.full_like(idomain, 0.5, dtype=np.float64)
    gwf["chd"] = mf6.ConstantHead(head=head, save_flows=True)
    gwf["oc"] = mf6.OutputControl(save_head="last", save_budget="last")

    sim = mf6.Modflow6Simulation("clock_matrix")
    sim["GWF_1"] = gwf
    sim["solver"] = mf6.Solution(
        modelnames=["GWF_1"],
        print_option="summary",
        outer_dvclose=1.0e-8,
        outer_maximum=50,
        under_relaxation=None,
        inner_dvclose=1.0e-8,
        inner_rclose=1.0e-6,
        inner_maximum=50,
        linear_acceleration="cg",
        scaling_method=None,
        reordering_method=None,
        relaxation_factor=0.97,
    )
    times = pd.date_range("2020-01-01", "2020-01-02", freq="6h")
    sim.create_time_discretization(additional_times=times)
    return sim


def write_case(root: Path, allocation_dt: float, saveat: float, modflow_dll: Path, ribasim_dll: Path, ribasim_dep: Path) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    build_modflow().write(root / "modflow6")
    build_ribasim(allocation_dt, saveat).write(root / "ribasim" / "ribasim.toml")

    cfg = {
        "timing": False,
        "log_level": "INFO",
        "driver_type": "ribamod",
        "driver": {
            "kernels": {
                "modflow6": {"dll": str(modflow_dll), "work_dir": "modflow6"},
                "ribasim": {
                    "dll": str(ribasim_dll),
                    "dll_dep_dir": str(ribasim_dep),
                    "config_file": "ribasim/ribasim.toml",
                },
            },
            "coupling": [{
                "mf6_model": "GWF_1",
                "mf6_active_river_packages": {},
                "mf6_active_drainage_packages": {},
                "mf6_passive_river_packages": {},
                "mf6_passive_drainage_packages": {},
            }],
        },
    }
    path = root / "imod_coupler.toml"
    with path.open("wb") as f:
        tomli_w.dump(cfg, f)
    return path


def observe(driver) -> dict[str, float]:
    cumulative = np.asarray(driver.ribasim.get_value_ptr("user_demand.cumulative_inflow"), dtype=float)
    require(cumulative.size == 2, f"expected two UserDemand values, got {cumulative.size}")
    return {
        "level": float(driver.ribasim.get_value_ptr("basin.level")[0]),
        "root": float(cumulative[0]),
        "external": float(cumulative[1]),
        "total": float(cumulative.sum()),
    }


def run_single(args: argparse.Namespace) -> None:
    case_id = args.single_case
    allocation_dt, saveat = CASES[case_id]
    root = Path(args.work_root).resolve() / case_id
    config_path = write_case(
        root,
        allocation_dt,
        saveat,
        Path(args.modflow_dll).resolve(),
        Path(args.ribasim_dll).resolve(),
        Path(args.ribasim_dep).resolve(),
    )
    with config_path.open("rb") as f:
        cfg = tomli.load(f)
    config_dir = config_path.parent
    base = BaseConfig(**cfg)
    driver = get_driver(cfg, config_dir, base)
    require(type(driver).__name__ == "RibaMod", "upstream get_driver did not select RibaMod")

    states: list[dict[str, float]] = []
    driver.initialize()
    try:
        for endpoint in ENDPOINTS_S:
            driver.update()
            mf6_s = float(driver.mf6.get_current_time()) * DAY
            rib_s = float(driver.ribasim.get_current_time())
            require(abs(mf6_s - endpoint) <= TIME_TOL, f"{case_id} MF6 time mismatch")
            require(abs(rib_s - endpoint) <= TIME_TOL, f"{case_id} Ribasim time mismatch")
            state = observe(driver)
            state["endpoint_s"] = endpoint
            states.append(state)
            print(
                "RIBASIM_REAL_20D_CASE "
                f"case={case_id} endpoint_s={endpoint} allocation_dt_s={allocation_dt} saveat_s={saveat} "
                f"root_m3={state['root']} external_m3={state['external']} total_m3={state['total']} level={state['level']}"
            )
    finally:
        driver.finalize()

    result_path = Path(args.work_root).resolve() / f"{case_id}.json"
    result_path.write_text(json.dumps(states, indent=2), encoding="utf-8")


def compare_reference(case_id: str, states: list[dict[str, float]]) -> None:
    if case_id.startswith("A24"):
        root_ref, ext_ref, total_ref, final_level = REF_24_ROOT, REF_24_EXT, REF_24_TOTAL, REF_24_FINAL_LEVEL
    else:
        root_ref, ext_ref, total_ref, final_level = REF_6_ROOT, REF_6_EXT, REF_6_TOTAL, REF_6_FINAL_LEVEL

    require(len(states) == 4, f"{case_id} trajectory length mismatch")
    for i, state in enumerate(states):
        require(abs(state["root"] - root_ref[i]) <= VOLUME_TOL, f"{case_id} root reference mismatch at endpoint {i}")
        require(abs(state["external"] - ext_ref[i]) <= VOLUME_TOL, f"{case_id} external reference mismatch at endpoint {i}")
        require(abs(state["total"] - total_ref[i]) <= VOLUME_TOL, f"{case_id} total reference mismatch at endpoint {i}")
    require(abs(states[-1]["level"] - final_level) <= LEVEL_TOL, f"{case_id} final level mismatch")


def compare_pair(a_id: str, b_id: str, results: dict[str, list[dict[str, float]]]) -> None:
    a, b = results[a_id], results[b_id]
    for i, endpoint in enumerate(ENDPOINTS_S):
        for key in ("root", "external", "total"):
            require(abs(a[i][key] - b[i][key]) <= PAIR_VOLUME_TOL, f"{a_id}/{b_id} {key} saveat mismatch at {endpoint}")
        require(abs(a[i]["level"] - b[i]["level"]) <= PAIR_LEVEL_TOL, f"{a_id}/{b_id} level saveat mismatch at {endpoint}")
        print(
            "RIBASIM_REAL_20D_SAVEAT_EQUIV "
            f"pair={a_id}:{b_id} endpoint_s={endpoint} "
            f"total_diff_m3={a[i]['total']-b[i]['total']} level_diff_m={a[i]['level']-b[i]['level']}"
        )


def run_parent(args: argparse.Namespace) -> None:
    work_root = Path(args.work_root).resolve()
    work_root.mkdir(parents=True, exist_ok=True)

    for case_id in CASES:
        cmd = [
            sys.executable,
            str(Path(__file__).resolve()),
            "--single-case", case_id,
            "--work-root", str(work_root),
            "--modflow-dll", str(Path(args.modflow_dll).resolve()),
            "--ribasim-dll", str(Path(args.ribasim_dll).resolve()),
            "--ribasim-dep", str(Path(args.ribasim_dep).resolve()),
        ]
        subprocess.run(cmd, check=True)

    results = {
        case_id: json.loads((work_root / f"{case_id}.json").read_text(encoding="utf-8"))
        for case_id in CASES
    }

    for case_id, states in results.items():
        compare_reference(case_id, states)

    compare_pair("A24_S24", "A24_S1", results)
    compare_pair("A6_S24", "A6_S1", results)

    final_24 = results["A24_S24"][-1]["total"]
    final_6 = results["A6_S24"][-1]["total"]
    require(final_6 - final_24 > MIN_FINAL_SEPARATION, "allocation.dt classes are not materially separated")
    print(f"RIBASIM_REAL_20D_ALLOCATION_DT_SEPARATION_M3={final_6-final_24}")
    print("RIBASIM_REAL_20D_RUNTIME_CLOCK_OWNERSHIP_MATRIX=PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--single-case", choices=CASES)
    parser.add_argument("--work-root", required=True)
    parser.add_argument("--modflow-dll", required=True)
    parser.add_argument("--ribasim-dll", required=True)
    parser.add_argument("--ribasim-dep", required=True)
    args = parser.parse_args()

    if args.single_case:
        run_single(args)
    else:
        run_parent(args)


if __name__ == "__main__":
    main()
