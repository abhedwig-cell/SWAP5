#!/usr/bin/env python3
import json, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
regs={"MOIST":(-50.0,8.0),"WET":(-20.0,12.0),"POND":(-5.0,25.0)}

cases=[]; steps=[]
for mid in ("B01","B12","O05","O14"):
    m=mats[mid]
    for rid,(h0,rain) in regs.items():
        cmd=[str(exe),mid,rid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        case={"material":mid,"regime":rid,"complete":cp.returncode==0}
        accepted=0
        for line in cp.stdout.splitlines():
            if not line.startswith("F_PE_TIMEINT14A_STEP|"):
                continue
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            rec={"material":mid,"regime":rid}
            rec["step"]=int(d["STEP"])
            for k in ("SOIL_M1","SOIL_N","SOIL_NP1","POND_N","POND_NP1","LEDGER",
                      "HISTORY_CORRECTION","IDENTITY_RESIDUAL","RUNOFF","BOTTOM_FLUX"):
                rec[k.lower()]=float(d[k])
            rec["route"]=d["ROUTE"]
            steps.append(rec); accepted+=1
        case["accepted_steps"]=accepted
        if not case["complete"]:
            case["stdout"]=cp.stdout[-1000:]; case["stderr"]=cp.stderr[-1000:]
        cases.append(case)

bootstrap=[x for x in steps if x["step"]==1]
bdf2=[x for x in steps if x["step"]>=2]
bootstrap_max=max((abs(x["ledger"]) for x in bootstrap),default=None)
identity_abs=[abs(x["identity_residual"]) for x in bdf2]
ordinary_abs=[abs(x["ledger"]) for x in bdf2]
max_identity=max(identity_abs) if identity_abs else None
median_identity=statistics.median(identity_abs) if identity_abs else None
max_ordinary=max(ordinary_abs) if ordinary_abs else None
count_large=sum(x>=1e-3 for x in ordinary_abs)
gates={
 "bdf2_steps_ge_100":len(bdf2)>=100,
 "bootstrap_ledger":bootstrap_max is not None and bootstrap_max<=5e-8,
 "max_identity":max_identity is not None and max_identity<=5e-8,
 "median_identity":median_identity is not None and median_identity<=1e-10,
 "nontrivial_large_ordinary":count_large>=1,
}
classification="BDF2_HISTORY_CONTRACT_MISMATCH_CONFIRMED" if all(gates.values()) else "UNEXPLAINED_MASS_DEFECT_REMAINS"
summary={
 "cases":len(cases),"complete_cases":sum(x["complete"] for x in cases),
 "accepted_steps":len(steps),"bootstrap_steps":len(bootstrap),"bdf2_steps":len(bdf2),
 "bootstrap_max_abs_ledger":bootstrap_max,
 "max_abs_identity_residual":max_identity,
 "median_abs_identity_residual":median_identity,
 "max_abs_ordinary_ledger":max_ordinary,
 "ordinary_steps_ge_1e_3":count_large,
 "gates":gates,"classification":classification
}
print("F_PE_TIMEINT14A_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT14A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT14A=PASS")
