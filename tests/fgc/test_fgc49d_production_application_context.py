from __future__ import annotations

import ctypes
import os
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from fmr_groundwater_application_runtime import FmrGroundwaterApplicationRuntime
from modflow6_groundwater_application_service import (
    GroundwaterApplicationServiceConfig,
    GroundwaterApplicationServiceStatus,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import PreparedSolveIteration, PreparedSolveStatus


class DeterministicPreparedSolve:
    def __init__(self, head1: float, head2: float) -> None:
        self.head1 = float(head1)
        self.head2 = float(head2)
        self.acquire_calls = 0
        self.open_calls = 0
        self.solve_calls = 0
        self.finalize_solve_calls = 0
        self.finalize_time_step_calls = 0
        self.invalidated = False
        self.finalized = False
        self.timestep_finalized = False
        self.accepted = np.array([self.head1, self.head1, self.head2, self.head2])

    def acquire_after_prepare_time_step(self):
        self.acquire_calls += 1
        return PreparedSolveStatus.OK

    def open_prepared_solve(self):
        self.open_calls += 1
        return PreparedSolveStatus.OK

    def publish_and_solve_iteration(self, bindings, terms):
        self.solve_calls += 1
        head = np.array([self.head1, self.head1, self.head2, self.head2])
        return (
            PreparedSolveStatus.OK,
            PreparedSolveIteration(
                iteration=self.solve_calls,
                modflow_converged=True,
                head_m=head,
                accepted_head_old_m=self.accepted.copy(),
            ),
        )

    def finalize_prepared_solve(self):
        self.finalize_solve_calls += 1
        self.finalized = True
        return PreparedSolveStatus.OK

    def timestep_ready_for_finalize(self):
        return self.finalized and not self.invalidated and not self.timestep_finalized

    def finalize_time_step_once(self):
        if not self.timestep_ready_for_finalize():
            return PreparedSolveStatus.TIMESTEP_NOT_READY
        self.finalize_time_step_calls += 1
        self.timestep_finalized = True
        return PreparedSolveStatus.OK

    def invalidate_without_finalize(self):
        self.invalidated = True


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def fixture_state(lib: ctypes.CDLL) -> tuple[int, int, int, int, int, int]:
    fn = lib.fgc49d_fixture_state_c
    fn.restype = ctypes.c_int
    fn.argtypes = [ctypes.POINTER(ctypes.c_int)] * 6
    values = [ctypes.c_int() for _ in range(6)]
    status = int(fn(*[ctypes.byref(value) for value in values]))
    require(status == 0, "fixture state")
    return tuple(int(value.value) for value in values)


def main() -> None:
    library_path = Path(os.environ["FGC49D_APPLICATION_LIB"]).resolve()
    require(library_path.is_file(), "production ABI qualification library")

    lib = ctypes.CDLL(str(library_path))
    print("FGC49D_TRACE library_loaded", flush=True)
    initialize = lib.fgc49d_fixture_initialize_c
    initialize.restype = ctypes.c_int
    initialize.argtypes = [
        ctypes.POINTER(ctypes.c_int64),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
    ]

    handle = ctypes.c_int64()
    href1 = ctypes.c_double()
    href2 = ctypes.c_double()
    require(
        int(initialize(ctypes.byref(handle), ctypes.byref(href1), ctypes.byref(href2))) == 0,
        "fixture initialization",
    )
    require(handle.value > 0, "opaque context handle")
    print("FGC49D_TRACE fixture_initialized", flush=True)

    runtime = FmrGroundwaterApplicationRuntime(library_path, handle.value)
    plan = runtime.materialize_plan()
    require(plan.valid(), "production plan view")
    require(tuple(plan.cell_ids) == (7001, 7002), "canonical two-cell plan")
    require(
        tuple(tile.groundwater_cell_id for tile in runtime.tiles) == (7001, 7001, 7002),
        "mixed N:1 plus 1:1 tile routing",
    )
    require(len(set(runtime.participant_handles)) == 3, "three distinct F-GC49B handles")
    require(all(value > 0 for value in runtime.participant_handles), "opaque participant handles")
    print("FGC49D_TRACE plan_materialized", flush=True)

    before = fixture_state(lib)
    require(before == (0, 0, 0, 0, 0, 0), "no committed mutation before service")

    groundwater = DeterministicPreparedSolve(href1.value, href2.value)
    for _trace_name in (
        "materialize_plan",
        "capture_origins",
        "evaluate_groundwater_fluxes",
        "trial_cell_heads",
        "discard_candidates",
        "relinearize_terms",
        "swap_preflight",
        "prepare_ledgers",
        "ledgers_preflight",
        "abort_prepublication",
        "commit_swaps",
        "commit_ledgers",
    ):
        _trace_original = getattr(runtime, _trace_name)

        def _trace_call(*args, _name=_trace_name, _original=_trace_original, **kwargs):
            print(f"FGC49D_TRACE {_name}_begin", flush=True)
            value = _original(*args, **kwargs)
            print(f"FGC49D_TRACE {_name}_end", flush=True)
            return value

        setattr(runtime, _trace_name, _trace_call)
    print("FGC49D_TRACE runtime_method_wrappers_installed", flush=True)

    print("FGC49D_TRACE service_begin", flush=True)
    result = run_groundwater_application_window(
        runtime,
        groundwater,
        GroundwaterApplicationServiceConfig(
            flux_tolerance_m_per_s=1.0e-15,
            max_coupling_iterations=5,
        ),
    )

    print("FGC49D_TRACE service_returned", flush=True)
    require(result.status == GroundwaterApplicationServiceStatus.OK, f"service status {result.failure_stage}")
    require(result.published, "whole-window publication")
    require(result.iterations >= 2, "first corrector must force authoritative reanchor")
    require(
        groundwater.acquire_calls == 1
        and groundwater.open_calls == 1
        and groundwater.finalize_solve_calls == 1
        and groundwater.finalize_time_step_calls == 1,
        "one prepared-solve and publication lifecycle",
    )
    require(
        max(abs(value) for value in result.final_residuals_m_per_s) <= 1.0e-15,
        "all cell residuals converge independently",
    )

    after = fixture_state(lib)
    require(after[:3] == (1, 1, 1), "three real FMR committed revisions")
    require(after[3:] == (1, 1, 1), "three externally owned ledgers committed")
    require(not runtime.capture_origins(), "published one-window context cannot be reused")

    runtime.release()

    counts = lib.fgc49d_context_counts_c
    counts.restype = ctypes.c_int
    counts.argtypes = [
        ctypes.c_int64,
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),
    ]
    ncell = ctypes.c_int()
    ntile = ctypes.c_int()
    require(
        int(counts(ctypes.c_int64(handle.value), ctypes.byref(ncell), ctypes.byref(ntile))) != 0,
        "released context handle must fail closed",
    )

    print(f"FGC49D_SERVICE_ITERATIONS={result.iterations}")
    print("FGC49D_FGC49A_PLAN_EXPOSED=PASS")
    print("FGC49D_FGC49B_OPAQUE_HANDLES_EXPOSED=PASS")
    print("FGC49D_REAL_FMR_MIXED_TOPOLOGY_ROUTING=PASS")
    print("FGC49D_FGC40_AGGREGATION_FORTRAN_OWNED=PASS")
    print("FGC49D_FGC33_EVALUATION_REANCHOR_FORTRAN_OWNED=PASS")
    print("FGC49D_EXTERNALLY_OWNED_LEDGERS=PASS")
    print("FGC49D_ONE_FGC49C_SERVICE_WINDOW=PASS")
    print("FGC49D_THREE_REAL_SWAP_AND_LEDGER_COMMITS=PASS")
    print("FGC49D_ONE_WINDOW_CONTEXT_REUSE_FAIL_CLOSED=PASS")
    print("FGC49D_STALE_CONTEXT_HANDLE_FAIL_CLOSED=PASS")
    print("F-GC49D PRODUCTION APPLICATION CONTEXT ABI GATE PASS")


if __name__ == "__main__":
    main()
