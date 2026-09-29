#!/usr/bin/env python3
import json, subprocess, sys
from collections import Counter
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
routes=("FLUX","HEAD","RUNOFF")

A={
 "name":"A","horizon":0.010,
 "dts":[0.0025,0.00125,0.000625,0.0003125],
 "fixture":lambda m,r: {
   "FLUX":(-50.0,0.0,2.0),
   "HEAD":(-5.0,0.020,12.0),
   "RUNOFF":(-5.0,0.080,25.0)}[r]
}

def k_vg(m,h):
    mm=1.0-1.0/m["n"]
    se=(1.0+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1.0-(1.0-se**(1.0/mm))**mm
    return m["ksat"]*(se**m["lambda"])*(term**2)

def fixture_a2(m,r):
    dtop=10.0; pmax=0.05; rsro=0.05
    if r=="FLUX":
        h=-50.0; p=0.0
        kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
        qhead=-kf*((p-h)/dtop+1.0)
        return h,p,0.25*(-qhead)
    if r=="HEAD":
        h=-5.0; p=0.025
        kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
        qhead=-kf*((p-h)/dtop+1.0)
        return h,p,-qhead
    h=-5.0; p=0.100
    kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
    qhead=-kf*((p-h)/dtop+1.0)
    return h,p,-qhead+(p-pmax)/rsro

A2={"name":"A2","horizon":0.001,
    "dts":[0.00025,0.000125,0.0000625,0.00003125],
    "fixture":fixture_a2}

def parse_result(line):
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    out={}
    for k in ("ELIGIBLE","TRANSITION_STEP","STEPS_DONE","NL","BACK","JAC","LIN","WORK",
              "SOLVER_STATUS","ORIGIN_ROUTE_CODE","PRED_ROUTE_CODE","ENDPOINT_ROUTE_CODE","ACCEPT_ROUTE_CODE"):
        if k in d: out[k.lower()]=int(d[k])
    for k in ("TOP_H","TOP_THETA","POND","MAX_LEDGER","CUM_LEDGER","MAX_NATIVE_RATE","MAX_SURFACE_RATE_RESIDUAL","MAX_K_SHIFT"):
        if k in d: out[k.lower()]=float(d[k])
    out["terminal_reason"]=d.get("TERMINAL_REASON","MISSING_TERMINAL_REASON")
    return out

def run_one(bankdef,mid,route,dt,mode):
    m=mats[mid]; h0,p0,rain=bankdef["fixture"](m,route)
    cmd=[str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(bankdef["horizon"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"bank":bankdef["name"],"material":mid,"route":route,"dt":dt,"mode":mode,
         "h0":h0,"p0":p0,"rain":rain,"process_ok":cp.returncode==0}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    if line:
        row.update(parse_result(line))
    else:
        row["terminal_reason"]="PROCESS_OR_OUTPUT_FAILURE"
        row["stdout"]=cp.stdout[-1000:]; row["stderr"]=cp.stderr[-1000:]
    return row

rows=[]
for b in (A,A2):
    for mid in ("B01","B12","O05","O14"):
        for route in routes:
            for dt in b["dts"]:
                for mode in ("TG","KLAG"):
                    rows.append(run_one(b,mid,route,dt,mode))

tg=[x for x in rows if x["mode"]=="TG"]
kl=[x for x in rows if x["mode"]=="KLAG"]
ineligible=[x for x in tg if x.get("terminal_reason")!="COMPLETE_SAME_ROUTE"]
counts=Counter(x.get("terminal_reason","MISSING") for x in ineligible)
route_reasons={
 "ORIGIN_ROUTE_MISMATCH","FORWARD_PREDICTOR_ROUTE_MISMATCH",
 "ENDPOINT_PROVIDER_ROUTE_MISMATCH","ENDPOINT_INSTANTANEOUS_ROUTE_MISMATCH",
 "ACCEPTED_ROUTE_MISMATCH"
}
solver_n=counts["ENDPOINT_SOLVE_FAILED"]
route_n=sum(counts[k] for k in route_reasons)
n=len(ineligible)
solver_frac=solver_n/n if n else 0.0
route_frac=route_n/n if n else 0.0

paired=[]
tg_specific=0; shared_solver=0
key=lambda x:(x["bank"],x["material"],x["route"],x["dt"])
kmap={key(x):x for x in kl}
for t in tg:
    q=kmap[key(t)]
    signal="NONE"
    if t.get("terminal_reason")=="ENDPOINT_SOLVE_FAILED":
        if q.get("terminal_reason")=="COMPLETE_SAME_ROUTE":
            signal="TG_SPECIFIC_ENDPOINT_ROBUSTNESS_SIGNAL"; tg_specific+=1
        elif q.get("terminal_reason")=="ENDPOINT_SOLVE_FAILED":
            signal="SHARED_DYNAMIC_TOP_SOLVER_SIGNAL"; shared_solver+=1
    paired.append({"bank":t["bank"],"material":t["material"],"route":t["route"],"dt":t["dt"],
                   "tg_reason":t.get("terminal_reason"),"klag_reason":q.get("terminal_reason"),"signal":signal})

# Frozen dominance rules from TIMEINT17B preregistration.
# Event dominance additionally requires converged evidence spanning onset and
# release/runoff transition families; route-code mismatches alone are not enough.
converged_route_rows=[x for x in ineligible if x.get("terminal_reason") in route_reasons]
onset_evidence=any(x.get("route")=="FLUX" and x.get("terminal_reason") in route_reasons for x in converged_route_rows)
release_or_runoff_evidence=any(x.get("route") in ("HEAD","RUNOFF") and x.get("terminal_reason") in route_reasons for x in converged_route_rows)
event_span_ok=onset_evidence and release_or_runoff_evidence

if solver_frac>0.50:
    classification="TIMEINT17B_ENDPOINT_SOLVER_DOMINANT"
elif route_frac>=0.75 and solver_frac<=0.25 and event_span_ok:
    classification="TIMEINT17B_EVENT_DOMINANT"
else:
    classification="TIMEINT17B_MIXED_ENDPOINT_AND_EVENT_BLOCKER"

shared_fraction=(shared_solver/solver_n) if solver_n else 0.0
secondary=("TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER" if solver_n>0 and shared_fraction>=0.75 else None)
mass_ok=all(abs(x.get("max_ledger",0.0))<=5e-8 and abs(x.get("cum_ledger",0.0))<=5e-8 for x in tg)
if not mass_ok:
    classification="BLOCKED_TIMEINT17B_ACCEPTED_MASS"

summary={
 "classification":classification,
 "secondary_classification":secondary,
 "tg_runs":len(tg),
 "tg_complete_same_route":sum(x.get("terminal_reason")=="COMPLETE_SAME_ROUTE" for x in tg),
 "tg_ineligible":n,
 "terminal_counts":dict(sorted(counts.items())),
 "endpoint_solver_fraction":solver_frac,
 "route_event_fraction":route_frac,
 "tg_specific_endpoint_signals":tg_specific,
 "shared_dynamic_top_solver_signals":shared_solver,
 "shared_endpoint_failure_fraction":shared_fraction,
 "event_span_ok":event_span_ok,
 "onset_evidence":onset_evidence,
 "release_or_runoff_evidence":release_or_runoff_evidence,
 "accepted_mass_ok":mass_ok,
 "process_failures":sum(not x["process_ok"] for x in rows)
}
print("F_PE_TIMEINT17B_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17B_PAIRED="+json.dumps(paired,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17B=PASS")
