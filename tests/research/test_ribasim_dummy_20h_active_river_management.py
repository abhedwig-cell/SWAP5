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

from imod import mf6
from imod_coupler.config import BaseConfig
from imod_coupler.drivers.driver import get_driver
from ribasim import Model
from ribasim.config import Allocation, Experimental, Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin, flow_boundary, level_demand, user_demand

DAY = 86400.0
AREA = 1_000_000.0
ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
K_GW = 1_000_000.0
RIVER_COND = 16.0
FIRST_RIVER_AUTHORITY = 7.999914667576883
EXPECTED_ACTIVE_ROOT_ALLOC = 32.0 - FIRST_RIVER_AUTHORITY

ALLOC_TOL = 0.05
RATE_TOL = 0.01
VOLUME_TOL = 0.05
ZERO_TOL = 0.001
TIME_TOL = 1.0e-6
MATERIAL_ROOT_DIFF = 1.0


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
            basin.Profile(level=[0.0, 2.0], area=[AREA, AREA]),
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
        np.ones((1, 1, 2), dtype=np.int32),
        dims=("layer", "y", "x"),
        coords={
            "layer": [1],
            "y": [0.0],
            "x": [0.0, 1.0],
            "dx": 1.0,
            "dy": -1.0,
        },
    )
    bottom = xr.DataArray([0.0], dims=("layer",), coords={"layer": [1]})
    gwf = mf6.GroundwaterFlowModel()
    gwf["dis"] = mf6.StructuredDiscretization(idomain=idomain, top=1.5, bottom=bottom)
    gwf["npf"] = mf6.NodePropertyFlow(
        icelltype=0,
        k=K_GW,
        k33=K_GW,
        save_flows=True,
    )
    gwf["ic"] = mf6.InitialConditions(start=0.5)
    gwf["sto"] = mf6.SpecificStorage(1.0e-5, 0.1, True, 0)

    chd = xr.DataArray(
        np.array([[[0.5, np.nan]]], dtype=np.float64),
        dims=("layer", "y", "x"),
        coords=idomain.coords,
    )
    gwf["chd"] = mf6.ConstantHead(
        head=chd,
        print_input=False,
        print_flows=False,
        save_flows=True,
    )
    stage = xr.DataArray(
        np.array([[[np.nan, 1.0]]], dtype=np.float64),
        dims=("layer", "y", "x"),
        coords=idomain.coords,
    )
    conductance = xr.DataArray(
        np.array([[[np.nan, RIVER_COND]]], dtype=np.float64),
        dims=("layer", "y", "x"),
        coords=idomain.coords,
    )
    bottom_elevation = xr.DataArray(
        np.array([[[np.nan, 0.0]]], dtype=np.float64),
        dims=("layer", "y", "x"),
        coords=idomain.coords,
    )
    gwf["riv"] = mf6.River(
        stage=stage,
        conductance=conductance,
        bottom_elevation=bottom_elevation,
        print_input=False,
        print_flows=False,
        save_flows=True,
    )
    gwf["oc"] = mf6.OutputControl(save_head="last", save_budget="last")

    sim = mf6.Modflow6Simulation("active_river_management_boundary")
    sim["GWF_1"] = gwf
    sim["solver"] = mf6.Solution(
        modelnames=["GWF_1"],
        print_option="summary",
        outer_dvclose=1.0e-10,
        outer_maximum=100,
        under_relaxation=None,
        inner_dvclose=1.0e-10,
        inner_rclose=1.0e-8,
        inner_maximum=100,
        linear_acceleration="cg",
        scaling_method=None,
        reordering_method=None,
        relaxation_factor=0.97,
    )
    sim.create_time_discretization(
        additional_times=pd.date_range("2020-01-01", "2020-01-02", freq="6h")
    )
    return sim


def write_case(
    root: Path,
    *,
    active: bool,
    modflow_dll: Path,
    ribasim_dll: Path,
    ribasim_dep: Path,
) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    mf6_dir = root / "modflow6"
    rib_dir = root / "ribasim"
    exchange_dir = root / "exchanges"
    exchange_dir.mkdir(parents=True, exist_ok=True)

    build_modflow().write(mf6_dir)
    build_ribasim().write(rib_dir / "ribasim.toml")

    active_rivers = {}
    if active:
        mapping = exchange_dir / "riv.tsv"
        mapping.write_text(
            "basin_index\tbound_index\tsubgrid_index\n0\t0\t0\n",
            encoding="utf-8",
        )
        active_rivers = {"riv": "./exchanges/riv.tsv"}

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
                "mf6_active_river_packages": active_rivers,
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


def find_allocation_output(case_root: Path) -> Path:
    # Ribasim v2026.1.1 writes allocation results as NetCDF, not Arrow.
    candidates = sorted(case_root.rglob("allocation.nc"))
    require(len(candidates) == 1, f"expected one allocation.nc under {case_root}, got {candidates}")
    return candidates[0]


def read_t0_allocations(case_root: Path) -> tuple[float, float]:
    path = find_allocation_output(case_root)
    with xr.open_dataset(path) as ds:
        required = {"allocated", "node_id", "demand_priority", "time"}
        available = set(ds.variables) | set(ds.coords)
        require(required.issubset(available), f"allocation NetCDF schema changed: {sorted(available)}")
        root_alloc = float(
            ds["allocated"].sel(node_id=3, demand_priority=2).isel(time=0).item()
        ) * DAY
        ext_alloc = float(
            ds["allocated"].sel(node_id=4, demand_priority=3).isel(time=0).item()
        ) * DAY
    return root_alloc, ext_alloc


def run_case(
    case_root: Path,
    *,
    active: bool,
    modflow_dll: Path,
    ribasim_dll: Path,
    ribasim_dep: Path,
) -> dict:
    config_path = write_case(
        case_root,
        active=active,
        modflow_dll=modflow_dll,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
    )
    with config_path.open("rb") as f:
        cfg = tomli.load(f)
    base = BaseConfig(**cfg)
    driver = get_driver(cfg, config_path.parent, base)
    require(type(driver).__name__ == "RibaMod", "upstream get_driver did not select RibaMod")

    original_cwd = Path.cwd()
    states = []
    first_river_flux = None
    driver.initialize()
    try:
        for endpoint in ENDPOINTS:
            driver.update()
            mf6_s = float(driver.mf6.get_current_time()) * DAY
            rib_s = float(driver.ribasim.get_current_time())
            require(abs(mf6_s - endpoint) <= TIME_TOL, f"MF6 time mismatch at {endpoint}")
            require(abs(rib_s - endpoint) <= TIME_TOL, f"Ribasim time mismatch at {endpoint}")

            level = float(driver.ribasim.get_value_ptr("basin.level")[0])
            cumulative_user = np.asarray(
                driver.ribasim.get_value_ptr("user_demand.cumulative_inflow"),
                dtype=float,
            )
            root_volume = float(cumulative_user[0])
            external_volume = float(cumulative_user[1])
            storage_gain = AREA * (level - 1.0)

            if active:
                river_flux = float(driver.mf6.packages["riv"].get_flux(driver.mf6_head)[0])
                infiltration_rate = float(np.asarray(
                    driver.ribasim.get_value_ptr("basin.infiltration"), dtype=float
                )[0]) * DAY
                cumulative_infiltration = float(np.asarray(
                    driver.ribasim.get_value_ptr("basin.cumulative_infiltration"),
                    dtype=float,
                )[0])
                if first_river_flux is None:
                    first_river_flux = river_flux
                require(abs(river_flux - infiltration_rate) <= RATE_TOL, f"river/infiltration reciprocity mismatch at {endpoint}")
                require(abs(river_flux) > 1.0, f"active river did not realize material flux at {endpoint}")
            else:
                river_flux = 0.0
                infiltration_rate = 0.0
                cumulative_infiltration = 0.0

            source_cumulative = 32.0 * endpoint / DAY
            ledger_residual = (
                source_cumulative
                - root_volume
                - external_volume
                - cumulative_infiltration
                - storage_gain
            )
            require(abs(ledger_residual) <= VOLUME_TOL, f"water ledger mismatch at {endpoint}")
            require(abs(external_volume) <= ZERO_TOL, f"external supplied within one-day root-first case at {endpoint}")

            states.append({
                "endpoint": endpoint,
                "level": level,
                "root": root_volume,
                "external": external_volume,
                "river_flux_day": river_flux,
                "infiltration_day": infiltration_rate,
                "cum_infiltration": cumulative_infiltration,
                "storage_gain": storage_gain,
                "ledger_residual": ledger_residual,
            })
            print(
                "RIBASIM_REAL_20H_STATE "
                f"case={'active' if active else 'control'} endpoint_s={endpoint} "
                f"level={level} root_m3={root_volume} external_m3={external_volume} "
                f"river_flux_m3_day={river_flux} infiltration_m3_day={infiltration_rate} "
                f"cumulative_infiltration_m3={cumulative_infiltration} "
                f"storage_gain_m3={storage_gain} ledger_residual_m3={ledger_residual}"
            )
    finally:
        driver.finalize()
        os.chdir(original_cwd)

    root_alloc, ext_alloc = read_t0_allocations(case_root)
    print(
        "RIBASIM_REAL_20H_ALLOC "
        f"case={'active' if active else 'control'} "
        f"root_alloc_m3_day={root_alloc} external_alloc_m3_day={ext_alloc}"
    )
    return {
        "states": states,
        "root_alloc": root_alloc,
        "ext_alloc": ext_alloc,
        "first_river_flux": first_river_flux,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-root", required=True)
    parser.add_argument("--modflow-dll", required=True)
    parser.add_argument("--ribasim-dll", required=True)
    parser.add_argument("--ribasim-dep", required=True)
    args = parser.parse_args()

    root = Path(args.work_root).resolve()
    modflow_dll = Path(args.modflow_dll).resolve()
    ribasim_dll = Path(args.ribasim_dll).resolve()
    ribasim_dep = Path(args.ribasim_dep).resolve()
    require(modflow_dll.is_file(), "MODFLOW DLL missing")
    require(ribasim_dll.is_file(), "Ribasim DLL missing")
    require(ribasim_dep.is_dir(), "Ribasim dependency directory missing")

    control = run_case(
        root / "control",
        active=False,
        modflow_dll=modflow_dll,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
    )
    active = run_case(
        root / "active",
        active=True,
        modflow_dll=modflow_dll,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
    )

    require(abs(control["root_alloc"] - 32.0) <= ALLOC_TOL, "control t=0 root allocation is not 32 m3/day")
    require(abs(control["ext_alloc"]) <= ALLOC_TOL, "control t=0 external allocation is not zero")

    require(active["first_river_flux"] is not None, "active first river flux missing")
    require(
        abs(active["first_river_flux"] - FIRST_RIVER_AUTHORITY) <= RATE_TOL,
        "active first river flux differs from qualified DUMMY-20G authority",
    )
    require(
        abs(active["root_alloc"] - EXPECTED_ACTIVE_ROOT_ALLOC) <= ALLOC_TOL,
        "active t=0 root allocation differs from frozen 32 - river forcing reference",
    )
    require(abs(active["ext_alloc"]) <= ALLOC_TOL, "active t=0 external allocation is not zero")
    require(
        abs((control["root_alloc"] - active["root_alloc"]) - active["first_river_flux"]) <= ALLOC_TOL,
        "allocation reduction does not equal pre-SOLVE active-river forcing",
    )

    for i, endpoint in enumerate(ENDPOINTS):
        require(
            active["states"][i]["root"] + MATERIAL_ROOT_DIFF < control["states"][i]["root"],
            f"active-river root physical delivery is not materially below control at {endpoint}",
        )

    print(
        "RIBASIM_REAL_20H_CURRENT_BOUNDARY_ADMISSION=PASS "
        f"control_root_alloc_m3_day={control['root_alloc']} "
        f"active_root_alloc_m3_day={active['root_alloc']} "
        f"first_river_flux_m3_day={active['first_river_flux']}"
    )
    print("RIBASIM_REAL_20H_TIME_DIRECTION_CONTRAST=PASS")


if __name__ == "__main__":
    main()
