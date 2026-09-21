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

H0=8.0
S0=0.15
K=1.0
INPUT=0.010
RESIDUAL_TOL=1.0e-12
HEAD_TOL=1.0e-10
RCLOSES=(1.0e-15,1.0e-14,1.0e-13,1.0e-12)

def storage_change(h: float)->float:
    x=h-H0
    return S0*x+0.5*K*x*x

def residual(h: float)->float:
    return INPUT-storage_change(h)

def tangent(h: float)->float:
    return -(S0+K*(h-H0))

def exact_head()->float:
    return H0+(-S0+math.sqrt(S0*S0+2.0*K*INPUT))/K

def run_variant(libmf6: Path, rclose: float)->dict[str,object]:
    label=f"R{rclose:.0e}".replace("-","M")
    with tempfile.TemporaryDirectory(prefix=f"gc-dsw09x-{label.lower()}-") as tmp:
        wd=Path(tmp)
        build_model(
            wd,
            f"dsw09x_{label.lower()}",
            sy=0.0,
            newton=False,
            ims_complexity="MODERATE",
            ims_under_relaxation="NONE",
            ims_rclose=rclose,
        )
        raw=XmiWrapper(lib_path=libmf6,working_directory=wd)
        initialized=False
        try:
            raw.initialize(); initialized=True
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(
                raw,"GWF_1","API_SWAP",DirectApiPublisher(),solution_id=1
            )
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,f"{label}: acquire")
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,f"{label}: open")
            href=H0
            accepted=float("nan")
            last_head=float("nan")
            last_res=float("nan")
            last_mf=False
            niter=0
            for iteration in range(1,81):
                niter=iteration
                qref=residual(href)
                hcof=tangent(href)
                rhs=hcof*href-qref
                status,it=session.publish_and_solve_iteration(
                    (Binding(),),
                    (Term(groundwater_cell_id=1,hcof_m2_per_day=hcof,rhs_m3_per_day=rhs),),
                )
                require(status==PreparedSolveStatus.OK and it is not None,f"{label}: solve {status}")
                last_head=float(it.head_m[0])
                last_res=residual(last_head)
                last_mf=bool(it.modflow_converged)
                if iteration<=6 or iteration in (10,20,40,80) or last_mf:
                    print(
                        f"GC_DSW09X_{label}_ITER_{iteration}_HREF_M={href:.17g} "
                        f"HEAD_M={last_head:.17g} RESIDUAL={last_res:.17g} "
                        f"MF_CONVERGED={1 if last_mf else 0}"
                    )
                if last_mf and abs(last_res)<=RESIDUAL_TOL:
                    accepted=last_head
                    break
                href=last_head
            if math.isfinite(accepted):
                require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,f"{label}: finalize solve")
                require(session.timestep_ready_for_finalize(),f"{label}: timestep ready")
                require(session.finalize_time_step_once()==PreparedSolveStatus.OK,f"{label}: finalize timestep")
            else:
                session.invalidate_without_finalize()
            return {
                "label":label,"rclose":rclose,"accepted_head":accepted,
                "last_head":last_head,"last_residual":last_res,
                "last_mf":last_mf,"iterations":niter
            }
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(),"missing libmf6")
    expected=exact_head()
    results={r:run_variant(libmf6,r) for r in RCLOSES}
    for r,res in results.items():
        label=str(res["label"])
        print(f"GC_DSW09X_{label}_LAST_HEAD_M={float(res['last_head']):.17g}")
        print(f"GC_DSW09X_{label}_LAST_RESIDUAL={float(res['last_residual']):.17g}")
        print(f"GC_DSW09X_{label}_MF_CONVERGED={1 if res['last_mf'] else 0}")
        print(f"GC_DSW09X_{label}_ITERATIONS={int(res['iterations'])}")
        print(f"GC_DSW09X_{label}_CLOSED={1 if math.isfinite(float(res['accepted_head'])) else 0}")
    target=results[1.0e-13]
    require(math.isfinite(float(target["accepted_head"])),f"1e-13 did not close: {target}")
    require(math.isclose(float(target["accepted_head"]),expected,rel_tol=0.0,abs_tol=HEAD_TOL),f"1e-13 head mismatch: {target}")
    require(abs(float(target["last_residual"]))<=RESIDUAL_TOL,f"1e-13 external residual: {target}")
    require(bool(target["last_mf"]),f"1e-13 MODFLOW certificate: {target}")
    print("GC_DSW09X_R1E13_STRICT_COUPLED_GATE=PASS")
    print("GC_DSW09X_RESIDUAL_SWEEP_RECORDED=PASS")
    print("GC_DSW09X_DIAGNOSTIC_GATE=PASS")

if __name__=="__main__":
    main()
