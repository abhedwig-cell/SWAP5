#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    out=Path(a.output).resolve()

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/materialize_fpe_elastic58_p2e08_indicator.py"),
        "--root",str(root),"--output",str(out)
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    s=out.read_text(encoding="utf-8")

    # Add history request/result/workspace.
    old="""    type(soil_water_solve_request_t) :: coarse_request,half1_request,half2_request
    type(soil_water_solve_result_t) :: coarse_result,half1_result,half2_result
"""
    new="""    type(soil_water_solve_request_t) :: history_request,coarse_request,half1_request,half2_request
    type(soil_water_solve_result_t) :: history_result,coarse_result,half1_result,half2_result
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL request declaration anchor")
    s=s.replace(old,new,1)

    old="""    type(reference_richards_legacy_workspace_t) :: coarse_workspace,half1_workspace,half2_workspace
"""
    new="""    type(reference_richards_legacy_workspace_t) :: history_workspace,coarse_workspace,half1_workspace,half2_workspace
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL workspace anchor")
    s=s.replace(old,new,1)

    old="""    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator
"""
    new="""    type(soil_water_temporal_indicator_request_t) :: indicator_request,history_indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator,history_indicator
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL indicator type anchor")
    s=s.replace(old,new,1)

    old="""    real(real64) :: half_dt,h0,k0,top_flux,bottom_flux,coarse_storage,refined_storage
"""
    new="""    real(real64) :: half_dt,h0,k0,top_flux,bottom_flux,coarse_storage,refined_storage
    real(real64) :: history_dt,history_flux,history_dh_inf,history_dtheta_inf,history_deriv_inf
    real(real64) :: binf_zero,binf_history
    real(real64), allocatable :: history_right_derivative(:)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL scalar declaration anchor")
    s=s.replace(old,new,1)

    # Insert accepted stationary history before current coarse interval.
    old="""    k0=conductivity(1); top_flux=top_factor*k0; bottom_flux=bottom_factor*k0
    half_dt=0.5_real64*coarse_dt
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    call initialize_request(coarse_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,coarse_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    call solver%solve(coarse_request,coarse_workspace,coarse_result)
"""
    new="""    k0=conductivity(1); top_flux=top_factor*k0; bottom_flux=bottom_factor*k0
    half_dt=0.5_real64*coarse_dt
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    history_dt=0.0064_real64
    history_flux=-k0
    call initialize_request(history_request,parameters,constitutive,source_sink,top_boundary,theta0,h0, &
         history_flux,history_flux,history_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,history_dt)
    call solver%solve(history_request,history_workspace,history_result)
    call require(reference_result_valid(history_result,material),'ELASTIC59 stationary history valid')
    history_dh_inf=maxval(abs(history_result%candidate_state%pressure_head-h0))
    history_dtheta_inf=maxval(abs(history_result%candidate_state%water_content-theta0))
    call require(history_dh_inf <= 1.0e-10_real64,'ELASTIC59 stationary history head preservation')
    call require(history_dtheta_inf <= 1.0e-12_real64,'ELASTIC59 stationary history theta preservation')
    allocate(history_right_derivative(n))
    history_right_derivative=(history_result%candidate_state%pressure_head-h0)/history_dt
    history_deriv_inf=maxval(abs(history_right_derivative))

    call initialize_request(coarse_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,coarse_dt)
    coarse_request%base_state=history_result%candidate_state
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,coarse_dt)
    call solver%solve(coarse_request,coarse_workspace,coarse_result)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL history insertion anchor")
    s=s.replace(old,new,1)

    # Replace the ELASTIC58 selected-dt indicator block with paired ZERO/HISTORY calls.
    start=s.find("    if (dt_index == 3) then\n      indicator_request = soil_water_temporal_indicator_request_t()")
    if start<0: raise SystemExit("F_PE_ELASTIC59_FAIL zero indicator block start")
    end=s.find("    end if\n\n    call initialize_request(half1_request",start)
    if end<0: raise SystemExit("F_PE_ELASTIC59_FAIL zero indicator block end")
    end += len("    end if\n")
    block="""    if (dt_index == 3) then
      indicator_request = soil_water_temporal_indicator_request_t()
      indicator = soil_water_temporal_indicator_result_t()
      indicator_request%previous_right_derivative_available = .true.
      allocate(indicator_request%previous_right_derivative(n))
      indicator_request%previous_right_derivative = 0.0_real64
      call solver%evaluate_temporal_indicator(coarse_request,coarse_result,indicator_request,coarse_workspace,indicator)
      call require(indicator%status == SW_TEMPORAL_INDICATOR_AVAILABLE .and. indicator%available, &
           'ELASTIC59 zero-history mode2 indicator available')
      call require(ieee_is_finite(indicator%head_inf_bound) .and. indicator%head_inf_bound >= 0.0_real64, &
           'ELASTIC59 zero-history finite Binf')
      binf_zero=indicator%head_inf_bound

      history_indicator_request = soil_water_temporal_indicator_request_t()
      history_indicator = soil_water_temporal_indicator_result_t()
      history_indicator_request%previous_right_derivative_available = .true.
      allocate(history_indicator_request%previous_right_derivative(n))
      history_indicator_request%previous_right_derivative = history_right_derivative
      call solver%evaluate_temporal_indicator(coarse_request,coarse_result,history_indicator_request,coarse_workspace,history_indicator)
      call require(history_indicator%status == SW_TEMPORAL_INDICATOR_AVAILABLE .and. history_indicator%available, &
           'ELASTIC59 real-history mode2 indicator available')
      call require(ieee_is_finite(history_indicator%head_inf_bound) .and. history_indicator%head_inf_bound >= 0.0_real64, &
           'ELASTIC59 real-history finite Binf')
      binf_history=history_indicator%head_inf_bound

      write(*,'(*(g0))') 'ELASTIC59_INDICATOR|CASE=',case_id,'|M=',trim(material_id), &
           '|SE=',se,'|F=',trim(forcing_id),'|DT=',coarse_dt, &
           '|BINF_ZERO=',binf_zero,'|BINF_HISTORY=',binf_history, &
           '|HISTORY_DH_INF=',history_dh_inf,'|HISTORY_DTHETA_INF=',history_dtheta_inf, &
           '|HISTORY_DERIV_INF=',history_deriv_inf, &
           '|ZERO_ROUTE=',trim(indicator%route),'|HISTORY_ROUTE=',trim(history_indicator%route)
    end if
"""
    s=s[:start]+block+s[end:]

    # Ensure the refined path starts from the accepted history endpoint.
    old="""    call initialize_request(half1_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
"""
    new="""    call initialize_request(half1_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
    half1_request%base_state=history_result%candidate_state
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,half_dt)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL half1 history anchor")
    s=s.replace(old,new,1)

    s=s.replace("program test_fpe_elastic58_independent_budget_bridge",
                "program test_fpe_elastic59_real_history_budget_bridge",1)
    s=s.replace("end program test_fpe_elastic58_independent_budget_bridge",
                "end program test_fpe_elastic59_real_history_budget_bridge",1)

    out.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC59_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
