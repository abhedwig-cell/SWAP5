#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys, time
import numpy as np

OBS_DT=1.0
NOBS=60
DT=0.01
LEDGER_GATE=1.0e-9
PARTITIONS={
  "S4":[0.,20.,40.,80.,160.],
  "G8":[0.,80.,100.,120.,130.,140.,150.,155.,160.]
}
SURF_SE={"SD01":0.72,"SD02":0.86}
GW_SE={"GD01":0.72,"GD02":0.88}

def load_module(path):
    spec=importlib.util.spec_from_file_location("rom_practical_p3_base",str(path))
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod
    spec.loader.exec_module(mod); return mod

def configure_material(bc,mat):
    bc.THETA_R=float(mat["theta_r"]); bc.THETA_S=float(mat["theta_s"])
    bc.ALPHA=float(mat["alpha_per_cm"]); bc.N_VG=float(mat["n"])
    bc.M_VG=1.0-1.0/bc.N_VG; bc.KS=float(mat["Ksat_cm_per_day"])
    bc.LAMBDA=float(mat["lambda"]); bc.OBS_DT=OBS_DT; bc.STEPS=NOBS
    for name,bounds in PARTITIONS.items():
        bc.PARTITIONS[name]=np.diff(np.asarray(bounds,float))
        bc.BOUNDARIES[name]=list(bounds)

def surf_symbol(h,step):
    if h=="SD01":
        return ("W12" if step<=15 else "D08" if step<=30 else "W06" if step<=45 else "D04")
    if h=="SD02":
        return ("D06" if step<=20 else "W10" if step<=30 else "D03" if step<=50 else "W08")
    raise ValueError(h)

def surf_q(sym,k0):
    delta={"W12":0.12,"D08":-0.08,"W06":0.06,"D04":-0.04,
           "D06":-0.06,"W10":0.10,"D03":-0.03,"W08":0.08}[sym]
    return k0+delta

def surf_bottom(h,sym,psi0): return None

def gw_symbol(h,step):
    if h=="GD01":
        return "RISE3" if step<=20 else "FALL3" if step<=40 else "HOLD"
    if h=="GD02":
        return "FALL3" if step<=15 else "RISE3" if step<=45 else "HOLD"
    raise ValueError(h)

def gw_q(sym,k0): return k0
def gw_bottom(h,sym,psi0):
    if sym=="RISE3": return 0.97*psi0
    if sym=="FALL3": return 1.03*psi0
    if sym=="HOLD": return None
    raise ValueError(sym)

def integrated(storage,bounds,lo,hi):
    dz=np.diff(np.asarray(bounds,float)); theta=np.asarray(storage,float)/dz; total=0.
    for t,a,b in zip(theta,bounds,bounds[1:]):
        total+=float(t)*max(0.,min(hi,b)-max(lo,a))
    return total

def mapped(storage,bounds):
    dz=np.diff(np.asarray(bounds,float)); theta=np.asarray(storage,float)/dz
    out=[]
    for j in range(16):
        lo=10.*j; hi=lo+10.; water=0.
        for t,a,b in zip(theta,bounds,bounds[1:]):
            water+=float(t)*max(0.,min(hi,b)-max(lo,a))
        out.append(water/10.)
    return out

def run_once(bc,purpose,member):
    histories=SURF_SE if purpose=="SURF_P" else GW_SE
    bc.HISTORY_SE=dict(histories)
    if purpose=="SURF_P":
        bc.symbol=surf_symbol; bc.qtop_downward=surf_q; bc.boundary_psi=surf_bottom
    else:
        bc.symbol=gw_symbol; bc.qtop_downward=gw_q; bc.boundary_psi=gw_bottom
    bounds=PARTITIONS[member]; out={}; maxledger=0.; maxiter=0
    for h in histories:
        sol=bc.solve(bc.Case(member,h,"CURRENT_LAYER_FACE"),DT)
        ledger=float(sol["max_abs_water_ledger_cm"])
        if ledger>LEDGER_GATE: raise RuntimeError(f"ledger gate {ledger}")
        s=np.asarray(sol["layer_storage_cm"],float)
        out[h]={
          "total_storage_cm":np.sum(s,axis=1).tolist(),
          "surface_0_20_storage_cm":[integrated(x,bounds,0,20) for x in s],
          "root_zone_0_40_storage_cm":[integrated(x,bounds,0,40) for x in s],
          "upper_0_80_storage_cm":[integrated(x,bounds,0,80) for x in s],
          "theta_10cm":[mapped(x,bounds) for x in s],
          "cumulative_bottom_downward_cm":[float(x) for x in sol["cumulative_bottom_downward_cm"]],
          "interval_average_bottom_downward_flux_cm_per_day":[float(x) for x in sol["interval_average_bottom_downward_flux_cm_per_day"]]
        }
        maxledger=max(maxledger,ledger); maxiter=max(maxiter,int(sol["max_corrector_iterations"]))
    return out,maxledger,maxiter

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True)
    ap.add_argument("--materials",required=True,type=pathlib.Path)
    ap.add_argument("--base",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    mats=json.loads(a.materials.read_text())["materials"]
    mat=mats[a.material]
    member="S4" if a.purpose=="SURF_P" else "G8"
    bc=load_module(a.base); configure_material(bc,mat)
    wall=[]; cpu=[]; payload=None; ledger=0.; maxiter=0
    for _ in range(3):
        t0=time.perf_counter(); c0=time.process_time()
        h,l,it=run_once(bc,a.purpose,member)
        wall.append(time.perf_counter()-t0); cpu.append(time.process_time()-c0)
        if payload is None: payload=h; ledger=l; maxiter=it
    out={
      "schema":"swap5.rom-practical.p3.candidate.v1","purpose":a.purpose,
      "material":a.material,"member":member,"boundaries_cm":PARTITIONS[member],
      "status":"QUALIFIED","horizon_day":60.0,"observation_dt_day":1.0,
      "candidate_dt_day":DT,"max_abs_water_ledger_cm":ledger,
      "max_corrector_iterations":maxiter,"histories":payload,
      "timing":{"wall_s_median":float(np.median(wall)),"cpu_s_median":float(np.median(cpu)),"repeats":3}
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"purpose":a.purpose,"material":a.material,"member":member,"status":"QUALIFIED","wall_s":out["timing"]["wall_s_median"]},sort_keys=True))
if __name__=="__main__": main()
