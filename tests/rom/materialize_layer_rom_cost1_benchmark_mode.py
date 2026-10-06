#!/usr/bin/env python3
from __future__ import annotations
import argparse,hashlib,json,pathlib,re

def sha(p:pathlib.Path)->str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def replace_once(text,old,new,label):
    n=text.count(old)
    if n!=1: raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    text=a.source.read_text(encoding="utf-8")

    # Add benchmark-only variables immediately before the first executable statement.
    marker="  call require("
    pos=text.find(marker)
    if pos<0: raise SystemExit("main executable marker not found")
    extra="""  integer :: cost1_repeats,cost1_rep,cost1_ih
  real(real64) :: cost1_cpu0,cost1_cpu1,cost1_checksum,cost1_total_checksum,cost1_mass
  character(len=32) :: cost1_arg1,cost1_arg2,cost1_route
  logical :: cost1_benchmark_mode

"""
    text=text[:pos]+extra+text[pos:]

    sig_old="""  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass
"""
    sig_new="""  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass,cost1_emit,cost1_checksum_out)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass,cost1_checksum_out
    logical,intent(in) :: cost1_emit
"""
    text=replace_once(text,sig_old,sig_new,"run_history signature")

    emit="      call emit_state(ih,step,symbol,state,forcing,t0,t1,mass,bex,bflux,nl,back,fallback_used)"
    text=replace_once(text,emit,"      if(cost1_emit) "+emit.strip(),"emit_state")

    hist_write=re.compile(
      r"(?ms)    write\(\*,'\(\*\(g0\)\)'\) 'F_ROMV2_D13_REF_HISTORY_PASS\|SPLIT=',trim\(split_label\(ih\)\),'\|HISTORY=',trim\(history_label\(ih\)\), &\n"
      r".*?    .*?'\|FINAL_REV=',state%current_revision\(\),'\|FINAL_T=',t0\n"
    )
    found=hist_write.findall(text)
    if len(found)!=1: raise SystemExit(f"history write block count {len(found)}")
    old=found[0]
    new="""    if(cost1_emit)then
"""+old+"""    else
      cost1_checksum_out=cost1_checksum_out+mass+bex+bflux+t0+real(history_fallbacks,real64)+real(state%current_revision(),real64)
    end if
"""
    text=text.replace(old,new,1)

    contains=text.find("\ncontains\n")
    if contains<0: raise SystemExit("contains marker missing")
    # Find the first executable statement again after inserted declarations.
    start=text.find(marker)
    validation=text[start:contains]
    validation=validation.replace(
      "call run_history(ih,total_states,total_fallbacks,max_abs_mass)",
      "call run_history(ih,total_states,total_fallbacks,max_abs_mass,.true.,cost1_checksum)"
    )
    if "call run_history(ih,total_states,total_fallbacks,max_abs_mass)" in validation:
        raise SystemExit("validation call replacement incomplete")

    mainblock="""  cost1_benchmark_mode=.false.;cost1_repeats=1;cost1_arg1='';cost1_arg2='';cost1_route=''
  call get_command_argument(1,cost1_arg1)
  if(trim(cost1_arg1)=='bench')then
    cost1_benchmark_mode=.true.
    call get_command_argument(2,cost1_arg2);read(cost1_arg2,*)cost1_repeats
    call get_command_argument(3,cost1_route)
    call require(cost1_repeats>=1,'LAYER_ROM_COST1 positive repeats')
    call require(len_trim(cost1_route)>0,'LAYER_ROM_COST1 route id')
  end if

  if(cost1_benchmark_mode)then
    cost1_total_checksum=0.0_real64
    call cpu_time(cost1_cpu0)
    do cost1_rep=1,cost1_repeats
      total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;cost1_checksum=0.0_real64
      do cost1_ih=1,NHIST
        call run_history(cost1_ih,total_states,total_fallbacks,max_abs_mass,.false.,cost1_checksum)
      end do
      call require(total_states==NHIST*NSTEPS,'LAYER_ROM_COST1 benchmark state count')
      cost1_total_checksum=cost1_total_checksum+cost1_checksum
    end do
    call cpu_time(cost1_cpu1)
    write(*,'(*(g0))') 'LAYER_ROM_COST1_BENCH|ROUTE=',trim(cost1_route),'|REPEATS=',cost1_repeats, &
         '|CPU_SECONDS=',cost1_cpu1-cost1_cpu0,'|CHECKSUM=',cost1_total_checksum
  else
    cost1_checksum=0.0_real64
"""+validation+"""  end if
"""
    text=text[:start]+mainblock+text[contains:]
    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.layer-rom.cost1.benchmark-mode-materialization.v1",
      "source_sha256":sha(a.source),"output_sha256":sha(a.output),
      "changes":[
        "add benchmark command mode with in-process CPU_TIME over all four histories",
        "suppress state/history scientific serialization only in benchmark mode",
        "retain original validation-mode executable block and history filtering",
        "add deterministic benchmark checksum"
      ],
      "solver_or_physics_changed":False,"numerical_policy_changed":False,
      "validation_semantics_changed":False,"production_rom_authorized":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))

if __name__=="__main__":
    main()
