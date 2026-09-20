#!/usr/bin/env python3
"""Research-only counters for raw-head interval-hint behavior."""
from pathlib import Path
import sys
if len(sys.argv)!=3:
    raise SystemExit("usage: patch_raw_head_interval_counters.py sptabulated.f90 swap_main.f90")
tab=Path(sys.argv[1]); main=Path(sys.argv[2])
s=tab.read_text()

diag="""module tabhyd_raw_diag_mod
  implicit none
  integer(8), save :: eval_count(4)=0_8
  integer(8), save :: hint_hit(2)=0_8, hint_miss(2)=0_8
contains
  subroutine tabhyd_raw_diag_report()
    write(*,'(a,4(1x,i0))') 'TABHYD_RAW_EVAL', eval_count
    write(*,'(a,4(1x,i0))') 'TABHYD_RAW_HINT', hint_hit(1),hint_miss(1),hint_hit(2),hint_miss(2)
  end subroutine tabhyd_raw_diag_report
end module tabhyd_raw_diag_mod

"""
marker="\nmodule doln\n"
if marker not in s: raise SystemExit("doln marker missing")
s=s.replace(marker,"\n"+diag+"module doln\n",1)

old="""subroutine EvalTabulatedFunction(inverse,n,ind1,ind2,ind3,node,   &
     &                                  sptab,ientrytab,xe,ye,dyedxe, iWhat)
      use doln"""
new="""subroutine EvalTabulatedFunction(inverse,n,ind1,ind2,ind3,node,   &
     &                                  sptab,ientrytab,xe,ye,dyedxe, iWhat)
      use tabhyd_raw_diag_mod
      use doln"""
if s.count(old)!=1: raise SystemExit("Eval use anchor mismatch")
s=s.replace(old,new,1)

old="""       ye = 0.d0

!      sptab(1,node,i):"""
new="""       ye = 0.d0
       if (inverse == 0 .and. iWhat >= 1 .and. iWhat <= 4) eval_count(iWhat)=eval_count(iWhat)+1_8

!      sptab(1,node,i):"""
if s.count(old)!=1: raise SystemExit("eval init anchor mismatch")
s=s.replace(old,new,1)

old="""         if (klast >= 1 .and. klast < n .and. &
     &       xe_local >= sptab(ind1,node,klast) .and. &
     &       xe_local <  sptab(ind1,node,klast+1)) then
            klo = klast
            khi = klo + 1
         else
            klo = 1"""
new="""         if (klast >= 1 .and. klast < n .and. &
     &       xe_local >= sptab(ind1,node,klast) .and. &
     &       xe_local <  sptab(ind1,node,klast+1)) then
            hint_hit(family)=hint_hit(family)+1_8
            klo = klast
            khi = klo + 1
         else
            hint_miss(family)=hint_miss(family)+1_8
            klo = 1"""
if s.count(old)!=1: raise SystemExit("raw hint anchor mismatch")
s=s.replace(old,new,1)
tab.write_text(s)

m=main.read_text()
old="""use variables, only: logf
use swap_log, only: log_init, log_close, LOGLEVEL_DEBUG, LOGLEVEL_INFO"""
new="""use variables, only: logf
use tabhyd_raw_diag_mod, only: tabhyd_raw_diag_report
use swap_log, only: log_init, log_close, LOGLEVEL_DEBUG, LOGLEVEL_INFO"""
if m.count(old)!=1: raise SystemExit("main use anchor mismatch")
m=m.replace(old,new,1)
old="""! write message on screen
write(*,'(a)')' Swap normal completion!'"""
new="""call tabhyd_raw_diag_report()

! write message on screen
write(*,'(a)')' Swap normal completion!'"""
if m.count(old)!=1: raise SystemExit("main report anchor mismatch")
m=m.replace(old,new,1)
main.write_text(m)
print("RAW_HEAD_INTERVAL_COUNTERS_PATCH_APPLIED")
