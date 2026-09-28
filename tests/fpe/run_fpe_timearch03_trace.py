#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

base_exe=Path(sys.argv[1])
trace_exe=Path(sys.argv[2])
bank=json.loads(Path(sys.argv[3]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={x["id"]:x for x in bank["regimes"]}
cfg=bank["baseline_policy"]
cases=list(bank["screening_cases"])

def command(exe,cid):
    mid,rid=cid.split("/")
    m=materials[mid]; r=regimes[rid]
    dtmin=cfg["dtmin_day"]; dtmax=cfg["dtmax_day"]
    dt0=math.sqrt(dtmin*dtmax)
    return [str(exe),cid,"REF",
            str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
            str(m["ksat"]),str(m["lambda"]),
            str(r["h0_cm"]),str(r["rain_cm_day"]),str(r["horizon_day"]),
            str(dtmin),str(dtmax),str(dt0),str(cfg["numbit_crit"]),
            str(cfg["maxit"]),str(cfg["max_backtracking"]),str(cfg["fact_inc"]),
            str(cfg["fact_dec"]),str(cfg["fact_fail_divisor"]),str(cfg["head_abs_tol"])]

def parse_result(stdout):
    line=next((x for x in stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if line is None:
        raise RuntimeError("missing result")
    d={}
    for field in line.split("|")[1:]:
        k,v=field.split("=",1); d[k]=v
    ints=["ATTEMPTS","ACCEPTED","REJECTED","GROWTHS","REDUCTIONS","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={k.lower():int(d[k]) for k in ints}
    out.update({k.lower():float(d[k]) for k in floats})
    return out

def parse_trace(stdout,cid):
    rows=[]
    for line in stdout.splitlines():
        if not line.startswith("F_PE_TIMEARCH03_TRACE|"): continue
        d={}
        for field in line.split("|")[1:]:
            k,v=field.split("=",1); d[k]=v
        ints=["EVENT_CLAMP","NL","BACK","JAC","LIN","DTMAX_LIMITED"]
        floats=["T0","DT_CTRL","DT_EXEC","NEXT_REF","SHADOW_A","SHADOW_B"]
        row={"case":cid,"status":d["STATUS"],"reason":d["REASON"]}
        row.update({k.lower():int(d[k]) for k in ints})
        row.update({k.lower():float(d[k]) for k in floats})
        row["work_index"]=row["nl"]+row["back"]+row["jac"]+row["lin"]
        rows.append(row)
    return rows

def run(exe,cid):
    cp=subprocess.run(command(exe,cid),text=True,capture_output=True)
    if cp.returncode:
        raise RuntimeError(f"{cid} failed: {cp.stdout[-1000:]} {cp.stderr[-1000:]}")
    return cp

compare_keys=["attempts","accepted","rejected","growths","reductions","nl","back","jac","lin",
              "cum_runoff","top_h","mid_h","bottom_h","pond","storage","max_ledger"]
all_traces=[]
case_reports=[]
for cid in cases:
    b=run(base_exe,cid); t=run(trace_exe,cid)
    br=parse_result(b.stdout); tr=parse_result(t.stdout)
    mismatches={k:(br[k],tr[k]) for k in compare_keys if br[k]!=tr[k]}
    if mismatches:
        raise SystemExit(f"trace changed baseline {cid}: {mismatches}")
    rows=parse_trace(t.stdout,cid)
    if len(rows)!=tr["attempts"]:
        raise SystemExit(f"trace count mismatch {cid}: {len(rows)} vs {tr['attempts']}")
    if sum(x["status"]=="ACCEPT" for x in rows)!=tr["accepted"]:
        raise SystemExit(f"accepted trace mismatch {cid}")
    if sum(x["status"]=="REJECT" for x in rows)!=tr["rejected"]:
        raise SystemExit(f"rejected trace mismatch {cid}")
    all_traces.extend(rows)
    case_reports.append({"case":cid,"attempts":tr["attempts"],"accepted":tr["accepted"],
                         "rejected":tr["rejected"],"work_index":tr["nl"]+tr["back"]+tr["jac"]+tr["lin"]})

accepted=[x for x in all_traces if x["status"]=="ACCEPT"]
rejected=[x for x in all_traces if x["status"]=="REJECT"]
reason_counts={}
for x in all_traces:
    reason_counts[x["reason"]]=reason_counts.get(x["reason"],0)+1

limited=[x for x in accepted if x["dtmax_limited"]==1]
ratios_a=[x["shadow_a"]/x["next_ref"] for x in accepted if x["next_ref"]>0]
b_gt=sum(x["shadow_b"]>x["next_ref"]+1e-13 for x in accepted)
b_lt=sum(x["shadow_b"]<x["next_ref"]-1e-13 for x in accepted)
b_eq=len(accepted)-b_gt-b_lt

regime={}
for x in accepted:
    reg=x["case"].split("/")[1]
    d=regime.setdefault(reg,{"accepted":0,"dtmax_limited":0,"shadow_b_gt":0,"shadow_b_lt":0})
    d["accepted"]+=1
    d["dtmax_limited"]+=x["dtmax_limited"]
    d["shadow_b_gt"]+=int(x["shadow_b"]>x["next_ref"]+1e-13)
    d["shadow_b_lt"]+=int(x["shadow_b"]<x["next_ref"]-1e-13)

summary={
    "cases":len(cases),
    "attempts":len(all_traces),
    "accepted":len(accepted),
    "rejected":len(rejected),
    "reason_counts":reason_counts,
    "event_clamps":sum(x["event_clamp"] for x in all_traces),
    "dtmax_limited_accepted":len(limited),
    "dtmax_limited_fraction":len(limited)/len(accepted) if accepted else 0.0,
    "dtmax_limited_work_fraction":sum(x["work_index"] for x in limited)/sum(x["work_index"] for x in accepted) if accepted else 0.0,
    "shadow_a_ratio_median":statistics.median(ratios_a) if ratios_a else None,
    "shadow_a_ratio_max":max(ratios_a) if ratios_a else None,
    "shadow_b_gt_ref":b_gt,
    "shadow_b_lt_ref":b_lt,
    "shadow_b_eq_ref":b_eq,
    "executed_dt_min":min(x["dt_exec"] for x in accepted),
    "executed_dt_median":statistics.median(x["dt_exec"] for x in accepted),
    "executed_dt_max":max(x["dt_exec"] for x in accepted),
    "regime":regime
}
print("F_PE_TIMEARCH03_CASES="+json.dumps(case_reports,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH03_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH03=PASS")
