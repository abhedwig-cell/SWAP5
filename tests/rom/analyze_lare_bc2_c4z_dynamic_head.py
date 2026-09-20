#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS={"Z01":0.725,"Z02":0.825,"Z03":0.875,"Z04":0.775}
NSTEPS=1024
OBS_DT=0.0008
DT=0.0001
EQ_TOL=1.0e-12
LEDGER_GATE=1.0e-10

PARTITIONS={
 "R3":[0.0,140.0,150.0,160.0],
 "R4":[0.0,130.0,140.0,150.0,160.0],
 "R5":[0.0,120.0,130.0,140.0,150.0,160.0],
 "R6":[0.0,110.0,120.0,130.0,140.0,150.0,160.0],
 "R8":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
 "R12":[0.0,50.0,60.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
 "R16":[float(x) for x in range(0,161,10)],
 "P4_TOP_LOWER":[0.0,10.0,140.0,150.0,160.0],
 "U4":[0.0,40.0,80.0,120.0,160.0],
 "U8":[0.0,20.0,40.0,60.0,80.0,100.0,120.0,140.0,160.0],
}
LADDER=("R3","R4","R5","R6","R8","R12","R16")
CONTROLS=("P4_TOP_LOWER","U4","U8")
GW_KEYS=(
 "total_storage_rmse_cm",
 "cumulative_bottom_rmse_cm",
 "interval_bottom_flux_rmse_cm_per_day",
 "bottom_flux_sign_mismatch_count",
 "abs_mean_signed_bottom_flux_error_cm_per_day",
 "max_abs_final_cumulative_bottom_error_cm",
 "reversal_sequence_mismatch_history_count",
 "reversal_penalty_steps",
)
PROFILE_KEYS=GW_KEYS+("mapped_theta_rmse",)

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

bc=load_module("bc1_c4z_base",HERE/"run_lare_bc1_stage_b.py")
bc.HISTORY_SE=dict(HISTS)
bc.OBS_DT=OBS_DT
bc.STEPS=NSTEPS
for name,bounds in PARTITIONS.items():
    bc.PARTITIONS[name]=np.diff(np.asarray(bounds,dtype=float))

def c4z_symbol(history,step):
    if history=="Z01":
        if step<=256:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="Z02":
        if step<=256:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    if history=="Z03":
        if step<=320:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="Z04":
        if step<=320:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    raise ValueError(history)

def c4z_boundary_psi(history,sym,psi0):
    if sym=="BOTTOM_HEAD_RISE": return 0.875*psi0
    if sym=="BOTTOM_HEAD_FALL": return 1.125*psi0
    if sym=="HOLD": return None
    raise ValueError((history,sym))

bc.symbol=c4z_symbol
bc.boundary_psi=c4z_boundary_psi

def qstats(values):
    a=np.asarray(values,dtype=float)
    return {
      "rmse":float(np.sqrt(np.mean(a*a))),
      "mean":float(np.mean(a)),
      "mean_abs":float(np.mean(np.abs(a))),
      "max_abs":float(np.max(np.abs(a))),
    }

def map_piecewise_theta(layer_storage,bounds):
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(layer_storage,dtype=float)/dz
    out=[]
    for node in range(16):
        lo=node*10.0;hi=(node+1)*10.0
        total=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0: total+=float(t)*w
        out.append(total/10.0)
    return out

def load_reference_n(path:pathlib.Path,expected_nodes:int):
    states={}
    nodes={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=bc.fields(line.split("|",1)[1])
            if r["HISTORY"] in HISTS:
                states[(r["HISTORY"],int(r["STEP"]))]=r
        elif line.startswith("LAREGW1_NODE|"):
            r=bc.fields(line.split("|",1)[1])
            if r["HISTORY"] in HISTS:
                nodes.setdefault((r["HISTORY"],int(r["STEP"])),[]).append({
                    "node":int(r["NODE"]),"theta":float(r["THETA"])
                })
    out={}
    for hist in HISTS:
        hs=[]
        for step in range(1,NSTEPS+1):
            key=(hist,step)
            if key not in states or key not in nodes or len(nodes[key])!=expected_nodes:
                raise RuntimeError(f"incomplete Reference {key}: expected_nodes={expected_nodes}")
            r=states[key]
            hs.append({
                "step":step,
                "bottom_exchange_cm":float(r["BOTTOM_OUTWARD_EXCHANGE"]),
                "bottom_interval_flux_cm_per_day":float(r["BOTTOM_OUTWARD_EXCHANGE"])/OBS_DT,
                "nodes":sorted(nodes[key],key=lambda x:x["node"]),
            })
        out[hist]={"steps":hs}
    return out

def reference_arrays(ref,hist,dz):
    steps=ref[hist]["steps"]
    total=[];cum=[];q=[];theta=[];x=0.0
    for row in steps:
        nodes=sorted(row["nodes"],key=lambda z:z["node"])
        if len(nodes)!=len(dz): raise RuntimeError("reference node count mismatch")
        vals=[float(n["theta"]) for n in nodes]
        total.append(sum(t*w for t,w in zip(vals,dz)))
        x+=float(row["bottom_exchange_cm"]);cum.append(x)
        q.append(float(row["bottom_interval_flux_cm_per_day"]))
        if len(dz)==16:
            theta.append(vals)
        elif len(dz)==2:
            theta.append([vals[0]]*8+[vals[1]]*8)
        else:
            raise RuntimeError("unsupported comparator geometry")
    return {"total":total,"cum":cum,"q":q,"theta":theta}

def candidate_arrays(result,bounds):
    storage=np.asarray(result["layer_storage_cm"],dtype=float)
    return {
      "total":np.sum(storage,axis=1).tolist(),
      "cum":[float(x) for x in result["cumulative_bottom_downward_cm"]],
      "q":[float(x) for x in result["interval_average_bottom_downward_flux_cm_per_day"]],
      "theta":[map_piecewise_theta(row,bounds) for row in storage],
    }

def reversal_steps(values):
    return bc.reversals([float(x) for x in values])

def compare_routes(candidates,reference):
    S=[];C=[];Q=[];T=[];finals=[];signerr=0;rev_mismatch=0;rev_penalty=0;by={}
    for h in HISTS:
        ca=candidates[h]; rr=reference[h]
        ds=np.asarray(ca["total"])-np.asarray(rr["total"])
        dc=np.asarray(ca["cum"])-np.asarray(rr["cum"])
        dq=np.asarray(ca["q"])-np.asarray(rr["q"])
        dt=np.asarray(ca["theta"])-np.asarray(rr["theta"])
        S.extend(ds.tolist());C.extend(dc.tolist());Q.extend(dq.tolist());T.extend(dt.ravel().tolist())
        finals.append(float(dc[-1]))
        se=int(np.count_nonzero(np.sign(np.asarray(ca["q"]))!=np.sign(np.asarray(rr["q"]))))
        signerr+=se
        cr=reversal_steps(ca["q"]); rrev=reversal_steps(rr["q"])
        mismatch=(len(cr)!=len(rrev))
        if mismatch:
            penalty=NSTEPS
            rev_mismatch+=1
        else:
            penalty=max([abs(a-b) for a,b in zip(cr,rrev)] or [0])
        rev_penalty=max(rev_penalty,penalty)
        by[h]={
          "total_storage_rmse_cm":qstats(ds)["rmse"],
          "cumulative_bottom_rmse_cm":qstats(dc)["rmse"],
          "interval_bottom_flux_rmse_cm_per_day":qstats(dq)["rmse"],
          "bottom_flux_sign_mismatch_count":se,
          "abs_mean_signed_bottom_flux_error_cm_per_day":abs(qstats(dq)["mean"]),
          "abs_final_cumulative_bottom_error_cm":abs(float(dc[-1])),
          "mapped_theta_rmse":qstats(dt.ravel())["rmse"],
          "candidate_reversal_steps":cr,
          "reference_reversal_steps":rrev,
          "reversal_sequence_mismatch":mismatch,
          "reversal_penalty_steps":penalty,
        }
    return {
      "total_storage_rmse_cm":qstats(S)["rmse"],
      "cumulative_bottom_rmse_cm":qstats(C)["rmse"],
      "interval_bottom_flux_rmse_cm_per_day":qstats(Q)["rmse"],
      "bottom_flux_sign_mismatch_count":int(signerr),
      "abs_mean_signed_bottom_flux_error_cm_per_day":abs(qstats(Q)["mean"]),
      "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
      "reversal_sequence_mismatch_history_count":int(rev_mismatch),
      "reversal_penalty_steps":int(rev_penalty),
      "mapped_theta_rmse":qstats(T)["rmse"],
      "by_history":by,
    }

def no_worse(a,b,keys):
    for k in keys:
        if isinstance(a[k],int) and isinstance(b[k],int):
            if a[k]>b[k]: return False
        elif float(a[k])>float(b[k])+EQ_TOL:
            return False
    return True

def run_lare_member(member,bounds,reference):
    histories={};status="QUALIFIED";failures={};maxledger=0.0;maxiter=0
    for h in HISTS:
        case=bc.Case(member,h,"CURRENT_LAYER_FACE")
        try:
            sol=bc.solve(case,DT)
            if float(sol["max_abs_water_ledger_cm"])>LEDGER_GATE:
                raise RuntimeError("water ledger gate")
            histories[h]=candidate_arrays(sol,bounds)
            maxledger=max(maxledger,float(sol["max_abs_water_ledger_cm"]))
            maxiter=max(maxiter,int(sol["max_corrector_iterations"]))
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN";failures[h]=str(exc)
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED";failures[h]=str(exc)
    metrics=None
    if status=="QUALIFIED" and len(histories)==len(HISTS):
        metrics=compare_routes(histories,reference)
    return {
      "id":member,"dimension":len(bounds)-1,"boundaries_cm":bounds,
      "status":status,"failures":failures,"max_abs_water_ledger_cm":maxledger,
      "max_corrector_iterations":maxiter,"metrics":metrics,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--bc1-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4x-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    bc1c=json.loads(a.bc1_closeout.read_text())
    c4x=json.loads(a.c4x_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C4Z_REFERENCE_RESPONSE"
    assert bc1c["decision"]=="FIXED_DOMAIN_PRESCRIBED_HEAD_CLOSURE_QUALIFIED_WITH_RESOLUTION_DEPENDENCE"
    assert c4x["decision"]=="C4X_B14_GW_TRANSFER_FRONTIER_PRESENT"
    assert p["representations"]["LARE"]["closure"]=="BC1 CURRENT_LAYER_FACE"

    r16raw=load_reference_n(a.r16,16)
    r2raw=load_reference_n(a.r2,2)
    r16={h:reference_arrays(r16raw,h,[10.0]*16) for h in HISTS}
    r2={h:reference_arrays(r2raw,h,[80.0,80.0]) for h in HISTS}
    r2metrics=compare_routes(r2,r16)

    members=[]
    for member in list(LADDER)+list(CONTROLS):
        members.append(run_lare_member(member,PARTITIONS[member],r16))

    r16ctrl=next(x for x in members if x["id"]=="R16")
    all_attempted=len(members)==len(LADDER)+len(CONTROLS)
    integrity=(all_attempted and r16ctrl["status"]=="QUALIFIED" and
               all(x["status"]!="QUALIFIED" or x["max_abs_water_ledger_cm"]<=LEDGER_GATE for x in members))
    reduced=[x for x in members if x["dimension"]<16 and x["status"]=="QUALIFIED"]

    crossing={}
    for x in reduced:
        m=x["metrics"]
        crossing[x["id"]]={
          "crosses_R2_GW":no_worse(m,r2metrics,GW_KEYS),
          "crosses_R2_PROFILE":no_worse(m,r2metrics,PROFILE_KEYS),
        }
    ladder_reduced=[x for x in reduced if x["id"] in LADDER]
    gw=[x["id"] for x in ladder_reduced if crossing[x["id"]]["crosses_R2_GW"]]
    profile=[x["id"] for x in ladder_reduced if crossing[x["id"]]["crosses_R2_PROFILE"]]
    min_gw=min([x["dimension"] for x in ladder_reduced if crossing[x["id"]]["crosses_R2_GW"]],default=None)
    min_profile=min([x["dimension"] for x in ladder_reduced if crossing[x["id"]]["crosses_R2_PROFILE"]],default=None)

    def placement(low,uniform):
        arow=next((x for x in reduced if x["id"]==low),None)
        brow=next((x for x in reduced if x["id"]==uniform),None)
        if arow is None or brow is None:return None
        return no_worse(arow["metrics"],brow["metrics"],GW_KEYS)

    if not integrity:
        decision="C4Z_REFERENCE_OR_EXECUTION_BLOCKED"
    elif profile:
        decision="C4Z_DYNAMIC_HEAD_GW_PROFILE_FRONTIERS_PRESENT"
    elif gw:
        decision="C4Z_DYNAMIC_HEAD_GW_FRONTIER_ONLY"
    else:
        decision="C4Z_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED"

    out={
      "schema":"swap5.lare.bc2.c4z.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4Z",
      "blind_validation":True,
      "decision":decision,
      "reference_workload":{
        "histories":HISTS,
        "observation_dt_day":OBS_DT,
        "steps":NSTEPS,
        "horizon_day":NSTEPS*OBS_DT,
        "top_forcing":"gravity-consistent qeq only",
        "bottom_head_multipliers":{"RISE":0.875,"FALL":1.125},
      },
      "integrity":{
        "pass":integrity,
        "all_members_and_controls_attempted":all_attempted,
        "R16_operator_control_status":r16ctrl["status"],
        "maximum_qualified_lare_water_ledger_cm":max([x["max_abs_water_ledger_cm"] for x in members if x["status"]=="QUALIFIED"] or [0.0]),
      },
      "R2_comparator":r2metrics,
      "members":[{k:x[k] for k in ("id","dimension","boundaries_cm","status","failures","max_abs_water_ledger_cm","max_corrector_iterations","metrics")} for x in members],
      "crossing_R2":crossing,
      "frontiers":{
        "GW":gw,"PROFILE":profile,
        "minimum_dimension_GW":min_gw,
        "minimum_dimension_PROFILE":min_profile,
      },
      "placement_tests":{
        "R4_no_worse_than_U4_GW":placement("R4","U4"),
        "R8_no_worse_than_U8_GW":placement("R8","U8"),
      },
      "hypotheses":{
        "H_DYNAMIC_HEAD_MIN_NOT_BELOW_R4":None if min_gw is None else min_gw>=4,
        "H_LOWER_ZONE_PLACEMENT_R4":placement("R4","U4"),
        "H_LOWER_ZONE_PLACEMENT_R8":placement("R8","U8"),
        "H_PROFILE_REQUIRES_MORE_STATE":None if min_gw is None or min_profile is None else min_profile>min_gw,
      },
      "interpretation_boundaries":[
        "Comparator-relative crossing against R2 is not application acceptance.",
        "C4Z tests fixed-domain prescribed-head semantics only; it is not moving-water-table geometry and not groundwater-coupling authority.",
        "No FMC comparison is made because the frozen FMC_GW200 equations are tied to the zero-head fixed-water-table workload and are not silently generalized.",
        "No post-response partition, closure, history or threshold tuning is authorized."
      ],
      "application_acceptance_adjudicated":False,
      "performance_comparison_authorized":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,"frontiers":out["frontiers"],
      "placement_tests":out["placement_tests"],"integrity":out["integrity"]
    },sort_keys=True))

if __name__=="__main__":
    main()
