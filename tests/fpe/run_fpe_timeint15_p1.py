#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
materials=["B01","O05"]
dts=[0.01,0.005,0.0025,0.00125]

def run(mid,dt):
    m=mats[mid]
    cp=subprocess.run([str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                       str(m["ksat"]),str(m["lambda"]),str(dt)],text=True,capture_output=True)
    row={"material":mid,"dt":dt,"ok":cp.returncode==0}
    if not row["ok"]:
        row["stdout"]=cp.stdout[-1200:]; row["stderr"]=cp.stderr[-1200:]; return row
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT15_P1_RESULT|")),None)
    if not line:
        row["ok"]=False; row["stderr"]="missing result"; return row
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    for k in ("TOP_H","STORAGE_START","STORAGE_END","CUM_TRAP_INPUT","EXACT_INPUT","QUAD_ERROR",
              "MAX_LEDGER","CUM_LEDGER","DIRECT_LEDGER"):
        row[k.lower()]=float(d[k])
    for k in ("NL","BACK","JAC","LIN","ALT","WORK","CLAMPS"):
        row[k.lower()]=int(d[k])
    return row

def order(a,b,c):
    if not all(x["ok"] for x in (a,b,c)): return None
    e1=a["quad_error"]; e2=b["quad_error"]
    e3=c["quad_error"]
    if min(e1,e2,e3)<=0: return None
    # Refined order from 0.005 -> 0.0025 -> 0.00125, based on error ratios.
    return math.log(e2/e3,2.0)

rows=[run(m,dt) for m in materials for dt in dts]
per=[]; orders=[]
for m in materials:
    rs=sorted([x for x in rows if x["material"]==m],key=lambda x:-x["dt"])
    p=order(rs[1],rs[2],rs[3])
    if p is not None and math.isfinite(p): orders.append(p)
    per.append({
      "material":m,
      "complete":all(x["ok"] for x in rs),
      "refined_quadrature_order":p,
      "max_step_ledger":max((abs(x["max_ledger"]) for x in rs if x["ok"]),default=None),
      "max_cumulative_ledger":max((abs(x["cum_ledger"]) for x in rs if x["ok"]),default=None),
      "max_direct_ledger":max((abs(x["direct_ledger"]) for x in rs if x["ok"]),default=None),
      "clamps":sum(x.get("clamps",0) for x in rs if x["ok"]),
      "alts":sum(x.get("alt",0) for x in rs if x["ok"])
    })

median_order=statistics.median(orders) if orders else None
summary={
  "complete_cases":sum(x["complete"] for x in per),
  "cases":per,
  "median_refined_quadrature_order":median_order,
  "all_orders_ge_1p8":all(x["refined_quadrature_order"] is not None and x["refined_quadrature_order"]>=1.8 for x in per),
  "all_ledgers_ok":all(x["max_step_ledger"] is not None and x["max_step_ledger"]<=5e-8 and
                       x["max_cumulative_ledger"] is not None and x["max_cumulative_ledger"]<=5e-8 and
                       x["max_direct_ledger"] is not None and x["max_direct_ledger"]<=5e-8 for x in per),
  "total_clamps":sum(x["clamps"] for x in per),
  "total_alt":sum(x["alts"] for x in per)
}
summary["p1_pass"]=bool(summary["complete_cases"]==2 and summary["all_orders_ge_1p8"] and
                        median_order is not None and median_order>=1.9 and summary["all_ledgers_ok"] and
                        summary["total_clamps"]==0 and summary["total_alt"]==0)
print("F_PE_TIMEINT15_P1_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P1=PASS")
