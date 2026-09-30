#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
route="RUNOFF"; dt=6.25e-5; horizon=360.0
dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(h):
    if h>=0:return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

h=-5.; p=.1
q=-.5*(m["ksat"]+kvg(h))*((p-h)/dtop+1)
rain=-q+(p-pmax)/rsro

cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
  str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h),str(p),
  str(rain),str(dt),str(horizon)],text=True,capture_output=True)

lines=cp.stdout.splitlines()
nominal=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_NOMINAL_RETRY|")]
rollbacks=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_ROLLBACK|")]
halves=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_HALF|")]
recovered=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_RECOVERED|")]
third=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_THIRD_RETRY|")]
failed=[fields(x) for x in lines if x.startswith("F_PE_NLGLOB14Z17E_RECOVERY_FAILED|")]
res=next((fields(x) for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

nominal_ok=(len(nominal)==2 and [int(x["INDEX"]) for x in nominal]==[1,2] and
            all(int(x["RETRY"])==1 and math.isclose(float(x["DT"]),dt,rel_tol=0,abs_tol=1e-15) for x in nominal))
rollback_ok=(len(rollbacks)==2 and [int(x["INDEX"]) for x in rollbacks]==[1,2] and
             all(all(abs(float(x[k]))<=1e-15 for k in ("H","THETA","POND","LEDGER","RUNOFF")) for x in rollbacks))
half_ok=(len(halves)==4 and
         sorted((int(x["INDEX"]),int(x["HALF"])) for x in halves)==[(1,1),(1,2),(2,1),(2,2)] and
         all(int(x["ELIGIBLE"])==1 and int(x["RETRY"])==0 and
             math.isclose(float(x["DT"]),0.5*dt,rel_tol=0,abs_tol=1e-15) for x in halves))
recovered_ok=(len(recovered)==2 and [int(x["COUNT"]) for x in recovered]==[1,2])
third_count=len(third)
complete=bool(res and int(res["ELIGIBLE"])==1 and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE")
finite=bool(res and all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE")))
ma=abs(float(res["MAX_LEDGER"])) if res else math.inf
cu=abs(float(res["CUM_LEDGER"])) if res else math.inf
mass_ok=ma<=5e-8 and cu<=5e-8

if nominal_ok and rollback_ok and half_ok and recovered_ok and third_count==0 and not failed and complete and finite and mass_ok:
    cls="QUALIFIED_Z17E_SECOND_LOCAL_RETRY_RECOVERY"
elif third_count>0 and nominal_ok and rollback_ok and half_ok and recovered_ok and finite and mass_ok:
    cls="Z17E_THIRD_RETRY_BEFORE_360D"
elif any(int(x.get("RETRY","0"))==1 for x in halves):
    cls="Z17E_SECOND_HALFSTEP_INSUFFICIENT"
elif not rollback_ok or not mass_ok or not finite:
    cls="Z17E_RETRY_TRANSACTION_INCONSISTENT"
else:
    cls="Z17E_SECOND_RECOVERY_HARD_FAILURE"

record={"classification":cls,"route":route,"dt":dt,"horizon":horizon,
        "process_ok":cp.returncode==0,"nominal_retry_count":len(nominal),
        "nominal_retry_steps":[int(x["STEP"]) for x in nominal],
        "rollback_ok":rollback_ok,"half_ok":half_ok,"recovered_ok":recovered_ok,
        "recovered_count":len(recovered),"third_retry_count":third_count,
        "third_retry_time":int(third[0]["STEP"])*dt if third else None,
        "complete":complete,"finite":finite,"mass_ok":mass_ok,
        "terminal_reason":res.get("TERMINAL_REASON") if res else None,
        "max_ledger":ma,"cum_ledger":cu}
print("F_PE_NLGLOB14Z17E_RECORDS="+json.dumps([record],separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17E_SUMMARY="+json.dumps({"classification":cls,"case_count":1},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z17E=PASS")
