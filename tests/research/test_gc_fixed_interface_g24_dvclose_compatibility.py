from __future__ import annotations

import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import flopy
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"research"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"src"/"adapter"))

import test_gc_fixed_interface_g23_endpoint_transaction_matrix as g23

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G24_PREREGISTRATION.json"
G23=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G23_RESULT.json"
G08=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G08_RESULT.json"
G08P=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"

def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)

def build_model_with_dvclose(
    workdir:Path,
    duration_day:float,
    href:float,
    k_m_per_day:float,
    ss_per_m:float,
    sy:float,
    initial_head_bias_m:float,
    outer_dvclose_m:float,
    inner_dvclose_m:float,
)->None:
    center=href+initial_head_bias_m
    sim=flopy.mf6.MFSimulation(sim_name="FGC44_G24",version="mf6",sim_ws=str(workdir))
    flopy.mf6.ModflowTdis(sim,time_units="DAYS",nper=1,perioddata=[(duration_day,1,1.0)])
    flopy.mf6.ModflowIms(
        sim,complexity="MODERATE",
        outer_dvclose=outer_dvclose_m,inner_dvclose=inner_dvclose_m,
        outer_maximum=100,inner_maximum=100,
    )
    gwf=flopy.mf6.ModflowGwf(sim,modelname="GWF_1",save_flows=True,newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf,nlay=1,nrow=1,ncol=3,delr=1.0,delc=1.0,top=0.0,botm=-2.0)
    flopy.mf6.ModflowGwfic(gwf,strt=np.asarray([[[center,center,center]]],dtype=float))
    flopy.mf6.ModflowGwfnpf(gwf,icelltype=1,k=k_m_per_day,save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf,iconvert=1,ss=ss_per_m,sy=sy,transient={0:True})
    flopy.mf6.ModflowGwfchd(
        gwf,stress_period_data={0:[
            ((0,0,0),center+0.002),
            ((0,0,2),center-0.002),
        ]},pname="CHD_ENDS",
    )
    flopy.mf6.ModflowGwfapi(gwf,maxbound=1,pname="API_SWAP",filename="api_swap.api")
    sim.write_simulation(silent=True)

def load_authorities():
    p=json.loads(PREREG.read_text())
    g23r=json.loads(G23.read_text())
    g08=json.loads(G08.read_text())
    g08p=json.loads(G08P.read_text())
    require(p["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G24 preregistration drift")
    require(g23r["decision"]=="PARTIAL_ENDPOINT_ENVELOPE_19_OF_21","G24 G23 parent drift")
    require(len(p["cases"])==4 and len(p["tolerance_ladder"])==3,"G24 matrix drift")
    require(float(p["frozen_algorithm"]["external_residual_gate_m_per_s"])==g23.FLUX_TOL,"G24 residual gate drift")
    require(float(p["frozen_algorithm"]["independent_head_gate_m"])==g23.HEAD_TOL,"G24 head gate drift")
    regimes={str(x["id"]):dict(x) for x in g08p["groundwater_regimes"]}
    auth={(str(x["case_id"]),str(x["regime_id"])):dict(x) for x in g08["groundwater_regimes"]}
    g23arms={str(x["id"]):dict(x) for x in g23r["arms"]}
    return p,g23r,regimes,auth,g23arms

def run_child(case_id:str,tol_id:str)->None:
    p,_,regimes,auth,_=load_authorities()
    case=next(dict(x) for x in p["cases"] if str(x["id"])==case_id)
    tol=next(dict(x) for x in p["tolerance_ladder"] if str(x["id"])==tol_id)
    regime=regimes[str(case["regime"])]
    oracle=auth[(str(case["swap_case"]),str(case["regime"]))]
    outer=float(tol["outer_dvclose_m"])
    inner=float(tol["inner_dvclose_m"])

    original_builder=g23.build_model
    def research_builder(workdir,duration_day,href,k_m_per_day,ss_per_m,sy,initial_head_bias_m):
        return build_model_with_dvclose(
            workdir,duration_day,href,k_m_per_day,ss_per_m,sy,initial_head_bias_m,outer,inner
        )
    g23.build_model=research_builder
    try:
        row=g23.run_arm(case,oracle,regime,Path(os.environ["LIBMF6"]),Path(os.environ["FGC44_SWAP_LIB"]))
    finally:
        g23.build_model=original_builder

    trace=list(row["accepted_trace"])
    last_res=trace[-1]["accepted_residual_m_per_s"] if trace else None
    unique_heads=len({float(x["accepted_head_m"]).hex() for x in trace})
    result={
        "case_id":case_id,"role":case["role"],"tolerance_id":tol_id,
        "outer_dvclose_m":outer,"inner_dvclose_m":inner,
        "classification":row["classification"],"physical_gate":row["physical_gate"],
        "transaction_gate":row["transaction_gate"],"diagnostic_non_authority":row["diagnostic_non_authority"],
        "final_head_m":row["final_head_m"],"reference_root_m":row["reference_root_m"],
        "head_error_m":row["head_error_m"],"final_residual_m_per_s":row["final_residual_m_per_s"],
        "last_accepted_residual_m_per_s":last_res,
        "accepted_outer_updates":row["accepted_outer_updates"],"unique_accepted_head_count":unique_heads,
        "total_contractions":row["total_contractions"],"modflow_solve_calls":row["modflow_solve_calls"],
        "response_status_topology":row["response_status_topology"],
        "max_prepared_vs_oracle_qgw_abs_m_per_s":row["max_prepared_vs_oracle_qgw_abs_m_per_s"],
        "publication":row["publication"],
        "accepted_trace":trace,
    }
    print("FGC44_G24_CHILD_JSON="+json.dumps(result,sort_keys=True,separators=(",",":")))

def run_case_fresh_process(case_id:str,tol_id:str)->dict[str,object]:
    proc=subprocess.run(
        [sys.executable,str(Path(__file__).resolve()),"--arm",case_id,tol_id],
        cwd=ROOT,env=os.environ.copy(),text=True,capture_output=True,
    )
    if proc.returncode!=0:
        sys.stdout.write(proc.stdout); sys.stderr.write(proc.stderr)
        raise subprocess.CalledProcessError(proc.returncode,proc.args,proc.stdout,proc.stderr)
    rows=[line for line in proc.stdout.splitlines() if line.startswith("FGC44_G24_CHILD_JSON=")]
    require(len(rows)==1,f"G24 child output count {case_id}/{tol_id}: {len(rows)}")
    return json.loads(rows[0].split("=",1)[1])

def main()->None:
    if len(sys.argv)==4 and sys.argv[1]=="--arm":
        run_child(sys.argv[2],sys.argv[3]); return

    p,g23r,_,_,g23arms=load_authorities()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file() and swaplib.is_file(),"G24 missing live libraries")

    rows=[]
    for case in p["cases"]:
        for tol in p["tolerance_ladder"]:
            row=run_case_fresh_process(str(case["id"]),str(tol["id"]))
            rows.append(row)
            print("FGC44_G24_ARM_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    by={(x["case_id"],x["tolerance_id"]):x for x in rows}
    expected_standard={
        "C0_MIXED_POS":False,
        "C0_MIXED_NEG":True,
        "C3_MIXED_NEG":False,
        "C3_MIXED_POS":True,
    }
    baseline_reproduction=True
    baseline_details=[]
    for cid,expected in expected_standard.items():
        row=by[(cid,"STANDARD")]
        parent=g23arms[cid]
        class_match=str(row["classification"])==str(parent["classification"])
        gate_match=bool(row["physical_gate"])==expected==bool(parent["physical_gate"])
        head_bitwise=float(row["final_head_m"]).hex()==float(parent["final_head_m"]).hex()
        last_parent=parent["last_accepted_residual_m_per_s"]
        last_match=(
            row["last_accepted_residual_m_per_s"] is not None and last_parent is not None
            and float(row["last_accepted_residual_m_per_s"]).hex()==float(last_parent).hex()
        )
        baseline_reproduction=baseline_reproduction and class_match and gate_match and head_bitwise and last_match
        baseline_details.append({
            "case_id":cid,"classification_match":class_match,"physical_gate_match":gate_match,
            "final_head_bitwise_match":head_bitwise,"last_residual_bitwise_match":last_match,
        })

    controls=["C0_MIXED_NEG","C3_MIXED_POS"]
    controls_all_pass=all(
        bool(by[(cid,tid)]["physical_gate"]) and bool(by[(cid,tid)]["transaction_gate"])
        for cid in controls for tid in ["STANDARD","TIGHT_1","TIGHT_2"]
    )
    c0_std=bool(by[("C0_MIXED_POS","STANDARD")]["physical_gate"])
    c0_t1=bool(by[("C0_MIXED_POS","TIGHT_1")]["physical_gate"])
    c0_t2=bool(by[("C0_MIXED_POS","TIGHT_2")]["physical_gate"])
    c3_std=bool(by[("C3_MIXED_NEG","STANDARD")]["physical_gate"])
    c3_t1=bool(by[("C3_MIXED_NEG","TIGHT_1")]["physical_gate"])
    c3_t2=bool(by[("C3_MIXED_NEG","TIGHT_2")]["physical_gate"])
    all_diag=all(str(x["diagnostic_non_authority"])=="PASS" for x in rows)
    converged_handoffs=all(bool(x["transaction_gate"]) for x in rows if bool(x["physical_gate"]))
    all_status_zero=all(all(int(v)==0 for v in x["response_status_topology"]) for x in rows)

    if not baseline_reproduction or not controls_all_pass or not all_diag or not converged_handoffs:
        classification="MIXED_OR_UNRESOLVED"
    elif (not c0_std and not c3_std and c3_t1 and not c0_t1 and c0_t2 and c3_t2):
        classification="STRONG_DVCLOSE_CAUSAL_SUPPORT"
    elif (not c0_std and not c3_std and c0_t2 and c3_t2):
        classification="DVCLOSE_CAUSAL_SUPPORT_DIFFERENT_THRESHOLD"
    else:
        classification="DVCLOSE_NOT_SUFFICIENT"

    transitions={}
    for cid in ["C0_MIXED_POS","C3_MIXED_NEG"]:
        transitions[cid]=[
            {"tolerance_id":tid,"physical_gate":bool(by[(cid,tid)]["physical_gate"]),
             "classification":by[(cid,tid)]["classification"],
             "last_accepted_residual_m_per_s":by[(cid,tid)]["last_accepted_residual_m_per_s"],
             "final_head_m":by[(cid,tid)]["final_head_m"],
             "accepted_outer_updates":by[(cid,tid)]["accepted_outer_updates"],
             "modflow_solve_calls":by[(cid,tid)]["modflow_solve_calls"]}
            for tid in ["STANDARD","TIGHT_1","TIGHT_2"]
        ]

    summary={
        "classification":classification,
        "arm_count":len(rows),
        "baseline_reproduction":baseline_reproduction,
        "baseline_details":baseline_details,
        "matched_controls_all_pass":controls_all_pass,
        "all_diagnostic_non_authority":all_diag,
        "all_converged_handoffs_pass":converged_handoffs,
        "all_participant_status_zero":all_status_zero,
        "failure_transitions":transitions,
        "physical_pass_count":sum(bool(x["physical_gate"]) for x in rows),
        "transaction_pass_count":sum(bool(x["transaction_gate"]) for x in rows),
        "production_change":"NONE",
        "g23_disposition":"PRESERVED_PARTIAL_19_OF_21",
    }
    print("FGC44_G24_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G24_EXECUTION=PASS")

if __name__=="__main__":
    main()
