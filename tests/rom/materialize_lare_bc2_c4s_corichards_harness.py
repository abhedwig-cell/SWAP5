#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re, hashlib, json

def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--blind-source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.blind_source.read_text(encoding="utf-8")

    old="call require(any(numnod==[2,16]),'F_ROMV2_D13_REF geometry is R2 or R16')"
    new="call require(any(numnod==[2,3,4,5,6,8,12,16]),'F_ROMV2_D13_REF geometry is frozen C4S member')"
    if text.count(old)!=1:
        raise SystemExit("C4S geometry guard source mismatch")
    text=text.replace(old,new,1)

    old_decl="""  integer :: ih,total_states,total_fallbacks
  real(real64) :: max_abs_mass
"""
    new_decl="""  integer :: ih,total_states,total_fallbacks,active_histories,env_status
  real(real64) :: max_abs_mass
  character(len=16) :: history_filter_raw
"""
    if text.count(old_decl)!=1:
        raise SystemExit("C4S declaration source mismatch")
    text=text.replace(old_decl,new_decl,1)

    old_loop="""  total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64

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
"""
    new_loop="""  history_filter_raw=''
  call get_environment_variable('C4S_HISTORY_FILTER',history_filter_raw,status=env_status)
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
"""
    if text.count(old_loop)!=1:
        raise SystemExit("C4S history loop source mismatch")
    text=text.replace(old_loop,new_loop,1)

    pat=re.compile(r"(?ms)^  subroutine metrics_from_physical\(physical,total,upper,lower\).*?^  end subroutine metrics_from_physical\n")
    found=pat.findall(text)
    if len(found)!=1:
        raise SystemExit(f"C4S metrics block source mismatch {len(found)}")
    replacement="""  subroutine metrics_from_physical(physical,total,upper,lower)
    type(fmr_b110_physical_state_t),intent(in) :: physical
    real(real64),intent(out) :: total,upper,lower
    real(real64) :: ztop,zbot,w
    integer :: node
    total=sum(physical%water_content(1:numnod)*dz(1:numnod))
    if(numnod==2.or.numnod==16)then
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
    manifest={
      "schema":"swap5.lare.bc2.c4s.harness-materialization.v1",
      "blind_source_sha256":sha(a.blind_source),
      "output_sha256":sha(a.output),
      "changes":[
        "allow frozen C4S grid dimensions",
        "optional C4S_HISTORY_FILTER with unchanged unfiltered semantics",
        "geometric 0-80/80-160 diagnostics on nonuniform grids; R2/R16 preserve original expression"
      ],
      "solver_or_physics_changed":False,
      "numerical_policy_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))

if __name__=="__main__":
    main()
