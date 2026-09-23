#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

MARKER="ROM_ROOT_RNP03_VECTOR_TRACE"
USE_OLD="subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n                    numerical_config, physical_config, explicit_step_duration, parameter_set)\n"
USE_NEW=USE_OLD+"   use, intrinsic :: iso_fortran_env, only: int64\n"
ANCHOR="""         if (.not. legacy_state_binding .and. maxit == 128) then
            write(*,'(*(g0))') 'RNP02_TRACE|IT=',solver_numbit,'|BT=',iBackTr, &
                 '|FACTOR=',factor,'|SUM=',sum1,'|FMAX=',Fmax,'|SUMP=',sump,'|SUMOLD=',sumold
         end if
"""
EXTRA=ANCHOR+"""         if (.not. legacy_state_binding .and. maxit == 128 .and. &
              any(solver_numbit == [17,26,27,32,50,51,56])) then
            do i=1,NN
               write(*,'(A,I0,A,I0,A,Z16.16,A,Z16.16)') 'RNP03_VECTOR|IT=',solver_numbit, &
                    '|I=',i,'|H=',transfer(state%h(i),0_int64),'|R=',transfer(fsi_ws%residual(i),0_int64)
            end do
         end if
         ! ROM_ROOT_RNP03_VECTOR_TRACE logging only
"""

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--path",required=True,type=Path)
    args=ap.parse_args()
    text=args.path.read_text()
    if MARKER in text:
        return 0
    if USE_OLD not in text:
        raise SystemExit("headcalc signature anchor missing")
    text=text.replace(USE_OLD,USE_NEW,1)
    if text.count(ANCHOR)!=1:
        raise SystemExit(f"expected one RNP02 trace anchor, found {text.count(ANCHOR)}")
    text=text.replace(ANCHOR,EXTRA,1)
    args.path.write_text(text)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
