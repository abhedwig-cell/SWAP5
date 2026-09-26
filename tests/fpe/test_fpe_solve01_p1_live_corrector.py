from __future__ import annotations
import json
import math
import os
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"src"/"adapter"))

from test_fgc44_real_swap_modflow_end_to_end import (
    AREA_M2, DAY_TO_S, FLUX_TOL, Binding, Term, CountingKernel, build_model, require
)
from fgc44_real_swap_ctypes import Fgc44RealSwap
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus

WINDOW_CM=0.010

def main()->None:
    if len(sys.argv)!=2:
        raise SystemExit("usage: POLICY")
    policy=sys.argv[1].lower()
    if policy not in ("exact","e4","eh"):
        raise SystemExit("policy must be exact/e4/eh")

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    swap=Fgc44RealSwap(swaplib)
    hcof,rhs,href=swap.initialize()
    origin_state=swap.state()
    require(origin_state==(0,0.0,0,0.0),"origin authority mismatch")

    anchor_h=href
    anchor_t=hcof/(AREA_M2*DAY_TO_S)
    anchor_q=(hcof*href-rhs)/(AREA_M2*DAY_TO_S)
    require(all(math.isfinite(x) for x in (anchor_h,anchor_q,anchor_t)),"invalid predictor anchor")
    current_hcof=hcof
    current_rhs=rhs
    since_exact=0

    exact_trials=0
    approximate_responses=0
    validation_count=0
    validation_failures=0
    max_anchor_displacement_cm=0.0
    final_head=None
    final_q_swap=None
    final_q_gw=None
    final_residual=None
    coupled_iterations=0

    with tempfile.TemporaryDirectory(prefix=f"solve01-p1-{policy}-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,href)
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=CountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            raw.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            accepted_xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]

            t0=time.perf_counter_ns()
            for outer in range(1,min(40,session.max_solve_iterations)+1):
                coupled_iterations=outer
                term=Term(7001,current_hcof,current_rhs)
                status,it=session.publish_and_solve_iteration(binding,[term])
                require(status==PreparedSolveStatus.OK,session.last_error)
                require(it is not None,f"missing MODFLOW iterate {outer}")
                require(np.array_equal(it.accepted_head_old_m,accepted_xold),"accepted XOLD drift")
                head=float(it.head_m[1])
                q_gw=(current_hcof*head-current_rhs)/(AREA_M2*DAY_TO_S)
                displacement_cm=abs(head-anchor_h)*100.0
                max_anchor_displacement_cm=max(max_anchor_displacement_cm,displacement_cm)

                force_exact=(policy=="exact")
                if policy=="e4" and since_exact>=3:
                    force_exact=True
                if policy=="eh" and displacement_cm>WINDOW_CM:
                    force_exact=True

                live_candidate=False
                if force_exact:
                    q_swap=swap.trial(head)
                    exact_trials+=1
                    q_diag,_,tangent,available=swap.last_trial_response()
                    require(available and math.isfinite(tangent),"exact tangent unavailable")
                    require(abs(q_diag-q_swap)<=64*np.finfo(float).eps*max(1.0,abs(q_swap)),
                            "exact q diagnostic mismatch")
                    anchor_h=head; anchor_q=q_swap; anchor_t=tangent; since_exact=0
                    live_candidate=True
                else:
                    q_swap=anchor_q+anchor_t*(head-anchor_h)
                    tangent=anchor_t
                    approximate_responses+=1
                    since_exact+=1

                residual=q_swap-q_gw
                require(all(math.isfinite(x) for x in (head,q_gw,q_swap,tangent,residual)),
                        "nonfinite coupled response")

                if it.modflow_converged and abs(residual)<=FLUX_TOL:
                    if live_candidate:
                        final_head=head; final_q_swap=q_swap; final_q_gw=q_gw; final_residual=residual
                        break

                    # Approximate convergence is advisory only. Validate exactly.
                    q_exact=swap.trial(head)
                    exact_trials+=1
                    validation_count+=1
                    q_diag,_,t_exact,available=swap.last_trial_response()
                    require(available and math.isfinite(t_exact),"validation tangent unavailable")
                    require(abs(q_diag-q_exact)<=64*np.finfo(float).eps*max(1.0,abs(q_exact)),
                            "validation q diagnostic mismatch")
                    exact_residual=q_exact-q_gw
                    if abs(exact_residual)<=FLUX_TOL:
                        final_head=head; final_q_swap=q_exact; final_q_gw=q_gw; final_residual=exact_residual
                        break

                    validation_failures+=1
                    anchor_h=head; anchor_q=q_exact; anchor_t=t_exact; since_exact=0
                    swap.discard()
                    current_hcof=t_exact*AREA_M2*DAY_TO_S
                    current_rhs=current_hcof*head-q_exact*AREA_M2*DAY_TO_S
                    require(swap.state()==origin_state,"failed validation changed authority")
                    continue

                if live_candidate:
                    swap.discard()
                    require(swap.state()==origin_state,"discarded exact corrector changed authority")

                current_hcof=tangent*AREA_M2*DAY_TO_S
                current_rhs=current_hcof*head-q_swap*AREA_M2*DAY_TO_S
            loop_ns=time.perf_counter_ns()-t0

            require(final_head is not None,"coupled corrector did not converge")
            require(swap.has_live_candidate(),"final exact SWAP candidate unavailable")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(swap.swap_preflight(),"SWAP preflight failed")
            swap.prepare_ledger()
            require(swap.ledger_preflight(),"ledger preflight failed")
            require(session.timestep_ready_for_finalize(),"MODFLOW timestep not ready")
            require(swap.state()==origin_state,"prepublication authority drift")

            require(session.finalize_time_step_once()==PreparedSolveStatus.OK,session.last_error)
            require(swap.state()==origin_state,"MODFLOW publication changed SWAP authority")
            swap.commit_swap()
            mid_state=swap.state()
            require(mid_state[0]==1 and mid_state[2]==0,"SWAP commit semantics")
            swap.commit_ledger()
            final_state=swap.state()
            require(final_state[0]==1 and final_state[2]==1,"ledger commit semantics")
            raw.finalize(); initialized=False
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass

    print("SOLVE01_P1_RAW|"+json.dumps({
        "policy":policy,
        "iterations":coupled_iterations,
        "exact_trials":exact_trials,
        "approximate_responses":approximate_responses,
        "validation_count":validation_count,
        "validation_failures":validation_failures,
        "loop_ns":loop_ns,
        "final_head":final_head,
        "final_q_swap":final_q_swap,
        "final_q_gw":final_q_gw,
        "final_residual":final_residual,
        "max_anchor_displacement_cm":max_anchor_displacement_cm,
        "revision":final_state[0],
        "time_day":final_state[1],
        "ledger_count":final_state[2],
        "ledger_exchange":final_state[3],
        "prepare_solve_calls":kernel.prepare_solve_calls,
        "solve_calls":kernel.solve_calls,
        "finalize_solve_calls":kernel.finalize_solve_calls,
        "finalize_time_step_calls":kernel.finalize_time_step_calls,
    },separators=(",",":")))

if __name__=="__main__":
    main()
