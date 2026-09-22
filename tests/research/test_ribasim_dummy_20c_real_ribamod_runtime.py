#!/usr/bin/env python3
from __future__ import annotations

import argparse
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
from imod_coupler.kernelwrappers.ribasim_wrapper import RibasimWrapper
from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, level_demand, user_demand

DAY = 86400.0
ENDPOINTS_S = [21600.0, 43200.0, 64800.0, 86400.0]
ROUTE_VOLUME_TOL = 0.05
ROUTE_LEVEL_TOL = 5.0e-8
ZERO_EXTERNAL_TOL = 0.001
TIME_TOL = 1.0e-6


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def build_ribasim() -> Model:
    model = Model(
        starttime=datetime(2020, 1, 1),
        endtime=datetime(2020, 1, 2),
        crs="EPSG:28992",
        allocation=Allocation(dt=DAY),
        solver=Solver(saveat=DAY),
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
    root_sink = model.terminal.add(
        Node(5, Point(2.0, 0.5), subnetwork_id=2, name="root_sink")
    )
    external_sink = model.terminal.add(
        Node(6, Point(2.0, -0.5), subnetwork_id=2, name="external_sink")
    )
    hold = model.level_demand.add(
        Node(7, Point(0.0, 1.0), subnetwork_id=2, name="forecast_hold"),
        [
            level_demand.Static(
                min_level=[1.0],
                max_level=[1.0],
                demand_priority=1,
            )
        ],
    )

    model.link.add(source, store)
    model.link.add(store, root)
    model.link.add(root, root_sink)
    model.link.add(store, external)
    model.link.add(external, external_sink)
    model.link.add(hold, store)
    return model


def build_modflow() -> imod.mf6.Modflow6Simulation:
    layer = [1]
    y = [0.0]
    x = [0.0]
    idomain = xr.DataArray(
        np.ones((1, 1, 1), dtype=np.int32),
        dims=("layer", "y", "x"),
        coords={"layer": layer, "y": y, "x": x},
    )
    bottom = xr.DataArray([0.0], dims=("layer",), coords={"layer": layer})

    gwf = mf6.GroundwaterFlowModel()
    gwf["dis"] = mf6.StructuredDiscretization(
        idomain=idomain,
        top=1.0,
        bottom=bottom,
    )
    gwf["npf"] = mf6.NodePropertyFlow(
        icelltype=0,
        k=1.0,
        k33=1.0,
        save_flows=True,
    )
    gwf["ic"] = mf6.InitialConditions(start=0.5)
    gwf["sto"] = mf6.SpecificStorage(
        specific_storage=1.0e-3,
        specific_yield=0.1,
        transient=True,
        convertible=0,
    )
    head = xr.full_like(idomain, 0.5, dtype=np.float64)
    gwf["chd"] = mf6.ConstantHead(
        head=head,
        print_input=False,
        print_flows=False,
        save_flows=True,
    )
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
    times = pd.date_range("2020-01-01", "2020-01-02", freq="6h")
    simulation.create_time_discretization(additional_times=times)
    return simulation


def write_product_case(
    root: Path,
    modflow_dll: Path,
    ribasim_dll: Path,
    ribasim_dep: Path,
) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    mf6_dir = root / "modflow6"
    rib_dir = root / "ribasim"
    build_modflow().write(mf6_dir)
    build_ribasim().write(rib_dir / "ribasim.toml")

    config = {
        "timing": False,
        "log_level": "INFO",
        "driver_type": "ribamod",
        "driver": {
            "kernels": {
                "modflow6": {
                    "dll": str(modflow_dll),
                    "work_dir": "modflow6",
                },
                "ribasim": {
                    "dll": str(ribasim_dll),
                    "dll_dep_dir": str(ribasim_dep),
                    "config_file": "ribasim/ribasim.toml",
                },
            },
            "coupling": [
                {
                    "mf6_model": "GWF_1",
                    "mf6_active_river_packages": {},
                    "mf6_active_drainage_packages": {},
                    "mf6_passive_river_packages": {},
                    "mf6_passive_drainage_packages": {},
                }
            ],
        },
    }
    config_path = root / "imod_coupler.toml"
    with config_path.open("wb") as f:
        tomli_w.dump(config, f)
    return config_path


def write_direct_case(root: Path) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    path = root / "ribasim.toml"
    build_ribasim().write(path)
    return path


def observe_ribasim(wrapper) -> tuple[float, float, float]:
    level = float(wrapper.get_value_ptr("basin.level")[0])
    cumulative = np.asarray(
        wrapper.get_value_ptr("user_demand.cumulative_inflow"),
        dtype=float,
    )
    require(cumulative.size == 2, f"expected two UserDemand cumulative values, got {cumulative.size}")
    return level, float(cumulative[0]), float(cumulative[1])


def run_product(config_path: Path) -> list[tuple[float, float, float, float, float]]:
    with config_path.open("rb") as f:
        config_dict = tomli.load(f)
    config_dir = config_path.parent
    base_config = BaseConfig(**config_dict)
    driver = get_driver(config_dict, config_dir, base_config)
    require(type(driver).__name__ == "RibaMod", "upstream get_driver did not return RibaMod")
    require(
        type(driver).__module__ == "imod_coupler.drivers.ribamod.ribamod",
        "RibaMod did not originate from the upstream product module",
    )

    states = []
    driver.initialize()
    try:
        for endpoint in ENDPOINTS_S:
            driver.update()
            mf6_s = float(driver.mf6.get_current_time()) * DAY
            ribasim_s = float(driver.ribasim.get_current_time())
            require(abs(mf6_s - endpoint) <= TIME_TOL, f"MF6 product time differs at {endpoint}")
            require(abs(ribasim_s - endpoint) <= TIME_TOL, f"Ribasim product time differs at {endpoint}")
            level, root, external = observe_ribasim(driver.ribasim)
            require(external <= ZERO_EXTERNAL_TOL, f"external UserDemand supplied within day at {endpoint}: {external}")
            states.append((mf6_s, ribasim_s, level, root, external))
            print(
                "RIBASIM_REAL_20C_PRODUCT "
                f"endpoint_s={endpoint} mf6_s={mf6_s} ribasim_s={ribasim_s} "
                f"level={level} root_cumulative_m3={root} external_cumulative_m3={external}"
            )
    finally:
        driver.finalize()
    return states


def run_direct(
    ribasim_config: Path,
    ribasim_dll: Path,
    ribasim_dep: Path,
) -> list[tuple[float, float, float]]:
    wrapper = RibasimWrapper(
        lib_path=ribasim_dll,
        lib_dependency=ribasim_dep,
        timing=False,
    )
    states = []
    wrapper.initialize(str(ribasim_config.resolve()))
    try:
        for endpoint in ENDPOINTS_S:
            wrapper.update_until(endpoint)
            current = float(wrapper.get_current_time())
            require(abs(current - endpoint) <= TIME_TOL, f"direct Ribasim time differs at {endpoint}")
            level, root, external = observe_ribasim(wrapper)
            require(external <= ZERO_EXTERNAL_TOL, f"direct external UserDemand supplied within day at {endpoint}: {external}")
            states.append((level, root, external))
            print(
                "RIBASIM_REAL_20C_DIRECT "
                f"endpoint_s={endpoint} ribasim_s={current} level={level} "
                f"root_cumulative_m3={root} external_cumulative_m3={external}"
            )
    finally:
        wrapper.finalize()
    return states


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-root", required=True)
    parser.add_argument("--modflow-dll", required=True)
    parser.add_argument("--ribasim-dll", required=True)
    parser.add_argument("--ribasim-dep", required=True)
    args = parser.parse_args()

    work_root = Path(args.work_root).resolve()
    modflow_dll = Path(args.modflow_dll).resolve()
    ribasim_dll = Path(args.ribasim_dll).resolve()
    ribasim_dep = Path(args.ribasim_dep).resolve()
    for path in (modflow_dll, ribasim_dll):
        require(path.is_file(), f"kernel library missing: {path}")
    require(ribasim_dep.is_dir(), f"Ribasim dependency directory missing: {ribasim_dep}")

    product_config = write_product_case(
        work_root / "product",
        modflow_dll,
        ribasim_dll,
        ribasim_dep,
    )
    direct_config = write_direct_case(work_root / "direct")

    original_cwd = Path.cwd()
    try:
        product_states = run_product(product_config)
    finally:
        os.chdir(original_cwd)
    direct_states = run_direct(direct_config, ribasim_dll, ribasim_dep)

    require(len(product_states) == len(direct_states) == 4, "unexpected trajectory length")
    for i, endpoint in enumerate(ENDPOINTS_S):
        _, _, p_level, p_root, p_external = product_states[i]
        d_level, d_root, d_external = direct_states[i]
        require(abs(p_level - d_level) <= ROUTE_LEVEL_TOL, f"Basin route mismatch at {endpoint}")
        require(abs(p_root - d_root) <= ROUTE_VOLUME_TOL, f"root cumulative route mismatch at {endpoint}")
        require(abs(p_external - d_external) <= ROUTE_VOLUME_TOL, f"external cumulative route mismatch at {endpoint}")
        print(
            "RIBASIM_REAL_20C_EQUIV "
            f"endpoint_s={endpoint} level_diff={p_level-d_level} "
            f"root_diff_m3={p_root-d_root} external_diff_m3={p_external-d_external}"
        )

    print("RIBASIM_REAL_20C_REAL_RIBAMOD_RUNTIME_CLOCK_EQUIVALENCE=PASS")


if __name__ == "__main__":
    main()
