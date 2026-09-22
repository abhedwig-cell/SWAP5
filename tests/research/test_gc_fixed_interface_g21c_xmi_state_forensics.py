from __future__ import annotations

import hashlib
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
from test_fgc44_real_swap_modflow_end_to_end import Binding, Term
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import build_model, initialize_case
from test_gc_fixed_interface_g21b_prepared_solve_convergence import (
    LifecycleCountingKernel, response_term, solve_once, settle_first,
)

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21C_PREREGISTRATION.json"
G21B=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21B_RESULT.json"
HEAD_GATE=1.0e-12
TAIL_CALLS=12

PROBES={
    "model":[("X","GWF_1",""),("XOLD","GWF_1","")],
    "api":[
        ("HCOF","GWF_1","API_SWAP"),("RHS","GWF_1","API_SWAP"),
        ("NODELIST","GWF_1","API_SWAP"),("NBOUND","GWF_1","API_SWAP"),
        ("MAXBOUND","GWF_1","API_SWAP"),
    ],
    "solution_state":[
        ("ICNVG","SLN_1",""),("MXITER","SLN_1",""),("DVCLOSE","SLN_1",""),
        ("BIGCH","SLN_1",""),("BIGCHOLD","SLN_1",""),("RELAXOLD","SLN_1",""),
        ("RES_PREV","SLN_1",""),("RES_NEW","SLN_1",""),
        ("XTEMP","SLN_1",""),("DXOLD","SLN_1",""),
        ("WSAVE","SLN_1",""),("HCHOLD","SLN_1",""),("DEOLD","SLN_1",""),
    ],
    "solution_config":[
        ("NONMETH","SLN_1",""),("THETA","SLN_1",""),("AKAPPA","SLN_1",""),
        ("GAMMA","SLN_1",""),("AMOMENTUM","SLN_1",""),
    ],
    "solution_bookkeeping":[
        ("ITERTOT_TIMESTEP","SLN_1",""),("IOUTTOT_TIMESTEP","SLN_1",""),
        ("INNERTOT_SIM","SLN_1",""),
    ],
    "npf":[
        ("SAT","GWF_1","NPF"),("CONDSAT","GWF_1","NPF"),
        ("K11","GWF_1","NPF"),("ICELLTYPE","GWF_1","NPF"),
    ],
    "sto":[
        ("SS","GWF_1","STO"),("SY","GWF_1","STO"),
        ("STRGSS","GWF_1","STO"),("STRGSY","GWF_1","STO"),
        ("ICONVERT","GWF_1","STO"),
    ],
}
STATIC_NAMES={"MXITER","DVCLOSE","NODELIST","NBOUND","MAXBOUND","K11","ICELLTYPE","SS","SY","ICONVERT",
              "NONMETH","THETA","AKAPPA","GAMMA","AMOMENTUM"}
SOLVER_HISTORY_NAMES={"BIGCH","BIGCHOLD","RELAXOLD","RES_PREV","RES_NEW","DXOLD","WSAVE","HCHOLD","DEOLD"}
DBD_HISTORY_NAMES={"WSAVE","HCHOLD","DEOLD"}
PACKAGE_DYNAMIC_NAMES={"SAT","CONDSAT","STRGSS","STRGSY"}


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def arr_bits_equal(a:np.ndarray,b:np.ndarray)->bool:
    if a.dtype != b.dtype or a.shape != b.shape:
        return False
    aa=np.ascontiguousarray(a)
    bb=np.ascontiguousarray(b)
    return aa.tobytes()==bb.tobytes()


def read_probe(kernel:LifecycleCountingKernel,var:str,component:str,subcomponent:str)->dict[str,object]:
    try:
        address=kernel.get_var_address(var,component,subcomponent)
        ptr=kernel.get_value_ptr(address)
    except Exception as exc:
        raise AssertionError(f"G21C required probe unresolved {component}/{subcomponent}/{var}: {exc}") from exc
    arr=np.ascontiguousarray(np.asarray(ptr).copy())
    return {
        "var":var,"component":component,"subcomponent":subcomponent,
        "address":str(address),"dtype":str(arr.dtype),"shape":list(arr.shape),
        "sha256":hashlib.sha256(arr.tobytes()).hexdigest(),
        "values":arr.reshape(-1).tolist(),
        "_array":arr,
    }


def snapshot(kernel:LifecycleCountingKernel,label:str)->dict[str,object]:
    groups={}
    for group,specs in PROBES.items():
        rows={}
        for var,component,subcomponent in specs:
            rows[var]=read_probe(kernel,var,component,subcomponent)
        groups[group]=rows
    return {"label":label,"groups":groups}


def json_snapshot(snap:dict[str,object])->dict[str,object]:
    out={"label":snap["label"],"groups":{}}
    for group,rows in snap["groups"].items():
        outrows={}
        for name,row in rows.items():
            outrows[name]={k:v for k,v in row.items() if k!="_array"}
        out["groups"][group]=outrows
    return out


def probe_array(snap:dict[str,object],group:str,name:str)->np.ndarray:
    return snap["groups"][group][name]["_array"]


def compare_snapshots(stage:str,fresh:dict[str,object],history:dict[str,object])->dict[str,object]:
    rows=[]
    for group,specs in PROBES.items():
        for var,_,_ in specs:
            a=probe_array(fresh,group,var)
            b=probe_array(history,group,var)
            same=arr_bits_equal(a,b)
            max_abs=None
            if a.shape==b.shape and np.issubdtype(a.dtype,np.number) and np.issubdtype(b.dtype,np.number) and a.size:
                aa=a.astype(np.float64,copy=False)
                bb=b.astype(np.float64,copy=False)
                if np.all(np.isfinite(aa)) and np.all(np.isfinite(bb)):
                    max_abs=float(np.max(np.abs(a.astype(np.float64)-b.astype(np.float64))))
            rows.append({
                "stage":stage,"group":group,"var":var,"bitwise_equal":same,
                "max_abs_difference":max_abs,
                "fresh_sha256":fresh["groups"][group][var]["sha256"],
                "history_sha256":history["groups"][group][var]["sha256"],
                "fresh_values":fresh["groups"][group][var]["values"],
                "history_values":history["groups"][group][var]["values"],
            })
    return {"stage":stage,"probes":rows}


def run_arm(label:str,libmf6:Path,swaplib:Path,case:dict[str,float],
            outer1:dict[str,object],outer2:dict[str,float],sy:float,history:bool)->dict[str,object]:
    with tempfile.TemporaryDirectory(prefix=f"fgc44-g21c-{label.lower()}-") as tmp:
        workdir=Path(tmp)
        build_model(workdir,case["duration_day"],case["href"],case["k_m_per_day"],
                    case["ss_per_m"],sy,case["bias_m"])
        raw=XmiWrapper(lib_path=libmf6,working_directory=workdir)
        kernel=LifecycleCountingKernel(raw)
        publisher=Fgc34CtypesPublisher(swaplib)
        initialized=False
        try:
            raw.initialize(); initialized=True
            require("6.8.0" in raw.get_version(),"G21C wrong MODFLOW version")
            kernel.prepare_time_step(0.0)
            session=Modflow6PreparedSolveSession(kernel,"GWF_1","API_SWAP",publisher,solution_id=1)
            require(session.acquire_after_prepare_time_step()==PreparedSolveStatus.OK,session.last_error)
            require(session.open_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(session.accepted_xold is not None,"G21C accepted XOLD missing")
            xold=session.accepted_xold.copy()
            binding=[Binding(7001,1,2)]
            history_rows=[]
            if history:
                h0=float(outer1["anchor_head_m"])
                p0=float(outer1["tangent_per_s"])
                r0=float(outer1["current_residual_m_per_s"])
                g0=float(case["a_per_s"])*h0+float(case["b"])
                expected=[float(x) for x in outer1["expected_settled_heads_m"]]
                for index,lam in enumerate([float(x) for x in outer1["lambda_sequence"]]):
                    qref=g0+lam*r0
                    hh,calls=settle_first(session,binding,xold,h0,qref,p0)
                    err=hh-expected[index]
                    require(abs(err)<=HEAD_GATE,f"G21C history lambda {lam} replay drift {err}")
                    history_rows.append({"lambda":lam,"head_m":hh,"calls":calls,"error_m":err})
            hcof,rhs=response_term(float(outer2["anchor_head_m"]),float(outer2["qref_m_per_s"]),float(outer2["tangent_per_s"]))
            require(session.nodelist is not None and session.hcof is not None and session.rhs is not None and session.nbound is not None,
                    "G21C missing API package views before outer-2 staging")
            stage_status=int(publisher(binding,[Term(7001,hcof,rhs)],session.maxbound,
                                       session.nodelist,session.hcof,session.rhs,session.nbound))
            require(stage_status==0,"G21C failed to stage outer-2 response before tail-entry snapshot")
            require(float(session.hcof[0])==hcof and float(session.rhs[0])==rhs,
                    "G21C staged outer-2 response drift")
            entry=snapshot(kernel,f"{label}_TAIL_ENTRY")
            rows=[]
            first_convergence=None
            first_snapshot=None
            for local_call in range(1,TAIL_CALLS+1):
                row=solve_once(session,binding,xold,hcof,rhs)
                row["tail_call"]=local_call
                row["error_to_reference_m"]=float(row["head_m"])-float(outer2["fresh_reference_head_m"])
                rows.append(row)
                if first_convergence is None and bool(row["modflow_converged"]):
                    first_convergence=local_call
                    first_snapshot=snapshot(kernel,f"{label}_FIRST_CONVERGENCE")
            require(first_convergence is not None and first_snapshot is not None,"G21C missing first convergence")
            final_snapshot=snapshot(kernel,f"{label}_CALL12")
            require(np.array_equal(session.xold,xold),"G21C XOLD drift inside arm")
            require(kernel.prepare_time_step_calls==1 and kernel.prepare_solve_calls==1,"G21C lifecycle reopen")
            require(session.finalize_prepared_solve()==PreparedSolveStatus.OK,session.last_error)
            require(kernel.finalize_solve_calls==1 and kernel.finalize_time_step_calls==0,"G21C finalization boundary drift")
            result={
                "label":label,"history":history_rows,
                "first_convergence_call":first_convergence,
                "first_convergence_head_m":float(rows[first_convergence-1]["head_m"]),
                "call12_head_m":float(rows[-1]["head_m"]),
                "tail_rows":rows,
                "entry_snapshot":entry,
                "first_convergence_snapshot":first_snapshot,
                "call12_snapshot":final_snapshot,
                "xold_bitwise_fixed":bool(np.array_equal(session.xold,xold)),
                "prepare_time_step_calls":kernel.prepare_time_step_calls,
                "prepare_solve_calls":kernel.prepare_solve_calls,
                "finalize_solve_calls":kernel.finalize_solve_calls,
                "finalize_time_step_calls":kernel.finalize_time_step_calls,
            }
            raw.finalize(); initialized=False
            return result
        finally:
            if initialized:
                try: raw.finalize()
                except Exception: pass


def main()->None:
    prereg=json.loads(PREREG.read_text())
    g21b=json.loads(G21B.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G21C","wrong G21C preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION_AMENDED","G21C amended preregistration not frozen")
    require(g21b["decision"]=="QUALIFIED_DIAGNOSTIC_PERSISTENT_PREPARED_SOLVE_PATH_MEMORY","G21C parent G21B drift")
    inv=prereg["source_backed_probe_inventory"]
    require(inv["model_GWF_1_required"]==["X","XOLD"],"G21C model probe inventory drift")
    require(inv["solution_SLN_1_required"]==["ICNVG","MXITER","DVCLOSE","BIGCH","BIGCHOLD","RELAXOLD","RES_PREV","RES_NEW","XTEMP","DXOLD","WSAVE","HCHOLD","DEOLD"],
            "G21C solution probe inventory drift")
    require(inv["solution_SLN_1_configuration"]==["NONMETH","THETA","AKAPPA","GAMMA","AMOMENTUM"],
            "G21C solution configuration inventory drift")
    require(TAIL_CALLS==int(prereg["frozen_case"]["tail_calls"]),"G21C tail length drift")

    parent_prereg=json.loads((ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21B_PREREGISTRATION.json").read_text())
    frozen=parent_prereg["frozen_case"]
    outer1=parent_prereg["frozen_outer1_response_history"]
    outer2=parent_prereg["frozen_outer2_response"]

    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file() and swaplib.is_file(),"G21C missing live libraries")
    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,float(frozen["duration_day"]),float(frozen["predictor_qbot_cm_per_day"]))
    require(origin==(0,0.0,0,0.0),"G21C dirty SWAP origin")
    sy=0.5*float(diag["u"])
    case={
        "duration_day":float(frozen["duration_day"]),"href":float(href),
        "k_m_per_day":float(frozen["groundwater_k_m_per_day"]),
        "ss_per_m":float(frozen["groundwater_ss_per_m"]),
        "bias_m":float(frozen["groundwater_initial_head_bias_m"]),
        "a_per_s":float(frozen["groundwater_a_per_s"]),
        "b":float(frozen["groundwater_intercept"]),
    }
    outer2n={
        "anchor_head_m":float(outer2["anchor_head_m"]),
        "qref_m_per_s":float(outer2["qref_m_per_s"]),
        "tangent_per_s":float(outer2["tangent_per_s"]),
        "fresh_reference_head_m":float(outer2["fresh_reference_head_m"]),
    }

    fresh=run_arm("FRESH",libmf6,swaplib,case,outer1,outer2n,sy,False)
    history=run_arm("HISTORY",libmf6,swaplib,case,outer1,outer2n,sy,True)

    expected=float(g21b["matched_comparison"]["final_call_12_history_minus_fresh_m"])
    observed=float(history["call12_head_m"])-float(fresh["call12_head_m"])
    require(abs(observed-expected)<=HEAD_GATE,"G21C failed to reproduce G21B persistent offset")

    comparisons={}
    for stage,key in (
        ("TAIL_ENTRY","entry_snapshot"),
        ("FIRST_CONVERGENCE","first_convergence_snapshot"),
        ("CALL12","call12_snapshot"),
    ):
        comparisons[stage]=compare_snapshots(stage,fresh[key],history[key])

    for stage in comparisons.values():
        rows={x["var"]:x for x in stage["probes"] if x["group"]=="model"}
        require(rows["XOLD"]["bitwise_equal"],f"G21C XOLD differs between arms at {stage['stage']}")
    for stage_name in ("TAIL_ENTRY","FIRST_CONVERGENCE","CALL12"):
        api={x["var"]:x for x in comparisons[stage_name]["probes"] if x["group"]=="api"}
        require(api["HCOF"]["bitwise_equal"] and api["RHS"]["bitwise_equal"],f"G21C API response differs at {stage_name}")
        config={x["var"]:x for x in comparisons[stage_name]["probes"] if x["group"]=="solution_config"}
        require(config["NONMETH"]["fresh_values"]==[3] and config["NONMETH"]["history_values"]==[3],
                f"G21C expected MODERATE delta-bar-delta NONMETH=3 at {stage_name}")

    for stage in comparisons.values():
        for row in stage["probes"]:
            if row["var"] in STATIC_NAMES and row["group"]!="solution_bookkeeping":
                require(row["bitwise_equal"],f"G21C static/config probe differs {stage['stage']} {row['group']}/{row['var']}")

    call12=comparisons["CALL12"]["probes"]
    solver_different=[x["var"] for x in call12 if x["group"]=="solution_state" and x["var"] in SOLVER_HISTORY_NAMES and not x["bitwise_equal"]]
    dbd_different=[x["var"] for x in call12 if x["group"]=="solution_state" and x["var"] in DBD_HISTORY_NAMES and not x["bitwise_equal"]]
    package_different=[x["var"] for x in call12 if x["group"] in ("npf","sto") and x["var"] in PACKAGE_DYNAMIC_NAMES and not x["bitwise_equal"]]
    xtemp_different=any(x["group"]=="solution_state" and x["var"]=="XTEMP" and not x["bitwise_equal"] for x in call12)

    if solver_different and not package_different:
        classification="SOLVER_HISTORY_STATE_DIFFERENT"
    elif package_different and not solver_different:
        classification="PACKAGE_STATE_DIFFERENT"
    elif solver_different and package_different:
        classification="MIXED_OR_UNRESOLVED"
    else:
        classification="CURRENT_ITERATE_ONLY_OR_DERIVED"

    for arm in (fresh,history):
        print("FGC44_G21C_ARM_META_JSON="+json.dumps({
            "label":arm["label"],"first_convergence_call":arm["first_convergence_call"],
            "first_convergence_head_m":arm["first_convergence_head_m"],
            "call12_head_m":arm["call12_head_m"],"xold_bitwise_fixed":arm["xold_bitwise_fixed"],
            "prepare_time_step_calls":arm["prepare_time_step_calls"],"prepare_solve_calls":arm["prepare_solve_calls"],
            "finalize_solve_calls":arm["finalize_solve_calls"],"finalize_time_step_calls":arm["finalize_time_step_calls"],
        },sort_keys=True,separators=(",",":")))
        for key in ("entry_snapshot","first_convergence_snapshot","call12_snapshot"):
            print("FGC44_G21C_SNAPSHOT_JSON="+json.dumps(json_snapshot(arm[key]),sort_keys=True,separators=(",",":")))

    for stage in comparisons.values():
        for row in stage["probes"]:
            print("FGC44_G21C_COMPARE_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    summary={
        "classification":classification,
        "observed_call12_history_minus_fresh_m":observed,
        "persisted_g21b_offset_m":expected,
        "solver_history_fields_different_call12":solver_different,
        "delta_bar_delta_history_fields_different_call12":dbd_different,
        "package_dynamic_fields_different_call12":package_different,
        "xtemp_different_call12":xtemp_different,
        "fresh_first_convergence_call":fresh["first_convergence_call"],
        "history_first_convergence_call":history["first_convergence_call"],
        "xold_equal_all_stages":True,
        "api_response_equal_all_forensic_stages":True,
        "nonmeth_fresh_history":3,
        "bookkeeping_reported_separately":True,
        "diagnostic_pointer_state_mutation_performed":False,
        "normal_api_response_publication_performed":True,
        "causal_claim":"NONE_READ_ONLY_FORENSICS",
    }
    print("FGC44_G21C_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21C_REQUIRED_PROBES=PASS")
    print("GC_FIXED_INTERFACE_G21C_READ_ONLY_FORENSICS=PASS")
    print("GC_FIXED_INTERFACE_G21C_EXECUTION=PASS")


if __name__=="__main__":
    main()
