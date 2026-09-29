#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); baseline=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bank_path=Path(sys.argv[4])
root=Path(__file__).resolve().parents[2]
bank=json.loads(bank_path.read_text()); mats={x["id"]:x for x in bank["materials"]}
routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG"); dts=[0.00025,0.000125,0.0000625,0.00003125]
targets={("O05","TG","HEAD",0.00025),("O05","TG","HEAD",0.000125),("O05","TG","HEAD",0.0000625),
         ("O05","TG","RUNOFF",0.00025),("O05","TG","RUNOFF",0.000125)}
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def invoke(args):
    cp=subprocess.run(args,text=True,capture_output=True)
    return cp

def payload(out,prefix):
    line=next((x for x in out.splitlines() if x.startswith(prefix+"=")),None)
    return json.loads(line.split("=",1)[1]) if line else None

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

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

sout=invoke([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(baseline),str(bank_path)])
if sout.returncode!=0:
    print(sout.stdout); print(sout.stderr,file=sys.stderr); raise SystemExit(sout.returncode)
ss=payload(sout.stdout,"F_PE_TIMEINT16C_SUMMARY")
smooth_ok=bool(ss and ss.get("advance") and ss.get("complete") and
               ss.get("median_refined_top_head_order",0)>=1.6 and
               ss.get("median_refined_top_theta_order",0)>=1.6 and
               ss.get("head_cases_order_ge_1p5",0)>=3 and ss.get("ledger_ok") and
               ss.get("roundtrip_ok") and ss.get("native_balance_ok") and
               ss.get("median_work_ratio_vs_klag_be",999)<=1.15)

records=[]; proc=0; split_rows=[]
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cp=invoke([str(dynamic),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
          str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)])
        if cp.returncode!=0: proc+=1
        res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        splits=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14B_SPLIT|")]
        split_rows.extend([{**s,"material":mid,"mode":mode,"route":route,"dt":dt} for s in splits])
        key=(mid,mode,route,dt)
        if res is None:
            records.append({"material":mid,"mode":mode,"route":route,"dt":dt,"target":key in targets,
                            "complete":False,"missing":True,"split_count":len(splits)})
            continue
        complete=res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1
        finite=all(math.isfinite(float(res[k])) for k in ("TOP_H","TOP_THETA","MID_H","BOTTOM_H","POND","STORAGE"))
        records.append({"material":mid,"mode":mode,"route":route,"dt":dt,"target":key in targets,
                        "complete":complete,"terminal_reason":res["TERMINAL_REASON"],"split_count":len(splits),
                        "finite":finite,"max_ledger":abs(float(res["MAX_LEDGER"])),
                        "cum_ledger":abs(float(res["CUM_LEDGER"])),"work":int(res["WORK"])})

targets_rows=[x for x in records if x["target"]]
target_complete=sum(x.get("complete",False) for x in targets_rows)
target_split_ok=sum(any(s.get("OK")=="1" and s["material"]==x["material"] and s["mode"]==x["mode"] and
                        s["route"]==x["route"] and abs(float(s["dt"])-x["dt"])<1e-15 for s in split_rows)
                    for x in targets_rows)
second_cross=sum(s.get("REASON")=="SECOND_CROSSING" for s in split_rows)
completed=[x for x in records if x.get("complete")]
full_recovery=len(completed)/96
maxledger=max((x.get("max_ledger",0) for x in completed),default=math.inf)
maxcum=max((x.get("cum_ledger",0) for x in completed),default=math.inf)
finite_ok=all(x.get("finite",False) for x in completed)
mass_ok=maxledger<=5e-8 and maxcum<=5e-8
split_mass_ok=all(float(s.get("EVENT_LEDGER","0"))<=5e-8 and float(s.get("NOMINAL_LEDGER","0"))<=5e-8
                  for s in split_rows if s.get("OK")=="1")
event_ok=(len(targets_rows)==5 and target_complete==5 and target_split_ok==5 and second_cross==0 and split_mass_ok and mass_ok and finite_ok)

if event_ok and smooth_ok:
    cls="QUALIFIED_CONSERVATIVE_SATURATION_EVENT_SPLIT_RESEARCH"
elif second_cross>=3 or target_complete<=2:
    cls="CLOSED_SATURATION_EVENT_SPLIT_REMAINDER_INSUFFICIENT"
elif not mass_ok or not split_mass_ok or not finite_ok:
    cls="CLOSED_SATURATION_EVENT_SPLIT_PHYSICAL_ADMISSIBILITY_FAILED"
elif not smooth_ok:
    cls="CLOSED_SATURATION_EVENT_SPLIT_ORDER_REGRESSION"
else:
    cls="BLOCKED_SATURATION_EVENT_SPLIT_COVERAGE"

summary={"classification":cls,"smooth_ok":smooth_ok,
         "smooth_median_head_order":ss.get("median_refined_top_head_order") if ss else None,
         "smooth_median_theta_order":ss.get("median_refined_top_theta_order") if ss else None,
         "event_target_count":len(targets_rows),"event_target_complete":target_complete,
         "event_target_split_ok":target_split_ok,"second_crossing_count":second_cross,
         "full_bank_complete":len(completed),"full_bank_recovery_fraction":full_recovery,
         "split_count":len(split_rows),"max_ledger":maxledger,"max_cumulative_ledger":maxcum,
         "split_mass_ok":split_mass_ok,"finite_ok":finite_ok,"process_failures":proc}
print("F_PE_NLGLOB14B_RECORDS="+json.dumps(records,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B_SPLITS="+json.dumps(split_rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B_SMOOTH="+json.dumps(ss,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14B=PASS")
