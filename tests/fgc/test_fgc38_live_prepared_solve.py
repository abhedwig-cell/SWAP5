from __future__ import annotations

import math
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveStatus,
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


class CountingKernel:
    def __init__(self, kernel: XmiWrapper) -> None:
        self.kernel = kernel
        self.prepare_solve_calls = 0
        self.solve_calls = 0
        self.finalize_solve_calls = 0
        self.finalize_time_step_calls = 0

    def __getattr__(self, name: str) -> Any:
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


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_allclose(
    actual: np.ndarray,
    expected: np.ndarray,
    tolerance: float,
    message: str,
) -> None:
    max_abs_diff = float(np.max(np.abs(actual - expected)))
    if not np.all(np.isfinite(actual)) or not np.allclose(
        actual, expected, rtol=0.0, atol=tolerance
    ):
        raise AssertionError(
            f"{message}: actual={np.array2string(actual, precision=17)}, "
            f"expected={np.array2string(expected, precision=17)}, "
            f"max_abs_diff={max_abs_diff:.17g}, tol={tolerance:.17g}"
        )


def build_model(workdir: Path) -> None:
    sim = flopy.mf6.MFSimulation(
        sim_name="FGC38_PREPARED_SOLVE",
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
        ncol=3,
        delr=1.0,
        delc=1.0,
        top=1.0,
        botm=0.0,
    )
    flopy.mf6.ModflowGwfic(gwf, strt=0.55)
    flopy.mf6.ModflowGwfnpf(
        gwf,
        icelltype=1,
        k=1.0,
        save_flows=True,
    )
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
                ((0, 0, 0), 0.9),
                ((0, 0, 2), 0.2),
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


def run_case(
    libmf6: Path,
    bridge: Path,
    response_sequence: list[Term],
) -> tuple[np.ndarray, np.ndarray, list[np.ndarray], CountingKernel]:
    with tempfile.TemporaryDirectory(prefix="fgc38-") as tmp:
        workdir = Path(tmp)
        build_model(workdir)

        raw_kernel = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingKernel(raw_kernel)
        publisher = Fgc34CtypesPublisher(bridge)
        bindings = [Binding(7001, 1, 2)]

        initialized = False
        timestep_prepared = False
        try:
            raw_kernel.initialize()
            initialized = True
            require("6.8.0" in raw_kernel.get_version(), "wrong MODFLOW version")
            raw_kernel.prepare_time_step(0.0)
            timestep_prepared = True

            session = Modflow6PreparedSolveSession(
                kernel,
                "GWF_1",
                "API_SWAP",
                publisher,
                solution_id=1,
            )
            status = session.acquire_after_prepare_time_step()
            require(status == PreparedSolveStatus.OK, session.last_error)
            status = session.open_prepared_solve()
            require(status == PreparedSolveStatus.OK, session.last_error)

            require(kernel.prepare_solve_calls == 1, "prepare_solve count mismatch")
            accepted_xold = session.accepted_xold.copy()
            heads: list[np.ndarray] = []

            # Every response before the last receives exactly one MODFLOW
            # nonlinear iteration. The final response is then held fixed until
            # MODFLOW reports convergence.
            for term in response_sequence[:-1]:
                status, iteration = session.publish_and_solve_iteration(
                    bindings, [term]
                )
                require(status == PreparedSolveStatus.OK, session.last_error)
                require(iteration is not None, "missing iteration result")
                require_allclose(
                    iteration.accepted_head_old_m,
                    accepted_xold,
                    0.0,
                    "XOLD drifted during external iteration",
                )
                heads.append(iteration.head_m)

            final_term = response_sequence[-1]
            converged = False
            for _ in range(100):
                status, iteration = session.publish_and_solve_iteration(
                    bindings, [final_term]
                )
                require(status == PreparedSolveStatus.OK, session.last_error)
                require(iteration is not None, "missing final-response iteration")
                require_allclose(
                    iteration.accepted_head_old_m,
                    accepted_xold,
                    0.0,
                    "XOLD drifted while final response was held",
                )
                heads.append(iteration.head_m)
                if iteration.modflow_converged:
                    converged = True
                    break
            require(converged, "MODFLOW did not converge under final response")

            status = session.finalize_prepared_solve()
            require(status == PreparedSolveStatus.OK, session.last_error)
            require(kernel.prepare_solve_calls == 1, "prepare_solve repeated")
            require(kernel.finalize_solve_calls == 1, "finalize_solve count mismatch")
            require(
                kernel.finalize_time_step_calls == 0,
                "backend/session finalized the timestep",
            )
            require(session.head is not None, "head pointer missing")
            final_head = session.head.copy()
            require_allclose(
                session.xold,
                accepted_xold,
                0.0,
                "XOLD changed before finalize_time_step",
            )

            raw_kernel.finalize_time_step()
            timestep_prepared = False
            raw_kernel.finalize()
            initialized = False

            return final_head, accepted_xold, heads, kernel
        finally:
            if initialized:
                # If the gate itself fails, tear down the kernel.  The test does
                # not represent that torn-down state as an accepted candidate.
                try:
                    if timestep_prepared:
                        pass
                    raw_kernel.finalize()
                except Exception:
                    pass


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    bridge = Path(os.environ["FGC34_BRIDGE_LIB"]).resolve()
    require(libmf6.is_file(), f"missing LIBMF6: {libmf6}")
    require(bridge.is_file(), f"missing FGC34 bridge: {bridge}")

    response_a = Term(7001, hcof_m2_per_day=-0.04, rhs_m3_per_day=-0.018)
    response_b = Term(7001, hcof_m2_per_day=-0.30, rhs_m3_per_day=-0.165)
    response_c = Term(7001, hcof_m2_per_day=-0.12, rhs_m3_per_day=-0.066)

    iterative_head, iterative_xold, heads, iterative_kernel = run_case(
        libmf6,
        bridge,
        [response_a, response_b, response_c],
    )
    clean_head, clean_xold, clean_heads, clean_kernel = run_case(
        libmf6,
        bridge,
        [response_c],
    )

    require(len(heads) >= 3, "iterative case did not execute at least A, B and C")
    require(iterative_kernel.solve_calls >= 3, "too few iterative solve calls")
    require(iterative_kernel.prepare_solve_calls == 1, "iterative prepare_solve repeated")
    require(iterative_kernel.finalize_solve_calls == 1, "iterative finalize_solve repeated")

    require(
        any(
            not np.allclose(heads[i], heads[i + 1], rtol=0.0, atol=1.0e-14)
            for i in range(len(heads) - 1)
        ),
        "current X did not evolve through prepared solve",
    )
    require_allclose(
        iterative_xold,
        clean_xold,
        0.0,
        "independent kernels did not start from same accepted XOLD",
    )
    print("FGC38_ITERATIVE_FINAL_HEAD=" + np.array2string(iterative_head, precision=17))
    print("FGC38_CLEAN_FINAL_HEAD=" + np.array2string(clean_head, precision=17))
    print(
        "FGC38_FINAL_HEAD_MAX_ABS_DIFF="
        f"{float(np.max(np.abs(iterative_head - clean_head))):.17g}"
    )
    print(
        "FGC38_SOLVE_COUNTS="
        f"iterative:{iterative_kernel.solve_calls},clean:{clean_kernel.solve_calls}"
    )
    require_allclose(
        iterative_head,
        clean_head,
        2.0e-10,
        "A->B->C path does not close to clean C-only converged solution",
    )

    require(
        clean_kernel.prepare_solve_calls == 1
        and clean_kernel.finalize_solve_calls == 1,
        "clean reference lifecycle mismatch",
    )

    print("FGC38_OFFICIAL_MODFLOW680_LOADED=PASS")
    print("FGC38_ONE_PREPARE_SOLVE_PER_WINDOW=PASS")
    print("FGC38_XOLD_ACCEPTED_ORIGIN_FIXED=PASS")
    print("FGC38_X_EVOLVES_WITHIN_PREPARED_SOLVE=PASS")
    print("FGC38_LIVE_FGC34_REPUBLISH_BETWEEN_SOLVES=PASS")
    print("FGC38_FINAL_RESPONSE_CONVERGED=PASS")
    print("FGC38_CLEAN_ORIGIN_EQUIVALENCE=PASS")
    print("FGC38_FINALIZE_SOLVE_EXACTLY_ONCE=PASS")
    print("FGC38_BACKEND_DOES_NOT_FINALIZE_TIMESTEP=PASS")
    print("FGC38_PREPARED_SOLVE_ITERATIVE_BACKEND_GATE=PASS")


if __name__ == "__main__":
    main()
