#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
dt=1.5625e-5; horizon=2.8; dtop=10.; pmax=.05; rsro=.05

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

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

rows=[]; proc=0
for route in ("HEAD","RUNOFF"):
    h0,p0,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
      str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),
      str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    lines=cp.stdout.splitlines()

    nominal=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z3_NOMINAL_RETRY|")]
    rollback=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z3_ROLLBACK|")]
    halves=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z3_HALF|")]
    recovered=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z3_RECOVERED|")]
    states=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    bystep={}
    inconsistent=False
    for x in states:
        bystep.setdefault(int(x["STEP"]),[]).append(x)
        inconsistent |= (int(x["SAT_H"])==1)!=(int(x["SAT_THETA"])==1)

    series=[]; noncontig=False; finite=True
    for step in sorted(bystep):
        xs=sorted(bystep[step],key=lambda z:int(z["NODE"]))
        if len(xs)!=16:
            finite=False; continue
        sat=[]; vals=[]
        for x in xs:
            vals += [float(x[k]) for k in ("H","THETA","THETA_S","POND","TOP_FLUX","BOTTOM_FLUX")]
            if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1:
                sat.append(int(x["NODE"]))
        finite &= all(math.isfinite(v) for v in vals)
        noncontig |= bool(sat and sat!=list(range(min(sat),17)))
        series.append((step,step*dt,sat))

    reverse=False; skipped=False; late=False; first8=None; last7=None
    prev_top=None; pre=None; post=None
    for step,t,sat in series:
        top=min(sat) if sat else None
        if prev_top is not None and top is not None and top!=prev_top:
            delta=top-prev_top
            if prev_top==6 and top==7:
                late=True
            elif late:
                if delta<0: reverse=True
                if delta>1: skipped=True
        if late:
            if sat==list(range(7,17)):
                last7=t; pre=(step,t,sat)
            if first8 is None and sat==list(range(8,17)):
                first8=t; post=(step,t,sat)
        prev_top=top

    rb_ok=(len(rollback)==len(nominal) and len(nominal)>0 and all(
        all(abs(float(r[k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF"))
        for r in rollback))
    halves_by={}
    for h in halves:
        halves_by.setdefault(int(h["STEP"]),[]).append(h)
    half_retry=any(int(h["RETRY"])==1 for h in halves)
    half_hard=any(int(h["ELIGIBLE"])!=1 and int(h["RETRY"])!=1 for h in halves)
    half_ok=(len(halves)==2*len(nominal) and all(
        len(v)==2 and sorted(int(x["HALF"]) for x in v)==[1,2] and
        all(int(x["ELIGIBLE"])==1 and int(x["RETRY"])==0 and
            math.isclose(float(x["DT"]),.5*dt,rel_tol=0,abs_tol=1e-15) for x in v)
        for v in halves_by.values()))
    recovered_ok=(len(recovered)==len(nominal) and [int(x["COUNT"]) for x in recovered]==list(range(1,len(recovered)+1)))

    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    maxledger=abs(float(res["MAX_LEDGER"])) if res else math.inf
    cumledger=abs(float(res["CUM_LEDGER"])) if res else math.inf
    mass_ok=maxledger<=5e-8 and cumledger<=5e-8
    event_ok=bool(post and pre and pre[2]==list(range(7,17)) and post[2]==list(range(8,17)))
    state_ok=finite and not inconsistent and not noncontig and not reverse and not skipped

    if not rb_ok or not mass_ok:
        cls="REPAIRED_TRAJECTORY_TRANSACTION_INCONSISTENT"
    elif half_retry:
        cls="BOUNDED_RECOVERY_DEPTH_INSUFFICIENT"
    elif half_hard or not half_ok or not recovered_ok:
        cls="REPAIRED_TRAJECTORY_HARD_FAILURE"
    elif complete and event_ok and state_ok:
        cls="REPAIRED_FINEST_TRAJECTORY_REACHES_LATE_RETREAT"
    elif complete and state_ok:
        cls="REPEATED_LOCAL_RECOVERY_BUT_LATE_RETREAT_NOT_REACHED"
    else:
        cls="REPAIRED_TRAJECTORY_HARD_FAILURE"

    rows.append({"route":route,"dt":dt,"horizon":horizon,"classification":cls,
        "process_ok":cp.returncode==0,"nominal_retry_count":len(nominal),
        "nominal_retry_steps":[int(x["STEP"]) for x in nominal],
        "nominal_retry_counts":[int(x["COUNT"]) for x in nominal],
        "rollback_count":len(rollback),"rollback_ok":rb_ok,
        "half_count":len(halves),"half_ok":half_ok,"half_retry":half_retry,"half_hard":half_hard,
        "recovered_count":len(recovered),"recovered_ok":recovered_ok,
        "complete":complete,"terminal_reason":res.get("TERMINAL_REASON") if res else None,
        "solver_status":int(res["SOLVER_STATUS"]) if res else None,
        "max_ledger":maxledger,"cum_ledger":cumledger,"mass_ok":mass_ok,
        "finite":finite,"indicator_inconsistent":inconsistent,"noncontiguous":noncontig,
        "reverse":reverse,"skipped":skipped,
        "last7_time":pre[1] if pre else last7,"first8_time":post[1] if post else first8,
        "pre_set":pre[2] if pre else None,"post_set":post[2] if post else None})

classes=[x["classification"] for x in rows]
coverage=len(rows)==2 and proc==0
if any(x=="REPAIRED_TRAJECTORY_TRANSACTION_INCONSISTENT" for x in classes):
    agg="NLGLOB14Z3_REPAIRED_TRANSACTION_INCONSISTENT"
elif any(x=="BOUNDED_RECOVERY_DEPTH_INSUFFICIENT" for x in classes):
    agg="NLGLOB14Z3_BOUNDED_RECOVERY_DEPTH_INSUFFICIENT"
elif coverage and all(x=="REPAIRED_FINEST_TRAJECTORY_REACHES_LATE_RETREAT" for x in classes):
    agg="QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY"
elif coverage and all(x=="REPEATED_LOCAL_RECOVERY_BUT_LATE_RETREAT_NOT_REACHED" for x in classes):
    agg="NLGLOB14Z3_LATE_RETREAT_NOT_REACHED"
else:
    agg="NLGLOB14Z3_MIXED_REPAIRED_TRAJECTORY"

summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "qualified_cases":sum(x=="REPAIRED_FINEST_TRAJECTORY_REACHES_LATE_RETREAT" for x in classes),
         "total_nominal_retries":sum(x["nominal_retry_count"] for x in rows),
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cum_ledger":max((x["cum_ledger"] for x in rows),default=math.inf),
         "event_times":[{"route":x["route"],"time":x["first8_time"]} for x in rows]}
print("F_PE_NLGLOB14Z3_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z3_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z3=PASS")
