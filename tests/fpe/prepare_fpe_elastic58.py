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
        "--geometry-json",str(Path(a.geometry_json).resolve())
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    # Add independent reference trajectory state/output objects.
    old="""  type(soil_water_solve_result_t)::res_full,res_half1,res_half2
"""
    new="""  type(soil_water_solve_result_t)::res_full,res_half1,res_half2
  type(soil_water_physical_state_t)::ref8_state,ref16_state
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL type anchor")
    s=s.replace(old,new,1)

    old="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
"""
    new="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  real(real64)::href16,href8_16,thetaref16,storage_ref_signed,storage_ref_l1
  logical::ref8_ok,ref16_ok,ref_stable
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL real anchor")
    s=s.replace(old,new,1)

    # Run ref8/ref16 after candidate full solve and indicator creation, before half-step work.
    anchor="""  call bind_b110_default_mvg_provider(constitutive_half,p%prepared_default_mvg,0.5_real64*dt)
"""
    insert="""  call run_reference_trajectory(p,h0,delta,dt,8,ref8_state,ref8_ok)
  call run_reference_trajectory(p,h0,delta,dt,16,ref16_state,ref16_ok)
  href16=0.0_real64;href8_16=0.0_real64;thetaref16=0.0_real64
  storage_ref_signed=0.0_real64;storage_ref_l1=0.0_real64;ref_stable=.false.
  if(res_full%status==SW_SOLVE_CONVERGED.and.ref8_ok.and.ref16_ok)then
    href16=maxval(abs(res_full%candidate_state%pressure_head-ref16_state%pressure_head))
    href8_16=maxval(abs(ref8_state%pressure_head-ref16_state%pressure_head))
    thetaref16=maxval(abs(res_full%candidate_state%water_content-ref16_state%water_content))
    storage_ref_signed=abs(sum((res_full%candidate_state%water_content-ref16_state%water_content)*p%dz))
    storage_ref_l1=sum(abs(res_full%candidate_state%water_content-ref16_state%water_content)*p%dz)
    ref_stable=href8_16<=max(1.0e-5_real64,0.1_real64*href16)
  end if

"""
    if anchor not in s: raise SystemExit("F_PE_ELASTIC58_FAIL half anchor")
    s=s.replace(anchor,insert+anchor,1)

    # Extend output.
    old="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
"""
    new="""       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|ref8_ok=',ref8_ok,'|ref16_ok=',ref16_ok,'|ref_stable=',ref_stable, &
       '|href16=',href16,'|href8_16=',href8_16,'|thetaref16=',thetaref16, &
       '|storage_ref_signed=',storage_ref_signed,'|storage_ref_l1=',storage_ref_l1, &
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC58_FAIL output anchor")
    s=s.replace(old,new,1)
    s=s.replace("'ELASTIC55_BANK|profile=", "'ELASTIC58_BANK|profile=",1)
    s=s.replace("'F_PE_ELASTIC55_EXEC=PASS'","'F_PE_ELASTIC58_EXEC=PASS'",1)

    # Insert reference trajectory helper before init_base.
    anchor2="""  subroutine init_base(q,zv,dzv)
"""
    helper=r"""
  subroutine run_reference_trajectory(q,hstart,df,total_dt,nsteps,final_state,ok)
    type(fmr_b110_physical_parameters_t),intent(in)::q
    real(real64),intent(in)::hstart,df,total_dt
    integer,intent(in)::nsteps
    type(soil_water_physical_state_t),intent(out)::final_state
    logical,intent(out)::ok
    type(soil_water_parameter_set_t),target::sref
    type(b110_default_mvg_provider_t),target::cref,cinit
    type(b110_source_sink_provider_t),target::src_ref
    type(fixed_flux_top_boundary_provider_t),target::top_ref
    type(reference_richards_legacy_solver_t)::sol_ref
    type(reference_richards_legacy_workspace_t)::ws_ref
    type(soil_water_solve_request_t)::rq
    type(soil_water_solve_result_t)::rr
    type(soil_water_physical_state_t)::state_cur
    real(real64),target::dra_ref(1,N),ss_ref(N),root_ref(N)
    real(real64)::hh(N),ww(N),kk(N),cc(N),dd(N),qeq_ref,subdt
    integer::j

    ok=.false.
    final_state=soil_water_physical_state_t()
    if(nsteps<=0.or.total_dt<=0.0_real64)return
    subdt=total_dt/real(nsteps,real64)
    call init_soil(sref,q)
    dra_ref=0.0_real64;ss_ref=0.0_real64;root_ref=0.0_real64
    call bind_b110_source_sink_provider(src_ref,dra_ref,ss_ref,root_ref)
    call bind_b110_default_mvg_provider(cinit,q%prepared_default_mvg,subdt)
    hh=hstart
    call cinit%evaluate(hh,ww,kk,cc,dd)
    if(any(.not.ieee_is_finite(ww)).or.any(.not.ieee_is_finite(kk)))return
    qeq_ref=-kk(1)
    state_cur%active_nodes=N
    allocate(state_cur%pressure_head(N),state_cur%water_content(N))
    state_cur%pressure_head=hh;state_cur%water_content=ww
    state_cur%ponding_depth=max(0.0_real64,hstart);state_cur%groundwater_level=-2.0_real64
    call bind_b110_default_mvg_provider(cref,q%prepared_default_mvg,subdt)
    do j=1,nsteps
      call make_request_from_state(rq,sref,cref,src_ref,top_ref,state_cur,hstart,qeq_ref+df,qeq_ref,subdt)
      call sol_ref%solve(rq,ws_ref,rr)
      if(rr%status/=SW_SOLVE_CONVERGED)return
      state_cur=rr%candidate_state
    end do
    final_state=state_cur
    ok=.true.
  end subroutine

"""
    if anchor2 not in s: raise SystemExit("F_PE_ELASTIC58_FAIL helper anchor")
    s=s.replace(anchor2,helper+anchor2,1)

    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC58_PREP=PASS")

if __name__=="__main__":
    main()
