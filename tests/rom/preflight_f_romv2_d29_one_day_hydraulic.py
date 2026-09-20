#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; HCM=14.085215420920257
NB=200; I=100; J0=101; J1=199; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NB; MASS_TOL=1e-12; RELAX_TOL=1e-14
BLOCK_STEPS=30; NSTEPS=8640
PATTERNS={
 "P_UP_24H":[0.10,0.25,0.50,0.75],
 "P_DOWN_24H":[0.75,0.50,0.25,0.10],
 "P_ALT_A_24H":[0.10,0.75,0.25,0.50],
 "P_ALT_B_24H":[0.75,0.10,0.50,0.25],
}

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR)
    k=KS*se**ELL*(1-(1-se**(1.0/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K domain")
    return k

TI=theta(I); KI=kval(TI); TD=theta(J1); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def initial_surface():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}
def initial_gw():
    return {j:0.25*abs(psi(theta(j))) for j in range(J0,J1+1)}
def relax(d):
    keys=sorted(d)
    before=DTH*math.fsum(d.values())
    vals=sorted(d.values(),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    drift=DTH*math.fsum(out.values())-before
    if abs(drift)>RELAX_TOL: raise ValueError("relax drift")
    return out,drift
def factor_for(pattern,step):
    block=(step-1)//BLOCK_STEPS
    return pattern[block%4]
def surface_step(fronts,factor):
    supply=factor*KS*DT; gray=KI*DT
    if supply+1e-18<gray: raise ValueError("supply below gray")
    rem=supply-gray; out=dict(fronts)
    for j in range(J0,J1+1):
        z=fronts[j]
        raw=z+DT*ADV*(1+GEFF/z)
        if not(math.isfinite(raw) and 0<raw<DEPTH): raise ValueError("surface bounds")
        demand=max(0.0,DTH*(raw-z))
        take=min(rem,demand)
        if take>0:
            out[j]=z+take/DTH; rem-=take
        if take<demand-1e-18 or rem<=1e-18: break
    out,drift=relax(out)
    return out,supply,gray,rem,drift
def gw_velocity(j,h):
    tj=theta(j); return (kval(tj)-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)
def gw_step(gw):
    raw={j:h+DT*gw_velocity(j,h) for j,h in gw.items()}
    if not all(math.isfinite(h) and 0<h<=DEPTH for h in raw.values()):
        raise ValueError("gw bounds")
    return relax(raw)
def storage(fronts,gw):
    return TI*DEPTH+DTH*math.fsum(fronts.values())+DTH*math.fsum(gw.values())
def min_gap(fronts,gw):
    vals={j:DEPTH-fronts[j]-gw[j] for j in range(J0,J1+1)}
    j=min(vals,key=vals.get); return vals[j],j

def run(pattern):
    fronts=initial_surface(); gw=initial_gw()
    s0=storage(fronts,gw); cumtop=0.; cumbot=0.; maxmass=0.; mingap=1e99
    maxsrel=maxgrel=0.; block_rows=[]
    block_top=block_bot=0.
    for step in range(1,NSTEPS+1):
        factor=factor_for(pattern,step)
        sb=storage(fronts,gw)
        try:
            fronts2,supply,gray,rem,srel=surface_step(fronts,factor)
        except Exception as exc:
            return {"pass":False,"reason":"surface_process_failure","detail":str(exc),"step":step,"factor":factor}
        if rem>1e-14:
            return {"pass":False,"reason":"unabsorbed_surface_supply","step":step,"factor":factor,"remaining_cm":rem}
        g0=TI*DEPTH+DTH*math.fsum(gw.values())
        try:
            gw2,grel=gw_step(gw)
        except Exception as exc:
            return {"pass":False,"reason":"groundwater_process_failure","detail":str(exc),"step":step,"factor":factor}
        g1=TI*DEPTH+DTH*math.fsum(gw2.values())
        bottom=gray-(g1-g0)
        sa=storage(fronts2,gw2)
        mass=(sa-sb)-supply+bottom
        gap,jgap=min_gap(fronts2,gw2)
        if gap<=0:
            return {"pass":False,"reason":"surface_groundwater_contact","step":step,"factor":factor,"gap_cm":gap,"bin":jgap,
                    "elapsed_seconds":step*10.0,"elapsed_hours":step*10.0/3600.0}
        if abs(mass)>MASS_TOL:
            return {"pass":False,"reason":"mass_gate","step":step,"factor":factor,"mass_residual_cm":mass}
        maxmass=max(maxmass,abs(mass)); maxsrel=max(maxsrel,abs(srel)); maxgrel=max(maxgrel,abs(grel)); mingap=min(mingap,gap)
        cumtop+=supply; cumbot+=bottom; block_top+=supply; block_bot+=bottom
        fronts,gw=fronts2,gw2
        if step%BLOCK_STEPS==0:
            block_rows.append({"block":step//BLOCK_STEPS,"factor":factor,
                               "cumulative_top_cm":cumtop,"cumulative_bottom_cm":cumbot,
                               "block_top_cm":block_top,"block_bottom_cm":block_bot,
                               "storage_cm":sa,"minimum_gap_so_far_cm":mingap})
            block_top=block_bot=0.
    sf=storage(fronts,gw); ledger=(sf-s0)-cumtop+cumbot
    return {"pass":abs(ledger)<=MASS_TOL and maxsrel<=RELAX_TOL and maxgrel<=RELAX_TOL,
            "initial_storage_cm":s0,"final_storage_cm":sf,"cumulative_top_cm":cumtop,
            "cumulative_bottom_cm":cumbot,"global_ledger_residual_cm":ledger,
            "max_abs_step_mass_residual_cm":maxmass,
            "max_abs_surface_relaxation_drift_cm":maxsrel,
            "max_abs_groundwater_relaxation_drift_cm":maxgrel,
            "minimum_surface_groundwater_separation_cm":mingap,
            "completed_steps":NSTEPS,"completed_hours":24.0,
            "blocks":block_rows}

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args(); p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_FMC_ONLY_PREFLIGHT_AND_ANY_NEW_RICHARDS_TRAJECTORY"
    assert p["temporal_design"]["total_steps_per_history"]==8640
    assert p["temporal_design"]["cycles_per_history"]==72
    assert p["firewalls"].count("NO_ET_ROOT_UPTAKE")==1
    assert p["firewalls"].count("NO_SLUG_OR_MERGE_BRANCH")==1
    rows={h:run(pattern) for h,pattern in PATTERNS.items()}
    passed=all(v.get("pass") for v in rows.values())
    tops=[v.get("cumulative_top_cm") for v in rows.values() if v.get("pass")]
    equal_top=(len(tops)==4 and max(tops)-min(tops)<=1e-12)
    passed=passed and equal_top
    out={"schema":"swap5.f-romv2-d29.preflight.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D29",
         "decision":"D29_FMC_ONE_DAY_SEPARATED_PREFLIGHT_PASS" if passed else "D29_FMC_ONE_DAY_SEPARATED_PREFLIGHT_NO_GO",
         "new_R16_R2_trajectory_evidence_consumed":False,"histories":rows,
         "equal_cumulative_top_input":equal_top,"preflight_pass":passed,
         "stage2_R16_R2_trajectory_generation_authorized":passed,
         "post_preflight_scientific_retuning_authorized":False,
         "production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    summary={}
    for h,v in rows.items():
        summary[h]={k:v.get(k) for k in (
            "pass","reason","step","elapsed_hours","completed_steps","cumulative_top_cm",
            "cumulative_bottom_cm","minimum_surface_groundwater_separation_cm","max_abs_step_mass_residual_cm")}
    print(json.dumps({"decision":out["decision"],"equal_top":equal_top,"summary":summary},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
