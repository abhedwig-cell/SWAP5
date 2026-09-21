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
INPUT_RATE = 0.010
DT = 1.0
HEAD_TOL = 1.0e-10
MASS_TOL = 1.0e-12


def run_case(
    libmf6: Path,
    name: str,
    runtime_sy: float | None,
    api_storage: float,
) -> dict[str, float | int | bool | str]:
    with tempfile.TemporaryDirectory(prefix=f"gc-hlink01-{name}-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            name,
            sy=CONFIGURED_SY,
            newton=False,
            well_rate_m3_per_day=INPUT_RATE,
            initial_head_m=H0,
            dt_day=DT,
        )

        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        result: dict[str, float | int | bool | str] = {
            "converged": False,
            "head_m": float("nan"),
            "iterations": 0,
            "configured_sy": float("nan"),
            "runtime_sy": float("nan"),
            "status": "not-run",
        }
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW6 version")

            x = raw.get_value_ptr(raw.get_var_address("X", "GWF_1"))
            xold = raw.get_value_ptr(raw.get_var_address("XOLD", "GWF_1"))
            x[:] = H0
            xold[:] = H0

            sy_ptr = raw.get_value_ptr(raw.get_var_address("SY", "GWF_1", "STO"))
            result["configured_sy"] = float(sy_ptr[0])
            require(
                math.isclose(
                    float(sy_ptr[0]),
                    CONFIGURED_SY,
                    rel_tol=0.0,
                    abs_tol=1.0e-15,
                ),
                f"configured SY {sy_ptr[0]} != {CONFIGURED_SY}",
            )

            if runtime_sy is not None:
                sy_ptr[:] = float(runtime_sy)
            result["runtime_sy"] = float(sy_ptr[0])
            if runtime_sy is not None:
                require(
                    float(sy_ptr[0]) == float(runtime_sy),
                    "XMI STO/SY replacement did not read back bit-for-bit",
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
                session.acquire_after_prepare_time_step() == PreparedSolveStatus.OK,
                f"acquire failed: {session.last_error}",
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                f"open failed: {session.last_error}",
            )

            hcof = -api_storage / DT
            rhs = hcof * H0
            term = Term(
                groundwater_cell_id=1,
                hcof_m2_per_day=hcof,
                rhs_m3_per_day=rhs,
            )

            for _ in range(max(1, session.max_solve_iterations)):
                status, iterate = session.publish_and_solve_iteration(
                    (Binding(),),
                    (term,),
                )
                require(
                    status == PreparedSolveStatus.OK and iterate is not None,
                    f"solve failed: {status} {session.last_error}",
                )
                result["iterations"] = int(iterate.iteration)
                result["head_m"] = float(iterate.head_m[0])
                if bool(iterate.modflow_converged):
                    result["converged"] = True
                    result["status"] = "converged"
                    break

            require(bool(result["converged"]), f"{name} did not converge: {result}")
            require(
                session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                f"finalize solve failed: {session.last_error}",
            )
            require(session.timestep_ready_for_finalize(), "timestep not ready")
            require(
                session.finalize_time_step_once() == PreparedSolveStatus.OK,
                f"finalize timestep failed: {session.last_error}",
            )
            return result
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    unreplaced = run_case(
        libmf6,
        "unreplaced",
        runtime_sy=None,
        api_storage=0.0,
    )
    replacement = run_case(
        libmf6,
        "replacement",
        runtime_sy=SHARED_STORAGE,
        api_storage=0.0,
    )
    duplicate = run_case(
        libmf6,
        "replacement_plus_duplicate_api",
        runtime_sy=SHARED_STORAGE,
        api_storage=SHARED_STORAGE,
    )

    expected_unreplaced = H0 + INPUT_RATE * DT / CONFIGURED_SY
    expected_replacement = H0 + INPUT_RATE * DT / SHARED_STORAGE
    expected_duplicate = H0 + INPUT_RATE * DT / (2.0 * SHARED_STORAGE)

    for label, result, expected in (
        ("UNREPLACED", unreplaced, expected_unreplaced),
        ("REPLACEMENT", replacement, expected_replacement),
        ("DUPLICATE", duplicate, expected_duplicate),
    ):
        head = float(result["head_m"])
        print(f"GC_HLINK01_{label}_CONFIGURED_SY={float(result['configured_sy']):.17g}")
        print(f"GC_HLINK01_{label}_RUNTIME_SY={float(result['runtime_sy']):.17g}")
        print(f"GC_HLINK01_{label}_HEAD_M={head:.17g}")
        print(f"GC_HLINK01_{label}_EXPECTED_HEAD_M={expected:.17g}")
        print(f"GC_HLINK01_{label}_HEAD_ERROR_M={head-expected:.17g}")
        print(f"GC_HLINK01_{label}_ITERATIONS={int(result['iterations'])}")
        require(
            math.isclose(head, expected, rel_tol=0.0, abs_tol=HEAD_TOL),
            f"{label} head {head} != {expected}",
        )

    replacement_gain = SHARED_STORAGE * (float(replacement["head_m"]) - H0)
    duplicate_geometric_gain = SHARED_STORAGE * (float(duplicate["head_m"]) - H0)
    duplicate_sto_bookkeeping = SHARED_STORAGE * (float(duplicate["head_m"]) - H0)
    duplicate_api_bookkeeping = SHARED_STORAGE * (float(duplicate["head_m"]) - H0)
    duplicate_total_bookkeeping = duplicate_sto_bookkeeping + duplicate_api_bookkeeping

    print(f"GC_HLINK01_REPLACEMENT_GEOMETRIC_GAIN_M3={replacement_gain:.17g}")
    print(f"GC_HLINK01_DUPLICATE_GEOMETRIC_GAIN_M3={duplicate_geometric_gain:.17g}")
    print(f"GC_HLINK01_DUPLICATE_STO_BOOKKEEPING_M3={duplicate_sto_bookkeeping:.17g}")
    print(f"GC_HLINK01_DUPLICATE_API_BOOKKEEPING_M3={duplicate_api_bookkeeping:.17g}")
    print(f"GC_HLINK01_DUPLICATE_TOTAL_BOOKKEEPING_M3={duplicate_total_bookkeeping:.17g}")

    require(
        math.isclose(replacement_gain, INPUT_RATE * DT, rel_tol=0.0, abs_tol=MASS_TOL),
        "replacement one-volume mass oracle",
    )
    require(
        math.isclose(duplicate_geometric_gain, 0.005, rel_tol=0.0, abs_tol=MASS_TOL),
        "duplicate geometric gain",
    )
    require(
        math.isclose(duplicate_total_bookkeeping, INPUT_RATE * DT, rel_tol=0.0, abs_tol=MASS_TOL),
        "duplicate numerical bookkeeping",
    )
    require(
        math.isclose(
            INPUT_RATE * DT - duplicate_geometric_gain,
            0.005,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        "duplicate physical volume deficit",
    )

    print("GC_HLINK01_XMI_STORAGE_REPLACEMENT=PASS")
    print("GC_HLINK01_ONE_VOLUME_MASS=PASS")
    print("GC_HLINK01_DUPLICATE_STORAGE_SIGNATURE=PASS")
    print("GC_HLINK01_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
