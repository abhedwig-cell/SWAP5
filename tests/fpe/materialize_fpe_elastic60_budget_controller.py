#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    out=Path(a.output).resolve()
    base=out.with_suffix(".base.f90")

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/materialize_fpe_elastic58_reference_budget.py"),
        "--root",str(root),"--output",str(base)
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    s=base.read_text(encoding="utf-8")

    anchor="  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
    insert="""  use mod_fpe_elastic53_reference_richards_temporal_indicator, only: &
       evaluate_fpe_elastic53_reference_richards_temporal_indicator
  use mod_soil_water_solver_contract, only: soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_TEMPORAL_INDICATOR_AVAILABLE
"""
    if anchor not in s: raise SystemExit("F_PE_ELASTIC60_FAIL use anchor")
    s=s.replace(anchor,anchor+insert,1)

    old="""    type(soil_water_solve_result_t) :: coarse_result,half1_result,half2_result
"""
    new="""    type(soil_water_solve_result_t) :: coarse_result,half1_result,half2_result
    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator_result
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC60_FAIL result declaration anchor")
    s=s.replace(old,new,1)

    old="""    real(real64) :: half_dt,h0,k0,top_flux,bottom_flux,coarse_storage,refined_storage
    logical :: found
"""
    new="""    real(real64) :: half_dt,h0,k0,top_flux,bottom_flux,coarse_storage,refined_storage
    real(real64) :: indicator_binf
    logical :: found,indicator_available
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC60_FAIL scalar declaration anchor")
    s=s.replace(old,new,1)

    old="""    if (.not.reference_result_valid(coarse_result,material)) then
      failure_stage='COARSE_REFERENCE_GATE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    call initialize_request(half1_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
"""
    new="""    if (.not.reference_result_valid(coarse_result,material)) then
      failure_stage='COARSE_REFERENCE_GATE'
      call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
      return
    end if

    indicator_request=soil_water_temporal_indicator_request_t()
    indicator_result=soil_water_temporal_indicator_result_t()
    indicator_request%previous_right_derivative_available=.true.
    allocate(indicator_request%previous_right_derivative(n))
    indicator_request%previous_right_derivative=0.0_real64
    call evaluate_fpe_elastic53_reference_richards_temporal_indicator( &
         coarse_request,coarse_result,indicator_request,indicator_result)
    indicator_available=indicator_result%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.indicator_result%available
    indicator_binf=0.0_real64
    if(indicator_available) indicator_binf=indicator_result%head_inf_bound
    write(*,'(*(g0))') 'ELASTIC60_COARSE|DT_INDEX=',dt_index,'|CASE=',case_id,'|M=',trim(material_id), &
         '|SE=',se,'|F=',trim(forcing_id),'|DT=',coarse_dt, &
         '|MASS_CM=',coarse_result%integrated_mass_balance_residual_cm, &
         '|INDICATOR_AVAILABLE=',indicator_available,'|BINF=',indicator_binf

    call initialize_request(half1_request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_flux,bottom_flux,half_dt)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC60_FAIL coarse solve anchor")
    s=s.replace(old,new,1)

    old="""    valid=.true.; failure_stage='NONE'
    call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
    write(*,'(*(g0))') 'ELASTIC58_TYPED_MASS|DT_INDEX=',dt_index,'|CASE=',case_id, &
"""
    new="""    valid=.true.; failure_stage='NONE'
    call report_trial(case_id,dt_index,material_id,se,forcing_id,coarse_dt,valid,failure_stage)
    write(*,'(*(g0))') 'ELASTIC60_PAIR|DT_INDEX=',dt_index,'|CASE=',case_id,'|M=',trim(material_id), &
         '|SE=',se,'|F=',trim(forcing_id),'|DT=',coarse_dt,'|HINF=',uh_inf_out
    write(*,'(*(g0))') 'ELASTIC58_TYPED_MASS|DT_INDEX=',dt_index,'|CASE=',case_id, &
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC60_FAIL pair output anchor")
    s=s.replace(old,new,1)

    out.write_text(s,encoding="utf-8")
    try: base.unlink()
    except OSError: pass
    print("F_PE_ELASTIC60_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
