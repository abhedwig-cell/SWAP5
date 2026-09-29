#!/usr/bin/env python3
import json, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes=[
 {"id":"MOIST","h0":-50.0,"rain":8.0},
 {"id":"WET","h0":-20.0,"rain":12.0},
 {"id":"POND","h0":-5.0,"rain":25.0},
]
rows=[]
for mid in ["B01","B12","O05","O14"]:
  m=materials[mid]
  for reg in regimes:
    for mode in ["KLAG","KIMPL"]:
      cmd=[str(exe),mid,mode,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
           str(m["ksat"]),str(m["lambda"]),str(reg["h0"]),str(reg["rain"])]
      cp=subprocess.run(cmd,text=True,capture_output=True)
      line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT12A_RESULT|")),None)
      if cp.returncode or not line:
        rows.append({"material":mid,"regime":reg["id"],"mode":mode,"ok":False,
                     "stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]})
        continue
      d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
      ints=["STEPS","NL","BACK","JAC","LIN","ALT","WORK"]
      floats=["RUNOFF","POND","STORAGE","TOP_H","MID_H","BOTTOM_H","MAX_LEDGER"]
      out={"material":mid,"regime":reg["id"],"mode":mode,"ok":True,"route":d["ROUTE"]}
      out.update({k.lower():int(d[k]) for k in ints})
      out.update({k.lower():float(d[k]) for k in floats})
      rows.append(out)

by={(r["material"],r["regime"],r["mode"]):r for r in rows}
ratios=[]; per_case=[]
for mid in ["B01","B12","O05","O14"]:
  for reg in [x["id"] for x in regimes]:
    q=by[(mid,reg,"KLAG")]; c=by[(mid,reg,"KIMPL")]
    ratio=None
    if q["ok"] and c["ok"] and q["work"]>0:
      ratio=c["work"]/q["work"]; ratios.append(ratio)
    per_case.append({"material":mid,"regime":reg,"klag_ok":q["ok"],"kimpl_ok":c["ok"],"work_ratio":ratio})

kimpl=[r for r in rows if r["mode"]=="KIMPL"]
complete=sum(r["ok"] for r in kimpl)
pond_ok=all(r["ok"] for r in kimpl if r["regime"]=="POND")
ledger_ok=all((not r["ok"]) or r["max_ledger"]<=5e-8 for r in kimpl)
finite_ok=all((not r["ok"]) or all(abs(r[k])<1e300 for k in ["top_h","mid_h","bottom_h","storage","pond","runoff"]) for r in kimpl)
median_ratio=statistics.median(ratios) if ratios else None
max_ratio=max(ratios) if ratios else None
qualifies=(complete==12 and pond_ok and ledger_ok and finite_ok and median_ratio is not None and
           median_ratio<=1.25 and max_ratio<=1.50)
summary={"kimpl_complete":complete,"kimpl_total":12,"pond_ok":pond_ok,"ledger_ok":ledger_ok,
         "finite_ok":finite_ok,"median_work_ratio":median_ratio,"max_work_ratio":max_ratio,
         "qualifies":qualifies,
         "classification":"IMPLICIT_DYNAMIC_TOP_BE_QUALIFIED" if qualifies else "CLOSED_IMPLICIT_DYNAMIC_TOP_BE_NOT_QUALIFIED"}
print("F_PE_TIMEINT12A_RUNS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12A_CASES="+json.dumps(per_case,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12A=PASS")
