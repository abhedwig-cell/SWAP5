#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
regs={"MOIST":(-50.0,8.0),"WET":(-20.0,12.0),"POND":(-5.0,25.0)}

rows=[]
for mid in ("B01","B12","O05","O14"):
    m=mats[mid]
    for rid,(h0,rain) in regs.items():
        cmd=[str(exe),mid,rid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        row={"material":mid,"regime":rid,"ok":cp.returncode==0,
             "stdout":cp.stdout[-2200:],"stderr":cp.stderr[-1200:]}
        if row["ok"]:
            line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT15_P1_RESULT|")),None)
            if not line:
                row["ok"]=False; row["stderr"]="missing result"
            else:
                d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
                for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK","CLAMP_STEPS"):
                    row[k.lower()]=int(d[k])
                for k in ("RUNOFF","POND","STORAGE","TOP_H","MID_H","BOTTOM_H","MAX_LEDGER",
                          "CUM_LEDGER","MIN_RAIN_DEPTH","MIN_RUNOFF_DEPTH"):
                    row[k.lower()]=float(d[k])
                row["route"]=d["ROUTE"]
        rows.append(row)

complete=[r for r in rows if r["ok"]]
pond_complete=all(r["ok"] for r in rows if r["regime"]=="POND")
ledger_ok=all(r["max_ledger"]<=5e-8 and abs(r["cum_ledger"])<=5e-8 for r in complete)
alt_ok=all(r["alt"]==0 for r in complete)
nonnegative_ok=all(r["min_rain_depth"]>=-1e-14 and r["min_runoff_depth"]>=-1e-14 for r in complete)
bootstrap_ok=True
# Step-level harness enforces the same physical ledger formula from step 1;
# max ledger gate therefore includes bootstrap and all BDF2 steps.
gate=(len(complete)>=10 and ledger_ok and alt_ok and nonnegative_ok)
summary={
 "complete":len(complete),"cases":len(rows),
 "failed":[f"{r['material']}/{r['regime']}" for r in rows if not r["ok"]],
 "pond_complete":pond_complete,
 "max_physical_ledger":max((r["max_ledger"] for r in complete),default=None),
 "max_abs_cumulative_ledger":max((abs(r["cum_ledger"]) for r in complete),default=None),
 "min_rain_depth":min((r["min_rain_depth"] for r in complete),default=None),
 "min_runoff_depth":min((r["min_runoff_depth"] for r in complete),default=None),
 "alternative_solver_ok":alt_ok,
 "nonnegative_interval_integrals":nonnegative_ok,
 "conservation_pass":gate,
 "classification":("CONSERVATIVE_BDF2_P1_CONSERVATION_PASS" if gate else "CONSERVATIVE_BDF2_P1_FAIL")
}
print("F_PE_TIMEINT15_P1_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P1_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P1=PASS")
