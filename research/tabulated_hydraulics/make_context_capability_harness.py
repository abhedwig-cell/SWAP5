#!/usr/bin/env python3
"""Create TAB-HYD-CTX01 equivalence harness from the existing temporal harness."""
from pathlib import Path
import sys
if len(sys.argv)!=3:
    raise SystemExit("usage: make_context_capability_harness.py INPUT.f90 OUTPUT.f90")
s=Path(sys.argv[1]).read_text()

s=s.replace(
"""       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE
""",
"""       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE, &
       SW_TEMPORAL_INDICATOR_FAILED
""",1)
s=s.replace(
"""  use mod_reference_richards_temporal_indicator_generic_research, only: &
       evaluate_reference_richards_temporal_indicator_generic
""",
"""  use mod_reference_richards_temporal_indicator_context_research, only: &
       evaluate_reference_richards_temporal_indicator_context
""",1)
s=s.replace(
"""  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, &
       initialize_tabhyd_raw_provider_from_mvg, TABHYD_RAW_TABLE_N
""",
"""  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, &
       initialize_tabhyd_raw_provider_from_mvg, bind_tabhyd_raw_provider_step_duration, TABHYD_RAW_TABLE_N
""",1)
s=s.replace(
"""  type(soil_water_temporal_indicator_result_t) :: ican, igen_a, ican_t, igen_t
""",
"""  type(soil_water_temporal_indicator_result_t) :: ican, igen_a, ican_t, igen_t, mismatch_a, mismatch_t
""",1)
s=s.replace("evaluate_reference_richards_temporal_indicator_generic(","evaluate_reference_richards_temporal_indicator_context(")

anchor="""  call evaluate_reference_richards_temporal_indicator_context(req_t,res_t,ireq,igen_t)
  call require(igen_t%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. igen_t%available,'generic table indicator available')
  call require(ieee_is_finite(igen_t%head_inf_bound) .and. igen_t%head_inf_bound>=0.0_real64,'table head bound finite')
  call require(all(ieee_is_finite(igen_t%current_right_derivative)),'table derivative finite')

"""
insert=anchor+"""  ! CTX-G3: deliberate provider/request timestep mismatch must fail closed.
  call bind_b110_default_mvg_provider(analytic,hp,1.25_real64*step_duration)
  call evaluate_reference_richards_temporal_indicator_context(req_a,res_a,ireq,mismatch_a)
  call require(mismatch_a%status==SW_TEMPORAL_INDICATOR_FAILED,'analytic dt mismatch failed')
  call require(trim(mismatch_a%route)=='constitutive-dt-mismatch','analytic dt mismatch route')
  call bind_b110_default_mvg_provider(analytic,hp,step_duration)

  call bind_tabhyd_raw_provider_step_duration(table,1.25_real64*step_duration)
  call evaluate_reference_richards_temporal_indicator_context(req_t,res_t,ireq,mismatch_t)
  call require(mismatch_t%status==SW_TEMPORAL_INDICATOR_FAILED,'table dt mismatch failed')
  call require(trim(mismatch_t%route)=='constitutive-dt-mismatch','table dt mismatch route')
  call bind_tabhyd_raw_provider_step_duration(table,step_duration)

"""
if s.count(anchor)!=1:
    raise SystemExit(f"harness normal-table anchor mismatch: {s.count(anchor)}")
s=s.replace(anchor,insert,1)

s=s.replace(
"""  write(*,'(a)') 'TABHYD_TEMPORAL_PHASE_A=PASS'
  write(*,'(a)') 'TABHYD_TEMPORAL_PHASE_B=PASS'
""",
"""  write(*,'(a)') 'TABHYD_CTX01_ANALYTIC_IDENTITY=PASS'
  write(*,'(a)') 'TABHYD_CTX01_TABLE_AVAILABLE=PASS'
  write(*,'(a)') 'TABHYD_CTX01_ANALYTIC_DT_MISMATCH_FAIL_CLOSED=PASS'
  write(*,'(a)') 'TABHYD_CTX01_TABLE_DT_MISMATCH_FAIL_CLOSED=PASS'
""",1)

Path(sys.argv[2]).write_text(s)
print("TABHYD_CTX01_HARNESS_CREATED")
