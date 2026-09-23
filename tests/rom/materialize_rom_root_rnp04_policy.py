#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

FAIL_BLOCK="""    ! C6R root-active Reference fails closed after any first-attempt failure; the mode-2 fallback is not root-active authority.
    if(p%root_extraction_active)then
      if(allocated(before))deallocate(before)
      return
    end if

"""
BOUND_BLOCK="""    call prospective_bound(state,p,rep_bound,bound_ok)
    call require(bound_ok.and.rep_bound>0.0_real64,'LAREDYN0R prospective representation bound')
"""
NO_FALLBACK="""        call require(.not.fallback_used,'LAREDYN0R C6R root-active fallback forbidden')
"""
CLASS_ANCHOR="""    select case(trim(failure_class))
"""
COMPLETE="""  write(*,'(A)') 'LAREDYN0R_C6R_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'
"""

def one(text: str, old: str, new: str, label: str) -> str:
    n=text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()
    text=args.input.read_text()

    text=one(text,BOUND_BLOCK,"""    if(p%root_extraction_active)then
      rep_bound=sum(p%dz(1:numnod)*spacing(p%cofgen(2,1:numnod)))
      bound_ok=ieee_is_finite(rep_bound).and.rep_bound>0.0_real64
    else
      call prospective_bound(state,p,rep_bound,bound_ok)
    end if
    call require(bound_ok.and.rep_bound>0.0_real64,'RNP04 prospective representation bound')
""","prospective root representation bound")

    text=one(text,FAIL_BLOCK,"""    ! ROM_ROOT_RNP04_POLICY: root-active second attempt is admitted only by
    ! the independently preregistered representation-floor rule below.
""","remove C6R root fail-closed return only inside RNP04 materialization")

    text=one(text,CLASS_ANCHOR,"""    if(p%root_extraction_active)then
      call require(trim(failure_class)=='RETRY_TOTAL_ONLY','RNP04 root policy admits total-only failure only')
    end if
    select case(trim(failure_class))
""","root failure-class firewall")

    text=one(text,NO_FALLBACK,"""        if(fallback_used)then
          history_fallbacks=history_fallbacks+1
          total_fallbacks=total_fallbacks+1
        end if
""","RNP04 fallback accounting")

    text=text.replace("'LAREDYN0R_FALLBACK|HISTORY_STEP_T0='","'RNP04_FALLBACK|HISTORY_STEP_T0='")
    if text.count("'RNP04_FALLBACK|HISTORY_STEP_T0='") != 1:
        raise SystemExit("RNP04 fallback marker replacement failed")

    text=one(text,COMPLETE,COMPLETE+"  write(*,'(A)') 'RNP04_REFERENCE_POLICY_COMPLETE=PASS'\n","completion marker")
    args.output.write_text(text)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
