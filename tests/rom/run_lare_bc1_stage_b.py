#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from dataclasses import dataclass

import numpy as np

THETA_R=0.02
THETA_S=0.427494
ALPHA=0.021659
N_VG=1.734737
M_VG=1.0-1.0/N_VG
KS=31.225016
LAMBDA=0.98087

OBS_DT=0.0008
STEPS=1024
HEUN_DT=(0.0002,0.0001)
HEUN_CORRECTOR_TOL_THETA=1.0e-13
HEUN_MAX_CORRECTOR=50
LEDGER_GATE=1.0e-10

PARTITIONS={
    "D3":np.asarray([140.0,10.0,10.0],dtype=float),
    "D4":np.asarray([130.0,10.0,10.0,10.0],dtype=float),
}
BOUNDARIES={
    "D3":[0.0,140.0,150.0,160.0],
    "D4":[0.0,130.0,140.0,150.0,160.0],
}
HISTORY_SE={"G00":0.85,"G03":0.95,"G04":0.85,"G05":0.65}
CLOSURES=("CURRENT_LAYER_FACE","BOUNDARY_FACE")

@dataclass(frozen=True)
class Case:
    partition:str
    history:str
    closure:str
    @property
    def id(self)->str:
        return f"{self.partition}_{self.history}_{self.closure}"

def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1);out[k]=v
    return out

def theta_from_se(se:float)->float:
    return THETA_R+se*(THETA_S-THETA_R)

def se_from_theta(theta:np.ndarray)->np.ndarray:
    return (theta-THETA_R)/(THETA_S-THETA_R)

def psi_k(theta:np.ndarray)->tuple[np.ndarray,np.ndarray]:
    se=se_from_theta(theta)
    if np.any(~np.isfinite(se)) or np.any(se<=0.0) or np.any(se>=1.0):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN theta endpoint")
    psi=np.power(np.power(se,-1.0/M_VG)-1.0,1.0/N_VG)/ALPHA
    term=1.0-np.power(1.0-np.power(se,1.0/M_VG),M_VG)
    k=KS*np.power(se,LAMBDA)*np.square(term)
    if np.any(~np.isfinite(psi)) or np.any(~np.isfinite(k)) or np.any(k<0.0):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN constitutive")
    if np.any(psi<=0.01):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN near-saturation smoothing")
    return psi,k

def psi_from_se(se:float)->float:
    return float(np.power(np.power(se,-1.0/M_VG)-1.0,1.0/N_VG)/ALPHA)

def k_from_psi(psi:float)->float:
    se=(1.0+(ALPHA*abs(psi))**N_VG)**(-M_VG)
    term=1.0-(1.0-se**(1.0/M_VG))**M_VG
    return float(KS*se**LAMBDA*term*term)

def initial(history:str,partition:str)->tuple[np.ndarray,np.ndarray,float,float]:
    dz=PARTITIONS[partition].copy()
    se0=HISTORY_SE[history]
    theta0=theta_from_se(se0)
    theta=np.full(len(dz),theta0,dtype=float)
    psi,k=psi_k(theta)
    y=np.concatenate([theta*dz,[0.0,0.0]])
    return dz,y,float(k[0]),float(psi[0])

def symbol(history:str,step:int)->str:
    if history=="G00":
        if step<=24:return "BOTTOM_HEAD_FALL"
        if step<=64:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="G03":
        if step<=256:return "BOTTOM_HEAD_FALL"
        if step<=768:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="G04":
        if step<=256:return "BOTTOM_HEAD_RISE"
        if step<=768:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    if history=="G05":
        if step<=256:return "COMBINED_RISE_PLUS"
        if step<=512:return "HOLD"
        if step<=768:return "COMBINED_FALL_MINUS"
        return "HOLD"
    raise ValueError(history)

def qtop_downward(sym:str,k0:float)->float:
    if sym=="COMBINED_RISE_PLUS":return 0.99*k0
    if sym=="COMBINED_FALL_MINUS":return 1.01*k0
    return k0

def boundary_psi(history:str,sym:str,psi0:float)->float|None:
    if sym in ("BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"):
        return 0.75*psi0
    if sym in ("BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"):
        return 1.25*psi0
    if sym=="HOLD":
        return None
    raise ValueError((history,sym))

def interface_fluxes(theta:np.ndarray,dz:np.ndarray)->np.ndarray:
    psi,k=psi_k(theta)
    if len(theta)<=1:return np.empty(0,dtype=float)
    out=np.empty(len(theta)-1,dtype=float)
    for i in range(len(out)):
        di=float(dz[i]);dj=float(dz[i+1])
        kij=(dj*k[i]+di*k[i+1])/(di+dj)
        out[i]=kij*(1.0+2.0*(psi[i+1]-psi[i])/(di+dj))
    return out

def qbottom(theta:np.ndarray,dz:np.ndarray,k0:float,psi0:float,history:str,sym:str,closure:str)->float:
    psib=boundary_psi(history,sym,psi0)
    if psib is None:
        return k0
    psi,k=psi_k(theta)
    grad=1.0+2.0*(psib-float(psi[-1]))/float(dz[-1])
    if closure=="CURRENT_LAYER_FACE":
        kb=float(k[-1])
    elif closure=="BOUNDARY_FACE":
        kb=k_from_psi(psib)
    else:
        raise ValueError(closure)
    return kb*grad

def rhs(y:np.ndarray,dz:np.ndarray,k0:float,psi0:float,history:str,sym:str,closure:str)->np.ndarray:
    n=len(dz)
    theta=y[:n]/dz
    qint=interface_fluxes(theta,dz)
    qt=qtop_downward(sym,k0)
    qb=qbottom(theta,dz,k0,psi0,history,sym,closure)
    dy=np.zeros_like(y)
    for i in range(n):
        qup=qt if i==0 else qint[i-1]
        qdn=qb if i==n-1 else qint[i]
        dy[i]=qup-qdn
    dy[n]=qt
    dy[n+1]=qb
    return dy

def heun_step(y,dt,dz,k0,psi0,history,sym,closure):
    f0=rhs(y,dz,k0,psi0,history,sym,closure)
    guess=y+dt*f0
    n=len(dz)
    for iteration in range(1,HEUN_MAX_CORRECTOR+1):
        nxt=y+0.5*dt*(f0+rhs(guess,dz,k0,psi0,history,sym,closure))
        if np.max(np.abs(nxt[:n]/dz-guess[:n]/dz))<=HEUN_CORRECTOR_TOL_THETA:
            return nxt,iteration
        guess=nxt
    raise RuntimeError("iterative Heun corrector did not converge")

def solve(case:Case,dt:float)->dict[str,object]:
    ratio=OBS_DT/dt
    substeps=int(round(ratio))
    if substeps<=0 or abs(ratio-substeps)>1e-12:
        raise ValueError("dt must divide observation interval")
    dz,y,k0,psi0=initial(case.history,case.partition)
    n=len(dz)
    storage=[]
    cum_bottom=[]
    interval_bottom=[]
    max_corrector=0
    max_ledger=0.0
    prev_cumb=0.0
    for step in range(1,STEPS+1):
        sym=symbol(case.history,step)
        for _ in range(substeps):
            y,it=heun_step(y,dt,dz,k0,psi0,case.history,sym,case.closure)
            max_corrector=max(max_corrector,it)
        theta=y[:n]/dz
        psi_k(theta)
        total=float(np.sum(y[:n]))
        ledger=total-float(np.sum(initial(case.history,case.partition)[1][:n]))-(float(y[n])-float(y[n+1]))
        max_ledger=max(max_ledger,abs(ledger))
        storage.append(y[:n].copy())
        cumb=float(y[n+1])
        cum_bottom.append(cumb)
        interval_bottom.append((cumb-prev_cumb)/OBS_DT)
        prev_cumb=cumb
    return {
        "status":"QUALIFIED",
        "dt_day":dt,
        "layer_storage_cm":np.asarray(storage).tolist(),
        "cumulative_bottom_downward_cm":cum_bottom,
        "interval_average_bottom_downward_flux_cm_per_day":interval_bottom,
        "max_abs_water_ledger_cm":max_ledger,
        "max_corrector_iterations":max_corrector,
    }

def project_reference(nodes:list[dict[str,float]],bounds:list[float])->list[float]:
    out=[]
    for lo,hi in zip(bounds,bounds[1:]):
        total=0.0;covered=0.0
        for row in nodes:
            node=int(row["node"])
            top=(node-1)*10.0;bot=node*10.0
            w=max(0.0,min(hi,bot)-max(lo,top))
            if w>0.0:
                total+=float(row["theta"])*w;covered+=w
        if abs(covered-(hi-lo))>1e-12:
            raise RuntimeError((lo,hi,covered))
        out.append(total)
    return out

def load_reference(path:pathlib.Path)->dict[str,dict[str,object]]:
    states={}
    nodes={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            if r["HISTORY"] in HISTORY_SE:
                states[(r["HISTORY"],int(r["STEP"]))]=r
        elif line.startswith("LAREGW1_NODE|"):
            r=fields(line.split("|",1)[1])
            if r["HISTORY"] in HISTORY_SE:
                nodes.setdefault((r["HISTORY"],int(r["STEP"])),[]).append({
                    "node":int(r["NODE"]),"theta":float(r["THETA"])
                })
    out={}
    for hist in HISTORY_SE:
        hs=[]
        for step in range(1,STEPS+1):
            key=(hist,step)
            if key not in states or key not in nodes or len(nodes[key])!=16:
                raise RuntimeError(f"incomplete Reference {key}")
            r=states[key]
            hs.append({
                "step":step,
                "bottom_exchange_cm":float(r["BOTTOM_OUTWARD_EXCHANGE"]),
                "bottom_interval_flux_cm_per_day":float(r["BOTTOM_OUTWARD_EXCHANGE"])/OBS_DT,
                "nodes":sorted(nodes[key],key=lambda x:x["node"]),
            })
        out[hist]={"steps":hs}
    return out

def reversals(values:list[float])->list[int]:
    out=[];prev=0
    for i,v in enumerate(values,1):
        s=1 if v>0 else -1 if v<0 else 0
        if s==0:continue
        if prev and s!=prev:out.append(i)
        prev=s
    return out

def quantile(xs:list[float],q:float)->float:
    ys=sorted(xs)
    pos=q*(len(ys)-1);lo=int(math.floor(pos));hi=int(math.ceil(pos))
    if lo==hi:return ys[lo]
    return ys[lo]*(hi-pos)+ys[hi]*(pos-lo)

def compare(candidate:dict[str,object],ref_steps:list[dict[str,object]],bounds:list[float])->dict[str,object]:
    cs=np.asarray(candidate["layer_storage_cm"],dtype=float)
    rs=np.asarray([project_reference(row["nodes"],bounds) for row in ref_steps],dtype=float)
    sd=cs-rs
    cb=np.asarray(candidate["cumulative_bottom_downward_cm"],dtype=float)
    rb=np.cumsum([float(r["bottom_exchange_cm"]) for r in ref_steps])
    bd=cb-rb
    cq=np.asarray(candidate["interval_average_bottom_downward_flux_cm_per_day"],dtype=float)
    rq=np.asarray([float(r["bottom_interval_flux_cm_per_day"]) for r in ref_steps])
    qd=cq-rq
    crev=reversals(cq.tolist());rrev=reversals(rq.tolist())
    rev_match=len(crev)==len(rrev)
    max_rev=None if not rev_match else (max([abs(a-b) for a,b in zip(crev,rrev)] or [0]))
    return {
        "max_abs_layer_storage_error_cm":float(np.max(np.abs(sd))),
        "mean_abs_layer_storage_error_cm":float(np.mean(np.abs(sd))),
        "p95_abs_layer_storage_error_cm":float(quantile(np.abs(sd).ravel().tolist(),0.95)),
        "final_signed_layer_storage_error_cm":sd[-1].tolist(),
        "max_abs_cumulative_bottom_exchange_error_cm":float(np.max(np.abs(bd))),
        "final_signed_cumulative_bottom_exchange_error_cm":float(bd[-1]),
        "max_abs_interval_bottom_flux_error_cm_per_day":float(np.max(np.abs(qd))),
        "mean_abs_interval_bottom_flux_error_cm_per_day":float(np.mean(np.abs(qd))),
        "bottom_flux_sign_mismatch_count":int(np.count_nonzero(np.sign(cq)!=np.sign(rq))),
        "candidate_reversal_steps":crev,
        "reference_reversal_steps":rrev,
        "reversal_sequence_length_match":rev_match,
        "max_reversal_step_difference":max_rev,
        "max_reversal_time_difference_minutes":None if max_rev is None else max_rev*OBS_DT*24.0*60.0,
        "max_abs_water_ledger_cm":float(candidate["max_abs_water_ledger_cm"]),
    }

def numerical_floor(a:dict[str,object],b:dict[str,object])->dict[str,float]:
    sa=np.asarray(a["layer_storage_cm"],float);sb=np.asarray(b["layer_storage_cm"],float)
    ca=np.asarray(a["cumulative_bottom_downward_cm"],float);cb=np.asarray(b["cumulative_bottom_downward_cm"],float)
    qa=np.asarray(a["interval_average_bottom_downward_flux_cm_per_day"],float)
    qb=np.asarray(b["interval_average_bottom_downward_flux_cm_per_day"],float)
    return {
        "max_abs_layer_storage_cm":float(np.max(np.abs(sa-sb))),
        "max_abs_cumulative_bottom_exchange_cm":float(np.max(np.abs(ca-cb))),
        "max_abs_interval_bottom_flux_cm_per_day":float(np.max(np.abs(qa-qb))),
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_PRESCRIBED_HEAD_REDUCED_DYNAMICS"
    assert pre["pre_execution_domain_coverage_clarification"]["before_first_BC1_B_execution"] is True

    ref=load_reference(args.reference)
    cases={}
    for part in PARTITIONS:
        for hist in HISTORY_SE:
            for closure in CLOSURES:
                case=Case(part,hist,closure)
                refinements={};failures={}
                for dt in HEUN_DT:
                    key=f"{dt:.7f}"
                    try:
                        refinements[key]=solve(case,dt)
                    except ValueError as exc:
                        failures[key]=f"OUTSIDE_QUALIFIED_DOMAIN: {exc}"
                    except (RuntimeError,FloatingPointError) as exc:
                        failures[key]=f"NUMERICAL_BLOCKED: {exc}"
                finest=refinements.get("0.0001000")
                if finest is not None:
                    status="QUALIFIED"
                    comparison=compare(finest,ref[hist]["steps"],BOUNDARIES[part])
                elif "OUTSIDE_QUALIFIED_DOMAIN" in failures.get("0.0001000",""):
                    status="OUTSIDE_QUALIFIED_DOMAIN";comparison=None
                else:
                    status="NUMERICAL_BLOCKED";comparison=None
                floor=None
                if "0.0002000" in refinements and "0.0001000" in refinements:
                    floor=numerical_floor(refinements["0.0002000"],refinements["0.0001000"])
                cases[case.id]={
                    "partition":part,"history":hist,"closure":closure,
                    "status":status,"comparison":comparison,
                    "numerical_floor":floor,"failures":failures,
                    "finest_max_corrector_iterations":None if finest is None else finest["max_corrector_iterations"],
                }

    aggregates={}
    for closure in CLOSURES:
        qualified=[v for v in cases.values() if v["closure"]==closure and v["status"]=="QUALIFIED"]
        comps=[v["comparison"] for v in qualified]
        aggregates[closure]={
            "qualified_case_count":len(qualified),
            "outside_qualified_domain_count":sum(v["closure"]==closure and v["status"]=="OUTSIDE_QUALIFIED_DOMAIN" for v in cases.values()),
            "numerical_blocked_count":sum(v["closure"]==closure and v["status"]=="NUMERICAL_BLOCKED" for v in cases.values()),
            "max_abs_layer_storage_error_cm":None if not comps else max(x["max_abs_layer_storage_error_cm"] for x in comps),
            "mean_of_case_mean_abs_layer_storage_error_cm":None if not comps else sum(x["mean_abs_layer_storage_error_cm"] for x in comps)/len(comps),
            "max_abs_cumulative_bottom_exchange_error_cm":None if not comps else max(x["max_abs_cumulative_bottom_exchange_error_cm"] for x in comps),
            "max_abs_interval_bottom_flux_error_cm_per_day":None if not comps else max(x["max_abs_interval_bottom_flux_error_cm_per_day"] for x in comps),
            "bottom_flux_sign_mismatch_count":None if not comps else sum(x["bottom_flux_sign_mismatch_count"] for x in comps),
            "reversal_sequence_mismatch_case_count":None if not comps else sum(not x["reversal_sequence_length_match"] for x in comps),
            "max_reversal_step_difference":None if not comps else max([x["max_reversal_step_difference"] for x in comps if x["max_reversal_step_difference"] is not None] or [0]),
            "max_abs_water_ledger_cm":None if not comps else max(x["max_abs_water_ledger_cm"] for x in comps),
        }

    common_ids=[]
    for part in PARTITIONS:
        for hist in HISTORY_SE:
            a=cases[f"{part}_{hist}_CURRENT_LAYER_FACE"]
            b=cases[f"{part}_{hist}_BOUNDARY_FACE"]
            if a["status"]=="QUALIFIED" and b["status"]=="QUALIFIED":
                common_ids.append((part,hist))

    def common_vector(closure):
        rows=[cases[f"{p}_{h}_{closure}"]["comparison"] for p,h in common_ids]
        return {
            "common_case_count":len(rows),
            "max_abs_layer_storage_error_cm":max(x["max_abs_layer_storage_error_cm"] for x in rows) if rows else None,
            "mean_of_case_mean_abs_layer_storage_error_cm":sum(x["mean_abs_layer_storage_error_cm"] for x in rows)/len(rows) if rows else None,
            "max_abs_cumulative_bottom_exchange_error_cm":max(x["max_abs_cumulative_bottom_exchange_error_cm"] for x in rows) if rows else None,
            "max_abs_interval_bottom_flux_error_cm_per_day":max(x["max_abs_interval_bottom_flux_error_cm_per_day"] for x in rows) if rows else None,
            "bottom_flux_sign_mismatch_count":sum(x["bottom_flux_sign_mismatch_count"] for x in rows) if rows else None,
            "reversal_sequence_mismatch_case_count":sum(not x["reversal_sequence_length_match"] for x in rows) if rows else None,
            "max_reversal_step_difference":max([x["max_reversal_step_difference"] for x in rows if x["max_reversal_step_difference"] is not None] or [0]) if rows else None,
        }

    common={c:common_vector(c) for c in CLOSURES}
    primary_keys=[
        "max_abs_layer_storage_error_cm",
        "mean_of_case_mean_abs_layer_storage_error_cm",
        "max_abs_cumulative_bottom_exchange_error_cm",
        "max_abs_interval_bottom_flux_error_cm_per_day",
        "bottom_flux_sign_mismatch_count",
        "reversal_sequence_mismatch_case_count",
        "max_reversal_step_difference",
    ]
    a=common["CURRENT_LAYER_FACE"];b=common["BOUNDARY_FACE"]
    coverage_a=aggregates["CURRENT_LAYER_FACE"]["qualified_case_count"]
    coverage_b=aggregates["BOUNDARY_FACE"]["qualified_case_count"]
    a_noninferior=coverage_a>=coverage_b and all(a[k]<=b[k] for k in primary_keys)
    b_noninferior=coverage_b>=coverage_a and all(b[k]<=a[k] for k in primary_keys)
    a_strict=coverage_a>coverage_b or any(a[k]<b[k] for k in primary_keys)
    b_strict=coverage_b>coverage_a or any(b[k]<a[k] for k in primary_keys)
    if coverage_a==0 and coverage_b==0:
        decision="BC1_BOTH_DYNAMICS_BLOCKED"
    elif not common_ids:
        decision="BC1_REFERENCE_OR_DOMAIN_INSUFFICIENT"
    elif a_noninferior and a_strict and not (b_noninferior and b_strict):
        decision="BC1_CURRENT_LAYER_RELATIVE_SUPPORT"
    elif b_noninferior and b_strict and not (a_noninferior and a_strict):
        decision="BC1_BOUNDARY_FACE_RELATIVE_SUPPORT"
    else:
        decision="BC1_MIXED_NO_RELATIVE_SELECTION"

    # D4-vs-D3 closure-resolution comparison on common qualified histories for each closure.
    resolution={}
    for closure in CLOSURES:
        rows=[]
        for hist in HISTORY_SE:
            d3=cases[f"D3_{hist}_{closure}"];d4=cases[f"D4_{hist}_{closure}"]
            if d3["status"]=="QUALIFIED" and d4["status"]=="QUALIFIED":
                rows.append({
                    "history":hist,
                    "D3_max_layer_cm":d3["comparison"]["max_abs_layer_storage_error_cm"],
                    "D4_max_layer_cm":d4["comparison"]["max_abs_layer_storage_error_cm"],
                    "D3_max_cum_bottom_cm":d3["comparison"]["max_abs_cumulative_bottom_exchange_error_cm"],
                    "D4_max_cum_bottom_cm":d4["comparison"]["max_abs_cumulative_bottom_exchange_error_cm"],
                })
        resolution[closure]=rows

    result={
        "schema":"swap5.lare.bc1.stage-b.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC1-B",
        "decision":decision,
        "reference_authority":{
            "artifact_id":10585316225,
            "payload_sha256":"7d92c4524d16836a25200851ce560b041971d05f65256785e8cf1ef59ae0b345"
        },
        "cases":cases,
        "aggregate_by_closure":aggregates,
        "common_cohort":{
            "partition_history_cases":[{"partition":p,"history":h} for p,h in common_ids],
            "CURRENT_LAYER_FACE":a,
            "BOUNDARY_FACE":b,
        },
        "relative_support":{
            "CURRENT_LAYER_FACE_noninferior":a_noninferior,
            "CURRENT_LAYER_FACE_strictly_better":a_strict,
            "BOUNDARY_FACE_noninferior":b_noninferior,
            "BOUNDARY_FACE_strictly_better":b_strict,
            "qualified_case_coverage":{
                "CURRENT_LAYER_FACE":coverage_a,
                "BOUNDARY_FACE":coverage_b
            },
            "no_scalar_weighting":True
        },
        "D3_D4_resolution":resolution,
        "interpretation_firewall":[
            "Reference bottom comparison uses interval-integrated outward exchange from the Stage-A mass-accounting authority.",
            "Interval-average Reference bottom flux is exchange divided by observation duration, not an independent current-K terminal face observable.",
            "No boundary coefficient was fitted and no candidate was retuned after response.",
            "Relative support is closure characterization, not absolute groundwater-application acceptance."
        ],
        "application_acceptance_adjudicated":False,
        "moving_water_table_authorized":False,
        "speed_claim":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],"decision":decision,
        "aggregate_by_closure":aggregates,
        "common_cohort":result["common_cohort"],
        "relative_support":result["relative_support"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
