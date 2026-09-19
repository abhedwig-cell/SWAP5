#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DEPTH=160.0; DT=10.0/86400.0
DTH=(TS-TR)/NBINS; TOL=1e-14
FACTORS=[0.25,0.5,1.0,2.0,4.0,8.0,16.0]

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
GEFF=max(abs(psi(TD)),HCM)
ADV=(KD-KI)/(TD-TI)

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

def classify(store,runoff):
    if runoff>TOL:return "ACTIVE_RUNOFF"
    if store>TOL:return "PONDED_NO_RUNOFF"
    return "FLUX_NO_PONDING"

def fmc_response(factor,pondmax,rsro):
    fronts=initial_fronts();s0=column_storage(fronts)
    rain=factor*KS*DT;remaining=rain;infil=0.0;out=dict(fronts);partial=None
    # D16 exact connected-front Eq.18 trajectory kinematics: fixed GEFF from terminal active bin.
    for j in range(J0,J1+1):
        z=fronts[j]
        raw=z+ADV*(1.0+GEFF/z)*DT
        if not(math.isfinite(raw) and 0<raw<DEPTH):
            return {"integrity":False,"reason":"front_bounds","bin":j,"raw":raw}
        demand=max(0.0,DTH*(raw-z))
        take=min(remaining,demand)
        if take>0:
            out[j]=z+take/DTH;infil+=take;remaining-=take
        if take<demand-1e-18:
            partial=j;break
        if remaining<=1e-18:break
    out=relax(out);s1=column_storage(out)
    if remaining<=pondmax:
        store=remaining;runoff=0.0
    else:
        ratio=DT/rsro
        store=(remaining+ratio*pondmax)/(1.0+ratio)
        runoff=remaining-store
    ledger=rain-infil-store-runoff
    return {"integrity":abs(ledger)<=1e-12,"factor":factor,"regime":classify(store,runoff),
            "rain_cm":rain,"infiltration_cm":infil,"surface_store_cm":store,"runoff_cm":runoff,
            "surface_ledger_residual_cm":ledger,"partial_bin":partial,"column_storage_change_cm":s1-s0}

def parse_swap(path):
    rows={"R16":[],"R2":[]}
    for line in pathlib.Path(path).read_text().splitlines():
        if not line.startswith("F_ROMV2_D22_SWAP|"):continue
        d={}
        for part in line.split("|")[1:]:
            if "=" in part:
                k,v=part.split("=",1);d[k]=v
        route=d["ROUTE"]
        if route=="surface-flux":reg="FLUX_NO_PONDING"
        elif route=="ponded-head":reg="PONDED_NO_RUNOFF"
        elif route=="ponded-head-linear-runoff":reg="ACTIVE_RUNOFF"
        else:reg="OTHER_"+route
        row={"factor":float(d["FACTOR"]),"regime":reg,"infiltration_cm":float(d["INFIL_CM"]),
             "surface_store_cm":float(d["POND_CM"]),"runoff_cm":float(d["RUNOFF_CM"]),
             "surface_ledger_residual_cm":float(d["LEDGER_CM"]),"top_theta":float(d["TOP_THETA"]),
             "top_h_cm":float(d["TOP_H_CM"])}
        rows[d["GRID"]].append(row)
    for key in rows:
        rows[key].sort(key=lambda x:x["factor"])
        if [r["factor"] for r in rows[key]]!=FACTORS:raise SystemExit(f"{key} factor structure mismatch")
    return rows

def onset(rows,key):
    for r in rows:
        if key=="ponding" and r["surface_store_cm"]>TOL:return r["factor"]
        if key=="runoff" and r["runoff_cm"]>TOL:return r["factor"]
    return None

def rmse(candidate,reference,key):
    return math.sqrt(sum((a[key]-b[key])**2 for a,b in zip(candidate,reference))/len(reference))

def mismatch(candidate,reference):
    return sum(a["regime"]!=b["regime"] for a,b in zip(candidate,reference))

def dist(a,b):
    if a is None or b is None:return math.inf
    return abs(math.log2(a/b))

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--prereg",required=True);ap.add_argument("--swap",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
    assert p["common_context"]["rainfall_factor_ladder_Ksat"]==FACTORS
    assert "NO_MATCHED_LABEL_SEARCH" in p["firewalls"]

    swap=parse_swap(a.swap)
    fmc=[fmc_response(f,p["common_context"]["ponding_max_cm"],p["common_context"]["runoff_resistance_day"]) for f in FACTORS]
    integrity=all(r["integrity"] for r in fmc) and all(abs(r["surface_ledger_residual_cm"])<=1e-12 for x in swap.values() for r in x)

    ref=swap["R16"];r2=swap["R2"]
    onsets={}
    for name,rows in [("R16",ref),("R2",r2),("FMC",fmc)]:
        onsets[name]={"ponding":onset(rows,"ponding"),"runoff":onset(rows,"runoff")}
    distances={
      "R2":{"ponding":dist(onsets["R2"]["ponding"],onsets["R16"]["ponding"]),
            "runoff":dist(onsets["R2"]["runoff"],onsets["R16"]["runoff"])},
      "FMC":{"ponding":dist(onsets["FMC"]["ponding"],onsets["R16"]["ponding"]),
             "runoff":dist(onsets["FMC"]["runoff"],onsets["R16"]["runoff"])}
    }
    curves={}
    for name,rows in [("R2",r2),("FMC",fmc)]:
        curves[name]={
          "infiltration_RMSE_cm":rmse(rows,ref,"infiltration_cm"),
          "surface_store_RMSE_cm":rmse(rows,ref,"surface_store_cm"),
          "runoff_RMSE_cm":rmse(rows,ref,"runoff_cm"),
          "regime_mismatch_count":mismatch(rows,ref)
        }
    gates={
      "ponding_onset_distance":distances["FMC"]["ponding"]<=distances["R2"]["ponding"],
      "runoff_onset_distance":distances["FMC"]["runoff"]<=distances["R2"]["runoff"],
      "regime_mismatch_count":curves["FMC"]["regime_mismatch_count"]<=curves["R2"]["regime_mismatch_count"],
      "infiltration_RMSE":curves["FMC"]["infiltration_RMSE_cm"]<=curves["R2"]["infiltration_RMSE_cm"],
      "surface_store_RMSE":curves["FMC"]["surface_store_RMSE_cm"]<=curves["R2"]["surface_store_RMSE_cm"],
      "runoff_RMSE":curves["FMC"]["runoff_RMSE_cm"]<=curves["R2"]["runoff_RMSE_cm"]
    }
    retained=integrity and all(gates.values())
    decision="FMC_NATIVE_SURFACE_THRESHOLD_RESPONSE_COMPETITIVE_WITH_R2" if retained else "FMC_NATIVE_SURFACE_THRESHOLD_RESPONSE_NOT_COMPETITIVE_WITH_R2"
    out={
      "schema":"swap5.f-romv2-d22.result.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D22",
      "decision":decision,"integrity":{"pass":integrity},
      "responses":{"R16":ref,"R2":r2,"FMC":fmc},
      "onsets":onsets,"onset_log2_distance_to_R16":distances,
      "curve_metrics_vs_R16":curves,
      "frontier_gates":gates,"all_gates_required":True,"retained":retained,
      "interpretation":{
        "FAST_EVENT_THRESHOLD":"RESEARCH_CANDIDACY_RETAINED_RELATIVE_TO_R2" if retained else "NOT_RETAINED_RELATIVE_TO_R2",
        "Richards_trajectory_test":False,
        "prior_D13_D20_FMC_candidacy_reclassified":False
      },
      "application_acceptance":False,"formal_performance_claim":False,"production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"onsets":onsets,"distances":distances,"curves":curves,"gates":gates},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
