#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from dataclasses import dataclass

import numpy as np

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
ELL=0.98087
NBINS=200
I=100
J0=101
J1=199
DEPTH=160.0
OBS_DT=0.001
NSTEPS=64
DT=0.0001
SUBSTEPS=10
DTHETA=(TS-TR)/NBINS
THETA_I=TR+I*DTHETA
HEUN_TOL=1.0e-13
HEUN_MAX=50
LEDGER_GATE=1.0e-10
EQ_TOL=1.0e-12

HISTS={"V01":0.375,"V02":0.625,"V03":0.875,"V04":1.125}
LADDER={
    "L2":[0.0,150.0,160.0],
    "L3":[0.0,140.0,150.0,160.0],
    "L4":[0.0,130.0,140.0,150.0,160.0],
    "L6":[0.0,110.0,120.0,130.0,140.0,150.0,160.0],
}
ORDER=("L2","L3","L4","L6")


def fields(payload:str)->dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
    return out


def qstats(values:list[float])->dict[str,float|int]:
    a=np.asarray(values,dtype=float)
    aa=np.abs(a)
    return {
        "count":int(len(a)),
        "mean":float(np.mean(a)),
        "mean_abs":float(np.mean(aa)),
        "rmse":float(np.sqrt(np.mean(a*a))),
        "p95_abs":float(np.percentile(aa,95)),
        "max_abs":float(np.max(aa)),
    }


def se_from_theta(theta:np.ndarray)->np.ndarray:
    return (theta-TR)/(TS-TR)


def psi_k(theta:np.ndarray)->tuple[np.ndarray,np.ndarray]:
    se=se_from_theta(theta)
    if np.any(~np.isfinite(se)) or np.any(se<=0.0) or np.any(se>=1.0):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN theta endpoint")
    psi=np.power(np.power(se,-1.0/M)-1.0,1.0/N)/ALPHA
    term=1.0-np.power(1.0-np.power(se,1.0/M),M)
    k=KS*np.power(se,ELL)*np.square(term)
    if np.any(~np.isfinite(psi)) or np.any(~np.isfinite(k)) or np.any(k<0.0):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN constitutive")
    if np.any(psi<=0.01):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN near-saturation smoothing")
    return psi,k


def psi_scalar(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    return float((se**(-1.0/M)-1.0)**(1.0/N)/ALPHA)


THETA=[TR+j*DTHETA for j in range(J0,J1+1)]
PSI=[psi_scalar(t) for t in THETA]


def parse_d13(path:pathlib.Path):
    states={}; nodes={}; initial={}; geom=None
    for line in path.read_text(errors="replace").splitlines():
        if "F_ROMV2_D13_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D13_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D13_REF_INITIAL|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_INITIAL|",1)[1])
            initial[r["HISTORY"].strip()]=r
        elif "F_ROMV2_D13_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_STATE|",1)[1])
            states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D13_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_NODE|",1)[1])
            nodes[(r["HISTORY"].strip(),int(r["STEP"]),int(r["NODE"]))]=r
    if geom is None:
        raise RuntimeError("missing D13 geometry")
    n=int(geom["N"])
    expected={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if set(states)!=expected or set(initial)!=set(HISTS) or len(nodes)!=len(expected)*n:
        raise RuntimeError("D13 payload structure mismatch")
    return {"n":n,"states":states,"nodes":nodes,"initial":initial}


def exact_initial_profile(lam:float)->list[float]:
    return [lam*x for x in PSI]


def layer_mean_theta_from_fronts(h:list[float],zlo:float,zhi:float)->float:
    dz=zhi-zlo
    ylow=DEPTH-zhi
    yhigh=DEPTH-zlo
    theta=THETA_I
    for hj in h:
        width=max(0.0,min(hj,yhigh)-max(0.0,ylow))
        theta += DTHETA*width/dz
    if not TR<theta<TS:
        raise ValueError("initial layer theta outside physical bounds")
    return theta


def initial(lam:float,bounds:list[float],reference_initial:dict[str,str]):
    h=exact_initial_profile(lam)
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray([
        layer_mean_theta_from_fronts(h,float(lo),float(hi))
        for lo,hi in zip(bounds,bounds[1:])
    ],dtype=float)
    psi_k(theta)
    y=np.concatenate([theta*dz,[0.0,0.0]])
    total=float(np.sum(y[:len(dz)]))
    ref_total=float(reference_initial["TOTAL_STORAGE"])
    if abs(total-ref_total)>1.0e-12:
        raise RuntimeError(f"initial storage identity mismatch {total-ref_total}")
    return dz,y,total


def interface_fluxes(theta:np.ndarray,dz:np.ndarray)->np.ndarray:
    psi,k=psi_k(theta)
    out=np.empty(max(0,len(theta)-1),dtype=float)
    for i in range(len(out)):
        di=float(dz[i]); dj=float(dz[i+1])
        kij=(dj*k[i]+di*k[i+1])/(di+dj)
        out[i]=kij*(1.0+2.0*(psi[i+1]-psi[i])/(di+dj))
    return out


def qbottom_zero_head(theta:np.ndarray,dz:np.ndarray)->float:
    psi,k=psi_k(theta)
    q=float(k[-1])*(1.0+2.0*(0.0-float(psi[-1]))/float(dz[-1]))
    if not math.isfinite(q):
        raise FloatingPointError("nonfinite qbottom")
    return q


def rhs(y:np.ndarray,dz:np.ndarray)->np.ndarray:
    n=len(dz)
    theta=y[:n]/dz
    qint=interface_fluxes(theta,dz)
    qb=qbottom_zero_head(theta,dz)
    dy=np.zeros_like(y)
    for i in range(n):
        qup=0.0 if i==0 else qint[i-1]
        qdn=qb if i==n-1 else qint[i]
        dy[i]=qup-qdn
    dy[n]=0.0
    dy[n+1]=qb
    return dy


def heun_step(y:np.ndarray,dz:np.ndarray):
    f0=rhs(y,dz)
    guess=y+DT*f0
    n=len(dz)
    for it in range(1,HEUN_MAX+1):
        nxt=y+0.5*DT*(f0+rhs(guess,dz))
        if np.max(np.abs(nxt[:n]/dz-guess[:n]/dz))<=HEUN_TOL:
            return nxt,it
        guess=nxt
    raise RuntimeError("iterative Heun corrector did not converge")


def map_piecewise_to_10cm(theta:np.ndarray,bounds:list[float])->list[float]:
    out=[]
    for node in range(1,17):
        lo=(node-1)*10.0; hi=node*10.0
        total=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0:
                total+=float(t)*w
        out.append(total/10.0)
    return out


def integrated_storage(theta:np.ndarray,bounds:list[float],lo:float,hi:float)->float:
    total=0.0
    for t,a,b in zip(theta,bounds,bounds[1:]):
        w=max(0.0,min(hi,b)-max(lo,a))
        if w>0.0:
            total+=float(t)*w
    return total


def sign(x:float)->int:
    return 1 if x>0.0 else (-1 if x<0.0 else 0)


def run_member(member:str,bounds:list[float],r16)->dict:
    dim=len(bounds)-1
    pooled_S=[]; pooled_C=[]; pooled_Q=[]; pooled_T=[]; pooled_U=[]; pooled_L=[]
    signerr=0; by_hist={}; maxledger=0.0; maxiter=0
    status="QUALIFIED"; failure=None; failure_class=None
    for hist,lam in HISTS.items():
        try:
            dz,y,initial_total=initial(lam,bounds,r16["initial"][hist])
            cum=0.0
            es=[];ec=[];eq=[];et=[];eu=[];el=[];hsign=0
            for step in range(1,NSTEPS+1):
                for _ in range(SUBSTEPS):
                    y,it=heun_step(y,dz)
                    maxiter=max(maxiter,it)
                theta=y[:dim]/dz
                psi_k(theta)
                total=float(np.sum(y[:dim]))
                cumb=float(y[dim+1])
                qb=qbottom_zero_head(theta,dz)
                ledger=total-initial_total+cumb
                maxledger=max(maxledger,abs(ledger))
                if abs(ledger)>LEDGER_GATE:
                    raise RuntimeError(f"water ledger gate {ledger}")
                rr=r16["states"][(hist,step)]
                ref_total=float(rr["TOTAL_STORAGE"])
                ref_cum=sum(float(r16["states"][(hist,s)]["BOTTOM_OUTWARD_EXCHANGE"]) for s in range(1,step+1))
                ref_q=float(rr["BOTTOM_FLUX"])
                es.append(total-ref_total)
                ec.append(cumb-ref_cum)
                eq.append(qb-ref_q)
                if sign(ref_q)!=0 and sign(qb)!=sign(ref_q):
                    hsign+=1
                mapped=map_piecewise_to_10cm(theta,bounds)
                for node,t in enumerate(mapped,1):
                    et.append(float(t)-float(r16["nodes"][(hist,step,node)]["THETA"]))
                rupper=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(1,9))
                rlower=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(9,17))
                eu.append(integrated_storage(theta,bounds,0.0,80.0)-rupper)
                el.append(integrated_storage(theta,bounds,80.0,160.0)-rlower)
            signerr+=hsign
            by_hist[hist]={
                "total_storage_error_cm":qstats(es),
                "cumulative_bottom_exchange_error_cm":qstats(ec),
                "terminal_bottom_flux_error_cm_per_day":qstats(eq),
                "mapped_R16_cell_theta_error":qstats(et),
                "upper_storage_error_cm":qstats(eu),
                "lower_storage_error_cm":qstats(el),
                "bottom_flux_sign_error_count":hsign,
                "final_cumulative_bottom_exchange_error_cm":ec[-1],
            }
            pooled_S+=es; pooled_C+=ec; pooled_Q+=eq; pooled_T+=et; pooled_U+=eu; pooled_L+=el
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN"; failure={"history":hist,"error":str(exc)}; failure_class=status; break
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED"; failure={"history":hist,"error":str(exc)}; failure_class=status; break
    pooled=None
    if status=="QUALIFIED":
        pooled={
            "total_storage_error_cm":qstats(pooled_S),
            "cumulative_bottom_exchange_error_cm":qstats(pooled_C),
            "terminal_bottom_flux_error_cm_per_day":qstats(pooled_Q),
            "mapped_R16_cell_theta_error":qstats(pooled_T),
            "upper_storage_error_cm":qstats(pooled_U),
            "lower_storage_error_cm":qstats(pooled_L),
            "bottom_flux_sign_error_count":signerr,
        }
    return {
        "id":member,"dimension":dim,"boundaries_cm":bounds,
        "status":status,"failure_class":failure_class,"failure":failure,
        "max_abs_water_ledger_cm":maxledger,"max_corrector_iterations":maxiter,
        "pooled":pooled,"by_history":by_hist,
    }


def r2_metrics(r2,r16)->dict:
    es=[];ec=[];eq=[];et=[];eu=[];el=[];signerr=0
    for hist in HISTS:
        cum=0.0;rcum=0.0
        for step in range(1,NSTEPS+1):
            c=r2["states"][(hist,step)]; r=r16["states"][(hist,step)]
            cum+=float(c["BOTTOM_OUTWARD_EXCHANGE"]); rcum+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
            es.append(float(c["TOTAL_STORAGE"])-float(r["TOTAL_STORAGE"]))
            ec.append(cum-rcum)
            cq=float(c["BOTTOM_FLUX"]); rq=float(r["BOTTOM_FLUX"])
            eq.append(cq-rq)
            if sign(rq)!=0 and sign(cq)!=sign(rq):
                signerr+=1
            t1=float(r2["nodes"][(hist,step,1)]["THETA"])
            t2=float(r2["nodes"][(hist,step,2)]["THETA"])
            for node,t in enumerate([t1]*8+[t2]*8,1):
                et.append(t-float(r16["nodes"][(hist,step,node)]["THETA"]))
            ru=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(1,9))
            rl=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(9,17))
            eu.append(t1*80.0-ru); el.append(t2*80.0-rl)
    return {
        "total_storage_error_cm":qstats(es),
        "cumulative_bottom_exchange_error_cm":qstats(ec),
        "terminal_bottom_flux_error_cm_per_day":qstats(eq),
        "mapped_R16_cell_theta_error":qstats(et),
        "upper_storage_error_cm":qstats(eu),
        "lower_storage_error_cm":qstats(el),
        "bottom_flux_sign_error_count":signerr,
    }


def fmc_metrics(raw:dict)->dict:
    p=raw["FMC"]["pooled"]
    return {
        "total_storage_error_cm":p["total_storage_error_cm"],
        "cumulative_bottom_exchange_error_cm":p["cumulative_bottom_exchange_error_cm"],
        "terminal_bottom_flux_error_cm_per_day":p["terminal_bottom_flux_error_cm_per_day"],
        "mapped_R16_cell_theta_error":p["R16_cell_theta_error"],
        "bottom_flux_sign_error_count":p["bottom_flux_sign_error_count"],
    }


def scalar_diff(a,b)->float:
    return abs(float(a)-float(b))


def validate_metric_group(a:dict,b:dict,tol:float,label:str)->float:
    largest=0.0
    for metric in ("total_storage_error_cm","cumulative_bottom_exchange_error_cm","terminal_bottom_flux_error_cm_per_day","mapped_R16_cell_theta_error"):
        for stat in ("mean","mean_abs","rmse","p95_abs","max_abs"):
            d=scalar_diff(a[metric][stat],b[metric][stat])
            largest=max(largest,d)
            if d>tol:
                raise RuntimeError(f"{label} reproduction drift {metric}.{stat}={d}")
    if int(a["bottom_flux_sign_error_count"])!=int(b["bottom_flux_sign_error_count"]):
        raise RuntimeError(f"{label} sign-count reproduction drift")
    return largest


def crosses_gw(member:dict,comp:dict,tol:float)->bool:
    if member["status"]!="QUALIFIED":
        return False
    a=member["pooled"]
    return (
        a["total_storage_error_cm"]["rmse"]<=comp["total_storage_error_cm"]["rmse"]+tol
        and a["cumulative_bottom_exchange_error_cm"]["rmse"]<=comp["cumulative_bottom_exchange_error_cm"]["rmse"]+tol
        and a["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=comp["terminal_bottom_flux_error_cm_per_day"]["rmse"]+tol
        and a["bottom_flux_sign_error_count"]<=comp["bottom_flux_sign_error_count"]
    )


def crosses_profile(member:dict,comp:dict,tol:float)->bool:
    return crosses_gw(member,comp,tol) and (
        member["pooled"]["mapped_R16_cell_theta_error"]["rmse"]
        <=comp["mapped_R16_cell_theta_error"]["rmse"]+tol
    )


def minimum_dimension(members:list[dict],key:str):
    dims=[m["dimension"] for m in members if m["status"]=="QUALIFIED" and m[key]]
    return min(dims) if dims else None


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-result",required=True,type=pathlib.Path)
    ap.add_argument("--c4r-result",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_LAYER_LADDER_FIXED_HEAD_REPLAY":
        raise SystemExit("wrong B1 preregistration phase")
    if [r["id"] for r in pre["layer_ladder"]]!=list(ORDER):
        raise SystemExit("B1 ladder drift")

    r16=parse_d13(args.r16); r2=parse_d13(args.r2)
    if r16["n"]!=16 or r2["n"]!=2:
        raise SystemExit("B1 Reference geometry mismatch")
    for hist,lam in HISTS.items():
        if float(r16["initial"][hist]["LAMBDA"])!=lam or float(r2["initial"][hist]["LAMBDA"])!=lam:
            raise SystemExit(f"B1 blind lambda drift {hist}")

    persisted=json.loads(args.c4r_result.read_text())
    raw_fmc=json.loads(args.fmc_result.read_text())
    tol=float(pre["relative_frontiers"]["numerical_equality_tolerance"])
    r2cmp=r2_metrics(r2,r16)
    fmccmp=fmc_metrics(raw_fmc)

    max_repro=0.0
    max_repro=max(max_repro,validate_metric_group(r2cmp,persisted["comparators"]["R2"]["pooled"],tol,"R2"))
    max_repro=max(max_repro,validate_metric_group(fmccmp,persisted["comparators"]["FMC_GW200"]["pooled"],tol,"FMC"))

    members=[run_member(mid,list(map(float,LADDER[mid])),r16) for mid in ORDER]

    # Reproduce the already blind C4R L3/L4/L6 members before interpreting the new L2 challenge.
    persisted_members={m["id"]:m for m in persisted["lare_members"]}
    for mid,oldid in (("L3","R3"),("L4","R4"),("L6","R6")):
        old=persisted_members[oldid]
        new=next(m for m in members if m["id"]==mid)
        if new["status"]!=old["status"]:
            raise RuntimeError(f"{mid} C4R status reproduction drift")
        if new["status"]=="QUALIFIED":
            max_repro=max(max_repro,validate_metric_group(new["pooled"],old["pooled"],tol,f"{mid}/C4R"))

    for m in members:
        m["crosses_R2_GW"]=crosses_gw(m,r2cmp,tol)
        m["crosses_FMC_GW"]=crosses_gw(m,fmccmp,tol)
        m["crosses_R2_PROFILE"]=crosses_profile(m,r2cmp,tol)
        m["crosses_FMC_PROFILE"]=crosses_profile(m,fmccmp,tol)

    mins={
        "R2_GW":minimum_dimension(members,"crosses_R2_GW"),
        "FMC_GW":minimum_dimension(members,"crosses_FMC_GW"),
        "R2_PROFILE":minimum_dimension(members,"crosses_R2_PROFILE"),
        "FMC_PROFILE":minimum_dimension(members,"crosses_FMC_PROFILE"),
    }
    max_ledger=max((m["max_abs_water_ledger_cm"] for m in members if m["status"]=="QUALIFIED"),default=0.0)
    integrity=(
        max_repro<=tol
        and len(members)==4
        and all(m["status"]=="QUALIFIED" for m in members)
        and max_ledger<=float(pre["integrity_gates"]["maximum_water_ledger_cm"])
    )
    if not integrity:
        decision="B1_EXECUTION_OR_AUTHORITY_BLOCKED"
    elif mins["R2_GW"]==4 and mins["FMC_GW"]==4:
        decision="B1_DIMENSION4_GW_FRONTIER_REPLICATED"
    elif ((mins["R2_GW"] is not None and mins["R2_GW"]<4)
          or (mins["FMC_GW"] is not None and mins["FMC_GW"]<4)):
        decision="B1_LOWER_DIMENSION_GW_FRONTIER"
    else:
        decision="B1_HIGHER_DIMENSION_REQUIRED_FOR_GW_FRONTIER"

    result={
        "schema":"swap5.layer-rom.phase-b1.result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1",
        "decision":decision,
        "blind_reference_reused":True,
        "integrity":{
            "pass":integrity,
            "max_abs_C4R_reproduction_difference":max_repro,
            "maximum_qualified_water_ledger_cm":max_ledger,
            "all_four_members_qualified":all(m["status"]=="QUALIFIED" for m in members),
        },
        "comparators":{"R2":r2cmp,"FMC_GW200":fmccmp},
        "members":members,
        "frontiers":{
            "minimum_dimension":mins,
            "crossing_members":{
                "R2_GW":[m["id"] for m in members if m["crosses_R2_GW"]],
                "FMC_GW":[m["id"] for m in members if m["crosses_FMC_GW"]],
                "R2_PROFILE":[m["id"] for m in members if m["crosses_R2_PROFILE"]],
                "FMC_PROFILE":[m["id"] for m in members if m["crosses_FMC_PROFILE"]],
            },
        },
        "hypotheses":{
            "H1_L2_L3_do_not_cross_both_GW":not any(
                m["id"] in ("L2","L3") and (m["crosses_R2_GW"] or m["crosses_FMC_GW"])
                for m in members
            ),
            "H2_dimension4_both_GW":mins["R2_GW"]==4 and mins["FMC_GW"]==4,
            "H3_L6_profile_RMSE_lower_than_L4":(
                next(m for m in members if m["id"]=="L6")["pooled"]["mapped_R16_cell_theta_error"]["rmse"]
                < next(m for m in members if m["id"]=="L4")["pooled"]["mapped_R16_cell_theta_error"]["rmse"]
            ),
        },
        "interpretation_firewalls":[
            "B1 replays a previously blind fixed-water-table cohort and adds only the preregistered L2 challenge.",
            "Comparator-relative crossing is not application acceptance.",
            "Groundwater and profile vectors are adjudicated separately.",
            "The bottom boundary is fixed zero pressure head, not moving-water-table or coupled-groundwater application semantics.",
            "No runtime or speed conclusion is permitted."
        ],
        "application_acceptance":False,
        "speed_claim":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "integrity":result["integrity"],
        "frontiers":result["frontiers"],
        "members":{m["id"]:{
            "status":m["status"],
            "GW_R2":m["crosses_R2_GW"],
            "GW_FMC":m["crosses_FMC_GW"],
            "PROFILE_R2":m["crosses_R2_PROFILE"],
            "PROFILE_FMC":m["crosses_FMC_PROFILE"],
            "pooled":m["pooled"]
        } for m in members}
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
