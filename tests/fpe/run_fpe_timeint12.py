#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
mids=["B01","B12","O05","O14"]

runs=[]; points=[]
for mid in mids:
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    pts=[]
    end=None
    for line in cp.stdout.splitlines():
        if line.startswith("F_PE_TIMEINT12_POINT|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            p={"material":d["MATERIAL"],"h":float(d["H"]),"rain":float(d["RAIN"]),"dt":float(d["DT"]),
               "pond0":float(d["POND0"]),"route":d["ROUTE"],"ana":float(d["ANA"]),"fd":float(d["FD"]),
               "abs":float(d["ABS"]),"rel":float(d["REL"]),"fixed_id":float(d["FIXED_ID"])}
            pts.append(p); points.append(p)
        elif line.startswith("F_PE_TIMEINT12_END|"):
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            end={"head":int(d["HEAD"]),"pond":int(d["POND"]),"runoff":int(d["RUNOFF"])}
    ok=cp.returncode==0 and "F_PE_TIMEINT12=PASS" in cp.stdout and end is not None
    runs.append({"material":mid,"ok":ok,"points":len(pts),"end":end,
                 "stdout_tail":cp.stdout[-1200:] if not ok else "",
                 "stderr_tail":cp.stderr[-1200:] if not ok else ""})

finite=all(math.isfinite(p["ana"]) and math.isfinite(p["fd"]) for p in points)
max_abs=max((p["abs"] for p in points),default=None)
relvals=[p["rel"] for p in points if abs(p["fd"])>=1e-6]
max_rel=max(relvals,default=0.0)
max_fixed=max((p["fixed_id"] for p in points),default=None)
npond=sum(p["route"]=="ponded-head" for p in points)
nrun=sum(p["route"]=="ponded-head-linear-runoff" for p in points)
qualifies=(all(r["ok"] for r in runs) and len(points)>=20 and npond>=5 and nrun>=5 and finite and
           max_abs is not None and max_abs<=1e-6 and max_rel<=1e-5 and
           max_fixed is not None and max_fixed<=1e-12)

summary={"runs_ok":all(r["ok"] for r in runs),"points":len(points),"ponded_head":npond,
         "linear_runoff":nrun,"finite":finite,"max_abs_mismatch":max_abs,
         "max_relative_mismatch":max_rel,"max_fixed_k_identity":max_fixed,
         "qualifies":qualifies}
print("F_PE_TIMEINT12_RUNS="+json.dumps(runs,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT12_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not all(r["ok"] for r in runs):
    raise SystemExit("one or more derivative material runs failed")
print("F_PE_TIMEINT12=PASS")
