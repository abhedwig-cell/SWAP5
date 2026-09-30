#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    src=(root/"tests/publication/test_pub_p2e08_reference_valid_calibration_domain.f90").read_text(encoding="utf-8")

    old="""  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
"""
    new="""  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
"""
    if old not in src:
        raise SystemExit("F_PE_ELASTIC58_FAIL solver-contract import anchor")
    src=src.replace(old,new,1)

    old="""    type(soil_water_solve_result_t) :: coarse_result,half1_result,half2_result
"""
    new="""    type(soil_water_solve_result_t) :: coarse_result,half1_result,half2_result
    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator
"""
    if old not in src:
        raise SystemExit("F_PE_ELASTIC58_FAIL indicator declaration anchor")
    src=src.replace(old,new,1)

    anchor="""    if (.not.reference_result_valid(coarse_result,material)) then
      failure_stage='COARSE_REFERENCE_GATE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

"""
    insert="""    if (.not.reference_result_valid(coarse_result,material)) then
      failure_stage='COARSE_REFERENCE_GATE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    if (dt_index == 3) then
      indicator_request = soil_water_temporal_indicator_request_t()
      indicator = soil_water_temporal_indicator_result_t()
      indicator_request%previous_right_derivative_available = .true.
      allocate(indicator_request%previous_right_derivative(n))
      indicator_request%previous_right_derivative = 0.0_real64
      call solver%evaluate_temporal_indicator(coarse_request,coarse_result,indicator_request,coarse_workspace,indicator)
      call require(indicator%status == SW_TEMPORAL_INDICATOR_AVAILABLE .and. indicator%available, &
           'ELASTIC58 selected-dt mode2 indicator available')
      call require(ieee_is_finite(indicator%head_inf_bound) .and. indicator%head_inf_bound >= 0.0_real64, &
           'ELASTIC58 selected-dt finite Binf')
      call require(indicator%additional_full_nonlinear_solves == 0, &
           'ELASTIC58 indicator no extra nonlinear solve')
      call require(indicator%additional_tridiagonal_solves == 1, &
           'ELASTIC58 indicator one extra tridiagonal solve')
      write(*,'(*(g0))') 'ELASTIC58_INDICATOR|CASE=',case_id,'|M=',trim(material_id), &
           '|SE=',se,'|F=',trim(forcing_id),'|DT=',coarse_dt,'|BINF=',indicator%head_inf_bound, &
           '|RAW=',indicator%raw_m_norm,'|DEFECT=',indicator%defect_m_norm, &
           '|ROUTE=',trim(indicator%route)
    end if

"""
    if anchor not in src:
        raise SystemExit("F_PE_ELASTIC58_FAIL coarse-result anchor")
    src=src.replace(anchor,insert,1)

    src=src.replace(
        "program test_pub_p2e08_reference_valid_calibration_domain",
        "program test_fpe_elastic58_independent_budget_bridge",1)
    src=src.replace(
        "end program test_pub_p2e08_reference_valid_calibration_domain",
        "end program test_fpe_elastic58_independent_budget_bridge",1)

    Path(a.output).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC58_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
