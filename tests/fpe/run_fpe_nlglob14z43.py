#!/usr/bin/env python3
import json,math,subprocess,sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
rows=[]
physical_fail=False
operational_fail=False

for mid in ("O05","O14","B12"):
    m=mats[mid]
    cmd=[str(exe),str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    print(cp.stdout,end="")
    if cp.returncode:
        print(cp.stderr,file=sys.stderr)
        print('F_PE_NLGLOB14Z43_RESULT={"aggregate":"Z43_HOLDOUT_PHYSICAL_FAILURE","reason":"execution"}')
        print("F_PE_NLGLOB14Z43=PASS")
        raise SystemExit
    if "F_PE_NLGLOB14Z42_PHYSICAL_FAIL" in cp.stdout:
        physical_fail=True
        break
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z42_METRICS|")),None)
    if not line:
        physical_fail=True
        break
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    red=int(d["REDUCED_COUNT"]); fb=int(d["FALLBACK_COUNT"]); bp=int(d["BYPASS_COUNT"])
    total=red+fb+bp
    row={
      "material":mid,
      "wall_ratio":float(d["WALL_RATIO"]),
      "work_ratio":float(d["WORK_RATIO"]),
      "reduced_fraction":red/total if total else 0.0,
      "fallback_count":fb,"bypass_count":bp,
      "mean_active":float(d["MEAN_ACTIVE"]),
      "full_final_tail":int(d["FULL_FINAL_TAIL"]),
      "adaptive_final_tail":int(d["ADAPTIVE_FINAL_TAIL"]),
      "full_events":int(d["FULL_EVENTS"]),
      "adaptive_events":int(d["ADAPTIVE_EVENTS"]),
      "max_hdiff":float(d["MAX_HDIFF"]),
      "max_tdiff":float(d["MAX_TDIFF"]),
      "max_full_ledger":float(d["MAX_FULL_LEDGER"]),
      "max_adaptive_ledger":float(d["MAX_ADAPTIVE_LEDGER"]),
      "origin_leak":float(d["ORIGIN_LEAK"]),
      "request_reallocs":int(d["REQUEST_REALLOCS"]),
      "candidate_reallocs":int(d["CANDIDATE_REALLOCS"]),
      "last_nonreduced_reason":d["LAST_NONREDUCED_REASON"],
    }
    row["physical_pass"]=(row["max_hdiff"]<=5e-3 and row["max_tdiff"]<=5e-6 and
                          row["max_adaptive_ledger"]<=5e-8 and row["origin_leak"]<=1e-15 and
                          abs(row["full_final_tail"]-row["adaptive_final_tail"])<=1)
    row["operational_pass"]=(row["reduced_fraction"]>=0.95 and
                             (fb+bp)<=0.05*total and
                             row["request_reallocs"]<=2 and row["candidate_reallocs"]<=2)
    rows.append(row)
    if not row["physical_pass"]: physical_fail=True
    if not row["operational_pass"]: operational_fail=True

if physical_fail:
    agg="Z43_HOLDOUT_PHYSICAL_FAILURE"
elif operational_fail:
    agg="Z43_OPERATIONAL_FALLBACK_FAILURE"
else:
    walls=[r["wall_ratio"] for r in rows]
    works=[r["work_ratio"] for r in rows]
    wall_gm=math.exp(sum(math.log(x) for x in walls)/len(walls))
    work_gm=math.exp(sum(math.log(x) for x in works)/len(works))
    if max(walls)>1.05 or wall_gm>=1.0 or work_gm>=0.90:
        agg="Z43_PERFORMANCE_NOT_PORTABLE"
    else:
        agg="QUALIFIED_Z43_PRODUCTION_ADMISSION_CANDIDATE_READY"

out={"aggregate":agg,"rows":rows}
if rows:
    out["geomean_wall_ratio"]=math.exp(sum(math.log(r["wall_ratio"]) for r in rows)/len(rows))
    out["geomean_work_ratio"]=math.exp(sum(math.log(r["work_ratio"]) for r in rows)/len(rows))
print("F_PE_NLGLOB14Z43_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z43=PASS")
