#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; HCM=14.085215420920257
NBINS=200; I=100; J0=101; J1=199; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; MASS_TOL=1.0e-12; RELAX_TOL=1.0e-14
FACTORS={"C10_G25":0.10,"C25_G25":0.25,"C50_G25":0.50,"C75_G25":0.75}
STEPS=16

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

TI=theta(I); KI=kval(TI); TD=theta(J1); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM)
ADV=(KD-KI)/(TD-TI)

def initial_surface():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def initial_groundwater():
    return {j:0.25*abs(psi(theta(j))) for j in range(J0,J1+1)}

def relax_map(d):
    keys=sorted(d)
    before=DTH*math.fsum(d[j] for j in keys)
    vals=sorted((d[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    if abs(after-before)>RELAX_TOL: raise ValueError("relaxation mass drift")
    return out,after-before

def surface_step(fronts,factor):
    supply=factor*KS*DT
    gray=KI*DT
    if supply+1e-18<gray:
        raise ValueError("surface supply below gray-bin demand")
    remaining=supply-gray
    out=dict(fronts); allocated=0.0
    for j in range(J0,J1+1):
        z=fronts[j]
        v=ADV*(1.0+GEFF/z)
        raw=z+DT*v
        if not(math.isfinite(raw) and 0.0<raw<DEPTH):
            raise ValueError("surface raw front bounds")
        demand=max(0.0,DTH*(raw-z))
        take=min(remaining,demand)
        if take>0:
            out[j]=z+take/DTH
            remaining-=take; allocated+=take
        if take<demand-1e-18 or remaining<=1e-18:
            break
    out,relax_drift=relax_map(out)
    return out,supply,gray,remaining,allocated,relax_drift

def gw_velocity(j,h):
    if not(math.isfinite(h) and h>0): raise ValueError("groundwater front height")
    tj=theta(j); kj=kval(tj)
    return (kj-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)

def groundwater_step(gw):
    raw={}
    for j,h in gw.items():
        nh=h+DT*gw_velocity(j,h)
        if not(math.isfinite(nh) and 0.0<nh<=DEPTH):
            raise ValueError("groundwater raw front bounds")
        raw[j]=nh
    relaxed,relax_drift=relax_map(raw)
    return relaxed,relax_drift

def storage(fronts,gw):
    return TI*DEPTH + DTH*math.fsum(fronts.values()) + DTH*math.fsum(gw.values())

def minimum_gap(fronts,gw):
    vals={j:DEPTH-fronts[j]-gw[j] for j in range(J0,J1+1)}
    j=min(vals,key=vals.get)
    return vals[j],j

def theta16(fronts,gw):
    vals=[]
    for cell in range(16):
        top=10.0*cell; bot=top+10.0; t=TI
        for j in range(J0,J1+1):
            z=fronts[j]
            surf=max(0.0,min(z,bot)-top)
            gtop=DEPTH-gw[j]
            ground=max(0.0,bot-max(gtop,top))
            if surf>0 and ground>0 and min(z,bot)>max(gtop,top):
                raise ValueError("cell overlap despite separation gate")
            t += DTH*(surf+ground)/10.0
        if not(TR<t<TS): raise ValueError("mapped theta bounds")
        vals.append(t)
    return vals

def run(factor):
    fronts=initial_surface(); gw=initial_groundwater()
    s0=storage(fronts,gw)
    init_gap,init_j=minimum_gap(fronts,gw)
    if not init_gap>0: return {"pass":False,"reason":"initial_contact","gap_cm":init_gap,"bin":init_j}
    initial_theta16=theta16(fronts,gw)
    max_mass=0.0; max_srel=0.0; max_grel=0.0; min_gap=init_gap; min_gap_bin=init_j
    cumulative_top=0.0; cumulative_bottom=0.0; cumulative_gray=0.0
    for step in range(1,STEPS+1):
        sb=storage(fronts,gw)
        fronts2,supply,gray,remaining,allocated,srel=surface_step(fronts,factor)
        if remaining>1e-14:
            return {"pass":False,"reason":"unabsorbed_surface_supply","step":step,"remaining_cm":remaining}
        gw_before=TI*DEPTH + DTH*math.fsum(gw.values())
        gw2,grel=groundwater_step(gw)
        gw_after=TI*DEPTH + DTH*math.fsum(gw2.values())
        dgw=gw_after-gw_before
        bottom=gray-dgw
        sa=storage(fronts2,gw2)
        mass=(sa-sb)-supply+bottom
        gap,jgap=minimum_gap(fronts2,gw2)
        if gap<=0:
            return {"pass":False,"reason":"surface_groundwater_contact","step":step,"gap_cm":gap,"bin":jgap}
        theta16(fronts2,gw2)
        max_mass=max(max_mass,abs(mass)); max_srel=max(max_srel,abs(srel)); max_grel=max(max_grel,abs(grel))
        if abs(mass)>MASS_TOL:
            return {"pass":False,"reason":"global_mass_gate","step":step,"mass_residual_cm":mass}
        min_gap=min(min_gap,gap)
        if gap==min_gap: min_gap_bin=jgap
        cumulative_top+=supply; cumulative_bottom+=bottom; cumulative_gray+=gray
        fronts,gw=fronts2,gw2
    sf=storage(fronts,gw)
    global_ledger=(sf-s0)-cumulative_top+cumulative_bottom
    return {
      "pass":abs(global_ledger)<=MASS_TOL and max_srel<=RELAX_TOL and max_grel<=RELAX_TOL,
      "initial_storage_cm":s0,"final_storage_cm":sf,
      "initial_minimum_separation_cm":init_gap,"initial_minimum_separation_bin":init_j,
      "minimum_separation_cm":min_gap,"minimum_separation_bin":min_gap_bin,
      "cumulative_top_infiltration_cm":cumulative_top,
      "cumulative_gray_throughflow_cm":cumulative_gray,
      "cumulative_bottom_outward_exchange_cm":cumulative_bottom,
      "global_ledger_residual_cm":global_ledger,
      "max_abs_step_mass_residual_cm":max_mass,
      "max_abs_surface_relaxation_storage_drift_cm":max_srel,
      "max_abs_groundwater_relaxation_storage_drift_cm":max_grel,
      "initial_theta16":initial_theta16,
      "final_theta16":theta16(fronts,gw)
    }

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args(); p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
    assert p["discretization"]["moisture_bins"]==200
    assert p["discretization"]["process_step_seconds"]==10
    assert p["initial_composite_state"]["groundwater_component"]["lambda"]==0.25
    assert "NO_SURFACE_GROUNDWATER_CONTACT_OR_MERGE_IN_D17" in p["firewalls"]
    rows={hid:run(f) for hid,f in FACTORS.items()}
    passed=all(v.get("pass") for v in rows.values())
    out={
      "schema":"swap5.f-romv2-d17.internal-preflight.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D17",
      "decision":"D17_FMC_COMBINED_PULSE_GW_PREFLIGHT_PASS" if passed else "D17_FMC_COMBINED_PULSE_GW_PREFLIGHT_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "theta_i":TI,"K_i_cm_per_day":KI,"gray_throughflow_fraction_of_Ksat":KI/KS,
      "histories":rows,"preflight_pass":passed,
      "SWAP_trajectory_generation_authorized":passed,
      "post_preflight_factor_lambda_duration_bin_substep_retuning_authorized":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
