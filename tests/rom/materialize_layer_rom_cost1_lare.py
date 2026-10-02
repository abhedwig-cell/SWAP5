#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

ALLOWED_DT=(1.0e-4,2.5e-5)
OBS_DT=1.0e-3

def sha(p:pathlib.Path)->str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def replace_once(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def fmt(x:float)->str:
    return format(float(x),".17g")

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--base-fortran",required=True,type=pathlib.Path)
    ap.add_argument("--panel",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--cost-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True)
    ap.add_argument("--dt-day",required=True,type=float)
    ap.add_argument("--variant",choices=("BASE","FINE"),required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    if not any(abs(a.dt_day-x)<=1e-15 for x in ALLOWED_DT):
        raise SystemExit(f"dt outside frozen COST1 pair: {a.dt_day}")
    expected=1.0e-4 if a.variant=="BASE" else 2.5e-5
    if abs(a.dt_day-expected)>1e-15:
        raise SystemExit("variant/dt mismatch")
    substeps=int(round(OBS_DT/a.dt_day))
    if abs(substeps*a.dt_day-OBS_DT)>1e-15 or substeps not in (10,40):
        raise SystemExit("invalid substep factor")

    panel=json.loads(a.panel.read_text())
    b1h=json.loads(a.b1h_prereg.read_text())
    cost=json.loads(a.cost_prereg.read_text())
    if cost["phase"]!="PREREGISTERED_AFTER_PHASE_B_FIDELITY_FREEZE_BEFORE_NEW_TIMING_EXPOSURE":
        raise SystemExit("wrong COST1 phase")
    mat=next(x for x in panel["panel"] if x["id"]==a.material)
    lambdas=[float(x) for x in b1h["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]

    text=a.base_fortran.read_text(encoding="utf-8")
    text=replace_once(text,
        "integer, parameter :: MAXN=12, NHIST=4, NSTEPS=64, NBINS=200, IBASE=100, J0=101, J1=199",
        "integer, parameter :: MAXN=12, NHIST=4, NSTEPS=1024, NBINS=200, IBASE=100, J0=101, J1=199","NSTEPS")
    text=replace_once(text,
        "real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64, ALPHA=0.021659_real64",
        f"real(real64), parameter :: TR={fmt(mat['theta_r'])}_real64, TS={fmt(mat['theta_s'])}_real64, ALPHA={fmt(mat['alpha_per_cm'])}_real64","retention")
    text=replace_once(text,
        "real(real64), parameter :: NN=1.734737_real64, MM=1.0_real64-1.0_real64/NN",
        f"real(real64), parameter :: NN={fmt(mat['n'])}_real64, MM=1.0_real64-1.0_real64/NN","n")
    text=replace_once(text,
        "real(real64), parameter :: KS=31.225016_real64, ELL=0.98087_real64",
        f"real(real64), parameter :: KS={fmt(mat['Ksat_cm_per_day'])}_real64, ELL={fmt(mat['lambda'])}_real64","conductivity")
    text=replace_once(text,
        "real(real64), parameter :: DEPTH=160.0_real64, OBS_DT=0.001_real64, DT=0.0001_real64",
        f"real(real64), parameter :: DEPTH=160.0_real64, OBS_DT=0.001_real64, DT={fmt(a.dt_day)}_real64","dt")
    text=replace_once(text,
        "integer, parameter :: SUBSTEPS=10, MAXCOR=50",
        f"integer, parameter :: SUBSTEPS={substeps}, MAXCOR=50","substeps")

    suffix=a.variant
    for n in (4,6,8):
        text=text.replace(f"LARE_R{n}",f"LR{n}_{suffix}")
    text=text.replace("LARE_BC2_C4T_BENCH|","LAYER_ROM_COST1_BENCH|")

    label_pat=re.compile(r"(?ms)  function history_label\(ih\) result\(v\).*?  end function history_label\n")
    lambda_pat=re.compile(r"(?ms)  pure real\(real64\) function history_lambda\(ih\) result\(v\).*?  end function history_lambda\n")
    if len(label_pat.findall(text))!=1 or len(lambda_pat.findall(text))!=1:
        raise SystemExit("history function structure drift")
    labels="""  function history_label(ih) result(v)
    integer,intent(in)::ih
    character(len=4)::v
    select case(ih)
    case(1);v='X01 '
    case(2);v='X02 '
    case(3);v='X03 '
    case(4);v='X04 '
    case default;v='BAD '
    end select
  end function history_label
"""
    lams="\n".join(
        ["  pure real(real64) function history_lambda(ih) result(v)",
         "    integer,intent(in)::ih","    select case(ih)"]+
        [f"    case({i});v={fmt(v)}_real64" for i,v in enumerate(lambdas,1)]+
        ["    case default;v=-1.0_real64","    end select","  end function history_lambda",""]
    )
    text=label_pat.sub(labels,text,count=1)
    text=lambda_pat.sub(lams,text,count=1)

    a.output.write_text(text,encoding="utf-8")
    manifest={
      "schema":"swap5.layer-rom.cost1.lare-materialization.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-COST1",
      "material":a.material,"variant":a.variant,"dt_day":a.dt_day,
      "substeps_per_observation":substeps,"observation_count":1024,
      "material_parameters":mat,"scaled_lambdas":lambdas,
      "base_fortran_sha256":sha(a.base_fortran),"output_fortran_sha256":sha(a.output),
      "source_changes":[
        "B01 constitutive parameters -> frozen transfer-panel material",
        "V01-V04 -> frozen X01-X04 scaled-lambda histories",
        "64 -> 1024 observations",
        f"Heun dt -> {a.dt_day} d with {substeps} substeps per observation",
        f"route labels -> LR4_{suffix}, LR6_{suffix}, LR8_{suffix}",
        "benchmark record prefix only"
      ],
      "closure_changed":False,"boundary_changed":False,"state_changed":False,
      "corrector_tolerance_changed":False,"response_based":False,
      "production_rom_authorized":False
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"material":a.material,"variant":a.variant,"dt_day":a.dt_day,
                      "substeps":substeps,"output_sha256":manifest["output_fortran_sha256"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
