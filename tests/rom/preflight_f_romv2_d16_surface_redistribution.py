#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1.0e-14
FACTORS={"S10":0.10,"S25":0.25,"S50":0.50,"S75":0.75}
PULSE=16; HIATUS=48

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

TI=theta(I); TD=theta(J1); KI=kval(TI); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM)
ADV=(KD-KI)/(TD-TI)

def initial_fronts():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def front_storage(fronts):
    return TI*DEPTH + DTH*math.fsum(fronts.values())

def relax(fronts):
    keys=sorted(fronts)
    before=DTH*math.fsum(fronts[j] for j in keys)
    vals=sorted((fronts[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    if abs(after-before)>TOL: raise ValueError("relaxation mass drift")
    return out

def pulse_step(fronts,factor):
    supply=factor*KS*DT
    remaining=supply
    out=dict(fronts)
    partial=None
    for j in range(J0,J1+1):
        z=fronts[j]
        v=ADV*(1.0+GEFF/z)
        raw=z+DT*v
        if not(math.isfinite(raw) and 0.0<raw<DEPTH):
            raise ValueError("raw front bounds")
        demand=max(0.0,DTH*(raw-z))
        take=min(remaining,demand)
        if take>0.0:
            out[j]=z+take/DTH
            remaining-=take
        if take<demand-1.0e-18:
            partial=j
            break
        if remaining<=1.0e-18: break
    out=relax(out)
    return out,supply,remaining,partial

def slug_velocity(j):
    return (kval(theta(j))-kval(theta(j-1)))/(theta(j)-theta(j-1))

def run_history(factor):
    fronts=initial_fronts()
    s0=front_storage(fronts)
    supplied=0.0
    max_ledger=0.0
    partial_bins=[]
    max_front=max(fronts.values())

    for _ in range(PULSE):
        sb=front_storage(fronts)
        fronts,supply,remaining,partial=pulse_step(fronts,factor)
        sa=front_storage(fronts)
        ledger=(sa-sb)-(supply-remaining)
        max_ledger=max(max_ledger,abs(ledger))
        if remaining>TOL:
            return {"pass":False,"reason":"unabsorbed_prescribed_infiltration","remaining_cm":remaining}
        supplied+=supply
        partial_bins.append(partial)
        max_front=max(max_front,max(fronts.values()))

    slugs={j:[0.0,z] for j,z in fronts.items()}
    detach_storage=TI*DEPTH + DTH*math.fsum(b-a for a,b in slugs.values())
    if abs(detach_storage-front_storage(fronts))>TOL:
        return {"pass":False,"reason":"detachment_storage_drift"}

    max_slug_bottom=max(b for _,b in slugs.values())
    max_len_drift=0.0
    for _ in range(HIATUS):
        for j,(top,bottom) in list(slugs.items()):
            move=slug_velocity(j)*DT
            nt=top+move; nb=bottom+move
            if not(math.isfinite(nt) and math.isfinite(nb) and 0.0<=nt<nb<DEPTH):
                return {"pass":False,"reason":"slug_bottom_or_bounds","bin":j,"top":nt,"bottom":nb}
            max_len_drift=max(max_len_drift,abs((nb-nt)-(bottom-top)))
            slugs[j]=[nt,nb]
            max_slug_bottom=max(max_slug_bottom,nb)

    final_storage=TI*DEPTH + DTH*math.fsum(b-a for a,b in slugs.values())
    global_ledger=final_storage-(s0+supplied)
    return {
      "pass":abs(global_ledger)<=TOL and max_ledger<=TOL and max_len_drift<=TOL,
      "initial_storage_cm":s0,
      "prescribed_infiltration_cm":supplied,
      "final_storage_cm":final_storage,
      "global_ledger_residual_cm":global_ledger,
      "max_abs_pulse_step_ledger_residual_cm":max_ledger,
      "max_abs_slug_length_drift_cm":max_len_drift,
      "max_connected_front_depth_cm":max_front,
      "max_slug_bottom_depth_cm":max_slug_bottom,
      "minimum_bottom_clearance_cm":DEPTH-max_slug_bottom,
      "partial_bins":partial_bins
    }

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args(); p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
    assert p["state_and_geometry"]["FMC_moisture_bins"]==NBINS
    assert p["temporal_contract"]["observation_step_seconds"]==10
    assert p["scientific_role"]["blind_confirmation"] is False
    assert "NO_PULSE_FACTOR_OR_DURATION_RETUNING_AFTER_PREFLIGHT" in p["firewalls"]
    rows={h:run_history(f) for h,f in FACTORS.items()}
    passed=all(v["pass"] for v in rows.values())
    out={
      "schema":"swap5.f-romv2-d16.internal-preflight.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D16",
      "decision":"D16_FMC_SURFACE_REDISTRIBUTION_INTERNAL_PREFLIGHT_PASS" if passed else "D16_FMC_SURFACE_REDISTRIBUTION_INTERNAL_PREFLIGHT_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "initial_profile":"D14_I_DEEP",
      "histories":rows,
      "preflight_pass":passed,
      "SWAP_trajectory_generation_authorized":passed,
      "post_preflight_factor_duration_bin_substep_retuning_authorized":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
