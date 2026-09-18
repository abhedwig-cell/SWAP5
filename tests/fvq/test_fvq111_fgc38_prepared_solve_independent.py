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


def require(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError(message)


def build_model(workdir: Path) -> None:
    sim = flopy.mf6.MFSimulation(
        sim_name="FVQ111",
        version="mf6",
        sim_ws=str(workdir),
    )
    flopy.mf6.ModflowTdis(
        sim,
        time_units="DAYS",
        nper=1,
        perioddata=[(0.5, 1, 1.0)],
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
        top=1.0,
        botm=0.0,
    )
    flopy.mf6.ModflowGwfic(gwf, strt=0.52)
    flopy.mf6.ModflowGwfnpf(
        gwf,
        icelltype=1,
        k=1.0,
        save_flows=True,
    )
    flopy.mf6.ModflowGwfsto(
        gwf,
        iconvert=1,
        ss=0.015,
        sy=0.12,
        transient={0: True},
    )
    flopy.mf6.ModflowGwfchd(
        gwf,
        stress_period_data={
            0: [
                ((0, 0, 0), 0.95),
                ((0, 0, 3), 0.15),
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


def run_case(
    libmf6: Path,
    bridge: Path,
    response_sequence: list[list[Term]],
) -> tuple[np.ndarray, np.ndarray, list[np.ndarray], CountingKernel]:
    with tempfile.TemporaryDirectory(prefix="fvq111-") as tmp:
        workdir = Path(tmp)
        build_model(workdir)

        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingKernel(raw)
        publisher = Fgc34CtypesPublisher(bridge)

        bindings = [
            Binding(groundwater_cell_id=9202, package_slot=2, modflow_node_id=3),
            Binding(groundwater_cell_id=9101, package_slot=1, modflow_node_id=2),
        ]

        initialized = False
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW version")
            raw.prepare_time_step(0.0)

            session = Modflow6PreparedSolveSession(
                kernel,
                "GWF_1",
                "API_SWAP",
                publisher,
                solution_id=1,
            )
            require(
                session.acquire_after_prepare_time_step() == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(kernel.prepare_solve_calls == 1, "prepare_solve repeated")
            require(session.maxbound == 2, "MAXBOUND != 2")
            require(session.accepted_xold is not None, "missing accepted XOLD")
            accepted_xold = session.accepted_xold.copy()

            heads: list[np.ndarray] = []
            final_terms = response_sequence[-1]

            for terms in response_sequence[:-1]:
                status, iteration = session.publish_and_solve_iteration(bindings, terms)
                require(status == PreparedSolveStatus.OK, session.last_error)
                require(iteration is not None, "missing iteration")
                require(
                    np.array_equal(iteration.accepted_head_old_m, accepted_xold),
                    "XOLD drifted before final response",
                )
                require(session.nbound is not None and int(session.nbound[0]) == 2, "NBOUND != 2")
                require(
                    session.nodelist is not None
                    and np.array_equal(session.nodelist[:2], np.array([2, 3], dtype=np.int32)),
                    "NODELIST mismatch",
                )
                heads.append(iteration.head_m)

            converged = False
            stabilized = False
            previous: np.ndarray | None = None
            stabilization_delta = math.inf

            for _ in range(session.max_solve_iterations - session.iteration_count):
                status, iteration = session.publish_and_solve_iteration(bindings, final_terms)
                require(status == PreparedSolveStatus.OK, session.last_error)
                require(iteration is not None, "missing final iteration")
                require(
                    np.array_equal(iteration.accepted_head_old_m, accepted_xold),
                    "XOLD drifted under final response",
                )
                heads.append(iteration.head_m)

                converged = converged or iteration.modflow_converged
                if previous is not None:
                    stabilization_delta = float(
                        np.max(np.abs(iteration.head_m - previous))
                    )
                    if converged and stabilization_delta <= 5.0e-13:
                        stabilized = True
                        break
                previous = iteration.head_m.copy()

            require(converged, "MODFLOW did not converge")
            require(stabilized, f"final response did not stabilize: {stabilization_delta}")

            require(
                session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(kernel.prepare_solve_calls == 1, "prepare_solve count mismatch")
            require(kernel.finalize_solve_calls == 1, "finalize_solve count mismatch")
            require(kernel.finalize_time_step_calls == 0, "backend accepted timestep")
            require(session.head is not None and session.xold is not None, "missing live heads")
            require(np.array_equal(session.xold, accepted_xold), "XOLD drift before timestep finalize")

            final_head = session.head.copy()
            raw.finalize_time_step()
            raw.finalize()
            initialized = False

            return final_head, accepted_xold, heads, kernel
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    bridge = Path(os.environ["FGC34_BRIDGE_LIB"]).resolve()
    require(libmf6.is_file(), "missing official libmf6")
    require(bridge.is_file(), "missing F-GC34 bridge")

    a = [
        Term(9101, -0.05, -0.020),
        Term(9202, -0.08, -0.030),
    ]
    b = [
        Term(9101, -0.18, -0.090),
        Term(9202, -0.25, -0.115),
    ]
    c = [
        Term(9101, -0.10, -0.048),
        Term(9202, -0.14, -0.060),
    ]

    iterative_head, iterative_xold, heads, iterative_kernel = run_case(
        libmf6, bridge, [a, b, c]
    )
    clean_head, clean_xold, clean_heads, clean_kernel = run_case(
        libmf6, bridge, [c]
    )

    require(len(heads) >= 3, "A/B/C path too short")
    require(
        any(
            not np.allclose(heads[i], heads[i + 1], rtol=0.0, atol=1.0e-14)
            for i in range(len(heads) - 1)
        ),
        "X did not evolve during prepared solve",
    )
    require(np.array_equal(iterative_xold, clean_xold), "accepted XOLD differs between kernels")

    scale = max(
        1.0,
        float(np.max(np.abs(iterative_head))),
        float(np.max(np.abs(clean_head))),
    )
    tolerance = math.sqrt(float(np.finfo(np.float64).eps)) * scale
    max_diff = float(np.max(np.abs(iterative_head - clean_head)))

    require(
        np.allclose(iterative_head, clean_head, rtol=0.0, atol=tolerance),
        f"multi-slot A->B->C path differs from clean C-only: diff={max_diff}, tol={tolerance}",
    )
    require(iterative_kernel.prepare_solve_calls == 1, "iterative prepare_solve != 1")
    require(iterative_kernel.finalize_solve_calls == 1, "iterative finalize_solve != 1")
    require(clean_kernel.prepare_solve_calls == 1, "clean prepare_solve != 1")
    require(clean_kernel.finalize_solve_calls == 1, "clean finalize_solve != 1")

    print(f"FVQ111_FINAL_HEAD_MAX_ABS_DIFF={max_diff:.17g}")
    print(f"FVQ111_PATH_EQUIVALENCE_TOLERANCE={tolerance:.17g}")
    print(f"FVQ111_SOLVE_COUNTS=iterative:{iterative_kernel.solve_calls},clean:{clean_kernel.solve_calls}")
    print("FVQ111_OFFICIAL_MODFLOW680_LOADED=PASS")
    print("FVQ111_TWO_SLOT_PREPARED_SOLVE=PASS")
    print("FVQ111_SHUFFLED_BINDING_PUBLICATION=PASS")
    print("FVQ111_XOLD_ACCEPTED_ORIGIN_FIXED=PASS")
    print("FVQ111_X_EVOLVES_WITHIN_PREPARED_SOLVE=PASS")
    print("FVQ111_MULTI_SLOT_REPUBLISH_BETWEEN_SOLVES=PASS")
    print("FVQ111_CLEAN_FINAL_RESPONSE_EQUIVALENCE=PASS")
    print("FVQ111_FINALIZE_SOLVE_EXACTLY_ONCE=PASS")
    print("FVQ111_BACKEND_DOES_NOT_FINALIZE_TIMESTEP=PASS")
    print("FVQ111_INDEPENDENT_PREPARED_SOLVE_GATE=PASS")


if __name__ == "__main__":
    main()
