#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); be=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bank=Path(sys.argv[4])
root=Path(__file__).resolve().parents[2]
mats={x["id"]:x for x in json.loads(bank.read_text())["materials"]}
targets=[("O05","TG","HEAD",0.00025),("O05","TG","HEAD",0.000125),("O05","TG","HEAD",0.0000625),
         ("O05","TG","RUNOFF",0.00025),("O05","TG","RUNOFF",0.000125)]
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

sout=subprocess.run([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(be),str(bank)],text=True,capture_output=True)
sl=next((x for x in sout.stdout.splitlines() if x.startswith("F_PE_TIMEINT16C_SUMMARY=")),None)
if sl is None:
    raise SystemExit("missing smooth summary")
ss=json.loads(sl.split("=",1)[1])

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(dynamic),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    modesw=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
    switches=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14C_SWITCH|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)

    entries=[x for x in modesw if int(x.get("ENTRY","0"))==1]
    persists=[x for x in modesw if int(x.get("ENTRY","0"))==0]
    persistent_ok=all(int(x.get("OK","0"))==1 and x.get("MODE")=="SATURATED_KLAG" for x in persists)
    switch_ok=any(int(x.get("SWITCH_OK","0"))==1 for x in switches)
    rec={"material":mid,"route":route,"mode":mode,"dt":dt,"process_ok":cp.returncode==0,
         "entry_count":len(entries),"persistent_interval_count":len(persists),
         "persistent_ok":persistent_ok,"switch_ok":switch_ok}
    if res:
        rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
        rec["terminal_reason"]=res["TERMINAL_REASON"]
        rec["max_ledger"]=abs(float(res["MAX_LEDGER"])); rec["cum_ledger"]=abs(float(res["CUM_LEDGER"]))
        rec["finite"]=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
    else:
        rec["complete"]=False; rec["finite"]=False
    rows.append(rec)

smooth_ok=bool(ss.get("advance") and ss.get("complete") and ss.get("median_refined_top_head_order",0)>=1.6 and
               ss.get("median_refined_top_theta_order",0)>=1.6 and ss.get("head_cases_order_ge_1p5",0)>=3 and
               ss.get("ledger_ok") and ss.get("roundtrip_ok") and ss.get("native_balance_ok") and
               ss.get("median_work_ratio_vs_klag_be",999)<=1.15)

complete=[x for x in rows if x.get("complete") and x.get("switch_ok") and x.get("entry_count")==1 and
          x.get("persistent_ok") and x.get("finite")]
mass_ok=all(x.get("max_ledger",0)<=5e-8 and x.get("cum_ledger",0)<=5e-8 for x in rows if "max_ledger" in x)
later_endpoint=sum((not x.get("complete")) and x.get("terminal_reason")=="ENDPOINT_SOLVE_FAILURE" for x in rows)
state_fail=sum((not x.get("complete")) and x.get("terminal_reason")!="ENDPOINT_SOLVE_FAILURE" for x in rows)

if not smooth_ok:
    cls="CLOSED_PERSISTENT_SATURATED_MODE_ORDER_REGRESSION"
elif proc or len(rows)!=5:
    cls="BLOCKED_PERSISTENT_SATURATED_MODE_IMPLEMENTATION"
elif len(complete)==5 and mass_ok:
    cls="QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH"
elif later_endpoint>=3:
    cls="CLOSED_PERSISTENT_SATURATED_MODE_ENDPOINT_FAILED"
elif state_fail>=3:
    cls="CLOSED_PERSISTENT_SATURATED_MODE_STATE_FAILED"
elif not mass_ok:
    cls="CLOSED_PERSISTENT_SATURATED_MODE_MASS_FAILED"
else:
    cls="CLOSED_PERSISTENT_SATURATED_MODE_STATE_FAILED"

summary={"classification":cls,"smooth_ok":smooth_ok,"target_count":len(rows),"completed_targets":len(complete),
         "process_failures":proc,"later_endpoint_failures":later_endpoint,"state_failures":state_fail,
         "mass_ok":mass_ok,"max_ledger":max((x.get("max_ledger",0) for x in rows),default=0),
         "max_cumulative_ledger":max((x.get("cum_ledger",0) for x in rows),default=0),
         "total_persistent_intervals":sum(x.get("persistent_interval_count",0) for x in rows)}
print("F_PE_NLGLOB14D_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14D_SMOOTH="+json.dumps(ss,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14D_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14D=PASS")
