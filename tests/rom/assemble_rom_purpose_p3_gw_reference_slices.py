#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib

ROUTES={
    "R512_T32":32,
    "R1024_T32":32,
    "R2048_T32":32,
    "R2048_T16":16,
    "R2048_T8":8,
}

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()
    a.output_dir.mkdir(parents=True,exist_ok=True)

    for material in ("B01","B14"):
        for route,factor in ROUTES.items():
            rendered={}
            for opt in (0,2):
                chunks=[]
                for history in range(1,5):
                    hh=f"{history:02d}"
                    matches=list(a.root.rglob(f"gw_{material}_{route}_o{opt}_h{hh}.txt"))
                    if len(matches)!=1:
                        raise SystemExit(f"expected one slice for {material} {route} O{opt} h{hh}, got {len(matches)}")
                    chunks.append(matches[0].read_text(errors="strict"))
                text="".join(chunks)
                if text.count("LAREGW1_STATE|")!=4*1024*factor:
                    raise SystemExit(f"incomplete assembled state trace {material} {route} O{opt}")
                if text.count("LAREGW1_PROFILE|")!=4*1024*16:
                    raise SystemExit(f"incomplete assembled profile trace {material} {route} O{opt}")
                out=a.output_dir/f"gw_{material}_{route}_o{opt}.txt"
                out.write_text(text)
                rendered[opt]=text
            if rendered[0]!=rendered[2]:
                raise SystemExit(f"O0/O2 scientific trace mismatch {material} {route}")

    return 0

if __name__=="__main__":
    raise SystemExit(main())
