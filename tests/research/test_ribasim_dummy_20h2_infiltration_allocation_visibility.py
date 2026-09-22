#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys

import numpy as np
import tomli

from imod_coupler.config import BaseConfig
from imod_coupler.drivers.driver import get_driver
from imod_coupler.kernelwrappers.ribasim_wrapper import RibasimWrapper

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_ribasim_dummy_20h_active_river_management as h20  # noqa: E402

DAY = 86400.0
ENDPOINT = 21600.0
INJECTION_M3_DAY = 7.999914667576883
EXPECTED_REDUCED_ROOT = 32.0 - INJECTION_M3_DAY

ALLOC_TOL = 0.05
RATE_TOL = 0.01
ZERO_TOL = 0.001
POSITIVE_CUM_INF = 0.1
TIME_TOL = 1.0e-6


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def write_direct_case(root: Path) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    config = root / "ribasim.toml"
    h20.build_ribasim().write(config)
    return config


def run_direct(
    root: Path,
    *,
    injection_m3_day: float,
    ribasim_dll: Path,
    ribasim_dep: Path,
    label: str,
) -> dict:
    config = write_direct_case(root)
    wrapper = RibasimWrapper(
        lib_path=ribasim_dll,
        lib_dependency=ribasim_dep,
        timing=False,
    )
    wrapper.initialize(str(config.resolve()))
    try:
        infiltration = wrapper.get_value_ptr("basin.infiltration")
        require(infiltration.size == 1, f"{label}: expected one Basin infiltration pointer")
        infiltration[0] = injection_m3_day / DAY
        readback = float(infiltration[0]) * DAY
        require(abs(readback - injection_m3_day) <= RATE_TOL, f"{label}: infiltration pointer readback mismatch")

        wrapper.update_until(ENDPOINT)
        require(abs(float(wrapper.get_current_time()) - ENDPOINT) <= TIME_TOL, f"{label}: direct time mismatch")

        cumulative_infiltration = float(
            np.asarray(wrapper.get_value_ptr("basin.cumulative_infiltration"), dtype=float)[0]
        )
        cumulative_user = np.asarray(
            wrapper.get_value_ptr("user_demand.cumulative_inflow"), dtype=float
        )
        level = float(wrapper.get_value_ptr("basin.level")[0])
        root_volume = float(cumulative_user[0])
        external_volume = float(cumulative_user[1])

        if injection_m3_day > 0.0:
            require(
                cumulative_infiltration > POSITIVE_CUM_INF,
                f"{label}: injected infiltration did not affect physical cumulative infiltration",
            )
        else:
            require(
                abs(cumulative_infiltration) <= ZERO_TOL,
                f"{label}: zero-injection control accumulated infiltration",
            )
        require(abs(external_volume) <= ZERO_TOL, f"{label}: external demand supplied unexpectedly")

        print(
            "RIBASIM_REAL_20H2_DIRECT_STATE "
            f"label={label} pointer_m3_day={readback} level={level} "
            f"root_m3={root_volume} external_m3={external_volume} "
            f"cumulative_infiltration_m3={cumulative_infiltration}"
        )
    finally:
        wrapper.finalize()

    root_alloc, ext_alloc = h20.read_t0_allocations(root)
    print(
        "RIBASIM_REAL_20H2_DIRECT_ALLOC "
        f"label={label} root_alloc_m3_day={root_alloc} external_alloc_m3_day={ext_alloc}"
    )
    return {
        "pointer_m3_day": readback,
        "root_alloc": root_alloc,
        "ext_alloc": ext_alloc,
        "level": level,
        "root_volume": root_volume,
        "external_volume": external_volume,
        "cumulative_infiltration": cumulative_infiltration,
    }


def run_actual_ribamod(
    root: Path,
    *,
    modflow_dll: Path,
    ribasim_dll: Path,
    ribasim_dep: Path,
) -> dict:
    config_path = h20.write_case(
        root,
        active=True,
        modflow_dll=modflow_dll,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
    )
    with config_path.open("rb") as f:
        cfg = tomli.load(f)
    base = BaseConfig(**cfg)
    driver = get_driver(cfg, config_path.parent, base)
    require(type(driver).__name__ == "RibaMod", "actual product route did not select RibaMod")

    observed_pre_update = []
    original_cwd = Path.cwd()
    driver.initialize()
    original_update_until = driver.ribasim.update_until

    def observed_update_until(target_time: float):
        rate = float(driver.ribasim.get_value_ptr("basin.infiltration")[0]) * DAY
        observed_pre_update.append(rate)
        print(
            "RIBASIM_REAL_20H2_PRE_UPDATE_POINTER "
            f"target_s={target_time} infiltration_m3_day={rate}"
        )
        return original_update_until(target_time)

    driver.ribasim.update_until = observed_update_until
    try:
        driver.update()
        require(len(observed_pre_update) == 1, "actual RibaMod did not call observed update_until exactly once")
        pre_rate = observed_pre_update[0]
        require(
            abs(pre_rate - INJECTION_M3_DAY) <= RATE_TOL,
            "actual RibaMod infiltration pointer was not populated before update_until",
        )
        require(abs(float(driver.mf6.get_current_time()) * DAY - ENDPOINT) <= TIME_TOL, "actual MF6 time mismatch")
        require(abs(float(driver.ribasim.get_current_time()) - ENDPOINT) <= TIME_TOL, "actual Ribasim time mismatch")

        cumulative_infiltration = float(
            np.asarray(driver.ribasim.get_value_ptr("basin.cumulative_infiltration"), dtype=float)[0]
        )
        cumulative_user = np.asarray(
            driver.ribasim.get_value_ptr("user_demand.cumulative_inflow"), dtype=float
        )
        root_volume = float(cumulative_user[0])
        external_volume = float(cumulative_user[1])
        level = float(driver.ribasim.get_value_ptr("basin.level")[0])
        require(cumulative_infiltration > POSITIVE_CUM_INF, "actual RibaMod infiltration was not physically realized")
        require(abs(external_volume) <= ZERO_TOL, "actual RibaMod external demand supplied unexpectedly")
        print(
            "RIBASIM_REAL_20H2_RIBAMOD_STATE "
            f"pointer_before_update_m3_day={pre_rate} level={level} "
            f"root_m3={root_volume} external_m3={external_volume} "
            f"cumulative_infiltration_m3={cumulative_infiltration}"
        )
    finally:
        driver.finalize()
        os.chdir(original_cwd)

    root_alloc, ext_alloc = h20.read_t0_allocations(root)
    require(abs(root_alloc - 32.0) <= ALLOC_TOL, "actual RibaMod did not reproduce DUMMY-20H 32 m3/day t=0 root allocation")
    require(abs(ext_alloc) <= ALLOC_TOL, "actual RibaMod external allocation is not zero")
    print(
        "RIBASIM_REAL_20H2_RIBAMOD_ALLOC "
        f"root_alloc_m3_day={root_alloc} external_alloc_m3_day={ext_alloc}"
    )
    return {
        "pointer_m3_day": pre_rate,
        "root_alloc": root_alloc,
        "ext_alloc": ext_alloc,
        "level": level,
        "root_volume": root_volume,
        "external_volume": external_volume,
        "cumulative_infiltration": cumulative_infiltration,
    }


def classify(control: dict, injected: dict, product: dict) -> str:
    require(abs(control["root_alloc"] - 32.0) <= ALLOC_TOL, "direct control allocation is not 32 m3/day")
    require(abs(control["ext_alloc"]) <= ALLOC_TOL, "direct control external allocation is not zero")
    require(abs(injected["ext_alloc"]) <= ALLOC_TOL, "direct injected external allocation is not zero")

    injected_is_32 = abs(injected["root_alloc"] - 32.0) <= ALLOC_TOL
    injected_is_reduced = abs(injected["root_alloc"] - EXPECTED_REDUCED_ROOT) <= ALLOC_TOL
    product_pointer_is_8 = abs(product["pointer_m3_day"] - INJECTION_M3_DAY) <= RATE_TOL

    if injected_is_32 and product_pointer_is_8:
        return "RIBASIM_RELEASE_CURRENT_BOUNDARY_BMI_INFILTRATION_NOT_VISIBLE_TO_FIXED_ALLOCATION"
    if injected_is_reduced and product_pointer_is_8:
        return "RIBAMOD_CURRENT_BOUNDARY_COMPOSITION_VISIBILITY_SEAM"
    if not product_pointer_is_8:
        return "RIBAMOD_EXCHANGE_POINTER_TIMING_SEAM"
    return "UNRESOLVED_DIAGNOSTIC_MISMATCH"


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

    control = run_direct(
        root / "direct_control",
        injection_m3_day=0.0,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
        label="control",
    )
    injected = run_direct(
        root / "direct_injection",
        injection_m3_day=INJECTION_M3_DAY,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
        label="injected",
    )
    product = run_actual_ribamod(
        root / "actual_ribamod",
        modflow_dll=modflow_dll,
        ribasim_dll=ribasim_dll,
        ribasim_dep=ribasim_dep,
    )

    classification = classify(control, injected, product)
    require(
        classification != "UNRESOLVED_DIAGNOSTIC_MISMATCH",
        "DUMMY-20H2 outcome falls outside preregistered classification matrix",
    )

    print(
        "RIBASIM_REAL_20H2_CLASSIFICATION "
        f"value={classification} direct_control_root_alloc={control['root_alloc']} "
        f"direct_injected_root_alloc={injected['root_alloc']} "
        f"ribamod_root_alloc={product['root_alloc']} "
        f"ribamod_pre_update_pointer_m3_day={product['pointer_m3_day']}"
    )
    print("RIBASIM_REAL_20H2_VISIBILITY_DIAGNOSTIC=PASS")


if __name__ == "__main__":
    main()
