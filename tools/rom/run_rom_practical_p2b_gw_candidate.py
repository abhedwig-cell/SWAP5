#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys, time
import numpy as np

OBS_DT=0.0008
NOBS=1024
DT=0.0001
LEDGER_GATE=1.0e-10
PARTITIONS={"S4":[0.,20.,40.,80.,160.],"G4":[0.,80.,120.,140.,160.],"G6":[0.,80.,100.,120.,140.,150.,160.]}
SURF_SE={"S09":0.70,"S10":0.79,"S11":0.88,"S12":0.91}
GW_SE={"G06":0.70,"G07":0.78,"G08":0.86,"G09":0.92}

def load_module(path):
    spec=importlib.util.spec_from_file_location("rom_practical_base",str(path))
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
    alt1=("WET","DRY","WET","DRY"); alt2=("DRY","WET","DRY","WET")
    phases=alt1 if h in ("S09","S11") else alt2
    return phases[min((step-1)//256,3)]

def surf_q(sym,k0): return (1.15 if sym=="WET" else 0.85)*k0
def surf_bottom(h,sym,psi0): return None

def gw_symbol(h,step):
    if h=="G06":
        return "BOTTOM_HEAD_RISE" if step<=256 else "BOTTOM_HEAD_FALL" if step<=640 else "HOLD"
    if h=="G07":
        return "BOTTOM_HEAD_FALL" if step<=256 else "BOTTOM_HEAD_RISE" if step<=640 else "HOLD"
    if h=="G08":
        return "BOTTOM_HEAD_RISE" if step<=384 else "BOTTOM_HEAD_FALL" if step<=768 else "HOLD"
    if h=="G09":
        return "BOTTOM_HEAD_FALL" if step<=384 else "BOTTOM_HEAD_RISE" if step<=768 else "HOLD"
    raise ValueError(h)
def gw_q(sym,k0): return k0
def gw_bottom(h,sym,psi0):
    if sym=="BOTTOM_HEAD_RISE": return 0.90*psi0
    if sym=="BOTTOM_HEAD_FALL": return 1.10*psi0
    if sym=="HOLD": return None
    raise ValueError(sym)

def integrated(storage,bounds,lo,hi):
    dz=np.diff(np.asarray(bounds,float)); theta=np.asarray(storage,float)/dz; total=0.
    for t,a,b in zip(theta,bounds,bounds[1:]):
        w=max(0.,min(hi,b)-max(lo,a)); total+=float(t)*w
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

def one_run(bc,purpose,member):
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
        if ledger>LEDGER_GATE: raise RuntimeError(f"ledger {ledger}")
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
    ap.add_argument("--member",default=None,choices=("G4","G6","S4"))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    mats=json.loads(a.materials.read_text())["materials"]
    if a.material not in mats: raise SystemExit("unknown material")
    member=a.member or ("S4" if a.purpose=="SURF_P" else "G4")
    if a.purpose=="SURF_P" and member!="S4": raise SystemExit("SURF_P only S4 in this runner")
    if a.purpose=="GW_LB" and member not in ("G4","G6"): raise SystemExit("GW_LB only G4/G6")
    bc=load_module(a.base); configure_material(bc,mats[a.material])
    wall=[]; cpu=[]; payload=None; ledger=0.; maxiter=0
    for _ in range(3):
        t0=time.perf_counter(); c0=time.process_time()
        h,l,it=one_run(bc,a.purpose,member)
        wall.append(time.perf_counter()-t0); cpu.append(time.process_time()-c0)
        if payload is None: payload=h; ledger=l; maxiter=it
    result={
      "schema":"swap5.rom-practical.p2a.candidate.v1","purpose":a.purpose,
      "material":a.material,"member":member,"boundaries_cm":PARTITIONS[member],
      "status":"QUALIFIED","candidate_dt_day":DT,"max_abs_water_ledger_cm":ledger,
      "max_corrector_iterations":maxiter,"histories":payload,
      "timing":{"wall_s_median":float(np.median(wall)),"cpu_s_median":float(np.median(cpu)),"repeats":3}
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:result[k] for k in ("purpose","material","member","status")},sort_keys=True))
if __name__=="__main__": main()
