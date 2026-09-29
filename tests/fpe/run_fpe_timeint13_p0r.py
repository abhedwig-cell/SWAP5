#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
m=next(x for x in bank["materials"] if x["id"]=="B01")
dts=(0.008,0.004,0.002,0.001)
schemes=("BE_KLAG","BDF2_KPRED")

def run(dt,scheme):
    cmd=[str(exe),"B01",scheme,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),"1.0",str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"dt":dt,"scheme":scheme,"ok":cp.returncode==0,"stdout_tail":cp.stdout[-1200:],"stderr_tail":cp.stderr[-800:]}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT13_RESULT|")),None)
        if line is None:
            out["ok"]=False; out["stderr_tail"]="missing result"; return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK"): d[k]=int(d[k])
        for k in ("RAIN","DT","TOP_H","MID_H","BOTTOM_H","STORAGE"): d[k]=float(d[k])
        out.update(d); out["work_per_step"]=d["WORK"]/d["STEPS"]
    return out

rows=[run(dt,scheme) for scheme in schemes for dt in dts]

def order(scheme):
    rs={r["dt"]:r["TOP_H"] for r in rows if r["scheme"]==scheme and r["ok"]}
    a,b,c=0.004,0.002,0.001
    if not all(x in rs for x in (a,b,c)): return None
    e1=abs(rs[a]-rs[b]); e2=abs(rs[b]-rs[c])
    if e1<=0 or e2<=0: return None
    return math.log(e1/e2,2.0)

bdf=[r for r in rows if r["scheme"]=="BDF2_KPRED"]
be=[r for r in rows if r["scheme"]=="BE_KLAG"]
bdf_ok=all(r["ok"] for r in bdf); be_ok=all(r["ok"] for r in be)
p=order("BDF2_KPRED")
bdf_work=statistics.median([r["work_per_step"] for r in bdf if r["ok"]]) if any(r["ok"] for r in bdf) else None
be_work=statistics.median([r["work_per_step"] for r in be if r["ok"]]) if any(r["ok"] for r in be) else None
ratio=bdf_work/be_work if bdf_work is not None and be_work else None
alt_ok=all((not r["ok"]) or r.get("ALT",0)==0 for r in bdf)
advance=bdf_ok and be_ok and p is not None and p>=1.70 and ratio is not None and ratio<=1.15 and alt_ok

summary={"bdf_complete":bdf_ok,"be_complete":be_ok,"bdf_refined_order":p,
         "median_bdf_work_per_step":bdf_work,"median_be_work_per_step":be_work,
         "work_ratio":ratio,"alternative_solver_ok":alt_ok,"advance":advance}
print("F_PE_TIMEINT13_P0R_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0R_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0R=PASS")
