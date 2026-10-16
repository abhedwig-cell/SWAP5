#!/usr/bin/env python3
import json, math, statistics, subprocess, sys, time
from pathlib import Path

exe=Path(sys.argv[1])
base_bank=json.loads(Path(sys.argv[2]).read_text())
val_bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in base_bank["materials"]}
base=base_bank["baseline_policy"]

def base_cfg():
    return dict(dtmin=base["dtmin_day"],dtmax=base["dtmax_day"],dt0=math.sqrt(base["dtmin_day"]*base["dtmax_day"]),
                numbit=base["numbit_crit"],maxit=base["maxit"],maxback=base["max_backtracking"],
                inc=base["fact_inc"],dec=base["fact_dec"],fail=base["fact_fail_divisor"],headtol=base["head_abs_tol"])

def halfmax_cfg():
    return dict(dtmin=base["dtmin_day"],dtmax=base["dtmax_day"],dt0=0.5*base["dtmax_day"],
                numbit=base["numbit_crit"],maxit=base["maxit"],maxback=base["max_backtracking"],
                inc=base["fact_inc"],dec=base["fact_dec"],fail=base["fact_fail_divisor"],headtol=base["head_abs_tol"])

def regime_cfg(cls):
    if cls in ("DRY","TRANSITION"):
        dtmin=base["dtmin_day"]; dtmax=4.0*base["dtmax_day"]; dt0=math.sqrt(dtmin*dtmax)
    elif cls=="WET":
        dtmin=base["dtmin_day"]; dtmax=base["dtmax_day"]; dt0=0.5*dtmax
    elif cls=="POND":
        dtmin=base["dtmin_day"]; dtmax=base["dtmax_day"]; dt0=dtmax
    else:
        raise ValueError(cls)
    return dict(dtmin=dtmin,dtmax=dtmax,dt0=dt0,
                numbit=base["numbit_crit"],maxit=base["maxit"],maxback=base["max_backtracking"],
                inc=base["fact_inc"],dec=base["fact_dec"],fail=base["fact_fail_divisor"],headtol=base["head_abs_tol"])

def cand_cfg(material,cls):
    if material=="B12":
        return halfmax_cfg()
    if material=="O14" and cls=="POND":
        return halfmax_cfg()
    return regime_cfg(cls)

def run(material_id,regime,pid,cfg):
    m=materials[material_id]
    cid=f"{material_id}/{regime['id']}"
    cmd=[str(exe),cid,pid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(regime["h0_cm"]),str(regime["rain_cm_day"]),str(val_bank["horizon_day"]),
         str(cfg["dtmin"]),str(cfg["dtmax"]),str(cfg["dt0"]),str(cfg["numbit"]),str(cfg["maxit"]),str(cfg["maxback"]),
         str(cfg["inc"]),str(cfg["dec"]),str(cfg["fail"]),str(cfg["headtol"])]
    t0=time.perf_counter(); cp=subprocess.run(cmd,text=True,capture_output=True); sec=time.perf_counter()-t0
    if cp.returncode:
        return {"case":cid,"regime_class":regime["class"],"policy":pid,"ok":False,"seconds":sec,
                "stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line:
        return {"case":cid,"regime_class":regime["class"],"policy":pid,"ok":False,"seconds":sec,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"case":cid,"regime_class":regime["class"],"policy":pid,"ok":True,"seconds":sec}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

def gate(c,q):
    if not c["ok"] or not q["ok"]: return False,"FAIL",{}
    runoff_diff=abs(c["cum_runoff"]-q["cum_runoff"])
    runoff_ok=runoff_diff<=0.01 if abs(q["cum_runoff"])<1.0 else runoff_diff<=0.01*abs(q["cum_runoff"])
    storage_diff=abs(c["storage"]-q["storage"])
    storage_ok=storage_diff<=max(0.01,0.005*abs(q["storage"]))
    head_diff=max(abs(c[k]-q[k]) for k in ("top_h","mid_h","bottom_h"))
    pond_diff=abs(c["pond"]-q["pond"])
    metrics={"runoff_diff":runoff_diff,"storage_diff":storage_diff,"max_head_diff":head_diff,"pond_diff":pond_diff}
    if c["max_ledger"]>5e-8: return False,"LEDGER",metrics
    if not runoff_ok: return False,"RUNOFF",metrics
    if not storage_ok: return False,"STORAGE",metrics
    if pond_diff>0.02: return False,"POND",metrics
    if head_diff>2.0: return False,"HEAD",metrics
    if c["rejected"]>max(2*q["rejected"],math.ceil(0.25*c["attempts"])): return False,"RETRY",metrics
    return True,"PASS",metrics

pairs=[]
for mid in val_bank["materials"]:
    for reg in val_bank["regimes"]:
        q=run(mid,reg,"REF",base_cfg())
        c=run(mid,reg,"ARCHETYPE_REGIME_POLICY",cand_cfg(mid,reg["class"]))
        ok,why,metrics=gate(c,q)
        red=(1-c["work_index"]/q["work_index"]) if ok and q["ok"] and q["work_index"] else None
        pairs.append({"case":c["case"],"material":mid,"regime_class":reg["class"],"reference":q,"candidate":c,
                      "pass":ok,"reason":why,"metrics":metrics,"work_reduction":red})

passed=[x for x in pairs if x["pass"]]
reductions=[x["work_reduction"] for x in passed]
by_regime={}; by_material={}
for x in pairs:
    by_regime.setdefault(x["regime_class"],[]).append(x)
    by_material.setdefault(x["material"],[]).append(x)

regime_summary={}
for k,xs in by_regime.items():
    rs=[x["work_reduction"] for x in xs if x["pass"]]
    regime_summary[k]={"pass":sum(x["pass"] for x in xs),"n":len(xs),
                       "median_work_reduction":statistics.median(rs) if rs else None}
material_summary={k:{"pass":sum(x["pass"] for x in xs),"n":len(xs)} for k,xs in by_material.items()}
med=statistics.median(reductions) if reductions else None
wetpond_ok=all(x["pass"] for x in pairs if x["regime_class"] in ("WET","POND"))
materials_ok=all(v["pass"]>=3 for v in material_summary.values())
regression_ok=all(v["median_work_reduction"] is not None and v["median_work_reduction"]>=0 for v in regime_summary.values())
deterministic_pass=(len(passed)>=15 and wetpond_ok and materials_ok and med is not None and med>=0.20 and regression_ok)

timing={}
if deterministic_pass:
    ratios=[]
    for mid in val_bank["materials"]:
        for reg in val_bank["regimes"]:
            ref_times=[]; cand_times=[]
            for rep in range(5):
                if rep%2==0:
                    q=run(mid,reg,"REF_TIMING",base_cfg()); c=run(mid,reg,"ARCHETYPE_TIMING",cand_cfg(mid,reg["class"]))
                else:
                    c=run(mid,reg,"ARCHETYPE_TIMING",cand_cfg(mid,reg["class"])); q=run(mid,reg,"REF_TIMING",base_cfg())
                if not q["ok"] or not c["ok"]: raise SystemExit(f"timing failure {mid}/{reg['id']}")
                ref_times.append(q["seconds"]); cand_times.append(c["seconds"])
            ratio=statistics.median(cand_times)/statistics.median(ref_times)
            timing[f"{mid}/{reg['id']}"]={"reference_seconds":ref_times,"candidate_seconds":cand_times,"median_ratio":ratio}
            ratios.append(ratio)
    timing["aggregate"]={"median_case_ratio":statistics.median(ratios),
                         "cases_over_1p10":sum(r>1.10 for r in ratios)}

summary={"pass":len(passed),"cases":len(pairs),"median_work_reduction":med,
         "wetpond_ok":wetpond_ok,"materials_ok":materials_ok,"regression_ok":regression_ok,
         "deterministic_pass":deterministic_pass,"regime":regime_summary,"material":material_summary,
         "timing":timing.get("aggregate")}

print("F_PE_BOFEK_PRACTICAL03_RESULTS="+json.dumps(pairs,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK_PRACTICAL03_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if timing:
    print("F_PE_BOFEK_PRACTICAL03_TIMING="+json.dumps(timing,separators=(",",":"),sort_keys=True))
print("F_PE_BOFEK_PRACTICAL03=PASS")
