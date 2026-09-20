#!/usr/bin/env python3
"""Research-only theta preprocessing split at exact h=-0.01 table knot."""
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

            ! TAB-HYD research candidate: preserve the derivative kink at
            ! h=-0.01 cm.  Generated candidate tables contain this exact knot.
            ! Keep the full preprocessing above for inverse-route metadata, then
            ! overwrite the dry-branch theta slopes/tensions with an independent
            ! preprocessing that cannot see the wet linear branch.
            j = 0
            do i = 1,numtablay(lay)
              if (abs(headtab(i) + dlog(1.01d0)) .lt. 1.0d-12) j = i
            enddo
            if (j .lt. 2) then
              messag = ' TAB-HYD research table lacks exact h=-0.01 branch knot'
              call fatalerr('Readswap',messag)
            endif
            call PreProcTabulatedFunction(1,j,headtab,thetatab,dydx,sigma)
            do i = 1,j
              sptablay(4,lay,i) = dydx(i)
              sptablay(6,lay,i) = sigma(i)
            enddo"""
if s.count(old)!=1:
    raise SystemExit(f"expected one theta preprocess block, found {s.count(old)}")
path.write_text(s.replace(old,new,1))
print(f"TABLE_THETA_HCRIT_PREPROC_PATCH_APPLIED {path}")
