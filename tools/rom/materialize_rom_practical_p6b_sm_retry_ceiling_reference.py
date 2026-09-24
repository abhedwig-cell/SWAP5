#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--max-step-day",required=True,type=float,choices=(0.03125,0.015625))
    ap.add_argument("--max-retries",required=True,type=int,choices=(12,16))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    t=a.source.read_text()
    t=t.replace("integer, parameter :: NHIST=2, NSTEPS=1920\n  integer, parameter :: OUTPUT_FACTOR=32",
                "integer, parameter :: NHIST=2, NSTEPS=60\n  integer, parameter :: OUTPUT_FACTOR=1",1)
    t=t.replace("real(real64), parameter :: step_dt=0.03125_real64",
                "real(real64), parameter :: step_dt=1.0_real64",1)
    anchor="  integer(int64), parameter :: column_id=971001_int64\n"
    extra=(f"  real(real64), parameter :: RNP03_MAX_STEP={a.max_step_day:.17e}_real64\n"
           "  real(real64), parameter :: RNP03_RETRY_SCALE=0.5_real64\n"
           f"  integer, parameter :: RNP03_MAX_RETRIES={a.max_retries}\n")
    if anchor not in t: raise SystemExit("parameter anchor missing")
    t=t.replace(anchor,anchor+extra,1)

    pat=re.compile(r"^  subroutine run_history\(ih,total_states,total_fallbacks,max_abs_mass\).*?^  end subroutine run_history\n",re.M|re.S)
    repl=r'''  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: state
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qeq,t0,t1,mass,bex,bflux
    real(real64) :: cursor,target,attempt_t1,attempt_dt,day_mass,day_bex,day_bflux
    integer :: step,status,nl,ir,back,retry,accepted_substeps
    character(len=96) :: route
    logical :: ok
    integer :: history_retries,history_substeps
    real(real64) :: history_max_mass

    call initialize_parameters(p)
    call initialize_state(p,initial_se(ih),h0,k0,initial_state)
    qeq=-k0
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(state,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.state%ready(),'RNP03 initial committed state')

    p%bottom_mode=2
    p%total_balance_tolerance=original_total_tol
    call seed_steady(column,template,p,state,forcing,qeq,ok)
    call require(ok,'RNP03 gravity-consistent seed')

    t0=real(seed_intervals,real64)*seed_dt
    history_retries=0;history_substeps=0;history_max_mass=0.0_real64

    do step=1,NSTEPS
      call configure_case(ih,step,h0,k0,qeq,p,forcing)
      cursor=t0
      target=real(seed_intervals,real64)*seed_dt+real(step,real64)*step_dt
      day_mass=0.0_real64;day_bex=0.0_real64;day_bflux=0.0_real64;accepted_substeps=0
      do while(cursor < target-1.0e-14_real64)
        attempt_dt=min(RNP03_MAX_STEP,target-cursor)
        retry=0
        do
          attempt_t1=cursor+attempt_dt
          if(attempt_t1>target)attempt_t1=target
          call sample_fresh(column,template,p,state,forcing,cursor,attempt_t1,ok,mass,bex,bflux,status,route,nl,ir,back)
          if(ok)exit
          retry=retry+1;history_retries=history_retries+1;total_fallbacks=total_fallbacks+1
          call require(retry<=RNP03_MAX_RETRIES,'RNP03 retry budget')
          attempt_dt=attempt_dt*RNP03_RETRY_SCALE
          call require(attempt_dt>=p%min_step_duration,'RNP03 minimum step')
        end do
        call require(abs(mass)<=hard_mass_gate,'RNP03 hard mass gate')
        cursor=attempt_t1
        call require_current_time(state,cursor)
        accepted_substeps=accepted_substeps+1;history_substeps=history_substeps+1
        day_mass=day_mass+mass;day_bex=day_bex+bex;day_bflux=bflux
        history_max_mass=max(history_max_mass,abs(mass));max_abs_mass=max(max_abs_mass,abs(mass))
      end do
      t1=cursor;t0=t1
      total_states=total_states+1
      call emit_state(ih,step,state,forcing,t1-min(RNP03_MAX_STEP,step_dt),t1,day_mass,day_bex,day_bflux,nl,back,.false.)
      write(*,'(*(g0))') 'RNP03_DAY|CASE=',trim(case_label(ih)),'|DAY=',step,'|ACCEPTED_SUBSTEPS=',accepted_substeps, &
           '|CUM_RETRIES=',history_retries,'|T=',t1
    end do

    write(*,'(*(g0))') 'LAREDYN0R_HISTORY_PASS|CASE=',trim(case_label(ih)),'|SE0=',initial_se(ih), &
         '|FORCING=HUPSEL_NET_ATMOS_PROXY|BOTTOM=',trim(bottom_label(bottom_kind(ih))), &
         '|STATES=',NSTEPS,'|SUBSTEPS=',history_substeps,'|FALLBACKS=',history_retries,'|MAX_ABS_MASS=',history_max_mass, &
         '|FINAL_REV=',state%current_revision(),'|FINAL_T=',t0
  end subroutine run_history
'''
    t,n=pat.subn(repl,t,count=1)
    if n!=1: raise SystemExit(f"run_history replacement found {n}")
    t=t.replace("call require(total_states==active_histories*NSTEPS,'LAREDYN0R exact library state count')",
                "call require(total_states==active_histories*NSTEPS,'RNP03 exact daily state count')",1)
    t=t.replace("  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
                "  write(*,'(A)') 'RNP03_ADAPTIVE_REFERENCE=PASS'\n  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",1)
    a.output.write_text(t)
    print(f"ROM_PRACTICAL_P6B_RNP03_MAX_STEP={a.max_step_day}|MAX_RETRIES={a.max_retries}")
if __name__=="__main__": main()
