#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import tempfile

MAGIC=660062001

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def block(text:str,pattern:str,replacement:str,label:str)->str:
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1:
        raise SystemExit(f"{label}: expected one block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)

def run_history_block(start:int,end:int)->str:
    nsteps=end-start+1
    return f"""  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: state
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qeq,t0,t1,mass,bex,bflux,sub_t0,sub_t1,sub_dt
    real(real64) :: root_rate,cumulative_root,observation_root
    integer :: step,status,nl,ir,back,substep,revision_base
    character(len=96) :: route
    logical :: ok,fallback_used
    integer :: history_fallbacks
    real(real64) :: history_max_mass

    call initialize_parameters(p)
    call initialize_state(p,initial_se(ih),h0,k0,initial_state)
    qeq=-k0
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)

    p%bottom_mode=2
    p%root_extraction_active=.false.
    p%total_balance_tolerance=original_total_tol
    if(SEGMENT_START==1)then
      call fmr_new_b110_committed_state(state,column_id,initial_state,0.0_real64,ok)
      call require(ok.and.state%ready(),'LAREDYN0R C6R segmented initial committed state')
      call seed_steady(column,template,p,state,forcing,qeq,ok)
      call require(ok,'LAREDYN0R C6R segmented gravity-consistent seed')
      t0=real(seed_intervals,real64)*seed_dt
      revision_base=seed_intervals
    else
      call read_segment_checkpoint(initial_state,t0,ok)
      call require(ok,'LAREDYN0R C6R segmented checkpoint read')
      call fmr_new_b110_committed_state(state,column_id,initial_state,t0,ok)
      call require(ok.and.state%ready(),'LAREDYN0R C6R segmented restart committed state')
      revision_base=0
    end if

    history_fallbacks=0
    history_max_mass=0.0_real64
    cumulative_root=0.0_real64
    observation_root=0.0_real64
    sub_dt=step_dt/real(substeps,real64)

    do step=SEGMENT_START,SEGMENT_END
      call configure_case(ih,step,h0,k0,qeq,p,forcing)
      sub_t0=t0
      do substep=1,substeps
        if(substep==substeps)then
          sub_t1=real(seed_intervals,real64)*seed_dt+real(step,real64)*step_dt
        else
          sub_t1=sub_t0+sub_dt
        end if
        call evaluate_committed_root_sink(ih,p,state,forcing,root_rate)
        call strict_first_sample(column,template,p,state,forcing,sub_t0,sub_t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
        call require(ok,'LAREDYN0R C6R accepted segmented root-active step')
        call require(.not.fallback_used,'LAREDYN0R C6R segmented root-active fallback forbidden')
        call require(abs(mass)<=hard_mass_gate,'LAREDYN0R C6R segmented hard mass gate')
        call require(state%current_revision()==int(revision_base+(step-SEGMENT_START)*substeps+substep,int64), &
             'LAREDYN0R C6R segmented local revision progression')
        call require_current_time(state,sub_t1)
        cumulative_root=cumulative_root+root_rate*(sub_t1-sub_t0)
        observation_root=observation_root+root_rate*(sub_t1-sub_t0)
        history_max_mass=max(history_max_mass,abs(mass))
        max_abs_mass=max(max_abs_mass,abs(mass))
        sub_t0=sub_t1
      end do
      t1=sub_t1
      t0=t1
      total_states=total_states+1
      call emit_state(ih,step,state,forcing,t1-sub_dt,t1,mass,bex,bflux,nl,back,fallback_used)
      if(mod(step,OUTPUT_FACTOR)==0)then
        write(*,'(*(g0))') 'LAREDYN0R_ROOT|CASE=',trim(case_label(ih)),'|STEP=',step, &
             '|OBS_STEP=',step/OUTPUT_FACTOR,'|PTRA=',potential_transpiration(ih), &
             '|ACTUAL_RATE=',observation_root/0.0008_real64,'|ACTUAL_FRACTION=', &
             (observation_root/0.0008_real64)/potential_transpiration(ih), &
             '|CUMULATIVE_ROOT=',cumulative_root
        observation_root=0.0_real64
      end if
    end do

    call write_segment_checkpoint(state,t0,ok)
    call require(ok,'LAREDYN0R C6R segmented checkpoint write')
    write(*,'(*(g0))') 'LAREDYN0R_HISTORY_PASS|CASE=',trim(case_label(ih)),'|SE0=',initial_se(ih), &
         '|FORCING=',trim(forcing_label(forcing_kind(ih))),'|BOTTOM=',trim(bottom_label(bottom_kind(ih))), &
         '|STATES=',{nsteps},'|SUBSTEPS=',substeps,'|FALLBACKS=',history_fallbacks,'|MAX_ABS_MASS=',history_max_mass, &
         '|FINAL_REV=',state%current_revision(),'|FINAL_T=',t0,'|SEGMENT_START=',SEGMENT_START,'|SEGMENT_END=',SEGMENT_END
  end subroutine run_history
"""

def checkpoint_block()->str:
    return f"""  subroutine read_segment_checkpoint(physical_state,checkpoint_time,ok)
    type(fmr_b110_physical_state_t),intent(inout) :: physical_state
    real(real64),intent(out) :: checkpoint_time
    logical,intent(out) :: ok
    integer :: unit,ios,active
    integer(int64) :: magic
    real(real64) :: expected_time
    ok=.false.;checkpoint_time=0.0_real64
    if(len_trim(segment_checkpoint_in)==0)return
    open(newunit=unit,file=trim(segment_checkpoint_in),access='stream',form='unformatted',status='old',action='read',iostat=ios)
    if(ios/=0)return
    read(unit,iostat=ios)magic,active,checkpoint_time,physical_state%ponding_depth,physical_state%groundwater_level
    if(ios==0)read(unit,iostat=ios)physical_state%pressure_head
    if(ios==0)read(unit,iostat=ios)physical_state%water_content
    close(unit)
    if(ios/=0)return
    if(magic/={MAGIC}_int64.or.active/=numnod)return
    physical_state%active_nodes=active
    expected_time=real(seed_intervals,real64)*seed_dt+real(SEGMENT_START-1,real64)*step_dt
    if(.not.same_bits(checkpoint_time,expected_time))return
    if(.not.all(ieee_is_finite(physical_state%pressure_head)))return
    if(.not.all(ieee_is_finite(physical_state%water_content)))return
    if(.not.ieee_is_finite(physical_state%ponding_depth).or..not.ieee_is_finite(physical_state%groundwater_level))return
    ok=.true.
  end subroutine read_segment_checkpoint

  subroutine write_segment_checkpoint(state,checkpoint_time,ok)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(in) :: checkpoint_time
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: unit,ios
    integer(int64) :: magic
    ok=.false.
    if(len_trim(segment_checkpoint_out)==0)return
    call state%snapshot(snap,got)
    if(.not.got)return
    magic={MAGIC}_int64
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      open(newunit=unit,file=trim(segment_checkpoint_out),access='stream',form='unformatted',status='replace',action='write',iostat=ios)
      if(ios==0)write(unit,iostat=ios)magic,physical%active_nodes,checkpoint_time,physical%ponding_depth,physical%groundwater_level
      if(ios==0)write(unit,iostat=ios)physical%pressure_head
      if(ios==0)write(unit,iostat=ios)physical%water_content
      if(ios==0)close(unit)
      if(ios/=0)then
        if(unit>0)close(unit,iostat=ios)
      end if
      ok=ios==0
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine write_segment_checkpoint

"""

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--base-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--segment-start",required=True,type=int)
    ap.add_argument("--segment-end",required=True,type=int)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    if not (1<=a.segment_start<=a.segment_end<=32768):
        raise SystemExit("segment bounds outside C6R T32 route")

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c6r_full.f90"; bm=td/"base.json"
        subprocess.run([
          sys.executable,str(a.base_materializer),
          "--source",str(a.source),"--material",a.material,"--temporal-factor","32",
          "--output",str(base),"--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False or m.get("production_source_changed") is not False:
            raise SystemExit("C6R base materializer violates response-independent source lock")
        text=base.read_text()

    nsteps=a.segment_end-a.segment_start+1
    text=one(
      text,
      "integer, parameter :: NHIST=4, NSTEPS=32768\n  integer, parameter :: OUTPUT_FACTOR=32",
      f"integer, parameter :: NHIST=4, NSTEPS=32768\n  integer, parameter :: OUTPUT_FACTOR=32\n"
      f"  integer, parameter :: SEGMENT_START={a.segment_start}, SEGMENT_END={a.segment_end}, SEGMENT_STEPS={nsteps}",
      "segment constants"
    )
    text=one(
      text,
      "  character(len=32) :: substeps_raw\n",
      "  character(len=32) :: substeps_raw\n  character(len=512) :: segment_checkpoint_in,segment_checkpoint_out\n",
      "checkpoint declarations"
    )
    anchor="  total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;active_histories=0\n"
    setup="""  segment_checkpoint_in=''
  segment_checkpoint_out=''
  call get_environment_variable('C6R_CHECKPOINT_IN',segment_checkpoint_in,status=env_status)
  if(SEGMENT_START>1)call require(env_status==0.and.len_trim(segment_checkpoint_in)>0,'LAREDYN0R C6R checkpoint input path')
  call get_environment_variable('C6R_CHECKPOINT_OUT',segment_checkpoint_out,status=env_status)
  call require(env_status==0.and.len_trim(segment_checkpoint_out)>0,'LAREDYN0R C6R checkpoint output path')

"""
    text=one(text,anchor,setup+anchor,"checkpoint environment")
    text=one(
      text,
      "  call require(total_states==active_histories*NSTEPS,'LAREDYN0R exact library state count')",
      "  call require(total_states==active_histories*SEGMENT_STEPS,'LAREDYN0R C6R exact segmented state count')",
      "state count"
    )
    text=one(
      text,
      "  write(*,'(A,I0)') 'LAREDYN0R_STEPS_PER_HISTORY=',NSTEPS",
      "  write(*,'(A,I0)') 'LAREDYN0R_STEPS_PER_HISTORY=',SEGMENT_STEPS\n"
      "  write(*,'(A,I0)') 'LAREDYN0R_SEGMENT_START=',SEGMENT_START\n"
      "  write(*,'(A,I0)') 'LAREDYN0R_SEGMENT_END=',SEGMENT_END",
      "summary"
    )
    text=block(
      text,
      r"^  subroutine run_history\(ih,total_states,total_fallbacks,max_abs_mass\).*?^  end subroutine run_history\n",
      run_history_block(a.segment_start,a.segment_end),
      "segmented root run history"
    )
    text=one(
      text,
      "  pure real(real64) function pressure_head_from_se(p,se) result(h)\n",
      checkpoint_block()+"  pure real(real64) function pressure_head_from_se(p,se) result(h)\n",
      "checkpoint helpers"
    )
    text=one(
      text,
      "  write(*,'(A)') 'LAREDYN0R_C6R_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'",
      "  write(*,'(A)') 'LAREDYN0R_C6R_SEGMENTED_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\n"
      "  write(*,'(A)') 'LAREDYN0R_C6R_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'",
      "segmented marker"
    )

    a.output.write_text(text)
    out={
      "schema":"swap5.lare.bc2.c6r.segmented-reference-materialization.v1",
      "base_materializer_sha256":sha256(a.base_materializer),
      "source_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "material":a.material,
      "temporal_factor":32,
      "transaction_dt_day":0.000025,
      "segment_start":a.segment_start,
      "segment_end":a.segment_end,
      "segment_steps":nsteps,
      "checkpoint_payload":"exact fmr_b110_physical_state_t plus committed time",
      "root_sink_persisted":False,
      "root_sink_recomputed_from_committed_state":True,
      "root_interval_output_is_segment_composable":True,
      "solver_or_physics_changed":False,
      "retry_policy_extended":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
