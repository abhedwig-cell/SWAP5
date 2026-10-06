#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--b1h-source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.b1h_source.read_text(encoding="utf-8")

    text=replace_once(
        text,
        "call require(any(numnod==[2,16]),'F_ROMV2_D13_REF geometry is R2 or R16')",
        "call require(any(numnod==[4,6,8,16]),'F_ROMV2_D13_REF geometry is frozen B1HC-Q member')",
        "geometry guard",
    )

    text=replace_once(
        text,
        """  integer :: ih,total_states,total_fallbacks
  real(real64) :: max_abs_mass
""",
        """  integer :: ih,total_states,total_fallbacks,active_histories,env_status
  real(real64) :: max_abs_mass
  character(len=16) :: history_filter_raw
""",
        "declaration block",
    )

    text=replace_once(
        text,
        """  total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64

  do ih=1,NHIST
    call run_history(ih,total_states,total_fallbacks,max_abs_mass)
  end do

  call require(total_states==NHIST*NSTEPS,'F_ROMV2_D13_REF exact library state count')
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_HISTORY_COUNT=',NHIST
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_DEVELOPMENT_HISTORY_COUNT=',NHIST
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_ZERO_HEAD_HISTORY_COUNT=',NHIST
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_STATE_COUNT=',total_states
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_DEVELOPMENT_STATE_COUNT=',NHIST*NSTEPS
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_ZERO_HEAD_STATE_COUNT=',NHIST*NSTEPS
""",
        """  history_filter_raw=''
  call get_environment_variable('B1HC_HISTORY_FILTER',history_filter_raw,status=env_status)
  if(env_status/=0)history_filter_raw=''

  total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;active_histories=0

  do ih=1,NHIST
    if(len_trim(history_filter_raw)==0.or.trim(history_label(ih))==trim(history_filter_raw))then
      call run_history(ih,total_states,total_fallbacks,max_abs_mass)
      active_histories=active_histories+1
    end if
  end do

  call require(active_histories>0,'F_ROMV2_D13_REF history filter selected at least one history')
  call require(total_states==active_histories*NSTEPS,'F_ROMV2_D13_REF exact library state count')
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_HISTORY_COUNT=',active_histories
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_DEVELOPMENT_HISTORY_COUNT=',active_histories
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_ZERO_HEAD_HISTORY_COUNT=',active_histories
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_STATE_COUNT=',total_states
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_DEVELOPMENT_STATE_COUNT=',active_histories*NSTEPS
  write(*,'(A,I0)') 'F_ROMV2_D13_REF_ZERO_HEAD_STATE_COUNT=',active_histories*NSTEPS
""",
        "history loop",
    )

    pat=re.compile(r"(?ms)^  subroutine metrics_from_physical\(physical,total,upper,lower\).*?^  end subroutine metrics_from_physical\n")
    found=pat.findall(text)
    if len(found)!=1:
        raise SystemExit(f"metrics block: expected one occurrence, found {len(found)}")
    replacement="""  subroutine metrics_from_physical(physical,total,upper,lower)
    type(fmr_b110_physical_state_t),intent(in) :: physical
    real(real64),intent(out) :: total,upper,lower
    real(real64) :: ztop,zbot,w
    integer :: node
    total=sum(physical%water_content(1:numnod)*dz(1:numnod))
    if(numnod==16)then
      upper=sum(physical%water_content(1:numnod/2)*dz(1:numnod/2))
      lower=sum(physical%water_content(numnod/2+1:numnod)*dz(numnod/2+1:numnod))
    else
      upper=0.0_real64;lower=0.0_real64;ztop=0.0_real64
      do node=1,numnod
        zbot=ztop+dz(node)
        w=max(0.0_real64,min(zbot,80.0_real64)-max(ztop,0.0_real64))
        upper=upper+physical%water_content(node)*w
        w=max(0.0_real64,min(zbot,160.0_real64)-max(ztop,80.0_real64))
        lower=lower+physical%water_content(node)*w
        ztop=zbot
      end do
    end if
    call require(ieee_is_finite(total).and.ieee_is_finite(upper).and.ieee_is_finite(lower),'F-ROMV2 D13 REF finite primary outputs')
  end subroutine metrics_from_physical
"""
    text=pat.sub(replacement,text,count=1)
    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.layer-rom.b1hc-q.harness-materialization.v1",
      "input_b1h_source_sha256":sha(a.b1h_source),
      "output_sha256":sha(a.output),
      "changes":[
        "allow frozen L4/L6/R8 and R16 control geometries",
        "optional B1HC_HISTORY_FILTER with unchanged unfiltered semantics",
        "geometric 0-80/80-160 diagnostics on nonuniform grids; R16 preserves original expression"
      ],
      "solver_or_physics_changed":False,
      "numerical_policy_changed":False,
      "boundary_semantics_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
