#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1])
s = path.read_text()
needle = """         if (use_TSPACK) then
             x(1:2)   = sptab(ind1,node,klo:khi)"""
inject = """         ! TAB-HYD research-only fast linear interpolation in transformed x.
         ! theta is linear in x; log(K) is linear in x.
         f1 = sptab(ind2,node,klo)
         f2 = sptab(ind2,node,khi)
         delta = (f2-f1)/(x2-x1)
         xx = xe_local-x1
         if (iWhat <= 2) then
            ye = f1 + xx*delta
            if (do_ln_trans .and. iWhat == 2) ye = dexp(ye)
         else if (iWhat == 3) then
            dyedxe = delta
            if (do_ln_trans) dyedxe = dyedxe/(-xe+1.0d0)
         else if (iWhat == 4) then
            ye = f1 + xx*delta
            if (do_ln_trans) then
               ye = dexp(ye)
               dyedxe = delta*ye/(-xe+1.0d0)
            else
               dyedxe = delta
            end if
         end if
         return

         if (use_TSPACK) then
             x(1:2)   = sptab(ind1,node,klo:khi)"""
if s.count(needle) != 1:
    raise SystemExit(f"expected one EvalTabulatedFunction insertion point, found {s.count(needle)}")
path.write_text(s.replace(needle, inject, 1))
print("FAST_LINEAR_PATCH_APPLIED")
