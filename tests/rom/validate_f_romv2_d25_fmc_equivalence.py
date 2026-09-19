#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

HISTS=("RG05","RG20","RG40"); STEPS=16
DEPTH_TOL=1e-11; THETA_TOL=1e-12; Q_TOL=1e-9; LEDGER_TOL=1e-12

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse_fortran(path):
    states={}; cells={}
    complete=False
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("F_ROMV2_D25_FMC_STATE|"):
            r=fields(line.split("|",1)[1]); key=(r["HISTORY"],int(r["STEP"])); states[key]=r
        elif line.startswith("F_ROMV2_D25_FMC_CELL|"):
            r=fields(line.split("|",1)[1]); cells[(r["HISTORY"],int(r["STEP"]),int(r["CELL"]))]=float(r["THETA"])
        elif line.startswith("F_ROMV2_D25_FMC_VALIDATE_COMPLETE=PASS"):
            complete=True
    expected={(h,s) for h in HISTS for s in range(1,STEPS+1)}
    if set(states)!=expected: raise SystemExit(f"state structure mismatch {path}")
    if set(cells)!={(h,s,c) for h in HISTS for s in range(1,STEPS+1) for c in range(1,17)}:
        raise SystemExit(f"cell structure mismatch {path}")
    if not complete: raise SystemExit(f"missing completion {path}")
    return states,cells

def close(a,b,tol):
    return math.isfinite(a) and math.isfinite(b) and abs(a-b)<=tol

def compare_one(label,states,cells,oracle):
    mapping={
      "RAIN_CM":("rain_cm",DEPTH_TOL),
      "INFIL_CM":("infiltration_cm",DEPTH_TOL),
      "CUM_INFIL_CM":("cumulative_infiltration_cm",DEPTH_TOL),
      "SURFACE_STORE_CM":("surface_store_cm",DEPTH_TOL),
      "RUNOFF_CM":("runoff_cm",DEPTH_TOL),
      "CUM_RUNOFF_CM":("cumulative_runoff_cm",DEPTH_TOL),
      "BOTTOM_EXCHANGE_CM":("bottom_exchange_cm",DEPTH_TOL),
      "CUM_BOTTOM_CM":("cumulative_bottom_exchange_cm",DEPTH_TOL),
      "BOTTOM_FLUX_CM_PER_DAY":("bottom_flux_cm_per_day",Q_TOL),
      "SOIL_STORAGE_CM":("soil_storage_cm",DEPTH_TOL),
      "MIN_GAP_CM":("minimum_separation_cm",DEPTH_TOL),
    }
    maxdiff={k:0.0 for k in mapping}; max_theta=0.0
    runoff_presence_mismatch=0; failures=[]
    for h in HISTS:
        rows=oracle["histories"][h]["rows"]
        if len(rows)!=STEPS: raise SystemExit("oracle row count")
        for step,row in enumerate(rows,1):
            r=states[(h,step)]
            for fk,(okey,tol) in mapping.items():
                a=float(r[fk]); b=float(row[okey]); d=abs(a-b); maxdiff[fk]=max(maxdiff[fk],d)
                if not close(a,b,tol): failures.append(f"{h}:{step}:{fk}:{a}:{b}:{d}")
            if (float(r["RUNOFF_CM"])>0)!=(float(row["runoff_cm"])>0): runoff_presence_mismatch+=1
            for led in ("SURFACE_LEDGER_CM","SOIL_LEDGER_CM","GLOBAL_LEDGER_CM"):
                if abs(float(r[led]))>LEDGER_TOL: failures.append(f"{h}:{step}:{led}:gate")
            for c in range(1,17):
                a=cells[(h,step,c)];b=float(row["theta16"][c-1]);d=abs(a-b);max_theta=max(max_theta,d)
                if not close(a,b,THETA_TOL): failures.append(f"{h}:{step}:theta{c}:{a}:{b}:{d}")
    passed=not failures and runoff_presence_mismatch==0
    return {"label":label,"pass":passed,"max_abs_differences":maxdiff,"max_abs_theta_difference":max_theta,
            "runoff_presence_mismatch_count":runoff_presence_mismatch,"first_failures":failures[:20]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--oracle",required=True);ap.add_argument("--o0",required=True);ap.add_argument("--o2",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    oracle=json.loads(pathlib.Path(a.oracle).read_text())
    if oracle["decision"]!="D25_FROZEN_D24_PYTHON_ORACLE_PASS": raise SystemExit("oracle decision drift")
    s0,c0=parse_fortran(a.o0);s2,c2=parse_fortran(a.o2)
    r0=compare_one("O0",s0,c0,oracle);r2=compare_one("O2",s2,c2,oracle)
    cross_state_max=0.;cross_theta_max=0.
    for k in s0:
        for fld in ("RAIN_CM","INFIL_CM","CUM_INFIL_CM","SURFACE_STORE_CM","RUNOFF_CM","CUM_RUNOFF_CM","BOTTOM_EXCHANGE_CM","CUM_BOTTOM_CM","BOTTOM_FLUX_CM_PER_DAY","SOIL_STORAGE_CM","MIN_GAP_CM"):
            cross_state_max=max(cross_state_max,abs(float(s0[k][fld])-float(s2[k][fld])))
    for k in c0: cross_theta_max=max(cross_theta_max,abs(c0[k]-c2[k]))
    passed=r0["pass"] and r2["pass"]
    out={"schema":"swap5.f-romv2-d25.fmc-implementation-equivalence.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D25",
         "decision":"D25_COMPILED_FMC_IMPLEMENTATION_EQUIVALENCE_PASS" if passed else "D25_COMPILED_FMC_IMPLEMENTATION_EQUIVALENCE_NO_GO",
         "tolerances":{"water_depth_cm":DEPTH_TOL,"theta":THETA_TOL,"bottom_flux_cm_per_day":Q_TOL,"ledger_cm":LEDGER_TOL},
         "O0":r0,"O2":r2,"O0_O2":{"max_state_difference":cross_state_max,"max_theta_difference":cross_theta_max},
         "timing_authorized":passed,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
