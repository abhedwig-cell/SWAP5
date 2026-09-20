#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

B14 = {
    "theta_r": 0.01,
    "theta_s": 0.416774,
    "alpha": 0.00541,
    "n": 1.301528,
    "ks": 0.895023,
    "ell": -0.334926,
}
HISTS = {
    "X01": 0.022579865507494613,
    "X02": 0.037633109179157694,
    "X03": 0.05268635285082077,
    "X04": 0.06773959652248385,
}

def sha(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(text:str, old:str, new:str, label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def materialize_fortran(src:pathlib.Path,dst:pathlib.Path)->None:
    text=src.read_text(encoding="utf-8")
    text=replace_once(text,
        "integer, parameter :: NHIST=4, NSTEPS=64",
        "integer, parameter :: NHIST=4, NSTEPS=1024","Fortran NSTEPS")
    text=replace_once(text,
        "real(real64), parameter :: theta_r_b01=0.02_real64",
        "real(real64), parameter :: theta_r_b01=0.01_real64","theta_r")
    text=replace_once(text,
        "real(real64), parameter :: theta_s_b01=0.427494_real64",
        "real(real64), parameter :: theta_s_b01=0.416774_real64","theta_s")
    text=replace_once(text,
        "    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64\n"
        "    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64",
        "    tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64\n"
        "    nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64",
        "B14 parameter block")

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
    lambdas="""  pure real(real64) function history_lambda(ih) result(lambda)
    integer,intent(in) :: ih
    select case(ih)
    case(1);lambda=0.022579865507494613_real64
    case(2);lambda=0.037633109179157694_real64
    case(3);lambda=0.052686352850820770_real64
    case(4);lambda=0.067739596522483850_real64
    case default;lambda=-1.0_real64
    end select
  end function history_lambda
"""
    split="""  pure function split_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=10) :: label
    label='B14BLIND  '
  end function split_label
"""
    text=label_pat.sub(labels,text,count=1)
    text=lambda_pat.sub(lambdas,text,count=1)
    text=split_pat.sub(split,text,count=1)
    dst.write_text(text,encoding="utf-8")

def materialize_fmc(src:pathlib.Path,dst:pathlib.Path)->None:
    text=src.read_text(encoding="utf-8")
    text=replace_once(
        text,
        "TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N\n"
        "KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199",
        "TR=0.01; TS=0.416774; ALPHA=0.00541; N=1.301528; M=1.0-1.0/N\n"
        "KS=0.895023; ELL=-0.334926; NBINS=200; I=100; J0=101; J1=199",
        "FMC B14 constants")
    text=replace_once(
        text,
        'HISTS={"G25":0.25,"G50":0.50,"G75":0.75,"G125":1.25}',
        'HISTS={"X01":0.022579865507494613,"X02":0.037633109179157694,"X03":0.05268635285082077,"X04":0.06773959652248385}',
        "FMC histories")
    text=replace_once(text,"NSTEPS=64; HARD_MASS=1e-12; RELAX_TOL=1e-14",
                      "NSTEPS=1024; HARD_MASS=1e-12; RELAX_TOL=1e-14","FMC NSTEPS")
    dst.write_text(text,encoding="utf-8")

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--fortran-source",required=True,type=pathlib.Path)
    ap.add_argument("--fortran-output",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-source",required=True,type=pathlib.Path)
    ap.add_argument("--fmc-output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    materialize_fortran(a.fortran_source,a.fortran_output)
    materialize_fmc(a.fmc_source,a.fmc_output)
    out={
      "schema":"swap5.lare.bc2.c4x.b14-materialization.v1",
      "fortran_source_sha256":sha(a.fortran_source),
      "fortran_output_sha256":sha(a.fortran_output),
      "fmc_source_sha256":sha(a.fmc_source),
      "fmc_output_sha256":sha(a.fmc_output),
      "material":"B14",
      "B14":B14,
      "histories":HISTS,
      "allowed_changes":[
        "B01 constitutive constants -> preregistered B14 constants",
        "C4R/C4V history identity -> preregistered X01-X04 B14-scaled front factors",
        "NSTEPS 64 -> 1024",
        "split label only"
      ],
      "closure_changed":False,
      "boundary_semantics_changed":False,
      "timestep_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
