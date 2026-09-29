#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("O05","HEAD",0.00025),
 ("O05","HEAD",0.000125),
 ("O05","HEAD",0.0000625),
 ("O05","RUNOFF",0.00025),
 ("O05","RUNOFF",0.000125),
]
horizon=.004; dtop=10.; pmax=.05; rsro=.05

def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    if r=="HEAD":
        h=-5.;p=.025;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q
    elif r=="RUNOFF":
        h=-5.;p=.1;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q+(p-pmax)/rsro
    else:
        raise ValueError(r)
    return h,p,rain
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

rows=[]; proc=0
for mid,route,dt in cases:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,"TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    rel=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB15_RELEASE|")]
    entries=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|") and "ENTRY=1" in x]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    elig=[i for i,x in enumerate(rel) if int(x["ELIGIBLE"])==1]
    first=elig[0] if elig else None
    persisted=False
    if first is not None and first+1<len(rel):
        persisted=(float(rel[first+1]["DELTA"])>float(rel[first+1]["U"]))
    safe=True
    for x in rel:
        vals=[float(x[k]) for k in ("THETA","THETA_S","DELTA","U","R_UNSAT","MASS_LEDGER")]
        safe=safe and all(math.isfinite(v) for v in vals) and float(x["MASS_LEDGER"])<=5e-8
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    rows.append({"material":mid,"route":route,"dt":dt,"process_ok":cp.returncode==0,"entry_count":len(entries),
                 "release_records":len(rel),"ever_release_eligible":first is not None,
                 "release_persists_next_interval":persisted,"safe":safe,"complete":complete,
                 "terminal_reason":res["TERMINAL_REASON"] if res else "MISSING_RESULT",
                 "first_release_step":int(rel[first]["STEP"]) if first is not None else None,
                 "first_release_ratio":float(rel[first]["R_UNSAT"]) if first is not None else None})

coverage=(len(rows)==5 and proc==0 and all(x["entry_count"]>=1 and x["release_records"]>=1 for x in rows))
unsafe=any(x["ever_release_eligible"] and not x["safe"] for x in rows)
positive=sum(x["ever_release_eligible"] and x["release_persists_next_interval"] and x["safe"] for x in rows)
if not coverage:
    cls="BLOCKED_NLGLOB15_RELEASE_COVERAGE"
elif unsafe:
    cls="NLGLOB15_RELEASE_SIGNAL_UNSAFE"
elif positive>=4:
    cls="NLGLOB15_REPRESENTATIONAL_RELEASE_SIGNAL"
elif positive<=1:
    cls="NLGLOB15_NO_RELEASE_SIGNAL"
else:
    cls="NLGLOB15_MIXED_RELEASE_SIGNAL"
summary={"classification":cls,"case_count":len(rows),"coverage_ok":coverage,"positive_release_cases":positive,
         "ever_release_eligible_cases":sum(x["ever_release_eligible"] for x in rows),
         "persistent_release_cases":sum(x["release_persists_next_interval"] for x in rows),
         "complete_cases":sum(x["complete"] for x in rows),"process_failures":proc}
print("F_PE_NLGLOB15_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB15_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB15=PASS")
