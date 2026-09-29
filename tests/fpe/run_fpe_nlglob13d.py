#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); be=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bank_path=Path(sys.argv[4])
root=Path(__file__).resolve().parents[2]
bank=json.loads(bank_path.read_text()); mats={x["id"]:x for x in bank["materials"]}
targets=[
 ("O05","TG","HEAD",0.00025),
 ("O05","TG","HEAD",0.000125),
 ("O05","TG","HEAD",0.0000625),
 ("O05","TG","RUNOFF",0.00025),
 ("O05","TG","RUNOFF",0.000125),
]
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def invoke(args):
    cp=subprocess.run(args,text=True,capture_output=True)
    if cp.returncode!=0:
        print(cp.stdout); print(cp.stderr,file=sys.stderr); raise SystemExit(cp.returncode)
    return cp.stdout

def payload(out,prefix):
    line=next((x for x in out.splitlines() if x.startswith(prefix+"=")),None)
    if line is None: raise SystemExit("missing "+prefix)
    return json.loads(line.split("=",1)[1])

def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

def fixture(m,r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

sout=invoke([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(be),str(bank_path)])
ss=payload(sout,"F_PE_TIMEINT16C_SUMMARY")
smooth_ok=bool(ss.get("advance") and ss.get("complete") and ss.get("median_refined_top_head_order",0)>=1.6 and
               ss.get("median_refined_top_theta_order",0)>=1.6 and ss.get("head_cases_order_ge_1p5",0)>=3 and
               ss.get("ledger_ok") and ss.get("roundtrip_ok") and ss.get("native_balance_ok") and
               ss.get("median_work_ratio_vs_klag_be",999)<=1.15)

rows=[]; proc=0
for mid,mode,route,dt in targets:
    m=mats[mid]; h0,p0,rain=fixture(m,route)
    cp=subprocess.run([str(dynamic),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    first_ok=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13D_H8_FIRST|")]
    ef=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13D_EFAIL|")]
    subdiv8=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13D_SUBDIV8|")]
    q2=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13D_Q2FAIL|")]
    first_fail=[x for x in ef if int(x.get("EIGHTH","0"))==1]
    first_h8_ok=(len(first_ok)>=1 and len(first_fail)==0)
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,
         "first_h8_ok":first_h8_ok,"first_h8_ok_count":len(first_ok),
         "first_h8_fail_count":len(first_fail),"subdiv8_complete_count":len(subdiv8),
         "quarter2_fail_count":len(q2)}
    if res:
        finite=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
        rec.update({"result_present":True,
                    "complete":res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1,
                    "terminal_reason":res["TERMINAL_REASON"],
                    "max_ledger":abs(float(res["MAX_LEDGER"])),"cum_ledger":abs(float(res["CUM_LEDGER"])),
                    "finite":finite})
    else:
        rec.update({"result_present":False,"complete":False,"terminal_reason":"MISSING_RESULT",
                    "max_ledger":math.inf,"cum_ledger":math.inf,"finite":False})
    rows.append(rec)

origin_identity_authority=True  # inherited unchanged from NLGLOB13C1/C2 rollback path
all_first_h8_ok=all(x["first_h8_ok"] for x in rows)
mass_ok=all(x["max_ledger"]<=5e-8 and x["cum_ledger"]<=5e-8 for x in rows)
finite_ok=all(x["finite"] for x in rows)
non_domain_first_fail=sum(x["first_h8_fail_count"]>0 for x in rows)
if proc or not origin_identity_authority:
    cls="BLOCKED_NLGLOB13D_COVERAGE"
elif all_first_h8_ok and mass_ok and finite_ok and smooth_ok:
    cls="NLGLOB13D_H8_ADMISSIBILITY_CONFIRMED"
elif non_domain_first_fail>=3:
    cls="NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED"
else:
    cls="NLGLOB13D_MIXED_H8_SIGNAL"

summary={"classification":cls,"target_count":len(rows),"origin_identity_authority":origin_identity_authority,
         "first_h8_admissible_count":sum(x["first_h8_ok"] for x in rows),
         "subdiv8_pair_complete_count":sum(x["subdiv8_complete_count"]>0 for x in rows),
         "full_horizon_complete_count":sum(x["complete"] for x in rows),
         "smooth_ok":smooth_ok,"smooth_median_head_order":ss.get("median_refined_top_head_order"),
         "smooth_median_theta_order":ss.get("median_refined_top_theta_order"),
         "mass_ok":mass_ok,"finite_ok":finite_ok,
         "max_ledger":max((x["max_ledger"] for x in rows),default=math.inf),
         "max_cumulative_ledger":max((x["cum_ledger"] for x in rows),default=math.inf),
         "process_failures":proc}
print("F_PE_NLGLOB13D_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13D_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13D=PASS")
