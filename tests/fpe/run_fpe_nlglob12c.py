#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05
stagnation={
 ("B01","HEAD","KLAG",0.00025),
 ("B01","HEAD","TG",0.000125),
 ("B01","HEAD","KLAG",0.00003125),
 ("B01","RUNOFF","TG",0.0000625),
 ("B01","RUNOFF","KLAG",0.0000625),
 ("B12","HEAD","KLAG",0.0000625),
 ("O14","FLUX","TG",0.0000625),
 ("O14","RUNOFF","TG",0.0000625),
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

records=[]; proc=0; rep_accepts=[]
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        s0=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB09_ACCEPT|")]
        ra=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB12C_ACCEPT|")]
        rep_accepts.extend(ra)
        key=(mid,route,mode,dt)
        if result is None:
          records.append({"material":mid,"route":route,"mode":mode,"dt":dt,"complete":False,"missing":True,
                          "s0_accepts":len(s0),"rep_accepts":len(ra),"stagnation_target":key in stagnation}); continue
        complete=result["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(result["ELIGIBLE"])==1
        finite=all(math.isfinite(float(result[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
        records.append({"material":mid,"route":route,"mode":mode,"dt":dt,"complete":complete,
          "terminal_reason":result["TERMINAL_REASON"],"s0_accepts":len(s0),"rep_accepts":len(ra),
          "stagnation_target":key in stagnation,"finite":finite,
          "max_ledger":abs(float(result["MAX_LEDGER"])),"cum_ledger":abs(float(result["CUM_LEDGER"])),
          "work":int(result["WORK"]),"steps_done":int(result["STEPS_DONE"])})

complete=[x for x in records if x.get("complete")]
recovery=len(complete)/96
maxledger=max((x.get("max_ledger",0.) for x in complete),default=math.inf)
maxcum=max((x.get("cum_ledger",0.) for x in complete),default=math.inf)
finite=all(x.get("finite",False) for x in complete)
span_modes={x["mode"] for x in complete}; span_routes={x["route"] for x in complete}; span_mats={x["material"] for x in complete}
stag=[x for x in records if x.get("stagnation_target")]
stag_recovered=sum(x.get("complete",False) for x in stag)
rep_ratios_ok=all(float(x["RLOCAL"])<=1 and float(x["RTOTAL"])<=1 for x in rep_accepts)
rep_finite=all(all(math.isfinite(float(x[k])) for k in ("RLOCAL","RTOTAL","RHEAD","RPOND")) for x in rep_accepts)

qualified=bool(proc==0 and recovery>=.80 and span_modes==set(modes) and span_routes==set(routes) and len(span_mats)>=3 and
               stag_recovered==8 and maxledger<=5e-8 and maxcum<=5e-8 and finite and rep_ratios_ok and rep_finite)
if maxledger>5e-8 or maxcum>5e-8:
    cls="CLOSED_REPRESENTATION_REPLAY_PHYSICAL_MASS_FAILED"
elif not finite or not rep_finite or not rep_ratios_ok:
    cls="CLOSED_REPRESENTATION_REPLAY_STATE_UNSAFE"
elif recovery<.80:
    cls="CLOSED_REPRESENTATION_REPLAY_INSUFFICIENT_RECOVERY"
elif qualified:
    cls="QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_REPLAY_RESEARCH"
else:
    cls="CLOSED_REPRESENTATION_REPLAY_STATE_UNSAFE"

summary={"classification":cls,"case_count":len(records),"complete_cases":len(complete),"recovery_fraction":recovery,
         "stagnation_targets":len(stag),"stagnation_recovered":stag_recovered,
         "representation_accept_count":len(rep_accepts),"representation_ratios_ok":rep_ratios_ok,
         "max_ledger":maxledger,"max_cumulative_ledger":maxcum,"finite_ok":finite,
         "completed_modes":sorted(span_modes),"completed_routes":sorted(span_routes),"completed_materials":sorted(span_mats),
         "process_failures":proc}
print("F_PE_NLGLOB12C_RECORDS="+json.dumps(records,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12C_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB12C=PASS")
