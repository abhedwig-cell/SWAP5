#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=list(bank["screening_cases"])

def run_case(cid):
    mid,rid=cid.split("/")
    m=materials[mid]; r=regimes[rid]
    dtmin=base["dtmin_day"]; dtmax=4.0*base["dtmax_day"]; dt0=math.sqrt(base["dtmin_day"]*base["dtmax_day"])
    cmd=[str(exe),cid,"CLASSIFIER",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         str(dtmin),str(dtmax),str(dt0),str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),str(base["head_abs_tol"]),
         "CLASSIFIER","1.0","1.0","1.0"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"case":cid,"ok":False,"stdout":cp.stdout[-1500:],"stderr":cp.stderr[-1500:]},[]
    labels=[]
    for line in cp.stdout.splitlines():
        if not line.startswith("F_PE_DYNTOP_PREDICT01_LABEL|"): continue
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        ints=["PRED_OK","PRED_REGIME","PRED_RUNOFF_POT","FULL_OK","HALF_OK","SAFE"]
        floats=["T0","DT","PRED_POND","PRED_RUNOFF","PRED_SURFACE_HEAD","PRED_Q0","EH","EPOND","ERUN","ESTORE"]
        rec={"case":cid}
        rec.update({k.lower():int(d[k]) for k in ints})
        rec.update({k.lower():float(d[k]) for k in floats})
        labels.append(rec)
    ok="F_PE_DYNTOP_PREDICT01=PASS" in cp.stdout
    return {"case":cid,"ok":ok,"labels":len(labels)},labels

case_results=[]; labels=[]
for cid in cases:
    cr,ls=run_case(cid); case_results.append(cr); labels.extend(ls)

rules={
 "P0":lambda x:x["pred_ok"]==1 and x["pred_runoff_pot"]==0,
 "P1":lambda x:x["pred_ok"]==1 and abs(x["pred_runoff"])<=1e-14 and x["pred_pond"]<=0.005,
 "P2":lambda x:x["pred_ok"]==1 and abs(x["pred_runoff"])<=1e-14 and x["pred_pond"]<=0.020,
 "P3":lambda x:x["pred_ok"]==1 and abs(x["pred_runoff"])<=1e-14 and x["pred_pond"]<=0.050,
}
safe_total=sum(x["safe"]==1 for x in labels)
unsafe_total=len(labels)-safe_total
summary=[]
for name,fn in rules.items():
    tp=fp=tn=fnn=0
    for x in labels:
        pred=fn(x); safe=x["safe"]==1
        if pred and safe: tp+=1
        elif pred and not safe: fp+=1
        elif (not pred) and safe: fnn+=1
        else: tn+=1
    coverage=tp/safe_total if safe_total else 0.0
    summary.append({"rule":name,"labels":len(labels),"safe_total":safe_total,"unsafe_total":unsafe_total,
                    "true_safe":tp,"false_safe":fp,"true_unsafe":tn,"false_unsafe":fnn,
                    "safe_coverage":coverage,
                    "advance":bool(len(labels)>=10 and fp==0 and coverage>=0.50)})

print("F_PE_DYNTOP_PREDICT01_CASES="+json.dumps(case_results,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT01_LABELS="+json.dumps(labels,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT01_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
failed_cases=sum(not x["ok"] for x in case_results)
print("F_PE_DYNTOP_PREDICT01_INCOMPLETE_CASES="+str(failed_cases))
print("F_PE_DYNTOP_PREDICT01=PASS")
