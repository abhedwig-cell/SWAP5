#!/usr/bin/env python3
"""Research-only reuse of capacity computed alongside tabulated watcon.

Apply after the exact-head cache patch. TSPACK interpolation remains unchanged.
For iWhat=1 EvalTabulatedFunction already has the interval and endpoint data, so
it also evaluates dtheta/dh. watcon stores that exact capacity per node/head.
moiscap reuses it only under exact floating-point head equality.
"""
from pathlib import Path
import sys

if len(sys.argv)!=3:
    raise SystemExit("usage: patch_watcon_capacity_reuse.py sptabulated.f90 soilhydraulicsutils.f90")

tab=Path(sys.argv[1]); util=Path(sys.argv[2])

s=tab.read_text()
old="""            if (iWhat <= 2) then
               ! WC (1) or K (2)
               ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
               if (do_ln_trans .and. iWhat == 2) ye = dexp(ye)      ! back transformation for K
            else"""
new="""            if (iWhat <= 2) then
               ! WC (1) or K (2)
               ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
               if (iWhat == 1) then
                  ! TAB-HYD research: compute C while interval setup is hot so
                  ! moiscap can reuse it for the same exact node/head.
                  dyedxe = my_HPVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (125,*) IER
                  if (do_ln_trans) dyedxe = dyedxe/(-xe+1.0d0)
               end if
               if (do_ln_trans .and. iWhat == 2) ye = dexp(ye)      ! back transformation for K
            else"""
if s.count(old)!=1:
    raise SystemExit(f"TSPACK value branch mismatch: {s.count(old)}")
tab.write_text(s.replace(old,new,1))

u=util.read_text()
old_use="""   use iso_fortran_env, only: real64
   use variables, only: cofgen, swsophy, numtab, sptab, ientrytab, &"""
new_use="""   use iso_fortran_env, only: real64
   use swap_array_dimensions, only: macp
   use variables, only: cofgen, swsophy, numtab, sptab, ientrytab, &"""
if u.count(old_use)!=1:
    raise SystemExit(f"module use anchor mismatch: {u.count(old_use)}")
u=u.replace(old_use,new_use,1)

old_contains="""   public :: watcon, moiscap, hconduc, dhconduc, prhead, hcomean, dkmean

contains"""
new_contains="""   public :: watcon, moiscap, hconduc, dhconduc, prhead, hcomean, dkmean

   ! TAB-HYD research-only exact-head theta/C reuse cache.
   real(real64), save :: tabcap_head(macp) = 1.0d300
   real(real64), save :: tabcap_value(macp) = 0.0_real64
   logical, save :: tabcap_valid(macp) = .false.

contains"""
if u.count(old_contains)!=1:
    raise SystemExit(f"module contains anchor mismatch: {u.count(old_contains)}")
u=u.replace(old_contains,new_contains,1)

old_w="""      else if (swsophy == 1) then
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
         else if (head > h_crit) then
            ! TAB-HYD research candidate: preserve the analytical default-MvG
            ! linear wet theta branch instead of accepting the spline endpoint slope.
            dum = h_crit
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, dum, help, moiscap, 1)
            watcon = help + (sptab(2,node,numtab(node)) - help) / (-h_crit) * (head - h_crit)
            watcon = min(watcon, sptab(2,node,numtab(node)))
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, watcon, moiscap, 1)
         end if
      end if"""
new_w="""      else if (swsophy == 1) then
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
            moiscap = dt*1.0d-7
         else if (head > h_crit) then
            ! TAB-HYD research candidate: preserve the analytical default-MvG
            ! linear wet theta branch instead of accepting the spline endpoint slope.
            dum = h_crit
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, dum, help, moiscap, 1)
            watcon = help + (sptab(2,node,numtab(node)) - help) / (-h_crit) * (head - h_crit)
            watcon = min(watcon, sptab(2,node,numtab(node)))
            moiscap = (sptab(2,node,numtab(node)) - help) / (-h_crit)
            if (head > -1.0_real64 .and. moiscap < (dt * 1.0d-7)) moiscap = dt * 1.0d-7
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, watcon, moiscap, 1)
         end if
         tabcap_head(node) = head
         tabcap_value(node) = moiscap
         tabcap_valid(node) = .true.
      end if"""
if u.count(old_w)!=1:
    raise SystemExit(f"cached watcon block mismatch: {u.count(old_w)}")
u=u.replace(old_w,new_w,1)

old_c="""      else if (swsophy == 1) then
         if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else if (head > h_crit) then"""
new_c="""      else if (swsophy == 1) then
         if (tabcap_valid(node) .and. head == tabcap_head(node)) then
            moiscap = tabcap_value(node)
         else if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else if (head > h_crit) then"""
if u.count(old_c)!=1:
    raise SystemExit(f"cached moiscap branch mismatch: {u.count(old_c)}")
u=u.replace(old_c,new_c,1)

util.write_text(u)
print(f"WATCON_CAPACITY_REUSE_PATCH_APPLIED {tab} {util}")
