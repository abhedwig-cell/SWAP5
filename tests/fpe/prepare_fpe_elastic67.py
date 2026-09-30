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
    root=Path(a.repo_root).resolve(); fixture=Path(a.fixture).resolve()

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/prepare_fpe_elastic60.py"),
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--profile-id","8016",
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve())
    ],text=True,capture_output=True)
    if cp.returncode!=0: raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    old="""      call solver_oracle%solve(req_oracle,ws_oracle,res_oracle)
      oracle_min_nonlinear=min(oracle_min_nonlinear,res_oracle%diagnostics%nonlinear_iterations)
      oracle_max_nonlinear=max(oracle_max_nonlinear,res_oracle%diagnostics%nonlinear_iterations)
      if(res_oracle%status/=SW_SOLVE_CONVERGED)then
        oracle_failure_step=j
        oracle_failure_status=res_oracle%status
        exit
      end if
"""
    new="""      call solver_oracle%solve(req_oracle,ws_oracle,res_oracle)
      oracle_min_nonlinear=min(oracle_min_nonlinear,res_oracle%diagnostics%nonlinear_iterations)
      oracle_max_nonlinear=max(oracle_max_nonlinear,res_oracle%diagnostics%nonlinear_iterations)
      if(res_oracle%status/=SW_SOLVE_CONVERGED)then
        call req(allocated(ws_oracle%richards%residual),'ELASTIC67 residual allocated')
        call req(all(ieee_is_finite(ws_oracle%richards%residual)),'ELASTIC67 residual finite')
        write(*,'(*(g0))')'ELASTIC67_POST|oracle_n=',oracle_n,'|step=',j,'|status=',res_oracle%status, &
             '|route=',trim(res_oracle%diagnostics%route),'|nonlinear=',res_oracle%diagnostics%nonlinear_iterations, &
             '|backtracking=',res_oracle%diagnostics%backtracking_attempts, &
             '|jacobians=',res_oracle%diagnostics%jacobian_builds,'|linear=',res_oracle%diagnostics%linear_solves, &
             '|alternative=',res_oracle%diagnostics%alternative_solver_calls, &
             '|internal_retries=',res_oracle%diagnostics%internal_retries, &
             '|max_residual=',maxval(abs(ws_oracle%richards%residual)), &
             '|max_residual_node=',maxloc(abs(ws_oracle%richards%residual),dim=1), &
             '|sum_residual=',sum(ws_oracle%richards%residual), &
             '|l2_residual=',sqrt(sum(ws_oracle%richards%residual*ws_oracle%richards%residual)), &
             '|h_min=',minval(res_oracle%candidate_state%pressure_head), &
             '|h_max=',maxval(res_oracle%candidate_state%pressure_head), &
             '|saturated_nodes=',count(res_oracle%candidate_state%pressure_head>=0.0_real64), &
             '|capacity_min=',minval(ws_oracle%richards%provider_capacity), &
             '|capacity_max=',maxval(ws_oracle%richards%provider_capacity), &
             '|k_min=',minval(ws_oracle%richards%provider_k),'|k_max=',maxval(ws_oracle%richards%provider_k)
        oracle_failure_step=j
        oracle_failure_status=res_oracle%status
        exit
      end if
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC67_FAIL oracle failure anchor")
    s=s.replace(old,new,1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC67_PREP=PASS")

if __name__=="__main__": main()
