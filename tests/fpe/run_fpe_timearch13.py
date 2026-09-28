#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=list(bank["screening_cases"])

candidates=[
 ("R20_H20",0.20,-20.0),("R20_H10",0.20,-10.0),("R20_H05",0.20,-5.0),
 ("R40_H20",0.40,-20.0),("R40_H10",0.40,-10.0),("R40_H05",0.40,-5.0)
]

def run(cid,mode,target,threshold):
    mid,rid=cid.split("/")
    m=materials[mid]; r=regimes[rid]
    cmd=[str(exe),cid,mode,
         str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         "0.001","0.02","0.005",
         str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),
         str(base["head_abs_tol"]),mode,str(target),str(threshold)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"case":cid,"policy":mode,"ok":False,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEARCH13_RESULT|")),None)
    if not line:
        return {"case":cid,"policy":mode,"ok":False,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","RISK_EVENTS","NL","BACK","JAC","LIN","RETRY_NL","RETRY_BACK","RETRY_JAC","RETRY_LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"policy":mode,"ok":True}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    out["retry_work"]=out["retry_nl"]+out["retry_back"]+out["retry_jac"]+out["retry_lin"]
    return out

def gate(c,q):
    if not c["ok"] or not q["ok"]: return False,"FAIL"
    rd=abs(c["cum_runoff"]-q["cum_runoff"])
    runoff_ok=rd<=0.01 if abs(q["cum_runoff"])<1.0 else rd<=0.01*abs(q["cum_runoff"])
    sd=abs(c["storage"]-q["storage"])
    hd=max(abs(c[k]-q[k]) for k in ("top_h","mid_h","bottom_h"))
    pd=abs(c["pond"]-q["pond"])
    if c["max_ledger"]>5e-8: return False,"LEDGER"
    if not runoff_ok: return False,"RUNOFF"
    if sd>max(0.01,0.005*abs(q["storage"])): return False,"STORAGE"
    if hd>2.0: return False,"HEAD"
    if pd>0.02: return False,"POND"
    if c["rejected"]>max(2*q["rejected"],math.ceil(0.25*c["attempts"])): return False,"RETRY"
    return True,"PASS"

refs={cid:run(cid,"LEGACY",1.0,-10.0) for cid in cases}
rows=[]; summary=[]
for pid,target,threshold in candidates:
    passed=[]; reductions=[]; reasons={}; wet_ok=True; retry_fracs=[]; ref_retry_fracs=[]; by_reg={}
    for cid in cases:
        c=run(cid,"AUTO",target,threshold); c["policy"]=pid; q=refs[cid]
        ok,why=gate(c,q); c["pc1_pass"]=ok; c["pc1_reason"]=why; rows.append(c)
        reasons[why]=reasons.get(why,0)+1
        reg=cid.split("/")[1]
        by_reg.setdefault(reg,[])
        if ok:
            passed.append(c)
            red=1-c["work_index"]/q["work_index"]
            reductions.append(red); by_reg[reg].append(red)
        else:
            by_reg[reg].append(None)
        if ("/WET" in cid or "/POND" in cid) and not ok: wet_ok=False
        if c.get("ok") and c["work_index"]>0: retry_fracs.append(c["retry_work"]/c["work_index"])
        if q.get("ok") and q["work_index"]>0: ref_retry_fracs.append(q["retry_work"]/q["work_index"])
    med=statistics.median(reductions) if reductions else None
    regime_med={}
    regime_bad=False
    for reg,vals in by_reg.items():
        vals=[v for v in vals if v is not None]
        regime_med[reg]=statistics.median(vals) if vals else None
        if vals and regime_med[reg] < -0.05: regime_bad=True
    retry_delta=(statistics.median(retry_fracs)-statistics.median(ref_retry_fracs)) if retry_fracs and ref_retry_fracs else None
    advance=(len(passed)>=15 and wet_ok and med is not None and med>=0.15 and not regime_bad and retry_delta is not None and retry_delta<=0.05)
    summary.append({"policy":pid,"pass":len(passed),"cases":len(cases),"wetpond_ok":wet_ok,
                    "median_work_reduction":med,"regime_median_work_reduction":regime_med,
                    "retry_fraction_delta":retry_delta,"reasons":reasons,"advance":advance})

print("F_PE_TIMEARCH13_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH13_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if len(refs)!=len(cases) or not all(x["ok"] for x in refs.values()):
    raise SystemExit("legacy baseline incomplete")
print("F_PE_TIMEARCH13=PASS")
