#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd
import tomli
import tomli_w
import xarray as xr
from shapely.geometry import Point

import imod
from imod import mf6
from imod_coupler.config import BaseConfig
from imod_coupler.drivers.driver import get_driver
from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, level_demand, user_demand

DAY = 86400.0
ENDPOINTS_S = [21600.0, 43200.0, 64800.0, 86400.0]
TIME_TOL = 1.0e-6

CASES = {
    "A24_S24": (86400.0, 86400.0),
    "A24_S1": (86400.0, 3600.0),
    "A6_S24": (21600.0, 86400.0),
    "A6_S1": (21600.0, 3600.0),
}


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


def build_modflow() -> imod.mf6.Modflow6Simulation:
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
    gwf["sto"] = mf6.SpecificStorage(1.0e-5, 0.1, True, 0)
    head = xr.full_like(idomain, 0.5, dtype=np.float64)
    gwf["chd"] = mf6.ConstantHead(head=head, print_input=False, print_flows=False, save_flows=True)
    gwf["oc"] = mf6.OutputControl(save_head="last", save_budget="last")

    simulation = mf6.Modflow6Simulation("clock_only")
    simulation["GWF_1"] = gwf
    simulation["solver"] = mf6.Solution(
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
    simulation.create_time_discretization(
        additional_times=pd.date_range("2020-01-01", "2020-01-02", freq="6h")
    )
    return simulation


def write_case(
    root: Path,
    allocation_dt: float,
    saveat: float,
    modflow_dll: Path,
    ribasim_dll: Path,
    ribasim_dep: Path,
) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    build_modflow().write(root / "modflow6")
    build_ribasim(allocation_dt, saveat).write(root / "ribasim" / "ribasim.toml")
    config = {
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
        tomli_w.dump(config, f)
    return path


def observe(driver) -> dict[str, float]:
    level = float(driver.ribasim.get_value_ptr("basin.level")[0])
    cumulative = np.asarray(
        driver.ribasim.get_value_ptr("user_demand.cumulative_inflow"), dtype=float
    )
    require(cumulative.size == 2, "expected two UserDemand cumulative values")
    return {
        "level_m": level,
        "root_cumulative_m3": float(cumulative[0]),
        "external_cumulative_m3": float(cumulative[1]),
        "total_cumulative_m3": float(cumulative.sum()),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CASES), required=True)
    parser.add_argument("--work-root", required=True)
    parser.add_argument("--modflow-dll", required=True)
    parser.add_argument("--ribasim-dll", required=True)
    parser.add_argument("--ribasim-dep", required=True)
    parser.add_argument("--result-json", required=True)
    args = parser.parse_args()

    allocation_dt, saveat = CASES[args.case]
    work_root = Path(args.work_root).resolve()
    modflow_dll = Path(args.modflow_dll).resolve()
    ribasim_dll = Path(args.ribasim_dll).resolve()
    ribasim_dep = Path(args.ribasim_dep).resolve()
    require(modflow_dll.is_file(), f"MODFLOW DLL missing: {modflow_dll}")
    require(ribasim_dll.is_file(), f"Ribasim DLL missing: {ribasim_dll}")
    require(ribasim_dep.is_dir(), f"Ribasim dependency directory missing: {ribasim_dep}")

    config_path = write_case(
        work_root, allocation_dt, saveat, modflow_dll, ribasim_dll, ribasim_dep
    )
    with config_path.open("rb") as f:
        config_dict = tomli.load(f)
    base_config = BaseConfig(**config_dict)
    driver = get_driver(config_dict, config_path.parent, base_config)
    require(type(driver).__name__ == "RibaMod", "get_driver did not return RibaMod")
    require(
        type(driver).__module__ == "imod_coupler.drivers.ribamod.ribamod",
        "RibaMod did not originate from upstream product module",
    )

    states = []
    original_cwd = Path.cwd()
    try:
        driver.initialize()
        try:
            for endpoint in ENDPOINTS_S:
                driver.update()
                mf6_s = float(driver.mf6.get_current_time()) * DAY
                ribasim_s = float(driver.ribasim.get_current_time())
                require(abs(mf6_s - endpoint) <= TIME_TOL, f"MF6 time mismatch at {endpoint}")
                require(abs(ribasim_s - endpoint) <= TIME_TOL, f"Ribasim time mismatch at {endpoint}")
                state = observe(driver)
                state.update({"endpoint_s": endpoint, "mf6_s": mf6_s, "ribasim_s": ribasim_s})
                states.append(state)
                print(
                    "RIBASIM_REAL_20D_CASE_STATE "
                    f"case={args.case} endpoint_s={endpoint} "
                    f"level={state['level_m']} root_m3={state['root_cumulative_m3']} "
                    f"external_m3={state['external_cumulative_m3']} total_m3={state['total_cumulative_m3']}"
                )
        finally:
            driver.finalize()
    finally:
        os.chdir(original_cwd)

    payload = {
        "case": args.case,
        "allocation_dt_seconds": allocation_dt,
        "solver_saveat_seconds": saveat,
        "states": states,
    }
    result_path = Path(args.result_json).resolve()
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"RIBASIM_REAL_20D_CASE=PASS case={args.case}")


if __name__ == "__main__":
    main()
