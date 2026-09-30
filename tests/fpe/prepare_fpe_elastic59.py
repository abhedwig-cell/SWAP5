#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--profile-id",required=True,type=int)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve()
    fixture=Path(a.fixture).resolve()

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/prepare_fpe_elastic55.py"),"profile",
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--profile-id",str(a.profile_id),
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve()),
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    old="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  integer::ih,itheta,i
  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect
"""
    new="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  real(real64)::h_real_ref16,h_oracle_8_16
  integer::ih,itheta,i
  logical::all_converged,exact_identity,indicator_available,ref8_ok,ref16_ok,oracle_complete
  real(real64)::indicator_binf,indicator_raw,indicator_defect
  type(soil_water_physical_state_t)::ref8_state,ref16_state
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL declaration anchor")
    s=s.replace(old,new,1)

    old="""  all_converged=res_full%status==SW_SOLVE_CONVERGED.and.res_half1%status==SW_SOLVE_CONVERGED.and. &
       res_half2%status==SW_SOLVE_CONVERGED

  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
"""
    new="""  all_converged=res_full%status==SW_SOLVE_CONVERGED.and.res_half1%status==SW_SOLVE_CONVERGED.and. &
       res_half2%status==SW_SOLVE_CONVERGED

  ref8_ok=.false.;ref16_ok=.false.;oracle_complete=.false.
  h_real_ref16=0.0_real64;h_oracle_8_16=0.0_real64
  call integrate_refined_path(p,soil,source_sink,top,heads,water,h0,qeq+delta,qeq,dt,8,ref8_state,ref8_ok)
  call integrate_refined_path(p,soil,source_sink,top,heads,water,h0,qeq+delta,qeq,dt,16,ref16_state,ref16_ok)
  if(res_full%status==SW_SOLVE_CONVERGED.and.ref8_ok.and.ref16_ok)then
    h_real_ref16=maxval(abs(res_full%candidate_state%pressure_head-ref16_state%pressure_head))
    h_oracle_8_16=maxval(abs(ref8_state%pressure_head-ref16_state%pressure_head))
    oracle_complete=ieee_is_finite(h_real_ref16).and.ieee_is_finite(h_oracle_8_16)
    call req(oracle_complete.and.h_real_ref16>=0.0_real64.and.h_oracle_8_16>=0.0_real64,'finite refined oracle')
  end if

  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL solve anchor")
    s=s.replace(old,new,1)

    old="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
"""
    new="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|ref8_ok=',ref8_ok,'|ref16_ok=',ref16_ok,'|oracle_complete=',oracle_complete, &
       '|h_real_ref16=',h_real_ref16,'|h_oracle_8_16=',h_oracle_8_16, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL output anchor")
    s=s.replace(old,new,1)
    s=s.replace("'ELASTIC55_BANK|profile=","'ELASTIC59_BANK|profile=",1)
    s=s.replace("'F_PE_ELASTIC55_EXEC=PASS'","'F_PE_ELASTIC59_EXEC=PASS'",1)

    anchor="""  subroutine init_base(q,zv,dzv)
"""
    helper="""  subroutine integrate_refined_path(q,s,src,tp,h,w,forcing_head,qtop,qbot,total_dt,nsub,endpoint,ok)
    type(fmr_b110_physical_parameters_t),intent(in)::q
    type(soil_water_parameter_set_t),target,intent(in)::s
    type(b110_source_sink_provider_t),target,intent(in)::src
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    real(real64),intent(in)::h(N),w(N),forcing_head,qtop,qbot,total_dt
    integer,intent(in)::nsub
    type(soil_water_physical_state_t),intent(out)::endpoint
    logical,intent(out)::ok
    type(b110_default_mvg_provider_t),target::constitutive
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::r
    type(soil_water_solve_result_t)::result
    type(soil_water_physical_state_t)::state
    real(real64)::step
    integer::j

    ok=.false.
    endpoint=soil_water_physical_state_t()
    if(nsub<=0.or.total_dt<=0.0_real64)return
    step=total_dt/real(nsub,real64)
    call bind_b110_default_mvg_provider(constitutive,q%prepared_default_mvg,step)
    call make_request(r,s,constitutive,src,tp,h,w,forcing_head,qtop,qbot,step)
    call solver%solve(r,workspace,result)
    if(result%status/=SW_SOLVE_CONVERGED)return
    state=result%candidate_state
    do j=2,nsub
      call make_request_from_state(r,s,constitutive,src,tp,state,forcing_head,qtop,qbot,step)
      call solver%solve(r,workspace,result)
      if(result%status/=SW_SOLVE_CONVERGED)return
      state=result%candidate_state
    end do
    endpoint=state
    ok=allocated(endpoint%pressure_head).and.size(endpoint%pressure_head)==N.and. &
       all(ieee_is_finite(endpoint%pressure_head)).and.allocated(endpoint%water_content).and. &
       all(ieee_is_finite(endpoint%water_content))
  end subroutine

"""
    if anchor not in s: raise SystemExit("F_PE_ELASTIC59_FAIL helper anchor")
    s=s.replace(anchor,helper+anchor,1)

    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC59_PREP=PASS")

if __name__=="__main__":
    main()
