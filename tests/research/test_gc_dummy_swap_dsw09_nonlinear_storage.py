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
S0 = 0.15
K = 1.0
INPUT = 0.010
DT = 1.0
RESIDUAL_TOL = 1.0e-12
HEAD_TOL = 1.0e-10


def storage_change_m(head_m: float) -> float:
    x = head_m - H0
    return S0 * x + 0.5 * K * x * x


def q_residual_m_per_day(head_m: float) -> float:
    return INPUT / DT - storage_change_m(head_m) / DT


def dq_dh_per_day(head_m: float) -> float:
    return -(S0 + K * (head_m - H0)) / DT


def exact_head_m() -> float:
    dx = (-S0 + math.sqrt(S0 * S0 + 2.0 * K * INPUT)) / K
    return H0 + dx


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    expected = exact_head_m()
    require(
        math.isclose(storage_change_m(expected), INPUT, rel_tol=0.0, abs_tol=1.0e-14),
        "closed-form mass oracle",
    )

    with tempfile.TemporaryDirectory(prefix="gc-dsw09-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            "nonlinear_storage",
            sy=0.0,
            newton=False,
        )

        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        history: list[tuple[int, float, float, float, float, bool]] = []
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW6 version")
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
            reanchor_count = 0

            # Two nested iteration levels are required:
            # 1. solve MODFLOW to convergence for one frozen affine tangent;
            # 2. evaluate the exact nonlinear residual and reanchor only then.
            for external_iteration in range(1, 21):
                reanchor_count += 1
                q_ref = q_residual_m_per_day(href)
                hcof = dq_dh_per_day(href)
                rhs = hcof * href - q_ref

                require(
                    math.isclose(
                        hcof,
                        dq_dh_per_day(href),
                        rel_tol=0.0,
                        abs_tol=1.0e-15,
                    ),
                    "published HCOF is not the exact local tangent",
                )

                linear_converged = False
                latest_head = float("nan")
                latest_residual = float("nan")
                while session.iteration_count < session.max_solve_iterations:
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
                    latest_head = float(iterate.head_m[0])
                    latest_residual = q_residual_m_per_day(latest_head)
                    history.append(
                        (
                            external_iteration,
                            href,
                            hcof,
                            latest_head,
                            latest_residual,
                            bool(iterate.modflow_converged),
                        )
                    )
                    if bool(iterate.modflow_converged):
                        linear_converged = True
                        break

                require(
                    linear_converged,
                    "MODFLOW did not converge for the frozen local tangent",
                )

                if abs(latest_residual) <= RESIDUAL_TOL:
                    accepted_head = latest_head
                    break

                href = latest_head

            require(reanchor_count > 1, "nonlinear test did not exercise reanchoring")
            require(
                math.isfinite(accepted_head),
                "nested nonlinear/MODFLOW solve did not converge",
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
                    f"GC_DSW09_ITER_{iteration}_HREF_M={href:.17g} "
                    f"HCOF={hcof:.17g} HEAD_M={head:.17g} "
                    f"Q_RESIDUAL_M_PER_DAY={residual:.17g} "
                    f"MF_CONVERGED={1 if mf_converged else 0}"
                )

            print(f"GC_DSW09_EXPECTED_HEAD_M={expected:.17g}")
            print(f"GC_DSW09_FINAL_HEAD_M={accepted_head:.17g}")
            print(
                "GC_DSW09_FINAL_STORAGE_CHANGE_M="
                f"{storage_change_m(accepted_head):.17g}"
            )

            require(
                math.isclose(accepted_head, expected, rel_tol=0.0, abs_tol=HEAD_TOL),
                f"nonlinear head {accepted_head} != {expected}",
            )
            require(
                abs(q_residual_m_per_day(accepted_head)) <= RESIDUAL_TOL,
                "nonlinear residual",
            )
            require(
                math.isclose(
                    storage_change_m(accepted_head),
                    INPUT,
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                ),
                "nonlinear mass closure",
            )

            print("GC_DSW09_CLOSED_FORM_ROOT=PASS")
            print("GC_DSW09_EXACT_LOCAL_TANGENT=PASS")
            print("GC_DSW09_REANCHOR_EXERCISED=PASS")
            print("GC_DSW09_NONLINEAR_MASS=PASS")
            print("GC_DSW09_LIVE_GATE=PASS")
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


if __name__ == "__main__":
    main()
