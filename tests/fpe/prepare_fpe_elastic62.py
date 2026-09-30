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
        "python3",str(root/"tests/fpe/prepare_fpe_elastic60.py"),
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

    anchor="""  res_half2=soil_water_solve_result_t()
  if(res_half1%status==SW_SOLVE_CONVERGED)then
"""
    insert="""  write(*,'(*(g0))')'ELASTIC62_FLOOR|regime=',trim(regime),'|delta=',delta, &
       '|half_dt=',0.5_real64*dt, &
       '|max_local_floor=',maxval(0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt)), &
       '|max_local_floor_node=',maxloc(0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt),dim=1), &
       '|sum_local_floors=',sum(0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt)), &
       '|integrated_max_floor=',0.5_real64*dt*maxval(0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt)), &
       '|integrated_sum_floor=',0.5_real64*dt*sum(0.5_real64*(spacing(ws_half%state_binding%theta)+ &
            spacing(req_half1%base_state%water_content))*p%dz/(0.5_real64*dt)), &
       '|max_local_residual=',maxval(abs(ws_half%richards%residual)), &
       '|max_local_residual_node=',maxloc(abs(ws_half%richards%residual),dim=1), &
       '|abs_total_residual=',abs(sum(ws_half%richards%residual)), &
       '|baltol_depth=',2.8e-16_real64, &
       '|baltol_rate=',max(1.0e-12_real64,2.8e-16_real64/(0.5_real64*dt))

  res_half2=soil_water_solve_result_t()
  if(res_half1%status==SW_SOLVE_CONVERGED)then
"""
    if anchor not in s:
        raise SystemExit("F_PE_ELASTIC62_FAIL anchor")
    s=s.replace(anchor,insert,1)
    s=s.replace("'F_PE_ELASTIC60_EXEC=PASS'","'F_PE_ELASTIC62_EXEC=PASS'",1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC62_PREP=PASS")

if __name__=="__main__":
    main()
