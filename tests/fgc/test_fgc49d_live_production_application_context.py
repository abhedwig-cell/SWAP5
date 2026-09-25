from __future__ import annotations

import ctypes
import os
import sys
import tempfile
import time
from pathlib import Path

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from fmr_groundwater_application_runtime import FmrGroundwaterApplicationRuntime
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_groundwater_application_service import (
    GroundwaterApplicationServiceConfig,
    GroundwaterApplicationServiceStatus,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveStatus,
)

WINDOW_DAY = 1.0e-4
FLUX_TOL = 1.0e-15


class CountingKernel:
    def __init__(self, kernel: XmiWrapper) -> None:
        self.kernel = kernel
        self.prepare_solve_calls = 0
        self.solve_calls = 0
        self.finalize_solve_calls = 0
        self.finalize_time_step_calls = 0

    def __getattr__(self, name):
        return getattr(self.kernel, name)

    def prepare_solve(self, solution_id: int) -> None:
        self.prepare_solve_calls += 1
        self.kernel.prepare_solve(solution_id)

    def solve(self, solution_id: int) -> bool:
        self.solve_calls += 1
        return bool(self.kernel.solve(solution_id))

    def finalize_solve(self, solution_id: int) -> None:
        self.finalize_solve_calls += 1
        self.kernel.finalize_solve(solution_id)

    def finalize_time_step(self) -> None:
        self.finalize_time_step_calls += 1
        self.kernel.finalize_time_step()


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def fixture_initialize(lib: ctypes.CDLL) -> tuple[int, float, float]:
    fn = lib.fgc49d_fixture_initialize_c
    fn.restype = ctypes.c_int
    fn.argtypes = [
        ctypes.POINTER(ctypes.c_int64),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
    ]
    handle = ctypes.c_int64()
    h1 = ctypes.c_double()
    h2 = ctypes.c_double()
    require(
        int(fn(ctypes.byref(handle), ctypes.byref(h1), ctypes.byref(h2))) == 0,
        "fixture initialization",
    )
    return int(handle.value), float(h1.value), float(h2.value)


def fixture_state(lib: ctypes.CDLL) -> tuple[int, int, int, int, int, int]:
    fn = lib.fgc49d_fixture_state_c
    fn.restype = ctypes.c_int
    fn.argtypes = [ctypes.POINTER(ctypes.c_int)] * 6
    values = [ctypes.c_int() for _ in range(6)]
    require(
        int(fn(*[ctypes.byref(value) for value in values])) == 0,
        "fixture state",
    )
    return tuple(int(value.value) for value in values)


def build_model(workdir: Path, href1: float, href2: float) -> None:
    sim = flopy.mf6.MFSimulation(
        sim_name="FGC49D_PRODUCTION_ABI",
        version="mf6",
        sim_ws=str(workdir),
    )
    flopy.mf6.ModflowTdis(
        sim,
        time_units="DAYS",
        nper=1,
        perioddata=[(WINDOW_DAY, 1, 1.0)],
    )
    flopy.mf6.ModflowIms(
        sim,
        complexity="MODERATE",
        outer_dvclose=1.0e-11,
        inner_dvclose=1.0e-12,
        outer_maximum=100,
        inner_maximum=100,
    )
    gwf = flopy.mf6.ModflowGwf(
        sim,
        modelname="GWF_1",
        save_flows=True,
        newtonoptions="NEWTON",
    )
    flopy.mf6.ModflowGwfdis(
        gwf,
        nlay=1,
        nrow=1,
        ncol=4,
        delr=1.0,
        delc=1.0,
        top=0.0,
        botm=-2.0,
    )
    flopy.mf6.ModflowGwfic(
        gwf,
        strt=np.array([[[href1, href1, href2, href2]]], dtype=float),
    )
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=1, k=1.0, save_flows=True)
    flopy.mf6.ModflowGwfsto(
        gwf,
        iconvert=1,
        ss=0.02,
        sy=0.15,
        transient={0: True},
    )
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={
            0: [
                ((0, 0, 0), href1 + 0.002),
                ((0, 0, 3), href2 - 0.002),
            ]
        },
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(
        gwf,
        maxbound=2,
        pname="API_SWAP",
        filename="api_swap.api",
    )
    sim.write_simulation(silent=True)


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    application_lib = Path(os.environ["FGC49D_APPLICATION_LIB"]).resolve()
    require(libmf6.is_file(), "missing MODFLOW6 library")
    require(application_lib.is_file(), "missing F-GC49D production ABI library")

    print('APPQUAL01_B0_STAGE=LOAD_BRIDGE', flush=True)
    bridge = ctypes.CDLL(str(application_lib))
    print('APPQUAL01_B0_STAGE=FIXTURE_INITIALIZE_BEGIN', flush=True)
    handle, href1, href2 = fixture_initialize(bridge)
    print('APPQUAL01_B0_STAGE=FIXTURE_INITIALIZE_DONE', flush=True)
    runtime = FmrGroundwaterApplicationRuntime(application_lib, handle)
    require(fixture_state(bridge) == (0, 0, 0, 0, 0, 0), "clean accepted origin")
    require(tuple(runtime.materialize_plan().cell_ids) == (7001, 7002), "canonical cell plan")
    require(
        tuple(tile.groundwater_cell_id for tile in runtime.tiles) == (7001, 7001, 7002),
        "production ABI mixed topology",
    )

    with tempfile.TemporaryDirectory(prefix="fgc49d-live-") as tmp:
        workdir = Path(tmp)
        build_model(workdir, href1, href2)
        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingKernel(raw)
        publisher = Fgc34CtypesPublisher(application_lib)
        initialized = False
        try:
            print('APPQUAL01_B0_STAGE=MF6_INITIALIZE_BEGIN', flush=True)
            raw.initialize()
            initialized = True
            print('APPQUAL01_B0_STAGE=MF6_INITIALIZE_DONE', flush=True)
            require("6.8.0" in raw.get_version(), "wrong MODFLOW version")
            print('APPQUAL01_B0_STAGE=MF6_PREPARE_TIMESTEP_BEGIN', flush=True)
            raw.prepare_time_step(0.0)
            print('APPQUAL01_B0_STAGE=MF6_PREPARE_TIMESTEP_DONE', flush=True)

            session = Modflow6PreparedSolveSession(
                kernel,
                "GWF_1",
                "API_SWAP",
                publisher,
                solution_id=1,
            )
            print('APPQUAL01_B0_STAGE=COUPLING_BEGIN', flush=True)
            coupling_start = time.perf_counter()
            result = run_groundwater_application_window(
                runtime,
                session,
                GroundwaterApplicationServiceConfig(
                    flux_tolerance_m_per_s=FLUX_TOL,
                    max_coupling_iterations=40,
                ),
            )

            coupling_seconds = time.perf_counter() - coupling_start
            print('APPQUAL01_B0_STAGE=COUPLING_DONE', flush=True)
            require(
                result.status == GroundwaterApplicationServiceStatus.OK,
                f"production ABI live service failed at {result.failure_stage}",
            )
            require(result.published, "whole window was not published")
            require(result.iterations >= 2, "live case unexpectedly skipped coupling")
            require(len(result.final_residuals_m_per_s) == 2, "missing two cell residuals")
            require(
                max(abs(value) for value in result.final_residuals_m_per_s) <= FLUX_TOL,
                "per-cell residual tolerance",
            )
            require(kernel.prepare_solve_calls == 1, "prepare_solve not exactly once")
            require(kernel.finalize_solve_calls == 1, "finalize_solve not exactly once")
            require(kernel.finalize_time_step_calls == 1, "finalize_time_step not exactly once")
            require(list(session.nodelist[:2]) == [2, 3], "F-GC34 canonical node routing")
            require(
                session.finalize_time_step_once()
                == PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,
                "second timestep publication not blocked",
            )
            require(
                fixture_state(bridge) == (1, 1, 1, 1, 1, 1),
                "three SWAP and three ledger publications",
            )

            raw.finalize()
            initialized = False
            runtime.release()

            print(f"FGC49D_LIVE_ITERATIONS={result.iterations}")
            print(f"FGC49D_LIVE_MODFLOW_SOLVE_CALLS={kernel.solve_calls}")
            print(f"FGC49D_LIVE_COUPLING_SECONDS={coupling_seconds:.17g}")
            print(
                "FGC49D_LIVE_MAX_CELL_RESIDUAL_M_PER_S="
                f"{max(abs(value) for value in result.final_residuals_m_per_s):.17g}"
            )
            print("FGC49D_LIVE_MODFLOW6_6_8_0=PASS")
            print("FGC49D_LIVE_PRODUCTION_FMR_ABI=PASS")
            print("FGC49D_LIVE_MIXED_N1_AND_11_TOPOLOGY=PASS")
            print("FGC49D_LIVE_ONE_PREPARED_SOLVE=PASS")
            print("FGC49D_LIVE_PER_CELL_CONJUNCTIVE_CONVERGENCE=PASS")
            print("FGC49D_LIVE_MODFLOW_SWAP_LEDGER_PUBLICATION=PASS")
            print("FGC49D_LIVE_THREE_REAL_SWAP_AND_LEDGER_COMMITS=PASS")
            print("F-GC49D LIVE PRODUCTION APPLICATION CONTEXT ABI GATE PASS")
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


if __name__ == "__main__":
    main()
