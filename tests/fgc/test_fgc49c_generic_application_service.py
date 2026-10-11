from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from modflow6_groundwater_application_service import (
    GroundwaterApplicationCorrectorBatch,
    GroundwaterApplicationPlanView,
    GroundwaterApplicationPublicationInvariantError,
    GroundwaterApplicationServiceConfig,
    GroundwaterApplicationServiceStatus,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import PreparedSolveIteration, PreparedSolveStatus


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
    valid: bool = True


class FakeSession:
    def __init__(self, script: list[tuple[bool, tuple[float, float]]], events: list[str]):
        self.script = script
        self.events = events
        self.index = 0
        self.invalidated = False
        self.solve_open = False
        self.finalized = False
        self.timestep_finalized = False
        self.acquire_calls = 0
        self.open_calls = 0
        self.finalize_solve_calls = 0
        self.finalize_timestep_calls = 0
        self.accepted = np.array([9.0, 1.0, 2.0, 8.0], dtype=np.float64)

    def acquire_after_prepare_time_step(self):
        self.acquire_calls += 1
        return PreparedSolveStatus.OK

    def open_prepared_solve(self):
        self.open_calls += 1
        self.solve_open = True
        return PreparedSolveStatus.OK

    def publish_and_solve_iteration(self, bindings, terms):
        if self.index >= len(self.script):
            return PreparedSolveStatus.SOLVE_FAILED, None
        converged, heads = self.script[self.index]
        self.index += 1
        x = np.array([9.0, heads[0], heads[1], 8.0], dtype=np.float64)
        return (
            PreparedSolveStatus.OK,
            PreparedSolveIteration(
                iteration=self.index,
                modflow_converged=converged,
                head_m=x,
                accepted_head_old_m=self.accepted.copy(),
            ),
        )

    def finalize_prepared_solve(self):
        self.finalize_solve_calls += 1
        self.solve_open = False
        self.finalized = True
        self.events.append("finalize_solve")
        return PreparedSolveStatus.OK

    def timestep_ready_for_finalize(self):
        self.events.append("modflow_preflight")
        return self.finalized and not self.invalidated and not self.timestep_finalized

    def finalize_time_step_once(self):
        if not self.timestep_ready_for_finalize():
            return PreparedSolveStatus.TIMESTEP_NOT_READY
        self.finalize_timestep_calls += 1
        self.timestep_finalized = True
        self.events.append("modflow_commit")
        return PreparedSolveStatus.OK

    def invalidate_without_finalize(self):
        self.invalidated = True
        self.solve_open = False
        self.events.append("modflow_invalidate")


class FakeRuntime:
    def __init__(
        self,
        corrector_script: list[tuple[float, float]],
        events: list[str],
        *,
        swap_preflight: bool = True,
        commit_swaps: bool = True,
    ):
        self.events = events
        self.corrector_script = list(corrector_script)
        self.swap_preflight_value = swap_preflight
        self.commit_swaps_value = commit_swaps
        self.discard_calls = 0
        self.reanchor_calls = 0
        self.abort_calls = 0
        self.capture_calls = 0
        self.bindings = (
            Binding(101, 1, 2),
            Binding(202, 2, 3),
        )
        self.terms = (
            Term(101, 2.0, 3.0),
            Term(202, 4.0, 5.0),
        )

    def materialize_plan(self):
        self.events.append("plan")
        return GroundwaterApplicationPlanView(
            bindings=self.bindings,
            terms=self.terms,
            cell_ids=(101, 202),
        )

    def capture_origins(self):
        self.capture_calls += 1
        self.events.append("origins")
        return True

    def evaluate_groundwater_fluxes(self, terms, cell_heads_m):
        self.events.append("qgw")
        return (0.0, 0.0)

    def trial_cell_heads(self, cell_heads_m):
        self.events.append("corrector")
        values = self.corrector_script.pop(0)
        return GroundwaterApplicationCorrectorBatch(
            True, values, tuple(0.0 for _ in values)
        )

    def discard_candidates(self):
        self.discard_calls += 1
        self.events.append("discard")
        return True

    def relinearize_terms(
        self, cell_heads_m, cell_q_swap_m_per_s, cell_dq_swap_dh_per_s
    ):
        self.reanchor_calls += 1
        self.events.append("reanchor")
        assert len(cell_dq_swap_dh_per_s) == len(cell_heads_m)
        return (
            Term(101, 2.0, 3.0 + self.reanchor_calls),
            Term(202, 4.0, 5.0 + self.reanchor_calls),
        )

    def swap_preflight(self):
        self.events.append("swap_preflight")
        return self.swap_preflight_value

    def prepare_ledgers(self):
        self.events.append("ledger_prepare")
        return True

    def ledgers_preflight(self):
        self.events.append("ledger_preflight")
        return True

    def abort_prepublication(self):
        self.abort_calls += 1
        self.events.append("abort")
        return True

    def commit_swaps(self):
        self.events.append("swap_commit")
        return self.commit_swaps_value

    def commit_ledgers(self):
        self.events.append("ledger_commit")
        return True


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def qualify_conjunctive_and_publication_order() -> None:
    events: list[str] = []
    groundwater = FakeSession(
        [
            (True, (1.1, 2.1)),
            (False, (1.2, 2.2)),
            (True, (1.3, 2.3)),
        ],
        events,
    )
    runtime = FakeRuntime(
        [
            (2.0e-6, -2.0e-6),  # cancelling global residual must NOT pass
            (0.0, 0.0),         # cell residuals pass but MODFLOW does not
            (2.0e-10, -2.0e-10),
        ],
        events,
    )
    result = run_groundwater_application_window(
        runtime,
        groundwater,
        GroundwaterApplicationServiceConfig(1.0e-9, 5),
    )

    require(result.status == GroundwaterApplicationServiceStatus.OK, "successful status")
    require(result.published, "successful publication")
    require(result.iterations == 3, "conjunctive convergence must take three iterations")
    require(runtime.discard_calls == 2 and runtime.reanchor_calls == 2, "nonfinal candidates discarded/reanchored")
    require(groundwater.acquire_calls == 1 and groundwater.open_calls == 1, "one prepared-solve session")
    require(groundwater.finalize_solve_calls == 1 and groundwater.finalize_timestep_calls == 1, "one finalization each")
    order = [events.index(x) for x in [
        "finalize_solve",
        "swap_preflight",
        "ledger_prepare",
        "ledger_preflight",
        "modflow_preflight",
        "modflow_commit",
        "swap_commit",
        "ledger_commit",
    ]]
    require(order == sorted(order), "publication ordering")
    print("FGC49C_PER_CELL_NO_CANCELLATION_CONVERGENCE=PASS")
    print("FGC49C_MODFLOW_AND_ALL_CELL_CONJUNCTIVE_CONVERGENCE=PASS")
    print("FGC49C_ONE_PREPARED_SOLVE_PER_WINDOW=PASS")
    print("FGC49C_ALL_PREFLIGHTS_BEFORE_PUBLICATION=PASS")
    print("FGC49C_MODFLOW_THEN_SWAP_THEN_LEDGER_PUBLICATION=PASS")


def qualify_prepublication_failure() -> None:
    events: list[str] = []
    groundwater = FakeSession([(True, (1.0, 2.0))], events)
    runtime = FakeRuntime([(0.0, 0.0)], events, swap_preflight=False)
    result = run_groundwater_application_window(
        runtime,
        groundwater,
        GroundwaterApplicationServiceConfig(1.0e-9, 2),
    )
    require(result.status == GroundwaterApplicationServiceStatus.SWAP_PREFLIGHT_FAILED, "preflight status")
    require(result.request_smaller_window and not result.published, "preflight is reversible retry")
    require(groundwater.finalize_timestep_calls == 0, "preflight failure did not publish MODFLOW timestep")
    require(runtime.abort_calls == 1 and groundwater.invalidated, "prepublication failure aborts/invalidate")
    print("FGC49C_PREFLIGHT_FAILURE_ZERO_TIMESTEP_PUBLICATION=PASS")


def qualify_postpublication_failure_class() -> None:
    events: list[str] = []
    groundwater = FakeSession([(True, (1.0, 2.0))], events)
    runtime = FakeRuntime([(0.0, 0.0)], events, commit_swaps=False)
    try:
        run_groundwater_application_window(
            runtime,
            groundwater,
            GroundwaterApplicationServiceConfig(1.0e-9, 2),
        )
    except GroundwaterApplicationPublicationInvariantError:
        require(groundwater.finalize_timestep_calls == 1, "hard failure occurs after MODFLOW publication")
        require("swap_commit" in events and "ledger_commit" not in events, "hard failure stops later publication")
        print("FGC49C_POST_MODFLOW_FAILURE_NOT_ROLLBACK_RETRY=PASS")
        return
    raise AssertionError("expected publication invariant error")


if __name__ == "__main__":
    qualify_conjunctive_and_publication_order()
    qualify_prepublication_failure()
    qualify_postpublication_failure_class()
    print("F-GC49C GENERIC APPLICATION SERVICE GATE PASS")
