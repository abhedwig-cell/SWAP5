#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes=[
 {"id":"TRANSITION","h0":-100.0,"rain":4.0},
 {"id":"WET","h0":-20.0,"rain":12.0},
 {"id":"POND","h0":-5.0,"rain":25.0},
]
dts=[0.01,0.005]
modes=["BE_FULL","BDF2_RAW","BDF2_FALLBACK"]

def run(mid,reg,dt,mode):
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(reg["h0"]),str(reg["rain"]),str(dt),mode]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT12_RESULT|")),None)
    if cp.returncode or not line:
        return {"material":mid,"regime":reg["id"],"dt":dt,"mode":mode,"ok":False,
                "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["STEPS","BDF_STEPS","BE_BOOT","BE_TRANS","DISCARDED_BDF","F2H","H2F","NL","BACK","JAC","LIN","WORK"]
    floats=["RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_EQ_RES"]
    out={"material":mid,"regime":reg["id"],"dt":dt,"mode":mode,"ok":True}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    return out

rows=[]
for mid in ["B01","B12","O05","O14"]:
  for reg in regimes:
    for dt in dts:
      for mode in modes:
        rows.append(run(mid,reg,dt,mode))

refs={}
for mid in ["B01","B12","O05","O14"]:
  for reg in regimes:
    refs[(mid,reg["id"])]=run(mid,reg,0.0025,"BE_FULL")

def max_head_err(a,b):
    return max(abs(a[k]-b[k]) for k in ("top_h","mid_h","bottom_h"))

groups={}
for r in rows:
    groups[(r["material"],r["regime"],r["dt"],r["mode"])]=r

fallback=[r for r in rows if r["mode"]=="BDF2_FALLBACK"]
complete_fb=[r for r in fallback if r["ok"]]
pond_ok=all(r["ok"] for r in fallback if r["regime"]=="POND")
ledger_ok=all(r["max_eq_res"]<=5e-8 for r in complete_fb)

transition_pairs=[]
smooth_identity=[]
not_worse=True
for fb in complete_fb:
    key=(fb["material"],fb["regime"],fb["dt"])
    raw=groups.get((*key,"BDF2_RAW"))
    ref=refs[(fb["material"],fb["regime"])]
    if not ref["ok"]: continue
    if raw and raw["ok"]:
        ef=max_head_err(fb,ref); er=max_head_err(raw,ref)
        fb["ref_head_error"]=ef; raw["ref_head_error"]=er
        if ef>er+0.01: not_worse=False
        if fb["discarded_bdf"]>0:
            transition_pairs.append((ef,er))
        else:
            smooth_identity.append({
              "case":key,
              "head":max_head_err(fb,raw),
              "storage":abs(fb["storage"]-raw["storage"]),
              "runoff":abs(fb["runoff"]-raw["runoff"])
            })

transition_improves=False
if transition_pairs:
    diffs=[er-ef for ef,er in transition_pairs]
    transition_improves=statistics.median(diffs)>0.0

smooth_identical=all(x["head"]<=1e-10 and x["storage"]<=1e-10 and x["runoff"]<=1e-10 for x in smooth_identity)

work_ratios=[]
for fb in complete_fb:
    raw=groups.get((fb["material"],fb["regime"],fb["dt"],"BDF2_RAW"))
    if raw and raw["ok"] and raw["work"]>0:
        work_ratios.append(fb["work"]/raw["work"])
median_work_ratio=statistics.median(work_ratios) if work_ratios else None

transition_accounting=all(r["discarded_bdf"]==r["be_trans"] for r in complete_fb)

summary={
 "fallback_complete":len(complete_fb),"fallback_total":len(fallback),
 "pond_ok":pond_ok,"ledger_ok":ledger_ok,"transition_accounting":transition_accounting,
 "transition_cases":len(transition_pairs),"transition_improves":transition_improves,
 "smooth_identity_cases":len(smooth_identity),"smooth_identical":smooth_identical,
 "not_worse":not_worse,"median_work_ratio":median_work_ratio,
 "ref_complete":sum(r["ok"] for r in refs.values()),"ref_total":len(refs)
}
summary["qualifies"]=(
 len(complete_fb)>=22 and pond_ok and ledger_ok and transition_accounting and not_worse and
 bool(transition_pairs) and transition_improves and smooth_identical and
 median_work_ratio is not None and median_work_ratio<=1.35
)
summary["classification"]="DYNTOP_BDF2_TRANSITION_FALLBACK_QUALIFIED" if summary["qualifies"] else "CLOSED_DYNTOP_BDF2_FALLBACK_NOT_QUALIFIED"

print("F_PE_TIMEINT12_RUNS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12_REFS="+json.dumps(list(refs.values()),separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12_SMOOTH_IDENTITY="+json.dumps(smooth_identity,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12=PASS")
