from __future__ import annotations

from dataclasses import dataclass
import math
import os
import sys
import tempfile
from pathlib import Path

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src" / "adapter"))

from modflow6_prepared_solve_session import (
    Modflow6PreparedSolveSession,
    PreparedSolveStatus,
)


H0_M = 8.0
TOP_M = 10.0
BOT_M = 0.0
AREA_M2 = 1.0
SY = 0.20
DT_DAY = 1.0
PRECIP_M = 0.010
EXPECTED_CONTROL_HEAD_M = 8.050
CONTROL_TOL_M = 1.0e-8


@dataclass(frozen=True)
class Binding:
    groundwater_cell_id: int = 1
    package_slot: int = 1
    modflow_node_id: int = 1


@dataclass(frozen=True)
class Term:
    groundwater_cell_id: int
    hcof_m2_per_day: float
    rhs_m3_per_day: float
    valid: bool = True


class DirectApiPublisher:
    """Minimal publisher with the same package-array semantics as F-GC34."""

    def __call__(
        self,
        bindings,
        terms,
        maxbound,
        nodelist,
        hcof,
        rhs,
        nbound,
    ) -> int:
        if len(bindings) != 1 or len(terms) != 1 or maxbound < 1:
            return 1
        binding = bindings[0]
        term = terms[0]
        if (
            int(binding.package_slot) != 1
            or int(binding.modflow_node_id) != 1
            or int(binding.groundwater_cell_id) != int(term.groundwater_cell_id)
        ):
            return 2
        if not math.isfinite(float(term.hcof_m2_per_day)) or not math.isfinite(
            float(term.rhs_m3_per_day)
        ):
            return 3

        nodelist[:] = 0
        hcof[:] = 0.0
        rhs[:] = 0.0
        nodelist[0] = 1
        hcof[0] = float(term.hcof_m2_per_day)
        rhs[0] = float(term.rhs_m3_per_day)
        nbound[0] = 1
        return 0


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def build_model(
    workdir: Path,
    name: str,
    sy: float = SY,
    newton: bool = True,
    well_rate_m3_per_day: float = 0.0,
    initial_head_m: float = H0_M,
    dt_day: float = DT_DAY,
    ims_complexity: str = "MODERATE",
    ims_under_relaxation: str | None = None,
    ims_rclose: float = 1.0e-15,
) -> None:
    sim = flopy.mf6.MFSimulation(
        sim_name=name,
        version="mf6",
        sim_ws=str(workdir),
    )
    flopy.mf6.ModflowTdis(
        sim,
        time_units="DAYS",
        nper=1,
        perioddata=[(float(dt_day), 1, 1.0)],
    )
    flopy.mf6.ModflowIms(
        sim,
        complexity=str(ims_complexity),
        under_relaxation=ims_under_relaxation,
        outer_dvclose=1.0e-12,
        inner_dvclose=1.0e-14,
        rcloserecord=[float(ims_rclose), "strict"],
        outer_maximum=100,
        inner_maximum=200,
    )
    gwf = flopy.mf6.ModflowGwf(
        sim,
        modelname="GWF_1",
        save_flows=True,
        newtonoptions="NEWTON" if newton else None,
    )
    flopy.mf6.ModflowGwfdis(
        gwf,
        nlay=1,
        nrow=1,
        ncol=1,
        delr=1.0,
        delc=1.0,
        top=TOP_M,
        botm=BOT_M,
    )
    flopy.mf6.ModflowGwfic(gwf, strt=np.array([[[float(initial_head_m)]]], dtype=float))
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=1, k=1.0, save_flows=True)
    flopy.mf6.ModflowGwfsto(
        gwf,
        iconvert=1,
        ss=0.0,
        sy=float(sy),
        transient={0: True},
        save_flows=True,
    )
    if well_rate_m3_per_day != 0.0:
        flopy.mf6.ModflowGwfwel(
            gwf,
            stress_period_data={0: [((0, 0, 0), float(well_rate_m3_per_day))]},
            pname="KNOWN_SOURCE",
            save_flows=True,
        )
    flopy.mf6.ModflowGwfapi(
        gwf,
        maxbound=1,
        pname="API_SWAP",
        filename="api_swap.api",
    )
    sim.write_simulation(silent=True)


def run_case(
    libmf6: Path,
    case_name: str,
    hcof_m2_per_day: float,
    rhs_m3_per_day: float,
    sy: float = SY,
    newton: bool = True,
    well_rate_m3_per_day: float = 0.0,
    initial_head_m: float = H0_M,
    dt_day: float = DT_DAY,
    ims_complexity: str = "MODERATE",
    ims_under_relaxation: str | None = None,
    ims_rclose: float = 1.0e-15,
) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix=f"gc-dsw01-{case_name}-") as tmp:
        workdir = Path(tmp)
        build_model(
            workdir,
            case_name,
            sy=sy,
            newton=newton,
            well_rate_m3_per_day=well_rate_m3_per_day,
            initial_head_m=initial_head_m,
            dt_day=dt_day,
            ims_complexity=ims_complexity,
            ims_under_relaxation=ims_under_relaxation,
            ims_rclose=ims_rclose,
        )

        raw = XmiWrapper(lib_path=libmf6, working_directory=workdir)
        initialized = False
        result: dict[str, object] = {
            "case": case_name,
            "converged": False,
            "head_m": float("nan"),
            "iterations": 0,
            "status": "not-run",
            "error": "",
        }
        try:
            raw.initialize()
            initialized = True
            require("6.8.0" in raw.get_version(), "wrong MODFLOW6 version")

            # FloPy writes IC heads through formatted MODFLOW input. For
            # substep/restart oracles that formatting can round an accepted
            # floating-point state before the next fresh simulation starts.
            # Reset both the current and previous model state through XMI so
            # the requested coupling state is carried bit-for-bit.
            x = raw.get_value_ptr(raw.get_var_address("X", "GWF_1"))
            xold = raw.get_value_ptr(raw.get_var_address("XOLD", "GWF_1"))
            x[:] = float(initial_head_m)
            xold[:] = float(initial_head_m)
            result["initialized_x_m"] = float(x[0])
            result["initialized_xold_m"] = float(xold[0])
            require(
                float(x[0]) == float(initial_head_m),
                "XMI current-head initialization lost precision",
            )
            require(
                float(xold[0]) == float(initial_head_m),
                "XMI previous-head initialization lost precision",
            )

            raw.prepare_time_step(0.0)
            result["model_dt_day"] = float(raw.get_time_step())

            session = Modflow6PreparedSolveSession(
                raw,
                "GWF_1",
                "API_SWAP",
                DirectApiPublisher(),
                solution_id=1,
            )
            acquire = session.acquire_after_prepare_time_step()
            if acquire != PreparedSolveStatus.OK:
                result["status"] = f"acquire:{acquire.name}"
                result["error"] = session.last_error
                return result
            opened = session.open_prepared_solve()
            if opened != PreparedSolveStatus.OK:
                result["status"] = f"open:{opened.name}"
                result["error"] = session.last_error
                return result

            binding = Binding()
            term = Term(
                groundwater_cell_id=1,
                hcof_m2_per_day=hcof_m2_per_day,
                rhs_m3_per_day=rhs_m3_per_day,
            )

            for _ in range(max(1, session.max_solve_iterations)):
                status, iterate = session.publish_and_solve_iteration(
                    (binding,), (term,)
                )
                if status != PreparedSolveStatus.OK or iterate is None:
                    result["status"] = f"solve:{status.name}"
                    result["error"] = session.last_error
                    break
                result["iterations"] = int(iterate.iteration)
                result["head_m"] = float(iterate.head_m[0])
                result["status"] = "iterating"
                if bool(iterate.modflow_converged):
                    result["converged"] = True
                    result["status"] = "converged"
                    break

            if bool(result["converged"]):
                finalized = session.finalize_prepared_solve()
                if finalized != PreparedSolveStatus.OK:
                    result["status"] = f"finalize-solve:{finalized.name}"
                    result["error"] = session.last_error
                    result["converged"] = False
                    return result
                if not session.timestep_ready_for_finalize():
                    result["status"] = "timestep-not-ready"
                    result["converged"] = False
                    return result
                final_ts = session.finalize_time_step_once()
                if final_ts != PreparedSolveStatus.OK:
                    result["status"] = f"finalize-timestep:{final_ts.name}"
                    result["error"] = session.last_error
                    result["converged"] = False
                    return result
            else:
                session.invalidate_without_finalize()

            return result
        except Exception as exc:
            result["status"] = "exception"
            result["error"] = f"{type(exc).__name__}: {exc}"
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

    # Control: fixed +10 mm/day into a 1 m2 cell. F-GC33 convention is
    # Q(H)=HCOF*H-RHS, hence RHS=-0.010 m3/day for a constant positive inflow.
    control = run_case(
        libmf6,
        "flux_only",
        hcof_m2_per_day=0.0,
        rhs_m3_per_day=-(PRECIP_M * AREA_M2 / DT_DAY),
        newton=False,
    )
    require(bool(control["converged"]), f"control did not converge: {control}")
    control_error_m = float(control["head_m"]) - EXPECTED_CONTROL_HEAD_M
    control_oracle_pass = math.isclose(
        float(control["head_m"]),
        EXPECTED_CONTROL_HEAD_M,
        rel_tol=0.0,
        abs_tol=CONTROL_TOL_M,
    )

    # Current coupling transform for the transparent qbot=0 dummy:
    # u=0.20, Href=8.05, qref=0.01 m/day.
    # HCOF=A*u/dt = 0.20 m2/day
    # RHS=HCOF*Href-A*qref = 1.60 m3/day.
    current = run_case(
        libmf6,
        "current_u",
        hcof_m2_per_day=0.20,
        rhs_m3_per_day=1.60,
        newton=False,
    )

    # Separate source-derived MODFLOW Newton regularization oracle.
    smoothed_control = run_case(
        libmf6,
        "flux_only_newton",
        hcof_m2_per_day=0.0,
        rhs_m3_per_day=-(PRECIP_M * AREA_M2 / DT_DAY),
        newton=True,
    )
    expected_smoothed_head_m = H0_M + (PRECIP_M / SY) * (1.0 - 1.0e-6)
    smoothed_error_m = float(smoothed_control["head_m"]) - expected_smoothed_head_m

    print(f"GC_DSW01_CONTROL_HEAD_M={float(control['head_m']):.17g}")
    print(f"GC_DSW01_CONTROL_ITERATIONS={int(control['iterations'])}")
    print(f"GC_DSW01_CONTROL_MODEL_DT_DAY={float(control.get('model_dt_day', float('nan'))):.17g}")
    print(f"GC_DSW01_CONTROL_ERROR_M={control_error_m:.17g}")
    print(f"GC_DSW01_CONTROL_ORACLE_PASS={1 if control_oracle_pass else 0}")
    print(f"GC_DSW01_NEWTON_CONTROL_HEAD_M={float(smoothed_control['head_m']):.17g}")
    print(f"GC_DSW01_NEWTON_CONTROL_EXPECTED_M={expected_smoothed_head_m:.17g}")
    print(f"GC_DSW01_NEWTON_CONTROL_ERROR_M={smoothed_error_m:.17g}")
    print(f"GC_DSW01_CURRENT_U_STATUS={current['status']}")
    print(f"GC_DSW01_CURRENT_U_CONVERGED={1 if current['converged'] else 0}")
    if math.isfinite(float(current["head_m"])):
        print(f"GC_DSW01_CURRENT_U_HEAD_M={float(current['head_m']):.17g}")
    else:
        print("GC_DSW01_CURRENT_U_HEAD_M=NONFINITE_OR_UNAVAILABLE")
    print(f"GC_DSW01_CURRENT_U_ITERATIONS={int(current['iterations'])}")
    if current["error"]:
        print(f"GC_DSW01_CURRENT_U_ERROR={current['error']}")
    print("GC_DSW01_LIVE_PROBE_COMPLETED=PASS")

    require(bool(smoothed_control["converged"]), f"Newton smoothing control did not converge: {smoothed_control}")
    require(
        math.isclose(
            float(smoothed_control["head_m"]),
            expected_smoothed_head_m,
            rel_tol=0.0,
            abs_tol=CONTROL_TOL_M,
        ),
        f"Newton smoothing source oracle mismatch: {smoothed_control['head_m']} != {expected_smoothed_head_m}",
    )
    print("GC_DSW01_MODFLOW_NEWTON_SMOOTHING_ORACLE=PASS")

    # Preserve the preregistered 1e-8 m control gate, but only after all
    # diagnostic observations have been emitted.
    require(
        control_oracle_pass,
        f"control head {control['head_m']} != {EXPECTED_CONTROL_HEAD_M} "
        f"within {CONTROL_TOL_M}",
    )
    print("GC_DSW01_LIVE_FLUX_ONLY_CONTROL=PASS")


if __name__ == "__main__":
    main()
