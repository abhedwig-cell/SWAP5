#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys

PRIMARY=("storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day",
         "bottom_flux_sign_errors","abs_mean_signed_bottom_flux_error_cm_per_day",
         "max_abs_final_cumulative_bottom_error_cm","mapped_theta_rmse")
CHECKPOINTS=("64","128","256","512","1024")

def load(name:pathlib.Path|str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(str(name),str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[str(name)]=mod
    spec.loader.exec_module(mod)
    return mod

def patch_material(c4v,mat,lambdas):
    c4v.TR=float(mat["theta_r"])
    c4v.TS=float(mat["theta_s"])
    c4v.ALPHA=float(mat["alpha_per_cm"])
    c4v.N=float(mat["n"])
    c4v.M=1.0-1.0/c4v.N
    c4v.KS=float(mat["Ksat_cm_per_day"])
    c4v.ELL=float(mat["lambda"])
    c4v.DTHETA=(c4v.TS-c4v.TR)/c4v.NBINS
    c4v.THETA_I=c4v.TR+c4v.I*c4v.DTHETA
    c4v.HISTS={f"X{i:02d}":float(v) for i,v in enumerate(lambdas,1)}
    c4v.THETA=[c4v.TR+j*c4v.DTHETA for j in range(c4v.J0,c4v.J1+1)]
    c4v.PSI=[c4v.psi_scalar(t) for t in c4v.THETA]
    b=c4v.bc1
    b.THETA_R=c4v.TR
    b.THETA_S=c4v.TS
    b.ALPHA=c4v.ALPHA
    b.N_VG=c4v.N
    b.M_VG=c4v.M
    b.KS=c4v.KS
    b.LAMBDA=c4v.ELL

def componentwise(candidate,control,tol=1e-12):
    noninferior={}
    strict={}
    for k in PRIMARY:
        if k=="bottom_flux_sign_errors":
            a=int(candidate[k]); b=int(control[k])
            noninferior[k]=a<=b
            strict[k]=a<b
        else:
            a=float(candidate[k]); b=float(control[k])
            noninferior[k]=a<=b+tol
            strict[k]=a<b-tol
    return {
      "noninferior":noninferior,
      "strict":strict,
      "all_noninferior":all(noninferior.values()),
      "any_strict":any(strict.values()),
      "supported":all(noninferior.values()) and any(strict.values())
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--panel",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--materialization",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    panel=json.loads(a.panel.read_text())
    mani=json.loads(a.materialization.read_text())
    if p["phase"]!="PREREGISTERED_BEFORE_NEW_MATERIAL_FIXED_HEAD_RESPONSE":
        raise SystemExit("wrong B1H prereg phase")
    if mani["material"]!=a.material or not mani["pre_reference_pass"]:
        raise SystemExit("materialization/preflight authority mismatch")
    mat=next(x for x in panel["panel"] if x["id"]==a.material)
    lambdas=[float(x) for x in p["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]

    c4v=load("layer_rom_b1h_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    patch_material(c4v,mat,lambdas)
    r16=c4v.parse_ref(a.reference)
    if r16["n"]!=16:
        raise SystemExit("B1H Reference geometry mismatch")
    for h,lam in c4v.HISTS.items():
        if h not in r16["initial"]:
            raise SystemExit(f"missing history {h}")
        if abs(float(r16["initial"][h]["LAMBDA"])-lam)>2e-15:
            raise SystemExit(f"Reference lambda mismatch {h}")

    routes=[c4v.run_lare(spec,r16) for spec in p["representations"]]
    summaries={}
    for route in routes:
        if route["status"]=="QUALIFIED":
            summaries[route["id"]]=c4v.summarize(route)

    op=next(x for x in routes if x["id"]=="R16_OP")
    integrity={
      "reference_state_count":len(r16["states"]),
      "reference_node_count":len(r16["nodes"]),
      "all_members_attempted":len(routes)==len(p["representations"]),
      "R16_operator_control_status":op["status"],
      "maximum_qualified_lare_water_ledger_cm":max(
          [float(x["max_abs_water_ledger_cm"]) for x in routes if x["status"]=="QUALIFIED"] or [0.0]
      ),
    }
    integrity["pass"]=(
      integrity["reference_state_count"]==4096
      and integrity["reference_node_count"]==4096*16
      and integrity["all_members_attempted"]
      and integrity["R16_operator_control_status"]=="QUALIFIED"
      and integrity["maximum_qualified_lare_water_ledger_cm"]<=1e-10
    )

    placement={}
    for label,target,uniform in (("dimension4","L4","U4"),("dimension8","R8","U8")):
        if target in summaries and uniform in summaries:
            placement[label]={
              "targeted":target,
              "uniform":uniform,
              "day1":componentwise(summaries[target]["1024"],summaries[uniform]["1024"]),
              "targeted_day1":summaries[target]["1024"],
              "uniform_day1":summaries[uniform]["1024"]
            }
        else:
            placement[label]={
              "targeted":target,"uniform":uniform,
              "supported":False,
              "reason":"one_or_both_members_not_qualified"
            }

    ladder={}
    for cp in CHECKPOINTS:
        ladder[cp]={}
        for rid in ("L4","L6","R8"):
            ladder[cp][rid]=summaries[rid][cp] if rid in summaries else None

    result={
      "schema":"swap5.layer-rom.phase-b1h.material-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1H",
      "material":a.material,
      "decision":"B1H_MATERIAL_TRANSFER_CHARACTERIZED" if integrity["pass"] else "B1H_REFERENCE_OR_HARNESS_BLOCKED",
      "material_parameters":mat,
      "scaled_lambdas":lambdas,
      "integrity":integrity,
      "member_status":[
        {k:x[k] for k in ("id","dimension","status","failure","max_abs_water_ledger_cm","max_corrector_iterations")}
        for x in routes
      ],
      "summaries":summaries,
      "placement":placement,
      "targeted_dimension_curve":ladder,
      "R16_operator_control_day1":summaries.get("R16_OP",{}).get("1024"),
      "interpretation_firewalls":[
        "Each material was selected from catalog parameters before Layer-ROM response.",
        "Initial-state scaling and all partitions were frozen before Reference generation.",
        "B1H compares only against the same-material fine R16 Reference.",
        "No CoRichards or FMC ranking is performed in B1H.",
        "No application tolerance, timing claim or production decision is made."
      ],
      "application_acceptance_adjudicated":False,
      "performance_measurement_performed":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "material":a.material,
      "decision":result["decision"],
      "integrity":integrity,
      "placement4":placement["dimension4"].get("day1",placement["dimension4"]),
      "placement8":placement["dimension8"].get("day1",placement["dimension8"]),
      "day1":{k:v["1024"] for k,v in summaries.items()}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
