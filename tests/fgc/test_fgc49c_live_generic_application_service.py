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
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc47_mixed_topology_ctypes import Fgc47MixedTopology
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_groundwater_application_service import (
    GroundwaterApplicationCorrectorBatch,
    GroundwaterApplicationPlanView,
    GroundwaterApplicationServiceConfig,
    GroundwaterApplicationServiceStatus,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveStatus,
)

DAY_TO_S = 86400.0
AREA_M2 = 1.0
WINDOW_DAY = 1.0e-4
FLUX_TOL = 1.0e-15
F1 = 0.35
F2 = 0.65


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


class Fgc47QualificationRuntime:
    """Test-only adapter around the already-qualified F-GC47 bridge.

    This exists only to prove the generic production Python service against
    real FMR/SWAP + live MODFLOW6. It is not the production FMR ABI.
    """

    def __init__(self, bridge: Path) -> None:
        self.swap = Fgc47MixedTopology(bridge)
        hcof1, rhs1, href1, hcof2, rhs2, href2 = self.swap.initialize()
        self.bindings = (
            Binding(7001, 1, 2),
            Binding(7002, 2, 3),
        )
        self.terms = (
            Term(7001, hcof1, rhs1),
            Term(7002, hcof2, rhs2),
        )
        self.reference_heads = (href1, href2)
        self.last_components: tuple[float, float, float] | None = None
        self.events: list[str] = []

    def materialize_plan(self) -> GroundwaterApplicationPlanView:
        self.events.append("plan")
        return GroundwaterApplicationPlanView(
            bindings=self.bindings,
            terms=self.terms,
            cell_ids=(7001, 7002),
        )

    def capture_origins(self) -> bool:
        # The qualification bridge captures all three accepted origins during
        # initialization. No new state mutation happens here.
        self.events.append("origins")
        return True

    def evaluate_groundwater_fluxes(self, terms, cell_heads_m):
        self.events.append("evaluate")
        values = []
        for term, head in zip(terms, cell_heads_m, strict=True):
            values.append(
                (
                    term.hcof_m2_per_day * float(head)
                    - term.rhs_m3_per_day
                )
                / (AREA_M2 * DAY_TO_S)
            )
        return tuple(values)

    def trial_cell_heads(self, cell_heads_m):
        self.events.append("trial")
        qc1, qc2, q1, q2, q3 = self.swap.trial(
            float(cell_heads_m[0]), float(cell_heads_m[1])
        )
        tol1 = 8.0 * np.finfo(float).eps * max(1.0, abs(qc1))
        tol2 = 8.0 * np.finfo(float).eps * max(1.0, abs(qc2))
        if abs(qc1 - (F1 * q1 + F2 * q2)) > tol1:
            return GroundwaterApplicationCorrectorBatch(False, ())
        if abs(qc2 - q3) > tol2:
            return GroundwaterApplicationCorrectorBatch(False, ())
        self.last_components = (q1, q2, q3)
        slopes = tuple(
            term.hcof_m2_per_day / (AREA_M2 * DAY_TO_S) for term in self.terms
        )
        return GroundwaterApplicationCorrectorBatch(True, (qc1, qc2), slopes)

    def discard_candidates(self) -> bool:
        self.events.append("discard")
        self.swap.discard()
        return True

    def relinearize_terms(
        self, cell_heads_m, cell_q_swap_m_per_s, cell_dq_swap_dh_per_s
    ):
        self.events.append("reanchor")
        updated = []
        for old, head, qswap, slope in zip(
            self.terms,
            cell_heads_m,
            cell_q_swap_m_per_s,
            cell_dq_swap_dh_per_s,
            strict=True,
        ):
            hcof = float(slope) * AREA_M2 * DAY_TO_S
            updated.append(
                Term(
                    old.groundwater_cell_id,
                    hcof,
                    hcof * float(head) - float(qswap) * AREA_M2 * DAY_TO_S,
                )
            )
        self.terms = tuple(updated)
        return self.terms

    def swap_preflight(self) -> bool:
        self.events.append("swap_preflight")
        return self.swap.swap_preflight()

    def prepare_ledgers(self) -> bool:
        self.events.append("ledger_prepare")
        self.swap.prepare_ledgers()
        return True

    def ledgers_preflight(self) -> bool:
        self.events.append("ledger_preflight")
        return self.swap.ledgers_preflight()

    def abort_prepublication(self) -> bool:
        self.events.append("abort")
        self.swap.abort_prepublication()
        return True

    def commit_swaps(self) -> bool:
        self.events.append("swap_commit")
        self.swap.commit_swaps()
        return True

    def commit_ledgers(self) -> bool:
        self.events.append("ledger_commit")
        self.swap.commit_ledgers()
        return True


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def build_model(workdir: Path, href1: float, href2: float) -> None:
    sim = flopy.mf6.MFSimulation(
        sim_name="FGC49C_GENERIC_MIXED",
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
    bridge = Path(os.environ["FGC49C_MIXED_LIB"]).resolve()
    require(libmf6.is_file(), "missing MODFLOW library")
    require(bridge.is_file(), "missing qualification bridge")

    runtime = Fgc47QualificationRuntime(bridge)
    href1, href2 = runtime.reference_heads
    state0 = runtime.swap.state()
    require(state0[:3] == (0, 0, 0), "accepted SWAP origins not at revision zero")
    require(state0[6:9] == (0, 0, 0), "ledgers not empty before run")

    with tempfile.TemporaryDirectory(prefix="fgc49c-generic-") as tmp:
        workdir = Path(tmp)
        build_model(workdir, href1, href2)
        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        kernel = CountingKernel(raw)
        publisher = Fgc34CtypesPublisher(bridge)
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
            result = run_groundwater_application_window(
                runtime,
                session,
                GroundwaterApplicationServiceConfig(
                    flux_tolerance_m_per_s=FLUX_TOL,
                    max_coupling_iterations=40,
                ),
            )

            require(
                result.status == GroundwaterApplicationServiceStatus.OK,
                f"generic service failed at {result.failure_stage}",
            )
            require(result.published, "generic service did not publish")
            require(result.iterations >= 2, "live mixed case unexpectedly skipped coupling")
            require(len(result.final_residuals_m_per_s) == 2, "missing cell residuals")
            require(
                max(abs(v) for v in result.final_residuals_m_per_s) <= FLUX_TOL,
                "cell residual tolerance",
            )
            require(kernel.prepare_solve_calls == 1, "prepare_solve count")
            require(kernel.finalize_solve_calls == 1, "finalize_solve count")
            require(kernel.finalize_time_step_calls == 1, "finalize_time_step count")
            require(list(session.nodelist[:2]) == [2, 3], "F-GC34 slot/node mapping")
            require(
                session.finalize_time_step_once()
                == PreparedSolveStatus.TIMESTEP_ALREADY_FINALIZED,
                "second MODFLOW timestep publication not blocked",
            )

            state = runtime.swap.state()
            require(state[:3] == (1, 1, 1), "three SWAP lineages not committed")
            require(
                all(abs(v - WINDOW_DAY) <= 1.0e-14 for v in state[3:6]),
                "three SWAP committed times mismatch",
            )
            require(state[6:9] == (1, 1, 1), "three ledgers not committed")
            require(
                all(math.isfinite(v) for v in state[9:]),
                "non-finite committed ledger exchange",
            )

            event_order = [
                runtime.events.index(name)
                for name in (
                    "swap_preflight",
                    "ledger_prepare",
                    "ledger_preflight",
                    "swap_commit",
                    "ledger_commit",
                )
            ]
            require(event_order == sorted(event_order), "runtime publication order")

            raw.finalize()
            initialized = False

            print(f"FGC49C_LIVE_ITERATIONS={result.iterations}")
            print(
                "FGC49C_LIVE_MAX_CELL_RESIDUAL_M_PER_S="
                f"{max(abs(v) for v in result.final_residuals_m_per_s):.17g}"
            )
            print("FGC49C_LIVE_FGC47_MIXED_TOPOLOGY_REPLAY=PASS")
            print("FGC49C_ONE_GENERIC_SERVICE_TWO_CELLS=PASS")
            print("FGC49C_ONE_PREPARED_MODFLOW_SOLVE=PASS")
            print("FGC49C_CELL_SPECIFIC_REAL_SWAP_CORRECTORS=PASS")
            print("FGC49C_PER_CELL_CONJUNCTIVE_CONVERGENCE=PASS")
            print("FGC49C_PREFLIGHT_BEFORE_PUBLICATION=PASS")
            print("FGC49C_MODFLOW_SWAP_LEDGER_PUBLICATION=PASS")
            print("FGC49C_THREE_REAL_SWAP_AND_LEDGER_COMMITS=PASS")
            print("F-GC49C LIVE GENERIC APPLICATION SERVICE GATE PASS")
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


if __name__ == "__main__":
    main()
