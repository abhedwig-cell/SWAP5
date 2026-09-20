#!/usr/bin/env python3
"""Research-only exact theta/C reuse for the raw-head log(K) candidate.

Apply after patch_raw_head_logk_lookup.py. The raw-head interpolation itself is
unchanged. EvalTabulatedFunction computes C together with theta; watcon stores
that exact C per node/head; moiscap reuses it only for exact floating-point head
equality.
"""
from pathlib import Path
import sys

if len(sys.argv)!=3:
    raise SystemExit("usage: patch_raw_head_capacity_reuse.py sptabulated.f90 soilhydraulicsutils.f90")

tab=Path(sys.argv[1]); util=Path(sys.argv[2])

s=tab.read_text()
old="""            if (iWhat <= 2) then
               ! WC (1) or K (2)
               ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
               if (iWhat == 2) ye = dexp(ye)
            else"""
new="""            if (iWhat <= 2) then
               ! WC (1) or K (2)
               ye = my_HVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (124,*) IER
               if (iWhat == 1) then
                  dyedxe = my_HPVAL (xe_local,x,y,yp,sig,IER); if (IER /= 0) write (125,*) IER
               end if
               if (iWhat == 2) ye = dexp(ye)
            else"""
if s.count(old)!=1:
    raise SystemExit(f"raw TSPACK value branch mismatch: {s.count(old)}")
s=s.replace(old,new,1)
tab.write_text(s)

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

   real(real64), save :: rawcap_head(macp) = 1.0d300
   real(real64), save :: rawcap_value(macp) = 0.0_real64
   logical, save :: rawcap_valid(macp) = .false.

contains"""
if u.count(old_contains)!=1:
    raise SystemExit(f"module contains anchor mismatch: {u.count(old_contains)}")
u=u.replace(old_contains,new_contains,1)

old_w="""      else if (swsophy == 1) then
         dum = head
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
         else if (head > h_crit) then
            ! TAB-HYD research candidate: preserve the analytical default-MvG
            ! linear wet theta branch instead of accepting the spline endpoint slope.
            dum = h_crit
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, dum, help, moiscap, 1)
            watcon = help + (sptab(2,node,numtab(node)) - help) / (-h_crit) * (head - h_crit)
            watcon = min(watcon, sptab(2,node,numtab(node)))
         else if (dum < sptab(1,node,1)) then
            watcon = sptab(2,node,1)
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, watcon, moiscap, 1)
         end if
      end if"""
new_w="""      else if (swsophy == 1) then
         dum = head
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
            moiscap = dt*1.0d-7
         else if (head > h_crit) then
            ! Preserve the analytical default-MvG linear wet theta branch.
            dum = h_crit
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, dum, help, moiscap, 1)
            watcon = help + (sptab(2,node,numtab(node)) - help) / (-h_crit) * (head - h_crit)
            watcon = min(watcon, sptab(2,node,numtab(node)))
            moiscap = (sptab(2,node,numtab(node)) - help) / (-h_crit)
            if (head > -1.0_real64 .and. moiscap < (dt * 1.0d-7)) moiscap = dt * 1.0d-7
         else if (dum < sptab(1,node,1)) then
            watcon = sptab(2,node,1)
            moiscap = 0.0_real64
         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, watcon, moiscap, 1)
         end if
         rawcap_head(node) = head
         rawcap_value(node) = moiscap
         rawcap_valid(node) = .true.
      end if"""
if u.count(old_w)!=1:
    raise SystemExit(f"raw watcon block mismatch: {u.count(old_w)}")
u=u.replace(old_w,new_w,1)

old_c="""      else if (swsophy == 1) then
         dum = head
         if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else if (head > h_crit) then"""
new_c="""      else if (swsophy == 1) then
         dum = head
         if (rawcap_valid(node) .and. head == rawcap_head(node)) then
            moiscap = rawcap_value(node)
         else if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else if (head > h_crit) then"""
if u.count(old_c)!=1:
    raise SystemExit(f"raw moiscap block mismatch: {u.count(old_c)}")
u=u.replace(old_c,new_c,1)

util.write_text(u)
print("RAW_HEAD_CAPACITY_REUSE_PATCH_APPLIED")
