#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); baseline=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bankp=Path(sys.argv[4])
bank=json.loads(bankp.read_text()); mats={x["id"]:x for x in bank["materials"]}
root=Path(__file__).resolve().parents[2]
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

sout=invoke([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(baseline),str(bankp)])
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
    splits=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14B_SPLIT|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    d=splits[-1] if splits else None
    rec={"material":mid,"mode":mode,"route":route,"dt":dt,"process_ok":cp.returncode==0,"split_present":d is not None}
    if d:
        rec["complete"]=int(d.get("COMPLETE","0"))==1
        rec["reason"]=d.get("REASON","")
        if rec["complete"]:
            for k in ("PHI","EVENT_DEPTH","EVENT_LEDGER","REMAINDER_DT","SPLIT_LEDGER","MAX_OVER","POND"):
                rec[k.lower()]=float(d[k])
            rec["bisect"]=int(d["BISECT"]); rec["event_route"]=int(d["EVENT_ROUTE"]); rec["remainder_route"]=int(d["REMAINDER_ROUTE"])
            rec["safe"]=(0<rec["phi"]<1 and rec["event_depth"]<=5e-8 and rec["event_ledger"]<=5e-8 and
                         rec["remainder_dt"]>0 and rec["split_ledger"]<=5e-8 and rec["max_over"]<=0 and
                         math.isfinite(rec["pond"]) and rec["event_route"] in (1,2,3) and rec["remainder_route"] in (1,2,3) and
                         1<=rec["bisect"]<=32)
    if res: rec["terminal_reason"]=res["TERMINAL_REASON"]
    rows.append(rec)

done=[x for x in rows if x.get("complete",False)]
domain_fail=sum(x.get("reason")=="REMAINDER_DOMAIN" for x in rows)
unsafe=any(x.get("complete") and not x.get("safe",False) for x in rows)
if not smooth_ok:
    cls="CLOSED_TG_EVENT_SPLIT_ORDER_REGRESSION"
elif proc or len(rows)!=5 or any(not x["split_present"] for x in rows):
    cls="BLOCKED_NLGLOB14B_EVENT_SPLIT_COVERAGE"
elif domain_fail>=3:
    cls="CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED"
elif unsafe:
    cls="CLOSED_TG_EVENT_SPLIT_PHYSICAL_ADMISSIBILITY_FAILED"
elif len(done)==5 and all(x.get("safe",False) for x in done):
    cls="QUALIFIED_TG_SATURATION_EVENT_SPLIT_RESEARCH"
else:
    cls="NLGLOB14B_MIXED_EVENT_SPLIT_SIGNAL"

summary={"classification":cls,"smooth_ok":smooth_ok,
         "smooth_median_head_order":ss.get("median_refined_top_head_order"),
         "smooth_median_theta_order":ss.get("median_refined_top_theta_order"),
         "smooth_work_ratio":ss.get("median_work_ratio_vs_klag_be"),
         "target_count":len(rows),"split_complete_count":len(done),"remainder_domain_failures":domain_fail,
         "max_split_ledger":max((x.get("split_ledger",0) for x in done),default=math.inf),
         "max_event_ledger":max((x.get("event_ledger",0) for x in done),default=math.inf),
         "process_failures":proc}
print("F_PE_NLGLOB14B_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B=PASS")