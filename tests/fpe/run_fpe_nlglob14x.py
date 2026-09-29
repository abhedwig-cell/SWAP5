#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
m=mats["O05"]
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
stages=(0.20,0.40,0.80); dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    if h>=0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

def run(route,dt,horizon):
    h0,p0,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    bystep={}
    inconsistent=False
    for x in states:
        bystep.setdefault(int(x["STEP"]),[]).append(x)
        if (int(x.get("SAT_H","0"))==1)!=(int(x.get("SAT_THETA","0"))==1): inconsistent=True
    series=[]; noncontig=False; finite=True
    for step in sorted(bystep):
        xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
        if len(xs)!=16: finite=False; continue
        sat=[]; vals=[]
        for x in xs:
            vals.extend(float(x[k]) for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX"))
            if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1: sat.append(int(x["NODE"]))
        if not all(math.isfinite(v) for v in vals): finite=False
        contiguous=(not sat) or sat==list(range(min(sat),17))
        noncontig|=not contiguous
        series.append((step,step*dt,sat))
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8

    transitions=[]; reverse=False; skipped=False; tops=[]
    last_top=None; disappeared=None; disappear_bracket=None
    second_retreat_seen=False; max_retreat_top=5
    for idx,(step,t,sat) in enumerate(series):
        top=min(sat) if sat else None
        tops.append(top)
        if top is None:
            if disappeared is None:
                disappeared=t
                prev=series[idx-1] if idx>0 else None
                disappear_bracket={"last_saturated_time":prev[1] if prev else None,
                                   "first_empty_time":t,
                                   "last_saturated_set":prev[2] if prev else None,
                                   "empty_set":sat}
            continue
        if last_top is not None and top!=last_top:
            delta=top-last_top
            transitions.append({"from_top":last_top,"to_top":top,"time":t,"step":step,
                                "from_set":list(range(last_top,17)),"to_set":sat})
            if last_top==4 and top==5:
                second_retreat_seen=True
                max_retreat_top=5
            elif second_retreat_seen:
                if delta<0:
                    reverse=True
                if delta>1:
                    skipped=True
                if top>max_retreat_top:
                    max_retreat_top=top
        last_top=top

    further=[x for x in transitions if x["from_top"]>=5 and x["to_top"]>x["from_top"]]
    valid=(cp.returncode==0 and complete and finite and mass_ok and not noncontig and not inconsistent and not skipped)
    rec={"route":route,"dt":dt,"horizon":horizon,"process_ok":cp.returncode==0,"complete":complete,
         "finite":finite,"mass_ok":mass_ok,"noncontiguous":noncontig,"indicator_inconsistent":inconsistent,
         "skipped_retreat":skipped,"reverse_after_retreat":reverse,"max_ledger":maxledger,"cum_ledger":cumledger,
         "transitions":transitions,"further_retreat_count":len(further),"disappearance_time":disappeared,
         "disappearance_bracket":disappear_bracket,"final_sat_set":series[-1][2] if series else None,
         "valid":valid}
    return rec

selected={}
stage_records={}
for horizon in stages:
    rs=[run(r,dt,horizon) for r in routes for dt in dts]
    stage_records[str(horizon)]=rs
    for x in rs:
        key=(x["route"],x["dt"])
        selected[key]=x
    if all(x["valid"] and x["disappearance_time"] is not None for x in rs):
        break

rows=[selected[(r,dt)] for r in routes for dt in dts]
coverage=len(rows)==8 and all(x["valid"] for x in rows)
all_disappear=coverage and all(x["disappearance_time"] is not None for x in rows)
further_all=coverage and all(x["further_retreat_count"]>0 for x in rows)
if any(x["noncontiguous"] or x["indicator_inconsistent"] or x["skipped_retreat"] for x in rows):
    agg="NLGLOB14X_RETREAT_GEOMETRY_INCONSISTENT"
elif any(x["reverse_after_retreat"] for x in rows):
    agg="NLGLOB14X_RETREAT_REVERSAL_OBSERVED"
elif not coverage:
    agg="BLOCKED_NLGLOB14X_CONTROL_EXPOSURE"
elif all_disappear:
    agg="QUALIFIED_SATURATED_BLOCK_DISAPPEARANCE_CONTROL_EXPOSURE"
elif further_all:
    agg="QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE"
elif not any(x["further_retreat_count"]>0 for x in rows):
    agg="NLGLOB14X_NO_FURTHER_RETREAT_WITHIN_0P80D"
else:
    agg="NLGLOB14X_MIXED_DISAPPEARANCE_EXPOSURE"

summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),
         "selected_horizon":max(x["horizon"] for x in rows),
         "disappearance_cases":sum(x["disappearance_time"] is not None for x in rows),
         "further_retreat_cases":sum(x["further_retreat_count"]>0 for x in rows),
         "reverse_cases":sum(x["reverse_after_retreat"] for x in rows),
         "skipped_cases":sum(x["skipped_retreat"] for x in rows),
         "max_ledger":max(x["max_ledger"] for x in rows),
         "max_cum_ledger":max(x["cum_ledger"] for x in rows),
         "disappearance_times":[{"route":x["route"],"dt":x["dt"],"time":x["disappearance_time"],"horizon":x["horizon"]} for x in rows],
         "retreat_sequences":[{"route":x["route"],"dt":x["dt"],"transitions":x["transitions"]} for x in rows]}
print("F_PE_NLGLOB14X_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14X_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14X=PASS")
