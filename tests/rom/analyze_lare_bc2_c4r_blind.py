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
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

bc1=load_module("bc1_c4r","run_lare_bc1_stage_b.py")

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
HISTS={"V01":0.375,"V02":0.625,"V03":0.875,"V04":1.125}
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

def crosses_gw(member,comp,tol):
    if member["status"]!="QUALIFIED":
        return False
    a=member["pooled"]; b=comp
    return (
        a["total_storage_error_cm"]["rmse"] <= b["total_storage_error_cm"]["rmse"]+tol and
        a["cumulative_bottom_exchange_error_cm"]["rmse"] <= b["cumulative_bottom_exchange_error_cm"]["rmse"]+tol and
        a["terminal_bottom_flux_error_cm_per_day"]["rmse"] <= b["terminal_bottom_flux_error_cm_per_day"]["rmse"]+tol and
        a["bottom_flux_sign_error_count"] <= b["bottom_flux_sign_error_count"]
    )

def crosses_profile(member,comp,tol):
    return crosses_gw(member,comp,tol) and (
        member["pooled"]["mapped_R16_cell_theta_error"]["rmse"]
        <= comp["mapped_R16_cell_theta_error"]["rmse"]+tol
    )

def minimum_dimension(members,key):
    good=[m for m in members if m.get(key)]
    return None if not good else min(int(m["dimension"]) for m in good)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-result",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-reproduction",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--bc1-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--representation-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--corichards-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    bc1c=json.loads(args.bc1_closeout.read_text())
    repsel=json.loads(args.representation_closeout.read_text())
    q1=json.loads(args.corichards_closeout.read_text())
    fmc_result=json.loads(args.fmc_result.read_text())
    repro=json.loads(args.fmc_reproduction.read_text())

    assert pre["phase"]=="PREREGISTERED_BEFORE_NEW_BLIND_FIXED_WATER_TABLE_VALIDATION"
    assert pre["pre_execution_implementation_binding"]["before_any_C4R_reference_generation"] is True
    assert bc1c["decision"]=="FIXED_DOMAIN_PRESCRIBED_HEAD_CLOSURE_QUALIFIED_WITH_RESOLUTION_DEPENDENCE"
    assert repsel["decision"]=="PREREGISTER_NEW_BLIND_D13_CLASS_VALIDATION_BEFORE_VALUE_MEASUREMENT"
    assert q1["decision"]=="ONLY_FINE_CORICHARDS_DYNAMIC_VIABLE"
    assert q1["Q2_authorized"] is False
    assert repro["pass"] is True
    assert fmc_result["integrity"]["pass"] is True

    r16=parse_d13(args.r16); r2=parse_d13(args.r2)
    if r16["n"]!=16 or r2["n"]!=2:
        raise SystemExit("C4R geometry mismatch")

    # Exact blind-history binding against preregistered lambdas.
    expected_lambdas={k:float(v["lambda"]) for k,v in pre["blind_initial_state_design"]["validation_histories"].items()}
    for h,lam in expected_lambdas.items():
        for ref in (r16,r2):
            if abs(float(ref["initial"][h]["LAMBDA"])-lam)>0.0:
                raise SystemExit(f"C4R lambda drift {h}")

    r2cmp=r2_metrics(r2,r16)
    raw_r2=fmc_result["R2_comparator"]
    for key in ("total_storage_error_cm","cumulative_bottom_exchange_error_cm","terminal_bottom_flux_error_cm_per_day"):
        if abs(r2cmp["pooled"][key]["rmse"]-raw_r2[key]["rmse"])>1e-12:
            raise SystemExit(f"C4R R2 reconstruction mismatch {key}")
    if r2cmp["pooled"]["bottom_flux_sign_error_count"]!=raw_r2["bottom_flux_sign_error_count"]:
        raise SystemExit("C4R R2 sign reconstruction mismatch")

    fmc={
      "total_storage_error_cm":fmc_result["FMC"]["pooled"]["total_storage_error_cm"],
      "cumulative_bottom_exchange_error_cm":fmc_result["FMC"]["pooled"]["cumulative_bottom_exchange_error_cm"],
      "terminal_bottom_flux_error_cm_per_day":fmc_result["FMC"]["pooled"]["terminal_bottom_flux_error_cm_per_day"],
      "mapped_R16_cell_theta_error":fmc_result["FMC"]["pooled"]["R16_cell_theta_error"],
      "bottom_flux_sign_error_count":fmc_result["FMC"]["pooled"]["bottom_flux_sign_error_count"]
    }

    members=[run_member(m,r16) for m in pre["representations"]["LARE"]["frozen_ladder"]]
    tol=float(pre["comparator_relative_frontiers"]["numerical_equality_tolerance"])
    for m in members:
        reduced=int(m["dimension"])<16
        m["crosses_R2_GW"]=reduced and crosses_gw(m,r2cmp["pooled"],tol)
        m["crosses_FMC_GW"]=reduced and crosses_gw(m,fmc,tol)
        m["crosses_R2_PROFILE"]=reduced and crosses_profile(m,r2cmp["pooled"],tol)
        m["crosses_FMC_PROFILE"]=reduced and crosses_profile(m,fmc,tol)

    r16ctrl=next(m for m in members if m["id"]=="R16")
    qualified=[m for m in members if m["status"]=="QUALIFIED"]
    reduced=[m for m in members if int(m["dimension"])<16]
    qred=[m for m in reduced if m["status"]=="QUALIFIED"]
    integrity=(
      len(members)==len(pre["representations"]["LARE"]["frozen_ladder"])
      and r16ctrl["status"]=="QUALIFIED"
      and all(m["max_abs_water_ledger_cm"]<=float(pre["integrity_gates"]["lare_qualified_member_max_abs_water_ledger_cm"]) for m in qualified)
    )

    mins={
      "R2_GW":minimum_dimension(qred,"crosses_R2_GW"),
      "FMC_GW":minimum_dimension(qred,"crosses_FMC_GW"),
      "R2_PROFILE":minimum_dimension(qred,"crosses_R2_PROFILE"),
      "FMC_PROFILE":minimum_dimension(qred,"crosses_FMC_PROFILE")
    }
    dev_replication={
      "H_GW_DIMENSION_SEPARATION_exact":mins["R2_GW"]==4 and mins["FMC_GW"]==4,
      "H_PROFILE_DIMENSION_SEPARATION_exact":mins["R2_PROFILE"]==4 and mins["FMC_PROFILE"]==12
    }

    if not integrity:
        decision="C4R_REFERENCE_OR_EXECUTION_BLOCKED"
    elif mins["FMC_PROFILE"] is not None and mins["R2_PROFILE"] is not None:
        decision="C4R_BLIND_PROFILE_FRONTIER_REPLICATED"
    elif mins["FMC_GW"] is not None and mins["R2_GW"] is not None:
        decision="C4R_BLIND_GW_FRONTIER_ONLY"
    elif mins["R2_GW"] is not None:
        decision="C4R_BLIND_R2_FRONTIER_ONLY"
    else:
        decision="C4R_BLIND_REDUCED_FRONTIER_NOT_REPLICATED"

    out={
      "schema":"swap5.lare.bc2.c4r.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4R",
      "decision":decision,
      "blind_validation":True,
      "reference":{
        "canonical_head":pre["reference_authority"]["current_canonical_at_preregistration"],
        "histories":expected_lambdas,
        "R16_node_count":r16["n"],
        "R2_node_count":r2["n"]
      },
      "integrity":{
        "pass":integrity,
        "fmc_D13_reproduction_pass":repro["pass"],
        "R16_operator_control_status":r16ctrl["status"],
        "qualified_member_count":len(qualified),
        "qualified_reduced_member_count":len(qred),
        "maximum_qualified_water_ledger_cm":max([m["max_abs_water_ledger_cm"] for m in qualified] or [0.0])
      },
      "comparators":{
        "R2":{"pooled":r2cmp["pooled"],"by_history":r2cmp["by_history"]},
        "FMC_GW200":{"pooled":fmc,"by_history":fmc_result["FMC"]["by_history"],
                     "source_decision":fmc_result["decision"]}
      },
      "lare_members":members,
      "frontiers":{
        "minimum_dimension":mins,
        "crossing_members":{
          key:[m["id"] for m in qred if m.get("crosses_"+key)]
          for key in ("R2_GW","FMC_GW","R2_PROFILE","FMC_PROFILE")
        }
      },
      "development_hypothesis_replication":dev_replication,
      "interpretation":[
        "C4R is blind with respect to the newly generated Reference trajectories; histories and representations were frozen before generation.",
        "GW and PROFILE comparator-relative frontiers are reported separately under the already-frozen purpose framework.",
        "Comparator-relative crossing is not application acceptance and no absolute tolerance is inferred from these errors.",
        "No computational-value or speed claim is adjudicated here."
      ],
      "application_acceptance_adjudicated":False,
      "performance_comparison_authorized":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "integrity":out["integrity"],
      "frontiers":out["frontiers"],
      "development_hypothesis_replication":dev_replication,
      "R2":r2cmp["pooled"],
      "FMC":fmc,
      "LARE":{m["id"]:{
        "status":m["status"],"pooled":m["pooled"],
        "crosses_R2_GW":m["crosses_R2_GW"],
        "crosses_FMC_GW":m["crosses_FMC_GW"],
        "crosses_R2_PROFILE":m["crosses_R2_PROFILE"],
        "crosses_FMC_PROFILE":m["crosses_FMC_PROFILE"],
        "failure":m["failure"]
      } for m in members}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
