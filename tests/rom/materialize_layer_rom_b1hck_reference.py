#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib


ALLOWED_DT=(0.0005,0.00025)
OBS_DT=0.001
BASE_STEPS=1024


def sha(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--base-fortran",required=True,type=pathlib.Path)
    ap.add_argument("--dt-day",required=True,type=float)
    ap.add_argument("--material",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    if not any(abs(a.dt_day-x)<=1e-15 for x in ALLOWED_DT):
        raise SystemExit(f"dt not in frozen B1HCK ladder: {a.dt_day}")
    factor=int(round(OBS_DT/a.dt_day))
    if factor not in (2,4) or abs(factor*a.dt_day-OBS_DT)>1e-15:
        raise SystemExit("dt does not divide common observation interval")
    nsteps=BASE_STEPS*factor

    text=a.base_fortran.read_text(encoding="utf-8")
    text=replace_once(
        text,
        "integer, parameter :: NHIST=4, NSTEPS=1024",
        f"integer, parameter :: NHIST=4, NSTEPS={nsteps}",
        "NSTEPS",
    )
    text=replace_once(
        text,
        "real(real64), parameter :: step_dt=0.001_real64",
        f"real(real64), parameter :: step_dt={format(a.dt_day,'.17g')}_real64",
        "step_dt",
    )
    a.output.write_text(text,encoding="utf-8")

    manifest={
        "schema":"swap5.layer-rom.b1hck.reference-materialization.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-B1HCK",
        "material":a.material,
        "dt_day":a.dt_day,
        "substeps_per_observation":factor,
        "nsteps":nsteps,
        "common_observation_interval_day":OBS_DT,
        "common_observation_count":BASE_STEPS,
        "base_fortran_sha256":sha(a.base_fortran),
        "output_fortran_sha256":sha(a.output),
        "only_changes":["NSTEPS","step_dt"],
        "solver_tolerance_changed":False,
        "physics_changed":False,
        "boundary_changed":False,
        "production_rom_authorized":False,
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,
        "dt_day":a.dt_day,
        "substeps_per_observation":factor,
        "nsteps":nsteps,
        "output_fortran_sha256":manifest["output_fortran_sha256"],
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
