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
ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0, 108000.0]
K_GW = 1_000_000.0
DRAIN_COND = 16.0
EXPECTED_HEAD = 0.5 * K_GW / (K_GW + DRAIN_COND)
EXPECTED_DRAIN_DAY = DRAIN_COND * EXPECTED_HEAD

REF_LEVEL = [
    1.0000039987293805,
    1.0000099943718745,
    1.0000159863657703,
    1.0000219748888743,
    1.000024448561855,
]
REF_ROOT = [
    4.001270619481194,
    8.005596125858313,
    12.013570230756775,
    16.02501512716806,
    21.0425451404563,
]
REF_EXTERNAL = [0.0, 0.0, 0.0, 0.0, 2.5087650066441327]
REF_GW = [0.0, 1.9999680005119933, 3.9999360010239866, 5.99990400153598, 7.999872002047974]

T0_ROOT = 32.0
T24_ROOT = 40.0
T24_EXTERNAL = 20.0
MEMORY_ONLY_EXTERNAL = 13.97488887434318

ALLOC_TOL = 0.05
LEVEL_TOL = 5.0e-8
VOLUME_TOL = 0.05
RATE_TOL = 0.01
ZERO_TOL = 0.001
TIME_TOL = 1.0e-6
MEMORY_ONLY_SEPARATION = 5.0


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
        coords={"layer": [1], "y": [0.0], "x": [0.0, 1.0], "dx": 1.0, "dy": -1.0},
    )
    bottom = xr.DataArray([0.0], dims=("layer",), coords={"layer": [1]})
    gwf = mf6.GroundwaterFlowModel()
    gwf["dis"] = mf6.StructuredDiscretization(idomain=idomain, top=1.0, bottom=bottom)
    gwf["npf"] = mf6.NodePropertyFlow(icelltype=0, k=K_GW, k33=K_GW, save_flows=True)
    gwf["ic"] = mf6.InitialConditions(start=0.5)
    gwf["sto"] = mf6.SpecificStorage(1.0e-5, 0.1, True, 0)

    chd = xr.DataArray(
        np.array([[[0.5, np.nan]]], dtype=np.float64),
        dims=("layer", "y", "x"), coords=idomain.coords,
    )
    gwf["chd"] = mf6.ConstantHead(head=chd, print_input=False, print_flows=False, save_flows=True)

    times = pd.to_datetime(["2020-01-01T00:00:00", "2020-01-01T06:00:00"])
    elevation = xr.DataArray(
        np.array([[[[np.nan, 0.5]]], [[[np.nan, 0.0]]]], dtype=np.float64),
        dims=("time", "layer", "y", "x"),
        coords={"time": times, "layer": [1], "y": [0.0], "x": [0.0, 1.0], "dx": 1.0, "dy": -1.0},
    )
    conductance = xr.DataArray(
        np.array([[[[np.nan, DRAIN_COND]]], [[[np.nan, DRAIN_COND]]]], dtype=np.float64),
        dims=("time", "layer", "y", "x"), coords=elevation.coords,
    )
    gwf["drn"] = mf6.Drainage(
        elevation=elevation, conductance=conductance,
        print_input=False, print_flows=False, save_flows=True,
    )
    gwf["oc"] = mf6.OutputControl(save_head="last", save_budget="last")

    sim = mf6.Modflow6Simulation("positive_groundwater_next_boundary")
    sim["GWF_1"] = gwf
    sim["solver"] = mf6.Solution(
        modelnames=["GWF_1"], print_option="summary",
        outer_dvclose=1.0e-10, outer_maximum=100, under_relaxation=None,
        inner_dvclose=1.0e-10, inner_rclose=1.0e-8, inner_maximum=100,
        linear_acceleration="cg", scaling_method=None, reordering_method=None,
        relaxation_factor=0.97,
    )
    sim.create_time_discretization(
        additional_times=pd.date_range("2020-01-01", "2020-01-03", freq="6h")
    )
    return sim


def write_case(root: Path, modflow_dll: Path, ribasim_dll: Path, ribasim_dep: Path) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    mf6_dir = root / "modflow6"
    rib_dir = root / "ribasim"
    exchange_dir = root / "exchanges"
    exchange_dir.mkdir(parents=True, exist_ok=True)
    build_modflow().write(mf6_dir)
    build_ribasim().write(rib_dir / "ribasim.toml")
    mapping = exchange_dir / "drn.tsv"
    mapping.write_text("basin_index\tbound_index\n0\t0\n", encoding="utf-8")
    cfg = {
        "timing": False, "log_level": "INFO", "driver_type": "ribamod",
        "driver": {
            "kernels": {
                "modflow6": {"dll": str(modflow_dll), "work_dir": "modflow6"},
                "ribasim": {
                    "dll": str(ribasim_dll), "dll_dep_dir": str(ribasim_dep),
                    "config_file": "ribasim/ribasim.toml",
                },
            },
            "coupling": [{
                "mf6_model": "GWF_1",
                "mf6_active_river_packages": {},
                "mf6_active_drainage_packages": {},
                "mf6_passive_river_packages": {},
                "mf6_passive_drainage_packages": {"drn": "./exchanges/drn.tsv"},
            }],
        },
    }
    path = root / "imod_coupler.toml"
    with path.open("wb") as f:
        tomli_w.dump(cfg, f)
    return path


def read_allocations(root: Path) -> dict:
    candidates = sorted(root.rglob("allocation.nc"))
    require(len(candidates) == 1, f"expected one allocation.nc, got {candidates}")
    with xr.open_dataset(candidates[0]) as ds:
        available = set(ds.variables) | set(ds.coords)
        require({"allocated", "node_id", "demand_priority", "time"}.issubset(available),
                f"allocation schema changed: {sorted(available)}")
        require(ds.sizes.get("time", 0) >= 2, "no distinct t=24 allocation record")
        times = np.asarray(ds["time"].values)
        require(pd.Timestamp(times[0]) == pd.Timestamp("2020-01-01T00:00:00"),
                f"first allocation record is not t=0: {times[0]}")
        require(pd.Timestamp(times[1]) == pd.Timestamp("2020-01-02T00:00:00"),
                f"second allocation record is not t=24 h: {times[1]}")
        root_a = np.asarray(ds["allocated"].sel(node_id=3, demand_priority=2).values, dtype=float) * DAY
        ext_a = np.asarray(ds["allocated"].sel(node_id=4, demand_priority=3).values, dtype=float) * DAY
    print(
        "RIBASIM_REAL_20H9_ALLOC "
        f"t0_root_m3_day={root_a[0]} t0_external_m3_day={ext_a[0]} "
        f"t24_root_m3_day={root_a[1]} t24_external_m3_day={ext_a[1]}"
    )
    return {
        "t0_root": float(root_a[0]), "t0_external": float(ext_a[0]),
        "t24_root": float(root_a[1]), "t24_external": float(ext_a[1]),
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

    config_path = write_case(root, modflow_dll, ribasim_dll, ribasim_dep)
    with config_path.open("rb") as f:
        cfg = tomli.load(f)
    base = BaseConfig(**cfg)
    driver = get_driver(cfg, config_path.parent, base)
    require(type(driver).__name__ == "RibaMod", "upstream get_driver did not select RibaMod")
    require(type(driver).__module__ == "imod_coupler.drivers.ribamod.ribamod", "non-upstream RibaMod")

    states = []
    original_cwd = Path.cwd()
    driver.initialize()
    try:
        for endpoint in ENDPOINTS:
            driver.update()
            mf6_s = float(driver.mf6.get_current_time()) * DAY
            rib_s = float(driver.ribasim.get_current_time())
            require(abs(mf6_s - endpoint) <= TIME_TOL, f"MF6 time mismatch at {endpoint}")
            require(abs(rib_s - endpoint) <= TIME_TOL, f"Ribasim time mismatch at {endpoint}")

            level = float(driver.ribasim.get_value_ptr("basin.level")[0])
            cumulative_user = np.asarray(driver.ribasim.get_value_ptr("user_demand.cumulative_inflow"), dtype=float)
            cumulative_gw = float(np.asarray(driver.ribasim.get_value_ptr("basin.cumulative_drainage"), dtype=float)[0])
            drainage_day = float(np.asarray(driver.ribasim.get_value_ptr("basin.drainage"), dtype=float)[0]) * DAY
            mf6_flux_day = float(driver.mf6.packages["drn"].get_flux(driver.mf6_head)[0])
            root_v = float(cumulative_user[0])
            ext_v = float(cumulative_user[1])
            storage_gain = AREA * (level - 1.0)
            source_cumulative = 32.0 * endpoint / DAY
            residual = source_cumulative + cumulative_gw - root_v - ext_v - storage_gain
            require(abs(residual) <= VOLUME_TOL, f"ledger mismatch at {endpoint}")
            states.append({
                "endpoint": endpoint, "level": level, "root": root_v, "external": ext_v,
                "cumulative_gw": cumulative_gw, "drainage_day": drainage_day,
                "mf6_flux_day": mf6_flux_day, "storage_gain": storage_gain, "residual": residual,
            })
            print(
                "RIBASIM_REAL_20H9_STATE "
                f"endpoint_s={endpoint} level={level} root_m3={root_v} external_m3={ext_v} "
                f"gw_cumulative_m3={cumulative_gw} ribasim_drainage_m3_day={drainage_day} "
                f"mf6_drain_flux_m3_day={mf6_flux_day} storage_gain_m3={storage_gain} "
                f"ledger_residual_m3={residual}"
            )
    finally:
        driver.finalize()
        os.chdir(original_cwd)

    for i in range(5):
        require(abs(states[i]["level"] - REF_LEVEL[i]) <= LEVEL_TOL, f"level mismatch at {ENDPOINTS[i]}")
        require(abs(states[i]["root"] - REF_ROOT[i]) <= VOLUME_TOL, f"root mismatch at {ENDPOINTS[i]}")
        require(abs(states[i]["external"] - REF_EXTERNAL[i]) <= VOLUME_TOL, f"external mismatch at {ENDPOINTS[i]}")
        require(abs(states[i]["cumulative_gw"] - REF_GW[i]) <= VOLUME_TOL, f"groundwater cumulative mismatch at {ENDPOINTS[i]}")
    require(abs(states[0]["drainage_day"]) <= ZERO_TOL, "first-step Ribasim drainage not zero")
    require(abs(states[0]["mf6_flux_day"]) <= ZERO_TOL, "first-step MF6 drainage not zero")
    for i in range(1,5):
        require(abs(states[i]["drainage_day"] - EXPECTED_DRAIN_DAY) <= RATE_TOL,
                f"Ribasim drainage mismatch at {ENDPOINTS[i]}")
        require(abs(states[i]["mf6_flux_day"] + EXPECTED_DRAIN_DAY) <= RATE_TOL,
                f"MF6 drain flux mismatch at {ENDPOINTS[i]}")

    alloc = read_allocations(root)
    require(abs(alloc["t0_root"] - T0_ROOT) <= ALLOC_TOL, "t=0 root allocation not 32")
    require(abs(alloc["t0_external"]) <= ALLOC_TOL, "t=0 external allocation nonzero")
    require(abs(alloc["t24_root"] - T24_ROOT) <= ALLOC_TOL, "t=24 root allocation not full 40")
    require(abs(alloc["t24_external"] - T24_EXTERNAL) <= ALLOC_TOL, "t=24 external allocation not full 20")
    require(alloc["t24_external"] - MEMORY_ONLY_EXTERNAL > MEMORY_ONLY_SEPARATION,
            "t=24 external allocation does not discriminate current positive forcing from memory-only alternative")
    require(abs(states[3]["external"]) <= ZERO_TOL, "external supplied before t=24 boundary")
    require(states[4]["external"] > 1.0, "external supply did not become positive after t=24 allocation")

    print(
        "RIBASIM_REAL_20H9_POSITIVE_GROUNDWATER_FORECAST_ADMISSION=PASS "
        f"accepted_t24_level={states[3]['level']} "
        f"current_drainage_m3_day={states[4]['drainage_day']} "
        f"t24_root_alloc_m3_day={alloc['t24_root']} "
        f"t24_external_alloc_m3_day={alloc['t24_external']} "
        f"memory_only_external_m3_day={MEMORY_ONLY_EXTERNAL}"
    )


if __name__ == "__main__":
    main()
