#!/usr/bin/env python3
from pathlib import Path
import argparse,re
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
ap.add_argument("--nodes",type=int,required=True)
ap.add_argument("--tail",type=int,required=True)
ap.add_argument("--steps",type=int,default=20000)
args=ap.parse_args()
src=Path(args.source).read_text()
src,n=re.subn(r"integer, parameter :: nstep=4000, tail_start=13",
              f"integer, parameter :: nstep={args.steps}, tail_start={args.tail}",src,count=1)
if n!=1: raise SystemExit(f"MIQUAL14 nstep marker count={n}")
src,n=re.subn(r"call require\(numnod==16,'MIQUAL07 requires N=16'\)",
              f"call require(numnod=={args.nodes},'MIQUAL14 geometry mismatch')",src,count=1)
if n!=1: raise SystemExit(f"MIQUAL14 geometry marker count={n}")
Path(args.output).write_text(src)
print(f"F_PE_MIQUAL14_MATERIALIZER=PASS|N={args.nodes}|TAIL={args.tail}|STEPS={args.steps}")
