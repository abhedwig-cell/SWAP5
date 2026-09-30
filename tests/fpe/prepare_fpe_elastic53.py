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
        "python3",str(root/"tests/fpe/prepare_fpe_elastic50.py"),
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

    anchor="""  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
"""
    insert="""  use mod_fpe_elastic53_reference_richards_temporal_indicator, only: &
       evaluate_fpe_elastic53_reference_richards_temporal_indicator
  use mod_soil_water_solver_contract, only: soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_TEMPORAL_INDICATOR_AVAILABLE
"""
    if anchor not in s: raise SystemExit("F_PE_ELASTIC53_FAIL use anchor")
    s=s.replace(anchor,anchor+insert,1)

    old="""  type(soil_water_solve_result_t)::res_full,res_half1,res_half2
"""
    new="""  type(soil_water_solve_result_t)::res_full,res_half1,res_half2
  type(soil_water_temporal_indicator_request_t)::indicator_request
  type(soil_water_temporal_indicator_result_t)::indicator
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC53_FAIL type anchor")
    s=s.replace(old,new,1)

    old="""  logical::all_converged,exact_identity
"""
    new="""  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC53_FAIL logical anchor")
    s=s.replace(old,new,1)

    old="""  call solver_full%solve(req_full,ws_full,res_full)

  call bind_b110_default_mvg_provider(constitutive_half,p%prepared_default_mvg,0.5_real64*dt)
"""
    new="""  call solver_full%solve(req_full,ws_full,res_full)

  indicator_available=.false.
  indicator_binf=0.0_real64;indicator_raw=0.0_real64;indicator_defect=0.0_real64
  indicator_request=soil_water_temporal_indicator_request_t()
  indicator=soil_water_temporal_indicator_result_t()
  if(res_full%status==SW_SOLVE_CONVERGED)then
    indicator_request%previous_right_derivative_available=.true.
    allocate(indicator_request%previous_right_derivative(N))
    indicator_request%previous_right_derivative=0.0_real64
    call evaluate_fpe_elastic53_reference_richards_temporal_indicator(req_full,res_full,indicator_request,indicator)
    indicator_available=indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.indicator%available
    if(indicator_available)then
      indicator_binf=indicator%head_inf_bound
      indicator_raw=indicator%raw_m_norm
      indicator_defect=indicator%defect_m_norm
      call req(ieee_is_finite(indicator_binf).and.indicator_binf>=0.0_real64,'finite indicator')
    end if
  end if

  call bind_b110_default_mvg_provider(constitutive_half,p%prepared_default_mvg,0.5_real64*dt)
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC53_FAIL solve anchor")
    s=s.replace(old,new,1)

    old="""       '|storage_half=',storage_half,'|exact_identity=',exact_identity, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
"""
    new="""       '|storage_half=',storage_half,'|exact_identity=',exact_identity, &
       '|indicator_available=',indicator_available,'|indicator_binf=',indicator_binf, &
       '|indicator_raw=',indicator_raw,'|indicator_defect=',indicator_defect, &
       '|full_nonlinear=',res_full%diagnostics%nonlinear_iterations,'|half1_nonlinear=',res_half1%diagnostics%nonlinear_iterations, &
"""
    if old not in s: raise SystemExit("F_PE_ELASTIC53_FAIL output anchor")
    s=s.replace(old,new,1)
    s=s.replace("ELASTIC50_DIFF|","ELASTIC53_BANK|")
    s=s.replace("F_PE_ELASTIC50_EXEC=PASS","F_PE_ELASTIC53_EXEC=PASS")
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC53_PREP=PASS")

if __name__=="__main__":
    main()
