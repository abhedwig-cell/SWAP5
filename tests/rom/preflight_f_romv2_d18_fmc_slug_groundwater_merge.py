#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087
NBINS=200; I=100; J0=101; J1=199; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; MASS_TOL=1.0e-12; RELAX_TOL=1.0e-14; SLUG_LEN=5.0
LAMBDAS={"M25":0.25,"M50":0.50,"M75":0.75,"M125":1.25}
NSTEPS=64

def theta(j): return TR+j*DTH
def psi(t):
    if not(TR<t<TS): raise ValueError("theta domain")
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    if not(TR<t<TS): raise ValueError("theta domain")
    se=(t-TR)/(TS-TR)
    k=KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K domain")
    return k

TI=theta(I); KI=kval(TI)

def slug_velocity(j):
    return (kval(theta(j))-kval(theta(j-1)))/(theta(j)-theta(j-1))

def initial_state(lam):
    gw={}
    slugs={}
    for j in range(J0,J1+1):
        h=lam*abs(psi(theta(j)))
        if not(math.isfinite(h) and 0.0<h<DEPTH): raise ValueError("initial groundwater front")
        gtop=DEPTH-h
        gap=0.5*slug_velocity(j)*DT
        bottom=gtop-gap
        top=bottom-SLUG_LEN
        if not(0.0<top<bottom<gtop<DEPTH): raise ValueError(f"initial slug separation bin={j}")
        gw[j]=h
        slugs[j]=(top,bottom)
    return slugs,gw

def relax_map(gw):
    keys=sorted(gw)
    before=DTH*math.fsum(gw[j] for j in keys)
    vals=sorted((gw[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    drift=after-before
    if abs(drift)>RELAX_TOL: raise ValueError("groundwater relaxation mass drift")
    return out,drift

def gw_velocity(j,h):
    if not(math.isfinite(h) and 0.0<h<=DEPTH): raise ValueError("groundwater front height")
    tj=theta(j); kj=kval(tj)
    return (kj-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)

def groundwater_step(gw):
    raw={}
    for j,h in gw.items():
        nh=h+DT*gw_velocity(j,h)
        if not(math.isfinite(nh) and 0.0<nh<=DEPTH): raise ValueError(f"groundwater raw front bounds bin={j}")
        raw[j]=nh
    return relax_map(raw)

def storage(slugs,gw):
    return TI*DEPTH + DTH*(math.fsum(b-a for a,b in slugs.values()) + math.fsum(gw.values()))

def theta16(slugs,gw):
    vals=[]
    for cell in range(16):
        top=10.0*cell; bot=top+10.0; t=TI
        for j in range(J0,J1+1):
            sa=sb=0.0
            if j in slugs:
                a,b=slugs[j]
                sa=max(0.0,min(b,bot)-max(a,top))
            gtop=DEPTH-gw[j]
            sb=max(0.0,bot-max(gtop,top))
            if sa>0 and sb>0:
                a,b=slugs[j]
                if min(b,bot)>max(gtop,top)+1e-14:
                    raise ValueError("slug-groundwater overlap after accepted state")
            t += DTH*(sa+sb)/10.0
        if not(TR<t<TS): raise ValueError("mapped theta bounds")
        vals.append(t)
    return vals

def theta2_from16(vals):
    return [sum(vals[:8])/8.0,sum(vals[8:])/8.0]

def terminal_bottom_flux(gw):
    return -DTH*math.fsum(gw_velocity(j,gw[j]) for j in range(J0,J1+1))

def run_history(lam):
    slugs,gw=initial_state(lam)
    s0=storage(slugs,gw)
    th16_0=theta16(slugs,gw)
    th2_0=theta2_from16(th16_0)
    map16_storage=sum(t*10.0 for t in th16_0)
    map2_storage=sum(t*80.0 for t in th2_0)
    if abs(map16_storage-s0)>MASS_TOL or abs(map2_storage-s0)>MASS_TOL:
        raise ValueError("initial exact mapping identity")

    rows=[]; cum_bottom=0.0; max_mass=0.0; max_merge=0.0; max_relax=0.0
    total_merges=0
    for step in range(1,NSTEPS+1):
        sb=storage(slugs,gw)
        merge_count=0; merge_drift=0.0

        if slugs:
            moved={}
            for j,(a,b) in slugs.items():
                d=slug_velocity(j)*DT
                na=a+d; nb=b+d
                if not(0.0<na<nb<=DEPTH): raise ValueError(f"translated slug bounds bin={j}")
                moved[j]=(na,nb)

            remaining={}
            for j,(a,b) in moved.items():
                gtop=DEPTH-gw[j]
                if b>=gtop:
                    before=DTH*((b-a)+gw[j])
                    length=b-a
                    newh=gw[j]+length
                    if not(math.isfinite(newh) and 0.0<newh<=DEPTH):
                        raise ValueError(f"merged groundwater front bounds bin={j}")
                    after=DTH*newh
                    drift=after-before
                    merge_drift += drift
                    max_merge=max(max_merge,abs(drift))
                    gw[j]=newh
                    merge_count+=1
                else:
                    remaining[j]=(a,b)
            slugs=remaining

        gw2,relax_drift=groundwater_step(gw)
        max_relax=max(max_relax,abs(relax_drift))
        gw=gw2

        sa=storage(slugs,gw)
        bottom=-(sa-sb)
        mass=(sa-sb)+bottom
        cum_bottom+=bottom
        max_mass=max(max_mass,abs(mass))
        if abs(mass)>MASS_TOL: raise ValueError(f"global mass gate step={step}")
        if abs(merge_drift)>RELAX_TOL: raise ValueError(f"merge storage drift step={step}")

        th16=theta16(slugs,gw)
        rows.append({
          "step":step,
          "merge_count":merge_count,
          "remaining_slug_count":len(slugs),
          "storage_cm":sa,
          "bottom_outward_exchange_cm":bottom,
          "cumulative_bottom_outward_exchange_cm":cum_bottom,
          "terminal_bottom_outward_flux_cm_per_day":terminal_bottom_flux(gw),
          "theta16":th16
        })
        total_merges+=merge_count

    if rows[0]["merge_count"]!=99 or rows[0]["remaining_slug_count"]!=0:
        return {"pass":False,"reason":"first_step_merge_contract","first_step":rows[0]}
    if total_merges!=99:
        return {"pass":False,"reason":"unexpected_total_merge_count","total_merges":total_merges}
    return {
      "pass":True,
      "initial_storage_cm":s0,
      "initial_theta16":th16_0,
      "initial_theta2":th2_0,
      "first_step_merge_count":rows[0]["merge_count"],
      "total_merge_count":total_merges,
      "max_abs_merge_storage_drift_cm":max_merge,
      "max_abs_groundwater_relaxation_storage_drift_cm":max_relax,
      "max_abs_step_mass_residual_cm":max_mass,
      "final_storage_cm":rows[-1]["storage_cm"],
      "final_cumulative_bottom_outward_exchange_cm":rows[-1]["cumulative_bottom_outward_exchange_cm"],
      "steps":rows
    }

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args(); p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
    assert p["discretization"]["moisture_bins"]==200
    assert p["discretization"]["process_step_seconds"]==10
    assert p["initial_state"]["falling_slug_length_cm"]==5
    assert p["initial_state"]["prospective_contact_gap"]=="gap_j=0.5*v_j*dt."
    assert "NO_MERGE_RULE_RETUNING" in p["firewalls"]

    histories={}
    for hid,lam in LAMBDAS.items():
        try:
            histories[hid]=run_history(lam)
        except Exception as exc:
            histories[hid]={"pass":False,"reason":str(exc)}

    passed=all(v.get("pass") for v in histories.values())
    out={
      "schema":"swap5.f-romv2-d18.internal-preflight.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D18",
      "decision":"D18_FMC_SLUG_GW_MERGE_PREFLIGHT_PASS" if passed else "D18_FMC_SLUG_GW_MERGE_PREFLIGHT_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "theta_i":TI,"K_i_cm_per_day":KI,"slug_length_cm":SLUG_LEN,
      "histories":histories,
      "preflight_pass":passed,
      "SWAP_trajectory_generation_authorized":passed,
      "post_preflight_lambda_slug_gap_bin_substep_merge_retuning_authorized":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":out["decision"],
      "summary":{h:{k:v.get(k) for k in ("pass","first_step_merge_count","total_merge_count","max_abs_merge_storage_drift_cm","max_abs_step_mass_residual_cm")} for h,v in histories.items()}
    },sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
