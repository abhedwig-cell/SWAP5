#!/usr/bin/env python3
"""Generate isolated trial-step globalization probe, never edit production."""
import argparse,hashlib
from pathlib import Path
ap=argparse.ArgumentParser()
ap.add_argument('output',type=Path)
ap.add_argument('cap',choices=['1','0.1'])
a=ap.parse_args()
src=Path('src/legacy/b1_10_port/headcalc.f90')
s=src.read_text()
needle='!     back tracking cycle\n      factor = 1.0d0\n'
assert s.count(needle)==1
replacement=needle+'''!     TOP03 research only: scale the trial direction before existing line search.
      if (canonical_trial .and. provider_constitutive_active .and. swmacro == 0) then
         factmax = maxval(abs(fsi_ws%delta_head(1:NN)) / max(1.0d0,abs(fsi_ws%old_head(1:NN))))
         if (factmax > CAP_VALUE) factor = CAP_VALUE / factmax
      end if
'''.replace('CAP_VALUE',a.cap+'d0')
a.output.write_text(s.replace(needle,replacement))
print('TOP03_GUARD_ORIGINAL_SHA256='+hashlib.sha256(src.read_bytes()).hexdigest())
print('TOP03_GUARD_RESEARCH_CAP='+a.cap)
