#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

needle="""   real(8) :: timeint05_a0, timeint05_a1, timeint05_a2
   common /timeint05_coeff_common/ timeint05_a0, timeint05_a1, timeint05_a2
"""
insert=needle+"""   integer :: timeint13_kpred_active
   real(8) :: timeint13_kpred(1000)
   common /timeint13_kpred_common/ timeint13_kpred_active, timeint13_kpred
"""
if needle not in src:
    raise SystemExit("TIMEINT05 declaration block not found")
src=src.replace(needle,insert,1)

old="state%k(1:numnod) = fsi_ws%provider_k(1:numnod)"
new="""if (timeint13_kpred_active == 1) then
         state%k(1:numnod) = timeint13_kpred(1:numnod)
      else
         state%k(1:numnod) = fsi_ws%provider_k(1:numnod)
      end if"""
if src.count(old)!=1:
    raise SystemExit(f"expected one provider-k reset, found {src.count(old)}")
src=src.replace(old,new,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT13_KPRED_MATERIALIZER=PASS")
