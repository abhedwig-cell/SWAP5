#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
m=next(x for x in bank["materials"] if x["id"]=="B01")

cmd=[str(exe),"B01",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
     str(m["ksat"]),str(m["lambda"]),"4.0","0.00125","2","1","8"]
cp=subprocess.run(cmd,text=True,capture_output=True)

nodes_by_iter={}
totals={}
failure=None
for line in cp.stdout.splitlines():
    if line.startswith("F_PE_TIMEINT04A_NODE|"):
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        rec={
            "iter":int(d["ITER"]),"node":int(d["NODE"]),
            "res":float(d["RES"]),"thnp1":float(d["THNP1"]),
            "thn":float(d["THN"]),"thnm1":float(d["THNM1"]),
            "dz":float(d["DZ"]),"dt":float(d["DT"])
        }
        nodes_by_iter.setdefault(rec["iter"],[]).append(rec)
    elif line.startswith("F_PE_TIMEINT04A_TOTAL|"):
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        totals[int(d["ITER"])]=float(d["SUMRES"])
    elif line.startswith("F_PE_TIMEINT04_FAILURE|"):
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        failure={k.lower():int(v) for k,v in d.items()}

def naive_sum(vals):
    s=0.0
    for v in vals:
        s+=v
    return s

rows=[]
for it in sorted(nodes_by_iter):
    nodes=sorted(nodes_by_iter[it],key=lambda x:x["node"])
    vals=[x["res"] for x in nodes]
    floors=[]
    for x in nodes:
        floor=0.5*x["dz"]/x["dt"]*(1.5*math.ulp(x["thnp1"])+2.0*math.ulp(x["thn"])+0.5*math.ulp(x["thnm1"]))
        floors.append(floor)
    native=naive_sum(vals)
    asc=naive_sum(sorted(vals,key=abs))
    desc=naive_sum(sorted(vals,key=abs,reverse=True))
    fsum=math.fsum(vals)
    spread=max(native,asc,desc)-min(native,asc,desc)
    total=totals.get(it,native)
    storage_floor_sum=sum(floors)
    storage_floor_rss=math.sqrt(sum(x*x for x in floors))
    l1=sum(abs(v) for v in vals)
    criterion=max(storage_floor_sum,spread)
    rows.append({
        "iter":it,
        "nodes":len(nodes),
        "observed_total":total,
        "abs_total":abs(total),
        "native_sum":native,
        "ascending_abs_sum":asc,
        "descending_abs_sum":desc,
        "fsum":fsum,
        "summation_spread":spread,
        "storage_floor_sum":storage_floor_sum,
        "storage_floor_rss":storage_floor_rss,
        "storage_floor_max":max(floors),
        "configured_total_tol":1e-12,
        "baltol02_rate_floor":2.8e-16/nodes[0]["dt"],
        "component_l1":l1,
        "cancellation_ratio":l1/max(abs(total),sys.float_info.min),
        "distinguishability_limit":criterion,
        "classification":"NOT_NUMERICALLY_DISTINGUISHABLE" if abs(total)<=criterion else "DISTINGUISHABLE"
    })

summary={
    "failure":failure,
    "iterations":rows,
    "retained_iters":[x["iter"] for x in rows],
    "all_not_distinguishable":bool(rows) and all(x["classification"]=="NOT_NUMERICALLY_DISTINGUISHABLE" for x in rows),
    "max_abs_total":max([x["abs_total"] for x in rows] or [None]),
    "min_storage_floor_sum":min([x["storage_floor_sum"] for x in rows] or [None]),
    "max_storage_floor_sum":max([x["storage_floor_sum"] for x in rows] or [None])
}
print("F_PE_TIMEINT04A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))

if failure is None or failure.get("step")!=25:
    raise SystemExit("expected BDF2 step-25 failure not reproduced")
if [x["iter"] for x in rows] != [4,5,6,7,8]:
    raise SystemExit("did not retain exact iterations 4..8")
if any(x["nodes"]!=16 for x in rows):
    raise SystemExit("incomplete residual vector")
if not summary["all_not_distinguishable"]:
    raise SystemExit("one or more terminal BDF2 residuals distinguishable under frozen criterion")
print("F_PE_TIMEINT04A=PASS")
