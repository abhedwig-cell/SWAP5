#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

PROFILE_ID = 90116260
X_RD = 179362.75550490862
Y_RD = 418659.84937244334
NODE_COUNT = 16

def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC47_FAIL cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod

def f64(x: float) -> str:
    s = format(float(x), ".17g")
    if "." not in s and "e" not in s.lower():
        s += ".0"
    return s + "_real64"

def fstr(x: object) -> str:
    return str(x).replace("'", "''")

def main() -> None:
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()

    root=Path(a.repo_root).resolve()
    tools=root/"tools"
    parent=load("fpe_elastic46_parent",root/"tests/fpe/prepare_fpe_elastic46.py")
    e24=load("fpe_elastic24_profile_retrieval",tools/"fpe_elastic24_profile_retrieval.py")
    e41=load("fpe_elastic41_rd_application_handoff",tools/"fpe_elastic41_rd_application_handoff.py")

    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC47_FAIL gpkg hits={len(hits)}")
    gpkg=hits[0].resolve()
    profile=e24.retrieve_profile(gpkg,PROFILE_ID)

    work=Path(a.work_dir).resolve()
    work.mkdir(parents=True,exist_ok=True)
    row=work/"generated.rows"
    prov=work/"generated.provenance.json"
    cfg=work/"request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    result=e41.prepare_handoff(True,gpkg,X_RD,Y_RD,row,prov)
    if result["status"]!="OK":
        raise SystemExit("F_PE_ELASTIC47_FAIL ELASTIC41 handoff")

    manifest=json.loads(prov.read_text(encoding="utf-8"))
    if int(manifest["normalsoilprofile_id"])!=PROFILE_ID:
        raise SystemExit("F_PE_ELASTIC47_FAIL profile identity")
    z,dz,counts=parent.split_profile(profile["horizons"],NODE_COUNT)
    node_distance=[abs(z[1]-z[0])]
    node_distance.extend(abs(z[i]-z[i-1]) for i in range(1,len(z)))
    Path(a.geometry_json).write_text(json.dumps({
        "z_cm":z,"dz_cm":dz,"node_distance_cm":node_distance
    },sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")

    zarr="["+",".join(f64(v) for v in z)+"]"
    dzarr="["+",".join(f64(v) for v in dz)+"]"

    src=f"""program test_fpe_elastic47_timestep_interaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       fmr_column_diagnostics_t, fmr_aggregate_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: N=16
  real(real64), parameter :: MASS_TOL=1.0e-12_real64
  integer(int64), parameter :: COLUMN_ID=470047_int64

  type(fmr_b110_physical_parameters_t) :: p_off,p_fixed,p_generated,p
  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag
  character(len=32) :: regime
  character(len=64) :: arg
  real(real64) :: h0,delta,duration,elapsed,checksum
  integer :: repeats,warmup,i
  integer(int64) :: c0,c1,rate
  logical :: completed,committed,mass_complete
  integer :: kernel_status,accepted_substeps,solver_iterations,nonlinear,retries,backtracking,jacobians,linear,headcalc
  real(real64) :: mass_residual

  if(command_argument_count()<6) error stop 'F_PE_ELASTIC47_FAIL args'
  call get_command_argument(1,regime)
  call get_command_argument(2,arg); read(arg,*)h0
  call get_command_argument(3,arg); read(arg,*)delta
  call get_command_argument(4,arg); read(arg,*)duration
  call get_command_argument(5,arg); read(arg,*)repeats
  call get_command_argument(6,arg); read(arg,*)warmup
  call req(duration>0.0_real64.and.repeats>0.and.warmup>=0,'argument range')

  call init_base(p_off,{zarr},{dzarr})
  p_fixed=p_off
  p_fixed%elasticity_active=.true.
  p_fixed%cofgen(24,:)=1.0e-6_real64
  call fmr_prepare_application_parameters_with_elastic_storage('{fstr(cfg)}','{fstr(row)}', &
       p_off,p_generated,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated preparation')
  call req(all(ieee_is_finite(p_generated%cofgen(24,:))).and.all(p_generated%cofgen(24,:)>0.0_real64), &
       'generated finite positive')

  select case(trim(regime))
  case('OFF')
    p=p_off
  case('FIXED_1E6')
    p=p_fixed
  case('GENERATED')
    p=p_generated
  case default
    error stop 'F_PE_ELASTIC47_FAIL regime'
  end select
  call prepare_fmr_b110_default_mvg(p,completed)
  call req(completed,'prepare selected regime')

  do i=1,warmup
    call execute_once(p,h0,delta,duration,completed,committed,kernel_status,accepted_substeps,solver_iterations, &
         nonlinear,retries,backtracking,jacobians,linear,headcalc,mass_complete,mass_residual,checksum)
    if(.not.completed.or..not.committed) exit
  end do

  call system_clock(c0,rate)
  do i=1,repeats
    call execute_once(p,h0,delta,duration,completed,committed,kernel_status,accepted_substeps,solver_iterations, &
         nonlinear,retries,backtracking,jacobians,linear,headcalc,mass_complete,mass_residual,checksum)
    if(repeats>1) call req(completed.and.committed,'timed repeat completed')
  end do
  call system_clock(c1)
  elapsed=real(c1-c0,real64)/real(rate,real64)

  write(*,'(A,A,A,ES16.8,A,ES16.8,A,ES16.8,A,L1,A,L1,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,L1,A,ES16.8,A,ES18.9)') &
       'ELASTIC47_CASE|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',duration, &
       '|completed=',completed,'|committed=',committed,'|kernel_status=',kernel_status, &
       '|accepted_substeps=',accepted_substeps,'|solver_iterations=',solver_iterations, &
       '|nonlinear=',nonlinear,'|retries=',retries,'|backtracking=',backtracking, &
       '|jacobians=',jacobians,'|linear=',linear,'|headcalc=',headcalc, &
       '|mass_complete=',mass_complete,'|mass=',merge(mass_residual,0.0_real64,mass_complete), &
       '|checksum=',checksum
  if(repeats>1) then
    write(*,'(A,A,A,ES16.8,A,I0,A,F18.3,A,ES18.9)') 'ELASTIC47_TIMING|regime=',trim(regime), &
         '|dt=',duration,'|repeats=',repeats,'|ns_per_interval=',elapsed*1.0e9_real64/real(repeats,real64), &
         '|checksum=',checksum
  end if
  write(*,'(A)')'F_PE_ELASTIC47_EXEC=PASS'

contains

  subroutine init_base(q,zv,dzv)
    type(fmr_b110_physical_parameters_t),intent(out)::q
    real(real64),intent(in)::zv(N),dzv(N)
    integer::k
    q%parameter_set_id=COLUMN_ID
    q%active_nodes=N
    allocate(q%z(N),q%dz(N),q%node_distance(N),q%cofgen(24,N))
    q%z=zv;q%dz=dzv;q%cofgen=0.0_real64
    q%node_distance=0.0_real64
    do k=2,N;q%node_distance(k)=abs(q%z(k)-q%z(k-1));end do
    if(N>1)q%node_distance(1)=q%node_distance(2)
    do k=1,N
      q%cofgen(1,k)=0.032_real64
      q%cofgen(2,k)=0.423_real64
      q%cofgen(3,k)=4.75_real64
      q%cofgen(4,k)=0.0135_real64
      q%cofgen(5,k)=0.365_real64
      q%cofgen(6,k)=1.455_real64
      q%cofgen(7,k)=1.0_real64-1.0_real64/q%cofgen(6,k)
      q%cofgen(8,k)=q%cofgen(4,k)
      q%cofgen(9,k)=0.0_real64
      q%cofgen(10,k)=q%cofgen(3,k)
      q%cofgen(11,k)=0.999_real64
      q%cofgen(12,k)=0.99_real64*q%cofgen(3,k)
      q%cofgen(22,k)=-1.0e6_real64
      q%cofgen(23,k)=1.0e-12_real64
    end do
    q%bottom_mode=7
    q%swkimpl=0;q%swkmean=1;q%swsophy=0
    q%max_iterations=16;q%max_backtracking=8
    q%min_step_duration=1.0e-8_real64
    q%compartment_balance_tolerance=MASS_TOL
    q%total_balance_tolerance=MASS_TOL
    q%head_abs_tolerance=MASS_TOL
    q%head_rel_tolerance=MASS_TOL
    q%ponding_tolerance=MASS_TOL
    q%elasticity_active=.false.
  end subroutine

  subroutine execute_once(q,h,df,dt,completed,committed,kstatus,accepted,solvit,nlit,retr,back,jac,lin,hc, &
                          mcomplete,mres,checksum)
    type(fmr_b110_physical_parameters_t),intent(in)::q
    real(real64),intent(in)::h,df,dt
    logical,intent(out)::completed,committed,mcomplete
    integer,intent(out)::kstatus,accepted,solvit,nlit,retr,back,jac,lin,hc
    real(real64),intent(out)::mres,checksum
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(fmr_b110_physical_forcing_t)::forcing(1)
    type(fmr_b110_physical_parameters_t)::params(1)
    type(kernel_committed_state_t)::state_registry(1)
    type(fmr_serialized_column_result_t),allocatable::results(:)
    type(fmr_column_diagnostics_t),allocatable::diagnostics(:)
    type(fmr_aggregate_diagnostics_t)::aggregate
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_provider_t)::provider
    type(fixed_flux_top_boundary_provider_t),target::top
    type(canonical_numerical_config_t)::num
    real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),qeq
    integer::dispatch
    logical::ok

    completed=.false.;committed=.false.;mcomplete=.false.
    kstatus=-999;accepted=0;solvit=0;nlit=0;retr=0;back=0;jac=0;lin=0;hc=0;mres=0.0_real64;checksum=0.0_real64
    heads=h
    call bind_b110_default_mvg_provider(provider,q%prepared_default_mvg,dt)
    call provider%evaluate(heads,water,cond,cap,dk)
    call req(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)),'initial constitutive')
    qeq=-cond(1)
    state%active_nodes=N
    allocate(state%pressure_head(N),state%water_content(N))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=max(0.0_real64,h);state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(state_registry(1),COLUMN_ID,state,0.0_real64,ok)
    call req(ok,'committed init')

    call init_column(column,template)
    params(1)=q
    call init_forcing(forcing(1),qeq+df,qeq,h)
    call init_config(num)
    call fmr_run_serialized_physical_multiswap([column],[template],params,forcing,state_registry,num,top, &
         0.0_real64,dt,1,results,diagnostics,aggregate,dispatch,materialize_worker_assignments=.false., &
         materialize_summary_diagnostics=.false.,materialize_diagnostic_metadata=.false., &
         materialize_column_diagnostics=.false.,trusted_prepared_parameters=.true.)
    call req(dispatch==FMR_SERIAL_DISPATCH_OK.and.allocated(results).and.size(results)==1,'dispatch/result')
    completed=results(1)%completed
    committed=results(1)%committed
    kstatus=results(1)%kernel_status
    accepted=results(1)%accepted_substeps
    solvit=results(1)%solver_iterations
    nlit=results(1)%solver_nonlinear_iterations
    retr=results(1)%solver_internal_retries
    back=results(1)%solver_backtracking_attempts
    jac=results(1)%solver_jacobian_builds
    lin=results(1)%solver_linear_solves
    hc=results(1)%solver_headcalc_calls
    mcomplete=results(1)%mass%complete
    if(mcomplete)mres=results(1)%mass%residual
    checksum=results(1)%mass%storage_end+results(1)%mass%residual
    if(completed.and.committed) then
      call req(mcomplete.and.abs(mres)<=MASS_TOL,'completed mass')
    end if
  end subroutine

  subroutine init_column(column,template)
    type(fmr_logical_column_t),intent(out)::column
    type(fmr_template_t),intent(out)::template
    template%template_id=470001_int64
    template%physics_topology_id=470002_int64
    template%vertical_layout_id=470003_int64
    template%state_layout_id=470004_int64
    template%solver_interface_id=470005_int64
    template%optional_state_layout_id=0_int64
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=COLUMN_ID
    column%template_id=template%template_id
    column%parameter_ref=1_int64
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine init_forcing(f,topq,botq,h)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::topq,botq,h
    f%top_flux=topq;f%top_head=h;f%bottom_flux=botq;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine

  subroutine init_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=MASS_TOL
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%model_temporal_indicator_budget=0.0_real64
  end subroutine

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC47_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_elastic47_timestep_interaction
"""
    Path(a.fixture).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC47_PREP="+json.dumps({
        "profile_id":PROFILE_ID,
        "horizon_count":len(profile["horizons"]),
        "node_count":NODE_COUNT,
        "node_counts_by_horizon":counts,
        "row_file":str(row),
    },sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
