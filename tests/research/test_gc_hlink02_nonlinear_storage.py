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
CONFIGURED_SY = 0.15
EXACT_X = 0.05615528128088301
EXACT_HEAD = H0 + EXACT_X
EXACT_SECANT = 0.17807764064044157
EXACT_TANGENT = 0.206155281280883
HEAD_TOL = 1.0e-10
MASS_TOL = 1.0e-12
RCLOSE = 1.0e-13
MAX_OUTER = 40


def volume_change(x: float) -> float:
    return S0 * x + 0.5 * K * x * x


def tangent_storage(x: float) -> float:
    return S0 + K * x


def secant_storage(x: float) -> float:
    if abs(x) <= 1.0e-16:
        return S0
    return volume_change(x) / x


def solve_replaced_sto(
    libmf6: Path,
    case_name: str,
    runtime_sy: float,
    numerical_correction_m3_per_day: float,
) -> dict[str, float | int | bool]:
    with tempfile.TemporaryDirectory(prefix=f"gc-hlink02-{case_name}-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            case_name,
            sy=CONFIGURED_SY,
            newton=False,
            well_rate_m3_per_day=INPUT / DT,
            initial_head_m=H0,
            dt_day=DT,
            ims_rclose=RCLOSE,
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
            require(
                math.isclose(
                    float(sy_ptr[0]),
                    CONFIGURED_SY,
                    rel_tol=0.0,
                    abs_tol=1.0e-15,
                ),
                "configured SY drift",
            )
            sy_ptr[:] = float(runtime_sy)
            require(
                float(sy_ptr[0]) == float(runtime_sy),
                "runtime SY replacement lost precision",
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

            # Q_api = HCOF*H - RHS.  The affine correction is a numerical
            # constant contribution, so HCOF=0 and RHS=-Q_corr.
            term = Term(
                groundwater_cell_id=1,
                hcof_m2_per_day=0.0,
                rhs_m3_per_day=-numerical_correction_m3_per_day,
            )

            accepted_head = float("nan")
            iterations = 0
            converged = False
            for _ in range(max(1, session.max_solve_iterations)):
                status, iterate = session.publish_and_solve_iteration(
                    (Binding(),),
                    (term,),
                )
                require(
                    status == PreparedSolveStatus.OK and iterate is not None,
                    f"MODFLOW solve failed: {status} {session.last_error}",
                )
                iterations = int(iterate.iteration)
                accepted_head = float(iterate.head_m[0])
                if bool(iterate.modflow_converged):
                    converged = True
                    break

            require(
                math.isfinite(accepted_head),
                "MODFLOW returned no finite head",
            )
            require(
                converged,
                "MODFLOW did not certify convergence",
            )
            require(
                session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                session.last_error,
            )
            require(
                session.timestep_ready_for_finalize(),
                "MODFLOW solve finalized but timestep not ready",
            )
            require(
                session.finalize_time_step_once() == PreparedSolveStatus.OK,
                session.last_error,
            )
            return {
                "head_m": accepted_head,
                "iterations": iterations,
                "modflow_converged": converged,
                "runtime_sy": float(sy_ptr[0]),
                "numerical_correction": numerical_correction_m3_per_day,
            }
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


def iterate_case(
    libmf6: Path,
    name: str,
    storage_rule: str,
    include_affine_correction: bool,
) -> tuple[float, list[dict[str, float | int]]]:
    anchor_x = 0.0
    history: list[dict[str, float | int]] = []

    for outer in range(1, MAX_OUTER + 1):
        if storage_rule == "secant":
            sy = secant_storage(anchor_x)
        elif storage_rule == "tangent":
            sy = tangent_storage(anchor_x)
        else:
            raise AssertionError(storage_rule)

        if include_affine_correction:
            correction = (
                sy * anchor_x - volume_change(anchor_x)
            ) / DT
        else:
            correction = 0.0

        solved = solve_replaced_sto(
            libmf6,
            f"{name.lower()}_{outer}",
            runtime_sy=sy,
            numerical_correction_m3_per_day=correction,
        )
        head = float(solved["head_m"])
        x = head - H0
        physical_residual = volume_change(x) - INPUT

        history.append(
            {
                "outer": outer,
                "anchor_x": anchor_x,
                "runtime_sy": sy,
                "correction": correction,
                "head": head,
                "physical_residual": physical_residual,
                "mf_iterations": int(solved["iterations"]),
            }
        )

        print(
            f"GC_HLINK02_{name}_OUTER_{outer}_ANCHOR_X_M="
            f"{anchor_x:.17g}"
        )
        print(
            f"GC_HLINK02_{name}_OUTER_{outer}_RUNTIME_SY="
            f"{sy:.17g}"
        )
        print(
            f"GC_HLINK02_{name}_OUTER_{outer}_NUMERICAL_CORRECTION_M3_PER_DAY="
            f"{correction:.17g}"
        )
        print(
            f"GC_HLINK02_{name}_OUTER_{outer}_HEAD_M={head:.17g}"
        )
        print(
            f"GC_HLINK02_{name}_OUTER_{outer}_PHYSICAL_RESIDUAL_M3="
            f"{physical_residual:.17g}"
        )

        if abs(physical_residual) <= MASS_TOL:
            return head, history
        anchor_x = x

    return float(history[-1]["head"]), history


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    require(
        math.isclose(
            volume_change(EXACT_X),
            INPUT,
            rel_tol=0.0,
            abs_tol=1.0e-14,
        ),
        "analytic nonlinear storage root",
    )
    require(
        math.isclose(
            secant_storage(EXACT_X),
            EXACT_SECANT,
            rel_tol=0.0,
            abs_tol=1.0e-14,
        ),
        "exact secant oracle",
    )
    require(
        math.isclose(
            tangent_storage(EXACT_X),
            EXACT_TANGENT,
            rel_tol=0.0,
            abs_tol=1.0e-14,
        ),
        "exact tangent oracle",
    )
    print("GC_HLINK02_ANALYTIC_STORAGE_ORACLE=PASS")

    secant_head, secant_history = iterate_case(
        libmf6,
        "SECANT",
        storage_rule="secant",
        include_affine_correction=False,
    )
    require(
        math.isclose(
            secant_head,
            EXACT_HEAD,
            rel_tol=0.0,
            abs_tol=HEAD_TOL,
        ),
        f"secant head {secant_head} != {EXACT_HEAD}",
    )
    require(
        abs(volume_change(secant_head - H0) - INPUT) <= MASS_TOL,
        "secant physical mass",
    )
    print(
        f"GC_HLINK02_SECANT_FINAL_SY="
        f"{float(secant_history[-1]['runtime_sy']):.17g}"
    )
    print("GC_HLINK02_SECANT_STORAGE_REPLACEMENT=PASS")

    tangent_head, tangent_history = iterate_case(
        libmf6,
        "TANGENT_AFFINE",
        storage_rule="tangent",
        include_affine_correction=True,
    )
    require(
        math.isclose(
            tangent_head,
            EXACT_HEAD,
            rel_tol=0.0,
            abs_tol=HEAD_TOL,
        ),
        f"tangent+affine head {tangent_head} != {EXACT_HEAD}",
    )
    require(
        abs(volume_change(tangent_head - H0) - INPUT) <= MASS_TOL,
        "tangent+affine physical mass",
    )
    require(
        abs(float(tangent_history[-1]["correction"])) > 1.0e-6,
        "affine correction was not exercised",
    )
    print(
        f"GC_HLINK02_TANGENT_FINAL_SY="
        f"{float(tangent_history[-1]['runtime_sy']):.17g}"
    )
    print(
        "GC_HLINK02_TANGENT_FINAL_NUMERICAL_CORRECTION_M3_PER_DAY="
        f"{float(tangent_history[-1]['correction']):.17g}"
    )
    print("GC_HLINK02_TANGENT_AFFINE_REPRESENTATION=PASS")

    wrong_head, wrong_history = iterate_case(
        libmf6,
        "TANGENT_ONLY",
        storage_rule="tangent",
        include_affine_correction=False,
    )
    require(
        math.isclose(
            wrong_head,
            8.05,
            rel_tol=0.0,
            abs_tol=HEAD_TOL,
        ),
        f"tangent-only wrong signature {wrong_head}",
    )
    wrong_residual = volume_change(wrong_head - H0) - INPUT
    require(
        abs(wrong_residual) > 1.0e-4,
        "tangent-only case did not violate nonlinear physical storage law",
    )
    require(
        abs(float(wrong_history[-1]["correction"])) <= 1.0e-18,
        "tangent-only case unexpectedly used correction",
    )
    print(
        f"GC_HLINK02_TANGENT_ONLY_PHYSICAL_RESIDUAL_M3="
        f"{wrong_residual:.17g}"
    )
    print("GC_HLINK02_TANGENT_ONLY_CONVERGED_WRONG=PASS")

    print("GC_HLINK02_NUMERICAL_CORRECTION_NOT_PHYSICAL_INPUT=PASS")
    print("GC_HLINK02_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
