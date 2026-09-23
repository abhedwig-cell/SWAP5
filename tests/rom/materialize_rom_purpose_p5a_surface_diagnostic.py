#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib, subprocess, sys, tempfile

def one(text,old,new,label):
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--member",required=True,choices=("S8","S12","S16"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--representation-ladder",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    source=("tests/rom/rom_purpose_p1_surface_b01_source.f90" if a.material=="B01"
            else "tests/rom/rom_purpose_p1_surface_b14_source.f90")
    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"p4matched.f90"; bm=td/"p4matched.json"
        subprocess.run([
          sys.executable,"tests/rom/materialize_rom_purpose_p4_matched_richards.py",
          "--purpose","SURF_P","--material",a.material,"--member",a.member,
          "--temporal-factor",str(a.temporal_factor),
          "--representation-ladder",str(a.representation_ladder),
          "--coarse-output-adapter","tests/rom/materialize_rom_purpose_p1_coarse_output.py",
          "--source",source,
          "--surface-materializer","tests/rom/materialize_rom_purpose_p4_surface_reference.py",
          "--output",str(base),"--manifest",str(bm)
        ],check=True)
        text=base.read_text()
        m=json.loads(bm.read_text())

    old="""      call require(ieee_is_finite(local_integrated).and.local_integrated<=1.6e-15_real64, &
           'LAREDYN0R local residual within prior integrated allowance')"""
    new="""      write(*,'(*(g0))') 'ROMPURP_P5A_LOCAL_ALLOWANCE|T0=',t0,'|T1=',t1,'|DT=',t1-t0, &
           '|CLASS=',trim(failure_class),'|BAL_FLAGS=',bal_flags,'|HEAD_FLAGS=',head_flags, &
           '|RMAX=',rmax,'|RSUM=',rsum,'|IMAX=',imax,'|LOCAL_INTEGRATED_CM=',local_integrated, &
           '|ALLOWANCE_CM=',1.6e-15_real64,'|RATIO=',local_integrated/1.6e-15_real64, &
           '|REP_BOUND_CM=',rep_bound,'|ABS_TOTAL_RESIDUAL_CM=',abs_integrated
      call require(ieee_is_finite(local_integrated).and.local_integrated<=1.6e-15_real64, &
           'LAREDYN0R local residual within prior integrated allowance')"""
    text=one(text,old,new,"P5A observability injection")
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(text)
    out={
      "schema":"swap5.rom-purpose.p5a.surface-diagnostic-materialization.v1",
      "material":a.material,"member":a.member,"temporal_factor":a.temporal_factor,
      "p4_base":m,"diagnostic_marker":"ROMPURP_P5A_LOCAL_ALLOWANCE",
      "allowance_cm":1.6e-15,"require_preserved":True,
      "solver_or_physics_changed":False,"numerical_policy_changed":False,
      "tolerance_changed":False,"response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")

if __name__=="__main__": main()
