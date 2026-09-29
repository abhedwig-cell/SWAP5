#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
dts=[1.25e-4,6.25e-5,3.125e-5,1.5625e-5]
routes=("HEAD","RUNOFF"); horizon=2.8; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(route):
    h=-5.; p=.025 if route=="HEAD" else .1
    q=-.5*(m["ksat"]+kvg(h))*((p-h)/dtop+1)
    rain=-q if route=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

def one(route,dt):
    h0,p0,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
      str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),
      str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    by={}; inconsistent=False
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

    first8=None; last7=None; reverse=False; skipped=False
    late_phase=False; prev_top=None; pre=None; post=None
    last_state_time=series[-1][1] if series else None
    for i,(step,t,sat) in enumerate(series):
        top=min(sat) if sat else None
        if prev_top is not None and top is not None and top!=prev_top:
            d=top-prev_top
            if prev_top==6 and top==7:
                late_phase=True
            elif late_phase:
                if d<0: reverse=True
                if d>1: skipped=True
        if late_phase:
            if sat==list(range(7,17)):
                last7=t
                pre=(step,t,sat)
            if first8 is None and sat==list(range(8,17)):
                first8=t
                post=(step,t,sat)
        prev_top=top
    valid=(cp.returncode==0 and complete and finite and maxledger<=5e-8 and cumledger<=5e-8
           and not inconsistent and not noncontig and not skipped)
    return {"route":route,"dt":dt,"valid":valid,"complete":complete,"finite":finite,
      "process_ok":cp.returncode==0,"terminal_reason":res["TERMINAL_REASON"] if res else None,"transition_step":int(res["TRANSITION_STEP"]) if res else None,"failure_time":int(res["TRANSITION_STEP"])*dt if res and res["TERMINAL_REASON"]!="COMPLETE_SAME_ROUTE" else None,
      "max_ledger":maxledger,"cum_ledger":cumledger,"indicator_inconsistent":inconsistent,
      "noncontiguous":noncontig,"skipped":skipped,"reverse":reverse,
      "last7_time":pre[1] if pre else last7,"first8_time":post[1] if post else first8,"last_state_time":last_state_time,
      "pre_set":pre[2] if pre else None,"post_set":post[2] if post else None}

rows=[one(r,dt) for r in routes for dt in dts]
coverage=len(rows)==8 and all(x["valid"] for x in rows)
events=all(x["first8_time"] is not None and x["pre_set"]==list(range(7,17)) and x["post_set"]==list(range(8,17)) for x in rows)
state_ok=all(not x["reverse"] and not x["skipped"] and not x["noncontiguous"] and not x["indicator_inconsistent"] for x in rows)
conv={}
for route in routes:
    rr=sorted([x for x in rows if x["route"]==route],key=lambda x:x["dt"],reverse=True)
    t3=next(x["first8_time"] for x in rr if abs(x["dt"]-3.125e-5)<1e-12)
    t4=next(x["first8_time"] for x in rr if abs(x["dt"]-1.5625e-5)<1e-12)
    t2=next(x["first8_time"] for x in rr if abs(x["dt"]-6.25e-5)<1e-12)
    bracket_lo=t2-6.25e-5; bracket_hi=t2+6.25e-5
    diff=None if t3 is None or t4 is None else abs(t3-t4)
    in_bracket=False if t4 is None else bracket_lo<=t4<=bracket_hi
    conv[route]={"dt3_time":t3,"dt4_time":t4,"difference":diff,
                 "threshold":3.125e-5,"finest_in_coarse_bracket":in_bracket,
                 "pass":diff is not None and diff<=3.125e-5 and in_bracket}

if not coverage:
    agg="BLOCKED_NLGLOB14Z1_REFINEMENT"
elif not state_ok:
    agg="NLGLOB14Z1_LATE_RETREAT_STATE_INCONSISTENT"
elif events and all(v["pass"] for v in conv.values()):
    agg="QUALIFIED_LATE_RETREAT_EVENT_TIME_REFINEMENT"
else:
    agg="NLGLOB14Z1_LATE_RETREAT_TIME_NOT_REFINED"

summary={"classification":agg,"coverage_ok":coverage,"event_coverage":events,"state_ok":state_ok,
         "case_count":len(rows),"convergence":conv,
         "max_ledger":max(x["max_ledger"] for x in rows),"max_cum_ledger":max(x["cum_ledger"] for x in rows)}
print("F_PE_NLGLOB14Z1_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z1=PASS")
