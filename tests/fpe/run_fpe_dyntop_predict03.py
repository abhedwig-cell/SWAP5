#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
base_bank=json.loads(Path(sys.argv[2]).read_text())
val_bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in base_bank["materials"]}
base=base_bank["baseline_policy"]

def run_case(mid,reg):
    m=materials[mid]
    cid=f"{mid}/{reg['id']}"
    dtmin=base["dtmin_day"]; dtmax=4.0*base["dtmax_day"]; dt0=math.sqrt(base["dtmin_day"]*base["dtmax_day"])
    cmd=[str(exe),cid,"VALIDATE_H0",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(reg["h0_cm"]),str(reg["rain_cm_day"]),str(val_bank["horizon_day"]),
         str(dtmin),str(dtmax),str(dt0),str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),str(base["head_abs_tol"]),
         "CLASSIFIER","1.0","1.0","1.0"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    labels=[]
    for line in cp.stdout.splitlines():
        if not line.startswith("F_PE_DYNTOP_PREDICT02_LABEL|"): continue
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        ints=["PRED_OK","PRED_REGIME","PRED_RUNOFF_POT","HIST2","FULL_OK","HALF_OK","SAFE"]
        floats=["T0","DT","PRED_POND","PRED_RUNOFF","PRED_SURFACE_HEAD","PRED_Q0","R_LAST","R_PREV","TREND","EH","EPOND","ERUN","ESTORE"]
        x={"case":cid,"material":mid,"regime":reg["id"],"regime_class":reg["class"]}
        x.update({k.lower():int(d[k]) for k in ints})
        x.update({k.lower():float(d[k]) for k in floats})
        x["h0_predict_safe"]=(x["hist2"]==1 and x["pred_ok"]==1 and x["pred_runoff_pot"]==0 and x["r_last"]<=0.10)
        labels.append(x)
    return {
      "case":cid,
      "material":mid,
      "regime":reg["id"],
      "ok":cp.returncode==0 and "F_PE_DYNTOP_PREDICT02=PASS" in cp.stdout,
      "labels":len(labels),
      "stdout":cp.stdout[-800:] if cp.returncode else "",
      "stderr":cp.stderr[-800:] if cp.returncode else "",
    },labels

case_results=[]; labels=[]
for mid in val_bank["materials"]:
    for reg in val_bank["regimes"]:
        c,ls=run_case(mid,reg); case_results.append(c); labels.extend(ls)

tp=fp=tn=fn=0
for x in labels:
    pred=x["h0_predict_safe"]; safe=x["safe"]==1
    if pred and safe: tp+=1
    elif pred and not safe: fp+=1
    elif (not pred) and safe: fn+=1
    else: tn+=1
safe_total=tp+fn
unsafe_total=tn+fp
coverage=tp/safe_total if safe_total else 0.0
materials_with_labels=len({x["material"] for x in labels})
wetpond_labels=sum(x["regime_class"] in ("WET","POND") for x in labels)
summary={
  "labels":len(labels),"safe_total":safe_total,"unsafe_total":unsafe_total,
  "true_safe":tp,"false_safe":fp,"true_unsafe":tn,"false_unsafe":fn,
  "safe_coverage":coverage,
  "materials_with_labels":materials_with_labels,
  "wetpond_labels":wetpond_labels,
  "incomplete_cases":sum(not x["ok"] for x in case_results),
}
summary["validate"]=(len(labels)>=10 and fp==0 and coverage>=0.50 and
                     materials_with_labels>=3 and wetpond_labels>=1)

print("F_PE_DYNTOP_PREDICT03_CASES="+json.dumps(case_results,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT03_LABELS="+json.dumps(labels,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT03_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT03=PASS")
