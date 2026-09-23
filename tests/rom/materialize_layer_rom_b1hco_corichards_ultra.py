#!/usr/bin/env python3
from __future__ import annotations
import argparse,hashlib,json,pathlib

DT=0.000125
SUBSTEPS=8
NSTEPS=8192

def sha(p:pathlib.Path)->str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def replace_once(text,old,new,label):
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--base-harness",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.base_harness.read_text(encoding="utf-8")
    text=replace_once(text,"integer, parameter :: NHIST=4, NSTEPS=1024",
                      f"integer, parameter :: NHIST=4, NSTEPS={NSTEPS}","NSTEPS")
    text=replace_once(text,"real(real64), parameter :: step_dt=0.001_real64",
                      "real(real64), parameter :: step_dt=0.000125_real64","step_dt")
    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.layer-rom.b1hco.corichards-ultra-materialization.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCO",
      "dt_day":DT,"substeps_per_observation":SUBSTEPS,"nsteps":NSTEPS,
      "common_observation_interval_day":0.001,"common_observation_count":1024,
      "input_harness_sha256":sha(a.base_harness),"output_sha256":sha(a.output),
      "only_changes":["NSTEPS","step_dt"],"solver_tolerance_changed":False,
      "physics_changed":False,"boundary_changed":False,"production_rom_authorized":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
