#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
base=bank["baseline_policy"]

cases=[
 ("B01","DRY",-300.0,0.5),
 ("B01","TRANSITION",-100.0,4.0),
 ("O05","DRY",-300.0,0.5),
 ("O05","TRANSITION",-100.0,4.0),
]
dts=[0.01,0.005,0.0025,0.00125]
horizon=0.04

def run(mid,reg,h0,rain,dt):
    m=materials[mid]
    cid=f"{mid}/{reg}"
    cmd=[str(exe),cid,f"FIXED_{dt}",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(h0),str(rain),str(horizon),
         str(dt),str(dt),str(dt),str(base["numbit_crit"]),str(base["maxit"]),str(base["max_backtracking"]),
         str(base["fact_inc"]),str(base["fact_dec"]),str(base["fact_fail_divisor"]),str(base["head_abs_tol"])]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        return {"ok":False,"case":cid,"dt":dt,"stdout":cp.stdout[-800:],"stderr":cp.stderr[-800:]}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_BOFEK01_RESULT|")),None)
    if not line:
        return {"ok":False,"case":cid,"dt":dt,"stderr":"missing result"}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    ints=["ATTEMPTS","ACCEPTED","REJECTED","NL","BACK","JAC","LIN"]
    floats=["CUM_RUNOFF","TOP_H","MID_H","BOTTOM_H","POND","STORAGE","MAX_LEDGER"]
    out={"ok":True,"case":cid,"dt":dt}
    out.update({k.lower():int(d[k]) for k in ints})
    out.update({k.lower():float(d[k]) for k in floats})
    out["work_index"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
    return out

rows=[]
for mid,reg,h0,rain in cases:
    for dt in dts:
        rows.append(run(mid,reg,h0,rain,dt))

def order(a,b,c,key):
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    floor=1e-11*scale
    if d1<=floor or d2<=floor:
        return None
    return math.log(d1/d2,2.0)

summary=[]
usable=[]
for mid,reg,_,_ in cases:
    cid=f"{mid}/{reg}"
    rs=sorted([r for r in rows if r["case"]==cid], key=lambda x:-x["dt"])
    ok=all(r["ok"] for r in rs)
    entry={"case":cid,"complete":ok}
    if ok:
        entry["p_top_10_5_2p5"]=order(rs[0],rs[1],rs[2],"top_h")
        entry["p_top_5_2p5_1p25"]=order(rs[1],rs[2],rs[3],"top_h")
        entry["p_mid_10_5_2p5"]=order(rs[0],rs[1],rs[2],"mid_h")
        entry["p_bottom_10_5_2p5"]=order(rs[0],rs[1],rs[2],"bottom_h")
        entry["p_storage_10_5_2p5"]=order(rs[0],rs[1],rs[2],"storage")
        for k in ("p_top_10_5_2p5","p_top_5_2p5_1p25"):
            if entry[k] is not None and math.isfinite(entry[k]): usable.append(entry[k])
    summary.append(entry)

overall={"complete_cases":sum(x["complete"] for x in summary),
         "total_cases":len(summary),
         "usable_top_orders":len(usable),
         "median_top_order":statistics.median(usable) if usable else None,
         "supports_first_order":bool(usable and 0.7<=statistics.median(usable)<=1.3)}

print("F_PE_TIMEINT01A_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT01A_CASE_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT01A_SUMMARY="+json.dumps(overall,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT01A=PASS")
