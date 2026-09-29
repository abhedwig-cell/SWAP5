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
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC48_FAIL cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def f64(x):
    s=format(float(x),".17g")
    if "." not in s and "e" not in s.lower():
        s+=".0"
    return s+"_real64"

def fstr(x):
    return str(x).replace("'","''")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve()
    tools=root/"tools"
    if str(tools) not in sys.path:
        sys.path.insert(0,str(tools))
    p46=load("fpe_elastic46_parent",root/"tests/fpe/prepare_fpe_elastic46.py")
    e24=load("fpe_elastic24_profile_retrieval",tools/"fpe_elastic24_profile_retrieval.py")
    e41=load("fpe_elastic41_rd_application_handoff",tools/"fpe_elastic41_rd_application_handoff.py")
    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC48_FAIL gpkg hits={len(hits)}")
    gpkg=hits[0].resolve()
    profile=e24.retrieve_profile(gpkg,PROFILE_ID)
    work=Path(a.work_dir).resolve(); work.mkdir(parents=True,exist_ok=True)
    row=work/"generated.rows"; prov=work/"generated.provenance.json"; cfg=work/"request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    result=e41.prepare_handoff(True,gpkg,X_RD,Y_RD,row,prov)
    if result["status"]!="OK":
        raise SystemExit("F_PE_ELASTIC48_FAIL handoff")
    z,dz,counts=p46.split_profile(profile["horizons"],N)
    nd=[abs(z[1]-z[0])]+[abs(z[i]-z[i-1]) for i in range(1,len(z))]
    Path(a.geometry_json).write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},
        sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")
    zarr="["+",".join(f64(v) for v in z)+"]"
    dzarr="["+",".join(f64(v) for v in dz)+"]"

    src=f"""program test_fpe_elastic48_failure_attribution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none
  integer, parameter :: N=16
  real(real64), parameter :: DT=0.015625_real64, MASS_TOL=1.0e-12_real64
  integer(int64), parameter :: COLUMN_ID=480048_int64

  type(fmr_b110_physical_parameters_t)::p_off,p_fixed,p_generated,p
  type(fmr_elastic_storage_application_host_diagnostics_t)::hdiag
  type(fmr_b110_physical_forcing_t)::forcing
  type(fmr_b110_physical_state_t)::state
  type(fmr_logical_column_t)::column
  type(fmr_template_t)::template
  type(kernel_committed_state_t)::committed
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_result_t)::result
  type(kernel_candidate_state_t)::candidate
  type(kernel_diagnostics_t)::diag
  type(fmr_serialized_reference_backend_t)::backend
  type(fmr_serialized_physical_observation_t)::obs
  type(fixed_flux_top_boundary_provider_t),target::top
  type(b110_default_mvg_provider_t)::provider
  type(canonical_numerical_config_t)::num
  real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),h0,delta,qeq
  character(len=32)::regime
  character(len=64)::arg
    logical::ok

  if(command_argument_count()<3) error stop 'F_PE_ELASTIC48_FAIL args'
  call get_command_argument(1,regime)
  call get_command_argument(2,arg);read(arg,*)h0
  call get_command_argument(3,arg);read(arg,*)delta

  call init_base(p_off,{zarr},{dzarr})
  p_fixed=p_off
  p_fixed%elasticity_active=.true.
  p_fixed%cofgen(24,:)=1.0e-6_real64
  call fmr_prepare_application_parameters_with_elastic_storage('{fstr(cfg)}','{fstr(row)}', &
       p_off,p_generated,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated preparation')

  select case(trim(regime))
  case('OFF'); p=p_off
  case('FIXED_1E6'); p=p_fixed
  case('GENERATED'); p=p_generated
  case default; error stop 'F_PE_ELASTIC48_FAIL regime'
  end select
  call prepare_fmr_b110_default_mvg(p,ok);call req(ok,'prepare')

  heads=h0
  call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DT)
  call provider%evaluate(heads,water,cond,cap,dk)
  qeq=-cond(1)
  state%active_nodes=N
  allocate(state%pressure_head(N),state%water_content(N))
  state%pressure_head=heads;state%water_content=water
  state%ponding_depth=max(0.0_real64,h0);state%groundwater_level=-2.0_real64
  call fmr_new_b110_committed_state(committed,COLUMN_ID,state,0.0_real64,ok);call req(ok,'committed')
  call fmr_capture_checkpoint(committed,checkpoint,ok);call req(ok,'checkpoint')
  call init_column(column,template)
  call init_forcing(forcing,qeq+delta,qeq,h0)
  call init_config(num)
  call backend%initialize(top)
  call backend%run_trial(column,template,p,committed,forcing,num,0.0_real64,DT,checkpoint,result,candidate,diag, &
       trusted_prepared_parameters=.true.)
  obs=backend%observation()

  write(*,'(*(g0))') &
    'ELASTIC48_ATTR|regime=',trim(regime),'|h0=',h0,'|delta=',delta, &
    '|kernel_status=',result%status,'|completed=',result%completed,'|candidate_ready=',candidate%ready(), &
    '|transaction_calls=',diag%transaction_calls,'|attempts=',diag%attempts,'|retries=',diag%retries, &
    '|solver_rejections=',diag%solver_rejections,'|temporal_rejections=',diag%temporal_rejections, &
    '|temporal_unavailable=',diag%temporal_certificate_unavailable_rejections,'|mass_rejections=',diag%mass_rejections, &
    '|admission_rejections=',diag%admission_rejections,'|checkpoint_rejections=',diag%checkpoint_rejections, &
    '|nonlinear=',diag%nonlinear_iterations,'|internal_retries=',diag%internal_retries,'|headcalc=',diag%headcalc_calls, &
    '|jacobians=',diag%jacobian_builds,'|linear=',diag%linear_solves,'|backtracking=',diag%backtracking_attempts, &
    '|solver_executed=',obs%solver_executed,'|route=',trim(obs%solver_diagnostics%route), &
    '|mass_complete=',result%mass%complete,'|mass_finite=',ieee_is_finite(result%mass%residual),'|mass=',result%mass%residual
  write(*,'(A)')'F_PE_ELASTIC48_EXEC=PASS'
contains
  subroutine init_base(q,zv,dzv)
    type(fmr_b110_physical_parameters_t),intent(out)::q
    real(real64),intent(in)::zv(N),dzv(N)
    integer::k
    q%parameter_set_id=COLUMN_ID;q%active_nodes=N
    allocate(q%z(N),q%dz(N),q%node_distance(N),q%cofgen(24,N))
    q%z=zv;q%dz=dzv;q%cofgen=0.0_real64;q%node_distance=0.0_real64
    do k=2,N;q%node_distance(k)=abs(q%z(k)-q%z(k-1));end do
    if(N>1)q%node_distance(1)=q%node_distance(2)
    do k=1,N
      q%cofgen(1,k)=0.032_real64;q%cofgen(2,k)=0.423_real64;q%cofgen(3,k)=4.75_real64
      q%cofgen(4,k)=0.0135_real64;q%cofgen(5,k)=0.365_real64;q%cofgen(6,k)=1.455_real64
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
  subroutine init_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=480001_int64;t%physics_topology_id=480002_int64;t%vertical_layout_id=480003_int64
    t%state_layout_id=480004_int64;t%solver_interface_id=480005_int64;t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=COLUMN_ID;c%template_id=t%template_id;c%parameter_ref=1_int64;c%state_handle=1_int64
    c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine
  subroutine init_forcing(f,tq,bq,h)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::tq,bq,h
    f%top_flux=tq;f%top_head=h;f%bottom_flux=bq;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine
  subroutine init_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64;c%transaction%mass_tolerance=MASS_TOL
    c%transaction%retry_scale=0.5_real64;c%transaction%max_retries=8
    c%max_committed_substeps=32;c%progress_tolerance=0.0_real64
  end subroutine
  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then;write(*,'(A,1X,A)')'F_PE_ELASTIC48_FAIL',trim(msg);error stop 1;end if
  end subroutine
end program test_fpe_elastic48_failure_attribution
"""
    Path(a.fixture).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC48_PREP="+json.dumps({"profile_id":PROFILE_ID,"node_counts_by_horizon":counts},
        sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
