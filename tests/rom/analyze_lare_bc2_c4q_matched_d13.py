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

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

bc1=load_module("bc1_c4q","run_lare_bc1_stage_b.py")

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
HISTS={"G25":0.25,"G50":0.50,"G75":0.75,"G125":1.25}
LEDGER_GATE=1e-10

def psi_scalar(theta):
    se=(theta-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

THETA=[TR+j*DTHETA for j in range(J0,J1+1)]
PSI=[psi_scalar(t) for t in THETA]

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse_d13(path):
    states={}; nodes={}; geom=None; initial={}
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
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

def qstats(errors):
    a=np.asarray(errors,dtype=float)
    aa=np.abs(a)
    return {
        "count":int(len(a)),
        "mean":float(np.mean(a)),
        "mean_abs":float(np.mean(aa)),
        "rmse":float(np.sqrt(np.mean(a*a))),
        "p95_abs":float(np.percentile(aa,95)),
        "max_abs":float(np.max(aa)),
    }

def exact_initial_profile(lam):
    h=[lam*x for x in PSI]
    return h

def layer_mean_theta_from_fronts(h,zlo,zhi):
    dz=zhi-zlo
    ylow=DEPTH-zhi
    yhigh=DEPTH-zlo
    theta=THETA_I
    for hj in h:
        overlap=max(0.0,min(hj,yhigh)-max(0.0,ylow))
        theta += DTHETA*overlap/dz
    if not(TR<theta<TS):
        raise ValueError("initial layer theta outside physical bounds")
    return theta

def initial_state(lam,bounds):
    h=exact_initial_profile(lam)
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray([layer_mean_theta_from_fronts(h,float(lo),float(hi)) for lo,hi in zip(bounds,bounds[1:])],dtype=float)
    bc1.psi_k(theta)
    y=np.concatenate([theta*dz,[0.0,0.0]])
    return dz,y,theta

def qbottom_zero_head(theta,dz):
    psi,k=bc1.psi_k(theta)
    grad=1.0+2.0*(0.0-float(psi[-1]))/float(dz[-1])
    q=float(k[-1])*grad
    if not math.isfinite(q):
        raise FloatingPointError("nonfinite qbottom")
    return q

def rhs(y,dz):
    n=len(dz)
    theta=y[:n]/dz
    qint=bc1.interface_fluxes(theta,dz)
    qb=qbottom_zero_head(theta,dz)
    dy=np.zeros_like(y)
    for i in range(n):
        qup=0.0 if i==0 else qint[i-1]
        qdn=qb if i==n-1 else qint[i]
        dy[i]=qup-qdn
    dy[n]=0.0
    dy[n+1]=qb
    return dy

def heun_step(y,dt,dz):
    f0=rhs(y,dz)
    guess=y+dt*f0
    n=len(dz)
    for it in range(1,bc1.HEUN_MAX_CORRECTOR+1):
        nxt=y+0.5*dt*(f0+rhs(guess,dz))
        if np.max(np.abs(nxt[:n]/dz-guess[:n]/dz))<=bc1.HEUN_CORRECTOR_TOL_THETA:
            return nxt,it
        guess=nxt
    raise RuntimeError("iterative Heun corrector did not converge")

def map_piecewise_to_10cm(theta,bounds):
    out=[]
    for node in range(1,17):
        lo=(node-1)*10.0; hi=node*10.0
        total=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0:
                total += float(t)*w
        out.append(total/10.0)
    return out

def integrated_storage(theta,bounds,lo,hi):
    total=0.0
    for t,a,b in zip(theta,bounds,bounds[1:]):
        w=max(0.0,min(hi,b)-max(lo,a))
        if w>0.0:
            total += float(t)*w
    return total

def sign(x):
    return 1 if x>0 else -1 if x<0 else 0

def run_member(member,r16):
    bounds=[float(x) for x in member["boundaries_cm"]]
    dim=int(member["dimension"])
    pooled_S=[]; pooled_C=[]; pooled_Q=[]; pooled_T=[]
    pooled_U=[]; pooled_L=[]
    signerr=0
    by_hist={}
    maxledger=0.0
    maxiter=0
    status="QUALIFIED"
    failure=None
    failclass=None

    for hist,lam in HISTS.items():
        try:
            dz,y,theta0=initial_state(lam,bounds)
            initial_total=float(np.sum(y[:dim]))
            d13_initial=float(r16["initial"][hist]["TOTAL_STORAGE"])
            if abs(initial_total-d13_initial)>1e-12:
                raise RuntimeError(f"initial storage identity mismatch {hist}: {initial_total-d13_initial}")
            cum=0.0
            es=[]; ec=[]; eq=[]; et=[]; eu=[]; el=[]
            hsign=0
            for step in range(1,NSTEPS+1):
                for _ in range(SUBSTEPS):
                    y,it=heun_step(y,DT,dz)
                    maxiter=max(maxiter,it)
                theta=y[:dim]/dz
                bc1.psi_k(theta)
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
                if sign(ref_q)!=0 and sign(qb)!=sign(ref_q): hsign+=1
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
                "final_cumulative_bottom_exchange_error_cm":ec[-1]
            }
            pooled_S+=es; pooled_C+=ec; pooled_Q+=eq; pooled_T+=et; pooled_U+=eu; pooled_L+=el
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN"; failure={"history":hist,"error":str(exc)}; failclass="OUTSIDE_QUALIFIED_DOMAIN"; break
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED"; failure={"history":hist,"error":str(exc)}; failclass="NUMERICAL_BLOCKED"; break

    pooled=None
    if status=="QUALIFIED":
        pooled={
            "total_storage_error_cm":qstats(pooled_S),
            "cumulative_bottom_exchange_error_cm":qstats(pooled_C),
            "terminal_bottom_flux_error_cm_per_day":qstats(pooled_Q),
            "mapped_R16_cell_theta_error":qstats(pooled_T),
            "upper_storage_error_cm":qstats(pooled_U),
            "lower_storage_error_cm":qstats(pooled_L),
            "bottom_flux_sign_error_count":signerr
        }
    return {
        "id":member["id"],"dimension":dim,"boundaries_cm":bounds,
        "status":status,"failure_class":failclass,"failure":failure,
        "max_abs_water_ledger_cm":maxledger,
        "max_corrector_iterations":maxiter,
        "pooled":pooled,"by_history":by_hist
    }

def r2_metrics(r2,r16):
    es=[]; ec=[]; eq=[]; et=[]; eu=[]; el=[]; signerr=0
    by={}
    for hist in HISTS:
        cum=0.0; rcum=0.0
        hes=[]; hec=[]; heq=[]; het=[]; heu=[]; hel=[]; hsign=0
        for step in range(1,NSTEPS+1):
            c=r2["states"][(hist,step)]; r=r16["states"][(hist,step)]
            cum+=float(c["BOTTOM_OUTWARD_EXCHANGE"]); rcum+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
            a=float(c["TOTAL_STORAGE"])-float(r["TOTAL_STORAGE"])
            b=cum-rcum
            cq=float(c["BOTTOM_FLUX"]); rq=float(r["BOTTOM_FLUX"]); q=cq-rq
            hes.append(a);hec.append(b);heq.append(q)
            if sign(rq)!=0 and sign(cq)!=sign(rq): hsign+=1
            t1=float(r2["nodes"][(hist,step,1)]["THETA"])
            t2=float(r2["nodes"][(hist,step,2)]["THETA"])
            mapped=[t1]*8+[t2]*8
            for node,t in enumerate(mapped,1):
                het.append(t-float(r16["nodes"][(hist,step,node)]["THETA"]))
            ru=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(1,9))
            rl=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(9,17))
            heu.append(t1*80.0-ru); hel.append(t2*80.0-rl)
        by[hist]={
            "total_storage_error_cm":qstats(hes),
            "cumulative_bottom_exchange_error_cm":qstats(hec),
            "terminal_bottom_flux_error_cm_per_day":qstats(heq),
            "mapped_R16_cell_theta_error":qstats(het),
            "upper_storage_error_cm":qstats(heu),
            "lower_storage_error_cm":qstats(hel),
            "bottom_flux_sign_error_count":hsign,
            "final_cumulative_bottom_exchange_error_cm":hec[-1]
        }
        es+=hes; ec+=hec; eq+=heq; et+=het; eu+=heu; el+=hel; signerr+=hsign
    return {
        "pooled":{
            "total_storage_error_cm":qstats(es),
            "cumulative_bottom_exchange_error_cm":qstats(ec),
            "terminal_bottom_flux_error_cm_per_day":qstats(eq),
            "mapped_R16_cell_theta_error":qstats(et),
            "upper_storage_error_cm":qstats(eu),
            "lower_storage_error_cm":qstats(el),
            "bottom_flux_sign_error_count":signerr
        },
        "by_history":by
    }

def crosses(member,comp,tol):
    if member["status"]!="QUALIFIED":
        return False
    a=member["pooled"]; b=comp
    return (
        a["total_storage_error_cm"]["rmse"] <= b["total_storage_error_cm"]["rmse"]+tol and
        a["cumulative_bottom_exchange_error_cm"]["rmse"] <= b["cumulative_bottom_exchange_error_cm"]["rmse"]+tol and
        a["terminal_bottom_flux_error_cm_per_day"]["rmse"] <= b["terminal_bottom_flux_error_cm_per_day"]["rmse"]+tol and
        a["mapped_R16_cell_theta_error"]["rmse"] <= b["mapped_R16_cell_theta_error"]["rmse"]+tol and
        a["bottom_flux_sign_error_count"] <= b["bottom_flux_sign_error_count"]
    )

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--d13-result",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--bc1-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--representation-reconciliation",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    bc1c=json.loads(args.bc1_closeout.read_text())
    rec=json.loads(args.representation_reconciliation.read_text())
    d13=json.loads(args.d13_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4P_BEFORE_MATCHED_D13_REPRESENTATION_DISCRIMINATOR"
    assert pre["pre_execution_domain_policy"]["before_first_C4Q_execution"] is True
    assert bc1c["decision"]==pre["authority"]["lare_required_boundary_decision"]
    assert rec["reconciliation_decision"]=="LARE_SCALAR_CLOSURE_SEARCH_PAUSED_COMPARE_AGAINST_COARSE_RICHARDS_AND_FMC_SMVE"
    assert d13["decision"]==pre["hard_gates"]["D13_raw_decision"]

    r16=parse_d13(args.r16); r2=parse_d13(args.r2)
    if r16["n"]!=16 or r2["n"]!=2:
        raise SystemExit("D13 geometry mismatch")

    r2cmp=r2_metrics(r2,r16)
    # Bind raw D13 R2 balance/flux identity where comparable.
    raw_r2=d13["R2_comparator"]
    for key in ("total_storage_error_cm","cumulative_bottom_exchange_error_cm","terminal_bottom_flux_error_cm_per_day"):
        if abs(r2cmp["pooled"][key]["rmse"]-raw_r2[key]["rmse"])>1e-12:
            raise SystemExit(f"R2 reconstruction mismatch {key}")
    if r2cmp["pooled"]["bottom_flux_sign_error_count"]!=raw_r2["bottom_flux_sign_error_count"]:
        raise SystemExit("R2 sign reconstruction mismatch")

    fmc={
      "total_storage_error_cm":d13["FMC"]["pooled"]["total_storage_error_cm"],
      "cumulative_bottom_exchange_error_cm":d13["FMC"]["pooled"]["cumulative_bottom_exchange_error_cm"],
      "terminal_bottom_flux_error_cm_per_day":d13["FMC"]["pooled"]["terminal_bottom_flux_error_cm_per_day"],
      "mapped_R16_cell_theta_error":d13["FMC"]["pooled"]["R16_cell_theta_error"],
      "bottom_flux_sign_error_count":d13["FMC"]["pooled"]["bottom_flux_sign_error_count"]
    }

    members=[run_member(m,r16) for m in pre["frozen_ladder"]]
    tol=float(pre["frontier_rules"]["numerical_equality_tolerance"])
    reduced=[m for m in members if m["dimension"]<16]
    for m in members:
        m["crosses_R2"]=crosses(m,r2cmp["pooled"],tol) if m["dimension"]<16 else False
        m["crosses_FMC"]=crosses(m,fmc,tol) if m["dimension"]<16 else False

    r16ctrl=next(m for m in members if m["id"]=="R16")
    all_attempted=len(members)==len(pre["frozen_ladder"])
    failopen=0
    qualified=[m for m in members if m["status"]=="QUALIFIED"]
    integrity=(
      all_attempted
      and r16ctrl["status"]=="QUALIFIED"
      and all(m["max_abs_water_ledger_cm"]<=float(pre["hard_gates"]["qualified_lare_member_max_abs_water_ledger_cm"]) for m in qualified)
      and failopen==0
    )
    qred=[m for m in reduced if m["status"]=="QUALIFIED"]
    cross_fmc=[m for m in qred if m["crosses_FMC"]]
    cross_r2=[m for m in qred if m["crosses_R2"]]

    if not integrity:
        decision="C4Q_DIAGNOSTIC_BLOCKED"
    elif not qred:
        decision="LARE_REDUCED_DOMAIN_NO_GO"
    elif cross_fmc:
        decision="LARE_REDUCED_FRONTIER_CROSSES_FMC"
    elif cross_r2:
        decision="LARE_REDUCED_FRONTIER_CROSSES_R2_NOT_FMC"
    else:
        decision="LARE_REDUCED_FRONTIER_DOES_NOT_CROSS_R2"

    out={
      "schema":"swap5.lare.bc2.c4q.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4Q",
      "decision":decision,
      "integrity":{
        "pass":integrity,
        "all_members_attempted":all_attempted,
        "R16_operator_control_status":r16ctrl["status"],
        "qualified_member_count":len(qualified),
        "qualified_reduced_member_count":len(qred),
        "fail_open_count":failopen,
        "maximum_qualified_water_ledger_cm":max([m["max_abs_water_ledger_cm"] for m in qualified] or [0.0])
      },
      "comparators":{
        "R2":r2cmp,
        "FMC_GW200":{"pooled":fmc,"source_decision":d13["decision"]}
      },
      "lare_members":members,
      "frontier":{
        "reduced_members_crossing_R2":[m["id"] for m in cross_r2],
        "reduced_members_crossing_FMC":[m["id"] for m in cross_fmc],
        "lowest_dimension_crossing_R2":None if not cross_r2 else min(m["dimension"] for m in cross_r2),
        "lowest_dimension_crossing_FMC":None if not cross_fmc else min(m["dimension"] for m in cross_fmc)
      },
      "interpretation":[
        "C4Q is an exposed matched-workload representation discriminator, not blind confirmation.",
        "Every frozen LARE resolution is attempted; fail-closed domain loss is reported rather than hidden.",
        "R16 LARE is an operator control and is excluded from reduced-frontier crossing.",
        "No single scalar score or application-acceptance threshold is used."
      ],
      "application_acceptance_adjudicated":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "integrity":out["integrity"],
      "frontier":out["frontier"],
      "R2":r2cmp["pooled"],
      "FMC":fmc,
      "LARE":{m["id"]:{
        "status":m["status"],
        "pooled":m["pooled"],
        "crosses_R2":m["crosses_R2"],
        "crosses_FMC":m["crosses_FMC"],
        "failure":m["failure"]
      } for m in members}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
