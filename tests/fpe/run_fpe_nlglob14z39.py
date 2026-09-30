#!/usr/bin/env python3
import json,subprocess,sys
from pathlib import Path
exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
ids=["B01","B12","O05","O14"]
rows=[]
for mid in ids:
    m=materials[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        print(cp.stdout); print(cp.stderr,file=sys.stderr); raise SystemExit(cp.returncode)
    line=next(x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z39_CASE|"))
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    row={"material":mid,"median_s":float(d["MEDIAN_S"]),"mean_s":float(d["MEAN_S"]),
         "overhead_frac_n13":float(d["OVERHEAD_FRAC_N13"]),"overhead_frac_n12":float(d["OVERHEAD_FRAC_N12"]),
         "nl":int(d["NL"]),"jac":int(d["JAC"]),"lin":int(d["LIN"]),"back":int(d["BACK"])}
    rows.append(row)
ok=all(r["overhead_frac_n13"]<0.05 and r["overhead_frac_n12"]<0.05 for r in rows)
agg="QUALIFIED_Z39_MANAGER_OVERHEAD_AMORTIZED" if ok else "Z39_MANAGER_OVERHEAD_MATERIAL"
print("F_PE_NLGLOB14Z39_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z39_RESULT="+json.dumps({"aggregate":agg},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z39=PASS")
