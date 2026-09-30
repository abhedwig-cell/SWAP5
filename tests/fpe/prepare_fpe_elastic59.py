#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, sys
from pathlib import Path

PROFILE_ID=90116260
X_RD=179362.75550490862
Y_RD=418659.84937244334
N=16

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None: raise SystemExit(f"F_PE_ELASTIC59_FAIL load {path}")
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod; spec.loader.exec_module(mod); return mod

def f64(x):
    s=format(float(x),".17g")
    if "." not in s and "e" not in s.lower(): s+=".0"
    return s+"_real64"

def fstr(x): return str(x).replace("'","''")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve(); tools=root/"tools"
    if str(tools) not in sys.path: sys.path.insert(0,str(tools))
    e24=load("el59_e24",tools/"fpe_elastic24_profile_retrieval.py")
    e41=load("el59_e41",tools/"fpe_elastic41_rd_application_handoff.py")
    p46=load("el59_p46",root/"tests/fpe/prepare_fpe_elastic46.py")

    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1: raise SystemExit(f"F_PE_ELASTIC59_FAIL gpkg hits={len(hits)}")
    gpkg=hits[0].resolve(); profile=e24.retrieve_profile(gpkg,PROFILE_ID)
    work=Path(a.work_dir).resolve(); work.mkdir(parents=True,exist_ok=True)
    row=work/"generated.rows"; prov=work/"generated.provenance.json"; cfg=work/"request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    r=e41.prepare_handoff(True,gpkg,X_RD,Y_RD,row,prov)
    if r["status"]!="OK": raise SystemExit("F_PE_ELASTIC59_FAIL handoff")
    z,dz,counts=p46.split_profile(profile["horizons"],N)
    nd=[abs(z[1]-z[0])]+[abs(z[i]-z[i-1]) for i in range(1,len(z))]
    Path(a.geometry_json).write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},
                                               sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")
    zarr="["+",".join(f64(v) for v in z)+"]"; dzarr="["+",".join(f64(v) for v in dz)+"]"

    src=f"""program test_fpe_elastic59_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_execute_serialized_resolved_physical_column
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: CERT=1, IDENTITY=2, CERT_NOHIST=3
  integer, parameter :: N=16, NREPLICA=5, NCALL=20
  integer(int64), parameter :: COLUMN_ID=590059_int64
  real(real64), parameter :: MASS_TOL=1.0e-12_real64
  real(real64), parameter :: DURATION=0.015625_real64
  real(real64), parameter :: H0=10.0_real64
  real(real64), parameter :: ALPHA=0.17320259355765216_real64
  real(real64), parameter :: HEAD_BUDGET=0.10_real64
  real(real64), parameter :: BINF_BUDGET=HEAD_BUDGET/ALPHA

  type(fmr_b110_physical_parameters_t) :: p_off,p_generated
  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag
  character(len=16) :: command
  logical :: ok

  if(command_argument_count()<1) error stop 'F_PE_ELASTIC59_FAIL command'
  call get_command_argument(1,command)
  call init_base(p_off,{zarr},{dzarr})
  call fmr_prepare_application_parameters_with_elastic_storage('{fstr(cfg)}','{fstr(row)}',p_off,p_generated,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated preparation')
  call req(p_generated%elasticity_active,'generated active')
  call prepare_fmr_b110_default_mvg(p_generated,ok); call req(ok,'prepare generated')
  write(*,'(A,ES24.16,A,ES24.16,A,ES24.16)')'ELASTIC59_META|ss_min=',minval(p_generated%cofgen(24,:)), &
       '|ss_max=',maxval(p_generated%cofgen(24,:)),'|binf_budget=',BINF_BUDGET

  select case(trim(command))
  case('cases')
    call run_cases(p_generated)
  case('timing')
    call run_timing(p_generated)
  case default
    error stop 'F_PE_ELASTIC59_FAIL unknown command'
  end select
  write(*,'(A)')'F_PE_ELASTIC59=PASS'

contains

  subroutine init_base(p,zv,dzv)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    real(real64),intent(in)::zv(N),dzv(N)
    integer::k
    p%parameter_set_id=COLUMN_ID;p%active_nodes=N
    allocate(p%z(N),p%dz(N),p%node_distance(N),p%cofgen(24,N))
    p%z=zv;p%dz=dzv;p%cofgen=0.0_real64;p%node_distance=0.0_real64
    do k=2,N;p%node_distance(k)=abs(p%z(k)-p%z(k-1));end do
    if(N>1)p%node_distance(1)=p%node_distance(2)
    do k=1,N
      p%cofgen(1,k)=0.032_real64;p%cofgen(2,k)=0.423_real64;p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64;p%cofgen(5,k)=0.365_real64;p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k);p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=p%cofgen(3,k);p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k);p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=MASS_TOL;p%total_balance_tolerance=MASS_TOL
    p%head_abs_tolerance=MASS_TOL;p%head_rel_tolerance=MASS_TOL;p%ponding_tolerance=MASS_TOL
    p%elasticity_active=.false.
  end subroutine

  subroutine run_cases(p)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_serialized_column_result_t)::o
    type(fmr_serialized_physical_observation_t)::obs
    call execute_case(CERT, 0.05_real64,p,.true.,o,obs)
    call req(o%completed.and.o%committed,'positive certificate completes')
    call req(o%mass%complete.and.abs(o%mass%residual)<=MASS_TOL,'positive certificate mass')
    call execute_case(CERT,-0.05_real64,p,.true.,o,obs)
    call req(o%completed.and.o%committed,'negative certificate completes')
    call req(o%mass%complete.and.abs(o%mass%residual)<=MASS_TOL,'negative certificate mass')
    call execute_case(IDENTITY, 0.05_real64,p,.true.,o,obs)
    call execute_case(IDENTITY,-0.05_real64,p,.true.,o,obs)
    call execute_case(CERT_NOHIST,0.05_real64,p,.true.,o,obs)
    call req(.not.o%committed,'no-history no commit')
    call req(trim(obs%temporal_certificate_unavailable_reason)=='history-unavailable','no-history reason')
    write(*,'(A)')'F_PE_ELASTIC59_CASES=PASS'
  end subroutine

  subroutine run_timing(p)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer::rep,k,mode
    real(real64)::delta,elapsed,checksum
    integer(int64)::c0,c1,rate
    type(fmr_serialized_column_result_t)::o
    type(fmr_serialized_physical_observation_t)::obs
    do rep=1,NREPLICA
      do mode=CERT,IDENTITY
        do k=1,2
          delta=merge(0.05_real64,-0.05_real64,k==1)
          checksum=0.0_real64
          call system_clock(c0,rate)
          do concurrent_dummy=1,1
          end do
          do concurrent_dummy=1,NCALL
            call execute_case(mode,delta,p,.false.,o,obs)
            checksum=checksum+merge(1.0_real64,0.0_real64,o%committed)+real(o%accepted_substeps,real64)
          end do
          call system_clock(c1)
          elapsed=real(c1-c0,real64)/real(rate,real64)
          write(*,'(A,A,A,ES14.6,A,I0,A,F18.3,A,ES18.9)')'ELASTIC59_TIMING|route=', &
               merge('CERT    ','IDENTITY',mode==CERT),'|delta=',delta,'|replica=',rep, &
               '|ns_per_interval=',elapsed*1.0e9_real64/real(NCALL,real64),'|checksum=',checksum
        end do
      end do
    end do
    write(*,'(A)')'F_PE_ELASTIC59_TIMING=PASS'
  end subroutine

  subroutine execute_case(mode,delta,p,emit,o,obs)
    integer,intent(in)::mode
    real(real64),intent(in)::delta
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(in)::emit
    type(fmr_serialized_column_result_t),intent(out)::o
    type(fmr_serialized_physical_observation_t),intent(out)::obs
    type(fmr_serialized_reference_backend_t)::backend
    type(kernel_executor_t)::transaction_control
    type(kernel_committed_state_t)::committed
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(fmr_b110_physical_forcing_t)::forcing
    type(canonical_numerical_config_t)::config
    type(fmr_column_diagnostics_t)::diagnostic
    type(fmr_serialized_batch_diagnostics_t)::runtime
    type(fixed_flux_top_boundary_provider_t),target::top
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),qeq,previous(N)
    integer::active_calls
    logical::state_ok

    heads=H0
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DURATION)
    call provider%evaluate(heads,water,cond,cap,dk)
    call req(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)),'initial constitutive')
    qeq=-cond(1)
    state%active_nodes=N;allocate(state%pressure_head(N),state%water_content(N))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=H0;state%groundwater_level=-2.0_real64
    previous=0.0_real64

    if(mode==IDENTITY)then
      call fmr_new_b110_committed_state(committed,COLUMN_ID,state,0.0_real64,state_ok)
    else if(mode==CERT)then
      call fmr_new_b110_temporal_indicator_committed_state(committed,COLUMN_ID,state,0.0_real64,state_ok,previous)
    else
      call fmr_new_b110_temporal_indicator_committed_state(committed,COLUMN_ID,state,0.0_real64,state_ok)
    end if
    call req(state_ok,'committed init')

    template%template_id=590001_int64;template%physics_topology_id=590002_int64
    template%vertical_layout_id=590003_int64;template%state_layout_id=590004_int64
    template%solver_interface_id=590005_int64;template%optional_state_layout_id=0_int64
    template%numerical_continuation_layout_id=merge(FMR_NUMERICAL_CONTINUATION_NONE, &
         FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY,mode==IDENTITY)
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=COLUMN_ID;column%template_id=template%template_id
    column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    forcing%top_flux=qeq+delta;forcing%top_head=H0
    forcing%bottom_flux=qeq;forcing%bottom_head=-999999.0_real64
    allocate(forcing%drainage_flux_by_level(1,N),forcing%subsurface_irrigation_source(N),forcing%root_extraction_sink(N))
    forcing%drainage_flux_by_level=0.0_real64;forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64

    if(mode==IDENTITY)then
      config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
      config%transaction%temporal_tolerance=1.0e-6_real64
      config%model_temporal_indicator_budget_available=.false.
      config%model_temporal_indicator_budget=0.0_real64
    else
      config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
      config%transaction%temporal_tolerance=0.0_real64
      config%model_temporal_indicator_budget_available=.true.
      config%model_temporal_indicator_budget=BINF_BUDGET
    end if
    config%transaction%mass_tolerance=MASS_TOL;config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=8;config%max_committed_substeps=32;config%progress_tolerance=0.0_real64

    o=fmr_serialized_column_result_t();o%column_id=COLUMN_ID;o%requested_t0=0.0_real64;o%requested_t1=DURATION
    diagnostic=fmr_column_diagnostics_t();diagnostic%column_id=COLUMN_ID
    runtime=fmr_serialized_batch_diagnostics_t();active_calls=0
    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend,transaction_control,column,template,p,forcing,committed, &
         config,0.0_real64,DURATION,o,diagnostic,runtime,active_calls)
    obs=backend%observation()

    if(emit)then
      write(*,'(*(g0))')'ELASTIC59_CASE|route=',merge('CERT    ','IDENTITY',mode/=IDENTITY), &
        '|seeded=',mode==CERT,'|delta=',delta,'|completed=',o%completed,'|committed=',o%committed, &
        '|kernel_status=',o%kernel_status,'|accepted_substeps=',o%accepted_substeps, &
        '|final_time=',o%final_committed_time,'|nonlinear=',o%solver_nonlinear_iterations, &
        '|linear=',o%solver_linear_solves,'|headcalc=',o%solver_headcalc_calls,'|backtracking=',o%solver_backtracking_attempts, &
        '|mass_complete=',o%mass%complete,'|mass=',merge(o%mass%residual,0.0_real64,o%mass%complete), &
        '|indicator_enabled=',obs%temporal_indicator_enabled,'|history_available=',obs%temporal_previous_derivative_available, &
        '|certificate_available=',obs%temporal_certificate_available,'|binf=',obs%temporal_head_inf_bound, &
        '|normalized=',obs%temporal_normalized_indicator,'|cert_reason=',trim(obs%temporal_certificate_unavailable_reason), &
        '|extra_tridiag=',obs%temporal_additional_tridiagonal_solves, &
        '|extra_full=',obs%temporal_additional_full_nonlinear_solves
    end if
  end subroutine

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then;write(*,'(A,1X,A)')'F_PE_ELASTIC59_FAIL',trim(msg);error stop 1;end if
  end subroutine

end program test_fpe_elastic59_runtime
"""
    # Replace invalid dummy-loop symbol with an ordinary declared loop construct.
    src=src.replace("    integer::rep,k,mode\n","    integer::rep,k,mode,concurrent_dummy\n")
    Path(a.fixture).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC59_PREP="+json.dumps({"profile_id":PROFILE_ID,"node_counts_by_horizon":counts,
          "binf_budget":0.10/0.17320259355765216},sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
