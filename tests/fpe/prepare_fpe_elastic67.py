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
        "python3",str(root/"tests/fpe/prepare_fpe_elastic55.py"),"profile",
        "--repo-root",str(root),"--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),"--profile-id","8016",
        "--fixture",str(fixture),"--geometry-json",str(Path(a.geometry_json).resolve())
    ],text=True,capture_output=True)
    if cp.returncode!=0: raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    anchor="  call solver_half%solve(req_half1,ws_half,res_half1)\n\n"
    insert="""  call solver_half%solve(req_half1,ws_half,res_half1)

  call req(allocated(ws_half%richards%residual),'ELASTIC67 residual allocated')
  call req(all(ieee_is_finite(ws_half%richards%residual)),'ELASTIC67 residual finite')
  write(*,'(*(g0))')'ELASTIC67_POST|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
       '|subdt=',0.5_real64*dt,'|status=',res_half1%status, &
       '|nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
       '|backtracking=',res_half1%diagnostics%backtracking_attempts, &
       '|jacobians=',res_half1%diagnostics%jacobian_builds, &
       '|linear=',res_half1%diagnostics%linear_solves, &
       '|internal_retries=',res_half1%diagnostics%internal_retries, &
       '|max_residual=',maxval(abs(ws_half%richards%residual)), &
       '|max_residual_node=',maxloc(abs(ws_half%richards%residual),dim=1), &
       '|sum_residual=',sum(ws_half%richards%residual), &
       '|l2_residual=',sqrt(sum(ws_half%richards%residual*ws_half%richards%residual)), &
       '|h_min=',minval(res_half1%candidate_state%pressure_head), &
       '|h_max=',maxval(res_half1%candidate_state%pressure_head), &
       '|saturated_nodes=',count(res_half1%candidate_state%pressure_head>=0.0_real64)

"""
    if anchor not in s: raise SystemExit("F_PE_ELASTIC67_FAIL solve anchor")
    s=s.replace(anchor,insert,1)
    s=s.replace("'F_PE_ELASTIC55_EXEC=PASS'","'F_PE_ELASTIC67_EXEC=PASS'",1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC67_PREP=PASS")

if __name__=="__main__": main()
