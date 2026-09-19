#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1.0e-14
PONDMAX=KS*DT; RSRO=0.001
HISTS={"R05":0.5,"R20":2.0,"R40":4.0}
STORM=16; NSTEPS=64

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    if t<=TR:return 0.0
    if t>=TS:return KS
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

TI=theta(I); TD=theta(J1); KI=kval(TI); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def initial_fronts():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def storage(fronts,slugs):
    if fronts is not None:
        return TI*DEPTH+DTH*math.fsum(fronts.values())
    return TI*DEPTH+DTH*math.fsum(length for _,length in slugs.values())

def relax(fronts):
    keys=sorted(fronts); vals=sorted((fronts[j] for j in keys),reverse=True)
    before=DTH*math.fsum(fronts.values())
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    if abs(after-before)>TOL: raise ValueError("relaxation mass drift")
    return out

def slug_velocity(j):
    return (kval(theta(j))-kval(theta(j-1)))/(theta(j)-theta(j-1))

def surface_route(residual):
    if residual<=PONDMAX:
        return residual,0.0
    ratio=DT/RSRO
    store=(residual+ratio*PONDMAX)/(1.0+ratio)
    runoff=residual-store
    return store,runoff

def connected_step(fronts,available):
    before=storage(fronts,None)
    rem=available; out=dict(fronts); infiltrated=0.0
    for j in range(J0,J1+1):
        z=fronts[j]
        raw=z+ADV*(1.0+GEFF/z)*DT
        if not(math.isfinite(raw) and 0.0<raw<DEPTH):
            raise ValueError(f"front bounds j={j} raw={raw}")
        demand=max(0.0,DTH*(raw-z))
        take=min(rem,demand)
        if take>0.0:
            out[j]=z+take/DTH; rem-=take; infiltrated+=take
        if take<demand-1.0e-18 or rem<=1.0e-18: break
    out=relax(out)
    after=storage(out,None)
    if abs((after-before)-infiltrated)>1e-12:
        raise ValueError("connected storage/infiltration ledger")
    store,runoff=surface_route(max(0.0,rem))
    return out,infiltrated,store,runoff

def run_hist(factor):
    fronts=initial_fronts(); slugs=None; surf=0.0; cum_runoff=0.0
    s0=storage(fronts,None); max_step=0.0; detached_step=None; rows=[]
    for step in range(1,NSTEPS+1):
        rain=(factor*KS*DT) if step<=STORM else 0.0
        before=storage(fronts,slugs)
        prev_surf=surf
        infil=runoff=0.0
        if fronts is not None:
            fronts,infil,surf,runoff=connected_step(fronts,prev_surf+rain)
            after=storage(fronts,None)
            # Freeze D23 transition: detach at end of the first zero-rain,
            # zero-store interval; translation begins next interval.
            if step>STORM and surf<=TOL:
                slugs={j:[0.0,z] for j,z in fronts.items()}
                fronts=None; detached_step=step if detached_step is None else detached_step
        else:
            if rain>TOL or prev_surf>TOL:
                raise ValueError("surface water after detachment")
            for j,(top,length) in list(slugs.items()):
                move=slug_velocity(j)*DT
                nt=top+move; nb=nt+length
                if not(math.isfinite(nt) and math.isfinite(nb) and 0.0<=nt<nb<DEPTH):
                    raise ValueError(f"slug bounds j={j}")
                slugs[j]=[nt,length]
            after=storage(None,slugs); surf=0.0; runoff=0.0; infil=0.0
        cum_runoff+=runoff
        ledger=(after-before)+surf+cumulative_zero if False else None
        step_ledger=prev_surf+rain-infil-surf-runoff
        if fronts is None and infil==0.0 and rain==0.0 and prev_surf==0.0:
            step_ledger=0.0
        if abs(step_ledger)>1e-12:
            raise ValueError(f"surface ledger step={step} res={step_ledger}")
        total_ledger=(after-before)+surf-prev_surf+runoff-rain
        if abs(total_ledger)>1e-12:
            raise ValueError(f"global step ledger step={step} res={total_ledger}")
        max_step=max(max_step,abs(total_ledger),abs(step_ledger))
        rows.append({"step":step,"rain_cm":rain,"infiltration_cm":infil,"surface_store_cm":surf,
                     "runoff_cm":runoff,"cumulative_runoff_cm":cum_runoff,
                     "soil_storage_cm":after,"surface_ledger_residual_cm":step_ledger,
                     "global_ledger_residual_cm":total_ledger,
                     "phase":"STORM" if step<=STORM else "HIATUS",
                     "state":"CONNECTED" if fronts is not None else "SLUGS"})
    sf=storage(fronts,slugs)
    rainfall=STORM*factor*KS*DT
    global_res=s0+rainfall-(sf+surf+cum_runoff)
    return {"pass":abs(global_res)<=1e-12 and max_step<=1e-12,
            "factor":factor,"initial_soil_storage_cm":s0,"final_soil_storage_cm":sf,
            "final_surface_store_cm":surf,"cumulative_runoff_cm":cum_runoff,
            "rainfall_cm":rainfall,"global_ledger_residual_cm":global_res,
            "max_abs_step_ledger_residual_cm":max_step,"detached_step":detached_step,
            "rows":rows}

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--prereg",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args();p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_FMC_INTERNAL_PREFLIGHT_AND_RICHARDS_TRAJECTORY_EXECUTION"
    assert p["temporal_contract"]["storm_steps"]==STORM and p["temporal_contract"]["total_steps"]==NSTEPS
    assert p["surface_parameters"]["ponding_max_cm"]==PONDMAX
    assert "NO_POST_PREFLIGHT_DETACHMENT_RULE_RETUNING" in p["firewalls"]
    rows={}
    try:
        for h,f in HISTS.items(): rows[h]=run_hist(f)
        passed=all(v["pass"] for v in rows.values())
        failure=None
    except Exception as exc:
        passed=False; failure=str(exc)
    out={"schema":"swap5.f-romv2-d23.fmc-preflight.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D23",
         "decision":"D23_FMC_SHORT_RAINFALL_INTERNAL_PREFLIGHT_PASS" if passed else "D23_FMC_SHORT_RAINFALL_INTERNAL_PREFLIGHT_NO_GO",
         "R16_R2_trajectory_evidence_consumed":False,"histories":rows,"failure":failure,
         "preflight_pass":passed,"R16_R2_trajectory_generation_authorized":passed,
         "post_preflight_retuning_authorized":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:v for k,v in out.items() if k!="histories"}|{"history_summary":{h:{x:v[x] for x in ("pass","cumulative_runoff_cm","final_surface_store_cm","global_ledger_residual_cm","detached_step")} for h,v in rows.items()}},sort_keys=True))
    return 0 if passed else 2
if __name__=="__main__": raise SystemExit(main())
