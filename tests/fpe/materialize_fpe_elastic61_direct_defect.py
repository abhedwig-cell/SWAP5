#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--module-out",required=True)
    ap.add_argument("--test-out",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    module_out=Path(a.module_out).resolve()
    test_out=Path(a.test_out).resolve()

    src=(root/"src/solver/mod_reference_richards_temporal_indicator.f90").read_text(encoding="utf-8")
    src=src.replace("module mod_reference_richards_temporal_indicator",
                    "module mod_fpe_elastic61_direct_defect_indicator",1)
    src=src.replace("end module mod_reference_richards_temporal_indicator",
                    "end module mod_fpe_elastic61_direct_defect_indicator",1)
    src=src.replace("public :: evaluate_reference_richards_temporal_indicator",
                    "public :: evaluate_fpe_elastic61_direct_defect_indicator",1)
    old="subroutine evaluate_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)"
    new="subroutine evaluate_fpe_elastic61_direct_defect_indicator(request, solve_result, indicator_request, indicator_result, direct_head_inf)"
    if old not in src: raise SystemExit("F_PE_ELASTIC61_FAIL indicator signature anchor")
    src=src.replace(old,new,1)
    src=src.replace("end subroutine evaluate_reference_richards_temporal_indicator",
                    "end subroutine evaluate_fpe_elastic61_direct_defect_indicator",1)

    old="""    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result

    integer :: n, i, ierr
"""
    new="""    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result
    real(real64), intent(out) :: direct_head_inf

    integer :: n, i, ierr
"""
    if old not in src: raise SystemExit("F_PE_ELASTIC61_FAIL output declaration anchor")
    src=src.replace(old,new,1)

    old="""    indicator_result = soil_water_temporal_indicator_result_t()
"""
    new="""    indicator_result = soil_water_temporal_indicator_result_t()
    direct_head_inf = 0.0_real64
"""
    if old not in src: raise SystemExit("F_PE_ELASTIC61_FAIL init anchor")
    src=src.replace(old,new,1)

    old="""    if (ierr /= 0 .or. any(.not. ieee_is_finite(delta))) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'defect-tridag-failed'
       return
    end if

    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
"""
    new="""    if (ierr /= 0 .or. any(.not. ieee_is_finite(delta))) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'defect-tridag-failed'
       return
    end if
    direct_head_inf = maxval(abs(delta))
    if (.not. ieee_is_finite(direct_head_inf) .or. direct_head_inf < 0.0_real64) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'nonfinite-direct-head-inf'
       return
    end if

    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
"""
    if old not in src: raise SystemExit("F_PE_ELASTIC61_FAIL delta anchor")
    src=src.replace(old,new,1)
    module_out.write_text(src,encoding="utf-8")

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/materialize_fpe_elastic59_history.py"),
        "--root",str(root),"--output",str(test_out)
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    t=test_out.read_text(encoding="utf-8")

    t=t.replace("use, intrinsic :: iso_fortran_env, only: real64",
                "use, intrinsic :: iso_fortran_env, only: int64, real64",1)
    anchor="""  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
"""
    insert="""  use mod_fpe_elastic61_direct_defect_indicator, only: &
       evaluate_fpe_elastic61_direct_defect_indicator
"""
    if anchor not in t: raise SystemExit("F_PE_ELASTIC61_FAIL test use anchor")
    t=t.replace(anchor,anchor+insert,1)

    old="""    type(soil_water_temporal_indicator_result_t) :: indicator,history_indicator
"""
    new="""    type(soil_water_temporal_indicator_result_t) :: indicator,history_indicator,research_indicator
"""
    if old not in t: raise SystemExit("F_PE_ELASTIC61_FAIL test indicator decl anchor")
    t=t.replace(old,new,1)

    old="""    real(real64) :: binf_zero,binf_history
"""
    new="""    real(real64) :: binf_zero,binf_history,direct_head_inf
"""
    if old not in t: raise SystemExit("F_PE_ELASTIC61_FAIL test scalar anchor")
    t=t.replace(old,new,1)

    needle="""      binf_history=history_indicator%head_inf_bound

      write(*,'(*(g0))') 'ELASTIC59_INDICATOR|CASE=',case_id,'|M=',trim(material_id), &
"""
    repl="""      binf_history=history_indicator%head_inf_bound

      research_indicator=soil_water_temporal_indicator_result_t()
      direct_head_inf=0.0_real64
      call evaluate_fpe_elastic61_direct_defect_indicator(coarse_request,coarse_result, &
           history_indicator_request,research_indicator,direct_head_inf)
      call require(research_indicator%status == SW_TEMPORAL_INDICATOR_AVAILABLE .and. research_indicator%available, &
           'ELASTIC61 research indicator available')
      call require(transfer(research_indicator%head_inf_bound,0_int64) == transfer(binf_history,0_int64), &
           'ELASTIC61 production Binf exact preservation')
      call require(ieee_is_finite(direct_head_inf) .and. direct_head_inf >= 0.0_real64, &
           'ELASTIC61 finite direct head inf')
      write(*,'(*(g0))') 'ELASTIC61_INDICATOR|CASE=',case_id,'|M=',trim(material_id), &
           '|SE=',se,'|F=',trim(forcing_id),'|DT=',coarse_dt,'|BINF=',binf_history, &
           '|D_INF=',direct_head_inf,'|ROUTE=',trim(research_indicator%route)

      write(*,'(*(g0))') 'ELASTIC59_INDICATOR|CASE=',case_id,'|M=',trim(material_id), &
"""
    if needle not in t: raise SystemExit("F_PE_ELASTIC61_FAIL test injection anchor")
    t=t.replace(needle,repl,1)
    t=t.replace("program test_fpe_elastic59_real_history_budget_bridge",
                "program test_fpe_elastic61_direct_defect_head_inf",1)
    t=t.replace("end program test_fpe_elastic59_real_history_budget_bridge",
                "end program test_fpe_elastic61_direct_defect_head_inf",1)
    test_out.write_text(t,encoding="utf-8")

    print("F_PE_ELASTIC61_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
