#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

HISTORIES={
  1:{"label":"V01","Se":0.60,"root":"SHALLOW","tp":0.60},
  2:{"label":"V02","Se":0.45,"root":"SHALLOW","tp":0.30},
  3:{"label":"V03","Se":0.60,"root":"UNIFORM","tp":0.60},
  4:{"label":"V04","Se":0.45,"root":"UNIFORM","tp":0.30},
}

def sha256(p:pathlib.Path)->str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

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

def initial_block()->str:
    return """  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.60_real64
    case(2); value=0.45_real64
    case(3); value=0.60_real64
    case(4); value=0.45_real64
    case default; value=-1.0_real64
    end select
  end function initial_se
"""

def bottom_block()->str:
    return """  pure integer function bottom_kind(ih) result(value)
    integer,intent(in) :: ih
    if(ih>=1.and.ih<=4)then
      value=BOTTOM_FIXED_FLUX
    else
      value=-1
    end if
  end function bottom_kind
"""

def forcing_kind_block()->str:
    return """  pure integer function forcing_kind(ih) result(value)
    integer,intent(in) :: ih
    if(ih>=1.and.ih<=4)then
      value=ih
    else
      value=-1
    end if
  end function forcing_kind
"""

def multiplier_block()->str:
    return """  pure real(real64) function top_multiplier(kind,step) result(value)
    integer,intent(in) :: kind,step
    if(kind>=1.and.kind<=4.and.step>=1)then
      value=1.0_real64
    else
      value=-1.0_real64
    end if
  end function top_multiplier
"""

def label_block()->str:
    return """  function case_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=48) :: label
    select case(ih)
    case(1); label='V01'
    case(2); label='V02'
    case(3); label='V03'
    case(4); label='V04'
    case default; label='BAD'
    end select
  end function case_label
"""

def forcing_label_block()->str:
    return """  pure function forcing_label(kind) result(label)
    integer,intent(in) :: kind
    character(len=20) :: label
    select case(kind)
    case(1); label='SHALLOW_HIGH'
    case(2); label='SHALLOW_MID'
    case(3); label='UNIFORM_HIGH'
    case(4); label='UNIFORM_MID'
    case default; label='UNKNOWN'
    end select
  end function forcing_label
"""

def configure_block()->str:
    return """  subroutine configure_case(ih,step,h0,k0,qeq,p,forcing)
    integer,intent(in) :: ih,step
    real(real64),intent(in) :: h0,k0,qeq
    type(fmr_b110_physical_parameters_t),intent(inout) :: p
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    call require(ih>=1.and.ih<=4.and.step>=1,'LAREDYN0R C6R valid root history')
    p%total_balance_tolerance=original_total_tol
    p%bottom_mode=2
    p%root_extraction_active=.true.
    forcing%top_head=0.0_real64
    forcing%top_flux=qeq
    forcing%bottom_flux=qeq
    forcing%bottom_head=h0
  end subroutine configure_case
"""

def run_history_block()->str:
    return """  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass)
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
    integer :: step,status,nl,ir,back,substep
    character(len=96) :: route
    logical :: ok,fallback_used
    integer :: history_fallbacks
    real(real64) :: history_max_mass

    call initialize_parameters(p)
    call initialize_state(p,initial_se(ih),h0,k0,initial_state)
    qeq=-k0
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(state,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.state%ready(),'LAREDYN0R C6R initial committed state')

    p%bottom_mode=2
    p%root_extraction_active=.false.
    p%total_balance_tolerance=original_total_tol
    call seed_steady(column,template,p,state,forcing,qeq,ok)
    call require(ok,'LAREDYN0R C6R gravity-consistent seed')

    t0=real(seed_intervals,real64)*seed_dt
    history_fallbacks=0
    history_max_mass=0.0_real64
    cumulative_root=0.0_real64
    observation_root=0.0_real64

    sub_dt=step_dt/real(substeps,real64)
    do step=1,NSTEPS
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
        call require(ok,'LAREDYN0R C6R accepted root-active history step')
        call require(.not.fallback_used,'LAREDYN0R C6R root-active fallback forbidden')
        call require(abs(mass)<=hard_mass_gate,'LAREDYN0R C6R hard mass gate')
        call require(state%current_revision()==int(seed_intervals+(step-1)*substeps+substep,int64), &
             'LAREDYN0R C6R exact revision progression')
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

    write(*,'(*(g0))') 'LAREDYN0R_HISTORY_PASS|CASE=',trim(case_label(ih)),'|SE0=',initial_se(ih), &
         '|FORCING=',trim(forcing_label(forcing_kind(ih))),'|BOTTOM=',trim(bottom_label(bottom_kind(ih))), &
         '|STATES=',NSTEPS,'|SUBSTEPS=',substeps,'|FALLBACKS=',history_fallbacks,'|MAX_ABS_MASS=',history_max_mass, &
         '|FINAL_REV=',state%current_revision(),'|FINAL_T=',t0,'|CUMULATIVE_ROOT=',cumulative_root
  end subroutine run_history
"""

def root_helpers()->str:
    return """  pure real(real64) function pressure_head_from_se(p,se) result(h)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(in) :: se
    real(real64) :: m
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
  end function pressure_head_from_se

  pure real(real64) function potential_transpiration(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1,3); value=0.60_real64
    case(2,4); value=0.30_real64
    case default; value=-1.0_real64
    end select
  end function potential_transpiration

  pure integer function root_profile_kind(ih) result(kind)
    integer,intent(in) :: ih
    select case(ih)
    case(1,2); kind=1
    case(3,4); kind=2
    case default; kind=-1
    end select
  end function root_profile_kind

  subroutine evaluate_committed_root_sink(ih,p,state,forcing,total_rate)
    integer,intent(in) :: ih
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64),intent(out) :: total_rate
    type(root_water_uptake_parameters_t) :: parameters
    type(root_water_uptake_request_t) :: request
    type(root_water_uptake_flux_result_t) :: fluxes
    type(root_water_uptake_diagnostics_t) :: diagnostics
    type(process_hydraulic_view_t) :: view
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: rooted,j,kind
    real(real64) :: u,expected_potential

    rooted=numnod/2
    call require(rooted>0.and.2*rooted==numnod,'LAREDYN0R C6R exact 80cm rooted half-column')
    kind=root_profile_kind(ih)
    call require(kind==1.or.kind==2,'LAREDYN0R C6R valid root profile')

    parameters%active_nodes=numnod
    parameters%hlim4=pressure_head_from_se(p,0.08_real64)
    parameters%hlim3l=pressure_head_from_se(p,0.35_real64)
    parameters%hlim3h=pressure_head_from_se(p,0.55_real64)
    parameters%adcrl=0.10_real64
    parameters%adcrh=0.50_real64

    request%potential_transpiration=potential_transpiration(ih)
    request%rooted_nodes=rooted
    allocate(request%cumulative_root_fraction(rooted+1))
    do j=0,rooted
      u=real(j,real64)/real(rooted,real64)
      if(kind==1)then
        request%cumulative_root_fraction(j+1)=2.0_real64*u-u*u
      else
        request%cumulative_root_fraction(j+1)=u
      end if
    end do

    call state%snapshot(snap,got)
    call require(got,'LAREDYN0R C6R committed root snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      view%active_nodes=physical%active_nodes
      allocate(view%pressure_head(numnod),view%water_content(numnod))
      view%pressure_head=physical%pressure_head
      view%water_content=physical%water_content
      view%ponding_depth=physical%ponding_depth
      view%groundwater_level=physical%groundwater_level
    class default
      call require(.false.,'LAREDYN0R C6R expected B110 root state')
    end select

    call evaluate_macro_feddes_drought_uptake(parameters,view,request,fluxes,diagnostics)
    call require(diagnostics%status==ROOT_UPTAKE_OK.and.diagnostics%evaluated,'LAREDYN0R C6R root process evaluated')
    expected_potential=request%potential_transpiration
    call require(abs(diagnostics%potential_uptake_total-expected_potential)<=1.0e-12_real64, &
         'LAREDYN0R C6R potential uptake reconciliation')
    call require(allocated(fluxes%root_extraction_sink).and.size(fluxes%root_extraction_sink)==numnod, &
         'LAREDYN0R C6R root sink shape')
    call require(all(ieee_is_finite(fluxes%root_extraction_sink)),'LAREDYN0R C6R finite root sink')
    call require(all(fluxes%root_extraction_sink>=0.0_real64),'LAREDYN0R C6R nonnegative root sink')
    call require(abs(sum(fluxes%root_extraction_sink)-fluxes%actual_uptake_total)<=1.0e-12_real64, &
         'LAREDYN0R C6R actual uptake reconciliation')
    forcing%root_extraction_sink=fluxes%root_extraction_sink
    total_rate=fluxes%actual_uptake_total
    call require(ieee_is_finite(total_rate).and.total_rate>=0.0_real64.and. &
         total_rate<=request%potential_transpiration+1.0e-12_real64,'LAREDYN0R C6R bounded actual uptake')
    if(allocated(snap))deallocate(snap)
  end subroutine evaluate_committed_root_sink

"""

def profile_loop()->str:
    return """      if(mod(step,OUTPUT_FACTOR)==0)then
        call require(mod(numnod,16)==0,'LAREDYN0R C6R geometry divisible by 16')
        nodes_per_bin=numnod/16
        do bin=1,16
          lo_node=(bin-1)*nodes_per_bin+1
          hi_node=bin*nodes_per_bin
          bin_theta=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))/10.0_real64
          write(*,'(*(g0))') 'LAREDYN0R_PROFILE|CASE=',trim(case_label(ih)),'|STEP=',step, &
               '|OBS_STEP=',step/OUTPUT_FACTOR,'|BIN=',bin,'|THETA=',bin_theta
        end do
      end if"""

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    factor=a.temporal_factor
    text=a.source.read_text()

    text=one(
      text,
      "  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n",
      "  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
      "  use mod_process_hydraulic_view, only: process_hydraulic_view_t\n"
      "  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &\n"
      "       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, ROOT_UPTAKE_OK\n",
      "root process imports"
    )
    text=one(
      text,
      "integer, parameter :: NHIST=24, NSTEPS=1024",
      f"integer, parameter :: NHIST=4, NSTEPS={1024*factor}\n  integer, parameter :: OUTPUT_FACTOR={factor}",
      "time grid"
    )
    text=one(
      text,
      "real(real64), parameter :: step_dt=0.0008_real64",
      f"real(real64), parameter :: step_dt={0.0008/factor:.12g}_real64",
      "transaction dt"
    )
    text=block(text,r"^  pure integer function bottom_kind\(ih\) result\(value\).*?^  end function bottom_kind\n",bottom_block(),"bottom kind")
    text=block(text,r"^  pure integer function forcing_kind\(ih\) result\(value\).*?^  end function forcing_kind\n",forcing_kind_block(),"forcing kind")
    text=block(text,r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",initial_block(),"initial Se")
    text=block(text,r"^  pure real\(real64\) function top_multiplier\(kind,step\) result\(value\).*?^  end function top_multiplier\n",multiplier_block(),"top multiplier")
    text=block(text,r"^  function case_label\(ih\) result\(label\).*?^  end function case_label\n",label_block(),"case label")
    text=block(text,r"^  pure function forcing_label\(kind\) result\(label\).*?^  end function forcing_label\n",forcing_label_block(),"forcing label")
    text=block(text,r"^  subroutine configure_case\(ih,step,h0,k0,qeq,p,forcing\).*?^  end subroutine configure_case\n",configure_block(),"configure")
    text=block(text,r"^  subroutine run_history\(ih,total_states,total_fallbacks,max_abs_mass\).*?^  end subroutine run_history\n",run_history_block(),"run history")

    text=one(
      text,
      "    real(real64) :: total\n    integer :: node\n",
      "    real(real64) :: total,bin_theta\n    integer :: bin,lo_node,hi_node,nodes_per_bin\n",
      "emit declarations"
    )
    pat=(
      r"\n      do node=1,numnod\n"
      r"        write\(\*,'\(\*\(g0\)\)'\) 'LAREDYN0R_NODE\|CASE=',trim\(case_label\(ih\)\),'\|STEP=',step,'\|NODE=',node, &\n"
      r"             '\|Z=',z\(node\),'\|DZ=',dz\(node\),'\|H=',physical%pressure_head\(node\),'\|THETA=',physical%water_content\(node\)\n"
      r"      end do"
    )
    text,n=re.subn(pat,"\n"+profile_loop(),text,count=1)
    if n!=1:
        raise SystemExit(f"profile replacement found {n}")

    text=one(
      text,
      "    ! DYN0A reuses only the already-qualified mode-2 fallback. Free drainage mode 7 fails closed.\n    if(p%bottom_mode/=2)then",
      "    ! C6R root-active Reference fails closed after any first-attempt failure; the mode-2 fallback is not root-active authority.\n"
      "    if(p%root_extraction_active)then\n"
      "      if(allocated(before))deallocate(before)\n"
      "      return\n"
      "    end if\n\n"
      "    ! DYN0A reuses only the already-qualified mode-2 fallback. Free drainage mode 7 fails closed.\n"
      "    if(p%bottom_mode/=2)then",
      "root-active fail closed"
    )

    text=one(
      text,
      "  subroutine strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)\n",
      root_helpers()+"  subroutine strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)\n",
      "root helpers"
    )
    text=one(
      text,
      "  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
      "  write(*,'(A)') 'LAREDYN0R_C6R_ROOT_ACTIVE_REFERENCE_GENERATED=TRUE'\n"
      "  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
      "completion marker"
    )

    a.output.write_text(text)
    out={
      "schema":"swap5.lare.bc2.c6r.reference-materialization.v1",
      "source_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "material":a.material,
      "temporal_factor":factor,
      "transaction_dt_day":0.0008/factor,
      "steps_per_history":1024*factor,
      "histories":HISTORIES,
      "root_depth_cm":80.0,
      "root_profiles":["SHALLOW","UNIFORM"],
      "feddes_Se_anchors":{"h4":0.08,"h3L":0.35,"h3H":0.55},
      "demand_breakpoints_cm_per_day":{"ADCRL":0.10,"ADCRH":0.50},
      "root_process":"evaluate_macro_feddes_drought_uptake on committed hydraulic state before every transaction",
      "root_sink_trial_semantics":"prescribed during each Reference transaction",
      "top_boundary":"FIXED_GRAVITY_EQUILIBRIUM_FLUX",
      "bottom_boundary":"FIXED_GRAVITY_EQUILIBRIUM_FLUX",
      "bottom_mode":2,
      "root_active_first_attempt_failure":"FAIL_CLOSED_NO_DYN0A_FALLBACK",
      "profile_output":{"bins":16,"bin_thickness_cm":10.0},
      "node_output_suppressed":True,
      "production_source_changed":False,
      "retry_policy_extended":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
