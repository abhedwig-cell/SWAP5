#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

PROFILE_ID=3030

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
        "python3",str(root/"tests/fpe/prepare_fpe_elastic55.py"),"profile",
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--profile-id",str(PROFILE_ID),
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve()),
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    old="""  integer::ih,itheta,i
  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect
  character(len=32)::regime
  character(len=64)::arg

  if(command_argument_count()<4) error stop 'F_PE_ELASTIC50_FAIL args'
"""
    new="""  integer::ih,itheta,i,repeats,warmup
  integer(int64)::clock0,clock1,clock_rate
  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect,elapsed
  character(len=32)::regime,benchmode
  character(len=64)::arg

  if(command_argument_count()<7) error stop 'F_PE_ELASTIC59_FAIL args'
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL declarations anchor")
    s=s.replace(old,new,1)

    old="""  call get_command_argument(4,arg);read(arg,*)dt
  call req(dt>0.0_real64,'dt')
"""
    new="""  call get_command_argument(4,arg);read(arg,*)dt
  call get_command_argument(5,benchmode)
  call get_command_argument(6,arg);read(arg,*)repeats
  call get_command_argument(7,arg);read(arg,*)warmup
  call req(dt>0.0_real64.and.repeats>0.and.warmup>=0,'arguments')
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL argument anchor")
    s=s.replace(old,new,1)

    anchor="""  call bind_b110_default_mvg_provider(constitutive_half,p%prepared_default_mvg,0.5_real64*dt)
"""
    bench="""  call req(res_full%status==SW_SOLVE_CONVERGED,'full solve converged')
  call req(indicator_available,'indicator available')
  select case(trim(benchmode))
  case('SOLVE_ONLY')
    do i=1,warmup
      call solver_full%solve(req_full,ws_full,res_full)
      call req(res_full%status==SW_SOLVE_CONVERGED,'warm solve')
    end do
    call system_clock(clock0,clock_rate)
    do i=1,repeats
      call solver_full%solve(req_full,ws_full,res_full)
      call req(res_full%status==SW_SOLVE_CONVERGED,'timed solve')
    end do
    call system_clock(clock1)
  case('INDICATOR_ONLY')
    do i=1,warmup
      call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator)
      call req(indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.indicator%available,'warm indicator')
    end do
    call system_clock(clock0,clock_rate)
    do i=1,repeats
      call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator)
      call req(indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.indicator%available,'timed indicator')
    end do
    call system_clock(clock1)
  case('SOLVE_PLUS_INDICATOR')
    do i=1,warmup
      call solver_full%solve(req_full,ws_full,res_full)
      call req(res_full%status==SW_SOLVE_CONVERGED,'warm combined solve')
      call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator)
      call req(indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.indicator%available,'warm combined indicator')
    end do
    call system_clock(clock0,clock_rate)
    do i=1,repeats
      call solver_full%solve(req_full,ws_full,res_full)
      call req(res_full%status==SW_SOLVE_CONVERGED,'timed combined solve')
      call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator)
      call req(indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.indicator%available,'timed combined indicator')
    end do
    call system_clock(clock1)
  case default
    error stop 'F_PE_ELASTIC59_FAIL benchmark mode'
  end select
  elapsed=real(clock1-clock0,real64)/real(clock_rate,real64)
  write(*,'(*(g0))')'ELASTIC59_TIMING|regime=',trim(regime),'|mode=',trim(benchmode), &
       '|repeats=',repeats,'|ns_per_op=',elapsed*1.0e9_real64/real(repeats,real64), &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations, &
       '|full_jacobians=',res_full%diagnostics%jacobian_builds, &
       '|full_linear=',res_full%diagnostics%linear_solves, &
       '|full_backtracking=',res_full%diagnostics%backtracking_attempts, &
       '|indicator_extra_tridiag=',indicator%additional_tridiagonal_solves, &
       '|indicator_extra_nonlinear=',indicator%additional_full_nonlinear_solves
  write(*,'(A)')'F_PE_ELASTIC59_EXEC=PASS'
  stop

"""
    if anchor not in s: raise SystemExit("F_PE_ELASTIC59_FAIL benchmark insertion anchor")
    s=s.replace(anchor,bench+anchor,1)
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC59_PREP=PASS")

if __name__=="__main__":
    main()
