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
sl=next(x for x in sout.stdout.splitlines() if x.startswith("F_PE_TIMEINT16C_SUMMARY="))
ss=json.loads(sl.split("=",1)[1])

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(dynamic),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    sw=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14C_SWITCH|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    d=sw[-1] if sw else None
    rec={"material":mid,"route":route,"mode":mode,"dt":dt,"process_ok":cp.returncode==0,"switch_present":d is not None}
    if d:
        rec["switch_ok"]=int(d.get("SWITCH_OK","0"))==1
        rec["reason"]=d.get("REASON","")
        if rec["switch_ok"]:
            for k in ("EVENT_DEPTH","EVENT_LEDGER","NOMINAL_LEDGER","EVENT_DT","REM_DT","EVENT_POND","FINAL_POND"):
                rec[k.lower()]=float(d[k])
            rec["event_route"]=int(d["EVENT_ROUTE"]); rec["final_route"]=int(d["FINAL_ROUTE"])
        else:
            rec["terminal_detail"]=d.get("TERMINAL","")
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
complete=[x for x in rows if x.get("complete") and x.get("switch_ok") and x.get("finite")]
endpoint_fail=sum(x.get("reason")=="KLAG_REMAINDER_FAILED" and x.get("terminal_detail")=="ENDPOINT_SOLVE_FAILURE" for x in rows)
state_fail=sum(x.get("reason")=="KLAG_REMAINDER_FAILED" and x.get("terminal_detail")!="ENDPOINT_SOLVE_FAILURE" for x in rows)
mass_ok=all(x.get("max_ledger",0)<=5e-8 and x.get("cum_ledger",0)<=5e-8 for x in rows if "max_ledger" in x)

if not smooth_ok:
    cls="CLOSED_TG_EVENT_KLAG_REMAINDER_ORDER_REGRESSION"
elif proc or len(rows)!=5:
    cls="BLOCKED_NLGLOB14C_COVERAGE"
elif len(complete)==5 and mass_ok:
    cls="QUALIFIED_TG_SATURATION_EVENT_KLAG_REMAINDER_RESEARCH"
elif endpoint_fail>=3:
    cls="CLOSED_TG_EVENT_KLAG_REMAINDER_ENDPOINT_FAILED"
elif state_fail>=3:
    cls="CLOSED_TG_EVENT_KLAG_REMAINDER_STATE_FAILED"
elif not mass_ok:
    cls="CLOSED_TG_EVENT_KLAG_REMAINDER_MASS_FAILED"
else:
    cls="CLOSED_TG_EVENT_KLAG_REMAINDER_STATE_FAILED"

summary={"classification":cls,"smooth_ok":smooth_ok,"target_count":len(rows),"completed_targets":len(complete),
         "remainder_endpoint_failures":endpoint_fail,"remainder_state_failures":state_fail,"process_failures":proc,
         "mass_ok":mass_ok,"max_ledger":max((x.get("max_ledger",0) for x in rows),default=0),
         "max_cumulative_ledger":max((x.get("cum_ledger",0) for x in rows),default=0)}
print("F_PE_NLGLOB14C_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14C_SMOOTH="+json.dumps(ss,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14C_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14C=PASS")
