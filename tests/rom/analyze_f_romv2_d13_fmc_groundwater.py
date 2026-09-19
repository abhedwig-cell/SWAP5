#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
DEPTH=160.0; OBS_DT=0.001; NSUB=9; SUB_DT=OBS_DT/NSUB
DTHETA=(TS-TR)/NBINS; THETA_I=TR+I*DTHETA
HISTS={"G25":0.25,"G50":0.50,"G75":0.75,"G125":1.25}
NSTEPS=64; HARD_MASS=1e-12; RELAX_TOL=1e-14

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse(path):
    states={}; nodes={}; geom=None; initial={}
    for line in pathlib.Path(path).read_text().splitlines():
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
    expected={(h,s) for h in HISTS for s in range(1,NSTEPS+1)}
    if geom is None or set(states)!=expected:
        raise SystemExit(f"reference structure mismatch {path}")
    n=int(geom["N"])
    if set(initial)!=set(HISTS):
        raise SystemExit(f"initial mapping structure mismatch {path}")
    if len(nodes)!=len(expected)*n:
        raise SystemExit(f"node structure mismatch {path}")
    return {"n":n,"states":states,"nodes":nodes,"initial":initial}

def psi(theta):
    if not(TR<theta<TS): raise ValueError("theta domain")
    se=(theta-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def kval(theta):
    if not(TR<theta<TS): raise ValueError("theta domain")
    se=(theta-TR)/(TS-TR)
    k=KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K domain")
    return k

THETA=[TR+j*DTHETA for j in range(J0,J1+1)]
PSI=[psi(t) for t in THETA]
K=[kval(t) for t in THETA]
KI=kval(THETA_I)

def velocity(theta_j,psi_j,k_j,h):
    if not(math.isfinite(h) and h>0): raise ValueError("front height domain")
    v=(k_j-KI)/(theta_j-THETA_I)*(abs(psi_j)/h-1.0)
    if not math.isfinite(v): raise ValueError("nonfinite velocity")
    return v

def storage(h):
    return THETA_I*DEPTH + DTHETA*math.fsum(h)

def relax(raw):
    before=DTHETA*math.fsum(raw)
    out=sorted(raw,reverse=True)
    after=DTHETA*math.fsum(out)
    if abs(after-before)>RELAX_TOL:
        raise ValueError("relaxation storage drift")
    return out,abs(after-before)

def advance_substep(h):
    vel=[velocity(t,p,k,x) for t,p,k,x in zip(THETA,PSI,K,h)]
    raw=[x+SUB_DT*v for x,v in zip(h,vel)]
    if not all(math.isfinite(x) and 0.0<x<=DEPTH for x in raw):
        raise ValueError("front physical bounds")
    hn,relaxerr=relax(raw)
    s0=storage(h); s1=storage(hn)
    bex=-(s1-s0)
    mass=(s1-s0)+bex
    if abs(mass)>HARD_MASS:
        raise ValueError("substep mass gate")
    return hn,bex,mass,relaxerr

def qout_terminal(h):
    vel=[velocity(t,p,k,x) for t,p,k,x in zip(THETA,PSI,K,h)]
    return -DTHETA*math.fsum(vel)

def cell_averages(h,n):
    dz=DEPTH/n
    vals=[]
    ztop=0.0
    for _ in range(n):
        zbot=ztop+dz
        ylow=DEPTH-zbot; yhigh=DEPTH-ztop
        theta=THETA_I
        for hj in h:
            overlap=max(0.0,min(hj,yhigh)-max(0.0,ylow))
            theta += DTHETA*overlap/dz
        if not(TR<theta<TS): raise ValueError("cell theta bounds")
        vals.append(theta)
        ztop=zbot
    return vals

def sign(x): return 1 if x>0 else -1 if x<0 else 0

def qstats(v):
    if not v:return {"count":0}
    a=sorted(abs(x) for x in v)
    return {"count":len(v),"mean":sum(v)/len(v),"mean_abs":sum(abs(x) for x in v)/len(v),
            "rmse":math.sqrt(sum(x*x for x in v)/len(v)),
            "p95_abs":a[min(len(a)-1,math.ceil(.95*len(a))-1)],"max_abs":a[-1]}

def compare_r2(r2,r16):
    es=[]; ec=[]; eq=[]; signerr=0; cum={h:0.0 for h in HISTS}; rcum={h:0.0 for h in HISTS}
    for h in HISTS:
        for st in range(1,NSTEPS+1):
            c=r2["states"][(h,st)]; r=r16["states"][(h,st)]
            cum[h]+=float(c["BOTTOM_OUTWARD_EXCHANGE"]); rcum[h]+=float(r["BOTTOM_OUTWARD_EXCHANGE"])
            es.append(float(c["TOTAL_STORAGE"])-float(r["TOTAL_STORAGE"]))
            ec.append(cum[h]-rcum[h])
            cq=float(c["BOTTOM_FLUX"]); rq=float(r["BOTTOM_FLUX"]); eq.append(cq-rq)
            if sign(rq)!=0 and sign(cq)!=sign(rq): signerr+=1
    return {"total_storage_error_cm":qstats(es),"cumulative_bottom_exchange_error_cm":qstats(ec),
            "terminal_bottom_flux_error_cm_per_day":qstats(eq),"bottom_flux_sign_error_count":signerr}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True); ap.add_argument("--r2",required=True)
    ap.add_argument("--prereg",required=True); ap.add_argument("--preflight",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    pre=json.loads(pathlib.Path(a.preflight).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_FULL_ALGORITHM_PREFLIGHT"
    assert p["candidate"]["moisture_bins"]==NBINS
    assert p["time_integration"]["internal_substep_max_seconds"]==10
    assert pre["decision"]=="D13_FMC_GROUNDWATER_FRONT_PREFLIGHT_PASS"
    r16=parse(a.r16); r2=parse(a.r2)
    if r16["n"]!=16 or r2["n"]!=2: raise SystemExit("geometry mismatch")

    r2cmp=compare_r2(r2,r16)
    allS=[]; allC=[]; allQ=[]; allTheta=[]
    by={}; failure=None; maxmass=0.0; maxrelax=0.0; signerr=0
    for hist,lam in HISTS.items():
        h=[lam*x for x in PSI]
        theoretical=storage(h)
        for ref in (r16,r2):
            mapped=float(ref["initial"][hist]["TOTAL_STORAGE"])
            target=float(ref["initial"][hist]["TARGET_STORAGE"])
            if abs(mapped-theoretical)>1e-12 or abs(target-theoretical)>1e-12:
                raise SystemExit(f"initial storage identity mismatch {hist}")
        cum=0.0; rcum=0.0; es=[]; ec=[]; eq=[]; eth=[]; hsign=0
        for st in range(1,NSTEPS+1):
            obs_bex=0.0; obs_mass=0.0
            try:
                for _ in range(NSUB):
                    h,db,mass,relaxerr=advance_substep(h)
                    obs_bex+=db; obs_mass+=mass
                    maxmass=max(maxmass,abs(mass)); maxrelax=max(maxrelax,relaxerr)
                q=qout_terminal(h)
                s=storage(h)
                theta16=cell_averages(h,16)
            except Exception as exc:
                failure={"history":hist,"step":st,"error":str(exc)}
                break
            if abs(obs_mass)>HARD_MASS:
                failure={"history":hist,"step":st,"error":"observation mass gate","mass":obs_mass}; break
            rr=r16["states"][(hist,st)]
            cum+=obs_bex; rcum+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            eS=s-float(rr["TOTAL_STORAGE"]); eC=cum-rcum; eQ=q-float(rr["BOTTOM_FLUX"])
            es.append(eS); ec.append(eC); eq.append(eQ)
            rq=float(rr["BOTTOM_FLUX"])
            if sign(rq)!=0 and sign(q)!=sign(rq): hsign+=1
            for node,t in enumerate(theta16,1):
                eth.append(t-float(r16["nodes"][(hist,st,node)]["THETA"]))
        if failure: break
        signerr+=hsign
        by[hist]={
          "lambda":lam,
          "total_storage_error_cm":qstats(es),
          "cumulative_bottom_exchange_error_cm":qstats(ec),
          "terminal_bottom_flux_error_cm_per_day":qstats(eq),
          "R16_cell_theta_error":qstats(eth),
          "bottom_flux_sign_error_count":hsign,
          "final_cumulative_bottom_exchange_error_cm":ec[-1],
          "R16_final_cumulative_bottom_exchange_cm":rcum
        }
        allS+=es; allC+=ec; allQ+=eq; allTheta+=eth

    integrity=failure is None and len(by)==4
    pooled=None
    if integrity:
        pooled={"total_storage_error_cm":qstats(allS),
                "cumulative_bottom_exchange_error_cm":qstats(allC),
                "terminal_bottom_flux_error_cm_per_day":qstats(allQ),
                "R16_cell_theta_error":qstats(allTheta),
                "bottom_flux_sign_error_count":signerr}
    balance=transient=False
    if integrity:
        balance=(pooled["total_storage_error_cm"]["rmse"]<=r2cmp["total_storage_error_cm"]["rmse"]
                 and pooled["cumulative_bottom_exchange_error_cm"]["rmse"]<=r2cmp["cumulative_bottom_exchange_error_cm"]["rmse"])
        transient=(pooled["terminal_bottom_flux_error_cm_per_day"]["rmse"]<=r2cmp["terminal_bottom_flux_error_cm_per_day"]["rmse"]
                   and pooled["bottom_flux_sign_error_count"]<=r2cmp["bottom_flux_sign_error_count"])
    retained=integrity and (balance or transient)
    decision=("FMC_GW200_RETAINS_GROUNDWATER_BRANCH_RESEARCH_CANDIDACY" if retained
              else "FMC_GW200_GROUNDWATER_BRANCH_NOT_COMPETITIVE_OR_NOT_ROBUST")
    out={
      "schema":"swap5.f-romv2-d13.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D13",
      "decision":decision,
      "preflight_decision":pre["decision"],
      "candidate":{"id":"FMC_GW200","moisture_bins":NBINS,"active_groundwater_bins":len(THETA),
                   "baseline_effective_saturation":0.5,"internal_substeps_per_observation":NSUB,
                   "substep_seconds":SUB_DT*86400.0,"full_order_fallback_used":False},
      "integrity":{"pass":integrity,"failure":failure,
                   "max_abs_substep_mass_residual_cm":maxmass,
                   "max_abs_capillary_relaxation_storage_difference_cm":maxrelax,
                   "hard_mass_gate_cm":HARD_MASS},
      "FMC": {"pooled":pooled,"by_history":by},
      "R2_comparator":r2cmp,
      "frontier":{"balance_view_pass":balance,"transient_view_pass":transient,"retained":retained},
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"integrity":out["integrity"],"FMC_pooled":pooled,
                      "R2":r2cmp,"frontier":out["frontier"],"by_history":by},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
