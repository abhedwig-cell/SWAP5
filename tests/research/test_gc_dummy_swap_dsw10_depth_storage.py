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
INPUT = 0.010
DT = 1.0
RESIDUAL_TOL = 1.0e-12
HEAD_TOL = 1.0e-10


def storage_profile(head_m: float) -> float:
    return 0.40 - 0.03 * head_m


def storage_change_m(head_m: float) -> float:
    return (
        0.40 * (head_m - H0)
        - 0.015 * (head_m * head_m - H0 * H0)
    )


def q_residual_m_per_day(head_m: float) -> float:
    return INPUT / DT - storage_change_m(head_m) / DT


def dq_dh_per_day(head_m: float) -> float:
    return -storage_profile(head_m) / DT


def exact_head_m() -> float:
    # DeltaV = 0.16*dx - 0.015*dx^2 = 0.01.
    discriminant = 0.16 * 0.16 - 4.0 * 0.015 * INPUT
    dx = (0.16 - math.sqrt(discriminant)) / (2.0 * 0.015)
    return H0 + dx


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    expected = exact_head_m()
    require(0.0 < expected < 10.0, "closed-form root outside column")
    require(
        math.isclose(storage_change_m(expected), INPUT, rel_tol=0.0, abs_tol=1.0e-14),
        "integrated storage root",
    )

    with tempfile.TemporaryDirectory(prefix="gc-dsw10-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            "depth_storage",
            sy=0.0,
            newton=False,
        )

        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        history: list[tuple[int, float, float, float, float, bool]] = []
        try:
            raw.initialize()
            initialized = True
            raw.prepare_time_step(0.0)

            session = Modflow6PreparedSolveSession(
                raw,
                "GWF_1",
                "API_SWAP",
                DirectApiPublisher(),
                solution_id=1,
            )
            require(
                session.acquire_after_prepare_time_step() == PreparedSolveStatus.OK,
                f"acquire failed: {session.last_error}",
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                f"open failed: {session.last_error}",
            )

            href = H0
            accepted_head = float("nan")
            max_coupling_iterations = min(80, session.max_solve_iterations)

            # Match the admitted application-service semantics: one MODFLOW
            # solve iteration, then evaluate the coupled nonlinear residual,
            # then reanchor for the next coupling iteration if needed.
            for external_iteration in range(1, max_coupling_iterations + 1):
                q_ref = q_residual_m_per_day(href)
                hcof = dq_dh_per_day(href)
                rhs = hcof * href - q_ref

                require(
                    math.isclose(
                        -hcof * DT,
                        storage_profile(href),
                        rel_tol=0.0,
                        abs_tol=1.0e-14,
                    ),
                    "tangent does not equal local storage profile",
                )

                status, iterate = session.publish_and_solve_iteration(
                    (Binding(),),
                    (
                        Term(
                            groundwater_cell_id=1,
                            hcof_m2_per_day=hcof,
                            rhs_m3_per_day=rhs,
                        ),
                    ),
                )
                require(
                    status == PreparedSolveStatus.OK and iterate is not None,
                    f"MODFLOW iteration failed: {status} {session.last_error}",
                )

                head = float(iterate.head_m[0])
                residual = q_residual_m_per_day(head)
                mf_converged = bool(iterate.modflow_converged)
                history.append(
                    (
                        external_iteration,
                        href,
                        hcof,
                        head,
                        residual,
                        mf_converged,
                    )
                )
                print(
                    f"GC_DSW10_TRACE_ITER={external_iteration} "
                    f"HREF_M={href:.17g} HCOF={hcof:.17g} "
                    f"HEAD_M={head:.17g} Q_RESIDUAL={residual:.17g} "
                    f"MF_CONVERGED={1 if mf_converged else 0}"
                )

                if mf_converged and abs(residual) <= RESIDUAL_TOL:
                    accepted_head = head
                    break

                href = head

            require(len(history) > 1, "coupling test did not exercise reanchoring")
            latest_candidate = float(history[-1][3])
            latest_residual = float(history[-1][4])
            print(f"GC_DSW10_LATEST_CANDIDATE_HEAD_M={latest_candidate:.17g}")
            print(f"GC_DSW10_LATEST_CANDIDATE_ERROR_M={latest_candidate - expected:.17g}")
            print(f"GC_DSW10_LATEST_RESIDUAL={latest_residual:.17g}")
            require(
                math.isfinite(accepted_head),
                "production-semantics coupling iteration did not converge",
            )

            require(
                session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                f"finalize solve failed: {session.last_error}",
            )
            require(session.timestep_ready_for_finalize(), "timestep not ready")
            require(
                session.finalize_time_step_once() == PreparedSolveStatus.OK,
                f"finalize timestep failed: {session.last_error}",
            )

            for iteration, href, hcof, head, residual, mf_converged in history:
                print(
                    f"GC_DSW10_ITER_{iteration}_HREF_M={href:.17g} "
                    f"LOCAL_STORAGE={storage_profile(href):.17g} "
                    f"HCOF={hcof:.17g} HEAD_M={head:.17g} "
                    f"Q_RESIDUAL={residual:.17g} "
                    f"MF_CONVERGED={1 if mf_converged else 0}"
                )

            print(f"GC_DSW10_EXPECTED_HEAD_M={expected:.17g}")
            print(f"GC_DSW10_FINAL_HEAD_M={accepted_head:.17g}")
            print(
                "GC_DSW10_FINAL_STORAGE_CHANGE_M="
                f"{storage_change_m(accepted_head):.17g}"
            )

            require(
                math.isclose(accepted_head, expected, rel_tol=0.0, abs_tol=HEAD_TOL),
                f"depth-profile head {accepted_head} != {expected}",
            )
            require(
                abs(q_residual_m_per_day(accepted_head)) <= RESIDUAL_TOL,
                "depth-profile residual",
            )
            require(
                math.isclose(
                    storage_change_m(accepted_head),
                    INPUT,
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                ),
                "depth-profile mass closure",
            )

            print("GC_DSW10_INTEGRATED_STORAGE_ROOT=PASS")
            print("GC_DSW10_LOCAL_STORAGE_TANGENT=PASS")
            print("GC_DSW10_REANCHOR_EXERCISED=PASS")
            print("GC_DSW10_MASS_CLOSURE=PASS")
            print("GC_DSW10_LIVE_GATE=PASS")
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


if __name__ == "__main__":
    main()
