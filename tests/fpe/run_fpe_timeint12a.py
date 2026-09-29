#!/usr/bin/env python3
import json, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes={
 "MOIST":{"h0_cm":-50.0,"rain_cm_day":8.0},
 "WET":{"h0_cm":-20.0,"rain_cm_day":12.0},
 "POND":{"h0_cm":-5.0,"rain_cm_day":25.0},
}
rows=[]
for mid in ["B01","B12","O05","O14"]:
    m=materials[mid]
    for rid,r in regimes.items():
        for kimpl in [0,1]:
            cmd=[str(exe),mid,rid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                 str(m["ksat"]),str(m["lambda"]),str(r["h0_cm"]),str(r["rain_cm_day"]),str(kimpl)]
            cp=subprocess.run(cmd,text=True,capture_output=True)
            rec={"material":mid,"regime":rid,"kimpl":kimpl,"ok":False}
            if cp.returncode==0:
                line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT12A_RESULT|")),None)
                if line:
                    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
                    ints=["STEPS","NL","BACK","JAC","LIN","FINAL_REGIME"]
                    floats=["RUNOFF","POND","TOP_H","MID_H","BOTTOM_H","STORAGE","MAX_LEDGER"]
                    rec.update({k.lower():int(d[k]) for k in ints})
                    rec.update({k.lower():float(d[k]) for k in floats})
                    rec["final_route"]=d["FINAL_ROUTE"]
                    rec["work_index"]=rec["nl"]+rec["back"]+rec["jac"]+rec["lin"]
                    rec["ok"]=True
            if not rec["ok"]:
                rec["stdout"]=cp.stdout[-1200:]
                rec["stderr"]=cp.stderr[-1200:]
            rows.append(rec)

ratios=[]
individual=[]
pond_ok=True
for mid in ["B01","B12","O05","O14"]:
    for rid in regimes:
        a=next(x for x in rows if x["material"]==mid and x["regime"]==rid and x["kimpl"]==0)
        b=next(x for x in rows if x["material"]==mid and x["regime"]==rid and x["kimpl"]==1)
        if a["ok"] and b["ok"] and a["work_index"]>0:
            ratio=b["work_index"]/a["work_index"]
            ratios.append(ratio); individual.append({"case":f"{mid}/{rid}","ratio":ratio})
        if rid=="POND" and not b["ok"]: pond_ok=False

kim=[x for x in rows if x["kimpl"]==1]
summary={
 "cases":12,
 "kimpl_complete":sum(x["ok"] for x in kim),
 "pond_complete":pond_ok,
 "max_ledger":max((x.get("max_ledger",0.0) for x in kim if x["ok"]),default=None),
 "median_work_ratio":statistics.median(ratios) if ratios else None,
 "max_work_ratio":max(ratios) if ratios else None,
 "ratios":individual,
}
summary["qualifies"]=(summary["kimpl_complete"]==12 and pond_ok and summary["max_ledger"] is not None and
                      summary["max_ledger"]<=5e-8 and summary["median_work_ratio"]<=1.25 and summary["max_work_ratio"]<=1.50)
print("F_PE_TIMEINT12A_ROWS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not summary["qualifies"]:
    raise SystemExit(1)
print("F_PE_TIMEINT12A=PASS")
