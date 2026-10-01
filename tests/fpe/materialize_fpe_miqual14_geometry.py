#!/usr/bin/env python3
from pathlib import Path
import argparse,re
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
ap.add_argument("--nodes",type=int,required=True)
ap.add_argument("--tail-start",type=int,required=True)
args=ap.parse_args()
src=Path(args.source).read_text()
src,n1=re.subn(r"integer, parameter :: nstep=4000, tail_start=13",
               f"integer, parameter :: nstep=40000, tail_start={args.tail_start}",src,count=1)
src,n2=re.subn(r"call require\(numnod==16,'MIQUAL07 requires N=16'\)",
               f"call require(numnod=={args.nodes},'MIQUAL14 frozen node count')",src,count=1)
if n1!=1 or n2!=1:
    raise SystemExit(f"MIQUAL14 materialization mismatch n1={n1} n2={n2}")
Path(args.output).write_text(src)
print(f"F_PE_MIQUAL14_MATERIALIZER=PASS N={args.nodes} TAIL={args.tail_start}")
