#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); be=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bank=Path(sys.argv[4])
root=Path(__file__).resolve().parents[2]
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    if r=="FLUX":
        h=-50.; p=0.; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=.25*(-q)
    elif r=="HEAD":
        h=-5.; p=.025; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q
    else:
        h=-5.; p=.1; kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1); rain=-q+(p-pmax)/rsro
    return h,p,rain

sout=subprocess.run([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(be),str(bank)],text=True,capture_output=True)
sl=next((x for x in sout.stdout.splitlines() if x.startswith("F_PE_TIMEINT16C_SUMMARY=")),None)
if sl is None: raise SystemExit("missing smooth summary")
ss=json.loads(sl.split("=",1)[1])

rows=[];proc=0
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(dynamic),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        mlogs=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14D_MODE|")]
        attempts=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14E1_ROOT_ATTEMPT|")]
        switches=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14C_SWITCH|")]
        res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        entries=[x for x in mlogs if int(x.get("ENTRY","0"))==1]
        persists=[x for x in mlogs if int(x.get("ENTRY","0"))==0]
        success_switches=[x for x in switches if int(x.get("SWITCH_OK","0"))==1]
        entry_steps=[int(x["STEP"]) for x in entries]
        attempt_steps=[int(x["STEP"]) for x in attempts]
        no_post_entry_attempt=True
        if entry_steps:
            first_entry=min(entry_steps)
            no_post_entry_attempt=all(s<=first_entry for s in attempt_steps)
        entry_semantics_ok=(len(entries)<=1 and len(success_switches)==len(entries))
        persistent_ok=all(int(x.get("OK","0"))==1 and x.get("MODE")=="SATURATED_KLAG" for x in persists)
        rec={"material":mid,"route":route,"mode":mode,"dt":dt,"process_ok":cp.returncode==0,
             "entry_count":len(entries),"switch_count":len(success_switches),"persistent_intervals":len(persists),
             "root_attempt_count":len(attempts),"entry_steps":entry_steps,"root_attempt_steps":attempt_steps,
             "entry_semantics_ok":entry_semantics_ok,"no_post_entry_attempt":no_post_entry_attempt,
             "persistent_ok":persistent_ok}
        if res:
            rec["terminal_reason"]=res["TERMINAL_REASON"]
            rec["complete"]=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
            rec["finite"]=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
            rec["max_ledger"]=abs(float(res["MAX_LEDGER"])); rec["cum_ledger"]=abs(float(res["CUM_LEDGER"]))
            rec["work"]=int(res["WORK"])
        else:
            rec["terminal_reason"]="MISSING_RESULT"; rec["complete"]=False; rec["finite"]=False; rec["work"]=0
        rows.append(rec)

smooth_ok=bool(ss.get("advance") and ss.get("complete") and ss.get("median_refined_top_head_order",0)>=1.6 and
               ss.get("median_refined_top_theta_order",0)>=1.6 and ss.get("head_cases_order_ge_1p5",0)>=3 and
               ss.get("ledger_ok") and ss.get("roundtrip_ok") and ss.get("native_balance_ok") and
               ss.get("median_work_ratio_vs_klag_be",999)<=1.15)
complete=[x for x in rows if x["complete"]]
incomplete=[x for x in rows if not x["complete"]]
mass_ok=all(x.get("max_ledger",math.inf)<=5e-8 and x.get("cum_ledger",math.inf)<=5e-8 for x in complete)
finite_ok=all(x.get("finite",False) for x in complete)
diagnostic_ok=all(x["entry_semantics_ok"] and x["persistent_ok"] and x["no_post_entry_attempt"] for x in rows)
bad_reasons={"PREDICTED_RETENTION_DOMAIN_FAILED","SATURATION_ROOT_BRACKET_INVALID","SATURATION_ROOT_NOT_LOCALIZED",
             "SATURATION_EVENT_KLAG_REMAINDER_INVALID","SATURATION_EVENT_REMAINDER_DOMAIN_FAILED"}
unsafe_reason_count=sum(x["terminal_reason"] in bad_reasons for x in incomplete)

if not smooth_ok:
    cls="CLOSED_NLGLOB14E_DYNAMIC_POLICY_ORDER_REGRESSION"
elif len(rows)!=96 or proc:
    cls="BLOCKED_NLGLOB14E_DYNAMIC_POLICY_COVERAGE"
elif not mass_ok or not finite_ok:
    cls="CLOSED_NLGLOB14E_DYNAMIC_POLICY_PHYSICAL_ADMISSIBILITY_FAILED"
elif not diagnostic_ok:
    cls="BLOCKED_NLGLOB14E1_ROOT_OBSERVABILITY"
elif len(incomplete)==0:
    cls="QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY"
elif len(incomplete)<=4:
    cls="NLGLOB14E_NEAR_COMPLETE_DYNAMIC_POLICY"
else:
    cls="CLOSED_NLGLOB14E_DYNAMIC_POLICY_INCOMPLETE"

tgwork=[x["work"] for x in rows if x["mode"]=="TG"]; klagwork=[x["work"] for x in rows if x["mode"]=="KLAG"]
summary={"classification":cls,"smooth_ok":smooth_ok,"case_count":len(rows),"complete_cases":len(complete),
         "incomplete_cases":len(incomplete),"process_failures":proc,"mass_ok":mass_ok,"finite_ok":finite_ok,
         "diagnostic_ok":diagnostic_ok,"unsafe_terminal_reason_count":unsafe_reason_count,
         "event_entries":sum(x["entry_count"] for x in rows),
         "root_attempts":sum(x["root_attempt_count"] for x in rows),
         "persistent_intervals":sum(x["persistent_intervals"] for x in rows),
         "post_entry_root_attempt_violations":sum(not x["no_post_entry_attempt"] for x in rows),
         "max_ledger":max((x.get("max_ledger",0) for x in complete),default=0),
         "max_cumulative_ledger":max((x.get("cum_ledger",0) for x in complete),default=0),
         "median_tg_work":statistics.median(tgwork) if tgwork else 0,
         "median_klag_work":statistics.median(klagwork) if klagwork else 0}
print("F_PE_NLGLOB14E1_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14E1_SMOOTH="+json.dumps(ss,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14E1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14E1=PASS")
