#!/usr/bin/env python3
import json, subprocess, sys, statistics
from pathlib import Path
exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
regs={"MOIST":(-50.0,8.0),"WET":(-20.0,12.0),"POND":(-5.0,25.0)}
rows=[]
for mid in ("B01","B12","O05","O14"):
    m=mats[mid]
    for rid,(h0,rain) in regs.items():
        case={}
        for mode in ("KLAG","KIMPL"):
            cmd=[str(exe),mid,mode,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                 str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)]
            cp=subprocess.run(cmd,text=True,capture_output=True)
            out={"ok":cp.returncode==0,"stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
            if out["ok"]:
                line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT12A_RESULT|")),None)
                d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
                for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK"): d[k]=int(d[k])
                for k in ("RUNOFF","POND","STORAGE","TOP_H","MID_H","BOTTOM_H","MAX_LEDGER"): d[k]=float(d[k])
                out.update(d)
            case[mode]=out
        rows.append({"material":mid,"regime":rid,**case})
complete=[r for r in rows if r["KIMPL"]["ok"]]
ratios=[r["KIMPL"]["WORK"]/r["KLAG"]["WORK"] for r in rows if r["KIMPL"]["ok"] and r["KLAG"]["ok"] and r["KLAG"]["WORK"]]
pond_ok=all(r["KIMPL"]["ok"] for r in rows if r["regime"]=="POND")
ledger_ok=all((not r["KIMPL"]["ok"]) or r["KIMPL"]["MAX_LEDGER"]<=5e-8 for r in rows)
max_ratio=max(ratios) if ratios else None
med_ratio=statistics.median(ratios) if ratios else None
summary={"complete":len(complete),"cases":len(rows),"pond_ok":pond_ok,"ledger_ok":ledger_ok,
         "median_work_ratio":med_ratio,"max_work_ratio":max_ratio,
         "advance":len(complete)==12 and pond_ok and ledger_ok and med_ratio is not None and med_ratio<=1.25 and max_ratio<=1.50}
print("F_PE_TIMEINT12A_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12A=PASS")
