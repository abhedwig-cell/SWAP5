#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text,old,new,label):
    n=text.count(old)
    if n!=1: raise SystemExit(f"{label}: expected 1 match, found {n}")
    return text.replace(old,new,1)

def block(text,pattern,replacement,label):
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1: raise SystemExit(f"{label}: expected 1 block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    t=a.source.read_text(encoding="utf-8")

    t=one(t,"integer, parameter :: NHIST=6, NSTEPS=1024",
          "integer, parameter :: NHIST=4, NSTEPS=1024","history count")
    t=one(t,"call require(numnod==16,'LAREGW1 geometry frozen at 16 nodes')",
          "call require(any(numnod==[2,16]),'LAREGW1 C4Z geometry is R2 or R16')","geometry")

    metrics="""  subroutine metrics_from_physical(physical,total,upper,lower)
    type(fmr_b110_physical_state_t),intent(in) :: physical
    real(real64),intent(out) :: total,upper,lower
    real(real64) :: ztop,zbot,w
    integer :: node
    total=sum(physical%water_content(1:numnod)*dz(1:numnod))
    upper=0.0_real64;lower=0.0_real64;ztop=0.0_real64
    do node=1,numnod
      zbot=ztop+dz(node)
      w=max(0.0_real64,min(zbot,80.0_real64)-max(ztop,0.0_real64))
      upper=upper+physical%water_content(node)*w
      w=max(0.0_real64,min(zbot,160.0_real64)-max(ztop,80.0_real64))
      lower=lower+physical%water_content(node)*w
      ztop=zbot
    end do
    call require(ieee_is_finite(total).and.ieee_is_finite(upper).and.ieee_is_finite(lower),'LAREGW1 finite primary outputs')
  end subroutine metrics_from_physical
"""
    t=block(t,r"^  subroutine metrics_from_physical\(physical,total,upper,lower\).*?^  end subroutine metrics_from_physical\n",metrics,"metrics")

    initial="""  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.725_real64
    case(2); value=0.825_real64
    case(3); value=0.875_real64
    case(4); value=0.775_real64
    case default; value=-1.0_real64
    end select
  end function initial_se
"""
    t=block(t,r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",initial,"initial se")

    symbols="""  integer function history_symbol(ih,step) result(symbol)
    integer,intent(in) :: ih,step
    select case(ih)
    case(1)
      if(step<=256)then; symbol=SYM_FALL
      else if(step<=576)then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(2)
      if(step<=256)then; symbol=SYM_RISE
      else if(step<=576)then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case(3)
      if(step<=320)then; symbol=SYM_FALL
      else if(step<=576)then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(4)
      if(step<=320)then; symbol=SYM_RISE
      else if(step<=576)then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case default
      symbol=0
    end select
    call require(symbol==SYM_HOLD.or.symbol==SYM_RISE.or.symbol==SYM_FALL,'LAREGW1 C4Z valid boundary-only symbol')
  end function history_symbol
"""
    t=block(t,r"^  integer function history_symbol\(ih,step\) result\(symbol\).*?^  end function history_symbol\n",symbols,"history symbols")

    labels="""  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=3) :: label
    select case(ih)
    case(1); label='Z01'
    case(2); label='Z02'
    case(3); label='Z03'
    case(4); label='Z04'
    case default; label='BAD'
    end select
  end function history_label
"""
    t=block(t,r"^  function history_label\(ih\) result\(label\).*?^  end function history_label\n",labels,"history labels")

    split="""  pure function split_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=9) :: label
    if(ih>=1.and.ih<=NHIST)then
      label='C4Z_BLIND'
    else
      label='INVALID  '
    end if
  end function split_label
"""
    t=block(t,r"^  pure function split_label\(ih\) result\(label\).*?^  end function split_label\n",split,"split label")

    t=one(t,
      "case(SYM_RISE)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=0.75_real64*h0\n"
      "    case(SYM_FALL)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=1.25_real64*h0",
      "case(SYM_RISE)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=0.875_real64*h0\n"
      "    case(SYM_FALL)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=1.125_real64*h0",
      "head multipliers")

    strict="""  subroutine strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(inout) :: p
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok,fallback_used
    real(real64),intent(out) :: mass,bex,bflux
    integer,intent(out) :: status,nl,ir,back
    character(len=*),intent(out) :: route
    type(fmr_b110_physical_parameters_t) :: fallback_p
    class(transaction_state_t),allocatable :: before,after
    real(real64) :: total_integrated_gate,local_integrated_gate,fallback_tol,local_fallback_tol, &
         rsum,rmax,abs_integrated,local_integrated
    integer :: bal_flags,head_flags,imax,failed_nl,failed_back
    integer(int64) :: rev_before,lineage_before
    real(real64) :: time_before,time_after
    logical :: got,time_ok,bound_ok,unchanged
    character(len=24) :: failure_class

    fallback_used=.false.
    p%total_balance_tolerance=original_total_tol
    rev_before=state%current_revision()
    lineage_before=state%current_lineage_id()
    call state%current_time(time_before,time_ok)
    call require(time_ok.and.same_bits(time_before,t0),'LAREGW1 C4Z pre-attempt committed time')
    call state%snapshot(before,got)
    call require(got,'LAREGW1 C4Z pre-attempt snapshot')
    total_integrated_gate=hard_mass_gate
    local_integrated_gate=hard_mass_gate/real(numnod,real64)
    bound_ok=ieee_is_finite(total_integrated_gate).and.ieee_is_finite(local_integrated_gate).and. &
         total_integrated_gate>0.0_real64.and.local_integrated_gate>0.0_real64
    call require(bound_ok,'LAREGW1 C4Z integrated water-depth gates')

    call sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
    if(ok)then
      if(allocated(before))deallocate(before)
      return
    end if
    if(p%bottom_mode/=2 .and. p%bottom_mode/=5)then
      if(allocated(before))deallocate(before)
      return
    end if

    call state%current_time(time_after,time_ok)
    call require(time_ok.and.same_bits(time_after,time_before),'LAREGW1 C4Z failed attempt time immutable')
    call require(state%current_revision()==rev_before,'LAREGW1 C4Z failed attempt revision immutable')
    call require(state%current_lineage_id()==lineage_before,'LAREGW1 C4Z failed attempt lineage immutable')
    call state%snapshot(after,got)
    call require(got,'LAREGW1 C4Z failed attempt snapshot')
    unchanged=state_bits_equal(before,after)
    call require(unchanged,'LAREGW1 C4Z failed attempt physical state immutable')

    failed_nl=nl;failed_back=back
    call diagnose_failed_interval(p,forcing,state,t0,t1,status,failed_nl,failed_back, &
         failure_class,bal_flags,head_flags,rmax,rsum,imax)
    abs_integrated=abs(rsum)*(t1-t0)
    local_integrated=abs(rmax)*(t1-t0)
    call require(ieee_is_finite(abs_integrated).and.abs_integrated<=total_integrated_gate, &
         'LAREGW1 C4Z total residual within integrated water-depth gate')
    call require(ieee_is_finite(local_integrated).and.local_integrated<=local_integrated_gate, &
         'LAREGW1 C4Z local residual within integrated water-depth gate')

    fallback_tol=max(original_total_tol,total_integrated_gate/(t1-t0))
    local_fallback_tol=max(p%compartment_balance_tolerance,local_integrated_gate/(t1-t0))
    fallback_p=p
    fallback_p%total_balance_tolerance=fallback_tol
    fallback_p%compartment_balance_tolerance=local_fallback_tol

    select case(trim(failure_class))
    case('RETRY_TOTAL_ONLY')
      call require(bal_flags==0.and.head_flags==0,'LAREGW1 C4Z total-only flag contract')
    case('RETRY_LOCAL_BALANCE')
      call require(bal_flags>0.and.head_flags==0,'LAREGW1 C4Z local-only flag contract')
    case default
      call require(.false.,'LAREGW1 C4Z failure class not authorized')
    end select

    call sample_fresh(column,template,fallback_p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
    call require(ok,'LAREGW1 C4Z qualified fallback reattempt')
    fallback_used=.true.
    write(*,'(*(g0))') 'LAREGW1_C4Z_FALLBACK|T0=',t0,'|T1=',t1,'|BOTTOM_MODE=',p%bottom_mode, &
         '|CLASS=',trim(failure_class),'|BAL_FLAGS=',bal_flags,'|HEAD_FLAGS=',head_flags, &
         '|RMAX=',rmax,'|RSUM=',rsum,'|LOCAL_INTEGRATED_CM=',local_integrated, &
         '|LOCAL_GATE_CM=',local_integrated_gate,'|TOTAL_INTEGRATED_CM=',abs_integrated, &
         '|TOTAL_GATE_CM=',total_integrated_gate,'|FAILED_NL=',failed_nl,'|FAILED_BACKTRACK=',failed_back, &
         '|ACCEPT_NL=',nl,'|ACCEPT_BACKTRACK=',back
    if(allocated(before))deallocate(before)
    if(allocated(after))deallocate(after)
  end subroutine strict_first_sample
"""
    t=block(t,r"^  subroutine strict_first_sample\(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used\).*?^  end subroutine strict_first_sample\n",strict,"strict-first policy")

    t=one(t,"write(*,'(A)') 'LAREGW1_B14_MATERIAL_TRANSFER_GENERATED=FALSE'",
          "write(*,'(A)') 'LAREGW1_C4Z_BLIND_DYNAMIC_HEAD_GENERATED=TRUE'","completion marker")

    a.output.write_text(t,encoding="utf-8")
    manifest={
      "schema":"swap5.lare.bc2.c4z.materialization.v1",
      "source_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "changes":[
        "fresh Z01-Z04 response-blind dynamic-head histories",
        "initial effective saturations 0.725,0.825,0.875,0.775",
        "head multipliers 0.875 and 1.125 retained from C4Y without attenuation",
        "segment lengths 256/320/448 or 320/256/448",
        "R2/R16 geometry and geometric half-column diagnostics",
        "replace RS1 prospective-representation fallback bound by the pre-existing D13 integrated-water-depth retry policy"
      ],
      "reference_retry_policy":{
        "total_integrated_gate_cm":1e-12,
        "local_integrated_gate_formula_cm":"1e-12/numnod",
        "authorized_failure_classes":["RETRY_TOTAL_ONLY","RETRY_LOCAL_BALANCE"],
        "source_authority":"F-ROMV2 D13 / C4S pre-existing policy"
      },
      "solver_or_physics_changed":False,
      "hydrological_threshold_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))

if __name__=="__main__":
    main()
