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

    # Full-solve diagnostics before half1 reuses any workspace.
    anchor="  call solver_full%solve(req_full,ws_full,res_full)\n"
    full=f"""  call solver_full%solve(req_full,ws_full,res_full)

  call req(allocated(ws_full%richards%residual).and.allocated(ws_full%state_binding%theta),'full floor workspace')
  call req(all(ieee_is_finite(ws_full%richards%residual)).and.all(ieee_is_finite(ws_full%state_binding%theta)), &
       'finite full floor workspace')
  write(*,'(*(g0))')'ELASTIC63_SOLVE|profile={a.profile_id}|stage=FULL|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
       '|status=',res_full%status, &
       '|max_local_residual=',maxval(abs(ws_full%richards%residual)), &
       '|max_local_residual_node=',maxloc(abs(ws_full%richards%residual),dim=1), &
       '|abs_total_residual=',abs(sum(ws_full%richards%residual)), &
       '|floor_max=',maxval(0.5_real64*(spacing(ws_full%state_binding%theta)+ &
            spacing(req_full%base_state%water_content))*p%dz/dt), &
       '|floor_rss=',sqrt(sum((0.5_real64*(spacing(ws_full%state_binding%theta)+ &
            spacing(req_full%base_state%water_content))*p%dz/dt)**2)), &
       '|floor_sum=',sum(0.5_real64*(spacing(ws_full%state_binding%theta)+ &
            spacing(req_full%base_state%water_content))*p%dz/dt), &
       '|baltol_rate=',max(1.0e-12_real64,2.8e-16_real64/dt)

"""
    if s.count(anchor)!=1: raise SystemExit(f"F_PE_ELASTIC63_FAIL full anchor count={s.count(anchor)}")
    s=s.replace(anchor,full,1)

    anchor="""  call solver_half%solve(req_half1,ws_half,res_half1)

  res_half2=soil_water_solve_result_t()
"""
    half=f"""  call solver_half%solve(req_half1,ws_half,res_half1)

  call req(allocated(ws_half%richards%residual).and.allocated(ws_half%state_binding%theta),'half1 floor workspace')
  call req(all(ieee_is_finite(ws_half%richards%residual)).and.all(ieee_is_finite(ws_half%state_binding%theta)), &
       'finite half1 floor workspace')
  write(*,'(*(g0))')'ELASTIC63_SOLVE|profile={a.profile_id}|stage=HALF1|regime=',trim(regime),'|h0=',h0,'|delta=',delta, &
       '|dt=',0.5_real64*dt,'|status=',res_half1%status, &
       '|max_local_residual=',maxval(abs(ws_half%richards%residual)), &
       '|max_local_residual_node=',maxloc(abs(ws_half%richards%residual),dim=1), &
       '|abs_total_residual=',abs(sum(ws_half%richards%residual)), &
       '|floor_max=',maxval(0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt)), &
       '|floor_rss=',sqrt(sum((0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt))**2)), &
       '|floor_sum=',sum(0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt)), &
       '|baltol_rate=',max(1.0e-12_real64,2.8e-16_real64/(0.5_real64*dt))

  res_half2=soil_water_solve_result_t()
"""
    if anchor not in s: raise SystemExit("F_PE_ELASTIC63_FAIL half anchor")
    s=s.replace(anchor,half,1)

    s=s.replace("'F_PE_ELASTIC55_EXEC=PASS'","'F_PE_ELASTIC63_EXEC=PASS'",1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC63_PREP=PASS")

if __name__=="__main__":
    main()
