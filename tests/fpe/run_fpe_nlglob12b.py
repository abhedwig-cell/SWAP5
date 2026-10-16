#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("B12","HEAD","TG",0.000125),
 ("O05","HEAD","TG",0.00003125),
 ("O14","HEAD","TG",0.0000625),
 ("O14","HEAD","KLAG",0.0000625),
 ("O14","HEAD","TG",0.00003125),
 ("O14","RUNOFF","KLAG",0.00003125),
]
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    if r=="FLUX":
        h=-50.;p=0.;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=.25*(-q)
    elif r=="HEAD":
        h=-5.;p=.025;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q
    else:
        h=-5.;p=.1;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q+(p-pmax)/rsro
    return h,p,rain
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

rows=[]; proc=0
for mid,route,mode,dt in cases:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    accepts=sum(x.startswith("F_PE_NLGLOB09_ACCEPT|") for x in cp.stdout.splitlines())
    if res is None:
        rows.append({"material":mid,"route":route,"mode":mode,"dt":dt,"complete":False,"missing":True,"accepts":accepts}); continue
    complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
    finite=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
    rows.append({"material":mid,"route":route,"mode":mode,"dt":dt,"complete":complete,
      "terminal_reason":res["TERMINAL_REASON"],"accepts":accepts,"finite":finite,
      "max_ledger":abs(float(res["MAX_LEDGER"])),"cum_ledger":abs(float(res["CUM_LEDGER"])),
      "work":int(res["WORK"]),"nl":int(res["NL"]),"back":int(res["BACK"])})

complete=[x for x in rows if x.get("complete")]
n=len(complete)
mass_ok=all(x["max_ledger"]<=5e-8 and x["cum_ledger"]<=5e-8 for x in complete)
finite_ok=all(x["finite"] for x in complete)
if not mass_ok or not finite_ok:
    cls="NLGLOB12B_EXTRA_ITERATION_PHYSICAL_ADMISSIBILITY_FAILED"
elif n>=5:
    cls="NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_SUPPORTED"
elif n<=3:
    cls="NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_FALSIFIED"
else:
    cls="NLGLOB12B_MIXED_EXTRA_ITERATION_SIGNAL"
summary={"classification":cls,"case_count":len(rows),"complete_cases":n,"mass_ok":mass_ok,"finite_ok":finite_ok,
         "process_failures":proc,"max_ledger":max((x.get("max_ledger",0) for x in complete),default=0),
         "max_cumulative_ledger":max((x.get("cum_ledger",0) for x in complete),default=0)}
print("F_PE_NLGLOB12B_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12B=PASS")
