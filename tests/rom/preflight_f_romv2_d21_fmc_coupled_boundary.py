#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1e-14

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

def column_storage(fronts):
    return TI*DEPTH + DTH*math.fsum(fronts.values())

def relax(fronts):
    keys=sorted(fronts)
    before=DTH*math.fsum(fronts.values())
    vals=sorted((fronts[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    if abs(after-before)>TOL: raise ValueError("relaxation mass drift")
    return out

def one_step(factor,pondmax,rsro):
    fronts=initial_fronts(); s0=column_storage(fronts)
    store0=0.0; rain=factor*KS*DT; available=store0+rain
    remaining=available; infiltrated=0.0; out=dict(fronts); partial=None
    hp=store0
    for j in range(J0,J1+1):
        z=fronts[j]
        raw=z+ADV*(1.0+(GEFF+hp)/z)*DT
        if not(math.isfinite(raw) and 0.0<raw<DEPTH):
            return {"pass":False,"reason":"front_bounds","bin":j,"raw":raw}
        demand=max(0.0,DTH*(raw-z))
        take=min(remaining,demand)
        if take>0:
            out[j]=z+take/DTH
            infiltrated+=take;remaining-=take
        if take<demand-1e-18:
            partial=j;break
        if remaining<=1e-18: break
    out=relax(out); s1=column_storage(out)
    if remaining<=pondmax:
        store1=remaining;runoff=0.0
    else:
        ratio=DT/rsro
        store1=(remaining+ratio*pondmax)/(1.0+ratio)
        runoff=remaining-store1
    ledger=s0+store0+rain-(s1+store1+runoff)
    return {"pass":abs(ledger)<=TOL,"factor_Ksat":factor,"rain_cm":rain,"infiltrated_cm":infiltrated,
            "remaining_after_infiltration_cm":remaining,"surface_store_cm":store1,"runoff_cm":runoff,
            "partial_bin":partial,"column_storage_change_cm":s1-s0,"ledger_residual_cm":ledger}

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--prereg",required=True);ap.add_argument("--auth",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text());auth=json.loads(pathlib.Path(a.auth).read_text())
    assert auth["stage"]=="STAGE2_FMC_COUPLED_BOUNDARY_MICRO_PREFLIGHT_AUTHORIZED"
    assert auth["stage1_execution"]["R16_R2_trajectory_evidence_consumed"] is False
    f=auth["frozen_thresholds"];pond=f["ponding_max_cm"];rsro=f["runoff_resistance_day"]
    rows={
      "M_FLUX":one_step(f["flux_factor_Ksat"],pond,rsro),
      "M_POND":one_step(f["pond_factor_Ksat"],pond,rsro),
      "M_RUNOFF":one_step(f["runoff_factor_Ksat"],pond,rsro)
    }
    flux=rows["M_FLUX"];pd=rows["M_POND"];ro=rows["M_RUNOFF"]
    labels={
      "M_FLUX":flux["pass"] and abs(flux["surface_store_cm"])<=TOL and abs(flux["runoff_cm"])<=TOL,
      "M_POND":pd["pass"] and pd["surface_store_cm"]>0 and abs(pd["runoff_cm"])<=TOL,
      "M_RUNOFF":ro["pass"] and ro["surface_store_cm"]>pond and ro["runoff_cm"]>0
    }
    passed=all(labels.values())
    out={
      "schema":"swap5.f-romv2-d21.stage2-micro-preflight.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D21",
      "decision":"D21_FMC_COUPLED_BOUNDARY_MICRO_PREFLIGHT_PASS" if passed else "D21_FMC_COUPLED_BOUNDARY_MICRO_PREFLIGHT_NO_GO",
      "R16_R2_trajectory_evidence_consumed":False,
      "frozen_thresholds":f,"histories":rows,"regime_label_pass":labels,
      "preflight_pass":passed,"stage3_R16_R2_trajectory_authorized":passed,
      "post_result_factor_surface_law_bin_step_retuning_authorized":False,
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":out["decision"],"regime_label_pass":labels,
                      "rows":{k:{"store":v.get("surface_store_cm"),"runoff":v.get("runoff_cm"),
                                 "infiltrated":v.get("infiltrated_cm"),"ledger":v.get("ledger_residual_cm")} for k,v in rows.items()}},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
