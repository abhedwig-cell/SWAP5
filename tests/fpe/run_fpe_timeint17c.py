#!/usr/bin/env python3
import json, subprocess, sys
from collections import Counter
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
routes=("FLUX","HEAD","RUNOFF")
dts=[0.00025,0.000125,0.0000625,0.00003125]
horizon=0.001
dtop=10.0; pmax=0.05; rsro=0.05

def k_vg(m,h):
    mm=1.0-1.0/m["n"]
    se=(1.0+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1.0-(1.0-se**(1.0/mm))**mm
    return m["ksat"]*(se**m["lambda"])*(term**2)

def fixture(m,r):
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

def parse_pipe(line):
    return {k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}

def parse_trial(line):
    d=parse_pipe(line); out={}
    for k in ("STEP","EVALS","DISTINCT_ROUTES","ROUTE_TRANSITIONS","FIRST_ROUTE","LAST_ROUTE",
              "UNAVAILABLE","FLUX_COUNT","HEAD_COUNT","RUNOFF_COUNT","ATMOS_COUNT","OTHER_COUNT"):
        out[k.lower()]=int(d[k])
    for k in ("MIN_HEAD","MAX_HEAD","MIN_POND","MAX_POND","MIN_FLUX","MAX_FLUX"):
        out[k.lower()]=float(d[k])
    out["terminal_reason"]=d["TERMINAL_REASON"]
    return out

def parse_result(line):
    d=parse_pipe(line)
    return {"terminal_reason":d.get("TERMINAL_REASON","MISSING"),
            "eligible":int(d.get("ELIGIBLE","0")),
            "transition_step":int(d.get("TRANSITION_STEP","0")),
            "solver_status":int(d.get("SOLVER_STATUS","0"))}

def classify(row):
    if row["terminal_reason"]!="ENDPOINT_SOLVE_FAILURE":
        return "NON_ENDPOINT_TERMINAL"
    if row.get("unavailable",0)>0:
        return "PROVIDER_AVAILABILITY_FAILURE"
    if row.get("route_transitions",0)>0:
        return "INTERNAL_ROUTE_SWITCHING_ENDPOINT_FAILURE"
    if row.get("evals",0)>0 and row.get("distinct_routes",0)==1:
        return "STATIC_ROUTE_ENDPOINT_FAILURE"
    return "MIXED_OR_UNRESOLVED_ENDPOINT_FAILURE"

def run_one(mid,route,dt,mode):
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cmd=[str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"route":route,"dt":dt,"mode":mode,"h0":h0,"p0":p0,"rain":rain,
         "process_ok":cp.returncode==0}
    result_line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    trial_line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17C_TRIAL|")),None)
    if result_line: row.update(parse_result(result_line))
    else: row.update(terminal_reason="PROCESS_OR_OUTPUT_FAILURE",eligible=0,transition_step=0,solver_status=-1)
    if trial_line: row.update(parse_trial(trial_line))
    else:
        row.update(evals=0,distinct_routes=0,route_transitions=0,first_route=0,last_route=0,
                   unavailable=0,flux_count=0,head_count=0,runoff_count=0,atmos_count=0,other_count=0,
                   min_head=0.0,max_head=0.0,min_pond=0.0,max_pond=0.0,min_flux=0.0,max_flux=0.0)
    row["route_path_class"]=classify(row)
    if not row["process_ok"]:
        row["stdout"]=cp.stdout[-1200:]; row["stderr"]=cp.stderr[-1000:]
    return row

rows=[]
for mid in ("B01","B12","O05","O14"):
    for route in routes:
        for dt in dts:
            for mode in ("TG","KLAG"):
                rows.append(run_one(mid,route,dt,mode))

tg=[x for x in rows if x["mode"]=="TG"]
kl=[x for x in rows if x["mode"]=="KLAG"]
tg_ep=[x for x in tg if x["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE"]
counts=Counter(x["route_path_class"] for x in tg_ep)
n=len(tg_ep)
switch_frac=counts["INTERNAL_ROUTE_SWITCHING_ENDPOINT_FAILURE"]/n if n else 0.0
static_frac=counts["STATIC_ROUTE_ENDPOINT_FAILURE"]/n if n else 0.0
avail_frac=sum(x["unavailable"]>0 for x in tg_ep)/n if n else 0.0

if avail_frac>=0.50:
    classification="TIMEINT17C_PROVIDER_AVAILABILITY_DOMINANT"
elif switch_frac>=0.75:
    classification="TIMEINT17C_IN_NEWTON_ROUTE_SWITCH_DOMINANT"
elif static_frac>=0.75:
    classification="TIMEINT17C_STATIC_ROUTE_SOLVER_DOMINANT"
else:
    classification="TIMEINT17C_MIXED_ROUTE_PATH_BLOCKER"

key=lambda x:(x["material"],x["route"],x["dt"])
kmap={key(x):x for x in kl}
matched=0; same=0; pairs=[]
for t in tg_ep:
    q=kmap[key(t)]
    if q["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE":
        matched+=1
        eq=t["route_path_class"]==q["route_path_class"]
        same+=int(eq)
        pairs.append({"material":t["material"],"route":t["route"],"dt":t["dt"],
                      "tg_class":t["route_path_class"],"klag_class":q["route_path_class"],"same":eq})
shared_frac=same/n if n else 0.0
secondary="TIMEINT17C_SHARED_ROUTE_PATH_BLOCKER" if n and shared_frac>=0.75 else None

summary={
 "classification":classification,
 "secondary_classification":secondary,
 "tg_endpoint_failures":n,
 "tg_route_path_counts":dict(sorted(counts.items())),
 "route_switch_fraction":switch_frac,
 "static_route_fraction":static_frac,
 "provider_unavailable_fraction":avail_frac,
 "matched_klag_endpoint_failures":matched,
 "same_route_path_class_pairs":same,
 "shared_route_path_fraction":shared_frac,
 "tg_total_evaluations":sum(x["evals"] for x in tg_ep),
 "tg_total_route_transitions":sum(x["route_transitions"] for x in tg_ep),
 "process_failures":sum(not x["process_ok"] for x in rows)
}
print("F_PE_TIMEINT17C_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17C_PAIRED="+json.dumps(pairs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17C_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17C=PASS")
