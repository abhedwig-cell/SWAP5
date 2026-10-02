#!/usr/bin/env python3
import csv,json,statistics,sys
from pathlib import Path

src=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
lines=src.read_text().splitlines()
abc=[x for x in lines if x.startswith("ABC,")]
timing=[x for x in lines if x.startswith("TIMING,")]

abc_header=abc[0].split(",")[1:]
rows=[]
for line in abc[1:]:
    vals=line.split(",")[1:]
    d=dict(zip(abc_header,vals))
    for k in ["soil","geom","regime","arm","completed","status","fail_step","transaction_calls","attempts","retries","nonlinear","backtracks","headcalc"]:
        d[k]=int(d[k])
    for k in [x for x in abc_header if x not in {"soil","geom","regime","arm","completed","status","fail_step","transaction_calls","attempts","retries","nonlinear","backtracks","headcalc"}]:
        d[k]=float(d[k])
    rows.append(d)

keys={}
for r in rows: keys.setdefault((r["soil"],r["geom"],r["regime"]),{})[r["arm"]]=r
comparison=[]
counts={}
for key,arms in sorted(keys.items()):
    if not all(a in arms for a in (1,2,3)): continue
    A,B,C=arms[1],arms[2],arms[3]
    cls="REVIEW_MODEL_FORM"
    reason=""
    if not B["completed"]:
        cls="B_NOT_ADMITTED";reason=f"status={B['status']} step={B['fail_step']}"
    elif not C["completed"]:
        cls="C_NOT_ADMITTED";reason=f"status={C['status']} step={C['fail_step']}"
    else:
        input_scale=max(B["total_in_cm"],C["total_in_cm"],0.1)
        storage_diff=abs(B["total_storage_cm"]-C["total_storage_cm"])
        bdrain=B["bottom_out_cm"]+B["fast_external_out_cm"]
        cdrain=C["bottom_out_cm"]+C["fast_external_out_cm"]
        drain_diff=abs(bdrain-cdrain)
        theta_diff=max(abs(B[k]-C[k]) for k in ["theta1","theta5","theta10"])
        fast_diff=abs(B["fast_storage_cm"]-C["fast_storage_cm"])
        mass_ok=max(B["max_mass_resid_cm"],C["max_mass_resid_cm"])<=1e-6
        if max(storage_diff,drain_diff,theta_diff,fast_diff)<=1e-8 and mass_ok:
            cls="E0"
        elif storage_diff<=max(.05,.05*input_scale) and drain_diff<=max(.05,.05*input_scale) and theta_diff<=.02 and mass_ok:
            cls="E1"
        else:
            reason="outside E1 thresholds; requires model-form attribution"
        comparison.append(dict(soil=key[0],geom=key[1],regime=key[2],classification=cls,reason=reason,
            B_completed=B["completed"],C_completed=C["completed"],accepted_input_B_cm=B["total_in_cm"],
            accepted_input_C_cm=C["total_in_cm"],storage_diff_cm=(abs(B["total_storage_cm"]-C["total_storage_cm"]) if B["completed"] and C["completed"] else None),
            total_drain_diff_cm=(abs((B["bottom_out_cm"]+B["fast_external_out_cm"])-(C["bottom_out_cm"]+C["fast_external_out_cm"])) if B["completed"] and C["completed"] else None),
            max_theta_diff=(max(abs(B[k]-C[k]) for k in ["theta1","theta5","theta10"]) if B["completed"] and C["completed"] else None),
            max_head_diff_cm=(max(abs(B[k]-C[k]) for k in ["h1_cm","h5_cm","h10_cm"]) if B["completed"] and C["completed"] else None),
            B_fast_storage_cm=B["fast_storage_cm"],C_fast_storage_cm=C["fast_storage_cm"],
            B_fast_external_out_cm=B["fast_external_out_cm"],C_fast_external_out_cm=C["fast_external_out_cm"],
            B_wall_seconds=B["wall_seconds"],C_wall_seconds=C["wall_seconds"],
            B_nonlinear=B["nonlinear"],C_nonlinear=C["nonlinear"],B_retries=B["retries"],C_retries=C["retries"]))
        counts[cls]=counts.get(cls,0)+1

with (out/"abc_comparison.csv").open("w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=list(comparison[0]));w.writeheader();w.writerows(comparison)
with (out/"abc_raw.csv").open("w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=abc_header);w.writeheader();w.writerows(rows)

timing_rows=[]
if timing:
    hdr=timing[0].split(",")[1:]
    for line in timing[1:]:
        vals=line.split(",")[1:];d=dict(zip(hdr,vals))
        for k in ["case_id","soil","geom","regime","arm","repeat","completed","nonlinear","backtracks","headcalc"]:d[k]=int(d[k])
        d["wall_seconds"]=float(d["wall_seconds"]);timing_rows.append(d)
groups={}
for r in timing_rows:
    groups.setdefault((r["case_id"],r["arm"]),[]).append(r)
timing_summary=[]
for case in sorted(set(k[0] for k in groups)):
    rec={"case_id":case}
    valid=True
    for arm,label in [(1,"A"),(2,"B"),(3,"C")]:
        rr=groups.get((case,arm),[])
        if len(rr)!=5 or not all(x["completed"] for x in rr):
            valid=False;rec[label+"_complete"]=False;continue
        xs=[x["wall_seconds"] for x in rr]
        rec[label+"_complete"]=True;rec[label+"_median_s"]=statistics.median(xs);rec[label+"_min_s"]=min(xs);rec[label+"_max_s"]=max(xs)
        rec[label+"_median_nonlinear"]=statistics.median(x["nonlinear"] for x in rr)
        rec[label+"_median_backtracks"]=statistics.median(x["backtracks"] for x in rr)
    if rec.get("B_complete") and rec.get("C_complete") and rec["C_median_s"]>0:
        rec["B_over_C_speed_ratio"]=rec["B_median_s"]/rec["C_median_s"]
    timing_summary.append(rec)
if timing_summary:
    fields=[]
    for r in timing_summary:
        for k in r:
            if k not in fields:fields.append(k)
    with (out/"abc_timing.csv").open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(timing_summary)

summary={
 "screen_cases":len(comparison),
 "classification_counts":counts,
 "all_completed_B":sum(1 for x in comparison if x["B_completed"]),
 "all_completed_C":sum(1 for x in comparison if x["C_completed"]),
 "timing_cases":timing_summary,
 "claim_boundary":"Exploratory production A/B/C screen. E2/E3 require manual model-form attribution; CI timings are not portable speed guarantees."
}
(out/"abc_summary.json").write_text(json.dumps(summary,indent=2)+"\n")
print(json.dumps(summary,indent=2))
