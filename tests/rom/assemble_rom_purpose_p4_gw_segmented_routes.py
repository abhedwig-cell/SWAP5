#!/usr/bin/env python3
from __future__ import annotations
import argparse,pathlib

ROUTES={"R512_T32":(32,4),"R1024_T32":(32,4),"R2048_T16":(16,2),"R2048_T8":(8,1)}

def find_log(root:pathlib.Path,material:str,route:str,opt:int,history:int,segment:int)->pathlib.Path:
    pat=f"p4gwseg{segment}-{material}-{route}-o{opt}-h{history}/segment{segment}.txt"
    p=root/pat
    if not p.exists(): raise RuntimeError(f"missing {p}")
    return p

def main()->int:
    ap=argparse.ArgumentParser()
    for i in range(1,5): ap.add_argument(f"--segment{i}-root",type=pathlib.Path,required=True)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()
    roots={i:getattr(a,f"segment{i}_root") for i in range(1,5)}
    a.output_dir.mkdir(parents=True,exist_ok=True)
    for material in ("B01","B14"):
      for route,(factor,nseg) in ROUTES.items():
        for opt in (0,2):
          out=a.output_dir/f"gw_{material}_{route}_o{opt}.txt"
          with out.open("wb") as fh:
            for h in (1,2,3,4):
              for seg in range(1,nseg+1):
                fh.write(find_log(roots[seg],material,route,opt,h,seg).read_bytes())
        a0=a.output_dir/f"gw_{material}_{route}_o0.txt"; a2=a.output_dir/f"gw_{material}_{route}_o2.txt"
        if a0.read_bytes()!=a2.read_bytes(): raise RuntimeError(f"O0/O2 mismatch {material} {route}")
        text=a0.read_text(errors="strict")
        if text.count("LAREGW1_STATE|")!=4*1024*factor: raise RuntimeError(f"state count {material} {route}")
        if text.count("LAREGW1_PROFILE|")!=4*1024*16: raise RuntimeError(f"profile count {material} {route}")
    return 0

if __name__=="__main__": raise SystemExit(main())
