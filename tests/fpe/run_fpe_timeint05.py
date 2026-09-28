#!/usr/bin/env python3
import json, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1])
bank=json.loads(Path(sys.argv[2]).read_text())
materials={x["id"]:x for x in bank["materials"]}
regimes=[
 {"id":"DRY_S","h0_cm":-250.0,"rain_cm_day":0.8},
 {"id":"TRANS_S","h0_cm":-100.0,"rain_cm_day":2.0},
 {"id":"MOIST_S","h0_cm":-50.0,"rain_cm_day":3.0},
]
dts=[0.005,0.010,0.020]

def run(mid,reg,dt):
    m=materials[mid]
    cid=f"{mid}/{reg['id']}"
    cmd=[str(exe),cid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(reg["h0_cm"]),str(reg["rain_cm_day"]),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT05|")),None)
    if line is None:
        return {"case":cid,"dt":dt,"domain":False,"ok":False,"stage":"NO_RECORD",
                "stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]}
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    domain=d.get("DOMAIN")=="1"
    ok=d.get("OK")=="1"
    out={"case":cid,"material":mid,"regime":reg["id"],"dt":dt,"domain":domain,"ok":ok,
         "stage":d.get("STAGE")}
    if ok:
        for k in ("BE_H_ERR","BDF_H_ERR","BE_THETA_ERR","BDF_THETA_ERR","BE_WATER_L1","BDF_WATER_L1",
                  "BE_STORAGE_ERR","BDF_STORAGE_ERR","BDF_MASS_RESID","MAX_BE_LEDGER","MAX_REF_LEDGER"):
            out[k.lower()]=float(d[k])
        for k in ("WORK_BE","WORK_BDF","WORK_REF","WORK_HISTORY"):
            out[k.lower()]=int(d[k])
    return out

rows=[run(m["id"],reg,dt) for m in bank["materials"] for reg in regimes for dt in dts]
complete=[r for r in rows if r["domain"] and r["ok"]]
candidate_fail=[r for r in rows if r["domain"] and not r["ok"]]

def median(vals):
    return statistics.median(vals) if vals else None

be_theta=median([r["be_theta_err"] for r in complete])
bdf_theta=median([r["bdf_theta_err"] for r in complete])
be_water=median([r["be_water_l1"] for r in complete])
bdf_water=median([r["bdf_water_l1"] for r in complete])
work_ratio=median([r["work_bdf"]/r["work_be"] for r in complete if r["work_be"]>0])

theta_ratio=(bdf_theta/be_theta) if be_theta and be_theta>0 else None
water_ratio=(bdf_water/be_water) if be_water and be_water>0 else None

outlier_theta=[r for r in complete if r["be_theta_err"]>0 and r["bdf_theta_err"]>2*r["be_theta_err"]]
outlier_water=[r for r in complete if r["be_water_l1"]>0 and r["bdf_water_l1"]>2*r["be_water_l1"]]
mass_ok=all(abs(r["bdf_mass_resid"])<=5e-8 and r["max_be_ledger"]<=5e-8 and r["max_ref_ledger"]<=5e-8 for r in complete)

summary={
 "planned":len(rows),
 "complete_smooth":len(complete),
 "outside_domain":sum(not r["domain"] for r in rows),
 "bdf_candidate_failures":len(candidate_fail),
 "median_be_theta_error":be_theta,
 "median_bdf_theta_error":bdf_theta,
 "theta_error_ratio":theta_ratio,
 "median_be_water_l1":be_water,
 "median_bdf_water_l1":bdf_water,
 "water_l1_ratio":water_ratio,
 "median_bdf_to_be_work_ratio":work_ratio,
 "theta_outliers_gt2x":len(outlier_theta),
 "water_outliers_gt2x":len(outlier_water),
 "mass_ok":mass_ok,
}
summary["advance"]=bool(
 len(complete)>=24 and len(candidate_fail)==0 and mass_ok and
 theta_ratio is not None and theta_ratio<=0.60 and
 water_ratio is not None and water_ratio<=0.60 and
 work_ratio is not None and work_ratio<=1.25 and
 len(outlier_theta)==0 and len(outlier_water)==0
)

print("F_PE_TIMEINT05_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05_THETA_OUTLIERS="+json.dumps(outlier_theta,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05_WATER_OUTLIERS="+json.dumps(outlier_water,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT05=PASS")
