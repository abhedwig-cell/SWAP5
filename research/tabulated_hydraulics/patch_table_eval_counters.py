#!/usr/bin/env python3
"""Research-only counters for tabulated hydraulic evaluation call flow."""
from pathlib import Path
import sys
if len(sys.argv)!=4:
    raise SystemExit("usage: patch_table_eval_counters.py sptabulated.f90 soilhydraulicsutils.f90 swap_main.f90")
tab=Path(sys.argv[1]); util=Path(sys.argv[2]); main=Path(sys.argv[3])

s=tab.read_text()
diagmod="""module tabhyd_diag_mod
   implicit none
   integer(8), save :: diag_eval(4) = 0_8
   integer(8), save :: diag_x_hit = 0_8, diag_x_miss = 0_8
   integer(8), save :: diag_int_hit(2) = 0_8, diag_int_miss(2) = 0_8
   integer(8), save :: diag_cap_hit = 0_8, diag_cap_miss = 0_8
contains
   subroutine tabhyd_diag_report()
      write(*,'(a,4(1x,i0))') 'TABHYD_DIAG_EVAL', diag_eval
      write(*,'(a,2(1x,i0))') 'TABHYD_DIAG_X', diag_x_hit, diag_x_miss
      write(*,'(a,4(1x,i0))') 'TABHYD_DIAG_INTERVAL', diag_int_hit(1), diag_int_miss(1), diag_int_hit(2), diag_int_miss(2)
      write(*,'(a,2(1x,i0))') 'TABHYD_DIAG_CAP', diag_cap_hit, diag_cap_miss
   end subroutine tabhyd_diag_report
end module tabhyd_diag_mod

"""
if s.count("module doln\n")!=1: raise SystemExit("doln marker mismatch")
s=s.replace("module doln\n",diagmod+"module doln\n",1)
old="""subroutine EvalTabulatedFunction(inverse,n,ind1,ind2,ind3,node,   &
     &                                  sptab,ientrytab,xe,ye,dyedxe, iWhat)
      use doln"""
new="""subroutine EvalTabulatedFunction(inverse,n,ind1,ind2,ind3,node,   &
     &                                  sptab,ientrytab,xe,ye,dyedxe, iWhat)
      use tabhyd_diag_mod
      use doln"""
if s.count(old)!=1: raise SystemExit("Eval use anchor mismatch")
s=s.replace(old,new,1)
old="""       ye = 0.d0

!      sptab(1,node,i):"""
new="""       ye = 0.d0
       if (inverse == 0 .and. iWhat >= 1 .and. iWhat <= 4) diag_eval(iWhat) = diag_eval(iWhat) + 1_8

!      sptab(1,node,i):"""
if s.count(old)!=1: raise SystemExit("Eval counter anchor mismatch")
s=s.replace(old,new,1)
old="""         if (xe == cache_head(node)) then
            xe_local = cache_x(node)
         else"""
new="""         if (xe == cache_head(node)) then
            diag_x_hit = diag_x_hit + 1_8
            xe_local = cache_x(node)
         else
            diag_x_miss = diag_x_miss + 1_8"""
if s.count(old)!=1: raise SystemExit("x cache anchor mismatch")
s=s.replace(old,new,1)
old="""         if (xe == cache_interval_head(family,node) .and. cache_klo(family,node) > 0) then
            klo = cache_klo(family,node)
            khi = klo + 1
         else"""
new="""         if (xe == cache_interval_head(family,node) .and. cache_klo(family,node) > 0) then
            diag_int_hit(family) = diag_int_hit(family) + 1_8
            klo = cache_klo(family,node)
            khi = klo + 1
         else
            diag_int_miss(family) = diag_int_miss(family) + 1_8"""
if s.count(old)!=1: raise SystemExit("interval cache anchor mismatch")
s=s.replace(old,new,1)
tab.write_text(s)

u=util.read_text()
old="""module soilhydraulics_utils
   use error_mod, only: fatalerr_collected"""
new="""module soilhydraulics_utils
   use tabhyd_diag_mod, only: diag_cap_hit, diag_cap_miss
   use error_mod, only: fatalerr_collected"""
if u.count(old)!=1: raise SystemExit("soil module use anchor mismatch")
u=u.replace(old,new,1)
old="""         if (tabcap_valid(node) .and. head == tabcap_head(node)) then
            moiscap = tabcap_value(node)
         else if (head >= -1.0d-9) then"""
new="""         if (tabcap_valid(node) .and. head == tabcap_head(node)) then
            diag_cap_hit = diag_cap_hit + 1_8
            moiscap = tabcap_value(node)
         else if (head >= -1.0d-9) then
            diag_cap_miss = diag_cap_miss + 1_8"""
if u.count(old)!=1: raise SystemExit("capacity cache anchor mismatch")
u=u.replace(old,new,1)
# Count all other miss branches too, once per moiscap call that did not hit.
old="""         else if (head > h_crit) then
            ! TAB-HYD research candidate: derivative of the same explicit"""
new="""         else if (head > h_crit) then
            diag_cap_miss = diag_cap_miss + 1_8
            ! TAB-HYD research candidate: derivative of the same explicit"""
if u.count(old)!=1: raise SystemExit("wet miss anchor mismatch")
u=u.replace(old,new,1)
old="""         else
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, dummy, moiscap, 3)
         end if
      end if
      
   end function moiscap"""
new="""         else
            diag_cap_miss = diag_cap_miss + 1_8
            call EvalTabulatedFunction(0, numtab(node), 1, 2, 4, node, sptab, ientrytab, head, dummy, moiscap, 3)
         end if
      end if
      
   end function moiscap"""
if u.count(old)!=1: raise SystemExit("general miss anchor mismatch")
u=u.replace(old,new,1)
util.write_text(u)

m=main.read_text()
old="""use variables, only: logf
use swap_log, only: log_init, log_close, LOGLEVEL_DEBUG, LOGLEVEL_INFO"""
new="""use variables, only: logf
use tabhyd_diag_mod, only: tabhyd_diag_report
use swap_log, only: log_init, log_close, LOGLEVEL_DEBUG, LOGLEVEL_INFO"""
if m.count(old)!=1: raise SystemExit("main use anchor mismatch")
m=m.replace(old,new,1)
old="""! write message on screen
write(*,'(a)')' Swap normal completion!'"""
new="""call tabhyd_diag_report()

! write message on screen
write(*,'(a)')' Swap normal completion!'"""
if m.count(old)!=1: raise SystemExit("main report anchor mismatch")
m=m.replace(old,new,1)
main.write_text(m)
print("TABHYD_EVAL_COUNTERS_PATCH_APPLIED")
