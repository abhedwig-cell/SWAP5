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
    e8=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13D_SUBDIV8|")]
    ef=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13D_EFAIL|")]
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,
         "subdiv8_count":len(e8),"eighth_fail_count":len(ef)}
    if res:
        rec.update({"complete":res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1,
                    "terminal_reason":res["TERMINAL_REASON"],
                    "max_ledger":abs(float(res["MAX_LEDGER"])),"cum_ledger":abs(float(res["CUM_LEDGER"])),
                    "finite":all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))})
    else:
        rec.update({"complete":False,"terminal_reason":"MISSING_RESULT","finite":False})
    rows.append(rec)

complete=sum(x["complete"] for x in rows)
all_first_h8_ok=all(x["eighth_fail_count"]==0 and x["subdiv8_count"]>=1 for x in rows)
mass_ok=all(x.get("max_ledger",999)<=5e-8 and x.get("cum_ledger",999)<=5e-8 for x in rows if x["complete"])
finite_ok=all(x.get("finite",False) for x in rows if x["complete"])

if proc or not smooth_ok:
    cls="BLOCKED_NLGLOB13D_COVERAGE" if proc else "NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED"
elif all_first_h8_ok and complete==5 and mass_ok and finite_ok:
    cls="NLGLOB13D_H8_ADMISSIBILITY_CONFIRMED"
elif sum(x["eighth_fail_count"]>0 for x in rows)>=3:
    cls="NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED"
else:
    cls="NLGLOB13D_MIXED_H8_SIGNAL"

summary={"classification":cls,"target_count":len(rows),"complete_cases":complete,
         "all_first_h8_ok":all_first_h8_ok,"smooth_ok":smooth_ok,
         "smooth_median_head_order":ss.get("median_refined_top_head_order"),
         "smooth_median_theta_order":ss.get("median_refined_top_theta_order"),
         "mass_ok":mass_ok,"finite_ok":finite_ok,"process_failures":proc}
print("F_PE_NLGLOB13D_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13D_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13D=PASS")
