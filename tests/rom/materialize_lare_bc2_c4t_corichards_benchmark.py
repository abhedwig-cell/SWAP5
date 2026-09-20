#!/usr/bin/env python3
from __future__ import annotations
import argparse,pathlib,re,hashlib,json

def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.source.read_text(encoding="utf-8")

    old="""  integer :: ih,total_states,total_fallbacks,active_histories,env_status
  real(real64) :: max_abs_mass
  character(len=16) :: history_filter_raw
"""
    new="""  integer :: ih,total_states,total_fallbacks,active_histories,env_status,repeats,rep
  real(real64) :: max_abs_mass,bench_checksum,total_checksum,cpu0,cpu1
  character(len=16) :: history_filter_raw
  character(len=32) :: arg1,arg2,route_id
  logical :: benchmark_mode
"""
    if text.count(old)!=1: raise SystemExit("declaration mismatch")
    text=text.replace(old,new,1)

    start=text.index("  call require(any(numnod==[2,3,4,5,6,8,12,16])")
    end_marker="  write(*,'(A)') 'F_ROMV2_D13_REF_EXECUTION_COMPLETE=PASS'\n"
    end=text.index(end_marker,start)+len(end_marker)
    validation=text[start:end]
    validation=validation.replace(
      "call run_history(ih,total_states,total_fallbacks,max_abs_mass)",
      "call run_history(ih,total_states,total_fallbacks,max_abs_mass,.true.,bench_checksum)"
    )
    validation=validation.replace(
      "total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;active_histories=0",
      "total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;active_histories=0;bench_checksum=0.0_real64"
    )
    mainblock="""  benchmark_mode=.false.;repeats=1;arg1='';arg2='';route_id=''
  call get_command_argument(1,arg1)
  if(trim(arg1)=='bench')then
    benchmark_mode=.true.
    call get_command_argument(2,arg2);read(arg2,*)repeats
    call get_command_argument(3,route_id)
    call require(repeats>=1,'LARE_BC2_C4T positive benchmark repeats')
    call require(len_trim(route_id)>0,'LARE_BC2_C4T benchmark route id')
  end if

  if(benchmark_mode)then
    call require(any(numnod==[2,3,4,5,6,8,12,16]),'F_ROMV2_D13_REF geometry is frozen C4S member')
    call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'F_ROMV2_D13_REF depth frozen')
    total_checksum=0.0_real64
    call cpu_time(cpu0)
    do rep=1,repeats
      total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;bench_checksum=0.0_real64
      do ih=1,NHIST
        call run_history(ih,total_states,total_fallbacks,max_abs_mass,.false.,bench_checksum)
      end do
      call require(total_states==NHIST*NSTEPS,'LARE_BC2_C4T benchmark exact state count')
      total_checksum=total_checksum+bench_checksum
    end do
    call cpu_time(cpu1)
    write(*,'(*(g0))') 'LARE_BC2_C4T_BENCH|ROUTE=',trim(route_id),'|REPEATS=',repeats, &
         '|CPU_SECONDS=',cpu1-cpu0,'|CHECKSUM=',total_checksum
  else
"""+validation+"""  end if
"""
    text=text[:start]+mainblock+text[end:]

    oldsig="""  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass
"""
    newsig="""  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass,emit,bench_checksum)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass,bench_checksum
    logical,intent(in) :: emit
"""
    if text.count(oldsig)!=1: raise SystemExit("run_history signature mismatch")
    text=text.replace(oldsig,newsig,1)

    emitline="      call emit_state(ih,step,symbol,state,forcing,t0,t1,mass,bex,bflux,nl,back,fallback_used)"
    if text.count(emitline)!=1: raise SystemExit("emit_state call mismatch")
    text=text.replace(emitline,"      if(emit)"+emitline.strip(),1)

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
      bench_checksum=bench_checksum+mass+bex+bflux+t0+real(history_fallbacks,real64)+real(state%current_revision(),real64)
    end if
  end subroutine run_history
"""
    if text.count(oldwrite)!=1: raise SystemExit("history pass block mismatch")
    text=text.replace(oldwrite,newwrite,1)

    a.output.write_text(text,encoding="utf-8")
    manifest={
      "schema":"swap5.lare.bc2.c4t.corichards-benchmark-materialization.v1",
      "source_sha256":sha(a.source),"output_sha256":sha(a.output),
      "changes":[
        "add benchmark command mode with in-process CPU_TIME",
        "suppress scientific serialization only in benchmark mode",
        "add deterministic benchmark checksum",
        "validation mode preserves original scientific serialization"
      ],
      "solver_or_physics_changed":False,
      "numerical_policy_changed":False,
      "validation_semantics_changed":False
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
if __name__=="__main__":main()
