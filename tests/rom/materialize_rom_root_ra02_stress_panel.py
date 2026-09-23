#!/usr/bin/env python3
"""Materialize the prospectively stress-activating ROM-ROOT-RA02 panel.

Input is an already materialized C6R root-active harness (base or segmented).
Only the four initial effective-saturation values are changed. Feddes physics,
potential transpiration, root profiles, forcing, horizon and numerical controls
are untouched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

MARKER="ROM_ROOT_RA02_STRESS_PANEL"
OLD_VALUES={1:"0.60",2:"0.45",3:"0.60",4:"0.45"}
NEW_VALUES={1:"0.551",2:"0.351",3:"0.551",4:"0.351"}

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected exactly one occurrence, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    ap.add_argument("--manifest",type=Path)
    args=ap.parse_args()

    text=args.input.read_text()
    if MARKER in text:
        raise SystemExit("RA02 stress panel already materialized")

    start=text.find("  pure real(real64) function initial_se(ih) result(value)")
    end=text.find("  end function initial_se",start)
    if start<0 or end<0:
        raise SystemExit("initial_se block not found")
    end=text.find("\n",end)
    if end<0: end=len(text)
    block=text[start:end]
    original=block
    for case in (1,2,3,4):
        old=f"case({case}); value={OLD_VALUES[case]}_real64"
        new=f"case({case}); value={NEW_VALUES[case]}_real64"
        block=one(block,old,new,f"initial Se case {case}")
    block += f"\n  ! {MARKER}: Se0=h3(Tp)+0.001, bound before response."
    text=text[:start]+block+text[end:]

    base_marker="  write(*,'(A)') 'LAREDYN0R_C6R_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\n"
    seg_marker="  write(*,'(A)') 'LAREDYN0R_C6R_SEGMENTED_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\n"
    marker_line="  write(*,'(A)') 'ROM_ROOT_RA02_STRESS_PANEL=TRUE'\n"
    if base_marker in text:
        text=one(text,base_marker,base_marker+marker_line,"RA02 base completion marker")
    elif seg_marker in text:
        text=one(text,seg_marker,seg_marker+marker_line,"RA02 segmented completion marker")
    else:
        raise SystemExit("C6R completion marker not found")

    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(text)
    manifest={
      "schema":"swap5.rom_root.ra02.stress-panel-materialization.v1",
      "state":"MATERIALIZED_PROSPECTIVE_STRESS_PANEL",
      "initial_se":{"V01":0.551,"V02":0.351,"V03":0.551,"V04":0.351},
      "feddes_h3_se":{"high":0.55,"low":0.35},
      "initial_offset_above_h3_se":0.001,
      "potential_transpiration_changed":False,
      "root_profiles_changed":False,
      "feddes_parameters_changed":False,
      "forcing_changed":False,
      "horizon_changed":False,
      "numerical_policy_changed":False,
      "production_source_changed":False,
      "response_based":False,
      "input_sha256":hashlib.sha256(args.input.read_bytes()).hexdigest(),
      "output_sha256":hashlib.sha256(args.output.read_bytes()).hexdigest()
    }
    if args.manifest:
        args.manifest.parent.mkdir(parents=True,exist_ok=True)
        args.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
