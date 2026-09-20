#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib

def sha(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.source.read_text(encoding="utf-8")

    decl="""  real(real64) :: max_abs_mass
"""
    repl="""  real(real64) :: max_abs_mass
  integer :: cost_repeats,cost_rep
  real(real64) :: cost_checksum,cost_total_checksum,cost_cpu0,cost_cpu1
  character(len=32) :: cost_arg1,cost_arg2,cost_route
  logical :: cost_benchmark_mode
"""
    text=replace_once(text,decl,repl,"benchmark declarations")

    marker="  call require(any(numnod==[4,6,8,16]),'F_ROMV2_D13_REF geometry is frozen B1HC-Q member')\n"
    if text.count(marker)!=1:
        raise SystemExit("COST1 requires B1HC-Q benchmark source structure")
    start=text.index(marker)
    end_marker="  write(*,'(A)') 'F_ROMV2_D13_REF_EXECUTION_COMPLETE=PASS'\n"
    end=text.index(end_marker,start)+len(end_marker)
    validation=text[start:end]

    validation=validation.replace(
        "call run_history(ih,total_states,total_fallbacks,max_abs_mass)",
        "call run_history(ih,total_states,total_fallbacks,max_abs_mass,.true.,cost_checksum)"
    )
    validation=validation.replace(
        "total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;active_histories=0",
        "total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;active_histories=0;cost_checksum=0.0_real64"
    )

    mainblock="""  cost_benchmark_mode=.false.;cost_repeats=1;cost_arg1='';cost_arg2='';cost_route=''
  call get_command_argument(1,cost_arg1)
  if(trim(cost_arg1)=='bench')then
    cost_benchmark_mode=.true.
    call get_command_argument(2,cost_arg2);read(cost_arg2,*)cost_repeats
    call get_command_argument(3,cost_route)
    call require(cost_repeats>=1,'LAYER_ROM_COST1 positive benchmark repeats')
    call require(len_trim(cost_route)>0,'LAYER_ROM_COST1 benchmark route id')
  end if

  if(cost_benchmark_mode)then
    call require(any(numnod==[4,6,8,16]),'F_ROMV2_D13_REF geometry is frozen COST1 route')
    call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'F_ROMV2_D13_REF depth frozen')
    cost_total_checksum=0.0_real64
    call cpu_time(cost_cpu0)
    do cost_rep=1,cost_repeats
      total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;cost_checksum=0.0_real64
      do ih=1,NHIST
        call run_history(ih,total_states,total_fallbacks,max_abs_mass,.false.,cost_checksum)
      end do
      call require(total_states==NHIST*NSTEPS,'LAYER_ROM_COST1 benchmark exact state count')
      cost_total_checksum=cost_total_checksum+cost_checksum
    end do
    call cpu_time(cost_cpu1)
    write(*,'(*(g0))') 'LAYER_ROM_COST1_BENCH|ROUTE=',trim(cost_route),'|REPEATS=',cost_repeats, &
         '|CPU_SECONDS=',cost_cpu1-cost_cpu0,'|CHECKSUM=',cost_total_checksum
  else
"""+validation+"""  end if
"""
    text=text[:start]+mainblock+text[end:]

    oldsig="""  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass
"""
    newsig="""  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass,emit,cost_checksum)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass,cost_checksum
    logical,intent(in) :: emit
"""
    text=replace_once(text,oldsig,newsig,"run_history signature")

    emitline="      call emit_state(ih,step,symbol,state,forcing,t0,t1,mass,bex,bflux,nl,back,fallback_used)"
    text=replace_once(text,emitline,"      if(emit)"+emitline.strip(),"emit_state call")

    oldwrite="""    write(*,'(*(g0))') 'F_ROMV2_D13_REF_HISTORY_PASS|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
         '|LAMBDA=',history_lambda(ih),'|STATES=',NSTEPS,'|FALLBACKS=',history_fallbacks,'|MAX_ABS_MASS=',history_max_mass, &
         '|FINAL_REV=',state%current_revision(),'|FINAL_T=',t0
  end subroutine run_history
"""
    newwrite="""    if(emit)then
      write(*,'(*(g0))') 'F_ROMV2_D13_REF_HISTORY_PASS|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
           '|LAMBDA=',history_lambda(ih),'|STATES=',NSTEPS,'|FALLBACKS=',history_fallbacks,'|MAX_ABS_MASS=',history_max_mass, &
           '|FINAL_REV=',state%current_revision(),'|FINAL_T=',t0
    else
      cost_checksum=cost_checksum+mass+bex+bflux+t0+real(history_fallbacks,real64)+real(state%current_revision(),real64)
    end if
  end subroutine run_history
"""
    text=replace_once(text,oldwrite,newwrite,"history pass block")

    a.output.write_text(text,encoding="utf-8")
    manifest={
      "schema":"swap5.layer-rom.cost1.richards-benchmark-materialization.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-COST1",
      "source_sha256":sha(a.source),"output_sha256":sha(a.output),
      "changes":[
        "add benchmark command mode with in-process CPU_TIME",
        "suppress scientific serialization only in benchmark mode",
        "add deterministic benchmark checksum",
        "validation mode preserves original scientific serialization"
      ],
      "solver_or_physics_changed":False,
      "numerical_policy_changed":False,
      "validation_semantics_changed":False,
      "production_rom_authorized":False
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
