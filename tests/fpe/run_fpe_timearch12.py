#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=list(bank["screening_cases"])
targets=[3.0,4.0,5.0,6.0]

def run(cid,mode,target):
    mid,rid=cid.split("/")
    m=materials[mid]; r=regimes[rid]
    retry_floor=base["dtmin_day"]
    legacy_dtmax=base["dtmax_day"]
    initial_dt=math.sqrt(base["dtmin_day"]*base["dtmax_day"]) if mode=="LEGACY" else 0.005
    cmd=[str(exe),cid,f"{mode}_{target}",
         str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
         str(retry_floor),str(legacy_dtmax),str(initial_dt),
         str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),str(base["head_abs_tol"]),
         mode,str(target)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"case":cid,"mode":mode,"target":target,"ok":False,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEARCH12_RESULT|")),None)
    if not line:
        return {"case":cid,"mode":mode,"target":target,"ok":False,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN",
          "RETRY_NL","RETRY_BACK","RETRY_JAC","RETRY_LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"mode":mode,"target":target,"ok":True}
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

refs={cid:run(cid,"LEGACY",4.0) for cid in cases}
rows=[]; summary=[]
for target in targets:
    passed=[]; reductions=[]; wet_ok=True; reasons={}
    regime_red={k:[] for k in regimes}
    retry_frac_diff=[]
    for cid in cases:
        c=run(cid,"AUTO",target); q=refs[cid]
        ok,why=gate(c,q)
        c["pc1_pass"]=ok; c["pc1_reason"]=why; rows.append(c)
        reasons[why]=reasons.get(why,0)+1
        if ok:
            passed.append(c)
            red=1-c["work_index"]/q["work_index"]
            reductions.append(red)
            regime_red[cid.split("/")[1]].append(red)
            qf=q["retry_work"]/q["work_index"] if q["work_index"] else 0.0
            cf=c["retry_work"]/c["work_index"] if c["work_index"] else 0.0
            retry_frac_diff.append(cf-qf)
        if ("/WET" in cid or "/POND" in cid) and not ok: wet_ok=False
    med=statistics.median(reductions) if reductions else None
    by_regime={k:(statistics.median(v) if v else None) for k,v in regime_red.items()}
    no_regression=all(v is None or v>=-0.05 for v in by_regime.values())
    retry_ok=(max(retry_frac_diff) if retry_frac_diff else 1.0)<=0.05
    advance=len(passed)>=15 and wet_ok and med is not None and med>=0.15 and no_regression and retry_ok
    summary.append({"target":target,"pass":len(passed),"cases":len(cases),"wetpond_ok":wet_ok,
                    "median_work_reduction":med,"regime_median_work_reduction":by_regime,
                    "retry_fraction_gate":retry_ok,"reasons":reasons,"advance":advance})

print("F_PE_TIMEARCH12_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH12_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not all(x["ok"] for x in refs.values()):
    raise SystemExit("legacy baseline incomplete")
print("F_PE_TIMEARCH12=PASS")
