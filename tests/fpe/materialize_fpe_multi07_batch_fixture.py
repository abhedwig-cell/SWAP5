#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True)
    ap.add_argument("--output",required=True)
    ap.add_argument("--columns",required=True,type=int)
    ap.add_argument("--profile-id",required=True,type=int)
    a=ap.parse_args()
    if a.columns<=0:
        raise SystemExit("F_PE_MULTI07_FAIL invalid column count")
    s=Path(a.source).read_text(encoding="utf-8")
    s=s.replace("program test_fpe_multi06_mode7_generated_worker_pool",
                "program test_fpe_multi07_mode7_population_batch")
    s=s.replace("end program test_fpe_multi06_mode7_generated_worker_pool",
                "end program test_fpe_multi07_mode7_population_batch")
    s=s.replace("integer, parameter :: N=numnod, NCOL=256",
                f"integer, parameter :: N=numnod, NCOL={a.columns}, PROFILE_ID={a.profile_id}")
    s=s.replace("F_PE_MULTI06","F_PE_MULTI07")
    s=s.replace("MULTI06_COLUMN","MULTI07_COLUMN")
    s=s.replace("MULTI06_SUMMARY","MULTI07_SUMMARY")
    decl="  integer :: workers,dispatch_status,pool_status,i,origin,ih,id,j,completed,committed,retries,mass_fail,solver\n"
    if decl not in s:
        raise SystemExit("F_PE_MULTI07_FAIL declaration seam")
    s=s.replace(decl,decl+"  integer(int64) :: clock0, clock1, clock_rate\n",1)
    call_anchor="  call fmr_run_parallel_physical_multiswap(columns,templates,params,forcings,states,numerical,top,0.0_real64,DT, &\n       32,workers,results,diagnostics,aggregate,dispatch_status,pool_status,runtime)\n"
    if call_anchor not in s:
        raise SystemExit("F_PE_MULTI07_FAIL runtime call seam")
    s=s.replace(call_anchor,
        "  call system_clock(clock0,count_rate=clock_rate)\n"+
        call_anchor+
        "  call system_clock(clock1)\n",1)
    summary="  write(*,'(*(g0))')'MULTI07_SUMMARY|workers=',workers,'|completed=',completed,'|committed=',committed, &\n"
    if summary not in s:
        raise SystemExit("F_PE_MULTI07_FAIL summary seam")
    s=s.replace(summary,
        "  write(*,'(*(g0))')'MULTI07_SUMMARY|profile=',PROFILE_ID,'|workers=',workers,'|completed=',completed,'|committed=',committed, &\n",1)
    tail="       '|aggregate_mass_residual=',runtime%authoritative_aggregate_mass%residual\n"
    if tail not in s:
        raise SystemExit("F_PE_MULTI07_FAIL timing seam")
    s=s.replace(tail,
        "       '|aggregate_mass_residual=',runtime%authoritative_aggregate_mass%residual, &\n"+
        "       '|seconds=',real(clock1-clock0,real64)/real(clock_rate,real64)\n",1)
    Path(a.output).write_text(s,encoding="utf-8")
    print(f"MULTI07_FIXTURE|profile={a.profile_id}|columns={a.columns}")
    print("F_PE_MULTI07_FIXTURE=PASS")

if __name__=="__main__":
    main()
