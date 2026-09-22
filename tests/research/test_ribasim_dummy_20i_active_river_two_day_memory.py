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
ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0, 108000.0, 129600.0, 151200.0, 172800.0]
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


REF_LEVEL = [
    1.0000029993357635,
    1.0000059973101296,
    1.0000089939237178,
    1.0000119891771457,
    1.0000134819227537,
    1.0000149736554362,
    1.0000164643758798,
    1.0000179540847753,
]
REF_ROOT = [
    3.000685569574161,
    6.002720539372463,
    9.00610429533599,
    12.010836225179707,
    16.518063994076833,
    21.026298717576452,
    25.53553971316831,
    30.0457862938985,
]
REF_RIVER_CUM = [
    1.9999786668942208,
    3.999969331003525,
    5.999971986882382,
    7.999986629087738,
    10.00001325217901,
    12.000045846189023,
    14.000084407066119,
    16.000128930761385,
]
REF_STORAGE = [
    2.9993357635316187,
    5.997310129624012,
    8.993923717781627,
    11.989177145732555,
    13.481922753744158,
    14.973655436234523,
    16.46437587976557,
    17.954084775340107,
]
EXPECTED_T24_ROOT_ALLOC = 35.98907065336747
EXPECTED_T24_EXT_ALLOC = 0.0
EFFECTIVE_RIVER_CONDUCTANCE = 15.999829335153766
LEVEL_TOL = 5.0e-8

def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def build_ribasim() -> Model:
    model = Model(
        starttime=datetime(2020, 1, 1),
        endtime=datetime(2020, 1, 3),
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

    sim = mf6.Modflow6Simulation("active_river_two_day_memory")
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
        additional_times=pd.date_range("2020-01-01", "2020-01-03", freq="6h")
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
    candidates = sorted(case_root.rglob("allocation.nc"))
    require(len(candidates) == 1, f"expected one allocation.nc under {case_root}, got {candidates}")
    return candidates[0]


def read_allocation_records(case_root: Path) -> list[dict]:
    path = find_allocation_output(case_root)
    records = []
    with xr.open_dataset(path) as ds:
        required = {"allocated", "node_id", "demand_priority", "time"}
        available = set(ds.variables) | set(ds.coords)
        require(required.issubset(available), f"allocation NetCDF schema changed: {sorted(available)}")
        times = pd.to_datetime(ds["time"].values)
        root = np.asarray(ds["allocated"].sel(node_id=3, demand_priority=2).values, dtype=float) * DAY
        ext = np.asarray(ds["allocated"].sel(node_id=4, demand_priority=3).values, dtype=float) * DAY
        require(len(times) == len(root) == len(ext), "allocation time/value shapes differ")
        t0 = pd.Timestamp("2020-01-01T00:00:00")
        for t, r, e in zip(times, root, ext):
            if np.isfinite(r) and np.isfinite(e):
                seconds = float((pd.Timestamp(t) - t0).total_seconds())
                records.append({"time_s": seconds, "root": float(r), "external": float(e)})
    require(len(records) == 2, f"expected exactly t=0 and t=24h allocation records, got {records}")
    return records


def run_active_case(
    case_root: Path,
    *,
    modflow_dll: Path,
    ribasim_dll: Path,
    ribasim_dep: Path,
) -> dict:
    config_path = write_case(
        case_root,
        active=True,
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
    driver.initialize()
    try:
        previous_stage = 1.0
        for i, endpoint in enumerate(ENDPOINTS):
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
            river_flux = float(driver.mf6.packages["riv"].get_flux(driver.mf6_head)[0])
            infiltration_rate = float(np.asarray(
                driver.ribasim.get_value_ptr("basin.infiltration"), dtype=float
            )[0]) * DAY
            cumulative_infiltration = float(np.asarray(
                driver.ribasim.get_value_ptr("basin.cumulative_infiltration"),
                dtype=float,
            )[0])
            storage_gain = AREA * (level - 1.0)

            expected_river = EFFECTIVE_RIVER_CONDUCTANCE * (previous_stage - 0.5)
            require(abs(river_flux - infiltration_rate) <= RATE_TOL, f"river/infiltration reciprocity mismatch at {endpoint}")
            require(abs(river_flux - expected_river) <= RATE_TOL, f"sample-and-hold River law mismatch at {endpoint}")
            require(abs(level - REF_LEVEL[i]) <= LEVEL_TOL, f"Basin level differs from frozen hybrid reference at {endpoint}")
            require(abs(root_volume - REF_ROOT[i]) <= VOLUME_TOL, f"root cumulative delivery differs at {endpoint}")
            require(abs(external_volume) <= ZERO_TOL, f"external supplied at {endpoint}")
            require(abs(cumulative_infiltration - REF_RIVER_CUM[i]) <= VOLUME_TOL, f"River cumulative transfer differs at {endpoint}")
            require(abs(storage_gain - REF_STORAGE[i]) <= VOLUME_TOL, f"storage gain differs at {endpoint}")

            source_cumulative = 32.0 * endpoint / DAY
            ledger_residual = (
                source_cumulative
                - root_volume
                - external_volume
                - cumulative_infiltration
                - storage_gain
            )
            require(abs(ledger_residual) <= VOLUME_TOL, f"water ledger mismatch at {endpoint}")

            states.append({
                "endpoint": endpoint,
                "level": level,
                "root": root_volume,
                "external": external_volume,
                "river_flux_day": river_flux,
                "cum_infiltration": cumulative_infiltration,
                "storage_gain": storage_gain,
                "ledger_residual": ledger_residual,
            })
            print(
                "RIBASIM_REAL_20I_STATE "
                f"endpoint_s={endpoint} level={level} root_m3={root_volume} "
                f"external_m3={external_volume} river_flux_m3_day={river_flux} "
                f"cumulative_infiltration_m3={cumulative_infiltration} "
                f"storage_gain_m3={storage_gain} ledger_residual_m3={ledger_residual}"
            )
            previous_stage = level
    finally:
        driver.finalize()
        os.chdir(original_cwd)

    allocation = read_allocation_records(case_root)
    for record in allocation:
        print(
            "RIBASIM_REAL_20I_ALLOC "
            f"time_s={record['time_s']} root_alloc_m3_day={record['root']} "
            f"external_alloc_m3_day={record['external']}"
        )
    return {"states": states, "allocation": allocation}


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

    result = run_active_case(
        root / "active",
        modflow_dll=modflow_dll,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
    )
    alloc = result["allocation"]
    require(abs(alloc[0]["time_s"] - 0.0) <= TIME_TOL, "first allocation is not t=0")
    require(abs(alloc[0]["root"] - EXPECTED_ACTIVE_ROOT_ALLOC) <= ALLOC_TOL, "t=0 root allocation differs from frozen reference")
    require(abs(alloc[0]["external"]) <= ALLOC_TOL, "t=0 external allocation is not zero")

    require(abs(alloc[1]["time_s"] - DAY) <= TIME_TOL, "second allocation is not t=24h")
    require(abs(alloc[1]["root"] - EXPECTED_T24_ROOT_ALLOC) <= ALLOC_TOL, "t=24h root allocation differs from frozen next-boundary reference")
    require(abs(alloc[1]["external"] - EXPECTED_T24_EXT_ALLOC) <= ALLOC_TOL, "t=24h external allocation differs from frozen reference")
    require(alloc[1]["root"] > alloc[0]["root"] + 1.0, "accepted physical memory did not materially increase next-boundary root allocation")

    print(
        "RIBASIM_REAL_20I_ACTIVE_RIVER_NEXT_BOUNDARY_MEMORY=PASS "
        f"t0_root_alloc_m3_day={alloc[0]['root']} "
        f"t24_root_alloc_m3_day={alloc[1]['root']}"
    )


if __name__ == "__main__":
    main()
