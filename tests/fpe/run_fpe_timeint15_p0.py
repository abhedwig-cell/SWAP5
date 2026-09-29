#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
rows=[]
for mid in ("B01","B12","O05","O14"):
    m=mats[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    row={"material":mid,"ok":cp.returncode==0,"stdout":cp.stdout[-1500:],"stderr":cp.stderr[-1000:]}
    if row["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT15_P0_RESULT|")),None)
        if not line:
            row["ok"]=False; row["stderr"]="missing result"
        else:
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("POINTS","STATUS_MISMATCH","REGIME_MISMATCH","DERIV_AVAIL_MISMATCH",
                      "FLUX_COUNT","HEAD_NO_RUNOFF_COUNT","RUNOFF_COUNT"):
                row[k.lower()]=int(d[k])
            for k in ("MAX_HEAD","MAX_FLUX","MAX_POND","MAX_RUNOFF","MAX_DERIV"):
                row[k.lower()]=float(d[k])
    rows.append(row)

gate=all(r["ok"] and r["status_mismatch"]==0 and r["regime_mismatch"]==0 and
         r["deriv_avail_mismatch"]==0 and r["max_head"]<=1e-12 and r["max_flux"]<=1e-12 and
         r["max_pond"]<=1e-12 and r["max_runoff"]<=1e-12 and r["max_deriv"]<=1e-12 and
         r["flux_count"]>0 and r["head_no_runoff_count"]>0 and r["runoff_count"]>0 for r in rows)
summary={"pass":gate,"materials":len(rows),"points":sum(r.get("points",0) for r in rows),
         "flux_points":sum(r.get("flux_count",0) for r in rows),
         "head_no_runoff_points":sum(r.get("head_no_runoff_count",0) for r in rows),
         "runoff_points":sum(r.get("runoff_count",0) for r in rows)}
print("F_PE_TIMEINT15_P0_ROWS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT15_P0_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not gate: raise SystemExit("TIMEINT15 P0 equivalence gate failed")
print("F_PE_TIMEINT15_P0=PASS")
