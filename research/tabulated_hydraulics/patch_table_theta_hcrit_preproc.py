#!/usr/bin/env python3
"""Research-only theta preprocessing split at an exact h=-0.01 table knot.

The split is applied only when that knot is present. This is necessary because
the legacy shared theta/K table cannot carry h=-0.01 for soils whose Ksat
plateau begins at a drier head without violating strict K monotonicity.
"""
from pathlib import Path
import sys
if len(sys.argv)!=2:
    raise SystemExit("usage: patch_table_theta_hcrit_preproc.py readswap.f90")
path=Path(sys.argv[1])
s=path.read_text()

old="""            call PreProcTabulatedFunction(1,                            &
     &                       numtablay(lay),headtab,thetatab,dydx,sigma)
            do i = 1,numtablay(lay)
              sptablay(4,lay,i) = dydx(i)
              sptablay(6,lay,i) = sigma(i)   !## MH: new
            enddo"""
new="""            call PreProcTabulatedFunction(1,                            &
     &                       numtablay(lay),headtab,thetatab,dydx,sigma)
            do i = 1,numtablay(lay)
              sptablay(4,lay,i) = dydx(i)
              sptablay(6,lay,i) = sigma(i)   !## MH: new
            enddo

            ! TAB-HYD research candidate: when the generated shared table can
            ! carry an exact h=-0.01 knot, overwrite the dry-branch theta
            ! slopes/tensions with independent preprocessing so the wet linear
            ! branch cannot smooth the derivative kink.
            j = 0
            do i = 1,numtablay(lay)
              if (abs(headtab(i) + dlog(1.01d0)) .lt. 1.0d-12) j = i
            enddo
            if (j .ge. 2) then
              call PreProcTabulatedFunction(1,j,headtab,thetatab,dydx,sigma)
              do i = 1,j
                sptablay(4,lay,i) = dydx(i)
                sptablay(6,lay,i) = sigma(i)
              enddo
            endif"""
if s.count(old)!=1:
    raise SystemExit(f"expected one theta preprocess block, found {s.count(old)}")
path.write_text(s.replace(old,new,1))
print(f"TABLE_THETA_HCRIT_PREPROC_PATCH_APPLIED {path}")
