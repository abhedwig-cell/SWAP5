#!/usr/bin/env python3
"""Research-only cheap Hermite K/dKdh evaluation using TSPACK knot slopes.

TSPACK preprocessing is unchanged for both theta/C and K/dKdh. During forward
evaluation, theta/C keep the full TSPACK tension-spline evaluator. K and dK/dh
instead use the ordinary cubic Hermite polynomial through the same endpoint
values and the TSPACK-precomputed endpoint slopes, ignoring interval sigma.
"""
from pathlib import Path
import sys
if len(sys.argv)!=2:
    raise SystemExit("usage: patch_hermite_k_eval.py sptabulated.f90")
p=Path(sys.argv[1]); s=p.read_text()

start=s.index("subroutine EvalTabulatedFunction")
end=s.index("subroutine PreProcTabulatedFunction",start)
ev=s[start:end]
needle="""         if (use_TSPACK) then
            x(1:2)   = sptab(ind1,node,klo:khi)"""
insert="""         ! TAB-HYD research candidate: retain TSPACK preprocessing slopes
         ! for K, but evaluate the local segment with cheap cubic Hermite.
         if (iWhat == 2 .or. iWhat == 4) then
            f1 = sptab(ind2,node,klo)
            f2 = sptab(ind2,node,khi)
            d1 = sptab(ind3,node,klo)
            d2 = sptab(ind3,node,khi)
            h = x2 - x1
            delta = (f2-f1)/h
            del1 = (d1-delta)/h
            del2 = (d2-delta)/h
            c2 = -(del1+del1+del2)
            c2t2 = c2+c2
            c3 = (del1+del2)/h
            c3t3 = c3+c3+c3
            xx = xe_local-x1
            ye = f1 + xx*(d1 + xx*(c2 + xx*c3))
            dyedxe = d1 + xx*(c2t2 + xx*c3t3)
            if (do_ln_trans) then
               ye = dexp(ye)
               if (iWhat == 4) dyedxe = dyedxe*ye/(-xe+1.0d0)
            end if
            return
         end if

         if (use_TSPACK) then
            x(1:2)   = sptab(ind1,node,klo:khi)"""
if ev.count(needle)!=1:
    raise SystemExit(f"Eval insertion point mismatch: {ev.count(needle)}")
ev=ev.replace(needle,insert,1)
s=s[:start]+ev+s[end:]
p.write_text(s)
print(f"HERMITE_K_EVAL_PATCH_APPLIED {p}")
