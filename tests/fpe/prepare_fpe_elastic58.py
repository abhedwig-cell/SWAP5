#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL missing anchor {label}")
    return text.replace(old, new, 1)

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

    s=replace_once(s,
"""  type(reference_richards_legacy_solver_t)::solver_full,solver_half
  type(reference_richards_legacy_workspace_t)::ws_full,ws_half
  type(b110_default_mvg_provider_t),target::constitutive_full,constitutive_half,constitutive_init
""",
"""  type(reference_richards_legacy_solver_t)::solver_full,solver_half,solver_oracle
  type(reference_richards_legacy_workspace_t)::ws_full,ws_half,ws_oracle
  type(b110_default_mvg_provider_t),target::constitutive_full,constitutive_half,constitutive_init,constitutive_oracle
""","solver declarations")

    s=replace_once(s,
"""  type(soil_water_solve_request_t)::req_full,req_half1,req_half2
  type(soil_water_solve_result_t)::res_full,res_half1,res_half2
""",
"""  type(soil_water_solve_request_t)::req_full,req_half1,req_half2,req_oracle
  type(soil_water_solve_result_t)::res_full,res_half1,res_half2,res_oracle
  type(soil_water_physical_state_t)::oracle_state
""","request declarations")

    s=replace_once(s,
"""  integer::ih,itheta,i
  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect
""",
"""  integer::ih,itheta,i,oracle_n,j
  logical::all_converged,exact_identity,indicator_available,oracle_complete,oracle_mass_ok
  real(real64)::indicator_binf,indicator_raw,indicator_defect
  real(real64)::oracle_dt,oracle_dh,oracle_dtheta,oracle_flux_rel,oracle_exchange_rel
  real(real64)::oracle_exchange,full_exchange,oracle_flux_final,ledger_residual,max_ledger_residual
""","oracle declarations")

    s=replace_once(s,
"""  if(command_argument_count()<4) error stop 'F_PE_ELASTIC50_FAIL args'
  call get_command_argument(1,regime)
""",
"""  if(command_argument_count()<4) error stop 'F_PE_ELASTIC50_FAIL args'
  oracle_n=0
  if(command_argument_count()>=5)then
    call get_command_argument(5,arg);read(arg,*)oracle_n
  end if
  call get_command_argument(1,regime)
""","oracle argument")

    s=replace_once(s,
"""  all_converged=res_full%status==SW_SOLVE_CONVERGED.and.res_half1%status==SW_SOLVE_CONVERGED.and. &
       res_half2%status==SW_SOLVE_CONVERGED

""",
"""  all_converged=res_full%status==SW_SOLVE_CONVERGED.and.res_half1%status==SW_SOLVE_CONVERGED.and. &
       res_half2%status==SW_SOLVE_CONVERGED

  oracle_complete=.false.;oracle_mass_ok=.false.
  oracle_dh=0.0_real64;oracle_dtheta=0.0_real64
  oracle_flux_rel=0.0_real64;oracle_exchange_rel=0.0_real64
  oracle_exchange=0.0_real64;full_exchange=0.0_real64
  oracle_flux_final=0.0_real64;ledger_residual=0.0_real64;max_ledger_residual=0.0_real64
  if(oracle_n>0.and.res_full%status==SW_SOLVE_CONVERGED)then
    oracle_dt=dt/real(oracle_n,real64)
    call req(oracle_dt>=p%min_step_duration,'oracle dt')
    call bind_b110_default_mvg_provider(constitutive_oracle,p%prepared_default_mvg,oracle_dt)
    do j=1,oracle_n
      if(j==1)then
        call make_request(req_oracle,soil,constitutive_oracle,source_sink,top,heads,water,h0,qeq+delta,qeq,oracle_dt)
      else
        call make_request_from_state(req_oracle,soil,constitutive_oracle,source_sink,top,oracle_state,h0,qeq+delta,qeq,oracle_dt)
      end if
      call solver_oracle%solve(req_oracle,ws_oracle,res_oracle)
      if(res_oracle%status/=SW_SOLVE_CONVERGED)exit
      call independent_mass_ledger(req_oracle,res_oracle,p%dz,oracle_dt,ledger_residual)
      max_ledger_residual=max(max_ledger_residual,abs(ledger_residual))
      oracle_exchange=oracle_exchange+res_oracle%bottom_flux*oracle_dt
      oracle_state=res_oracle%candidate_state
      oracle_flux_final=res_oracle%bottom_flux
    end do
    if(j>oracle_n.and.res_oracle%status==SW_SOLVE_CONVERGED)then
      oracle_complete=.true.
      oracle_mass_ok=max_ledger_residual<=MASS_TOL
      oracle_dh=maxval(abs(res_full%candidate_state%pressure_head-oracle_state%pressure_head))
      oracle_dtheta=maxval(abs(res_full%candidate_state%water_content-oracle_state%water_content))
      oracle_flux_rel=abs(res_full%bottom_flux-oracle_flux_final)/max(abs(oracle_flux_final),1.0e-12_real64)
      full_exchange=res_full%bottom_flux*dt
      oracle_exchange_rel=abs(full_exchange-oracle_exchange)/max(abs(oracle_exchange),1.0e-12_real64)
    end if
  end if

""","oracle run")

    s=replace_once(s,
"""  write(*,'(A)')'F_PE_ELASTIC55_EXEC=PASS'
""",
f"""  if(oracle_n>0)then
    write(*,'(*(g0))')'ELASTIC58_ORACLE|profile={a.profile_id}|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
      '|oracle_n=',oracle_n,'|oracle_complete=',oracle_complete,'|oracle_mass_ok=',oracle_mass_ok, &
      '|oracle_dh=',oracle_dh,'|oracle_dtheta=',oracle_dtheta,'|oracle_flux_rel=',oracle_flux_rel, &
      '|oracle_exchange_rel=',oracle_exchange_rel,'|max_ledger_residual=',max_ledger_residual
  end if
  write(*,'(A)')'F_PE_ELASTIC55_EXEC=PASS'
""","oracle output")

    s=replace_once(s,
"""contains

  subroutine init_base""",
"""contains

  subroutine independent_mass_ledger(r,res,dzv,step,ledger)
    type(soil_water_solve_request_t),intent(in)::r
    type(soil_water_solve_result_t),intent(in)::res
    real(real64),intent(in)::dzv(N),step
    real(real64),intent(out)::ledger
    real(real64)::s0,s1,total_in,total_out
    s0=sum(r%base_state%water_content*dzv)+r%base_state%ponding_depth
    s1=sum(res%candidate_state%water_content*dzv)+res%candidate_state%ponding_depth
    total_in=max(0.0_real64,-res%top_flux)*step+max(0.0_real64,res%bottom_flux)*step
    total_out=max(0.0_real64,res%top_flux)*step+max(0.0_real64,-res%bottom_flux)*step
    ledger=s1-s0-(total_in-total_out)
  end subroutine independent_mass_ledger

  subroutine init_base""","mass helper")

    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC58_PROFILE_PREP=PASS")

if __name__=="__main__":
    main()
