#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import re

NBINS=200
I=100
J0=101
J1=199
DEPTH=160.0
PSI_MIN=0.01

def sha(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def psi_from_se(se:float,alpha:float,n:float)->float:
    m=1.0-1.0/n
    return ((se**(-1.0/m)-1.0)**(1.0/n))/alpha

def psi_from_theta(theta:float,mat:dict)->float:
    se=(theta-mat["theta_r"])/(mat["theta_s"]-mat["theta_r"])
    if not 0.0<se<1.0:
        raise ValueError(f"theta outside material bounds: {theta}")
    return psi_from_se(se,mat["alpha_per_cm"],mat["n"])

def exact_initial_layer_means(mat:dict,lambdas:list[float],bounds:list[float])->list[list[float]]:
    tr=float(mat["theta_r"]);ts=float(mat["theta_s"])
    dtheta=(ts-tr)/NBINS
    theta_i=tr+I*dtheta
    theta=[tr+j*dtheta for j in range(J0,J1+1)]
    psi=[psi_from_theta(t,mat) for t in theta]
    result=[]
    for lam in lambdas:
        fronts=[lam*x for x in psi]
        row=[]
        for lo,hi in zip(bounds,bounds[1:]):
            dz=hi-lo
            ylow=DEPTH-hi
            yhigh=DEPTH-lo
            mean=theta_i
            for hj in fronts:
                overlap=max(0.0,min(hj,yhigh)-max(0.0,ylow))
                mean += dtheta*overlap/dz
            if not tr<mean<ts:
                raise ValueError(f"initial theta outside bounds: {mean} for {lo}-{hi}")
            if psi_from_theta(mean,mat)<=PSI_MIN:
                raise ValueError(f"initial layer enters near-saturation branch: {lo}-{hi}")
            row.append(mean)
        result.append(row)
    return result

def fmt(x:float)->str:
    return format(float(x),".17g")

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--base-fortran",required=True,type=pathlib.Path)
    ap.add_argument("--panel",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    panel=json.loads(a.panel.read_text())
    prereg=json.loads(a.prereg.read_text())
    if panel["phase"]!="PREREGISTERED_BEFORE_NEW_LAYER_ROM_TRANSFER_REFERENCE_RESPONSE":
        raise SystemExit("wrong B0 phase")
    if prereg["phase"]!="PREREGISTERED_BEFORE_NEW_MATERIAL_FIXED_HEAD_RESPONSE":
        raise SystemExit("wrong B1H phase")
    if a.material not in prereg["material_roles"]["new_response_materials"]:
        raise SystemExit("material not in frozen new-response panel")
    mat=next(x for x in panel["panel"] if x["id"]==a.material)
    lambdas=[float(x) for x in prereg["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]

    psi505=psi_from_se(0.505,float(mat["alpha_per_cm"]),float(mat["n"]))
    expected=[
        x*float(prereg["initial_state_transfer"]["psi_B01_Se0p505_cm"])/psi505
        for x in prereg["initial_state_transfer"]["source_B01_lambda"]
    ]
    if max(abs(x-y) for x,y in zip(expected,lambdas))>2e-15:
        raise SystemExit(f"frozen lambda drift: expected={expected} frozen={lambdas}")

    initial_preflight={}
    for spec in prereg["representations"]:
        initial_preflight[spec["id"]]=exact_initial_layer_means(
            mat,lambdas,[float(x) for x in spec["boundaries_cm"]]
        )

    text=a.base_fortran.read_text(encoding="utf-8")
    text=replace_once(text,
        "integer, parameter :: NHIST=4, NSTEPS=64",
        "integer, parameter :: NHIST=4, NSTEPS=1024","NSTEPS")
    text=replace_once(text,
        "real(real64), parameter :: theta_r_b01=0.02_real64",
        f"real(real64), parameter :: theta_r_b01={fmt(mat['theta_r'])}_real64","theta_r")
    text=replace_once(text,
        "real(real64), parameter :: theta_s_b01=0.427494_real64",
        f"real(real64), parameter :: theta_s_b01={fmt(mat['theta_s'])}_real64","theta_s")
    old=(
        "    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64\n"
        "    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64"
    )
    new=(
        f"    tr={fmt(mat['theta_r'])}_real64;ts={fmt(mat['theta_s'])}_real64;"
        f"alpha={fmt(mat['alpha_per_cm'])}_real64\n"
        f"    nn={fmt(mat['n'])}_real64;ks={fmt(mat['Ksat_cm_per_day'])}_real64;"
        f"lam={fmt(mat['lambda'])}_real64"
    )
    text=replace_once(text,old,new,"material block")

    label_pat=re.compile(r"(?ms)  function history_label\(ih\) result\(label\).*?  end function history_label\n")
    lambda_pat=re.compile(r"(?ms)  pure real\(real64\) function history_lambda\(ih\) result\(lambda\).*?  end function history_lambda\n")
    split_pat=re.compile(r"(?ms)  pure function split_label\(ih\) result\(label\).*?  end function split_label\n")
    if len(label_pat.findall(text))!=1 or len(lambda_pat.findall(text))!=1 or len(split_pat.findall(text))!=1:
        raise SystemExit("unexpected D13 history-function structure")
    labels="""  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=4) :: label
    select case(ih)
    case(1);label='X01 '
    case(2);label='X02 '
    case(3);label='X03 '
    case(4);label='X04 '
    case default;label='BAD '
    end select
  end function history_label
"""
    lams="\n".join(
        ["  pure real(real64) function history_lambda(ih) result(lambda)",
         "    integer,intent(in) :: ih","    select case(ih)"]+
        [f"    case({i});lambda={fmt(v)}_real64" for i,v in enumerate(lambdas,1)]+
        ["    case default;lambda=-1.0_real64","    end select","  end function history_lambda",""]
    )
    split=f"""  pure function split_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=10) :: label
    label='{a.material}XFER   '
  end function split_label
"""
    text=label_pat.sub(labels,text,count=1)
    text=lambda_pat.sub(lams,text,count=1)
    text=split_pat.sub(split,text,count=1)
    a.output.write_text(text,encoding="utf-8")

    manifest={
      "schema":"swap5.layer-rom.b1h.materialization.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1H",
      "material":a.material,
      "material_parameters":mat,
      "scaled_lambdas":lambdas,
      "psi_Se0p505_cm":psi505,
      "initial_preflight":initial_preflight,
      "base_fortran_sha256":sha(a.base_fortran),
      "output_fortran_sha256":sha(a.output),
      "reference_response_generated":False,
      "closure_changed":False,
      "boundary_semantics_changed":False,
      "timestep_changed":False,
      "response_based":False,
      "pre_reference_pass":True
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "material":a.material,"pre_reference_pass":True,
      "scaled_lambdas":lambdas,"psi_Se0p505_cm":psi505,
      "output_fortran_sha256":manifest["output_fortran_sha256"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
