#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--segment1-root",required=True,type=pathlib.Path)
    ap.add_argument("--segment2-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()
    a.output_dir.mkdir(parents=True,exist_ok=True)
    factor=32
    provenance={}
    for material in ("B01","B14"):
      rendered={}
      for opt in (0,2):
        chunks=[]
        for history in range(1,5):
          art1=f"p3gwr2048seg1-{material}-o{opt}-h{history}"
          art2=f"p3gwr2048seg2-{material}-o{opt}-h{history}"
          p1=a.segment1_root/art1/"segment1.txt"
          p2=a.segment2_root/art2/"segment2.txt"
          if not p1.exists() or not p2.exists():
            raise SystemExit(f"missing exact-state segments {material} O{opt} h{history}")
          t1=p1.read_text(errors="strict"); t2=p2.read_text(errors="strict")
          hist=t1+t2
          if hist.count("LAREGW1_STATE|")!=1024*factor:
            raise SystemExit(f"state coverage mismatch {material} O{opt} h{history}")
          if hist.count("LAREGW1_PROFILE|")!=1024*16:
            raise SystemExit(f"profile coverage mismatch {material} O{opt} h{history}")
          chunks.append(hist)
          provenance[f"{material}/O{opt}/h{history}"]={
            "segment1":str(p1),"segment2":str(p2),
            "method":"EXACT_STATE_CHECKPOINT_HALF_SEGMENTS"
          }
        text="".join(chunks)
        out=a.output_dir/f"gw_{material}_R2048_T32_o{opt}.txt"
        out.write_text(text)
        rendered[opt]=text
      if rendered[0]!=rendered[2]:
        raise SystemExit(f"O0/O2 identity mismatch for recovered R2048_T32 {material}")
    result={
      "schema":"swap5.rom-purpose.p3.gw-r2048-t32-recovery-result.v1",
      "route":"R2048_T32","materials":["B01","B14"],"optimization_modes":[0,2],
      "history_count_per_material":4,
      "complete_route_files":4,
      "provenance":provenance,
      "scientific_change":False,
      "forcing_changed":False,
      "numerical_policy_changed":False,
      "solver_or_physics_changed":False
    }
    (a.output_dir/"recovery.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    return 0
if __name__=="__main__":
    raise SystemExit(main())
