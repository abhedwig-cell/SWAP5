#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

PROFILE_ID = 90116260
X_RD = 179362.75550490862
Y_RD = 418659.84937244334
NODE_COUNT = 16

def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC46_FAIL cannot load {path}")
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

def split_profile(horizons: list[dict], n_nodes: int):
    if len(horizons) > n_nodes:
        raise SystemExit("F_PE_ELASTIC46_FAIL more horizons than nodes")
    counts = [1] * len(horizons)
    remaining = n_nodes - len(horizons)
    thickness = [float(h["bottom_depth_m"]) - float(h["top_depth_m"]) for h in horizons]
    while remaining:
        scores = [thickness[i] / counts[i] for i in range(len(horizons))]
        k = max(range(len(scores)), key=lambda i: (scores[i], -i))
        counts[k] += 1
        remaining -= 1
    z_cm=[]
    dz_cm=[]
    for h,count in zip(horizons,counts):
        top=float(h["top_depth_m"])
        bottom=float(h["bottom_depth_m"])
        step=(bottom-top)/count
        for j in range(count):
            a=top+j*step
            b=top+(j+1)*step
            z_cm.append(-0.5*(a+b)*100.0)
            dz_cm.append((b-a)*100.0)
    if len(z_cm)!=n_nodes:
        raise SystemExit("F_PE_ELASTIC46_FAIL node split")
    return z_cm,dz_cm,counts

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    a=ap.parse_args()

    root=Path(a.repo_root).resolve()
    tools=root/"tools"
    if str(tools) not in sys.path:
        sys.path.insert(0,str(tools))
    e24=load("fpe_elastic24_profile_retrieval",tools/"fpe_elastic24_profile_retrieval.py")
    e41=load("fpe_elastic41_rd_application_handoff",tools/"fpe_elastic41_rd_application_handoff.py")

    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC46_FAIL gpkg hits={len(hits)}")
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
        raise SystemExit("F_PE_ELASTIC46_FAIL ELASTIC41 handoff")
    manifest=json.loads(prov.read_text(encoding="utf-8"))
    if int(manifest["normalsoilprofile_id"])!=PROFILE_ID:
        raise SystemExit("F_PE_ELASTIC46_FAIL selected profile")
    z,dz,counts=split_profile(profile["horizons"],NODE_COUNT)

    zarr="["+",".join(f64(v) for v in z)+"]"
    dzarr="["+",".join(f64(v) for v in dz)+"]"

    lines=[
"program test_fpe_elastic46_production_effect",
"  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite",
"  use, intrinsic :: iso_fortran_env, only: int64, real64",
"  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF",
"  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &",
"       kernel_candidate_state_t, kernel_diagnostics_t",
"  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint",
"  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &",
"       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &",
"       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &",
"       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg",
"  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &",
"       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK",
"  use mod_fmr_elastic_storage_application_host_binding, only: &",
"       fmr_elastic_storage_application_host_diagnostics_t, &",
"       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK",
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider",
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t",
"  implicit none",
"",
"  integer, parameter :: N=16, NSTATE=4, NPERT=3, NREG=3, NREPLICA=5, NCALL=1000",
"  real(real64), parameter :: MASS_TOL=1.0e-12_real64, DURATION=0.25_real64",
"  integer(int64), parameter :: COLUMN_ID=460046_int64",
"  real(real64), parameter :: HSTATES(NSTATE)=[-75.0_real64,0.1_real64,2.0_real64,10.0_real64]",
"  real(real64), parameter :: PERT(NPERT)=[0.0_real64,0.05_real64,-0.05_real64]",
"",
"  type(fmr_b110_physical_parameters_t) :: p_off,p_fixed,p_generated",
"  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag",
"  integer :: i,j,r",
"",
f"  call init_base(p_off,{zarr},{dzarr})",
"  p_fixed=p_off",
"  p_fixed%elasticity_active=.true.",
"  p_fixed%cofgen(24,:)=1.0e-6_real64",
f"  call fmr_prepare_application_parameters_with_elastic_storage('{fstr(cfg)}','{fstr(row)}', &",
"       p_off,p_generated,hdiag)",
"  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated preparation')",
"  call req(p_generated%elasticity_active,'generated active')",
"  call req(all(ieee_is_finite(p_generated%cofgen(24,:))).and.all(p_generated%cofgen(24,:)>0.0_real64), &",
"       'generated finite positive')",
"  write(*,'(A,ES24.16,A,ES24.16,A,ES24.16)') 'F_PE_ELASTIC46_GENERATED_SS|min=',minval(p_generated%cofgen(24,:)), &",
"       '|median_proxy=',p_generated%cofgen(24,(N+1)/2),'|max=',maxval(p_generated%cofgen(24,:))",
"  write(*,'(A)')'F_PE_ELASTIC46_A1_GENERATED_PREPARATION=PASS'",
"",
"  call prepare_all(p_off,p_fixed,p_generated)",
"  do i=1,NSTATE",
"    do j=1,NPERT",
"      call run_case('OFF',p_off,HSTATES(i),PERT(j))",
"      call run_case('FIXED_1E6',p_fixed,HSTATES(i),PERT(j))",
"      call run_case('GENERATED',p_generated,HSTATES(i),PERT(j))",
"    end do",
"  end do",
"  write(*,'(A)')'F_PE_ELASTIC46_A2_BANK_EXECUTED=PASS'",
"  write(*,'(A)')'F_PE_ELASTIC46_A3_MASS_GATE=PASS'",
"  write(*,'(A)')'F_PE_ELASTIC46_A5_COUNTERS=PASS'",
"",
"  do r=1,NREPLICA",
"    call time_regime('OFF',p_off,r)",
"    call time_regime('FIXED_1E6',p_fixed,r)",
"    call time_regime('GENERATED',p_generated,r)",
"  end do",
"  write(*,'(A)')'F_PE_ELASTIC46_A6_TIMING=PASS'",
"  write(*,'(A)')'F_PE_ELASTIC46=PASS'",
"",
"contains",
"",
"  subroutine init_base(p,zv,dzv)",
"    type(fmr_b110_physical_parameters_t),intent(out)::p",
"    real(real64),intent(in)::zv(N),dzv(N)",
"    integer::k",
"    p%parameter_set_id=COLUMN_ID",
"    p%active_nodes=N",
"    allocate(p%z(N),p%dz(N),p%node_distance(N),p%cofgen(24,N))",
"    p%z=zv; p%dz=dzv; p%cofgen=0.0_real64",
"    p%node_distance=0.0_real64",
"    do k=2,N; p%node_distance(k)=abs(p%z(k)-p%z(k-1)); end do",
"    if(N>1)p%node_distance(1)=p%node_distance(2)",
"    do k=1,N",
"      p%cofgen(1,k)=0.032_real64",
"      p%cofgen(2,k)=0.423_real64",
"      p%cofgen(3,k)=4.75_real64",
"      p%cofgen(4,k)=0.0135_real64",
"      p%cofgen(5,k)=0.365_real64",
"      p%cofgen(6,k)=1.455_real64",
"      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)",
"      p%cofgen(8,k)=p%cofgen(4,k)",
"      p%cofgen(9,k)=0.0_real64",
"      p%cofgen(10,k)=p%cofgen(3,k)",
"      p%cofgen(11,k)=0.999_real64",
"      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)",
"      p%cofgen(22,k)=-1.0e6_real64",
"      p%cofgen(23,k)=1.0e-12_real64",
"    end do",
"    p%bottom_mode=7",
"    p%swkimpl=0;p%swkmean=1;p%swsophy=0",
"    p%max_iterations=16;p%max_backtracking=8",
"    p%min_step_duration=1.0e-8_real64",
"    p%compartment_balance_tolerance=MASS_TOL",
"    p%total_balance_tolerance=MASS_TOL",
"    p%head_abs_tolerance=MASS_TOL",
"    p%head_rel_tolerance=MASS_TOL",
"    p%ponding_tolerance=MASS_TOL",
"    p%elasticity_active=.false.",
"  end subroutine init_base",
"",
"  subroutine prepare_all(a,b,c)",
"    type(fmr_b110_physical_parameters_t),intent(inout)::a,b,c",
"    logical::ok",
"    call prepare_fmr_b110_default_mvg(a,ok); call req(ok,'prepare off')",
"    call prepare_fmr_b110_default_mvg(b,ok); call req(ok,'prepare fixed')",
"    call prepare_fmr_b110_default_mvg(c,ok); call req(ok,'prepare generated')",
"  end subroutine prepare_all",
"",
"  subroutine run_case(label,p,h0,delta)",
"    character(len=*),intent(in)::label",
"    type(fmr_b110_physical_parameters_t),intent(in)::p",
"    real(real64),intent(in)::h0,delta",
"    type(fmr_logical_column_t)::column",
"    type(fmr_template_t)::template",
"    type(fmr_b110_physical_forcing_t)::forcing(1)",
"    type(fmr_b110_physical_parameters_t)::params(1)",
"    type(kernel_committed_state_t)::committed(1)",
"    type(fmr_serialized_column_result_t),allocatable::results(:)",
"    type(fixed_flux_top_boundary_provider_t),target::top",
"    type(canonical_numerical_config_t)::cfgnum",
"    type(fmr_b110_physical_state_t)::state",
"    type(b110_default_mvg_provider_t)::provider",
"    real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),qeq",
"    integer::dispatch",
"    logical::ok",
"",
"    heads=h0",
"    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DURATION)",
"    call provider%evaluate(heads,water,cond,cap,dk)",
"    call req(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)),'initial constitutive')",
"    qeq=-cond(1)",
"    state%active_nodes=N; allocate(state%pressure_head(N),state%water_content(N))",
"    state%pressure_head=heads; state%water_content=water",
"    state%ponding_depth=max(0.0_real64,h0)",
"    state%groundwater_level=-2.0_real64",
"    call fmr_new_b110_committed_state(committed(1),COLUMN_ID,state,0.0_real64,ok)",
"    call req(ok,'committed init')",
"    call init_column(column,template)",
"    params(1)=p",
"    call init_forcing(forcing(1),qeq+delta,qeq,h0)",
"    call init_config(cfgnum)",
"    call fmr_run_serialized_physical_multiswap([column],[template],params,forcing,committed,cfgnum,top, &",
"         0.0_real64,DURATION,1,results,dispatch_status=dispatch,materialize_worker_assignments=.false., &",
"         materialize_summary_diagnostics=.false.,materialize_diagnostic_metadata=.false., &",
"         materialize_column_diagnostics=.false.,trusted_prepared_parameters=.true.)",
"    call req(dispatch==FMR_SERIAL_DISPATCH_OK,'dispatch')",
"    call req(allocated(results).and.size(results)==1,'result shape')",
"    call req(results(1)%status==CANONICAL_STATUS_COMPLETED.and.results(1)%completed.and.results(1)%committed, &",
"         'case completed')",
"    call req(abs(results(1)%mass%residual)<=MASS_TOL,'case mass')",
"    write(*,'(A,A,A,ES14.6,A,ES14.6,A,L1,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,ES14.6)') &",
"      'ELASTIC46_CASE|regime=',trim(label),'|h0=',h0,'|delta=',delta,'|committed=',results(1)%committed, &",
"      '|accepted_substeps=',results(1)%accepted_substeps,'|solver_iterations=',results(1)%solver_iterations, &",
"      '|nonlinear=',results(1)%solver_nonlinear_iterations,'|retries=',results(1)%solver_internal_retries, &",
"      '|backtracking=',results(1)%solver_backtracking_attempts,'|jacobians=',results(1)%solver_jacobian_builds, &",
"      '|headcalc=',results(1)%solver_headcalc_calls,'|mass=',results(1)%mass%residual",
"  end subroutine run_case",
"",
"  subroutine time_regime(label,p,replica)",
"    character(len=*),intent(in)::label",
"    type(fmr_b110_physical_parameters_t),intent(in)::p",
"    integer,intent(in)::replica",
"    type(fmr_logical_column_t)::column",
"    type(fmr_template_t)::template",
"    type(canonical_numerical_config_t)::cfgnum",
"    type(kernel_committed_state_t)::committed",
"    type(kernel_checkpoint_t)::checkpoint",
"    type(kernel_result_t)::result",
"    type(kernel_candidate_state_t)::candidate",
"    type(kernel_diagnostics_t)::diag",
"    type(fmr_serialized_reference_backend_t)::backend",
"    type(fixed_flux_top_boundary_provider_t),target::top",
"    type(fmr_b110_physical_forcing_t)::forcing",
"    type(fmr_b110_physical_state_t)::state",
"    type(b110_default_mvg_provider_t)::provider",
"    real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),qeq,elapsed,checksum",
"    integer(int64)::c0,c1,rate",
"    integer::k,warm",
"    logical::ok",
"",
"    heads=2.0_real64",
"    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DURATION)",
"    call provider%evaluate(heads,water,cond,cap,dk)",
"    qeq=-cond(1)",
"    state%active_nodes=N; allocate(state%pressure_head(N),state%water_content(N))",
"    state%pressure_head=heads; state%water_content=water",
"    state%ponding_depth=2.0_real64; state%groundwater_level=-2.0_real64",
"    call fmr_new_b110_committed_state(committed,COLUMN_ID,state,0.0_real64,ok); call req(ok,'timing init')",
"    call fmr_capture_checkpoint(committed,checkpoint,ok); call req(ok,'timing checkpoint')",
"    call init_column(column,template); call init_forcing(forcing,qeq+0.05_real64,qeq,2.0_real64)",
"    call init_config(cfgnum); call backend%initialize(top)",
"    warm=50",
"    do k=1,warm",
"      call backend%run_trial(column,template,p,committed,forcing,cfgnum,0.0_real64,DURATION,checkpoint, &",
"           result,candidate,diag)",
"    end do",
"    checksum=0.0_real64",
"    call system_clock(c0,rate)",
"    do k=1,NCALL",
"      call backend%run_trial(column,template,p,committed,forcing,cfgnum,0.0_real64,DURATION,checkpoint, &",
"           result,candidate,diag)",
"      checksum=checksum+result%mass%storage_end+result%mass%residual",
"    end do",
"    call system_clock(c1)",
"    elapsed=real(c1-c0,real64)/real(rate,real64)",
"    call req(result%status==CANONICAL_STATUS_COMPLETED.and.result%completed,'timing completed')",
"    write(*,'(A,A,A,I0,A,F18.3,A,ES18.9)')'ELASTIC46_TIMING|regime=',trim(label),'|replica=',replica, &",
"         '|ns_per_interval=',elapsed*1.0e9_real64/real(NCALL,real64),'|checksum=',checksum",
"  end subroutine time_regime",
"",
"  subroutine init_column(column,template)",
"    type(fmr_logical_column_t),intent(out)::column",
"    type(fmr_template_t),intent(out)::template",
"    template%template_id=460001_int64; template%physics_topology_id=460002_int64",
"    template%vertical_layout_id=460003_int64; template%state_layout_id=460004_int64",
"    template%solver_interface_id=460005_int64; template%optional_state_layout_id=0_int64",
"    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE",
"    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE",
"    column%column_id=COLUMN_ID; column%template_id=template%template_id",
"    column%parameter_ref=1_int64; column%state_handle=1_int64; column%forcing_handle=1_int64",
"    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE",
"  end subroutine init_column",
"",
"  subroutine init_forcing(f,topq,botq,h0)",
"    type(fmr_b110_physical_forcing_t),intent(out)::f",
"    real(real64),intent(in)::topq,botq,h0",
"    f%top_flux=topq; f%top_head=h0; f%bottom_flux=botq; f%bottom_head=-999999.0_real64",
"    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))",
"    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64",
"    f%root_extraction_sink=0.0_real64",
"  end subroutine init_forcing",
"",
"  subroutine init_config(c)",
"    type(canonical_numerical_config_t),intent(out)::c",
"    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF",
"    c%transaction%temporal_tolerance=1.0e-6_real64",
"    c%transaction%mass_tolerance=MASS_TOL",
"    c%transaction%retry_scale=0.5_real64",
"    c%transaction%max_retries=8",
"    c%max_committed_substeps=32",
"    c%progress_tolerance=0.0_real64",
"    c%model_temporal_indicator_budget_available=.false.",
"    c%model_temporal_indicator_budget=0.0_real64",
"  end subroutine init_config",
"",
"  subroutine req(cond,msg)",
"    logical,intent(in)::cond",
"    character(len=*),intent(in)::msg",
"    if(.not.cond)then; write(*,'(A,1X,A)')'F_PE_ELASTIC46_FAIL',trim(msg); error stop 1; end if",
"  end subroutine req",
"",
"end program test_fpe_elastic46_production_effect",
]
    Path(a.fixture).write_text("\n".join(lines)+"\n",encoding="utf-8")
    print("F_PE_ELASTIC46_PREP="+json.dumps({
        "profile_id":PROFILE_ID,
        "horizon_count":len(profile["horizons"]),
        "node_count":NODE_COUNT,
        "node_counts_by_horizon":counts,
        "row_file":str(row),
    },sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
