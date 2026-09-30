#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, re, sqlite3, sys
from pathlib import Path

PROFILE_ID=3030
N=16
ALPHA=0.17320259355765216
T_BOUND=0.049428424452890203
B_NATIVE=T_BOUND/ALPHA

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None: raise SystemExit(f"F_PE_ELASTIC60_FAIL load {path}")
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod; spec.loader.exec_module(mod); return mod

def f64(x):
    s=format(float(x),".17g")
    if "." not in s and "e" not in s.lower(): s+=".0"
    return s+"_real64"

def arr(vals): return "["+",".join(f64(v) for v in vals)+"]"
def fstr(x): return str(x).replace("'","''")

def parse_catalog(root):
    text=(root/"src/adapter/mod_fmr_elastic_storage_staringreeks_catalog.f90").read_text(encoding="utf-8")
    out={}
    for name in ("WCR","WCS","ALPHA","NPAR"):
        m=re.search(rf"{name}\(FMR_STARINGREEKS_CATALOG_COUNT\)\s*=\s*\[\s*&(?P<body>.*?)\]",text,re.S)
        if not m: raise SystemExit(f"F_PE_ELASTIC60_FAIL catalog {name}")
        vals=[float(x) for x in re.findall(r"([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?)_real64",m.group("body"))]
        if len(vals)!=36: raise SystemExit(f"F_PE_ELASTIC60_FAIL catalog count {name}")
        out[name]=vals
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve(); work=Path(a.work_dir).resolve(); work.mkdir(parents=True,exist_ok=True)
    tools=root/"tools"
    if str(tools) not in sys.path: sys.path.insert(0,str(tools))
    e24=load("el60_e24",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("el60_e33",tools/"fpe_elastic33_profile_row_interchange.py")
    p46=load("el60_p46",root/"tests/fpe/prepare_fpe_elastic46.py")
    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1: raise SystemExit(f"F_PE_ELASTIC60_FAIL gpkg hits={len(hits)}")
    profile=e24.retrieve_profile(hits[0].resolve(),PROFILE_ID)
    z,dz,counts=p46.split_profile(profile["horizons"],N)
    nd=[abs(z[1]-z[0])]+[abs(z[i]-z[i-1]) for i in range(1,len(z))]
    Path(a.geometry_json).write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")
    row=work/"profile.rows"; row.write_text(e33.materialize_interchange(profile),encoding="utf-8")
    cfg=work/"request.cfg"; cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    cat=parse_catalog(root)
    node={k:[] for k in cat}
    for h,count in zip(profile["horizons"],counts):
        b=int(h["staringseriesblock"]); idx=(b-101) if b<=118 else 18+(b-201)
        for k in cat: node[k].extend([cat[k][idx]]*count)
    if any(len(v)!=N for v in node.values()): raise SystemExit("F_PE_ELASTIC60_FAIL material count")

    src=f"""module mod_fpe_elastic60_transaction_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fpe_elastic53_reference_richards_temporal_indicator, only: &
       evaluate_fpe_elastic53_reference_richards_temporal_indicator
  implicit none
  integer, parameter :: N=16
  real(real64), parameter :: B_NATIVE={f64(B_NATIVE)}
  real(real64), parameter :: MASS_TOL=1.0e-12_real64

  type, extends(transaction_state_t), public :: el60_state_t
    real(real64) :: h(N)=0.0_real64
    real(real64) :: theta(N)=0.0_real64
    real(real64) :: pond=0.0_real64
    real(real64) :: gwl=-2.0_real64
    real(real64) :: previous_derivative(N)=0.0_real64
  contains
    procedure :: clone => el60_clone
  end type

  type, extends(transaction_model_t), public :: el60_model_t
    type(fmr_b110_physical_parameters_t) :: p
    real(real64) :: qtop=0.0_real64
    real(real64) :: qbot_seed=0.0_real64
    real(real64) :: forcing_top_head=0.0_real64
    logical :: inject_mass_defect=.false.
  contains
    procedure :: advance => el60_advance
    procedure :: storage => el60_storage
    procedure :: temporal_error => el60_temporal_error
    procedure :: storage_accounting_status => el60_storage_status
  end type
contains
  subroutine el60_clone(self,copy)
    class(el60_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(el60_state_t::copy)
    select type(copy); type is(el60_state_t)
      copy=self
    end select
  end subroutine

  function el60_storage(self,state) result(v)
    class(el60_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    real(real64)::v
    if(self%p%active_nodes<0) error stop 'unreachable'
    select type(state); type is(el60_state_t)
      v=sum(state%theta*self%p%dz)+state%pond
    class default
      error stop 'ELASTIC60 state type'
    end select
  end function

  subroutine el60_storage_status(self,state,complete,missing_mask)
    class(el60_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    complete=.false.; missing_mask=TX_MASS_MISSING_NONE
    if(self%p%active_nodes/=N)return
    select type(state); type is(el60_state_t)
      complete=all(ieee_is_finite(state%h)).and.all(ieee_is_finite(state%theta)).and.ieee_is_finite(state%pond)
    class default
      complete=.false.
    end select
  end subroutine

  function el60_temporal_error(self,full_state,half_state) result(v)
    class(el60_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    real(real64)::v
    if(self%p%active_nodes<0.or.same_type_as(full_state,half_state).neqv.same_type_as(half_state,full_state)) error stop 'unreachable'
    v=huge(0.0_real64)
  end function

  subroutine el60_advance(self,state,t0,t1,outcome)
    class(el60_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    type(soil_water_parameter_set_t),target::soil
    type(b110_default_mvg_provider_t),target::constitutive
    type(b110_source_sink_provider_t),target::source_sink
    type(fixed_flux_top_boundary_provider_t),target::top
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::r
    type(soil_water_solve_result_t)::res
    type(soil_water_temporal_indicator_request_t)::ireq
    type(soil_water_temporal_indicator_result_t)::ind
    real(real64),target::drain(1,N),ss(N),root(N)
    real(real64)::dt
    outcome=trial_outcome_t()
    dt=t1-t0
    if(dt<=0.0_real64)return
    call init_soil(soil,self%p)
    drain=0.0_real64;ss=0.0_real64;root=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drain,ss,root)
    call bind_b110_default_mvg_provider(constitutive,self%p%prepared_default_mvg,dt)
    select type(state); type is(el60_state_t)
      call make_request(r,soil,constitutive,source_sink,top,state,self%qtop,self%qbot_seed,self%forcing_top_head,dt)
      call solver%solve(r,workspace,res)
      outcome%nonlinear_iterations=res%diagnostics%nonlinear_iterations
      outcome%internal_retries=res%diagnostics%internal_retries
      outcome%jacobian_builds=res%diagnostics%jacobian_builds
      outcome%linear_solves=res%diagnostics%linear_solves
      outcome%backtracking_attempts=res%diagnostics%backtracking_attempts
      if(res%status/=SW_SOLVE_CONVERGED)return
      outcome%solver_ok=.true.
      outcome%mass_in=max(0.0_real64,-res%top_flux)*dt+max(0.0_real64,res%bottom_flux)*dt
      outcome%mass_out=max(0.0_real64,res%top_flux)*dt+max(0.0_real64,-res%bottom_flux)*dt
      if(self%inject_mass_defect) outcome%mass_out=outcome%mass_out+1.0e-3_real64
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      ireq%previous_right_derivative_available=.true.
      allocate(ireq%previous_right_derivative(N));ireq%previous_right_derivative=state%previous_derivative
      call evaluate_fpe_elastic53_reference_richards_temporal_indicator(r,res,ireq,ind)
      outcome%linear_solves=outcome%linear_solves+ind%additional_tridiagonal_solves
      if(ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.ind%available.and. &
         allocated(ind%current_right_derivative).and.ieee_is_finite(ind%head_inf_bound))then
        outcome%temporal_certificate_available=.true.
        outcome%temporal_indicator=ind%head_inf_bound/B_NATIVE
      end if
      state%h=res%candidate_state%pressure_head
      state%theta=res%candidate_state%water_content
      state%pond=res%candidate_state%ponding_depth
      state%gwl=res%candidate_state%groundwater_level
      if(allocated(ind%current_right_derivative))then
        if(size(ind%current_right_derivative)==N) state%previous_derivative=ind%current_right_derivative
      end if
    class default
      error stop 'ELASTIC60 state type advance'
    end select
  end subroutine

  subroutine init_soil(s,p)
    type(soil_water_parameter_set_t),target,intent(out)::s
    type(fmr_b110_physical_parameters_t),intent(in)::p
    s%parameter_set_id=p%parameter_set_id;s%active_nodes=N
    allocate(s%z(N),s%dz(N),s%node_distance(N))
    s%z=p%z;s%dz=p%dz;s%node_distance=p%node_distance
  end subroutine

  subroutine make_request(r,s,c,src,tp,state,qtop,qbot,tophead,dt)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::s
    type(b110_default_mvg_provider_t),target,intent(in)::c
    type(b110_source_sink_provider_t),target,intent(in)::src
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    type(el60_state_t),intent(in)::state
    real(real64),intent(in)::qtop,qbot,tophead,dt
    r%parameters=>s
    r%base_state%active_nodes=N
    allocate(r%base_state%pressure_head(N),r%base_state%water_content(N))
    r%base_state%pressure_head=state%h;r%base_state%water_content=state%theta
    r%base_state%ponding_depth=state%pond;r%base_state%groundwater_level=state%gwl
    r%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;r%boundary%bottom_mode=7
    r%boundary%top_flux=qtop;r%boundary%top_head=tophead;r%boundary%bottom_flux=qbot;r%boundary%bottom_head=-999999.0_real64
    r%evaluation%constitutive=>c;r%evaluation%source_sink=>src;r%evaluation%top_boundary=>tp
    r%physical%macropore_active=.false.;r%step_duration=dt
    r%numerical%max_iterations=16;r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0;r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=MASS_TOL;r%numerical%total_balance_tolerance=MASS_TOL
    r%numerical%head_abs_tolerance=MASS_TOL;r%numerical%head_rel_tolerance=MASS_TOL;r%numerical%ponding_tolerance=MASS_TOL
  end subroutine
end module

program test_fpe_elastic60_transaction_composition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_TEMPORAL_MODEL_CERTIFICATE, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, &
       TX_ROUTE_MODEL_CERTIFIED, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, prepare_fmr_b110_default_mvg
  use mod_fmr_elastic_storage_application_host_binding, only: fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fpe_elastic60_transaction_model
  implicit none
  real(real64),parameter::DURATION=0.015625_real64
  type(fmr_b110_physical_parameters_t)::p_off,p_fixed,p_gen,p
  type(fmr_elastic_storage_application_host_diagnostics_t)::hdiag
  real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),h0,delta,qeq
  type(b110_default_mvg_provider_t)::provider
  character(len=32)::regime
  character(len=64)::arg
  class(transaction_state_t),allocatable::committed,oracle_state,initial_copy
  type(el60_model_t)::model,probe
  type(transaction_policy_t)::policy
  type(transaction_result_t)::result,mass_result
  real(real64)::expected_dt,dt,initial_storage,probe_storage,mres
  integer::retry
  logical::oracle_accept,pass,prepared

  if(command_argument_count()<3) error stop 'F_PE_ELASTIC60_FAIL args'
  call get_command_argument(1,regime)
  call get_command_argument(2,arg);read(arg,*)h0
  call get_command_argument(3,arg);read(arg,*)delta

  call init_parameters(p_off)
  p_fixed=p_off;p_fixed%elasticity_active=.true.;p_fixed%cofgen(24,:)=1.0e-6_real64
  call fmr_prepare_application_parameters_with_elastic_storage('{fstr(cfg)}','{fstr(row)}',p_off,p_gen,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated prior')
  select case(trim(regime));case('OFF');p=p_off;case('FIXED_1E6');p=p_fixed;case('GENERATED');p=p_gen
  case default;error stop 'F_PE_ELASTIC60_FAIL regime';end select
  call prepare_fmr_b110_default_mvg(p,prepared);call req(prepared,'prepare')
  heads=h0
  call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DURATION)
  call provider%evaluate(heads,water,cond,cap,dk)
  qeq=-cond(1)

  model%p=p;model%qtop=qeq+delta;model%qbot_seed=qeq;model%forcing_top_head=h0
  call new_state(committed,h0,water)
  call committed%clone(initial_copy)
  initial_storage=model%storage(committed)

  oracle_accept=.false.;expected_dt=0.0_real64
  dt=DURATION
  do retry=0,8
    probe=model
    call new_state(oracle_state,h0,water)
    call probe%advance(oracle_state,0.0_real64,dt,probe_outcome)
    pass=.false.
    if(probe_outcome%solver_ok)then
      probe_storage=probe%storage(oracle_state)
      mres=probe_storage-initial_storage-(probe_outcome%mass_in-probe_outcome%mass_out)
      pass=abs(mres)<=MASS_TOL.and.probe_outcome%temporal_certificate_available.and.probe_outcome%temporal_indicator<=1.0_real64
    end if
    if(pass)then
      oracle_accept=.true.;expected_dt=dt;exit
    end if
    dt=0.5_real64*dt
  end do

  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  policy%mass_tolerance=MASS_TOL
  policy%retry_scale=0.5_real64
  policy%max_retries=8
  call execute_reference_interval(model,committed,0.0_real64,DURATION,policy,result)

  if(oracle_accept)then
    call req(result%status==TX_STATUS_ACCEPTED,'transaction accepted')
    call req(result%accepted_route==TX_ROUTE_MODEL_CERTIFIED,'model route')
    call req(result%temporal_acceptance_source==TX_TEMPORAL_MODEL_CERTIFICATE,'model source')
    call req(transfer(result%accepted_dt,0_int64)==transfer(expected_dt,0_int64),'first pass dt')
    call req(result%commits==1.and.result%rollbacks==result%retries,'commit rollback accounting')
    call req(result%accepted_mass_complete.and.abs(result%accepted_mass_residual)<=MASS_TOL,'hard mass')
    call req(result%temporal_indicator<=1.0_real64,'certificate accepted')
    call require_state_identity(committed,oracle_state)
  else
    call req(result%status==TX_STATUS_RETRY_EXHAUSTED,'transaction exhausted')
    call req(result%commits==0,'no exhausted commit')
    call require_state_identity(committed,initial_copy)
  end if

  ! Deliberate mass-defect discriminator at equilibrium.
  model%inject_mass_defect=.true.;model%qtop=qeq;model%qbot_seed=qeq
  call new_state(committed,h0,water)
  policy%max_retries=1
  call execute_reference_interval(model,committed,0.0_real64,DURATION,policy,mass_result)
  call req(mass_result%status==TX_STATUS_RETRY_EXHAUSTED,'mass discriminator exhausted')
  call req(mass_result%mass_rejections>=1.and.mass_result%commits==0,'mass before commit')
  call require_state_identity(committed,initial_copy)

  write(*,'(*(g0))')'ELASTIC60_CASE|regime=',trim(regime),'|h0=',h0,'|delta=',delta, &
       '|oracle_accept=',oracle_accept,'|expected_dt=',expected_dt,'|status=',result%status, &
       '|accepted_dt=',result%accepted_dt,'|attempts=',result%attempts,'|retries=',result%retries, &
       '|rollbacks=',result%rollbacks,'|commits=',result%commits,'|solver_rejections=',result%solver_rejections, &
       '|mass_rejections=',result%mass_rejections,'|temporal_rejections=',result%temporal_rejections, &
       '|temporal_indicator=',result%temporal_indicator,'|mass_residual=',result%accepted_mass_residual
  write(*,'(A)')'F_PE_ELASTIC60_EXEC=PASS'

contains
  type(trial_outcome_t) :: probe_outcome

  subroutine init_parameters(q)
    type(fmr_b110_physical_parameters_t),intent(out)::q
    integer::k
    q%parameter_set_id=600060_int64;q%active_nodes=N
    allocate(q%z(N),q%dz(N),q%node_distance(N),q%cofgen(24,N))
    q%z={arr(z)};q%dz={arr(dz)};q%node_distance=0.0_real64;q%cofgen=0.0_real64
    do k=2,N;q%node_distance(k)=abs(q%z(k)-q%z(k-1));end do
    q%node_distance(1)=q%node_distance(2)
    do k=1,N
      q%cofgen(1,k)={arr(node['WCR'])}(k);q%cofgen(2,k)={arr(node['WCS'])}(k);q%cofgen(3,k)=4.75_real64
      q%cofgen(4,k)={arr(node['ALPHA'])}(k);q%cofgen(5,k)=0.365_real64;q%cofgen(6,k)={arr(node['NPAR'])}(k)
      q%cofgen(7,k)=1.0_real64-1.0_real64/q%cofgen(6,k);q%cofgen(8,k)=q%cofgen(4,k)
      q%cofgen(9,k)=0.0_real64;q%cofgen(10,k)=q%cofgen(3,k);q%cofgen(11,k)=0.999_real64
      q%cofgen(12,k)=0.99_real64*q%cofgen(3,k);q%cofgen(22,k)=-1.0e6_real64;q%cofgen(23,k)=1.0e-12_real64
    end do
    q%bottom_mode=7;q%swkimpl=0;q%swkmean=1;q%swsophy=0
    q%max_iterations=16;q%max_backtracking=8;q%min_step_duration=1.0e-8_real64
    q%compartment_balance_tolerance=MASS_TOL;q%total_balance_tolerance=MASS_TOL
    q%head_abs_tolerance=MASS_TOL;q%head_rel_tolerance=MASS_TOL;q%ponding_tolerance=MASS_TOL
    q%elasticity_active=.false.
  end subroutine

  subroutine new_state(s,h,w)
    class(transaction_state_t),allocatable,intent(out)::s
    real(real64),intent(in)::h,w(N)
    allocate(el60_state_t::s)
    select type(s);type is(el60_state_t)
      s%h=h;s%theta=w;s%pond=max(0.0_real64,h);s%gwl=-2.0_real64;s%previous_derivative=0.0_real64
    end select
  end subroutine

  subroutine require_state_identity(a,b)
    class(transaction_state_t),allocatable,intent(in)::a,b
    select type(x=>a);type is(el60_state_t)
      select type(y=>b);type is(el60_state_t)
        call req(all(transfer(x%h,[(0_int64,k=1,N)])==transfer(y%h,[(0_int64,k=1,N)])),'head identity')
        call req(all(transfer(x%theta,[(0_int64,k=1,N)])==transfer(y%theta,[(0_int64,k=1,N)])),'theta identity')
        call req(transfer(x%pond,0_int64)==transfer(y%pond,0_int64),'pond identity')
        call req(all(transfer(x%previous_derivative,[(0_int64,k=1,N)])==transfer(y%previous_derivative,[(0_int64,k=1,N)])),'history identity')
      class default;error stop 'ELASTIC60 state b'
      end select
    class default;error stop 'ELASTIC60 state a'
    end select
  end subroutine

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then;write(*,'(A,1X,A)')'F_PE_ELASTIC60_FAIL',trim(msg);error stop 1;end if
  end subroutine
end program
"""
    # Fortran cannot index an array constructor directly in all supported modes:
    # materialize node arrays as parameters and replace constructor-index uses.
    # Insert parameter arrays after implicit none in the program.
    params=(
      f"  real(real64),parameter :: EL60_WCR(N)={arr(node['WCR'])}\n"
      f"  real(real64),parameter :: EL60_WCS(N)={arr(node['WCS'])}\n"
      f"  real(real64),parameter :: EL60_ALPHA(N)={arr(node['ALPHA'])}\n"
      f"  real(real64),parameter :: EL60_NPAR(N)={arr(node['NPAR'])}\n"
    )
    src=src.replace("  implicit none\n  real(real64),parameter::DURATION", "  implicit none\n"+params+"  real(real64),parameter::DURATION",1)
    src=src.replace(f"{arr(node['WCR'])}(k)","EL60_WCR(k)")
    src=src.replace(f"{arr(node['WCS'])}(k)","EL60_WCS(k)")
    src=src.replace(f"{arr(node['ALPHA'])}(k)","EL60_ALPHA(k)")
    src=src.replace(f"{arr(node['NPAR'])}(k)","EL60_NPAR(k)")
    # Move probe_outcome declaration from CONTAINS pseudo-scope into declarations.
    src=src.replace("  type(transaction_result_t)::result,mass_result\n", "  type(transaction_result_t)::result,mass_result\n  type(trial_outcome_t)::probe_outcome\n")
    src=src.replace("\ncontains\n  type(trial_outcome_t) :: probe_outcome\n","\ncontains\n")
    # Add trial_outcome_t import to program.
    src=src.replace("use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &",
                    "use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, trial_outcome_t, &")
    fixture=Path(a.fixture)
    marker="program test_fpe_elastic60_transaction_composition"
    pos=src.index(marker)
    module_text=src[:pos]
    program_text=src[pos:]
    module_path=fixture.with_name("mod_fpe_elastic60_transaction_model.f90")
    module_path.write_text(module_text,encoding="utf-8")
    fixture.write_text(program_text,encoding="utf-8")
    print("F_PE_ELASTIC60_PREP="+json.dumps({"profile_id":PROFILE_ID,"B_NATIVE":B_NATIVE,"counts":counts,"module":str(module_path)},sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
