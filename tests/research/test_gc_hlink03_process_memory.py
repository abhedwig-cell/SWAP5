from __future__ import annotations

import math
import os
import sys
import tempfile
from pathlib import Path

from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from test_gc_dummy_swap_dsw01_live_modflow import (
    Binding,
    DirectApiPublisher,
    Term,
    build_model,
    require,
)
from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveStatus,
)


H0 = 8.0
CONFIGURED_SY = 0.15
SHARED_STORAGE = 0.20
DT = 1.0
AREA = 1.0
ATM_INPUT = 0.012
LATERAL_INPUT = 0.004
ET_THRESHOLD = 8.02
ET_SLOPE = 0.05
DRAIN_THRESHOLD = 8.04
DRAIN_SLOPE = 0.10
MEMORY_K = 1.0
HEAD_TOL = 1.0e-10
MASS_TOL = 1.0e-12


def memory_step(memory0: float) -> tuple[float, float]:
    memory1 = memory0 / (1.0 + MEMORY_K * DT)
    transfer = memory0 - memory1
    return memory1, transfer


def et_amount(head: float) -> float:
    return ET_SLOPE * max(0.0, head - ET_THRESHOLD) * DT


def drain_amount(head: float) -> float:
    return DRAIN_SLOPE * max(0.0, head - DRAIN_THRESHOLD) * DT


def solve_case(
    libmf6: Path,
    name: str,
    memory0: float,
) -> dict[str, float | int | bool]:
    memory1, transfer = memory_step(memory0)

    # The preregistered roots lie above both thresholds, so this fixed affine
    # API term is the exact active-branch SWAP process remainder:
    #
    # Q_api(H) = atmospheric + internal memory transfer
    #            - ET_slope*(H-H_ET)
    #            - drain_slope*(H-H_D).
    process_constant = (
        ATM_INPUT / DT
        + transfer / DT
        + ET_SLOPE * ET_THRESHOLD
        + DRAIN_SLOPE * DRAIN_THRESHOLD
    )
    hcof = -(ET_SLOPE + DRAIN_SLOPE)
    rhs = -process_constant

    with tempfile.TemporaryDirectory(prefix=f"gc-hlink03-{name}-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            name,
            sy=CONFIGURED_SY,
            newton=False,
            well_rate_m3_per_day=LATERAL_INPUT / DT,
            initial_head_m=H0,
            dt_day=DT,
        )

        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW6 version")

            x = raw.get_value_ptr(raw.get_var_address("X", "GWF_1"))
            xold = raw.get_value_ptr(raw.get_var_address("XOLD", "GWF_1"))
            x[:] = H0
            xold[:] = H0

            sy_ptr = raw.get_value_ptr(
                raw.get_var_address("SY", "GWF_1", "STO")
            )
            configured_sy = float(sy_ptr[0])
            require(
                math.isclose(
                    configured_sy,
                    CONFIGURED_SY,
                    rel_tol=0.0,
                    abs_tol=1.0e-15,
                ),
                "configured SY drift",
            )
            sy_ptr[:] = SHARED_STORAGE
            require(
                float(sy_ptr[0]) == SHARED_STORAGE,
                "shared-storage runtime replacement lost precision",
            )

            raw.prepare_time_step(0.0)
            session = Modflow6PreparedSolveSession(
                raw,
                "GWF_1",
                "API_SWAP",
                DirectApiPublisher(),
                solution_id=1,
            )
            require(
                session.acquire_after_prepare_time_step()
                == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )

            term = Term(
                groundwater_cell_id=1,
                hcof_m2_per_day=hcof,
                rhs_m3_per_day=rhs,
            )

            final_head = float("nan")
            iterations = 0
            converged = False
            for _ in range(max(1, session.max_solve_iterations)):
                status, iterate = session.publish_and_solve_iteration(
                    (Binding(),),
                    (term,),
                )
                require(
                    status == PreparedSolveStatus.OK and iterate is not None,
                    f"solve failed: {status} {session.last_error}",
                )
                final_head = float(iterate.head_m[0])
                iterations = int(iterate.iteration)
                if bool(iterate.modflow_converged):
                    converged = True
                    break

            require(
                converged,
                f"{name} MODFLOW did not certify convergence",
            )
            require(
                session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(
                session.timestep_ready_for_finalize(),
                f"{name} finalized solve but timestep not ready",
            )
            require(
                session.finalize_time_step_once() == PreparedSolveStatus.OK,
                session.last_error,
            )

            return {
                "head": final_head,
                "iterations": iterations,
                "configured_sy": configured_sy,
                "runtime_sy": float(sy_ptr[0]),
                "memory0": memory0,
                "memory1": memory1,
                "transfer": transfer,
                "hcof": hcof,
                "rhs": rhs,
            }
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


def check_case(
    label: str,
    result: dict[str, float | int | bool],
    expected_head: float,
    expected_memory1: float,
    expected_transfer: float,
    expected_et: float,
    expected_drain: float,
    expected_shared_gain: float,
) -> None:
    head = float(result["head"])
    memory0 = float(result["memory0"])
    memory1 = float(result["memory1"])
    transfer = float(result["transfer"])
    storage_gain = SHARED_STORAGE * AREA * (head - H0)
    et = et_amount(head)
    drain = drain_amount(head)

    whole_external_net = ATM_INPUT + LATERAL_INPUT - et - drain
    total_state_change = storage_gain + (memory1 - memory0)
    api_window_amount = ATM_INPUT + transfer - et - drain

    print(f"GC_HLINK03_{label}_CONFIGURED_SY={float(result['configured_sy']):.17g}")
    print(f"GC_HLINK03_{label}_RUNTIME_SY={float(result['runtime_sy']):.17g}")
    print(f"GC_HLINK03_{label}_HEAD_M={head:.17g}")
    print(f"GC_HLINK03_{label}_MEMORY0_M={memory0:.17g}")
    print(f"GC_HLINK03_{label}_MEMORY1_M={memory1:.17g}")
    print(f"GC_HLINK03_{label}_INTERNAL_TRANSFER_M={transfer:.17g}")
    print(f"GC_HLINK03_{label}_ET_M={et:.17g}")
    print(f"GC_HLINK03_{label}_DRAIN_M={drain:.17g}")
    print(f"GC_HLINK03_{label}_SHARED_STORAGE_GAIN_M3={storage_gain:.17g}")
    print(f"GC_HLINK03_{label}_API_PROCESS_AMOUNT_M3={api_window_amount:.17g}")
    print(f"GC_HLINK03_{label}_WHOLE_EXTERNAL_NET_M3={whole_external_net:.17g}")
    print(f"GC_HLINK03_{label}_TOTAL_STATE_CHANGE_M3={total_state_change:.17g}")
    print(f"GC_HLINK03_{label}_ITERATIONS={int(result['iterations'])}")

    require(
        math.isclose(head, expected_head, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"{label} head {head} != {expected_head}",
    )
    require(
        math.isclose(
            memory1,
            expected_memory1,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        f"{label} memory1",
    )
    require(
        math.isclose(
            transfer,
            expected_transfer,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        f"{label} internal transfer",
    )
    require(
        math.isclose(et, expected_et, rel_tol=0.0, abs_tol=MASS_TOL),
        f"{label} ET",
    )
    require(
        math.isclose(
            drain,
            expected_drain,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        f"{label} drain",
    )
    require(
        math.isclose(
            storage_gain,
            expected_shared_gain,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        f"{label} shared storage gain",
    )
    require(
        math.isclose(
            total_state_change,
            whole_external_net,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        f"{label} whole-system mass",
    )
    require(
        math.isclose(
            storage_gain,
            LATERAL_INPUT + api_window_amount,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        f"{label} groundwater/shared-state balance",
    )


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    dry = solve_case(libmf6, "dry_memory", 0.0)
    wet = solve_case(libmf6, "wet_memory", 0.010)

    check_case(
        "DRY",
        dry,
        expected_head=8.06,
        expected_memory1=0.0,
        expected_transfer=0.0,
        expected_et=0.002,
        expected_drain=0.002,
        expected_shared_gain=0.012,
    )
    check_case(
        "WET",
        wet,
        expected_head=8.074285714285714,
        expected_memory1=0.005,
        expected_transfer=0.005,
        expected_et=0.0027142857142857,
        expected_drain=0.0034285714285714,
        expected_shared_gain=0.0148571428571428,
    )

    require(
        float(wet["head"]) > float(dry["head"]),
        "different internal memory did not change shared-head response",
    )

    print("GC_HLINK03_RUNTIME_SHARED_STORAGE_REPLACEMENT=PASS")
    print("GC_HLINK03_PROCESS_REMAINDER_EXCLUDES_STORAGE=PASS")
    print("GC_HLINK03_INTERNAL_TRANSFER_EQUAL_OPPOSITE=PASS")
    print("GC_HLINK03_ET_DRAIN_DECOMPOSITION=PASS")
    print("GC_HLINK03_SAME_HEAD_DIFFERENT_MEMORY_RESPONSE=PASS")
    print("GC_HLINK03_WHOLE_SYSTEM_MASS=PASS")
    print("GC_HLINK03_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
