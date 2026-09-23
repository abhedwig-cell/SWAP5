#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

def main()->int:
    ap=argparse.ArgumentParser()
    for i in range(1,5):
        ap.add_argument(f"--segment{i}-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()
    roots={i:getattr(a,f"segment{i}_root") for i in range(1,5)}
    a.output_dir.mkdir(parents=True,exist_ok=True)

    provenance={}
    for material in ("B01","B14"):
      rendered={}
      for opt in (0,2):
        histories=[]
        for history in range(1,5):
          parts=[]
          for seg in range(1,5):
            art=f"p3gwt32seg{seg}-{material}-o{opt}-h{history}"
            path=roots[seg]/art/f"segment{seg}.txt"
            if not path.exists():
                raise SystemExit(f"missing {path}")
            parts.append(path.read_text(errors="strict"))
            provenance[f"{material}/O{opt}/h{history}/s{seg}"]=str(path)
          hist="".join(parts)
          if hist.count("LAREGW1_STATE|")!=32768:
            raise SystemExit(f"state coverage mismatch {material} O{opt} h{history}")
          if hist.count("LAREGW1_PROFILE|")!=16384:
            raise SystemExit(f"profile coverage mismatch {material} O{opt} h{history}")
          histories.append(hist)
        text="".join(histories)
        out=a.output_dir/f"gw_{material}_R2048_T32_o{opt}.txt"
        out.write_text(text)
        rendered[opt]=text
      if rendered[0]!=rendered[2]:
        raise SystemExit(f"O0/O2 identity mismatch {material}")

    result={
      "schema":"swap5.rom-purpose.p3.gw-r2048-t32-recovery-result.v2",
      "route":"R2048_T32",
      "segment_steps":8192,
      "segments_per_history":4,
      "materials":["B01","B14"],
      "optimization_modes":[0,2],
      "histories":[1,2,3,4],
      "scientific_change":False,
      "forcing_changed":False,
      "numerical_policy_changed":False,
      "solver_or_physics_changed":False,
      "provenance":provenance
    }
    (a.output_dir/"recovery.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    return 0
if __name__=="__main__":
    raise SystemExit(main())
