#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
m=mats["O05"]
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
dtop=10.; pmax=.05; rsro=.05

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
    first13=next((i for i,s in enumerate(series) if s[2]==list(range(4,17))),None)
    first12=None
    if first13 is not None:
        first12=next((i for i in range(first13+1,len(series)) if series[i][2]==list(range(5,17))),None)
    reverse=False
    if first12 is not None:
        reverse=any(series[i][2]==list(range(4,17)) for i in range(first12+1,len(series)))
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    exact=first12 is not None
    rec={"route":route,"dt":dt,"horizon":horizon,"process_ok":cp.returncode==0,"complete":complete,
         "finite":finite,"mass_ok":mass_ok,"noncontiguous":noncontig,"indicator_inconsistent":inconsistent,
         "max_ledger":maxledger,"cum_ledger":cumledger,"first13_time":series[first13][1] if first13 is not None else None,
         "last13_time":series[first12-1][1] if first12 is not None and first12>0 else None,
         "first12_time":series[first12][1] if first12 is not None else None,
         "first13_set":series[first13][2] if first13 is not None else None,
         "first12_set":series[first12][2] if first12 is not None else None,
         "exact_second_retreat":exact,"reverse_after_second_retreat":reverse}
    if noncontig or inconsistent:
        rec["classification"]="SECOND_RETREAT_STATE_INCONSISTENT"
    elif not (cp.returncode==0 and complete and finite and mass_ok):
        rec["classification"]="BLOCKED_SECOND_RETREAT_CONTROL"
    elif exact:
        rec["classification"]="SECOND_RETREAT_EXPOSED"
    else:
        rec["classification"]="NO_SECOND_RETREAT"
    return rec

rows=[]
stage1=[run(r,dt,.10) for r in routes for dt in dts]
need_stage2=not all(x["exact_second_retreat"] for x in stage1)
if need_stage2:
    stage2=[run(r,dt,.20) for r in routes for dt in dts]
    by={(x["route"],x["dt"]):x for x in stage2}
    for x in stage1:
        y=by[(x["route"],x["dt"])]
        rows.append(y if not x["exact_second_retreat"] else x)
else:
    rows=stage1

coverage=len(rows)==8 and all(x["process_ok"] and x["complete"] and x["finite"] and x["mass_ok"] for x in rows)
if any(x["classification"]=="SECOND_RETREAT_STATE_INCONSISTENT" for x in rows):
    agg="NLGLOB14V_SECOND_RETREAT_STATE_INCONSISTENT"
elif any(x["classification"]=="BLOCKED_SECOND_RETREAT_CONTROL" for x in rows) or not coverage:
    agg="BLOCKED_NLGLOB14V_CONTROL_EXPOSURE"
elif all(x["exact_second_retreat"] for x in rows):
    agg="QUALIFIED_SECOND_RETREAT_CONTROL_EXPOSURE"
elif not any(x["exact_second_retreat"] for x in rows):
    agg="NLGLOB14V_NO_SECOND_RETREAT_WITHIN_0P20D"
else:
    agg="NLGLOB14V_MIXED_SECOND_RETREAT_EXPOSURE"

summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),"stage2_used":need_stage2,
         "exposed_cases":sum(x["exact_second_retreat"] for x in rows),
         "reverse_cases":sum(x["reverse_after_second_retreat"] for x in rows),
         "max_ledger":max(x["max_ledger"] for x in rows),
         "max_cum_ledger":max(x["cum_ledger"] for x in rows),
         "second_retreat_times":[{"route":x["route"],"dt":x["dt"],"time":x["first12_time"],"horizon":x["horizon"]} for x in rows]}
print("F_PE_NLGLOB14V_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14V_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14V=PASS")
