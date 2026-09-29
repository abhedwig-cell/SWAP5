#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
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
        reason=res["TERMINAL_REASON"] if res else "MISSING"
        rec={"material":mid,"route":route,"mode":mode,"dt":dt,"reason":reason}
        if res is None:
          rec["returncode"]=cp.returncode
          rec["stderr_tail"]="\\n".join(cp.stderr.splitlines()[-6:])
          rec["stdout_tail"]="\\n".join(cp.stdout.splitlines()[-6:])
        if res:
          rec.update({"eligible":int(res["ELIGIBLE"])==1,"max_ledger":abs(float(res["MAX_LEDGER"])),
                      "cum_ledger":abs(float(res["CUM_LEDGER"])),"top_theta":float(res["TOP_THETA"]),
                      "work":int(res["WORK"])})
        records.append(rec)

pred_fail=[x for x in records if x["reason"]=="PREDICTED_RETENTION_DOMAIN_FAILED"]
complete=[x for x in records if x["reason"]=="COMPLETE_SAME_ROUTE" and x.get("eligible")]
maxledger=max((x.get("max_ledger",0.0) for x in complete),default=math.inf)
maxcum=max((x.get("cum_ledger",0.0) for x in complete),default=math.inf)
summary={"predictor_domain_failures":len(pred_fail),"complete_cases":len(complete),"case_count":len(records),
         "max_ledger":maxledger,"max_cumulative_ledger":maxcum,"process_failures":proc,
         "remaining_reasons":{r:sum(x["reason"]==r for x in records) for r in sorted(set(x["reason"] for x in records))}}
print("F_PE_NLGLOB11_DYNAMIC_RECORDS="+json.dumps(records,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB11_DYNAMIC_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB11_DYNAMIC=PASS")
