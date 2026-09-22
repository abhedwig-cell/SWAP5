from __future__ import annotations

import ast
import json
import math
import os
import sys
import tempfile
from pathlib import Path

import numpy as np
from xmipy import XmiWrapper

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"src"/"adapter"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession, PreparedSolveStatus
from test_fgc44_real_swap_modflow_end_to_end import AREA_M2,DAY_TO_S,Binding,CountingKernel,Term
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import build_model, initialize_case

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G20_PREREGISTRATION.json"
G19=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G19_RESULT.json"
SESSION_SOURCE=ROOT/"src"/"adapter"/"modflow6_prepared_solve_session.py"


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


class LifecycleCountingKernel(CountingKernel):
    def __init__(self,kernel:XmiWrapper)->None:
        super().__init__(kernel)
        self.prepare_time_step_calls=0

    def prepare_time_step(self,dt:float)->None:
        self.prepare_time_step_calls+=1
        self.kernel.prepare_time_step(dt)


def no_direct_x_control_source_gate()->dict[str,object]:
    source=Path(__file__).read_text()
    tree=ast.parse(source)
    forbidden=[]
    for node in ast.walk(tree):
        if not isinstance(node,(ast.Assign,ast.AnnAssign,ast.AugAssign)):
            continue
        targets=node.targets if isinstance(node,ast.Assign) else [node.target]
        for target in targets:
            if isinstance(target,ast.Subscript):
                value=target.value
                if isinstance(value,ast.Attribute) and isinstance(value.value,ast.Name):
                    if value.value.id=="session" and value.attr in {"head","xold","accepted_xold"}:
                        forbidden.append(f"session.{value.attr}[]")
            if isinstance(target,ast.Attribute) and isinstance(target.value,ast.Name):
                if target.value.id=="session" and target.attr in {"head","xold","accepted_xold"}:
                    forbidden.append(f"session.{target.attr}")
    require(not forbidden,f"G20 test directly controls MODFLOW state: {forbidden}")
    return {"direct_session_x_control":[]}


def main()->None:
    prereg=json.loads(PREREG.read_text())
    g19=json.loads(G19.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G20","wrong G20 preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G20 preregistration not frozen")
    require(g19["decision"]=="QUALIFIED_BOUNDED_AFFINE_RESPONSE_SPACE_TO_HEAD_SPACE_P4_BRIDGE",
            "G20 parent G19 authority drift")

    audit=no_direct_x_control_source_gate()
    print("FGC44_G20_SOURCE_AUDIT_JSON="+json.dumps(audit,sort_keys=True,separators=(",",":")))

    frozen=prereg["frozen_g19"]
    model=prereg["frozen_groundwater_model"]
    lambdas=tuple(float(x) for x in frozen["lambda_sequence"])
    require(lambdas==(1.0,0.5,0.25),"G20 lambda sequence drift")
    require(float(frozen["current_head_m"])==float(g19["frozen_bridge"]["current_head_m"]),"G20 h0 authority drift")
    require(float(frozen["physical_tangent_per_s"])==float(g19["frozen_bridge"]["physical_tangent_per_s"]),"G20 p authority drift")
    require(float(frozen["current_residual_m_per_s"])==float(g19["frozen_bridge"]["current_residual_m_per_s"]),"G20 r0 authority drift")
    require(float(frozen["groundwater_a_per_s"])==float(g19["groundwater_fit"]["a_per_s"]),"G20 groundwater slope authority drift")
    require(float(frozen["groundwater_intercept"])==float(g19["groundwater_fit"]["intercept"]),"G20 groundwater intercept authority drift")

    result_by_lambda={float(x["lambda"]):x for x in g19["lambda_results"]}
    for lam in lambdas:
        key=str(lam)
        require(math.isclose(float(frozen["fresh_reference_heads_m"][key]),float(result_by_lambda[lam]["live_head_m"]),
                             rel_tol=0.0,abs_tol=0.0),f"G20 fresh head authority drift lambda={lam}")
        require(int(frozen["fresh_reference_status"][key])==int(result_by_lambda[lam]["participant_status"]),
                f"G20 fresh status authority drift lambda={lam}")

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing FGC44 SWAP library")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(
        swap,float(model["duration_day"]),float(model["predictor_qbot_cm_per_day"])
    )
    h0=float(frozen["current_head_m"])
    require(math.isclose(href,h0,rel_tol=0.0,abs_tol=1e-14),"G20 href drift")
    sy=0.5*float(diag["u"])
    require(origin==(0,0.0,0,0.0),"G20 dirty SWAP origin")
    swap.g16_begin_session()

    a=float(frozen["groundwater_a_per_s"])
    b=float(frozen["groundwater_intercept"])
    p=float(frozen["physical_tangent_per_s"])
    r0=float(frozen["current_residual_m_per_s"])
    g0=a*h0+b
    hcof=p*AREA_M2*DAY_TO_S

    rows=[]
    with tempfile.TemporaryDirectory(prefix="fgc44-g20-mf-") as tmp:
        workdir=Path(tmp)
        build_model(
            workdir,float(model["duration_day"]),href,
            float(model["k_m_per_day"]),float(model["ss_per_m"]),sy,
            float(model["initial_head_bias_m"]),
        )
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        solve_finalized=False
        try:
            raw.initialize()
            initialized=True
            require("6.8.0" in raw.get_version(),"G20 wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            require(kernel.prepare_time_step_calls==1,"G20 prepare_time_step count mismatch")
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.prepare_solve_calls==1,"G20 prepare_solve count mismatch")
            require(session.accepted_xold is not None,"G20 missing accepted XOLD")
            xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]

            previous_head=None
            for lam in lambdas:
                qref=g0+lam*r0
                rhs=hcof*h0-qref*AREA_M2*DAY_TO_S
                term=[Term(7001,hcof,rhs)]
                start_iteration=session.iteration_count
                converged=None

                while session.iteration_count < session.max_solve_iterations:
                    status,iteration=session.publish_and_solve_iteration(binding,term)
                    require(status==PreparedSolveStatus.OK,session.last_error)
                    require(iteration is not None,f"G20 lambda={lam} missing iteration")
                    require(np.array_equal(iteration.accepted_head_old_m,xold),
                            f"G20 lambda={lam} XOLD drifted")
                    if iteration.modflow_converged:
                        converged=iteration
                        break

                require(converged is not None,f"G20 lambda={lam} did not converge")
                require(session.solve_open and not session.invalid and not session.finalized,
                        f"G20 lambda={lam} prepared-solve lifecycle drift")
                require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,
                        f"G20 lambda={lam} repeated prepare lifecycle")
                head=float(converged.head_m[1])
                fresh=float(frozen["fresh_reference_heads_m"][str(lam)])
                scale=max(1.0,abs(head),abs(fresh))
                tolerance=math.sqrt(float(np.finfo(np.float64).eps))*scale
                diff=head-fresh
                require(abs(diff)<=tolerance,
                        f"G20 lambda={lam} continuous path differs from G19 fresh reference: diff={diff} tol={tolerance}")

                obs=swap.g16_observe_head(head)
                expected_status=int(frozen["fresh_reference_status"][str(lam)])
                require(int(obs["participant_status"])==expected_status,
                        f"G20 lambda={lam} SWAP status topology drift")
                require(swap.state()==origin and not swap.g15_has_live_candidate(),
                        f"G20 lambda={lam} SWAP diagnostic acquired authority")
                require(not swap.swap_preflight() and not swap.ledger_preflight(),
                        f"G20 lambda={lam} diagnostic reached publication preflight")

                if previous_head is not None:
                    require(head!=previous_head,f"G20 lambda={lam} response change did not evolve X")
                previous_head=head

                row={
                    "lambda":lam,
                    "settled_head_m":head,
                    "fresh_reference_head_m":fresh,
                    "head_difference_m":diff,
                    "path_equivalence_tolerance_m":tolerance,
                    "participant_status":int(obs["participant_status"]),
                    "solve_iterations_for_lambda":session.iteration_count-start_iteration,
                    "cumulative_solve_iterations":session.iteration_count,
                    "xold_fixed":True,
                }
                rows.append(row)
                print("FGC44_G20_LAMBDA_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            solve_finalized=True
            require(kernel.prepare_solve_calls==1,"G20 repeated prepare_solve")
            require(kernel.finalize_solve_calls==1,"G20 finalize_solve count mismatch")
            require(kernel.finalize_time_step_calls==0,"G20 unexpectedly finalized MODFLOW timestep")
            require(session.finalized and not session.solve_open and not session.invalid,
                    "G20 finalize_solve lifecycle state invalid")
            require(not session.timestep_finalized,"G20 timestep publication flag set unexpectedly")
            require(np.array_equal(session.xold,xold),"G20 XOLD changed before teardown")
            raw.finalize()
            initialized=False
        finally:
            if initialized:
                try:
                    raw.finalize()
                except Exception:
                    pass

    counts=swap.g16_counts()
    require(counts[0]==3 and counts[1]==3 and counts[2]==0 and counts[3]==3,
            f"G20 G16 diagnostic accounting mismatch {counts}")
    swap.g16_end_session()
    require(swap.state()==origin and not swap.g15_has_live_candidate(),"G20 end_session changed SWAP authority")
    require(not swap.swap_preflight() and not swap.ledger_preflight(),"G20 left SWAP/ledger publication authority")

    require([int(x["participant_status"]) for x in rows]==[6,6,0],"G20 final status topology mismatch")
    maxdiff=max(abs(float(x["head_difference_m"])) for x in rows)
    summary={
        "lambda_sequence":[1.0,0.5,0.25],
        "one_prepared_solve":"PASS",
        "prepare_time_step_calls":kernel.prepare_time_step_calls,
        "prepare_solve_calls":kernel.prepare_solve_calls,
        "total_modflow_solve_iterations":kernel.solve_calls,
        "finalize_solve_calls":kernel.finalize_solve_calls,
        "finalize_time_step_calls":kernel.finalize_time_step_calls,
        "xold_fixed":"PASS",
        "max_prepared_vs_fresh_head_difference_m":maxdiff,
        "status_topology":[int(x["participant_status"]) for x in rows],
        "g16_logical_requests":counts[0],
        "g16_participant_trials":counts[1],
        "g16_cache_hits":counts[2],
        "diagnostic_non_authority":"PASS",
        "outer_coupling_algorithm_claim":"NOT_MADE",
        "timestep_publication_claim":"NOT_MADE",
    }
    print("FGC44_G20_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G20_CONTINUOUS_XOLD=PASS")
    print("GC_FIXED_INTERFACE_G20_G19_PATH_EQUIVALENCE=PASS")
    print("GC_FIXED_INTERFACE_G20_SWAP_STATUS_TOPOLOGY=PASS")
    print("GC_FIXED_INTERFACE_G20_EXECUTION=PASS")


if __name__=="__main__":
    main()
