#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve()
    fixture=Path(a.fixture).resolve()

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/prepare_fpe_elastic50.py"),
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve())
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    old="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  integer::ih,itheta,i
"""
    new="""  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half
  real(real64)::qtop_fixed
  real(real64)::full_dh1,half1_dh1,half2_dh1,full_dtheta1,half1_dtheta1,half2_dtheta1
  real(real64)::full_storage_rate1,half1_storage_rate1,half2_storage_rate1,twohalf_storage_rate1
  real(real64)::full_internal_flux1,half1_internal_flux1,half2_internal_flux1,twohalf_internal_flux1
  real(real64)::terminal_dh1,storage_rate_diff1,internal_flux_diff1
  real(real64)::ratio_full,ratio_half1,ratio_half2,ss_node1
  real(real64)::full_h1_out,half1_h1_out,half2_h1_out,full_h2_out,half1_h2_out,half2_h2_out
  integer::ih,itheta,i
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC52_FAIL decl anchor")
    s=s.replace(old,new,1)

    old="""  qeq=-cond(1)

  call bind_b110_default_mvg_provider(constitutive_full,p%prepared_default_mvg,dt)
"""
    new="""  qeq=-cond(1)
  qtop_fixed=qeq+delta
  ss_node1=p%cofgen(24,1)

  call bind_b110_default_mvg_provider(constitutive_full,p%prepared_default_mvg,dt)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC52_FAIL qtop anchor")
    s=s.replace(old,new,1)

    old="""  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;storage_half=0.0_real64;ih=0;itheta=0;exact_identity=.false.
"""
    new="""  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;storage_half=0.0_real64;ih=0;itheta=0;exact_identity=.false.
  full_dh1=0.0_real64;half1_dh1=0.0_real64;half2_dh1=0.0_real64
  full_dtheta1=0.0_real64;half1_dtheta1=0.0_real64;half2_dtheta1=0.0_real64
  full_storage_rate1=0.0_real64;half1_storage_rate1=0.0_real64;half2_storage_rate1=0.0_real64
  twohalf_storage_rate1=0.0_real64
  full_internal_flux1=0.0_real64;half1_internal_flux1=0.0_real64;half2_internal_flux1=0.0_real64
  twohalf_internal_flux1=0.0_real64;terminal_dh1=0.0_real64;storage_rate_diff1=0.0_real64
  internal_flux_diff1=0.0_real64;ratio_full=0.0_real64;ratio_half1=0.0_real64;ratio_half2=0.0_real64
  full_h1_out=0.0_real64;half1_h1_out=0.0_real64;half2_h1_out=0.0_real64
  full_h2_out=0.0_real64;half1_h2_out=0.0_real64;half2_h2_out=0.0_real64
  if(res_full%status==SW_SOLVE_CONVERGED)then
    full_h1_out=res_full%candidate_state%pressure_head(1)
    full_h2_out=res_full%candidate_state%pressure_head(2)
  end if
  if(res_half1%status==SW_SOLVE_CONVERGED)then
    half1_h1_out=res_half1%candidate_state%pressure_head(1)
    half1_h2_out=res_half1%candidate_state%pressure_head(2)
  end if
  if(res_half2%status==SW_SOLVE_CONVERGED)then
    half2_h1_out=res_half2%candidate_state%pressure_head(1)
    half2_h2_out=res_half2%candidate_state%pressure_head(2)
  end if
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC52_FAIL init anchor")
    s=s.replace(old,new,1)

    old="""  if(all_converged)then
    dh_inf=maxval(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head))
"""
    new="""  if(all_converged)then
    full_dh1=res_full%candidate_state%pressure_head(1)-heads(1)
    half1_dh1=res_half1%candidate_state%pressure_head(1)-heads(1)
    half2_dh1=res_half2%candidate_state%pressure_head(1)-res_half1%candidate_state%pressure_head(1)
    full_dtheta1=res_full%candidate_state%water_content(1)-water(1)
    half1_dtheta1=res_half1%candidate_state%water_content(1)-water(1)
    half2_dtheta1=res_half2%candidate_state%water_content(1)-res_half1%candidate_state%water_content(1)
    full_storage_rate1=p%dz(1)*full_dtheta1/dt
    half1_storage_rate1=p%dz(1)*half1_dtheta1/(0.5_real64*dt)
    half2_storage_rate1=p%dz(1)*half2_dtheta1/(0.5_real64*dt)
    twohalf_storage_rate1=p%dz(1)*(res_half2%candidate_state%water_content(1)-water(1))/dt
    full_internal_flux1=-qtop_fixed-full_storage_rate1
    half1_internal_flux1=-qtop_fixed-half1_storage_rate1
    half2_internal_flux1=-qtop_fixed-half2_storage_rate1
    twohalf_internal_flux1=-qtop_fixed-twohalf_storage_rate1
    terminal_dh1=res_full%candidate_state%pressure_head(1)-res_half2%candidate_state%pressure_head(1)
    storage_rate_diff1=full_storage_rate1-twohalf_storage_rate1
    internal_flux_diff1=full_internal_flux1-twohalf_internal_flux1
    if(abs(full_dh1)>0.0_real64) ratio_full=full_dtheta1/full_dh1
    if(abs(half1_dh1)>0.0_real64) ratio_half1=half1_dtheta1/half1_dh1
    if(abs(half2_dh1)>0.0_real64) ratio_half2=half2_dtheta1/half2_dh1
    dh_inf=maxval(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head))
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC52_FAIL calc anchor")
    s=s.replace(old,new,1)

    old="""    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf).and.ieee_is_finite(dpond).and.ieee_is_finite(dgwl), &
         'finite discrepancy')
"""
    new="""    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf).and.ieee_is_finite(dpond).and.ieee_is_finite(dgwl), &
         'finite discrepancy')
    call req(ieee_is_finite(full_storage_rate1).and.ieee_is_finite(half1_storage_rate1).and. &
         ieee_is_finite(half2_storage_rate1).and.ieee_is_finite(twohalf_storage_rate1).and. &
         ieee_is_finite(full_internal_flux1).and.ieee_is_finite(half1_internal_flux1).and. &
         ieee_is_finite(half2_internal_flux1).and.ieee_is_finite(twohalf_internal_flux1),'finite mechanism terms')
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC52_FAIL finite anchor")
    s=s.replace(old,new,1)

    old="""  write(*,'(*(g0))')'ELASTIC50_DIFF|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
       '|full_status=',res_full%status,'|half1_status=',res_half1%status,'|half2_status=',res_half2%status, &
       '|all_converged=',all_converged,'|dh_inf=',dh_inf,'|dh_node=',ih,'|dtheta_inf=',dtheta_inf, &
       '|dtheta_node=',itheta,'|dpond=',dpond,'|dgwl=',dgwl,'|storage_full=',storage_full, &
       '|storage_half=',storage_half,'|exact_identity=',exact_identity, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
       '|half2_nonlinear=',res_half2%diagnostics%nonlinear_iterations
  write(*,'(A)')'F_PE_ELASTIC50_EXEC=PASS'
"""
    new="""  write(*,'(*(g0))')'ELASTIC52_MECH|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
       '|full_status=',res_full%status,'|half1_status=',res_half1%status,'|half2_status=',res_half2%status, &
       '|all_converged=',all_converged,'|qtop=',qtop_fixed,'|ss1=',ss_node1, &
       '|full_h1=',full_h1_out,'|half1_h1=',half1_h1_out,'|half2_h1=',half2_h1_out, &
       '|full_h2=',full_h2_out,'|half1_h2=',half1_h2_out,'|half2_h2=',half2_h2_out, &
       '|full_dh1=',full_dh1,'|half1_dh1=',half1_dh1,'|half2_dh1=',half2_dh1, &
       '|full_dtheta1=',full_dtheta1,'|half1_dtheta1=',half1_dtheta1,'|half2_dtheta1=',half2_dtheta1, &
       '|full_storage_rate1=',full_storage_rate1,'|half1_storage_rate1=',half1_storage_rate1, &
       '|half2_storage_rate1=',half2_storage_rate1,'|twohalf_storage_rate1=',twohalf_storage_rate1, &
       '|full_internal_flux1=',full_internal_flux1,'|half1_internal_flux1=',half1_internal_flux1, &
       '|half2_internal_flux1=',half2_internal_flux1,'|twohalf_internal_flux1=',twohalf_internal_flux1, &
       '|terminal_dh1=',terminal_dh1,'|storage_rate_diff1=',storage_rate_diff1, &
       '|internal_flux_diff1=',internal_flux_diff1,'|ratio_full=',ratio_full,'|ratio_half1=',ratio_half1, &
       '|ratio_half2=',ratio_half2,'|full_nonlinear=',res_full%diagnostics%nonlinear_iterations, &
       '|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
       '|half2_nonlinear=',res_half2%diagnostics%nonlinear_iterations
  write(*,'(A)')'F_PE_ELASTIC52_EXEC=PASS'
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC52_FAIL output anchor")
    s=s.replace(old,new,1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC52_PREP=PASS")

if __name__=="__main__":
    main()
