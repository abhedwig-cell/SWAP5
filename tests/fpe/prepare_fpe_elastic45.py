#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, sys
from pathlib import Path

PROFILE_ID=90116260
SOURCE_HASH="f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6"

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC45_FAIL cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def f64(x):
    s=format(float(x),".17g")
    if "e" not in s.lower() and "." not in s:
        s += ".0"
    return s+"_real64"

def fstr(s):
    return str(s).replace("'","''")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root); tools=root/"tools"
    sys.path.insert(0,str(tools))
    e24=load("fpe_elastic24_profile_retrieval",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("fpe_elastic33_profile_row_interchange",tools/"fpe_elastic33_profile_row_interchange.py")
    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC45_FAIL gpkg hits={len(hits)}")
    gpkg=hits[0]
    profile=e24.retrieve_profile(gpkg,PROFILE_ID)
    if profile["source_artifact_sha256"]!=SOURCE_HASH:
        raise SystemExit("F_PE_ELASTIC45_FAIL source hash")
    if int(profile["normalsoilprofile_id"])!=PROFILE_ID:
        raise SystemExit("F_PE_ELASTIC45_FAIL profile identity")
    if not all(h["organic_matter_pct"] is not None and float(h["organic_matter_pct"])<=15.0 and h["peat_type"] is None
               for h in profile["horizons"]):
        raise SystemExit("F_PE_ELASTIC45_FAIL selected profile no longer mineral")
    work=Path(a.work_dir); work.mkdir(parents=True,exist_ok=True)
    rows=work/"profile-90116260.rows"
    rows.write_text(e33.materialize_interchange(profile),encoding="utf-8")
    cfg=work/"request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    z=[]; dz=[]; blocks=[]
    for h in profile["horizons"]:
        top=float(h["top_depth_m"]); bottom=float(h["bottom_depth_m"])
        z.append(-0.5*(top+bottom)*100.0)
        dz.append((bottom-top)*100.0)
        blocks.append(int(h["staringseriesblock"]))
    n=len(z)
    zarr="["+",".join(f64(v) for v in z)+"]"
    dzarr="["+",".join(f64(v) for v in dz)+"]"
    barr="["+",".join(str(v) for v in blocks)+"]"

    src=f"""program test_fpe_elastic45_production_characterization
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_runtime_core, only: FMR_NUMERICAL_CONTINUATION_NONE, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fmr_serialized_reference_backend, only: prepare_fmr_b110_default_mvg
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  use mod_fmr_elastic_storage_staringseriesblock_map, only: &
       fmr_map_staringseriesblock_to_catalog, FMR_STARINGSERIESBLOCK_OK
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: fmr_elastic_storage_retention_t
  use mod_fmr_elastic_storage_staringreeks_catalog, only: &
       fmr_lookup_staringreeks_retention, FMR_STARINGREEKS_CATALOG_OK
  implicit none
  integer, parameter :: N={n}
  real(real64), parameter :: T0=9200.0_real64,T1=9200.02_real64,H0=2.0_real64
  real(real64), parameter :: MASS_TOL=1.0e-10_real64
  real(real64), parameter :: ZV(N)={zarr}, DZV(N)={dzarr}
  integer, parameter :: BLOCKS(N)={barr}
  type(fmr_b110_physical_parameters_t) :: base,p_off,p_manual,p_generated
  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag
  type(fmr_serialized_column_result_t) :: r_off,r_manual,r_generated
  real(real64) :: generated_min,generated_max,generated_mean

  call init_base(base)
  p_off=base
  p_off%elasticity_active=.false.
  p_off%cofgen(24,:)=0.0_real64
  p_manual=base
  p_manual%elasticity_active=.true.
  p_manual%cofgen(24,:)=1.0e-6_real64
  call fmr_prepare_application_parameters_with_elastic_storage('{fstr(cfg.as_posix())}', &
       '{fstr(rows.as_posix())}',base,p_generated,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'A2 generated binding')
  call req(all(p_generated%cofgen(24,:)>0.0_real64),'A2 positive')
  generated_min=minval(p_generated%cofgen(24,:))
  generated_max=maxval(p_generated%cofgen(24,:))
  generated_mean=sum(p_generated%cofgen(24,:))/real(N,real64)
  write(*,'(A,I0)')'F_PE_ELASTIC45_PROFILE_ID=',{PROFILE_ID}
  write(*,'(A,ES24.16)')'F_PE_ELASTIC45_GENERATED_MIN=',generated_min
  write(*,'(A,ES24.16)')'F_PE_ELASTIC45_GENERATED_MEAN=',generated_mean
  write(*,'(A,ES24.16)')'F_PE_ELASTIC45_GENERATED_MAX=',generated_max
  write(*,'(A)')'F_PE_ELASTIC45_A2_GENERATED=PASS'
  call req(.not.p_off%elasticity_active.and.all(p_off%cofgen(24,:)==0.0_real64),'A3 off')
  call req(p_manual%elasticity_active.and.all(p_manual%cofgen(24,:)==1.0e-6_real64),'A3 manual')
  write(*,'(A)')'F_PE_ELASTIC45_A3_VARIANTS=PASS'

  call run_case('OFF',p_off,r_off)
  call run_case('MANUAL_1E6',p_manual,r_manual)
  call run_case('GENERATED',p_generated,r_generated)

  call req(r_off%completed.and.r_off%committed,'A5 off')
  call req(r_manual%completed.and.r_manual%committed,'A5 manual')
  call req(r_generated%completed.and.r_generated%committed,'A5 generated')
  call req(abs(r_off%mass%residual)<=MASS_TOL,'A5 mass off')
  call req(abs(r_manual%mass%residual)<=MASS_TOL,'A5 mass manual')
  call req(abs(r_generated%mass%residual)<=MASS_TOL,'A5 mass generated')
  write(*,'(A)')'F_PE_ELASTIC45_A5_ALL_COMMITTED=PASS'
  write(*,'(A)')'F_PE_ELASTIC45_A6_METRICS=PASS'
  write(*,'(A)')'F_PE_ELASTIC45=PASS'

contains
  subroutine init_base(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    type(fmr_elastic_storage_retention_t)::ret
    character(len=3)::code
    integer::i,idx,s1,s2
    p%parameter_set_id=990450_int64
    p%active_nodes=N
    allocate(p%z(N),p%dz(N),p%node_distance(N),p%cofgen(24,N))
    p%z=ZV;p%dz=DZV;p%node_distance=max(1.0_real64,DZV);p%cofgen=0.0_real64
    do i=1,N
      call fmr_map_staringseriesblock_to_catalog(BLOCKS(i),code,idx,s1)
      call req(s1==FMR_STARINGSERIESBLOCK_OK,'catalog block')
      call fmr_lookup_staringreeks_retention(code,ret,idx,s2)
      call req(s2==FMR_STARINGREEKS_CATALOG_OK,'catalog retention')
      p%cofgen(1,i)=ret%wcr
      p%cofgen(2,i)=ret%wcs
      p%cofgen(3,i)=10.0_real64
      p%cofgen(4,i)=ret%alpha_cm_inv
      p%cofgen(5,i)=0.5_real64
      p%cofgen(6,i)=ret%npar
      p%cofgen(7,i)=1.0_real64-1.0_real64/ret%npar
      p%cofgen(8,i)=ret%alpha_cm_inv
      p%cofgen(9,i)=0.0_real64
      p%cofgen(10,i)=10.0_real64
      p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=9.9_real64
      p%cofgen(22,i)=-1.0e6_real64
      p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=7
    p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=24;p%max_backtracking=10
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=MASS_TOL
    p%total_balance_tolerance=MASS_TOL
    p%head_abs_tolerance=1.0e-10_real64
    p%head_rel_tolerance=1.0e-10_real64
    p%ponding_tolerance=1.0e-10_real64
    p%elasticity_active=.false.
  end subroutine init_base

  subroutine run_case(label,p,result)
    character(len=*),intent(in)::label
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_serialized_column_result_t),intent(out)::result
    type(fmr_production_application_config_t)::cfg
    type(fmr_production_application_bootstrap_t)::app
    type(fmr_serialized_column_result_t),allocatable::results(:)
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),qeq
    logical::ok
    integer::status
    call initialize_config(cfg,p,provider,heads,water,cond,cap,dk,qeq)
    call app%initialize(cfg,status)
    call req(status==FMR_APP_BOOT_OK.and.app%ready(),'bootstrap '//trim(label))
    call app%run_standalone(T0,T1,results,status)
    call req(status==FMR_APP_BOOT_OK.and.allocated(results).and.size(results)==1,'run '//trim(label))
    result=results(1)
    call emit_metrics(label,result,water)
    call app%close(status)
    call req(status==FMR_APP_BOOT_OK,'close '//trim(label))
  end subroutine run_case

  subroutine initialize_config(value,p,provider,heads,water,cond,cap,dk,qeq)
    type(fmr_production_application_config_t),intent(out)::value
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(b110_default_mvg_provider_t),intent(out)::provider
    real(real64),intent(out)::heads(N),water(N),cond(N),cap(N),dk(N),qeq
    logical::ok
    value%initial_time=T0
    value%numerical%transaction%temporal_tolerance=0.0_real64
    value%numerical%transaction%mass_tolerance=MASS_TOL
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=3
    value%numerical%max_committed_substeps=16
    value%numerical%progress_tolerance=0.0_real64
    allocate(value%tiles(1))
    value%tiles(1)%tile_id=990451_int64
    value%tiles(1)%template%template_id=990452_int64
    value%tiles(1)%template%physics_topology_id=990453_int64
    value%tiles(1)%template%vertical_layout_id=990454_int64
    value%tiles(1)%template%state_layout_id=990455_int64
    value%tiles(1)%template%solver_interface_id=990456_int64
    value%tiles(1)%template%optional_state_layout_id=0_int64
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    value%tiles(1)%parameters=p
    call prepare_fmr_b110_default_mvg(value%tiles(1)%parameters,ok)
    call req(ok.and.value%tiles(1)%parameters%prepared_default_mvg_available,'prepare')
    call bind_b110_default_mvg_provider(provider,value%tiles(1)%parameters%prepared_default_mvg,T1-T0)
    heads=H0
    call provider%evaluate(heads,water,cond,cap,dk)
    qeq=-cond(1)
    value%tiles(1)%initial_state%active_nodes=N
    allocate(value%tiles(1)%initial_state%pressure_head(N),value%tiles(1)%initial_state%water_content(N))
    value%tiles(1)%initial_state%pressure_head=heads
    value%tiles(1)%initial_state%water_content=water
    value%tiles(1)%initial_state%ponding_depth=0.0_real64
    value%tiles(1)%initial_state%groundwater_level=-2.0_real64
    value%tiles(1)%base_forcing%top_flux=0.95_real64*qeq
    value%tiles(1)%base_forcing%top_head=H0
    value%tiles(1)%base_forcing%bottom_flux=qeq
    value%tiles(1)%base_forcing%bottom_head=-999999.0_real64
    allocate(value%tiles(1)%base_forcing%drainage_flux_by_level(1,N), &
         value%tiles(1)%base_forcing%subsurface_irrigation_source(N), &
         value%tiles(1)%base_forcing%root_extraction_sink(N))
    value%tiles(1)%base_forcing%drainage_flux_by_level=0.0_real64
    value%tiles(1)%base_forcing%subsurface_irrigation_source=0.0_real64
    value%tiles(1)%base_forcing%root_extraction_sink=0.0_real64
  end subroutine initialize_config

  subroutine emit_metrics(label,r,initial_water)
    character(len=*),intent(in)::label
    type(fmr_serialized_column_result_t),intent(in)::r
    real(real64),intent(in)::initial_water(N)
    write(*,'(A,A,A,L1,A,L1,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0)') &
      'F_PE_ELASTIC45_METRIC|',trim(label),'|completed=',r%completed,'|committed=',r%committed, &
      '|substeps=',r%accepted_substeps,'|solver_iterations=',r%solver_iterations, &
      '|nonlinear=',r%solver_nonlinear_iterations,'|internal_retries=',r%solver_internal_retries, &
      '|headcalc=',r%solver_headcalc_calls,'|jacobian=',r%solver_jacobian_builds, &
      '|linear=',r%solver_linear_solves,'|backtracking=',r%solver_backtracking_attempts
    write(*,'(A,A,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16)') &
      'F_PE_ELASTIC45_MASS|',trim(label),'|storage_start=',r%mass%storage_start, &
      '|storage_end=',r%mass%storage_end,'|total_in=',r%mass%total_in, &
      '|total_out=',r%mass%total_out,'|residual=',r%mass%residual, &
      '|initial_water_mean=',sum(initial_water)/real(N,real64)
  end subroutine emit_metrics

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC45_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic45_production_characterization
"""
    Path(a.fixture).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC45_A1_SOURCE_PROFILE=PASS")
    print(f"F_PE_ELASTIC45_HORIZONS={n}")
    print("F_PE_ELASTIC45_PREP=PASS")

if __name__=="__main__":
    main()
