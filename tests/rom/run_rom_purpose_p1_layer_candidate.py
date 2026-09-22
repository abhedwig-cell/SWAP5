#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
OBS_DT=0.0008
NSTEPS=1024
DT=0.0001
SUBSTEPS=8
LEDGER_GATE=1.0e-10
PARTITIONS={
    "S4":[0.0,20.0,40.0,80.0,160.0],
    "G4":[0.0,80.0,120.0,140.0,160.0],
    "U4":[0.0,40.0,80.0,120.0,160.0],
}
HISTORY_SE={"01":0.68,"02":0.82,"03":0.73,"04":0.90}

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None: raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec); sys.modules[name]=mod; spec.loader.exec_module(mod); return mod

bc=load_module("rom_purpose_p1_layer_base",HERE/"rom_purpose_p1_layer_base.py")

def configure_material(material):
    if material=="B01":
        bc.THETA_R=0.02; bc.THETA_S=0.427494; bc.ALPHA=0.021659
        bc.N_VG=1.734737; bc.M_VG=1.0-1.0/bc.N_VG
        bc.KS=31.225016; bc.LAMBDA=0.98087
    elif material=="B14":
        bc.THETA_R=0.01; bc.THETA_S=0.416774; bc.ALPHA=0.00541
        bc.N_VG=1.301528; bc.M_VG=1.0-1.0/bc.N_VG
        bc.KS=0.895023; bc.LAMBDA=-0.334926
    else: raise ValueError(material)
    bc.OBS_DT=OBS_DT; bc.STEPS=NSTEPS
    for name,bounds in PARTITIONS.items():
        bc.PARTITIONS[name]=np.diff(np.asarray(bounds,float))

def surface_symbol(history,step):
    idx=history[-2:]
    first=192 if idx in ("01","02") else 320
    second=512
    wet_first=idx in ("01","03")
    if step<=first: return "WET" if wet_first else "DRY"
    if step<=second: return "DRY" if wet_first else "WET"
    return "HOLD"

def gw_symbol(history,step):
    idx=history[-2:]
    first=192 if idx in ("01","02") else 320
    second=512
    rise_first=idx in ("01","03")
    if step<=first: return "BOTTOM_HEAD_RISE" if rise_first else "BOTTOM_HEAD_FALL"
    if step<=second: return "BOTTOM_HEAD_FALL" if rise_first else "BOTTOM_HEAD_RISE"
    return "HOLD"

def qtop_surface(sym,k0):
    if sym=="WET": return 1.10*k0
    if sym=="DRY": return 0.90*k0
    if sym=="HOLD": return k0
    raise ValueError(sym)

def qtop_gw(sym,k0): return k0

def boundary_surface(history,sym,psi0): return None

def boundary_gw(history,sym,psi0):
    if sym=="BOTTOM_HEAD_RISE": return 0.90*psi0
    if sym=="BOTTOM_HEAD_FALL": return 1.10*psi0
    if sym=="HOLD": return None
    raise ValueError(sym)

def integrate(storage,bounds,lo,hi):
    dz=np.diff(np.asarray(bounds,float)); theta=np.asarray(storage,float)/dz
    total=0.0
    for th,a,b in zip(theta,bounds,bounds[1:]):
        total += float(th)*max(0.0,min(hi,b)-max(lo,a))
    return total

def map10(storage,bounds):
    return [integrate(storage,bounds,10.0*i,10.0*(i+1))/10.0 for i in range(16)]

def run(purpose,material,member):
    configure_material(material)
    bounds=PARTITIONS[member]
    histories={}
    if purpose=="surface":
        ids=[f"S{i:02d}" for i in range(1,5)]
        bc.HISTORY_SE={h:HISTORY_SE[h[-2:]] for h in ids}
        bc.symbol=surface_symbol; bc.qtop_downward=qtop_surface; bc.boundary_psi=boundary_surface
    else:
        ids=[f"G{i:02d}" for i in range(1,5)]
        bc.HISTORY_SE={h:HISTORY_SE[h[-2:]] for h in ids}
        bc.symbol=gw_symbol; bc.qtop_downward=qtop_gw; bc.boundary_psi=boundary_gw
    status="QUALIFIED"; failures={}; maxledger=0.0; maxiter=0
    for h in ids:
        try:
            sol=bc.solve(bc.Case(member,h,"CURRENT_LAYER_FACE"),DT)
            ledger=float(sol["max_abs_water_ledger_cm"])
            if ledger>LEDGER_GATE: raise RuntimeError(f"water ledger gate {ledger}")
            storage=np.asarray(sol["layer_storage_cm"],float)
            histories[h]={
              "layer_storage_cm":storage.tolist(),
              "total_storage_cm":np.sum(storage,axis=1).tolist(),
              "surface_0_20_storage_cm":[integrate(x,bounds,0,20) for x in storage],
              "root_zone_0_40_storage_cm":[integrate(x,bounds,0,40) for x in storage],
              "upper_0_80_storage_cm":[integrate(x,bounds,0,80) for x in storage],
              "theta_10cm":[map10(x,bounds) for x in storage],
              "cumulative_bottom_exchange_cm":sol["cumulative_bottom_downward_cm"],
              "interval_bottom_flux_cm_per_day":sol["interval_average_bottom_downward_flux_cm_per_day"],
            }
            maxledger=max(maxledger,ledger); maxiter=max(maxiter,int(sol["max_corrector_iterations"]))
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN"; failures[h]=str(exc)
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED"; failures[h]=str(exc)
    return {
      "purpose":purpose,"material":material,"id":member,"dimension":4,
      "boundaries_cm":bounds,"closure":"CURRENT_LAYER_FACE","candidate_dt_day":DT,
      "status":status,"failures":failures,"max_abs_water_ledger_cm":maxledger,
      "max_corrector_iterations":maxiter,
      "histories":histories if status=="QUALIFIED" and len(histories)==4 else None
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("surface","gw"))
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--member",required=True,choices=("S4","G4","U4"))
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--reference-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text()); rr=json.loads(a.reference_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P1_REFERENCE_OR_CANDIDATE_RESPONSE"
    assert rr["status"]=="P1_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED"
    assert rr["candidate_response_authorized"] is True
    allowed={"surface":("S4","U4"),"gw":("G4","U4")}
    if a.member not in allowed[a.purpose]:
        raise SystemExit(f"{a.member} is not a frozen {a.purpose} member")
    out={
      "schema":"swap5.rom-purpose.p1.layer-candidate.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P1",
      "candidate":run(a.purpose,a.material,a.member),
      "scientific_firewall":{
        "representation_changed":False,"closure_changed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,"production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    c=out["candidate"]
    print(json.dumps({"purpose":a.purpose,"material":a.material,"member":a.member,
      "status":c["status"],"max_abs_water_ledger_cm":c["max_abs_water_ledger_cm"]},sort_keys=True))
if __name__=="__main__": main()
