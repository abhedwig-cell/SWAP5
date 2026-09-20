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
NSTEPS=1024
DT=0.0001
SUBSTEPS=10
DTHETA=(TS-TR)/NBINS
THETA_I=TR+I*DTHETA
HISTS={"V01":0.375,"V02":0.625,"V03":0.875,"V04":1.125}
CHECKPOINTS=(64,128,256,512,1024)
PROSPECTIVE=(128,256,512,1024)
LEDGER_GATE=1e-10
GW4=("storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day","bottom_flux_sign_errors")
GW6=GW4+("abs_mean_signed_bottom_flux_error_cm_per_day","max_abs_final_cumulative_bottom_error_cm")

def load_path(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

bc1=load_path("bc1_c4v",HERE/"run_lare_bc1_stage_b.py")

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1)
            out[k]=v
    return out

def parse_ref(path):
    states={};nodes={};initial={};geom=None
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        if "F_ROMV2_D13_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D13_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D13_REF_INITIAL|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_INITIAL|",1)[1]);initial[r["HISTORY"].strip()]=r
        elif "F_ROMV2_D13_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_STATE|",1)[1]);states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D13_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_NODE|",1)[1]);nodes[(r["HISTORY"].strip(),int(r["STEP"]),int(r["NODE"]))]=r
    if geom is None:
        raise RuntimeError("missing reference geometry")
    n=int(geom["N"])
    expected={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if set(states)!=expected or set(initial)!=set(HISTS) or len(nodes)!=len(expected)*n:
        raise RuntimeError("reference structure mismatch")
    return {"n":n,"states":states,"nodes":nodes,"initial":initial}

def psi_scalar(theta):
    se=(theta-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

THETA=[TR+j*DTHETA for j in range(J0,J1+1)]
PSI=[psi_scalar(t) for t in THETA]

def exact_initial_profile(lam):
    return [lam*x for x in PSI]

def layer_mean_theta_from_fronts(h,zlo,zhi):
    dz=zhi-zlo;ylow=DEPTH-zhi;yhigh=DEPTH-zlo
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
    return dz,y

def qbottom_zero_head(theta,dz):
    psi,k=bc1.psi_k(theta)
    grad=1.0+2.0*(0.0-float(psi[-1]))/float(dz[-1])
    q=float(k[-1])*grad
    if not math.isfinite(q):
        raise FloatingPointError("nonfinite qbottom")
    return q

def rhs(y,dz):
    n=len(dz);theta=y[:n]/dz
    qint=bc1.interface_fluxes(theta,dz)
    qb=qbottom_zero_head(theta,dz)
    dy=np.zeros_like(y)
    for i in range(n):
        qup=0.0 if i==0 else qint[i-1]
        qdn=qb if i==n-1 else qint[i]
        dy[i]=qup-qdn
    dy[n]=0.0;dy[n+1]=qb
    return dy

def heun_step(y,dt,dz):
    f0=rhs(y,dz);guess=y+dt*f0;n=len(dz)
    for it in range(1,bc1.HEUN_MAX_CORRECTOR+1):
        nxt=y+0.5*dt*(f0+rhs(guess,dz))
        if np.max(np.abs(nxt[:n]/dz-guess[:n]/dz))<=bc1.HEUN_CORRECTOR_TOL_THETA:
            return nxt,it
        guess=nxt
    raise RuntimeError("iterative Heun corrector did not converge")

def map_piecewise_to_10cm(theta,bounds):
    out=[]
    for node in range(1,17):
        lo=(node-1)*10.0;hi=node*10.0;total=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0: total+=float(t)*w
        out.append(total/10.0)
    return out

def integrated_storage(theta,bounds,lo,hi):
    total=0.0
    for t,a,b in zip(theta,bounds,bounds[1:]):
        w=max(0.0,min(hi,b)-max(lo,a))
        if w>0.0: total+=float(t)*w
    return total

def sign(x):
    return 1 if x>0 else -1 if x<0 else 0

def qstats(v):
    a=np.asarray(v,dtype=float)
    aa=np.abs(a)
    return {
      "count":int(len(a)),
      "mean":float(np.mean(a)),
      "mean_abs":float(np.mean(aa)),
      "rmse":float(np.sqrt(np.mean(a*a))),
      "p95_abs":float(np.percentile(aa,95)),
      "max_abs":float(np.max(aa))
    }

def ref_arrays(r16,hist):
    cum=[];x=0.0
    for step in range(1,NSTEPS+1):
        x+=float(r16["states"][(hist,step)]["BOTTOM_OUTWARD_EXCHANGE"])
        cum.append(x)
    return cum

def empty_series():
    return {h:{"S":[],"C":[],"Q":[],"signerr":[],"theta":[],"upper":[],"lower":[],"cand_sign":[],"ref_sign":[]} for h in HISTS}

def append_errors(series,hist,step,total,cum,q,mapped,upper,lower,r16,refcum):
    rr=r16["states"][(hist,step)]
    ref_total=float(rr["TOTAL_STORAGE"]);ref_q=float(rr["BOTTOM_FLUX"])
    series[hist]["S"].append(total-ref_total)
    series[hist]["C"].append(cum-refcum[step-1])
    series[hist]["Q"].append(q-ref_q)
    series[hist]["signerr"].append(1 if sign(ref_q)!=0 and sign(q)!=sign(ref_q) else 0)
    series[hist]["cand_sign"].append(sign(q));series[hist]["ref_sign"].append(sign(ref_q))
    for node,t in enumerate(mapped,1):
        series[hist]["theta"].append(float(t)-float(r16["nodes"][(hist,step,node)]["THETA"]))
    ru=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(1,9))
    rl=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(9,17))
    series[hist]["upper"].append(upper-ru);series[hist]["lower"].append(lower-rl)

def run_lare(member,r16):
    bounds=[float(x) for x in member["boundaries_cm"]];dim=int(member["dimension"])
    series=empty_series();status="QUALIFIED";failure=None;maxledger=0.0;maxiter=0
    for hist,lam in HISTS.items():
        try:
            dz,y=initial_state(lam,bounds);initial=float(np.sum(y[:dim]))
            if abs(initial-float(r16["initial"][hist]["TOTAL_STORAGE"]))>1e-12:
                raise RuntimeError("initial storage identity mismatch")
            refcum=ref_arrays(r16,hist)
            for step in range(1,NSTEPS+1):
                for _ in range(SUBSTEPS):
                    y,it=heun_step(y,DT,dz);maxiter=max(maxiter,it)
                theta=y[:dim]/dz;bc1.psi_k(theta)
                total=float(np.sum(y[:dim]));cum=float(y[dim+1]);q=qbottom_zero_head(theta,dz)
                ledger=total-initial+cum;maxledger=max(maxledger,abs(ledger))
                if abs(ledger)>LEDGER_GATE: raise RuntimeError(f"water ledger gate {ledger}")
                mapped=map_piecewise_to_10cm(theta,bounds)
                upper=integrated_storage(theta,bounds,0.0,80.0);lower=integrated_storage(theta,bounds,80.0,160.0)
                append_errors(series,hist,step,total,cum,q,mapped,upper,lower,r16,refcum)
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN";failure={"history":hist,"error":str(exc)};break
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED";failure={"history":hist,"error":str(exc)};break
    return {"id":member["id"],"dimension":dim,"status":status,"failure":failure,
            "max_abs_water_ledger_cm":maxledger,"max_corrector_iterations":maxiter,"series":series}

def run_r2(r2,r16):
    series=empty_series()
    for hist in HISTS:
        cum=0.0;refcum=ref_arrays(r16,hist)
        for step in range(1,NSTEPS+1):
            c=r2["states"][(hist,step)]
            cum+=float(c["BOTTOM_OUTWARD_EXCHANGE"])
            total=float(c["TOTAL_STORAGE"]);q=float(c["BOTTOM_FLUX"])
            t1=float(r2["nodes"][(hist,step,1)]["THETA"]);t2=float(r2["nodes"][(hist,step,2)]["THETA"])
            mapped=[t1]*8+[t2]*8
            append_errors(series,hist,step,total,cum,q,mapped,t1*80.0,t2*80.0,r16,refcum)
    return {"id":"R2","dimension":2,"status":"QUALIFIED","failure":None,"series":series}

def run_fmc(mod,r16):
    series=empty_series();maxmass=0.0;maxrelax=0.0
    for hist,lam in HISTS.items():
        if hist not in mod.HISTS or float(mod.HISTS[hist])!=lam:
            raise RuntimeError("FMC history binding mismatch")
        h=[lam*x for x in mod.PSI];cum=0.0;refcum=ref_arrays(r16,hist)
        if abs(float(mod.storage(h))-float(r16["initial"][hist]["TOTAL_STORAGE"]))>1e-12:
            raise RuntimeError("FMC initial storage identity mismatch")
        for step in range(1,NSTEPS+1):
            obs=0.0
            for _ in range(mod.NSUB):
                h,db,mass,relax=mod.advance_substep(h)
                obs+=db;maxmass=max(maxmass,abs(mass));maxrelax=max(maxrelax,abs(relax))
            cum+=obs;q=float(mod.qout_terminal(h));total=float(mod.storage(h));mapped=mod.cell_averages(h,16)
            upper=sum(mapped[:8])*10.0;lower=sum(mapped[8:])*10.0
            append_errors(series,hist,step,total,cum,q,mapped,upper,lower,r16,refcum)
    return {"id":"FMC","status":"QUALIFIED","failure":None,
            "max_abs_substep_mass_residual_cm":maxmass,
            "max_abs_relaxation_storage_difference_cm":maxrelax,"series":series}

def reversal_steps(signs):
    out=[];prev=0
    for i,s in enumerate(signs,1):
        if s==0: continue
        if prev!=0 and s!=prev: out.append(i)
        prev=s
    return out

def checkpoint(series,cp):
    S=[];C=[];Q=[];T=[];U=[];L=[];signerrors=0;finals=[];by={}
    for h in HISTS:
        z=series[h]
        S+=z["S"][:cp];C+=z["C"][:cp];Q+=z["Q"][:cp];T+=z["theta"][:cp*16];U+=z["upper"][:cp];L+=z["lower"][:cp]
        signerrors+=sum(z["signerr"][:cp]);finals.append(z["C"][cp-1])
        by[h]={
          "storage_rmse_cm":qstats(z["S"][:cp])["rmse"],
          "cumulative_bottom_rmse_cm":qstats(z["C"][:cp])["rmse"],
          "bottom_flux_rmse_cm_per_day":qstats(z["Q"][:cp])["rmse"],
          "bottom_flux_sign_errors":sum(z["signerr"][:cp]),
          "abs_mean_signed_bottom_flux_error_cm_per_day":abs(qstats(z["Q"][:cp])["mean"]),
          "abs_final_cumulative_bottom_error_cm":abs(z["C"][cp-1]),
          "mapped_theta_rmse":qstats(z["theta"][:cp*16])["rmse"],
          "reference_reversal_steps":reversal_steps(z["ref_sign"][:cp]),
          "candidate_reversal_steps":reversal_steps(z["cand_sign"][:cp])
        }
    return {
      "storage_rmse_cm":qstats(S)["rmse"],
      "cumulative_bottom_rmse_cm":qstats(C)["rmse"],
      "bottom_flux_rmse_cm_per_day":qstats(Q)["rmse"],
      "bottom_flux_sign_errors":int(signerrors),
      "abs_mean_signed_bottom_flux_error_cm_per_day":abs(qstats(Q)["mean"]),
      "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
      "mapped_theta_rmse":qstats(T)["rmse"],
      "upper_storage_rmse_cm":qstats(U)["rmse"],
      "lower_storage_rmse_cm":qstats(L)["rmse"],
      "by_history":by
    }

def summarize(route):
    return {str(cp):checkpoint(route["series"],cp) for cp in CHECKPOINTS}

def no_worse(a,b,keys,tol=1e-12):
    for k in keys:
        if k=="bottom_flux_sign_errors":
            if int(a[k])>int(b[k]): return False
        elif float(a[k])>float(b[k])+tol:
            return False
    return True

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-module",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-reproduction",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-preflight",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--bc1-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4r-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4u-authority",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text());bc1c=json.loads(a.bc1_closeout.read_text())
    c4r=json.loads(a.c4r_closeout.read_text());c4u=json.loads(a.c4u_authority.read_text())
    repro=json.loads(a.fmc_reproduction.read_text());preflight=json.loads(a.fmc_preflight.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_ONE_DAY_RESPONSE_EXPOSURE"
    assert p["hard_gates"]["FMC_one_day_pre_reference_domain_preflight"] is True
    assert bc1c["decision"]=="FIXED_DOMAIN_PRESCRIBED_HEAD_CLOSURE_QUALIFIED_WITH_RESOLUTION_DEPENDENCE"
    assert c4r["decision"]=="C4R_BLIND_PROFILE_FRONTIER_REPLICATED"
    assert c4u["decision"]=="GW_APPLICATION_ACCEPTANCE_NOT_ADJUDICABLE_FROM_CURRENT_REPOSITORY_AUTHORITY"
    assert repro["pass"] is True and preflight["pass"] is True

    r16=parse_ref(a.r16);r2=parse_ref(a.r2)
    if r16["n"]!=16 or r2["n"]!=2: raise SystemExit("geometry mismatch")
    fmcmod=load_path("c4v_fmc_frozen",a.fmc_module)
    if int(fmcmod.NSTEPS)!=NSTEPS: raise SystemExit("FMC NSTEPS mismatch")

    r2route=run_r2(r2,r16);fmcroute=run_fmc(fmcmod,r16)
    members=[run_lare(m,r16) for m in p["representations"]["LARE"]["full_frozen_ladder"]]
    summaries={"R2":summarize(r2route),"FMC":summarize(fmcroute)}
    for m in members:
        if m["status"]=="QUALIFIED": summaries["LARE_"+m["id"]]=summarize(m)

    r16ctrl=next(m for m in members if m["id"]=="R16")
    integrity=(r16ctrl["status"]=="QUALIFIED"
               and len(members)==len(p["representations"]["LARE"]["full_frozen_ladder"])
               and all(m["status"]!="QUALIFIED" or m["max_abs_water_ledger_cm"]<=float(p["hard_gates"]["LARE_qualified_member_max_abs_water_ledger_cm"]) for m in members))
    reduced=[m for m in members if m["dimension"]<16 and m["status"]=="QUALIFIED"]

    # Exposed prefix ordering uses only original C4R four-component vector.
    prefix={}
    for m in reduced:
        key="LARE_"+m["id"];v=summaries[key]["64"]
        prefix[m["id"]]={
          "crosses_R2_C4R_GW4":no_worse(v,summaries["R2"]["64"],GW4),
          "crosses_FMC_C4R_GW4":no_worse(v,summaries["FMC"]["64"],GW4)
        }
    prefix_r2=[m["id"] for m in reduced if prefix[m["id"]]["crosses_R2_C4R_GW4"]]
    prefix_fmc=[m["id"] for m in reduced if prefix[m["id"]]["crosses_FMC_C4R_GW4"]]
    prefix_min_r2=min([m["dimension"] for m in reduced if prefix[m["id"]]["crosses_R2_C4R_GW4"]],default=None)
    prefix_min_fmc=min([m["dimension"] for m in reduced if prefix[m["id"]]["crosses_FMC_C4R_GW4"]],default=None)
    expected_r2=list(c4r["frontiers"]["crossing_members"]["R2_GW"])
    expected_fmc=list(c4r["frontiers"]["crossing_members"]["FMC_GW"])
    prefix_ordering_pass=(prefix_r2==expected_r2 and prefix_fmc==expected_fmc)

    persistent={}
    for m in reduced:
        key="LARE_"+m["id"]
        cross_r2={str(cp):no_worse(summaries[key][str(cp)],summaries["R2"][str(cp)],GW6) for cp in PROSPECTIVE}
        cross_fmc={str(cp):no_worse(summaries[key][str(cp)],summaries["FMC"][str(cp)],GW6) for cp in PROSPECTIVE}
        persistent[m["id"]]={
          "R2_by_checkpoint":cross_r2,"FMC_by_checkpoint":cross_fmc,
          "crosses_R2_all_prospective":all(cross_r2.values()),
          "crosses_FMC_all_prospective":all(cross_fmc.values()),
          "crosses_both_all_prospective":all(cross_r2.values()) and all(cross_fmc.values())
        }
    both=[m for m in reduced if persistent[m["id"]]["crosses_both_all_prospective"]]
    r2only=[m for m in reduced if persistent[m["id"]]["crosses_R2_all_prospective"]]
    fmconly=[m for m in reduced if persistent[m["id"]]["crosses_FMC_all_prospective"]]

    if not integrity or not prefix_ordering_pass:
        decision="C4V_REFERENCE_OR_REPRESENTATION_DOMAIN_BLOCKED"
    elif persistent.get("R4",{}).get("crosses_both_all_prospective",False):
        decision="C4V_R4_ONE_DAY_GW_FRONTIER_PERSISTS"
    elif any(m["id"] in ("R5","R6","R8","R12") for m in both):
        decision="C4V_HIGHER_DIMENSION_GW_FRONTIER_PERSISTS"
    elif r2only and not fmconly:
        decision="C4V_ONLY_R2_RELATIVE_GW_FRONTIER_PERSISTS"
    elif not r2only:
        decision="C4V_ONE_DAY_REDUCED_GW_FRONTIER_NOT_PRESERVED"
    else:
        decision="C4V_REFERENCE_OR_REPRESENTATION_DOMAIN_BLOCKED"

    out={
      "schema":"swap5.lare.bc2.c4v.result.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4V",
      "decision":decision,
      "integrity":{
        "pass":integrity and prefix_ordering_pass,
        "fmc_D13_reproduction_pass":repro["pass"],
        "fmc_one_day_pre_reference_preflight_pass":preflight["pass"],
        "R16_operator_control_status":r16ctrl["status"],
        "prefix_C4R_ordering_pass":prefix_ordering_pass,
        "prefix_min_dimension_crossing_R2":prefix_min_r2,
        "prefix_min_dimension_crossing_FMC":prefix_min_fmc,
        "prefix_crossing_R2":prefix_r2,
        "prefix_crossing_FMC":prefix_fmc,
        "expected_C4R_crossing_R2":expected_r2,
        "expected_C4R_crossing_FMC":expected_fmc,
        "maximum_qualified_lare_water_ledger_cm":max([m["max_abs_water_ledger_cm"] for m in members if m["status"]=="QUALIFIED"] or [0.0])
      },
      "checkpoints_day":{str(cp):cp*OBS_DT for cp in CHECKPOINTS},
      "summaries":summaries,
      "lare_member_status":[{k:m[k] for k in ("id","dimension","status","failure","max_abs_water_ledger_cm","max_corrector_iterations")} for m in members],
      "prefix_C4R_GW4_crossing":prefix,
      "prospective_persistence":persistent,
      "persistent_crossing":{
        "both_comparators":[m["id"] for m in both],
        "R2":[m["id"] for m in r2only],
        "FMC":[m["id"] for m in fmconly],
        "minimum_both_dimension":min([m["dimension"] for m in both],default=None)
      },
      "hypotheses":{
        "H_GW_R4_PERSISTS":persistent.get("R4",{}).get("crosses_both_all_prospective",False),
        "H_ACTIVE_LOWER_ZONE_PERSISTS":"DESCRIPTIVE_ONLY_NO_TOLERANCE",
        "H_NO_LONG_HORIZON_BIAS_REVERSAL":"REPORT_ONLY"
      },
      "interpretation":[
        "C4V extends the previously blind C4R fixed-water-table laboratory response prospectively beyond 0.064 day to 1.024 day.",
        "Persistent crossing is componentwise over the six preregistered groundwater-horizon components at every prospective checkpoint.",
        "Comparator-relative persistence is not application acceptance; the external H_app/A_temporal blocker remains.",
        "The fixed zero-head boundary is laboratory semantics and is not coupled-groundwater application authority.",
        "No timing, speedup or production-ROM decision is made."
      ],
      "application_acceptance_adjudicated":False,
      "performance_comparison_authorized":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "integrity":out["integrity"],
      "persistent_crossing":out["persistent_crossing"],
      "R4":persistent.get("R4"),
      "checkpoint1024":{
        "R2":summaries["R2"]["1024"],
        "FMC":summaries["FMC"]["1024"],
        **{k:summaries[k]["1024"] for k in summaries if k.startswith("LARE_")}
      }
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
