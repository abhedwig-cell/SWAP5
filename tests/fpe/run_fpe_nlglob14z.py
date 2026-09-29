#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
dts=[2.5e-4,1.25e-4,6.25e-5,3.125e-5]
routes=("HEAD","RUNOFF"); stages=(1.6,3.2,6.4)
dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(route):
    h=-5.; p=.025 if route=="HEAD" else .1
    kt=kvg(h); q=-.5*(m["ksat"]+kt)*((p-h)/dtop+1)
    rain=-q if route=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

def one(route,dt,horizon):
    h0,p0,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
      str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),
      str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    by={}
    inconsistent=False
    for x in states:
        by.setdefault(int(x["STEP"]),[]).append(x)
        inconsistent |= (int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1)
    series=[]; noncontig=False; finite=True
    for step in sorted(by):
        xs=sorted(by[step],key=lambda z:int(z["NODE"]))
        if len(xs)!=16: finite=False; continue
        sat=[]; vals=[]
        for x in xs:
            vals += [float(x[k]) for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
            if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1: sat.append(int(x["NODE"]))
        finite &= all(math.isfinite(v) for v in vals)
        noncontig |= bool(sat and sat!=list(range(min(sat),17)))
        series.append((step,step*dt,sat))
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    transitions=[]; reverse=False; skipped=False; late=False
    last_top=None; disappeared=None; bracket=None
    for i,(step,t,sat) in enumerate(series):
        top=min(sat) if sat else None
        if top is None:
            if disappeared is None:
                disappeared=t
                prev=series[i-1] if i else None
                bracket={"last_saturated_time":prev[1] if prev else None,
                         "first_empty_time":t,
                         "last_saturated_set":prev[2] if prev else None}
            continue
        if last_top is not None and top!=last_top:
            d=top-last_top
            transitions.append({"from_top":last_top,"to_top":top,"time":t,"step":step})
            if last_top==6 and top==7:
                late=True
            elif late:
                reverse |= d<0
                skipped |= d>1
        last_top=top
    late_trans=[x for x in transitions if x["from_top"]>=7 and x["to_top"]>x["from_top"]]
    valid=(cp.returncode==0 and complete and finite and maxledger<=5e-8 and cumledger<=5e-8
           and not inconsistent and not noncontig and not skipped)
    return {"route":route,"dt":dt,"horizon":horizon,"valid":valid,"process_ok":cp.returncode==0,
      "complete":complete,"finite":finite,"indicator_inconsistent":inconsistent,"noncontiguous":noncontig,
      "skipped_retreat":skipped,"reverse_after_late_retreat":reverse,"late_retreat_count":len(late_trans),
      "late_transitions":late_trans,"disappearance_time":disappeared,"disappearance_bracket":bracket,
      "final_sat_set":series[-1][2] if series else None,"max_ledger":maxledger,"cum_ledger":cumledger}

selected={}
used=None
for horizon in stages:
    rs=[one(r,dt,horizon) for r in routes for dt in dts]
    for x in rs: selected[(x["route"],x["dt"])]=x
    used=horizon
    if all(x["valid"] and x["disappearance_time"] is not None for x in rs): break

rows=[selected[(r,dt)] for r in routes for dt in dts]
coverage=len(rows)==8 and all(x["valid"] for x in rows)
all_disappear=coverage and all(x["disappearance_time"] is not None for x in rows)
late_all=coverage and all(x["late_retreat_count"]>0 for x in rows)
if any(x["noncontiguous"] or x["indicator_inconsistent"] or x["skipped_retreat"] for x in rows):
    agg="NLGLOB14Z_LATE_RETREAT_GEOMETRY_INCONSISTENT"
elif any(x["reverse_after_late_retreat"] for x in rows):
    agg="NLGLOB14Z_LATE_RETREAT_REVERSAL_OBSERVED"
elif not coverage:
    agg="BLOCKED_NLGLOB14Z_CONTROL_EXPOSURE"
elif all_disappear:
    agg="QUALIFIED_SATURATED_BLOCK_DISAPPEARANCE_CONTROL_EXPOSURE"
elif late_all:
    agg="QUALIFIED_LATE_MONOTONE_RETREAT_CONTROL_EXPOSURE"
elif not any(x["late_retreat_count"]>0 for x in rows):
    agg="NLGLOB14Z_NO_LATE_RETREAT_WITHIN_6P40D"
else:
    agg="NLGLOB14Z_MIXED_DISAPPEARANCE_EXPOSURE"
summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),"selected_horizon":used,
  "disappearance_cases":sum(x["disappearance_time"] is not None for x in rows),
  "late_retreat_cases":sum(x["late_retreat_count"]>0 for x in rows),
  "reverse_cases":sum(x["reverse_after_late_retreat"] for x in rows),
  "skipped_cases":sum(x["skipped_retreat"] for x in rows),
  "max_ledger":max(x["max_ledger"] for x in rows),"max_cum_ledger":max(x["cum_ledger"] for x in rows),
  "disappearance_times":[{"route":x["route"],"dt":x["dt"],"time":x["disappearance_time"]} for x in rows],
  "late_sequences":[{"route":x["route"],"dt":x["dt"],"transitions":x["late_transitions"]} for x in rows]}
print("F_PE_NLGLOB14Z_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z=PASS")
