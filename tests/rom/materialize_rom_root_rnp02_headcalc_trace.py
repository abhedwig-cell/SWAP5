#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

MARKER="ROM_ROOT_RNP02_TRACE"
OLD="""         sump = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))
         sum1 = sum(fsi_ws%residual(1:NN))
         Fmax = maxval(dabs(fsi_ws%residual(1:NN)))
"""
NEW=OLD+"""         if (.not. legacy_state_binding .and. maxit == 128) then
            write(*,'(*(g0))') 'RNP02_TRACE|IT=',solver_numbit,'|BT=',iBackTr, &
                 '|FACTOR=',factor,'|SUM=',sum1,'|FMAX=',Fmax,'|SUMP=',sump,'|SUMOLD=',sumold
         end if
"""

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--path",required=True,type=Path)
    args=ap.parse_args()
    text=args.path.read_text()
    if MARKER in text:
        return 0
    if text.count(OLD)!=1:
        raise SystemExit(f"expected one HeadCalc residual block, found {text.count(OLD)}")
    text=text.replace(OLD,NEW+"         ! "+MARKER+" logging only\n",1)
    args.path.write_text(text)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
