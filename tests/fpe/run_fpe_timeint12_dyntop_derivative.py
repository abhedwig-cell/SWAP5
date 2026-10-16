#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials=bank["materials"]
all_points=[]
ends=[]
for m in materials:
    cmd=[str(exe),m["id"],str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        print(cp.stdout)
        print(cp.stderr,file=sys.stderr)
        raise SystemExit(f"material failed: {m['id']}")
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_TIMEINT12_POINT|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            all_points.append({
                "material":d["MATERIAL"],"route":d["ROUTE"],
                "abs":float(d["ABS"]),"rel":float(d["REL"]),"fixed_id":float(d["FIXED_ID"]),
                "h":float(d["H"]),"rain":float(d["RAIN"]),"dt":float(d["DT"]),"pond0":float(d["POND0"])
            })
        elif line.startswith("F_PE_TIMEINT12_END|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            ends.append({"material":d["MATERIAL"],"head":int(d["HEAD"]),"pond":int(d["POND"]),"runoff":int(d["RUNOFF"])})

n=len(all_points)
pond=sum("linear-runoff" not in x["route"] for x in all_points)
runoff=sum("linear-runoff" in x["route"] for x in all_points)
max_abs=max((x["abs"] for x in all_points),default=float("inf"))
rels=[x["rel"] for x in all_points if x["rel"]>=0]
max_rel=max(rels,default=float("inf"))
max_fixed=max((x["fixed_id"] for x in all_points),default=float("inf"))

summary={"points":n,"pond":pond,"runoff":runoff,"max_abs":max_abs,"max_rel":max_rel,"max_fixed_identity":max_fixed,"materials":ends}
print("F_PE_TIMEINT12_DERIVATIVE_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
gates=(n>=20 and pond>=5 and runoff>=5 and max_abs<=1e-6 and max_rel<=1e-5 and max_fixed<=1e-12)
print("F_PE_TIMEINT12_DERIVATIVE_GATES="+("PASS" if gates else "FAIL"))
if not gates:
    raise SystemExit(1)
print("F_PE_TIMEINT12_DERIVATIVE=PASS")
