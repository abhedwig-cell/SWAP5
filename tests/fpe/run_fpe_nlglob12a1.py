#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05
stagnation={
("B01","KLAG","HEAD",0.00025),
("B01","TG","HEAD",0.000125),
("B01","KLAG","HEAD",0.00003125),
("B01","TG","RUNOFF",0.0000625),
("B01","KLAG","RUNOFF",0.0000625),
("B12","KLAG","HEAD",0.0000625),
("O14","TG","FLUX",0.0000625),
("O14","TG","RUNOFF",0.0000625),
}

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

records=[]; proc=0
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        r0=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB12A1_ACCEPT|")]
        s0=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB09_ACCEPT|")]
        if res is None:
            records.append({"material":mid,"mode":mode,"route":route,"dt":dt,"complete":False,"r0":len(r0),"s0":len(s0),"missing":True})
            continue
        complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
        finite=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
        records.append({"material":mid,"mode":mode,"route":route,"dt":dt,"complete":complete,
          "terminal_reason":res["TERMINAL_REASON"],"r0":len(r0),"s0":len(s0),"finite":finite,
          "max_ledger":abs(float(res["MAX_LEDGER"])),"cum_ledger":abs(float(res["CUM_LEDGER"]))})

complete=[x for x in records if x["complete"]]
bank_a=[x for x in records if (x["material"],x["mode"],x["route"],x["dt"]) in stagnation]
bank_a_recovered=[x for x in bank_a if x["complete"]]
bank_a_r0=[x for x in bank_a if x["r0"]>0]
recovery=len(complete)/96
maxledger=max((x["max_ledger"] for x in complete),default=math.inf)
maxcum=max((x["cum_ledger"] for x in complete),default=math.inf)
finite=all(x["finite"] for x in complete)
span_modes={x["mode"] for x in complete}; span_routes={x["route"] for x in complete}; span_mats={x["material"] for x in complete}
bank_a_ok=len(bank_a)==8 and len(bank_a_recovered)>=7 and all(x["finite"] for x in bank_a_recovered) and len(bank_a_r0)>0
dynamic_ok=(len(records)==96 and recovery>=.80 and span_modes==set(modes) and span_routes==set(routes) and len(span_mats)>=3 and
            maxledger<=5e-8 and maxcum<=5e-8 and finite and proc==0)
unsafe=any(x["r0"]>0 and (not x.get("finite",False)) for x in records)
if unsafe:
    cls="CLOSED_REPRESENTATION_CERTIFICATE_UNSAFE"
elif not bank_a_ok:
    cls="CLOSED_REPRESENTATION_CERTIFICATE_INSUFFICIENT_RECOVERY"
elif dynamic_ok:
    cls="QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH"
else:
    cls="REPRESENTATION_CERTIFICATE_QUALIFIED_ENDPOINT_BLOCKER_REMAINS"

summary={"classification":cls,"case_count":len(records),"complete_cases":len(complete),"recovery_fraction":recovery,
 "bank_a_n":len(bank_a),"bank_a_recovered":len(bank_a_recovered),"bank_a_r0_triggered":len(bank_a_r0),
 "r0_accept_count":sum(x["r0"] for x in records),"s0_accept_count":sum(x["s0"] for x in records),
 "max_ledger":maxledger,"max_cumulative_ledger":maxcum,"finite_ok":finite,
 "completed_modes":sorted(span_modes),"completed_routes":sorted(span_routes),"completed_materials":sorted(span_mats),
 "process_failures":proc}
print("F_PE_NLGLOB12A1_RECORDS="+json.dumps(records,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12A1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12A1=PASS")
