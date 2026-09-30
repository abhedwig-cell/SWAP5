#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL missing anchor {label}")
    return text.replace(old,new,1)

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
        "python3",str(root/"tests/fpe/prepare_fpe_elastic58.py"),
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
"""  integer::ih,itheta,i,oracle_n,j
  logical::all_converged,exact_identity,indicator_available,oracle_complete,oracle_mass_ok
""",
"""  integer::ih,itheta,i,oracle_n,j,oracle_failure_step,oracle_failure_status
  integer::oracle_min_nonlinear,oracle_max_nonlinear
  logical::all_converged,exact_identity,indicator_available,oracle_complete,oracle_mass_ok
""","oracle integer declarations")

    s=replace_once(s,
"""  oracle_complete=.false.;oracle_mass_ok=.false.
  oracle_dh=0.0_real64;oracle_dtheta=0.0_real64
""",
"""  oracle_complete=.false.;oracle_mass_ok=.false.
  oracle_failure_step=0;oracle_failure_status=0
  oracle_min_nonlinear=huge(0);oracle_max_nonlinear=0
  oracle_dh=0.0_real64;oracle_dtheta=0.0_real64
""","oracle init")

    s=replace_once(s,
"""      call solver_oracle%solve(req_oracle,ws_oracle,res_oracle)
      if(res_oracle%status/=SW_SOLVE_CONVERGED)exit
      call independent_mass_ledger(req_oracle,res_oracle,p%dz,oracle_dt,ledger_residual)
""",
"""      call solver_oracle%solve(req_oracle,ws_oracle,res_oracle)
      oracle_min_nonlinear=min(oracle_min_nonlinear,res_oracle%diagnostics%nonlinear_iterations)
      oracle_max_nonlinear=max(oracle_max_nonlinear,res_oracle%diagnostics%nonlinear_iterations)
      if(res_oracle%status/=SW_SOLVE_CONVERGED)then
        oracle_failure_step=j
        oracle_failure_status=res_oracle%status
        exit
      end if
      call independent_mass_ledger(req_oracle,res_oracle,p%dz,oracle_dt,ledger_residual)
""","oracle loop diagnostics")

    s=replace_once(s,
"""  if(oracle_n>0)then
    write(*,'(*(g0))')'ELASTIC58_ORACLE|profile=""",
"""  if(oracle_n>0)then
    if(oracle_min_nonlinear==huge(0))oracle_min_nonlinear=0
    write(*,'(*(g0))')'ELASTIC59_ORACLE|profile=""","oracle marker rename")

    s=replace_once(s,
"""      '|oracle_n=',oracle_n,'|oracle_complete=',oracle_complete,'|oracle_mass_ok=',oracle_mass_ok, &
      '|oracle_dh=',oracle_dh,'|oracle_dtheta=',oracle_dtheta,'|oracle_flux_rel=',oracle_flux_rel, &
      '|oracle_exchange_rel=',oracle_exchange_rel,'|max_ledger_residual=',max_ledger_residual
  end if
""",
"""      '|oracle_n=',oracle_n,'|oracle_complete=',oracle_complete,'|oracle_mass_ok=',oracle_mass_ok, &
      '|failure_step=',oracle_failure_step,'|failure_status=',oracle_failure_status, &
      '|min_nonlinear=',oracle_min_nonlinear,'|max_nonlinear=',oracle_max_nonlinear, &
      '|oracle_dh=',oracle_dh,'|oracle_dtheta=',oracle_dtheta,'|oracle_flux_rel=',oracle_flux_rel, &
      '|oracle_exchange_rel=',oracle_exchange_rel,'|max_ledger_residual=',max_ledger_residual
    if(oracle_complete)then
      write(*,'(*(g0,:,","))')'ELASTIC59_HEADS',oracle_state%pressure_head
      write(*,'(*(g0,:,","))')'ELASTIC59_THETA',oracle_state%water_content
    end if
  end if
""","oracle output diagnostics")

    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC59_PROFILE_PREP=PASS")

if __name__=="__main__":
    main()
