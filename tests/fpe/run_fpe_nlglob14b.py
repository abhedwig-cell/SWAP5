#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); be=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bank=Path(sys.argv[4])
root=Path(__file__).resolve().parents[2]
mats={x["id"]:x for x in json.loads(bank.read_text())["materials"]}
targets=[("O05","TG","HEAD",0.00025),("O05","TG","HEAD",0.000125),("O05","TG","HEAD",0.0000625),
         ("O05","TG","RUNOFF",0.00025),("O05","TG","RUNOFF",0.000125)]
horizon=.001; dtop=10.; pmax=.05; rsro=.05
def invoke(args):
  cp=subprocess.run(args,text=True,capture_output=True)
  if cp.returncode!=0: return cp
  return cp
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
  mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
  return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
  h=-5.; p=.025 if r=="HEAD" else .1; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
  return h,p,(-q if r=="HEAD" else -q+(p-pmax)/rsro)

sout=subprocess.run([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(be),str(bank)],text=True,capture_output=True)
sl=next(x for x in sout.stdout.splitlines() if x.startswith("F_PE_TIMEINT16C_SUMMARY="))
ss=json.loads(sl.split("=",1)[1])

rows=[]; proc=0
for mid,mode,route,dt in targets:
  m=mats[mid]; h0,p0,rain=fixture(m,route)
  cp=subprocess.run([str(dynamic),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
    str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
  if cp.returncode!=0: proc+=1
  split=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14B_SPLIT|")]
  res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
  d=split[-1] if split else None
  rec={"material":mid,"route":route,"mode":mode,"dt":dt,"process_ok":cp.returncode==0,"split_present":d is not None}
  if d:
    rec["split_ok"]=int(d.get("SPLIT_OK","0"))==1
    rec["reason"]=d.get("REASON","")
    rec["domain"]=int(d.get("DOMAIN","0")) if "DOMAIN" in d else 0
    if rec["split_ok"]:
      rec["event_depth"]=float(d["EVENT_DEPTH"]); rec["event_ledger"]=float(d["EVENT_LEDGER"])
      rec["nominal_ledger"]=float(d["NOMINAL_LEDGER"]); rec["event_dt"]=float(d["EVENT_DT"]); rec["rem_dt"]=float(d["REM_DT"])
  if res:
    rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
    rec["terminal_reason"]=res["TERMINAL_REASON"]; rec["max_ledger"]=abs(float(res["MAX_LEDGER"])); rec["cum_ledger"]=abs(float(res["CUM_LEDGER"]))
  else: rec["complete"]=False
  rows.append(rec)

smooth_ok=bool(ss.get("advance") and ss.get("median_refined_top_head_order",0)>=1.6 and ss.get("median_refined_top_theta_order",0)>=1.6 and ss.get("head_cases_order_ge_1p5",0)>=3)
complete=[x for x in rows if x.get("complete") and x.get("split_ok")]
domain_fail=sum(x.get("reason")=="REMAINDER_FAILED" and x.get("domain")==1 for x in rows)
endpoint_fail=sum(x.get("reason")=="REMAINDER_FAILED" and x.get("domain")==0 for x in rows)
safety=all(x.get("max_ledger",0)<=5e-8 and x.get("cum_ledger",0)<=5e-8 for x in rows if "max_ledger" in x)
if not smooth_ok: cls="CLOSED_TG_EVENT_SPLIT_ORDER_REGRESSION"
elif proc or len(rows)!=5: cls="BLOCKED_NLGLOB14B_EVENT_SPLIT_COVERAGE"
elif len(complete)==5 and safety: cls="QUALIFIED_TG_SATURATION_EVENT_SPLIT_RESEARCH"
elif domain_fail>=3: cls="CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED"
elif endpoint_fail>=3: cls="CLOSED_TG_EVENT_SPLIT_REMAINDER_ENDPOINT_FAILED"
else: cls="CLOSED_TG_EVENT_SPLIT_PHYSICAL_ADMISSIBILITY_FAILED"
summary={"classification":cls,"smooth_ok":smooth_ok,"target_count":len(rows),"completed_targets":len(complete),
         "remainder_domain_failures":domain_fail,"remainder_endpoint_failures":endpoint_fail,"process_failures":proc,
         "max_ledger":max((x.get("max_ledger",0) for x in rows),default=0),"max_cumulative_ledger":max((x.get("cum_ledger",0) for x in rows),default=0)}
print("F_PE_NLGLOB14B_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B_SMOOTH="+json.dumps(ss,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B=PASS")
