#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import numpy as np
import pandas as pd
import tomli
import tomli_w
import xarray as xr

from imod_coupler.config import BaseConfig
from imod_coupler.drivers.driver import get_driver

from test_ribasim_dummy_20d_real_ribamod_case import (
    DAY,
    ENDPOINTS_S,
    TIME_TOL,
    build_modflow,
    build_ribasim,
    observe,
    require,
)

CASES = {
    "A5_S24": (18000.0, 86400.0),
    "A6_S24": (21600.0, 86400.0),
}


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


def read_allocation(root: Path) -> dict:
    candidates = sorted(root.rglob("allocation.nc"))
    require(len(candidates) == 1, f"expected one allocation.nc, got {candidates}")
    with xr.open_dataset(candidates[0]) as ds:
        available = set(ds.variables) | set(ds.coords)
        require({"allocated", "node_id", "demand_priority", "time"}.issubset(available),
                f"allocation schema changed: {sorted(available)}")
        times = pd.to_datetime(np.asarray(ds["time"].values))
        origin = pd.Timestamp("2020-01-01T00:00:00")
        seconds = [float((pd.Timestamp(t) - origin).total_seconds()) for t in times]
        root = np.asarray(ds["allocated"].sel(node_id=3, demand_priority=2).values, dtype=float) * DAY
        external = np.asarray(ds["allocated"].sel(node_id=4, demand_priority=3).values, dtype=float) * DAY
    require(len(seconds) == len(root) == len(external), "allocation record lengths differ")
    return {
        "times": [str(pd.Timestamp(t)) for t in times],
        "seconds": seconds,
        "root_m3_per_day": [float(x) for x in root],
        "external_m3_per_day": [float(x) for x in external],
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
                    "RIBASIM_REAL_20H10_STATE "
                    f"case={args.case} endpoint_s={endpoint} allocation_dt_s={allocation_dt} "
                    f"level={state['level_m']} root_m3={state['root_cumulative_m3']} "
                    f"external_m3={state['external_cumulative_m3']} total_m3={state['total_cumulative_m3']}"
                )
        finally:
            driver.finalize()
    finally:
        os.chdir(original_cwd)

    allocation = read_allocation(work_root)
    print(
        "RIBASIM_REAL_20H10_ALLOC "
        f"case={args.case} seconds={allocation['seconds']} "
        f"root={allocation['root_m3_per_day']} external={allocation['external_m3_per_day']}"
    )

    payload = {
        "case": args.case,
        "allocation_dt_seconds": allocation_dt,
        "solver_saveat_seconds": saveat,
        "states": states,
        "allocation": allocation,
    }
    result_path = Path(args.result_json).resolve()
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"RIBASIM_REAL_20H10_CASE=PASS case={args.case}")


if __name__ == "__main__":
    main()
