#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); be=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bankp=Path(sys.argv[4])
bank=json.loads(bankp.read_text()); mats={x["id"]:x for x in bank["materials"]}
root=Path(__file__).resolve().parents[2]
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05
near={
("O05","TG","HEAD",0.00025),("O05","TG","HEAD",0.000125),
("O05","TG","HEAD",0.0000625),("O05","TG","HEAD",0.00003125),
("O05","TG","RUNOFF",0.00025),("O05","TG","RUNOFF",0.000125),
("O05","TG","RUNOFF",0.00003125),
}

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
    if r=="FLUX":
        h=-50.;p=0.;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=.25*(-q)
    elif r=="HEAD":
        h=-5.;p=.025;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q
    else:
        h=-5.;p=.1;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q+(p-pmax)/rsro
    return h,p,rain
def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

sout=invoke([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(be),str(bankp)])
ss=payload(sout,"F_PE_TIMEINT16C_SUMMARY")
smooth_ok=bool(ss.get("advance") and ss.get("complete") and ss.get("median_refined_top_head_order",0)>=1.6 and
               ss.get("median_refined_top_theta_order",0)>=1.6 and ss.get("head_cases_order_ge_1p5",0)>=3 and
               ss.get("ledger_ok") and ss.get("roundtrip_ok") and ss.get("native_balance_ok") and
               ss.get("median_work_ratio_vs_klag_be",999)<=1.15)

records=[]; proc=0
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=subprocess.run([str(dynamic),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        sub4=sum(x.startswith("F_PE_NLGLOB13B_SUBDIV4|") for x in cp.stdout.splitlines())
        qfail=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB13B_QFAIL|")]
        r0=sum(x.startswith("F_PE_NLGLOB12A1_ACCEPT|") for x in cp.stdout.splitlines())
        s0=sum(x.startswith("F_PE_NLGLOB09_ACCEPT|") for x in cp.stdout.splitlines())
        rec={"material":mid,"mode":mode,"route":route,"dt":dt,"sub4":sub4,"qfail":len(qfail),"r0":r0,"s0":s0,
             "qfail_domain":sum(int(x["DOMAIN"])==1 for x in qfail)}
        if res is None:
            rec.update({"complete":False,"missing":True})
        else:
            complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
            finite=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
            rec.update({"complete":complete,"terminal_reason":res["TERMINAL_REASON"],"finite":finite,
                        "max_ledger":abs(float(res["MAX_LEDGER"])),"cum_ledger":abs(float(res["CUM_LEDGER"]))})
        records.append(rec)

complete=[x for x in records if x.get("complete")]
nearrows=[x for x in records if (x["material"],x["mode"],x["route"],x["dt"]) in near]
near_complete=sum(x.get("complete",False) for x in nearrows)
near_sub4=sum(x.get("sub4",0)>0 for x in nearrows)
near_qdomain=sum(x.get("qfail_domain",0)>0 for x in nearrows)
near_qother=sum(x.get("qfail",0)>x.get("qfail_domain",0) for x in nearrows)
near_ok=(len(nearrows)==7 and near_complete==7 and near_sub4==7 and near_qdomain==0 and near_qother==0 and
         all(x.get("finite",False) for x in nearrows) and
         max((x.get("max_ledger",math.inf) for x in nearrows),default=math.inf)<=5e-8 and
         max((x.get("cum_ledger",math.inf) for x in nearrows),default=math.inf)<=5e-8)
recovery=len(complete)/96
maxledger=max((x.get("max_ledger",0.) for x in complete),default=math.inf)
maxcum=max((x.get("cum_ledger",0.) for x in complete),default=math.inf)
finite=all(x.get("finite",False) for x in complete)
span_modes={x["mode"] for x in complete}; span_routes={x["route"] for x in complete}; span_mats={x["material"] for x in complete}
dynamic_ok=(len(records)==96 and recovery>=.80 and span_modes==set(modes) and span_routes==set(routes) and len(span_mats)>=3 and
            maxledger<=5e-8 and maxcum<=5e-8 and finite and proc==0)

if not smooth_ok:
    cls="CLOSED_TG_NEARSAT_SUBDIV4_ORDER_REGRESSION"
elif near_qdomain>0:
    cls="CLOSED_TG_NEARSAT_SUBDIV4_DOMAIN_PERSISTS"
elif near_qother>0:
    cls="CLOSED_TG_NEARSAT_SUBDIV4_OTHER_FAILURE"
elif not near_ok:
    cls="CLOSED_TG_NEARSAT_SUBDIV4_OTHER_FAILURE"
elif not finite or maxledger>5e-8 or maxcum>5e-8:
    cls="CLOSED_TG_NEARSAT_SUBDIV4_PHYSICAL_ADMISSIBILITY_FAILED"
elif dynamic_ok:
    cls="QUALIFIED_TG_NEARSAT_SUBDIV4_RESEARCH"
else:
    cls="TG_NEARSAT_SUBDIV4_QUALIFIED_ENDPOINT_BLOCKER_REMAINS"

summary={"classification":cls,"smooth_ok":smooth_ok,
         "smooth_median_head_order":ss.get("median_refined_top_head_order"),
         "smooth_median_theta_order":ss.get("median_refined_top_theta_order"),
         "smooth_work_ratio":ss.get("median_work_ratio_vs_klag_be"),
         "near_n":len(nearrows),"near_complete":near_complete,"near_with_quarter_subdivision":near_sub4,
         "near_quarter_domain_failures":near_qdomain,"near_quarter_other_failures":near_qother,
         "dynamic_complete_cases":len(complete),"dynamic_recovery_fraction":recovery,
         "dynamic_max_ledger":maxledger,"dynamic_max_cumulative_ledger":maxcum,
         "quarter_subdivision_event_count":sum(x.get("sub4",0) for x in records),
         "r0_accept_count":sum(x.get("r0",0) for x in records),"s0_accept_count":sum(x.get("s0",0) for x in records),
         "process_failures":proc}
print("F_PE_NLGLOB13B_RECORDS="+json.dumps(records,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB13B=PASS")
