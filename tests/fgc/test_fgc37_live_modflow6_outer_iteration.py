from __future__ import annotations

import math
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_outer_iteration_host import (
    Modflow6OuterIterationHost,
    Modflow6OuterIterationHostStatus,
    Modflow6OuterIterationPublication,
)
from modflow6_xmi_package_adapter import (
    Modflow6XmiAdapterStatus,
    Modflow6XmiPackageAdapter,
)


@dataclass(frozen=True)
class Binding:
    groundwater_cell_id: int
    package_slot: int
    modflow_node_id: int


@dataclass(frozen=True)
class Term:
    groundwater_cell_id: int
    hcof_m2_per_day: float
    rhs_m3_per_day: float


class CountingXmi:
    def __init__(self, wrapped: XmiWrapper) -> None:
        self.wrapped = wrapped
        self.prepare_time_step_count = 0
        self.prepare_solve_count = 0
        self.solve_count = 0
        self.finalize_solve_count = 0
        self.finalize_time_step_count = 0

    def __getattr__(self, name: str):
        return getattr(self.wrapped, name)

    def prepare_time_step(self, dt: float) -> None:
        self.prepare_time_step_count += 1
        self.wrapped.prepare_time_step(dt)

    def prepare_solve(self, component_id: int = 1) -> None:
        self.prepare_solve_count += 1
        self.wrapped.prepare_solve(component_id)

    def solve(self, component_id: int = 1) -> bool:
        self.solve_count += 1
        return self.wrapped.solve(component_id)

    def finalize_solve(self, component_id: int = 1) -> None:
        self.finalize_solve_count += 1
        self.wrapped.finalize_solve(component_id)

    def finalize_time_step(self) -> None:
        self.finalize_time_step_count += 1
        self.wrapped.finalize_time_step()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_close(actual: float, expected: float, tolerance: float, message: str) -> None:
    if not math.isfinite(actual) or abs(actual - expected) > tolerance:
        raise AssertionError(
            f"{message}: actual={actual:.16g}, expected={expected:.16g}, tol={tolerance:.3g}"
        )


def build_live_model(workdir: Path) -> None:
    sim = flopy.mf6.MFSimulation(
        sim_name="FGC37_LIVE",
        version="mf6",
        sim_ws=str(workdir),
    )
    flopy.mf6.ModflowTdis(
        sim,
        time_units="DAYS",
        nper=1,
        perioddata=[(1.0, 1, 1.0)],
    )
    flopy.mf6.ModflowIms(
        sim,
        complexity="SIMPLE",
        outer_dvclose=1.0e-13,
        inner_dvclose=1.0e-13,
        outer_maximum=100,
        inner_maximum=100,
    )

    gwf = flopy.mf6.ModflowGwf(
        sim,
        modelname="GWF_1",
        save_flows=True,
    )
    flopy.mf6.ModflowGwfdis(
        gwf,
        nlay=1,
        nrow=1,
        ncol=3,
        delr=1.0,
        delc=1.0,
        top=1.0,
        botm=0.0,
    )
    flopy.mf6.ModflowGwfic(gwf, strt=0.5)
    flopy.mf6.ModflowGwfnpf(
        gwf,
        icelltype=0,
        k=1.0,
        save_flows=True,
    )
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={
            0: [
                ((0, 0, 0), 1.0),
                ((0, 0, 2), 0.0),
            ]
        },
        pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(
        gwf,
        maxbound=1,
        pname="API_SWAP",
        filename="api_swap.api",
    )
    sim.write_simulation(silent=True)


class NonlinearQuasiNewtonProvider:
    def __init__(self) -> None:
        self.bindings = [
            Binding(
                groundwater_cell_id=7001,
                package_slot=1,
                modflow_node_id=2,
            )
        ]
        self.reference_heads: list[float] = []
        self.rhs_history: list[float] = []

    def __call__(self, head: np.ndarray, iteration: int) -> Modflow6OuterIterationPublication:
        del iteration
        h_ref = float(head[1])
        q_star = 0.06 - 0.1 * h_ref + 0.5 * (h_ref - 0.5) ** 2

        hcof = -0.1
        rhs = hcof * h_ref - q_star

        self.reference_heads.append(h_ref)
        self.rhs_history.append(rhs)

        return Modflow6OuterIterationPublication(
            bindings=self.bindings,
            terms=[
                Term(
                    groundwater_cell_id=7001,
                    hcof_m2_per_day=hcof,
                    rhs_m3_per_day=rhs,
                )
            ],
        )


def analytic_small_root() -> float:
    # 2H = 1 + 0.06 - 0.1H + 0.5(H-0.5)^2
    # => 0.5 H^2 - 2.6 H + 1.185 = 0
    return 2.6 - math.sqrt(4.39)


def test_live_outer_iteration(
    libmf6: Path,
    publisher: Fgc34CtypesPublisher,
) -> None:
    with tempfile.TemporaryDirectory(prefix="fgc37-live-") as tmp:
        workdir = Path(tmp)
        build_live_model(workdir)

        wrapped = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingXmi(wrapped)
        initialized = False
        try:
            kernel.initialize()
            initialized = True
            require("6.8.0" in kernel.get_version(), "unexpected MODFLOW6 version")

            adapter = Modflow6XmiPackageAdapter(kernel, "GWF_1", "API_SWAP")
            status = adapter.acquire_after_initialize()
            require(
                status == Modflow6XmiAdapterStatus.OK,
                f"F-GC35 acquisition failed: {adapter.last_error}",
            )

            provider = NonlinearQuasiNewtonProvider()
            host = Modflow6OuterIterationHost(
                kernel,
                adapter,
                publisher,
                "GWF_1",
                monitored_head_indices=[1],
                head_tolerance_m=1.0e-11,
                max_iterations=20,
            )

            result = host.solve_candidate(provider)
            require(
                result.status == Modflow6OuterIterationHostStatus.OK,
                f"outer iteration failed at {result.failure_stage}: {result.message}",
            )
            require(result.converged and result.candidate_ready, "candidate not ready")
            require(not result.committed, "solve_candidate committed the timestep")
            require(not result.requires_reinitialize, "successful candidate requires reinit")

            require(kernel.prepare_time_step_count == 1, "prepare_time_step count mismatch")
            require(kernel.prepare_solve_count == 1, "prepare_solve count mismatch")
            require(kernel.solve_count >= 2, "outer host did not perform repeated MODFLOW solves")
            require(kernel.finalize_solve_count == 1, "finalize_solve count mismatch")
            require(
                kernel.finalize_time_step_count == 0,
                "solve_candidate performed irreversible timestep finalization",
            )

            require(result.publication_count >= 2, "no iterative F-GC34 republication occurred")
            require(
                len(provider.rhs_history) == result.publication_count,
                "provider/publication count mismatch",
            )
            require(
                any(
                    abs(provider.rhs_history[i] - provider.rhs_history[0]) > 1.0e-15
                    for i in range(1, len(provider.rhs_history))
                ),
                "outer-iteration RHS never changed",
            )
            require(
                adapter.generation == 1 and adapter.view is not None and adapter.view.generation == 1,
                "F-GC35 generation changed during prepared solve",
            )

            expected = analytic_small_root()
            actual = float(result.final_monitored_head_m[0])
            require_close(actual, expected, 2.0e-10, "nonlinear coupled head closure")

            commit = host.commit_candidate()
            require(
                commit.status == Modflow6OuterIterationHostStatus.OK and commit.committed,
                f"candidate commit failed: {commit.message}",
            )
            require(
                kernel.finalize_time_step_count == 1,
                "explicit commit did not finalize exactly one timestep",
            )

            kernel.finalize()
            initialized = False

            print(f"FGC37_PUBLICATION_COUNT={result.publication_count}")
            print(f"FGC37_SOLVE_COUNT={kernel.solve_count}")
            print(f"FGC37_FINAL_HEAD={actual:.16g}")
            print(f"FGC37_ANALYTIC_HEAD={expected:.16g}")
            print("FGC37_SINGLE_PREPARED_SOLVE_LIFECYCLE=PASS")
            print("FGC37_REPEATED_REAL_FGC34_PUBLICATION=PASS")
            print("FGC37_SAME_XMI_GENERATION=PASS")
            print("FGC37_NONLINEAR_ANALYTICAL_HEAD_CLOSURE=PASS")
            print("FGC37_CANDIDATE_BEFORE_TIMESTEP_COMMIT=PASS")
            print("FGC37_EXPLICIT_TIMESTEP_COMMIT=PASS")
            print("FGC37_LIVE_MODFLOW6_OUTER_ITERATION_GATE=PASS")
        finally:
            if initialized:
                kernel.finalize()



def test_live_nonconvergence_fail_closed(
    libmf6: Path,
    publisher: Fgc34CtypesPublisher,
) -> None:
    with tempfile.TemporaryDirectory(prefix="fgc37-fail-closed-") as tmp:
        workdir = Path(tmp)
        build_live_model(workdir)

        wrapped = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingXmi(wrapped)
        initialized = False
        try:
            kernel.initialize()
            initialized = True

            adapter = Modflow6XmiPackageAdapter(kernel, "GWF_1", "API_SWAP")
            status = adapter.acquire_after_initialize()
            require(
                status == Modflow6XmiAdapterStatus.OK,
                f"fail-closed F-GC35 acquisition failed: {adapter.last_error}",
            )

            host = Modflow6OuterIterationHost(
                kernel,
                adapter,
                publisher,
                "GWF_1",
                monitored_head_indices=[1],
                head_tolerance_m=0.0,
                max_iterations=1,
            )

            result = host.solve_candidate(NonlinearQuasiNewtonProvider())
            require(
                result.status == Modflow6OuterIterationHostStatus.NOT_CONVERGED,
                f"expected bounded nonconvergence, got {result.status}: {result.message}",
            )
            require(not result.candidate_ready and not result.committed, "failed solve published a candidate")
            require(result.requires_reinitialize, "failed prepared solve did not require reinitialization")
            require(host.requires_reinitialize, "host did not retain reinitialization requirement")
            require(kernel.prepare_solve_count == 1, "fail-closed prepare_solve count mismatch")
            require(kernel.solve_count == 1, "fail-closed solve count mismatch")
            require(kernel.finalize_solve_count == 0, "nonconverged solve called finalize_solve")
            require(
                kernel.finalize_time_step_count == 0,
                "nonconverged solve called finalize_time_step",
            )

            commit = host.commit_candidate()
            require(
                commit.status == Modflow6OuterIterationHostStatus.REINITIALIZATION_REQUIRED,
                "failed prepared solve was still committable",
            )
            require(
                kernel.finalize_time_step_count == 0,
                "rejected commit finalized the failed timestep",
            )

            kernel.finalize()
            initialized = False

            print("FGC37_NONCONVERGENCE_FAIL_CLOSED=PASS")
            print("FGC37_FAILED_PREPARED_SOLVE_REQUIRES_REINITIALIZATION=PASS")
            print("FGC37_FAILED_SOLVE_NO_TIMESTEP_PUBLICATION=PASS")
        finally:
            if initialized:
                kernel.finalize()


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    bridge_library = Path(os.environ["FGC34_BRIDGE_LIB"]).resolve()
    require(libmf6.is_file(), f"LIBMF6 does not exist: {libmf6}")
    require(bridge_library.is_file(), f"FGC34 bridge does not exist: {bridge_library}")

    publisher = Fgc34CtypesPublisher(bridge_library)
    test_live_outer_iteration(libmf6, publisher)
    test_live_nonconvergence_fail_closed(libmf6, publisher)


if __name__ == "__main__":
    main()
