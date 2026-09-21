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


def storage_change(head: float) -> float:
    x = head - H0
    return S0 * x + 0.5 * K * x * x


def residual(head: float) -> float:
    return INPUT - storage_change(head)


def tangent(head: float) -> float:
    return -(S0 + K * (head - H0))


def exact_head() -> float:
    return H0 + (-S0 + math.sqrt(S0 * S0 + 2.0 * K * INPUT)) / K


def run_variant(libmf6: Path, complexity: str) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix=f"gc-dsw09u-{complexity.lower()}-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            f"dsw09u_{complexity.lower()}",
            sy=0.0,
            newton=False,
            ims_complexity=complexity,
        )
        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        history: list[dict[str, object]] = []
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
                "acquire failed",
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                "open failed",
            )

            href = H0
            accepted = float("nan")
            for iteration in range(1, 81):
                qref = residual(href)
                hcof = tangent(href)
                rhs = hcof * href - qref

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
                    f"{complexity} iteration failed: {status}",
                )
                head = float(iterate.head_m[0])
                r = residual(head)
                mf = bool(iterate.modflow_converged)
                history.append(
                    {
                        "iteration":iteration,
                        "href":href,
                        "head":head,
                        "residual":r,
                        "modflow_converged":mf,
                    }
                )
                print(
                    f"GC_DSW09U_{complexity}_ITER_{iteration}_"
                    f"HREF_M={href:.17g} HEAD_M={head:.17g} "
                    f"RESIDUAL={r:.17g} MF_CONVERGED={1 if mf else 0}"
                )

                if mf and abs(r) <= RESIDUAL_TOL:
                    accepted = head
                    break
                href = head

            if math.isfinite(accepted):
                require(
                    session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                    "finalize solve failed",
                )
                require(session.timestep_ready_for_finalize(), "timestep not ready")
                require(
                    session.finalize_time_step_once() == PreparedSolveStatus.OK,
                    "finalize timestep failed",
                )
            else:
                session.invalidate_without_finalize()

            return {
                "complexity":complexity,
                "accepted_head":accepted,
                "last_head":float(history[-1]["head"]),
                "last_residual":float(history[-1]["residual"]),
                "last_modflow_converged":bool(history[-1]["modflow_converged"]),
                "iterations":len(history),
            }
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")
    expected = exact_head()

    moderate = run_variant(libmf6, "MODERATE")
    simple = run_variant(libmf6, "SIMPLE")

    for result in (moderate, simple):
        label = str(result["complexity"])
        print(f"GC_DSW09U_{label}_LAST_HEAD_M={float(result['last_head']):.17g}")
        print(f"GC_DSW09U_{label}_LAST_RESIDUAL={float(result['last_residual']):.17g}")
        print(f"GC_DSW09U_{label}_ITERATIONS={int(result['iterations'])}")
        print(
            f"GC_DSW09U_{label}_CLOSED="
            f"{1 if math.isfinite(float(result['accepted_head'])) else 0}"
        )

    require(
        math.isfinite(float(simple["accepted_head"])),
        f"SIMPLE did not close strict gate: {simple}",
    )
    require(
        math.isclose(
            float(simple["accepted_head"]),
            expected,
            rel_tol=0.0,
            abs_tol=HEAD_TOL,
        ),
        f"SIMPLE head mismatch: {simple}",
    )
    require(
        abs(float(simple["last_residual"])) <= RESIDUAL_TOL,
        f"SIMPLE residual gate: {simple}",
    )

    print("GC_DSW09U_SIMPLE_STRICT_GATE=PASS")
    print("GC_DSW09U_MODERATE_CHARACTERIZATION_RECORDED=PASS")
    print("GC_DSW09U_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
