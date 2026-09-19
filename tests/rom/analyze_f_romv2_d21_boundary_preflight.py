#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,re

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1e-14

def theta(j): return TR+j*DTH
def psi(t):
    if not (TR<t<TS): raise ValueError("theta domain")
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    if t<=TR:return 0.0
    if t>=TS:return KS
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2
TI=theta(I); TD=theta(J1); KI=kval(TI); KD=kval(TD)
ADV=(KD-KI)/(TD-TI)

def initial_fronts():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def relax(fronts):
    keys=sorted(fronts)
    before=DTH*math.fsum(fronts[j] for j in keys)
    vals=sorted((fronts[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out[j] for j in keys)
    if abs(after-before)>TOL: raise ValueError("relaxation mass drift")
    return out,before,after

def hp_front_test():
    base=initial_fronts()
    pondmax=KS*DT
    hp_values=[0.0,pondmax,2.0*pondmax]
    rows=[]
    previous_demand=None
    monotone=True
    for hp in hp_values:
        raw={}
        demand=0.0
        for j,z in base.items():
            geff=max(abs(psi(theta(j))),HCM)
            v=ADV*(1.0+(geff+hp)/z)
            zr=z+v*DT
            if not (math.isfinite(v) and v>0 and math.isfinite(zr) and 0<zr<DEPTH):
                return {"pass":False,"reason":"front_nonphysical","hp_cm":hp,"bin":j,"velocity":v,"raw":zr}
            raw[j]=zr
            demand += DTH*max(0.0,zr-z)
        relaxed,before,after=relax(raw)
        if previous_demand is not None and demand+TOL<previous_demand: monotone=False
        previous_demand=demand
        rows.append({"h_p_cm":hp,"potential_infiltration_demand_cm":demand,
                     "storage_before_relax_cm":before,"storage_after_relax_cm":after,
                     "relaxation_drift_cm":after-before,
                     "min_raw_front_cm":min(raw.values()),"max_raw_front_cm":max(raw.values())})
    return {"pass":monotone and all(abs(x["relaxation_drift_cm"])<=TOL for x in rows),
            "demand_nondecreasing_with_h_p":monotone,"cases":rows}

def surface_reservoir_test():
    cap=KS*DT
    ratio=DT/0.001
    cases=[]
    for label,W in [("NO_RUNOFF",0.5*cap),("ACTIVE_RUNOFF",2.0*cap)]:
        if W<=cap:
            s=W;run=0.0
        else:
            s=(W+ratio*cap)/(1.0+ratio)
            run=W-s
        residual=W-s-run
        cases.append({"id":label,"W_cm":W,"surface_store_cm":s,"runoff_cm":run,"ledger_residual_cm":residual})
    p=(cases[0]["runoff_cm"]==0.0 and abs(cases[0]["surface_store_cm"]-cases[0]["W_cm"])<=TOL
       and cases[1]["surface_store_cm"]>cap and cases[1]["runoff_cm"]>0.0
       and all(abs(c["ledger_residual_cm"])<=TOL for c in cases))
    return {"pass":p,"ponding_max_cm":cap,"dt_over_runoff_resistance":ratio,"cases":cases}

def provider_rows(path):
    rows=[]; selected=None
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("F_ROMV2_D21_PROVIDER|"):
            d={}
            for part in line.split("|")[1:]:
                if "=" in part:
                    k,v=part.split("=",1); d[k]=v
            rows.append({"factor":float(d["FACTOR"]),"route":d["ROUTE"],"pond_cm":float(d["POND_CM"]),
                         "runoff_cm":float(d["RUNOFF_CM"]),"top_flux_native":float(d["TOP_FLUX_NATIVE"]),
                         "surface_head_cm":float(d["SURFACE_HEAD"]),"iterations":int(d["ITER"])})
        if line.startswith("F_ROMV2_D21_SELECTION|"):
            d={}
            for part in line.split("|")[1:]:
                if "=" in part:
                    k,v=part.split("=",1); d[k]=v
            selected={"flux_factor":float(d["FLUX_FACTOR"]),"pond_factor":float(d["POND_FACTOR"]),
                      "runoff_factor":float(d["RUNOFF_FACTOR"]),"ponding_max_cm":float(d["PONDING_MAX_CM"]),
                      "top_theta":float(d["TOP_THETA"]),"top_h_cm":float(d["TOP_H_CM"])}
    if selected is None or len(rows)!=7:
        raise SystemExit("provider output structure incomplete")
    return rows,selected

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True);ap.add_argument("--provider",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_BOUNDARY_PREFLIGHT"
    assert p["boundary_parameters"]["rainfall_factor_ladder_of_Ksat"]==[0.25,0.5,1,2,4,8,16]
    assert p["boundary_parameters"]["runoff_resistance_day"]==0.001
    assert p["FMC_boundary_primitives"]["newly_qualified_dimension"]=="nonzero h_p only; no change to constitutive law, bins, process step or capillary relaxation"

    rows,selected=provider_rows(a.provider)
    ordered=(selected["flux_factor"]<selected["pond_factor"]<selected["runoff_factor"])
    provider_pass=ordered and any(r["factor"]==selected["flux_factor"] and r["route"]=="surface-flux" for r in rows) \
        and any(r["factor"]==selected["pond_factor"] and r["route"]=="ponded-head" and r["runoff_cm"]==0.0 for r in rows) \
        and any(r["factor"]==selected["runoff_factor"] and r["route"]=="ponded-head-linear-runoff" and r["runoff_cm"]>0.0 for r in rows)
    hp=hp_front_test(); reservoir=surface_reservoir_test()
    passed=provider_pass and hp["pass"] and reservoir["pass"]
    out={
      "schema":"swap5.f-romv2-d21.boundary-preflight.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D21",
      "decision":"D21_RAIN_PONDING_RUNOFF_BOUNDARY_PREFLIGHT_PASS" if passed else "D21_RAIN_PONDING_RUNOFF_BOUNDARY_PREFLIGHT_NO_GO",
      "R16_R2_trajectory_evidence_consumed":False,
      "SWAP_provider":{"pass":provider_pass,"rows":rows,"selected":selected},
      "FMC_nonzero_hp_front_primitive":hp,
      "FMC_linear_surface_reservoir":reservoir,
      "preflight_pass":passed,
      "stage2_micro_preflight_authorized":passed,
      "post_result_ladder_ponding_runoff_bin_step_retuning_authorized":False,
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":out["decision"],"selected":selected,"provider_pass":provider_pass,
                      "hp_pass":hp["pass"],"surface_reservoir_pass":reservoir["pass"]},sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
