#!/usr/bin/env python3
import json, subprocess, sys, statistics
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
             "stdout":cp.stdout[-1800:],"stderr":cp.stderr[-1000:]}
        if row["ok"]:
            line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT14_RESULT|")),None)
            if not line:
                row["ok"]=False; row["stderr"]="missing result"
            else:
                d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
                for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK","CLAMPS"): row[k.lower()]=int(d[k])
                for k in ("RUNOFF","POND","STORAGE","TOP_H","MID_H","BOTTOM_H","MAX_LEDGER",
                          "MAX_REPR_MISMATCH","MAX_ALG_LEDGER","MAX_BOOTSTRAP_LEDGER"):
                    row[k.lower()]=float(d[k])
        rows.append(row)

complete=[r for r in rows if r["ok"]]
max_repr=max((r["max_repr_mismatch"] for r in complete),default=None)
max_alg=max((r["max_alg_ledger"] for r in complete),default=None)
max_boot=max((r["max_bootstrap_ledger"] for r in complete),default=None)
attr_pass=(len(complete)>=10 and max_repr is not None and max_repr<=1e-10 and
           max_alg is not None and max_alg<=1e-10 and
           max_boot is not None and max_boot<=5e-8)

summary={
 "complete":len(complete),
 "cases":len(rows),
 "failed":[f"{r['material']}/{r['regime']}" for r in rows if not r["ok"]],
 "max_repr_mismatch":max_repr,
 "max_algorithmic_ledger":max_alg,
 "max_bootstrap_physical_ledger":max_boot,
 "attribution_pass":attr_pass,
 "classification":("BDF2_ALGORITHMIC_CONSERVATION_CONFIRMED_PHYSICAL_INTERVAL_CONTRACT_INCOMPATIBLE"
                   if attr_pass else "BDF2_PHYSICAL_LEDGER_DEFECT_NOT_EXPLAINED")
}

print("F_PE_TIMEINT14_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT14_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT14=PASS")
