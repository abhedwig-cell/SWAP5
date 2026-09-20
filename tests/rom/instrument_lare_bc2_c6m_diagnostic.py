#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--path",required=True,type=Path)
a=ap.parse_args()
s=a.path.read_text()
old="        call require(ok,'LAREDYN0R accepted history step')"
new="""        if(.not.ok)then
          write(*,'(*(g0))') 'LAREDYN0R_C6M_DIAG_FAIL|STEP=',step,'|SUBSTEP=',substep, &
               '|T0=',sub_t0,'|T1=',sub_t1,'|STATUS=',status,'|ROUTE=',trim(route), &
               '|NL=',nl,'|IR=',ir,'|BACK=',back,'|MASS=',mass,'|BEX=',bex,'|BFLUX=',bflux, &
               '|TOP_FLUX=',forcing%top_flux,'|BOTTOM_MODE=',p%bottom_mode
        end if
        call require(ok,'LAREDYN0R accepted history step')"""
if s.count(old)!=1:
    raise SystemExit(f"expected one accepted-step guard, found {s.count(old)}")
a.path.write_text(s.replace(old,new,1))
print("C6M_DIAGNOSTIC_INSTRUMENTATION=PASS")
