#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import numpy as np

HISTS=("X01","X02","X03","X04")
NSTEPS=1024

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod

def fields(line):
    out={}
    for p in line.split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1);out[k]=v
    return out

def patch_material(c4v,mat,lambdas):
    c4v.TR=float(mat["theta_r"]);c4v.TS=float(mat["theta_s"])
    c4v.ALPHA=float(mat["alpha_per_cm"]);c4v.N=float(mat["n"]);c4v.M=1.0-1.0/c4v.N
    c4v.KS=float(mat["Ksat_cm_per_day"]);c4v.ELL=float(mat["lambda"])
    c4v.DTHETA=(c4v.TS-c4v.TR)/c4v.NBINS;c4v.THETA_I=c4v.TR+c4v.I*c4v.DTHETA
    c4v.HISTS={f"X{i:02d}":float(v) for i,v in enumerate(lambdas,1)}
    c4v.THETA=[c4v.TR+j*c4v.DTHETA for j in range(c4v.J0,c4v.J1+1)]
    c4v.PSI=[c4v.psi_scalar(t) for t in c4v.THETA]
    b=c4v.bc1;b.THETA_R=c4v.TR;b.THETA_S=c4v.TS;b.ALPHA=c4v.ALPHA
    b.N_VG=c4v.N;b.M_VG=c4v.M;b.KS=c4v.KS;b.LAMBDA=c4v.ELL

def parse_compiled(path):
    states={};cells={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LARE_BC2_C4T_STATE|"):
            r=fields(line);states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif line.startswith("LARE_BC2_C4T_CELL|"):
            r=fields(line);cells[(r["HISTORY"].strip(),int(r["STEP"]),int(r["CELL"]))]=r
    if len(states)!=4*NSTEPS or len(cells)!=4*NSTEPS*16:
        raise SystemExit(f"compiled output structure states={len(states)} cells={len(cells)}")
    return states,cells

def compiled_summary(c4v,path,r16):
    states,cells=parse_compiled(path)
    series=c4v.empty_series()
    for h in HISTS:
        refcum=c4v.ref_arrays(r16,h)
        for st in range(1,NSTEPS+1):
            r=states[(h,st)]
            total=float(r["TOTAL_STORAGE"]);cum=float(r["CUM_BOTTOM"]);q=float(r["BOTTOM_FLUX"])
            mapped=[float(cells[(h,st,i)]["THETA"]) for i in range(1,17)]
            upper=sum(mapped[:8])*10.0;lower=sum(mapped[8:])*10.0
            c4v.append_errors(series,h,st,total,cum,q,mapped,upper,lower,r16,refcum)
    return c4v.summarize({"series":series})["1024"]

def compare(actual,expected,tol):
    keys=(
      "storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day",
      "bottom_flux_sign_errors","abs_mean_signed_bottom_flux_error_cm_per_day",
      "max_abs_final_cumulative_bottom_error_cm","mapped_theta_rmse",
      "upper_storage_rmse_cm","lower_storage_rmse_cm"
    )
    diffs={}
    for k in keys:
        if k=="bottom_flux_sign_errors":
            if int(actual[k])!=int(expected[k]): raise SystemExit(f"{k} mismatch {actual[k]} {expected[k]}")
            diffs[k]=0
        else:
            d=abs(float(actual[k])-float(expected[k]));diffs[k]=d
            lim=tol["flux"] if "flux" in k else tol["theta"] if k=="mapped_theta_rmse" else tol["water"]
            if d>lim: raise SystemExit(f"{k} mismatch {d} > {lim}")
    return diffs

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--compiled-o0",required=True,type=pathlib.Path)
    ap.add_argument("--compiled-o2",required=True,type=pathlib.Path)
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--panel",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--cost-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True)
    ap.add_argument("--member",choices=("L4","L6","R8"),required=True)
    ap.add_argument("--variant",choices=("BASE","FINE"),required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    if a.compiled_o0.read_bytes()!=a.compiled_o2.read_bytes():
        raise SystemExit("O0/O2 scientific stdout drift")

    panel=json.loads(a.panel.read_text());b1h=json.loads(a.b1h_prereg.read_text());cost=json.loads(a.cost_prereg.read_text())
    mat=next(x for x in panel["panel"] if x["id"]==a.material)
    lambdas=[float(x) for x in b1h["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]
    c4v=load("cost1_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    patch_material(c4v,mat,lambdas)
    c4v.DT=1.0e-4 if a.variant=="BASE" else 2.5e-5
    c4v.SUBSTEPS=10 if a.variant=="BASE" else 40
    r16=c4v.parse_ref(a.reference)
    spec=next(x for x in b1h["representations"] if x["id"]==a.member)
    py=c4v.run_lare(spec,r16)
    if py["status"]!="QUALIFIED": raise SystemExit(f"Python authority route not qualified: {py['status']}")
    expected=c4v.summarize(py)["1024"]
    actual=compiled_summary(c4v,a.compiled_o0,r16)
    tol={"water":1e-10,"flux":1e-8,"theta":1e-12}
    diffs=compare(actual,expected,tol)
    out={
      "schema":"swap5.layer-rom.cost1.lare-compiled-equivalence.v1",
      "material":a.material,"member":a.member,"variant":a.variant,
      "dt_day":c4v.DT,"pass":True,"O0_O2_stdout_identity":True,
      "max_abs_water_ledger_cm":float(py["max_abs_water_ledger_cm"]),
      "maximum_metric_abs_difference":max(float(x) for x in diffs.values()),
      "metric_differences":diffs,
      "timing_authorized_for_route":True,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))

if __name__=="__main__":
    raise SystemExit(main())
