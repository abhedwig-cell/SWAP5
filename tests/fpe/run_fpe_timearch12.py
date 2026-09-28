#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
base_bank=json.loads(Path(sys.argv[2]).read_text())
val_bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in base_bank["materials"]}
base=base_bank["baseline_policy"]

def run(mid,reg,mode):
    m=materials[mid]
    cid=f"{mid}/{reg['id']}"
    dtmin=base["dtmin_day"]
    dtmax=base["dtmax_day"] if mode=="REFERENCE" else 4.0*base["dtmax_day"]
    dt0=math.sqrt(base["dtmin_day"]*base["dtmax_day"])
    cmd=[str(exe),cid,mode,
         str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(reg["h0_cm"]),str(reg["rain_cm_day"]),
         str(val_bank["horizon_day"]),str(dtmin),str(dtmax),str(dt0),
         str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),
         str(base["head_abs_tol"]),mode,"1.0","1.0","1.0"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"case":cid,"regime_class":reg["class"],"mode":mode,"ok":False,
                "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEARCH12_RESULT|")),None)
    if not line:
        return {"case":cid,"regime_class":reg["class"],"mode":mode,"ok":False,
                "stderr":"missing result","stdout":cp.stdout[-1200:]}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GUARD_CHECKS","GUARD_REJECTS","H0_RELEASES","H0_BLOCKS","H0_FALLBACKS",
          "GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"regime_class":reg["class"],"mode":mode,"ok":True}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

def strict_gate(c,q):
    if not c["ok"] or not q["ok"]: return False,"FAIL",{}
    metrics={
      "runoff_diff":abs(c["cum_runoff"]-q["cum_runoff"]),
      "storage_diff":abs(c["storage"]-q["storage"]),
      "pond_diff":abs(c["pond"]-q["pond"]),
      "max_head_diff":max(abs(c[k]-q[k]) for k in ("top_h","mid_h","bottom_h")),
    }
    if c["max_ledger"]>5e-8: return False,"LEDGER",metrics
    if metrics["runoff_diff"]>1e-4: return False,"RUNOFF",metrics
    if metrics["storage_diff"]>1e-4: return False,"STORAGE",metrics
    if metrics["pond_diff"]>1e-4: return False,"POND",metrics
    if metrics["max_head_diff"]>1e-3: return False,"HEAD",metrics
    if c["rejected"]>max(2*q["rejected"],math.ceil(0.25*c["attempts"])): return False,"RETRY",metrics
    return True,"PASS",metrics

def pc1_gate(c,q):
    if not c["ok"] or not q["ok"]: return False,"FAIL",{}
    rd=abs(c["cum_runoff"]-q["cum_runoff"])
    sd=abs(c["storage"]-q["storage"])
    pd=abs(c["pond"]-q["pond"])
    hd=max(abs(c[k]-q[k]) for k in ("top_h","mid_h","bottom_h"))
    metrics={"runoff_diff":rd,"storage_diff":sd,"pond_diff":pd,"max_head_diff":hd}
    if c["max_ledger"]>5e-8: return False,"LEDGER",metrics
    if abs(q["cum_runoff"])<1.0:
        if rd>0.01: return False,"RUNOFF",metrics
    elif rd>0.01*abs(q["cum_runoff"]):
        return False,"RUNOFF",metrics
    if sd>max(0.01,0.005*abs(q["storage"])): return False,"STORAGE",metrics
    if pd>0.02: return False,"POND",metrics
    if hd>2.0: return False,"HEAD",metrics
    if c["rejected"]>max(2*q["rejected"],math.ceil(0.25*c["attempts"])): return False,"RETRY",metrics
    return True,"PASS",metrics

pairs=[]
for mid in val_bank["materials"]:
    for reg in val_bank["regimes"]:
        q=run(mid,reg,"REFERENCE")
        c=run(mid,reg,"H0_APPLICATION")
        strict_ok,strict_reason,strict_metrics=strict_gate(c,q)
        pc1_ok,pc1_reason,pc1_metrics=pc1_gate(c,q)
        reduction=(1-c["work_index"]/q["work_index"]) if c["ok"] and q["ok"] and q["work_index"] else None
        pairs.append({
          "case":c["case"],"material":mid,"regime_class":reg["class"],
          "reference":q,"candidate":c,
          "strict_pass":strict_ok,"strict_reason":strict_reason,"strict_metrics":strict_metrics,
          "pc1_pass":pc1_ok,"pc1_reason":pc1_reason,"pc1_metrics":pc1_metrics,
          "work_reduction":reduction
        })

valid=[x for x in pairs if x["work_reduction"] is not None]
reductions=[x["work_reduction"] for x in valid]
by_regime={}
for x in valid:
    by_regime.setdefault(x["regime_class"],[]).append(x["work_reduction"])
regime_med={k:statistics.median(v) for k,v in by_regime.items()}

strict_pass=sum(x["strict_pass"] for x in pairs)
pc1_pass=sum(x["pc1_pass"] for x in pairs)
wetpond_strict=all(x["strict_pass"] for x in pairs if x["regime_class"] in ("WET","POND"))
wetpond_pc1=all(x["pc1_pass"] for x in pairs if x["regime_class"] in ("WET","POND"))
median_red=statistics.median(reductions) if reductions else None
noninferior=sum(x["work_reduction"]>=0 for x in valid)/len(valid) if valid else 0.0
regime_ok=all(v>=0 for v in regime_med.values()) if regime_med else False
perf_ok=(median_red is not None and median_red>=0.15 and noninferior>=0.75 and regime_ok)

strict_advance=(strict_pass>=15 and wetpond_strict and perf_ok)
pc1_advance=(pc1_pass>=15 and wetpond_pc1 and perf_ok)

summary={
  "cases":len(pairs),
  "strict_pass":strict_pass,
  "pc1_pass":pc1_pass,
  "wetpond_strict":wetpond_strict,
  "wetpond_pc1":wetpond_pc1,
  "median_work_reduction":median_red,
  "noninferior_fraction":noninferior,
  "regime_median_work_reduction":regime_med,
  "performance_pass":perf_ok,
  "strict_advance":strict_advance,
  "pc1_advance":pc1_advance,
  "h0_releases":sum(x["candidate"].get("h0_releases",0) for x in pairs),
  "h0_blocks":sum(x["candidate"].get("h0_blocks",0) for x in pairs),
  "h0_fallbacks":sum(x["candidate"].get("h0_fallbacks",0) for x in pairs),
}

print("F_PE_TIMEARCH12_RESULTS="+json.dumps(pairs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH12_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH12=PASS")
