#!/usr/bin/env python3
import json, math, statistics, subprocess, sys, time
from pathlib import Path

exe=Path(sys.argv[1])
base_bank=json.loads(Path(sys.argv[2]).read_text())
val_bank=json.loads(Path(sys.argv[3]).read_text())

materials={x["id"]:x for x in base_bank["materials"]}
base=base_bank["baseline_policy"]

def run(mid,reg,mode):
    m=materials[mid]
    dtmin=base["dtmin_day"]; dtmax=base["dtmax_day"]
    dt0=math.sqrt(dtmin*dtmax) if mode=="REFERENCE" else val_bank["candidate"]["bootstrap_dt_day"]
    cmd=[str(exe),f"{mid}/{reg['id']}",mode,
         str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(reg["h0_cm"]),str(reg["rain_cm_day"]),str(val_bank["horizon_day"]),
         str(dtmin),str(dtmax),str(dt0),str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),str(base["head_abs_tol"]),
         mode,"1.0","1.0","1.0"]
    t0=time.perf_counter()
    cp=subprocess.run(cmd,text=True,capture_output=True)
    sec=time.perf_counter()-t0
    if cp.returncode:
        return {"case":f"{mid}/{reg['id']}","material":mid,"regime_class":reg["class"],"policy":mode,
                "ok":False,"seconds":sec,"stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEARCH16_RESULT|")),None)
    if not line:
        return {"case":f"{mid}/{reg['id']}","material":mid,"regime_class":reg["class"],"policy":mode,
                "ok":False,"seconds":sec,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","TRANSITION_REFINES","FALLBACK_ENTRIES","RETRY_WORK","TRANSITION_DISCARD_WORK",
          "GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":f"{mid}/{reg['id']}","material":mid,"regime_class":reg["class"],"policy":mode,"ok":True,"seconds":sec}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

def gate(c,q):
    if not c["ok"] or not q["ok"]: return False,"FAIL",{}
    rd=abs(c["cum_runoff"]-q["cum_runoff"])
    runoff_ok=rd<=0.01 if abs(q["cum_runoff"])<1.0 else rd<=0.01*abs(q["cum_runoff"])
    sd=abs(c["storage"]-q["storage"])
    hd=max(abs(c[k]-q[k]) for k in ("top_h","mid_h","bottom_h"))
    pd=abs(c["pond"]-q["pond"])
    metrics={"runoff_diff":rd,"storage_diff":sd,"max_head_diff":hd,"pond_diff":pd}
    if c["max_ledger"]>5e-8: return False,"LEDGER",metrics
    if not runoff_ok: return False,"RUNOFF",metrics
    if sd>max(0.01,0.005*abs(q["storage"])): return False,"STORAGE",metrics
    if hd>2.0: return False,"HEAD",metrics
    if pd>0.02: return False,"POND",metrics
    if c["rejected"]>max(2*q["rejected"],math.ceil(0.25*c["attempts"])): return False,"RETRY",metrics
    return True,"PASS",metrics

pairs=[]
for mid in val_bank["materials"]:
    for reg in val_bank["regimes"]:
        q=run(mid,reg,"REFERENCE")
        c=run(mid,reg,"GUARD_M5")
        ok,why,metrics=gate(c,q)
        red=(1-c["work_index"]/q["work_index"]) if ok and q["ok"] and q["work_index"] else None
        qf=q["retry_work"]/q["work_index"] if q.get("ok") and q["work_index"] else None
        cf=c["retry_work"]/c["work_index"] if c.get("ok") and c["work_index"] else None
        pairs.append({"case":c["case"],"material":mid,"regime_class":reg["class"],
                      "reference":q,"candidate":c,"pass":ok,"reason":why,"metrics":metrics,
                      "work_reduction":red,
                      "retry_fraction_delta":(cf-qf) if cf is not None and qf is not None else None})

passed=[x for x in pairs if x["pass"]]
reds=[x["work_reduction"] for x in passed if x["work_reduction"] is not None]
retry_deltas=[x["retry_fraction_delta"] for x in passed if x["retry_fraction_delta"] is not None]

by_regime={}
by_material={}
for x in pairs:
    by_regime.setdefault(x["regime_class"],[]).append(x)
    by_material.setdefault(x["material"],[]).append(x)

regime_summary={}
for k,xs in by_regime.items():
    rr=[x["work_reduction"] for x in xs if x["pass"] and x["work_reduction"] is not None]
    regime_summary[k]={"pass":sum(x["pass"] for x in xs),"n":len(xs),
                       "median_work_reduction":statistics.median(rr) if rr else None}
material_summary={k:{"pass":sum(x["pass"] for x in xs),"n":len(xs)} for k,xs in by_material.items()}

med=statistics.median(reds) if reds else None
wetpond_ok=all(x["pass"] for x in pairs if x["regime_class"] in ("WET","POND"))
materials_ok=all(v["pass"]>=4 for v in material_summary.values())
regression_ok=all(v["median_work_reduction"] is not None and v["median_work_reduction"]>=-0.05 for v in regime_summary.values())
retry_ok=(max(retry_deltas) if retry_deltas else 1.0)<=0.05
wetpond_floor_ok=all(x["candidate"]["ok"] for x in pairs if x["regime_class"] in ("WET","POND"))

deterministic_pass=(len(passed)>=19 and wetpond_ok and materials_ok and med is not None and med>=0.20 and
                    regression_ok and retry_ok and wetpond_floor_ok)

timing={}
if deterministic_pass:
    ratios=[]
    for mid in val_bank["materials"]:
        for reg in val_bank["regimes"]:
            ref_times=[]; cand_times=[]
            for rep in range(5):
                if rep%2==0:
                    q=run(mid,reg,"REFERENCE"); c=run(mid,reg,"GUARD_M5")
                else:
                    c=run(mid,reg,"GUARD_M5"); q=run(mid,reg,"REFERENCE")
                if not q["ok"] or not c["ok"]:
                    raise SystemExit(f"timing failure {mid}/{reg['id']}")
                ref_times.append(q["seconds"]); cand_times.append(c["seconds"])
            ratio=statistics.median(cand_times)/statistics.median(ref_times)
            timing[f"{mid}/{reg['id']}"]={"reference_seconds":ref_times,"candidate_seconds":cand_times,"median_ratio":ratio}
            ratios.append(ratio)
    timing["aggregate"]={"median_case_ratio":statistics.median(ratios),
                         "cases_over_1p10":sum(r>1.10 for r in ratios),
                         "cases_under_0p90":sum(r<0.90 for r in ratios)}

summary={"pass":len(passed),"cases":len(pairs),"median_work_reduction":med,
         "wetpond_ok":wetpond_ok,"materials_ok":materials_ok,"regression_ok":regression_ok,
         "retry_fraction_gate":retry_ok,"wetpond_solver_floor_ok":wetpond_floor_ok,
         "deterministic_pass":deterministic_pass,"regime":regime_summary,"material":material_summary,
         "timing":timing.get("aggregate")}

print("F_PE_TIMEARCH17_RESULTS="+json.dumps(pairs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH17_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if timing:
    print("F_PE_TIMEARCH17_TIMING="+json.dumps(timing,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH17=PASS")
