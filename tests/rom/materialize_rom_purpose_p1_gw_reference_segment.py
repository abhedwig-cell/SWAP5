#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

MAGIC=560061001

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
    real(real64) :: h0,k0,qeq,t0,t1,mass,bex,bflux
    integer :: step,symbol,status,nl,ir,back,revision_base
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
    p%total_balance_tolerance=original_total_tol
    if(SEGMENT_START==1)then
      call fmr_new_b110_committed_state(state,column_id,initial_state,0.0_real64,ok)
      call require(ok.and.state%ready(),'LAREGW1 ROMPURP_P1 segmented initial committed state')
      call seed_steady(column,template,p,state,forcing,qeq,ok)
      call require(ok,'LAREGW1 ROMPURP_P1 segmented gravity-consistent seed')
      t0=real(seed_intervals,real64)*seed_dt
      revision_base=seed_intervals
    else
      call read_segment_checkpoint(initial_state,t0,ok)
      call require(ok,'LAREGW1 ROMPURP_P1 segmented checkpoint read')
      call fmr_new_b110_committed_state(state,column_id,initial_state,t0,ok)
      call require(ok.and.state%ready(),'LAREGW1 ROMPURP_P1 segmented restart committed state')
      revision_base=0
    end if

    history_fallbacks=0
    history_max_mass=0.0_real64

    do step=SEGMENT_START,SEGMENT_END
      symbol=history_symbol(ih,step)
      call configure_symbol(symbol,h0,k0,qeq,p,forcing)
      t1=real(seed_intervals,real64)*seed_dt+real(step,real64)*step_dt
      call strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
      call require(ok,'LAREGW1 ROMPURP_P1 accepted segmented history step')
      call require(abs(mass)<=hard_mass_gate,'LAREGW1 ROMPURP_P1 segmented hard mass gate')
      call require(state%current_revision()==int(revision_base+(step-SEGMENT_START)+1,int64), &
           'LAREGW1 ROMPURP_P1 segmented exact local revision progression')
      call require_current_time(state,t1)
      history_max_mass=max(history_max_mass,abs(mass))
      max_abs_mass=max(max_abs_mass,abs(mass))
      if(fallback_used)then
        history_fallbacks=history_fallbacks+1
        total_fallbacks=total_fallbacks+1
      end if
      total_states=total_states+1
      call emit_state(ih,step,symbol,state,forcing,t0,t1,mass,bex,bflux,nl,back,fallback_used)
      t0=t1
    end do

    call write_segment_checkpoint(state,t0,ok)
    call require(ok,'LAREGW1 ROMPURP_P1 segmented checkpoint write')
    write(*,'(*(g0))') 'LAREGW1_HISTORY_PASS|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
         '|STATES=',{nsteps},'|FALLBACKS=',history_fallbacks,'|MAX_ABS_MASS=',history_max_mass, &
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
      ok=ios==0
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine write_segment_checkpoint

"""

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--slice-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--base-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--history-index",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--segment-start",required=True,type=int)
    ap.add_argument("--segment-end",required=True,type=int)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    total_steps=1024*a.temporal_factor
    if not (1<=a.segment_start<=a.segment_end<=total_steps):
        raise SystemExit("segment bounds outside P1 GW route")

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"p1_gw_single.f90"; manifest=td/"base.json"
        subprocess.run([
          sys.executable,str(a.slice_materializer),
          "--base-materializer",str(a.base_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--material",a.material,
          "--temporal-factor",str(a.temporal_factor),
          "--history-index",str(a.history_index),
          "--output",str(base),"--manifest",str(manifest)
        ],check=True)
        bm=json.loads(manifest.read_text())
        if bm.get("response_based") is not False:
            raise SystemExit("P1 GW slice materializer is not response-independent")
        text=base.read_text()

    nsteps=a.segment_end-a.segment_start+1
    base_constants=f"integer, parameter :: NHIST=4, NSTEPS={total_steps}\n  integer, parameter :: OUTPUT_FACTOR={a.temporal_factor}"
    text=one(
      text,base_constants,
      base_constants+f"\n  integer, parameter :: SEGMENT_START={a.segment_start}, SEGMENT_END={a.segment_end}, SEGMENT_STEPS={nsteps}",
      "segment constants")
    text=one(
      text,
      "  integer :: ih,total_states,total_fallbacks\n  real(real64) :: max_abs_mass\n",
      "  integer :: ih,total_states,total_fallbacks,env_status\n  real(real64) :: max_abs_mass\n  character(len=512) :: segment_checkpoint_in,segment_checkpoint_out\n",
      "checkpoint declarations")
    anchor="  total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64\n"
    setup="""  segment_checkpoint_in=''
  segment_checkpoint_out=''
  call get_environment_variable('ROMPURP_P1_CHECKPOINT_IN',segment_checkpoint_in,status=env_status)
  if(SEGMENT_START>1)call require(env_status==0.and.len_trim(segment_checkpoint_in)>0,'LAREGW1 ROMPURP_P1 segmented checkpoint input path')
  call get_environment_variable('ROMPURP_P1_CHECKPOINT_OUT',segment_checkpoint_out,status=env_status)
  call require(env_status==0.and.len_trim(segment_checkpoint_out)>0,'LAREGW1 ROMPURP_P1 segmented checkpoint output path')

"""
    text=one(text,anchor,setup+anchor,"checkpoint environment")
    text=one(
      text,
      "  call require(total_states==NSTEPS,'LAREGW1 exact P1 sliced history state count')",
      "  call require(total_states==SEGMENT_STEPS,'LAREGW1 exact P1 segmented history state count')",
      "segmented state count")
    text=one(
      text,
      "  write(*,'(A,I0)') 'LAREGW1_STEPS_PER_HISTORY=',NSTEPS",
      "  write(*,'(A,I0)') 'LAREGW1_STEPS_PER_HISTORY=',SEGMENT_STEPS\n"
      "  write(*,'(A,I0)') 'LAREGW1_SEGMENT_START=',SEGMENT_START\n"
      "  write(*,'(A,I0)') 'LAREGW1_SEGMENT_END=',SEGMENT_END",
      "segmented summary")
    text=block(
      text,
      r"^  subroutine run_history\(ih,total_states,total_fallbacks,max_abs_mass\).*?^  end subroutine run_history\n",
      run_history_block(a.segment_start,a.segment_end),
      "run_history segmentation")
    text=one(
      text,
      "  subroutine strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)\n",
      checkpoint_block()+"  subroutine strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)\n",
      "checkpoint helpers")
    text=one(
      text,
      "  write(*,'(A)') 'LAREGW1_ROMPURP_P1_GW_REFERENCE_GENERATED=TRUE'",
      "  write(*,'(A)') 'LAREGW1_ROMPURP_P1_SEGMENTED_GW_REFERENCE_GENERATED=TRUE'\n"
      "  write(*,'(A)') 'LAREGW1_ROMPURP_P1_GW_REFERENCE_GENERATED=TRUE'",
      "segmented marker")

    a.output.write_text(text)
    out={
      "schema":"swap5.rom-purpose.p1.segmented-gw-reference-materialization.v1",
      "slice_materializer_sha256":sha256(a.slice_materializer),
      "base_materializer_sha256":sha256(a.base_materializer),
      "source_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "material":a.material,
      "history_index":a.history_index,
      "history_label":f"G{a.history_index:02d}",
      "temporal_factor":a.temporal_factor,
      "transaction_dt_day":0.0008/a.temporal_factor,
      "segment_start":a.segment_start,
      "segment_end":a.segment_end,
      "segment_steps":nsteps,
      "checkpoint_payload":"exact fmr_b110_physical_state_t plus committed time in unformatted stream",
      "numerical_continuation_layout":"NONE",
      "solver_or_physics_changed":False,
      "forcing_changed":False,
      "retry_policy_changed":False,
      "scientific_output_fields_changed":False,
      "revision_counter_is_local_to_restart_segment":True,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
