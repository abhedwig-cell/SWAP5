#!/usr/bin/env python3
from pathlib import Path
import argparse,re
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()
new,n=re.subn(r"integer, parameter :: nstep=4000, tail_start=13",
              "integer, parameter :: nstep=40000, tail_start=13",src,count=1)
if n!=1:
    raise SystemExit(f"MIQUAL09 expected one nstep marker, found {n}")
Path(args.output).write_text(new)
print("F_PE_MIQUAL09_MATERIALIZER=PASS")
