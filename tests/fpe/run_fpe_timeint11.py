#!/usr/bin/env python3
import json, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
cases=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005]

rows=[]
for mid,rain in cases:
    m=materials[mid]
    for dt in dts:
        cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT11_RESULT|")),None)
        if cp.returncode or not line:
            rows.append({"material":mid,"rain":rain,"dt":dt,"ok":False,
                         "stdout":cp.stdout[-800:],"stderr":cp.stderr[-800:]})
            continue
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        bw=int(d["BDF_WORK"]); cw=int(d["CMP_WORK"])
        rows.append({"material":mid,"rain":rain,"dt":dt,"ok":True,
                     "bdf_work":bw,"composite_work":cw,"work_ratio":cw/bw,
                     "bdf_top_h":float(d["BDF_TOP_H"]),"composite_top_h":float(d["CMP_TOP_H"])})

okrows=[x for x in rows if x["ok"]]
ratios=[x["work_ratio"] for x in okrows]
summary={"runs":len(rows),"complete":len(okrows),
         "median_work_ratio":statistics.median(ratios) if ratios else None,
         "min_work_ratio":min(ratios) if ratios else None,
         "max_work_ratio":max(ratios) if ratios else None}
med=summary["median_work_ratio"]
if len(okrows)!=len(rows):
    decision="CLOSED_TRBDF2_DEFAULT_COST_TOO_HIGH"
elif med<=1.40:
    decision="TRBDF2_GENERAL_CANDIDATE_ADVANCES"
elif med<=1.70:
    decision="TRBDF2_NEEDS_ACCURACY_JUSTIFICATION"
else:
    decision="CLOSED_TRBDF2_DEFAULT_COST_TOO_HIGH"
summary["decision"]=decision
print("F_PE_TIMEINT11_RUNS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT11_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT11=PASS")
