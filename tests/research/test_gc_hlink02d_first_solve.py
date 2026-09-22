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
SY = 0.15
INPUT = 0.01
DT = 1.0
EXPECTED = H0 + INPUT * DT / SY
HEAD_TOL = 1.0e-10

VARIANTS = (
    ("NO_WRITE_R1E15", False, 1.0e-15),
    ("WRITE_SAME_R1E15", True, 1.0e-15),
    ("NO_WRITE_R1E13", False, 1.0e-13),
    ("WRITE_SAME_R1E13", True, 1.0e-13),
)


def run_variant(
    libmf6: Path,
    label: str,
    write_sy: bool,
    rclose: float,
) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix=f"gc-hlink02d-{label.lower()}-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            label.lower(),
            sy=SY,
            newton=False,
            well_rate_m3_per_day=INPUT,
            initial_head_m=H0,
            dt_day=DT,
            ims_rclose=rclose,
        )

        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        history: list[tuple[int, float, bool]] = []
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW6 version")

            x = raw.get_value_ptr(raw.get_var_address("X", "GWF_1"))
            xold = raw.get_value_ptr(raw.get_var_address("XOLD", "GWF_1"))
            x[:] = H0
            xold[:] = H0

            sy_ptr = raw.get_value_ptr(raw.get_var_address("SY", "GWF_1", "STO"))
            configured_sy = float(sy_ptr[0])
            require(
                math.isclose(configured_sy, SY, rel_tol=0.0, abs_tol=1.0e-15),
                f"{label} configured SY drift",
            )
            if write_sy:
                sy_ptr[:] = SY
            runtime_sy = float(sy_ptr[0])

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
                f"{label} acquire: {session.last_error}",
            )
            require(
                session.open_prepared_solve() == PreparedSolveStatus.OK,
                f"{label} open: {session.last_error}",
            )

            term = Term(
                groundwater_cell_id=1,
                hcof_m2_per_day=0.0,
                rhs_m3_per_day=0.0,
            )

            converged = False
            head = float("nan")
            for _ in range(max(1, session.max_solve_iterations)):
                status, iterate = session.publish_and_solve_iteration(
                    (Binding(),), (term,)
                )
                require(
                    status == PreparedSolveStatus.OK and iterate is not None,
                    f"{label} solve: {status} {session.last_error}",
                )
                head = float(iterate.head_m[0])
                mf = bool(iterate.modflow_converged)
                history.append((int(iterate.iteration), head, mf))
                if mf:
                    converged = True
                    break

            ready_before_finalize = session.timestep_ready_for_finalize()
            ready = False
            if converged:
                require(
                    session.finalize_prepared_solve() == PreparedSolveStatus.OK,
                    f"{label} finalize solve: {session.last_error}",
                )
                ready = session.timestep_ready_for_finalize()
                require(ready, f"{label} finalized solve but timestep not ready")
                require(
                    session.finalize_time_step_once() == PreparedSolveStatus.OK,
                    f"{label} finalize timestep: {session.last_error}",
                )
            else:
                session.invalidate_without_finalize()

            return {
                "label": label,
                "write_sy": write_sy,
                "rclose": rclose,
                "configured_sy": configured_sy,
                "runtime_sy": runtime_sy,
                "converged": converged,
                "ready_before_finalize": ready_before_finalize,
                "ready": ready,
                "head": head,
                "head_error": head - EXPECTED,
                "iterations": len(history),
                "history": history,
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

    results = [
        run_variant(libmf6, label, write_sy, rclose)
        for label, write_sy, rclose in VARIANTS
    ]

    for result in results:
        label = str(result["label"])
        print(f"GC_HLINK02D_{label}_CONFIGURED_SY={float(result['configured_sy']):.17g}")
        print(f"GC_HLINK02D_{label}_RUNTIME_SY={float(result['runtime_sy']):.17g}")
        print(f"GC_HLINK02D_{label}_RCLOSE={float(result['rclose']):.17g}")
        print(f"GC_HLINK02D_{label}_WRITE_SY={1 if result['write_sy'] else 0}")
        print(f"GC_HLINK02D_{label}_HEAD_M={float(result['head']):.17g}")
        print(f"GC_HLINK02D_{label}_HEAD_ERROR_M={float(result['head_error']):.17g}")
        print(f"GC_HLINK02D_{label}_CONVERGED={1 if result['converged'] else 0}")
        print(
            f"GC_HLINK02D_{label}_READY_BEFORE_FINALIZE="
            f"{1 if result['ready_before_finalize'] else 0}"
        )
        print(f"GC_HLINK02D_{label}_READY={1 if result['ready'] else 0}")
        print(f"GC_HLINK02D_{label}_ITERATIONS={int(result['iterations'])}")
        require(
            math.isclose(
                float(result["head"]),
                EXPECTED,
                rel_tol=0.0,
                abs_tol=HEAD_TOL,
            ),
            f"{label} physical head mismatch",
        )

    control = next(r for r in results if r["label"] == "NO_WRITE_R1E15")
    require(bool(control["converged"]), f"HLINK01 control not reproduced: {control}")
    require(bool(control["ready"]), f"HLINK01 control not ready: {control}")

    print(f"GC_HLINK02D_EXPECTED_HEAD_M={EXPECTED:.17g}")
    print("GC_HLINK02D_PHYSICAL_HEAD_ALL_VARIANTS=PASS")
    print("GC_HLINK02D_HLINK01_CONTROL_REPRODUCED=PASS")
    print("GC_HLINK02D_CERTIFICATION_CHARACTERIZATION_RECORDED=PASS")
    print("GC_HLINK02D_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
