#!/usr/bin/env python3
"""Materialize the corrected prospectively stress-activating ROM-ROOT-RA02R panel.

Only the four initial effective-saturation values are changed. Values are bound
per material from the frozen Feddes critical_hlim3 pressure-head interpolation
and the frozen homogeneous retention relation, with +0.001 effective saturation.
No candidate response or RA02 scientific output is used.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

MARKER="ROM_ROOT_RA02R_STRESS_PANEL"
OLD_VALUES={1:"0.60",2:"0.45",3:"0.60",4:"0.45"}
NEW_VALUES={
  "B01":{1:"0.551",2:"0.42671759600680326",3:"0.551",4:"0.42671759600680326"},
  "B14":{1:"0.551",2:"0.40713288830832667",3:"0.551",4:"0.40713288830832667"},
}
H3={
  "B01":{"high":0.55,"low":0.42571759600680326},
  "B14":{"high":0.55,"low":0.40613288830832667},
}

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected exactly one occurrence, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--manifest",type=Path)
    args=ap.parse_args()

    text=args.input.read_text()
    if MARKER in text:
        raise SystemExit("RA02R stress panel already materialized")

    start=text.find("  pure real(real64) function initial_se(ih) result(value)")
    end=text.find("  end function initial_se",start)
    if start<0 or end<0:
        raise SystemExit("initial_se block not found")
    end=text.find("\n",end)
    if end<0:
        end=len(text)
    block=text[start:end]
    for case in (1,2,3,4):
        old=f"case({case}); value={OLD_VALUES[case]}_real64"
        new=f"case({case}); value={NEW_VALUES[args.material][case]}_real64"
        block=one(block,old,new,f"initial Se case {case}")
    block += f"\n  ! {MARKER}: demand-specific h3(Tp) Se-equivalent + 0.001, bound before response."
    text=text[:start]+block+text[end:]

    base_marker="  write(*,'(A)') 'LAREDYN0R_C6R_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\n"
    seg_marker="  write(*,'(A)') 'LAREDYN0R_C6R_SEGMENTED_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\n"
    marker_line="  write(*,'(A)') 'ROM_ROOT_RA02R_STRESS_PANEL=TRUE'\n"
    if base_marker in text:
        text=one(text,base_marker,base_marker+marker_line,"RA02R base completion marker")
    elif seg_marker in text:
        text=one(text,seg_marker,seg_marker+marker_line,"RA02R segmented completion marker")
    else:
        raise SystemExit("C6R completion marker not found")

    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(text)
    manifest={
      "schema":"swap5.rom_root.ra02r.stress-panel-materialization.v1",
      "state":"MATERIALIZED_PROSPECTIVE_STRESS_PANEL",
      "material":args.material,
      "initial_se":{
        "V01":float(NEW_VALUES[args.material][1]),
        "V02":float(NEW_VALUES[args.material][2]),
        "V03":float(NEW_VALUES[args.material][3]),
        "V04":float(NEW_VALUES[args.material][4])
      },
      "critical_h3_se":H3[args.material],
      "initial_offset_above_demand_specific_h3_se":0.001,
      "potential_transpiration_changed":False,
      "root_profiles_changed":False,
      "feddes_parameters_changed":False,
      "forcing_changed":False,
      "horizon_changed":False,
      "numerical_policy_changed":False,
      "production_source_changed":False,
      "response_based":False,
      "ra02_scientific_output_used":False,
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
