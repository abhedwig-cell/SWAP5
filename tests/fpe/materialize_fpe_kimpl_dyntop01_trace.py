#!/usr/bin/env python3
from pathlib import Path
import argparse
ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()
needle="if (timeint04_step == 24 .or. timeint04_step == 25) then"
count=src.count(needle)
if count < 5:
    raise SystemExit(f"expected trace conditions, found {count}")
src=src.replace(needle,"if (timeint04_step > 0) then")
Path(args.output).write_text(src)
print("F_PE_KIMPL_DYNTOP01_TRACE_SCOPE=ALL_STEPS")
