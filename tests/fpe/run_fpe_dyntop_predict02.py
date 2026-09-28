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
    labels=[]
    for line in cp.stdout.splitlines():
        if not line.startswith("F_PE_DYNTOP_PREDICT02_LABEL|"): continue
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        ints=["PRED_OK","PRED_REGIME","PRED_RUNOFF_POT","HIST2","FULL_OK","HALF_OK","SAFE"]
        floats=["T0","DT","PRED_POND","PRED_RUNOFF","PRED_SURFACE_HEAD","PRED_Q0","R_LAST","R_PREV","TREND","EH","EPOND","ERUN","ESTORE"]
        rec={"case":cid}
        rec.update({k.lower():int(d[k]) for k in ints})
        rec.update({k.lower():float(d[k]) for k in floats})
        labels.append(rec)
    return {"case":cid,"ok":cp.returncode==0 and "F_PE_DYNTOP_PREDICT02=PASS" in cp.stdout,"labels":len(labels),
            "stdout":cp.stdout[-800:] if cp.returncode else "","stderr":cp.stderr[-800:] if cp.returncode else ""},labels

case_results=[]; labels=[]
for cid in cases:
    cr,ls=run_case(cid); case_results.append(cr); labels.extend(ls)

def base_safe(x):
    return x["pred_ok"]==1 and x["pred_runoff_pot"]==0 and x["hist2"]==1

rules={
 "H0":lambda x:base_safe(x) and x["r_last"]<=0.10,
 "H1":lambda x:base_safe(x) and x["r_last"]<=0.20,
 "H2":lambda x:base_safe(x) and x["trend"]<=1.00,
 "H3":lambda x:base_safe(x) and x["r_last"]<=0.20 and x["trend"]<=1.25,
}

safe_total=sum(x["safe"]==1 for x in labels)
unsafe_total=len(labels)-safe_total
summary=[]
for name,rule in rules.items():
    tp=fp=tn=fn=0
    for x in labels:
        pred=rule(x); safe=x["safe"]==1
        if pred and safe: tp+=1
        elif pred and not safe: fp+=1
        elif not pred and safe: fn+=1
        else: tn+=1
    cov=tp/safe_total if safe_total else 0.0
    summary.append({"rule":name,"labels":len(labels),"safe_total":safe_total,"unsafe_total":unsafe_total,
                    "true_safe":tp,"false_safe":fp,"true_unsafe":tn,"false_unsafe":fn,
                    "safe_coverage":cov,
                    "advance":bool(len(labels)>=10 and fp==0 and cov>=0.50)})

print("F_PE_DYNTOP_PREDICT02_CASES="+json.dumps(case_results,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT02_LABELS="+json.dumps(labels,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT02_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_DYNTOP_PREDICT02_INCOMPLETE_CASES="+str(sum(not x["ok"] for x in case_results)))
print("F_PE_DYNTOP_PREDICT02=PASS")
