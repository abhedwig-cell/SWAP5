from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from modflow6_groundwater_application_service import GroundwaterApplicationPlanView
from modflow6_prepared_solve_session import PreparedSolveIteration, PreparedSolveStatus
from modflow6_ribasim_triangle_application_service import (
    RibasimCandidateReceipt,
    TriangleApplicationConfig,
    TriangleApplicationStatus,
    TriangleCorrectorBatch,
    TrianglePublicationInvariantError,
    run_triangle_application_window,
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
    valid: bool = True


class FakeSession:
    def __init__(self, script: list[tuple[bool, float]], events: list[str]):
        self.script = list(script)
        self.events = events
        self.index = 0
        self.invalidated = False
        self.finalized_solve = False
        self.timestep_finalized = False
        self.finalize_timestep_calls = 0

    def acquire_after_prepare_time_step(self):
        self.events.append("mf_acquire")
        return PreparedSolveStatus.OK

    def open_prepared_solve(self):
        self.events.append("mf_open")
        return PreparedSolveStatus.OK

    def publish_and_solve_iteration(self, bindings, terms):
        if not self.script:
            return PreparedSolveStatus.SOLVE_FAILED, None
        converged, head = self.script.pop(0)
        self.index += 1
        self.events.append(f"mf_iter_{self.index}")
        return (
            PreparedSolveStatus.OK,
            PreparedSolveIteration(
                iteration=self.index,
                modflow_converged=converged,
                head_m=(head,),
                accepted_head_old_m=(head,),
            ),
        )

    def finalize_prepared_solve(self):
        self.finalized_solve = True
        self.events.append("mf_finalize_solve")
        return PreparedSolveStatus.OK

    def timestep_ready_for_finalize(self):
        self.events.append("mf_preflight")
        return self.finalized_solve and not self.invalidated and not self.timestep_finalized

    def finalize_time_step_once(self):
        if not self.timestep_ready_for_finalize():
            return PreparedSolveStatus.TIMESTEP_NOT_READY
        self.timestep_finalized = True
        self.finalize_timestep_calls += 1
        self.events.append("mf_commit")
        return PreparedSolveStatus.OK

    def invalidate_without_finalize(self):
        self.invalidated = True
        self.events.append("mf_invalidate")


class FakeRuntime:
    def __init__(
        self,
        joint_script: list[TriangleCorrectorBatch],
        events: list[str],
        *,
        origins_ok: bool = True,
    ):
        self.joint_script = list(joint_script)
        self.events = events
        self.origins_ok = origins_ok
        self.discards = 0
        self.recomposes = 0
        self.relinearizes = 0
        self.abort_calls = 0
        self.swap_commits = 0
        self.ledger_commits = 0
        self.binding = Binding(101, 1, 1)
        self.term = Term(101, 1.0, 0.0)

    def materialize_plan(self):
        self.events.append("plan")
        return GroundwaterApplicationPlanView(
            bindings=(self.binding,), terms=(self.term,), cell_ids=(101,)
        )

    def capture_origins(self):
        self.events.append("swap_origin")
        return self.origins_ok

    def evaluate_groundwater_fluxes(self, terms, cell_heads_m):
        self.events.append("qgw")
        return (0.0,)

    def trial_joint(self, cell_heads_m, surface_head_cm):
        self.events.append(f"joint_trial@{surface_head_cm:.6g}")
        if not self.joint_script:
            return TriangleCorrectorBatch(False, (), (), 0.0)
        return self.joint_script.pop(0)

    def recompose_surface_head(self, previous_surface_head_cm, receipt):
        self.recomposes += 1
        self.events.append("surface_recompose")
        # Deterministic stand-in for the source-owned inverse surface corrector.
        return previous_surface_head_cm - 1.0

    def discard_candidate(self):
        self.discards += 1
        self.events.append("swap_discard")
        return True

    def relinearize_terms(
        self, cell_heads_m, cell_q_swap_m_per_s, cell_dq_swap_dh_per_s
    ):
        self.relinearizes += 1
        self.events.append("gw_relinearize")
        return (Term(101, 1.0, float(self.relinearizes)),)

    def swap_preflight(self, realized_surface_exchange_cm):
        self.events.append("swap_preflight")
        return True

    def prepare_ledgers(self):
        self.events.append("ledger_prepare")
        return True

    def ledgers_preflight(self):
        self.events.append("ledger_preflight")
        return True

    def abort_prepublication(self):
        self.abort_calls += 1
        self.events.append("swap_abort")
        return True

    def commit_swap(self, realized_surface_exchange_cm):
        self.swap_commits += 1
        self.events.append("swap_commit")
        return True

    def commit_ledgers(self):
        self.ledger_commits += 1
        self.events.append("ledger_commit")
        return True


class FakeRibasim:
    def __init__(
        self,
        realized_script: list[float],
        events: list[str],
        *,
        origins_ok: bool = True,
    ):
        self.realized_script = list(realized_script)
        self.events = events
        self.origins_ok = origins_ok
        self.live = False
        self.discards = 0
        self.commits = 0
        self.abort_calls = 0

    def capture_origin(self):
        self.events.append("rib_origin")
        return self.origins_ok

    def trial_from_origin(self, requested_surface_exchange_cm):
        self.events.append("rib_trial")
        if not self.realized_script:
            return RibasimCandidateReceipt(False, requested_surface_exchange_cm, 0.0)
        realized = self.realized_script.pop(0)
        self.live = True
        return RibasimCandidateReceipt(True, requested_surface_exchange_cm, realized)

    def discard_candidate(self):
        self.discards += 1
        self.live = False
        self.events.append("rib_discard")
        return True

    def publication_ready(self):
        self.events.append("rib_preflight")
        return self.live

    def abort_prepublication(self):
        self.abort_calls += 1
        self.live = False
        self.events.append("rib_abort")
        return True

    def commit_candidate(self):
        self.events.append("rib_commit")
        if not self.live:
            return False
        self.commits += 1
        self.live = False
        return True


def batch(q=0.0, tangent=0.0, surface=0.0025, valid=True):
    return TriangleCorrectorBatch(valid, (q,), (tangent,), surface)


def config(max_iter=4):
    return TriangleApplicationConfig(
        groundwater_flux_tolerance_m_per_s=1.0e-9,
        surface_exchange_tolerance_cm=1.0e-8,
        max_coupling_iterations=max_iter,
        initial_surface_head_cm=-12.25,
    )


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def case_all_match() -> None:
    events: list[str] = []
    mf = FakeSession([(True, -2.23)], events)
    rt = FakeRuntime([batch(surface=0.0025)], events)
    rib = FakeRibasim([0.0025], events)
    result = run_triangle_application_window(rt, mf, rib, config())
    require(result.status == TriangleApplicationStatus.OK and result.published, "C1 publication")
    require(result.iterations == 1 and result.surface_recompositions == 0, "C1 iterations")
    require(mf.finalize_timestep_calls == 1 and rib.commits == 1 and rt.swap_commits == 1, "C1 one commit each")
    order = [
        events.index("swap_preflight"),
        events.index("rib_preflight"),
        events.index("ledger_prepare"),
        events.index("ledger_preflight"),
        events.index("mf_preflight"),
        events.index("mf_commit"),
        events.index("rib_commit"),
        events.index("swap_commit"),
        events.index("ledger_commit"),
    ]
    require(order == sorted(order), "C1 publication order")
    print("SW_TRI01_C_CASE_PASS=C1_ALL_MATCH_PUBLISH_ONCE")


def case_surface_mismatch_recompose() -> None:
    events: list[str] = []
    mf = FakeSession([(True, -2.23), (True, -2.23)], events)
    rt = FakeRuntime(
        [
            batch(surface=-0.0025),
            batch(surface=-0.00007),
        ],
        events,
    )
    rib = FakeRibasim([-0.00007, -0.00007], events)
    result = run_triangle_application_window(rt, mf, rib, config())
    require(result.status == TriangleApplicationStatus.OK and result.published, "C2 publication")
    require(result.iterations == 2 and result.surface_recompositions == 1, "C2 recomposition count")
    require(rt.discards == 1 and rib.discards == 1, "C2 both first candidates discarded")
    require(events.index("swap_discard") < events.index("surface_recompose"), "C2 discard before recompose")
    require(events.count("mf_commit") == 1 and events.count("rib_commit") == 1 and events.count("swap_commit") == 1, "C2 one final publication")
    require(events.index("mf_commit") > events.index("rib_trial"), "C2 no early MODFLOW publication")
    print("SW_TRI01_C_CASE_PASS=C2_RIBASIM_MISMATCH_SAME_ORIGIN_RECOMPOSE")


def case_groundwater_not_converged() -> None:
    events: list[str] = []
    mf = FakeSession([(False, -2.23)], events)
    rt = FakeRuntime([batch(surface=0.0025)], events)
    rib = FakeRibasim([0.0025], events)
    result = run_triangle_application_window(rt, mf, rib, config(max_iter=1))
    require(result.status == TriangleApplicationStatus.NOT_CONVERGED, "C3 status")
    require(not result.published and mf.finalize_timestep_calls == 0, "C3 no MODFLOW publication")
    require(rib.commits == 0 and rt.swap_commits == 0 and rt.ledger_commits == 0, "C3 no other publication")
    require(rt.discards == 1 and rib.discards == 1, "C3 candidate cleanup")
    print("SW_TRI01_C_CASE_PASS=C3_GROUNDWATER_NOT_CONVERGED_NO_PUBLICATION")


def case_stale_joint_origin() -> None:
    events: list[str] = []
    mf = FakeSession([(True, -2.23)], events)
    rt = FakeRuntime([batch(valid=False)], events)
    rib = FakeRibasim([0.0025], events)
    result = run_triangle_application_window(rt, mf, rib, config())
    require(result.status == TriangleApplicationStatus.JOINT_SWAP_TRIAL_FAILED, "C4 status")
    require(not result.published and mf.finalize_timestep_calls == 0, "C4 no MODFLOW publication")
    require(rib.commits == 0 and rt.swap_commits == 0, "C4 no state publication")
    print("SW_TRI01_C_CASE_PASS=C4_STALE_JOINT_ORIGIN_FAIL_CLOSED")


if __name__ == "__main__":
    case_all_match()
    case_surface_mismatch_recompose()
    case_groundwater_not_converged()
    case_stale_joint_origin()
    print("SW_TRI01_C_DUAL_EXTERNAL_PUBLICATION_ORDER=PASS")
