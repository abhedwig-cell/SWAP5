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
RESIDUAL_TOL = 1.0e-12
HEAD_TOL = 1.0e-10

VARIANTS = (
    ("DEFAULT_R1E15", None, 1.0e-15),
    ("DEFAULT_R1E14", None, 1.0e-14),
    ("NO_UR_R1E15", "NONE", 1.0e-15),
    ("NO_UR_R1E14", "NONE", 1.0e-14),
)


def storage_change(head: float) -> float:
    x = head - H0
    return S0 * x + 0.5 * K * x * x


def residual(head: float) -> float:
    return INPUT - storage_change(head)


def tangent(head: float) -> float:
    return -(S0 + K * (head - H0))


def exact_head() -> float:
    return H0 + (-S0 + math.sqrt(S0 * S0 + 2.0 * K * INPUT)) / K


def run_variant(
    libmf6: Path,
    label: str,
    under_relaxation: str | None,
    rclose: float,
) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix=f"gc-dsw09w-{label.lower()}-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            f"dsw09w_{label.lower()}",
            sy=0.0,
            newton=False,
            ims_complexity="MODERATE",
            ims_under_relaxation=under_relaxation,
            ims_rclose=rclose,
        )
        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
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
                f"{label}: acquire failed",
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                f"{label}: open failed",
            )

            href = H0
            accepted = float("nan")
            last_head = float("nan")
            last_residual = float("nan")
            last_mf = False
            history: list[dict[str, object]] = []

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
                    f"{label}: solve iteration failed: {status}",
                )
                last_head = float(iterate.head_m[0])
                last_residual = residual(last_head)
                last_mf = bool(iterate.modflow_converged)
                history.append(
                    {
                        "iteration": iteration,
                        "href": href,
                        "head": last_head,
                        "residual": last_residual,
                        "modflow_converged": last_mf,
                    }
                )
                if (
                    iteration <= 6
                    or iteration in (10, 20, 40, 80)
                    or last_mf
                    or abs(last_residual) <= RESIDUAL_TOL
                ):
                    print(
                        f"GC_DSW09W_{label}_ITER_{iteration}_"
                        f"HREF_M={href:.17g} HEAD_M={last_head:.17g} "
                        f"RESIDUAL={last_residual:.17g} "
                        f"MF_CONVERGED={1 if last_mf else 0}"
                    )

                if last_mf and abs(last_residual) <= RESIDUAL_TOL:
                    accepted = last_head
                    break
                href = last_head

            if math.isfinite(accepted):
                require(
                    session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                    f"{label}: finalize solve failed",
                )
                require(
                    session.timestep_ready_for_finalize(),
                    f"{label}: timestep not ready",
                )
                require(
                    session.finalize_time_step_once() == PreparedSolveStatus.OK,
                    f"{label}: finalize timestep failed",
                )
            else:
                session.invalidate_without_finalize()

            return {
                "label": label,
                "rclose": rclose,
                "under_relaxation": under_relaxation,
                "accepted_head": accepted,
                "last_head": last_head,
                "last_residual": last_residual,
                "last_mf": last_mf,
                "iterations": len(history),
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
    print(f"GC_DSW09W_EXACT_HEAD_M={expected:.17g}")

    results = {
        label: run_variant(libmf6, label, under_relaxation, rclose)
        for label, under_relaxation, rclose in VARIANTS
    }

    for label, result in results.items():
        print(f"GC_DSW09W_{label}_LAST_HEAD_M={float(result['last_head']):.17g}")
        print(f"GC_DSW09W_{label}_LAST_RESIDUAL={float(result['last_residual']):.17g}")
        print(f"GC_DSW09W_{label}_MF_CONVERGED={1 if result['last_mf'] else 0}")
        print(f"GC_DSW09W_{label}_ITERATIONS={int(result['iterations'])}")
        print(
            f"GC_DSW09W_{label}_CLOSED="
            f"{1 if math.isfinite(float(result['accepted_head'])) else 0}"
        )

    target = results["NO_UR_R1E14"]
    require(
        math.isfinite(float(target["accepted_head"])),
        f"NO_UR_R1E14 did not close the preregistered diagnostic gate: {target}",
    )
    require(
        math.isclose(
            float(target["accepted_head"]),
            expected,
            rel_tol=0.0,
            abs_tol=HEAD_TOL,
        ),
        f"NO_UR_R1E14 head mismatch: {target}",
    )
    require(
        abs(float(target["last_residual"])) <= RESIDUAL_TOL,
        f"NO_UR_R1E14 residual gate: {target}",
    )
    require(
        bool(target["last_mf"]),
        f"NO_UR_R1E14 lacks MODFLOW convergence certificate: {target}",
    )

    print("GC_DSW09W_NO_UR_R1E14_STRICT_COUPLED_GATE=PASS")
    print("GC_DSW09W_FACTORIAL_CHARACTERIZATION_RECORDED=PASS")
    print("GC_DSW09W_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
