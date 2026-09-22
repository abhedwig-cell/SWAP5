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
from ribasim.config import Solver
from ribasim.geometry.node import Node
from ribasim.nodes import basin

DAY = 86400.0
AREA = 1_000_000.0
ENDPOINTS = [21600.0, 43200.0, 64800.0, 86400.0]
K_GW = 1_000_000.0
RIVER_COND = 16.0
CHD_HEAD = 0.5
RIVER_BOTTOM = 0.0
CEFF = RIVER_COND * K_GW / (K_GW + RIVER_COND)

REF_STAGE = [
    1.0,
    0.9999980000319995,
    0.9999960000719987,
    0.9999940001199977,
]
REF_FLUX_DAY = [
    7.999872002047967,
    7.999840003071942,
    7.999808004223912,
    7.999776005503875,
]
REF_CUM_INFILTRATION = [
    1.9999680005119918,
    3.999928001279977,
    5.999880002335955,
    7.9998240037119235,
]
REF_LEVEL = [
    0.9999980000319995,
    0.9999960000719987,
    0.9999940001199977,
    0.9999920001759963,
]

RATE_TOL = 0.01
VOLUME_TOL = 0.05
LEVEL_TOL = 5.0e-8
STAGE_TOL = 5.0e-8
ZERO_TOL = 0.001
TIME_TOL = 1.0e-6


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def build_ribasim() -> Model:
    model = Model(
        starttime=datetime(2020, 1, 1),
        endtime=datetime(2020, 1, 2),
        crs="EPSG:28992",
        solver=Solver(saveat=DAY),
    )
    model.basin.add(
        Node(1, Point(0.0, 0.0), name="active_river_bucket"),
        [
            basin.Profile(level=[0.0, 2.0], area=[AREA, AREA]),
            basin.State(level=[1.0]),
            basin.Static(
                drainage=[np.nan],
                potential_evaporation=[np.nan],
                infiltration=[np.nan],
                precipitation=[np.nan],
            ),
            basin.Subgrid(
                subgrid_id=[1, 1],
                basin_level=[0.0, 2.0],
                subgrid_level=[0.0, 2.0],
            ),
        ],
    )
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
    gwf["ic"] = mf6.InitialConditions(start=CHD_HEAD)
    gwf["sto"] = mf6.SpecificStorage(1.0e-5, 0.1, True, 0)

    chd = xr.DataArray(
        np.array([[[CHD_HEAD, np.nan]]], dtype=np.float64),
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
        np.array([[[np.nan, RIVER_BOTTOM]]], dtype=np.float64),
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

    sim = mf6.Modflow6Simulation("active_river_reciprocity")
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


def write_case(root: Path, modflow_dll: Path, ribasim_dll: Path, ribasim_dep: Path) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    mf6_dir = root / "modflow6"
    rib_dir = root / "ribasim"
    exchange_dir = root / "exchanges"
    exchange_dir.mkdir(parents=True, exist_ok=True)

    build_modflow().write(mf6_dir)
    build_ribasim().write(rib_dir / "ribasim.toml")

    mapping = exchange_dir / "riv.tsv"
    mapping.write_text(
        "basin_index\tbound_index\tsubgrid_index\n0\t0\t0\n",
        encoding="utf-8",
    )

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
                "mf6_active_river_packages": {"riv": "./exchanges/riv.tsv"},
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
    require(
        type(driver).__module__ == "imod_coupler.drivers.ribamod.ribamod",
        "non-upstream RibaMod",
    )

    original_cwd = Path.cwd()
    states = []
    driver.initialize()
    try:
        for i, endpoint in enumerate(ENDPOINTS):
            # Stage used for this interval is established by exchange_rib2mod
            # inside the product update and remains in the MF6 River package.
            driver.update()

            mf6_s = float(driver.mf6.get_current_time()) * DAY
            rib_s = float(driver.ribasim.get_current_time())
            require(abs(mf6_s - endpoint) <= TIME_TOL, f"MF6 time mismatch at {endpoint}")
            require(abs(rib_s - endpoint) <= TIME_TOL, f"Ribasim time mismatch at {endpoint}")

            stage_used = float(driver.mf6.packages["riv"].water_level[0])
            mf6_flux_day = float(driver.mf6.packages["riv"].get_flux(driver.mf6_head)[0])
            level = float(driver.ribasim.get_value_ptr("basin.level")[0])
            cumulative_infiltration = float(np.asarray(
                driver.ribasim.get_value_ptr("basin.cumulative_infiltration"),
                dtype=float,
            )[0])
            cumulative_drainage = float(np.asarray(
                driver.ribasim.get_value_ptr("basin.cumulative_drainage"),
                dtype=float,
            )[0])
            infiltration_rate_day = float(np.asarray(
                driver.ribasim.get_value_ptr("basin.infiltration"),
                dtype=float,
            )[0]) * DAY
            drainage_rate_day = float(np.asarray(
                driver.ribasim.get_value_ptr("basin.drainage"),
                dtype=float,
            )[0]) * DAY
            storage_loss = AREA * (1.0 - level)
            ledger_residual = cumulative_infiltration - cumulative_drainage - storage_loss

            state = {
                "endpoint": endpoint,
                "stage": stage_used,
                "mf6_flux_day": mf6_flux_day,
                "level": level,
                "cumulative_infiltration": cumulative_infiltration,
                "cumulative_drainage": cumulative_drainage,
                "infiltration_rate_day": infiltration_rate_day,
                "drainage_rate_day": drainage_rate_day,
                "storage_loss": storage_loss,
                "ledger_residual": ledger_residual,
            }
            states.append(state)

            print(
                "RIBASIM_REAL_20G_STATE "
                f"endpoint_s={endpoint} stage_used_m={stage_used} "
                f"mf6_river_flux_m3_day={mf6_flux_day} "
                f"ribasim_infiltration_m3_day={infiltration_rate_day} "
                f"ribasim_drainage_m3_day={drainage_rate_day} "
                f"cumulative_infiltration_m3={cumulative_infiltration} "
                f"level_m={level} storage_loss_m3={storage_loss} "
                f"ledger_residual_m3={ledger_residual}"
            )
    finally:
        driver.finalize()
        os.chdir(original_cwd)

    require(len(states) == 4, "unexpected trajectory length")

    for i, state in enumerate(states):
        endpoint = ENDPOINTS[i]
        require(
            abs(state["stage"] - REF_STAGE[i]) <= STAGE_TOL,
            f"MF6 active River stage differs from accepted-start-state reference at {endpoint}",
        )
        require(
            abs(state["mf6_flux_day"] - REF_FLUX_DAY[i]) <= RATE_TOL,
            f"MF6 active River flux differs from frozen conductance reference at {endpoint}",
        )
        require(
            abs(state["infiltration_rate_day"] - state["mf6_flux_day"]) <= RATE_TOL,
            f"Ribasim infiltration is not reciprocal to MF6 River flux at {endpoint}",
        )
        require(
            abs(state["drainage_rate_day"]) <= ZERO_TOL,
            f"unexpected Ribasim drainage at {endpoint}",
        )
        require(
            abs(state["cumulative_drainage"]) <= VOLUME_TOL,
            f"unexpected cumulative drainage at {endpoint}",
        )
        require(
            abs(state["cumulative_infiltration"] - REF_CUM_INFILTRATION[i]) <= VOLUME_TOL,
            f"cumulative infiltration differs from frozen sample-and-hold reference at {endpoint}",
        )
        require(
            abs(state["level"] - REF_LEVEL[i]) <= LEVEL_TOL,
            f"Basin level differs from frozen sample-and-hold reference at {endpoint}",
        )
        require(
            abs(state["ledger_residual"]) <= VOLUME_TOL,
            f"Ribasim infiltration/storage ledger does not close at {endpoint}",
        )

    require(
        all(states[i + 1]["level"] < states[i]["level"] for i in range(3)),
        "Basin level is not monotonically decreasing under active River infiltration",
    )

    print(
        "RIBASIM_REAL_20G_RECIPROCITY=PASS "
        f"effective_exchange_conductance_m2_day={CEFF}"
    )
    print("RIBASIM_REAL_20G_ACTIVE_RIVER_STAGE_FEEDBACK=PASS")


if __name__ == "__main__":
    main()
