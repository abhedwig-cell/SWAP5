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
        "python3",str(root/"tests/fpe/prepare_fpe_elastic59.py"),
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

    anchor="""  call solver_half%solve(req_half1,ws_half,res_half1)

  res_half2=soil_water_solve_result_t()
"""
    insert="""  call solver_half%solve(req_half1,ws_half,res_half1)

  call req(allocated(ws_half%richards%residual).and.allocated(ws_half%richards%old_head).and. &
       allocated(ws_half%richards%provider_capacity).and.allocated(ws_half%richards%provider_k), &
       'postmortem workspace allocated')
  call req(all(ieee_is_finite(ws_half%richards%residual)).and. &
       all(ieee_is_finite(ws_half%richards%old_head)).and. &
       all(ieee_is_finite(res_half1%candidate_state%pressure_head)).and. &
       all(ieee_is_finite(ws_half%richards%provider_capacity)).and. &
       all(ieee_is_finite(ws_half%richards%provider_k)), 'finite postmortem')

  write(*,'(*(g0))')'ELASTIC60_POST|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
       '|oracle_maxit=',oracle_maxit,'|status=',res_half1%status,'|route=',trim(res_half1%diagnostics%route), &
       '|nonlinear=',res_half1%diagnostics%nonlinear_iterations,'|jacobians=',res_half1%diagnostics%jacobian_builds, &
       '|linear=',res_half1%diagnostics%linear_solves,'|backtracking=',res_half1%diagnostics%backtracking_attempts, &
       '|alternative=',res_half1%diagnostics%alternative_solver_calls,'|internal_retries=',res_half1%diagnostics%internal_retries, &
       '|max_residual=',maxval(abs(ws_half%richards%residual)), &
       '|max_residual_node=',maxloc(abs(ws_half%richards%residual),dim=1), &
       '|sum_residual=',sum(ws_half%richards%residual), &
       '|l2_residual=',sqrt(sum(ws_half%richards%residual*ws_half%richards%residual)), &
       '|max_last_dh=',maxval(abs(res_half1%candidate_state%pressure_head-ws_half%richards%old_head)), &
       '|max_last_dh_node=',maxloc(abs(res_half1%candidate_state%pressure_head-ws_half%richards%old_head),dim=1), &
       '|h_min=',minval(res_half1%candidate_state%pressure_head),'|h_max=',maxval(res_half1%candidate_state%pressure_head), &
       '|saturated_nodes=',count(res_half1%candidate_state%pressure_head>=0.0_real64), &
       '|capacity_min=',minval(ws_half%richards%provider_capacity),'|capacity_max=',maxval(ws_half%richards%provider_capacity), &
       '|k_min=',minval(ws_half%richards%provider_k),'|k_max=',maxval(ws_half%richards%provider_k)

  res_half2=soil_water_solve_result_t()
"""
    if anchor not in s:
        raise SystemExit("F_PE_ELASTIC60_FAIL half1 solve anchor")
    s=s.replace(anchor,insert,1)
    s=s.replace("'F_PE_ELASTIC59_EXEC=PASS'","'F_PE_ELASTIC60_EXEC=PASS'",1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC60_PREP=PASS")

if __name__=="__main__":
    main()
