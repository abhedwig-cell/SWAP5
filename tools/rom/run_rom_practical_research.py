#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, math, pathlib, subprocess, tempfile

PARAM_KEYS=(("tr","theta_r"),("ts","theta_s"),("alpha","alpha_per_cm"),("nvg","n"),("ks","Ksat_cm_per_day"),("lambda","lambda"))
BOUNDS={"SURF_P":[0.,20.,40.,80.,160.],"GW_LB":[0.,80.,100.,120.,130.,140.,150.,155.,160.]}
MEMBER={"SURF_P":"S4","GW_LB":"G8"}
PROFILES={"SURF_P":"P3_SD","GW_LB":"P3_GD"}
HISTORIES={"SURF_P":("SD01","SD02"),"GW_LB":("GD01","GD02")}

def sha(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def fields(line:str)->dict[str,str]:
    return dict(x.split("=",1) for x in line.strip().split("|") if "=" in x)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True)
    ap.add_argument("--materials",required=True,type=pathlib.Path)
    ap.add_argument("--exe",required=True,type=pathlib.Path)
    ap.add_argument("--forcing-profile",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--raw-output",type=pathlib.Path)
    ap.add_argument("--namelist-out",type=pathlib.Path)
    a=ap.parse_args()
    if a.forcing_profile!=PROFILES[a.purpose]:
        raise SystemExit(f"unsupported forcing profile {a.forcing_profile} for {a.purpose}")
    mats=json.loads(a.materials.read_text())["materials"]
    if a.material not in mats: raise SystemExit("unknown material")
    mat=mats[a.material]
    nml="&material_parameters\n"+",\n".join(f"{dst}={float(mat[src]):.17g}" for dst,src in PARAM_KEYS)+"\n/\n"
    if a.namelist_out:
        a.namelist_out.parent.mkdir(parents=True,exist_ok=True); a.namelist_out.write_text(nml)
        nml_path=a.namelist_out
        temp=None
    else:
        temp=tempfile.TemporaryDirectory(); nml_path=pathlib.Path(temp.name)/"material.nml"; nml_path.write_text(nml)
    p=subprocess.run([str(a.exe),a.purpose,a.material,str(nml_path),"0.005"],capture_output=True,text=True)
    raw=p.stdout+p.stderr
    if a.raw_output:
        a.raw_output.parent.mkdir(parents=True,exist_ok=True); a.raw_output.write_text(raw)
    if p.returncode!=0:
        raise SystemExit(f"core failed exit={p.returncode}: {raw[-1000:]}")
    state={}; layers={}; passes={}; timing=None
    for line in raw.splitlines():
        if line.startswith("P4_STATE|"):
            r=fields(line); state[(r["HISTORY"],int(r["DAY"]))]=r
        elif line.startswith("P4_LAYER|"):
            r=fields(line); layers[(r["HISTORY"],int(r["DAY"]),int(r["LAYER"]))]=float(r["THETA"])
        elif line.startswith("P4_HISTORY_PASS|"):
            r=fields(line); passes[r["HISTORY"]]=r
        elif line.startswith("P4_TIMING|"):
            timing={k:float(v) for k,v in fields(line).items()}
    if raw.count("P4_EXECUTION_COMPLETE=PASS")!=1: raise SystemExit("missing completion certificate")
    hist_ids=HISTORIES[a.purpose]; n=len(BOUNDS[a.purpose])-1
    if set(passes)!=set(hist_ids) or len(state)!=120 or len(layers)!=120*n:
        raise SystemExit("incomplete core trajectory")
    maxledger=max(float(passes[h]["MAX_LEDGER"]) for h in hist_ids)
    if not math.isfinite(maxledger) or maxledger>1e-8: raise SystemExit("ledger gate")
    out_hist={}
    for h in hist_ids:
        rows=[]
        for day in range(1,61):
            s=state[(h,day)]
            th=[layers[(h,day,j)] for j in range(1,n+1)]
            rows.append({
              "day":day,"total_storage_cm":float(s["TOTAL"]),"surface_0_20_storage_cm":float(s["S20"]),
              "root_zone_0_40_storage_cm":float(s["S40"]),"upper_0_80_storage_cm":float(s["S80"]),
              "cumulative_bottom_downward_cm":float(s["CUMBOT"]),
              "daily_bottom_downward_flux_cm_per_day":float(s["QBOT"]),"layer_theta":th
            })
        out_hist[h]=rows
    stable="\n".join(x for x in raw.splitlines() if x.startswith(("P4_STATE|","P4_LAYER|","P4_HISTORY_PASS|","P4_EXECUTION_COMPLETE=")))+"\n"
    result={
      "schema":"swap5.rom-practical.research-interface.v1","status":"QUALIFIED",
      "purpose":a.purpose,"material":a.material,"member":MEMBER[a.purpose],
      "boundaries_cm":BOUNDS[a.purpose],"dt_day":0.005,"horizon_days":60,
      "forcing_profile":a.forcing_profile,"histories":out_hist,
      "max_water_ledger_cm":maxledger,
      "rhs_evaluations":sum(int(passes[h]["RHS_EVALS"]) for h in hist_ids),
      "provenance":{"core_sha256":sha(a.exe),"materials_sha256":sha(a.materials),
                    "stable_core_output_sha256":hashlib.sha256(stable.encode()).hexdigest()},
      "core_internal_timing":timing,
      "production_authorized":False,"application_acceptance_adjudicated":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":"QUALIFIED","purpose":a.purpose,"material":a.material,"ledger":maxledger},sort_keys=True))
    if temp is not None: temp.cleanup()
if __name__=="__main__": main()
