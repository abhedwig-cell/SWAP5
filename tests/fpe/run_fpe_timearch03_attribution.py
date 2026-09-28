#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from collections import defaultdict
from pathlib import Path

base_exe=Path(sys.argv[1])
trace_exe=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
base=bank["baseline_policy"]
cases=[f"{m}/{r}" for m in materials for r in regimes]

def command(exe,cid):
    mid,rid=cid.split("/")
    m=materials[mid]; r=regimes[rid]
    dtmin=base["dtmin_day"]; dtmax=base["dtmax_day"]; dt0=math.sqrt(dtmin*dtmax)
    return [str(exe),cid,"REF",
            str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
            str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),
            str(r["horizon_day"]),str(dtmin),str(dtmax),str(dt0),
            str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
            str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),
            str(base["head_abs_tol"])]

def parse_result(stdout):
    line=next((x for x in stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line: raise RuntimeError("missing result")
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={k.lower():int(d[k]) for k in ints}
    out.update({k.lower():float(d[k]) for k in floats})
    return out

def run(exe,cid):
    cp=subprocess.run(command(exe,cid),text=True,capture_output=True)
    if cp.returncode:
        raise RuntimeError(f"{cid} failed: {cp.stdout[-1000:]} {cp.stderr[-1000:]}")
    return parse_result(cp.stdout),cp.stdout

def close(a,b):
    return abs(a-b)<=1e-12*max(1.0,abs(a),abs(b))

def parse_attempts(stdout):
    rows=[]
    for line in stdout.splitlines():
        if not line.startswith("F_PE_TIMEARCH03_ATTEMPT|"): continue
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        ints=["HORIZON_CLAMP","SOLVE_OK","NL","BACK","JAC","LIN","PROPOSAL_REASON",
              "DTMAX_HIT","SHADOW_GT_DTMAX","SHADOW_GT_REF"]
        floats=["T0","NOMINAL_DT","TRY_DT","RETRY_DT","REF_NEXT","RH","SHADOW_NEXT","POND","RUNOFF"]
        row={"case":d["CASE"]}
        row.update({k.lower():int(d[k]) for k in ints})
        row.update({k.lower():float(d[k]) for k in floats})
        row["work"]=row["nl"]+row["back"]+row["jac"]+row["lin"]
        row["regime"]=row["case"].split("/")[1]
        rows.append(row)
    return rows

pairs=[]
attempts=[]
int_fields=["attempts","accepted","rejected","growths","reductions","nl","back","jac","lin"]
float_fields=["cum_runoff","top_h","mid_h","bottom_h","pond","storage","max_ledger"]
for cid in cases:
    q,_=run(base_exe,cid)
    t,out=run(trace_exe,cid)
    for k in int_fields:
        if q[k]!=t[k]:
            raise SystemExit(f"preservation integer mismatch {cid} {k}: {q[k]} {t[k]}")
    for k in float_fields:
        if not close(q[k],t[k]):
            raise SystemExit(f"preservation float mismatch {cid} {k}: {q[k]} {t[k]}")
    rows=parse_attempts(out)
    if len(rows)!=t["attempts"]:
        raise SystemExit(f"attribution incomplete {cid}: {len(rows)} != {t['attempts']}")
    attempts.extend(rows)
    pairs.append({"case":cid,"preserved":True,"attempts":t["attempts"],"accepted":t["accepted"],"rejected":t["rejected"]})

accepted=[x for x in attempts if x["solve_ok"]==1]
failed=[x for x in attempts if x["solve_ok"]==0]
if len(accepted)!=sum(x["accepted"] for x in [parse_result(run(trace_exe,c)[1]) for c in cases]):
    raise SystemExit("accepted trace count mismatch")

reason_names={0:"KEEP",1:"GROW_LOW_ITER",2:"SHRINK_MAX_ITER",3:"GROW_THEN_SHRINK"}
reason_summary={}
for code,name in reason_names.items():
    xs=[x for x in accepted if x["proposal_reason"]==code]
    reason_summary[name]={
        "steps":len(xs),
        "work":sum(x["work"] for x in xs),
        "median_dt":statistics.median([x["try_dt"] for x in xs]) if xs else None,
    }

ratios=[x["shadow_next"]/x["ref_next"] for x in accepted if x["ref_next"]>0 and x["shadow_next"]>=0]
summary={
    "cases":len(cases),
    "attempts":len(attempts),
    "accepted_steps":len(accepted),
    "solver_retries":len(failed),
    "proposal_reasons":reason_summary,
    "dtmax_hits":sum(x["dtmax_hit"] for x in accepted),
    "dtmax_hit_fraction":sum(x["dtmax_hit"] for x in accepted)/len(accepted) if accepted else 0,
    "horizon_clamps":sum(x["horizon_clamp"] for x in attempts),
    "horizon_clamp_fraction":sum(x["horizon_clamp"] for x in attempts)/len(attempts) if attempts else 0,
    "shadow_gt_dtmax":sum(x["shadow_gt_dtmax"] for x in accepted),
    "shadow_gt_dtmax_fraction":sum(x["shadow_gt_dtmax"] for x in accepted)/len(accepted) if accepted else 0,
    "shadow_gt_ref":sum(x["shadow_gt_ref"] for x in accepted),
    "shadow_gt_ref_fraction":sum(x["shadow_gt_ref"] for x in accepted)/len(accepted) if accepted else 0,
    "median_shadow_ref_ratio":statistics.median(ratios) if ratios else None,
    "total_work":sum(x["work"] for x in attempts),
    "retry_work":sum(x["work"] for x in failed),
}

by_regime={}
for rid in regimes:
    xs=[x for x in accepted if x["regime"]==rid]
    fr=[x["shadow_next"]/x["ref_next"] for x in xs if x["ref_next"]>0 and x["shadow_next"]>=0]
    by_regime[rid]={
        "accepted_steps":len(xs),
        "work":sum(x["work"] for x in xs),
        "dtmax_hit_fraction":sum(x["dtmax_hit"] for x in xs)/len(xs) if xs else 0,
        "shadow_gt_dtmax_fraction":sum(x["shadow_gt_dtmax"] for x in xs)/len(xs) if xs else 0,
        "shadow_gt_ref_fraction":sum(x["shadow_gt_ref"] for x in xs)/len(xs) if xs else 0,
        "median_shadow_ref_ratio":statistics.median(fr) if fr else None,
    }
summary["by_regime"]=by_regime
summary["fixed_ceiling_material"]=bool(summary["dtmax_hit_fraction"]>=0.25 and summary["shadow_gt_dtmax_fraction"]>=0.25)

print("F_PE_TIMEARCH03_PRESERVATION="+json.dumps(pairs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH03_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH03=PASS")
