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
        raise SystemExit(f"F_PE_ELASTIC50_FAIL cannot load {path}")
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
        raise SystemExit(f"F_PE_ELASTIC50_FAIL gpkg hits={len(hits)}")
    gpkg=hits[0].resolve()
    profile=e24.retrieve_profile(gpkg,PROFILE_ID)
    work=Path(a.work_dir).resolve()
    work.mkdir(parents=True,exist_ok=True)
    row=work/"generated.rows"; prov=work/"generated.provenance.json"; cfg=work/"request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    result=e41.prepare_handoff(True,gpkg,X_RD,Y_RD,row,prov)
    if result["status"]!="OK":
        raise SystemExit("F_PE_ELASTIC50_FAIL handoff")

    z,dz,counts=p46.split_profile(profile["horizons"],N)
    nd=[abs(z[1]-z[0])]+[abs(z[i]-z[i-1]) for i in range(1,len(z))]
    Path(a.geometry_json).write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},
        sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")
    zarr="["+",".join(f64(v) for v in z)+"]"
    dzarr="["+",".join(f64(v) for v in dz)+"]"

    src=f"""program test_fpe_elastic50_full_half_discrepancy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, prepare_fmr_b110_default_mvg
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  implicit none

  integer, parameter :: N=16
  real(real64), parameter :: MASS_TOL=1.0e-12_real64
  integer(int64), parameter :: PARAM_ID=500050_int64

  type(fmr_b110_physical_parameters_t)::p_off,p_fixed,p_generated,p
  type(fmr_elastic_storage_application_host_diagnostics_t)::hdiag
  type(soil_water_parameter_set_t),target::soil
  type(reference_richards_legacy_solver_t)::solver_full,solver_half
  type(reference_richards_legacy_workspace_t)::ws_full,ws_half
  type(b110_default_mvg_provider_t),target::constitutive_full,constitutive_half,constitutive_init
  type(b110_source_sink_provider_t),target::source_sink
  type(fixed_flux_top_boundary_provider_t),target::top
  type(soil_water_solve_request_t)::req_full,req_half1,req_half2
  type(soil_water_solve_result_t)::res_full,res_half1,res_half2
  real(real64),target::drainage(1,N),ss(N),root(N)
  real(real64)::heads(N),water(N),cond(N),cap(N),dk(N),h0,delta,dt,qeq
  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  integer::ih,itheta,i
  logical::all_converged,exact_identity
  character(len=32)::regime
  character(len=64)::arg

  if(command_argument_count()<4) error stop 'F_PE_ELASTIC50_FAIL args'
  call get_command_argument(1,regime)
  call get_command_argument(2,arg);read(arg,*)h0
  call get_command_argument(3,arg);read(arg,*)delta
  call get_command_argument(4,arg);read(arg,*)dt
  call req(dt>0.0_real64,'dt')

  call init_base(p_off,{zarr},{dzarr})
  p_fixed=p_off
  p_fixed%elasticity_active=.true.
  p_fixed%cofgen(24,:)=1.0e-6_real64
  call fmr_prepare_application_parameters_with_elastic_storage('{fstr(cfg)}','{fstr(row)}', &
       p_off,p_generated,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated preparation')

  select case(trim(regime))
  case('OFF');p=p_off
  case('FIXED_1E6');p=p_fixed
  case('GENERATED');p=p_generated
  case default;error stop 'F_PE_ELASTIC50_FAIL regime'
  end select
  call prepare_fmr_b110_default_mvg(p,all_converged)
  call req(all_converged,'prepare')

  call init_soil(soil,p)
  drainage=0.0_real64;ss=0.0_real64;root=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,ss,root)
  call bind_b110_default_mvg_provider(constitutive_init,p%prepared_default_mvg,dt)
  heads=h0
  call constitutive_init%evaluate(heads,water,cond,cap,dk)
  call req(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)),'initial constitutive')
  qeq=-cond(1)

  call bind_b110_default_mvg_provider(constitutive_full,p%prepared_default_mvg,dt)
  call make_request(req_full,soil,constitutive_full,source_sink,top,heads,water,h0,qeq+delta,qeq,dt)
  call solver_full%solve(req_full,ws_full,res_full)

  call bind_b110_default_mvg_provider(constitutive_half,p%prepared_default_mvg,0.5_real64*dt)
  call make_request(req_half1,soil,constitutive_half,source_sink,top,heads,water,h0,qeq+delta,qeq,0.5_real64*dt)
  call solver_half%solve(req_half1,ws_half,res_half1)

  res_half2=soil_water_solve_result_t()
  if(res_half1%status==SW_SOLVE_CONVERGED)then
    call make_request_from_state(req_half2,soil,constitutive_half,source_sink,top,res_half1%candidate_state, &
         h0,qeq+delta,qeq,0.5_real64*dt)
    call solver_half%solve(req_half2,ws_half,res_half2)
  end if

  all_converged=res_full%status==SW_SOLVE_CONVERGED.and.res_half1%status==SW_SOLVE_CONVERGED.and. &
       res_half2%status==SW_SOLVE_CONVERGED

  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;storage_half=0.0_real64;ih=0;itheta=0;exact_identity=.false.
  if(all_converged)then
    dh_inf=maxval(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head))
    ih=maxloc(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head),dim=1)
    dtheta_inf=maxval(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content))
    itheta=maxloc(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content),dim=1)
    dpond=abs(res_full%candidate_state%ponding_depth-res_half2%candidate_state%ponding_depth)
    dgwl=abs(res_full%candidate_state%groundwater_level-res_half2%candidate_state%groundwater_level)
    storage_full=sum(res_full%candidate_state%water_content*p%dz)
    storage_half=sum(res_half2%candidate_state%water_content*p%dz)
    exact_identity=all(same_bits(res_full%candidate_state%pressure_head,res_half2%candidate_state%pressure_head)).and. &
       all(same_bits(res_full%candidate_state%water_content,res_half2%candidate_state%water_content)).and. &
       same_scalar_bits(res_full%candidate_state%ponding_depth,res_half2%candidate_state%ponding_depth).and. &
       same_scalar_bits(res_full%candidate_state%groundwater_level,res_half2%candidate_state%groundwater_level)
    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf).and.ieee_is_finite(dpond).and.ieee_is_finite(dgwl), &
         'finite discrepancy')
  end if

  write(*,'(*(g0))')'ELASTIC50_DIFF|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
       '|full_status=',res_full%status,'|half1_status=',res_half1%status,'|half2_status=',res_half2%status, &
       '|all_converged=',all_converged,'|dh_inf=',dh_inf,'|dh_node=',ih,'|dtheta_inf=',dtheta_inf, &
       '|dtheta_node=',itheta,'|dpond=',dpond,'|dgwl=',dgwl,'|storage_full=',storage_full, &
       '|storage_half=',storage_half,'|exact_identity=',exact_identity, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
       '|half2_nonlinear=',res_half2%diagnostics%nonlinear_iterations
  write(*,'(A)')'F_PE_ELASTIC50_EXEC=PASS'

contains

  subroutine init_base(q,zv,dzv)
    type(fmr_b110_physical_parameters_t),intent(out)::q
    real(real64),intent(in)::zv(N),dzv(N)
    integer::k
    q%parameter_set_id=PARAM_ID;q%active_nodes=N
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

  subroutine init_soil(s,q)
    type(soil_water_parameter_set_t),intent(out),target::s
    type(fmr_b110_physical_parameters_t),intent(in)::q
    s%parameter_set_id=q%parameter_set_id;s%active_nodes=q%active_nodes
    allocate(s%z(N),s%dz(N),s%node_distance(N))
    s%z=q%z;s%dz=q%dz;s%node_distance=q%node_distance
  end subroutine

  subroutine make_request(r,s,c,src,tp,h,w,pond,qtop,qbot,step)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::s
    type(b110_default_mvg_provider_t),target,intent(in)::c
    type(b110_source_sink_provider_t),target,intent(in)::src
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    real(real64),intent(in)::h(N),w(N),pond,qtop,qbot,step
    r%parameters=>s;r%base_state%active_nodes=N
    allocate(r%base_state%pressure_head(N),r%base_state%water_content(N))
    r%base_state%pressure_head=h;r%base_state%water_content=w
    r%base_state%ponding_depth=max(0.0_real64,pond);r%base_state%groundwater_level=-2.0_real64
    r%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;r%boundary%bottom_mode=7
    r%boundary%top_flux=qtop;r%boundary%top_head=pond;r%boundary%bottom_flux=qbot;r%boundary%bottom_head=-999999.0_real64
    call finish_request(r,c,src,tp,step)
  end subroutine

  subroutine make_request_from_state(r,s,c,src,tp,state,forcing_top_head,qtop,qbot,step)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::s
    type(b110_default_mvg_provider_t),target,intent(in)::c
    type(b110_source_sink_provider_t),target,intent(in)::src
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    type(soil_water_physical_state_t),intent(in)::state
    real(real64),intent(in)::forcing_top_head,qtop,qbot,step
    r%parameters=>s;r%base_state=state
    r%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;r%boundary%bottom_mode=7
    r%boundary%top_flux=qtop;r%boundary%top_head=forcing_top_head
    r%boundary%bottom_flux=qbot;r%boundary%bottom_head=-999999.0_real64
    call finish_request(r,c,src,tp,step)
  end subroutine

  subroutine finish_request(r,c,src,tp,step)
    type(soil_water_solve_request_t),intent(inout)::r
    type(b110_default_mvg_provider_t),target,intent(in)::c
    type(b110_source_sink_provider_t),target,intent(in)::src
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    real(real64),intent(in)::step
    r%evaluation%constitutive=>c;r%evaluation%source_sink=>src;r%evaluation%top_boundary=>tp
    r%physical%macropore_active=.false.;r%step_duration=step
    r%numerical%max_iterations=16;r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0;r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=MASS_TOL;r%numerical%total_balance_tolerance=MASS_TOL
    r%numerical%head_abs_tolerance=MASS_TOL;r%numerical%head_rel_tolerance=MASS_TOL
    r%numerical%ponding_tolerance=MASS_TOL
  end subroutine

  elemental logical function same_bits(a,b)
    real(real64),intent(in)::a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function
  logical function same_scalar_bits(a,b)
    real(real64),intent(in)::a,b
    same_scalar_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then;write(*,'(A,1X,A)')'F_PE_ELASTIC50_FAIL',trim(msg);error stop 1;end if
  end subroutine
end program test_fpe_elastic50_full_half_discrepancy
"""
    Path(a.fixture).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC50_PREP="+json.dumps({"profile_id":PROFILE_ID,"node_counts_by_horizon":counts},
        sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
