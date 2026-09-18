program test_fvq124_fapp07_tcs1_dcs2_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_tcs1_dcs2_sprinkling_irrigation_process
  implicit none
  type(tcs1_dcs2_sprinkling_parameters_t) :: p
  type(tcs1_dcs2_sprinkling_state_t) :: s, c1, c2
  type(tcs1_dcs2_sprinkling_request_t) :: r
  type(tcs1_dcs2_sprinkling_result_t) :: y1, y2
  type(tcs1_dcs2_sprinkling_diagnostics_t) :: d1, d2
  real(real64), parameter :: tol=1.0e-12_real64
  real(real64) :: tred, dur

  call hupsel_parameters(p)
  dur = 2.0_real64/36.0_real64

  ! Independent 7 Aug 2003 oracle from B1.11 source observation.
  s=tcs1_dcs2_sprinkling_state_t()
  call req(r,218.0_real64,1.3505714285714288_real64,0.5471354589029818_real64,0.2123937335777891_real64)
  tred=1.0_real64-0.2123937335777891_real64/0.5471354589029818_real64
  call require(abs(tred-0.6118077705955248_real64)<tol,1)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call require(d1%status==TCS1_DCS2_SPLIT_REQUIRED .and. d1%split_required,2)
  call require(abs(d1%transpiration_ratio-tred)<tol,3)
  call require(abs(d1%interpolated_trel-0.85_real64)<tol,4)
  call require(abs(d1%interpolated_depth_cm-2.0_real64)<tol,5)
  call require(abs(d1%split_time-(218.0_real64+dur))<tol,6)
  call require(.not.y1%applied .and. c1%dayfix==s%dayfix .and. .not.c1%active_event,7)

  r%t1=218.0_real64+dur
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call require(d1%status==TCS1_DCS2_OK .and. y1%event_started .and. y1%event_finished,8)
  call require(abs(y1%gross_surface_rate_cm_per_day-36.0_real64)<tol,9)
  call require(abs(y1%event_duration_day-dur)<tol,10)
  call require(abs(y1%external_inflow_amount_cm-2.0_real64)<tol,11)
  call require(c1%dayfix==1 .and. .not.c1%active_event,12)

  ! Independent TCSFIX cadence: 13 Aug suppressed at pre-dayfix 6, 14 Aug accepted at 7.
  s=tcs1_dcs2_sprinkling_state_t(); s%dayfix=6
  call req(r,224.0_real64,1.4145952380952382_real64,0.5623513394029622_real64,0.18022047755438408_real64)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call require(d1%status==TCS1_DCS2_OK .and. d1%stress_triggered .and. .not.d1%interval_gate_passed,13)
  call require(.not.y1%applied .and. c1%dayfix==7,14)

  s=c1
  call req(r,225.0_real64,1.4235476190476193_real64,0.40396776352969294_real64,0.14829717147207683_real64)
  r%t1=225.0_real64+dur
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call require(d1%status==TCS1_DCS2_OK .and. d1%interval_gate_passed .and. y1%applied,15)
  call require(abs(d1%transpiration_ratio-0.6328985011667236_real64)<tol,16)

  ! Continuation must not depend on a second selection opportunity.
  s=tcs1_dcs2_sprinkling_state_t(); s%dayfix=7
  call req(r,300.0_real64,1.5_real64,0.4_real64,0.1_real64)
  r%t1=300.0_real64+0.5_real64*dur
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call require(d1%status==TCS1_DCS2_OK .and. y1%event_started .and. y1%event_remains_active .and. c1%active_event,17)
  s=c1
  r=tcs1_dcs2_sprinkling_request_t()
  r%t0=300.0_real64+0.5_real64*dur; r%t1=300.0_real64+dur
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call require(d1%status==TCS1_DCS2_OK .and. y1%event_finished .and. abs(y1%external_inflow_amount_cm-1.0_real64)<tol,18)

  ! A-B-A determinism from identical committed state.
  s=tcs1_dcs2_sprinkling_state_t(); s%dayfix=12
  call req(r,237.0_real64,1.5060476190476193_real64,0.31534971046284993_real64,0.11551480616973946_real64)
  r%t1=237.0_real64+dur
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call req(r,400.0_real64,0.2_real64,1.0_real64,0.0_real64)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c2,y2,d2)
  call req(r,237.0_real64,1.5060476190476193_real64,0.31534971046284993_real64,0.11551480616973946_real64)
  r%t1=237.0_real64+dur
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c2,y2,d2)
  call require(d1%status==d2%status .and. y1%applied.eqv.y2%applied .and. c1%dayfix==c2%dayfix,19)
  call require(abs(y1%external_inflow_amount_cm-y2%external_inflow_amount_cm)<tol,20)

  ! Fail closed above a partial table's final knot.
  s=tcs1_dcs2_sprinkling_state_t()
  call req(r,500.0_real64,2.1_real64,0.4_real64,0.2_real64)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c1,y1,d1)
  call require(d1%status==TCS1_DCS2_INVALID_PARAMETERS .and. .not.y1%applied,21)

  print '(A)','F_VQ124_B110_EQUATION_ORACLE=PASS'
  print '(A)','F_VQ124_TCSFIX_CADENCE=PASS'
  print '(A)','F_VQ124_SPLIT_ROLLBACK_REPLAY=PASS'
  print '(A)','F_VQ124_A_B_A=PASS'
  print '(A)','F_VQ124_FAIL_CLOSED=PASS'
contains
  subroutine hupsel_parameters(x)
    type(tcs1_dcs2_sprinkling_parameters_t),intent(out)::x
    x=tcs1_dcs2_sprinkling_parameters_t()
    x%enabled=.true.; x%rate_cm_per_day=36.0_real64
    x%threshold_knot_count=2; x%threshold_dvs(1:2)=[0.0_real64,2.0_real64]
    x%threshold_trel(1:2)=[0.85_real64,0.85_real64]
    x%depth_knot_count=2; x%depth_dvs(1:2)=[0.0_real64,2.0_real64]
    x%depth_cm(1:2)=[2.0_real64,2.0_real64]; x%minimum_interval_days=7
  end subroutine
  subroutine req(x,t0,dvs,iptra,iqdry)
    type(tcs1_dcs2_sprinkling_request_t),intent(out)::x
    real(real64),intent(in)::t0,dvs,iptra,iqdry
    x=tcs1_dcs2_sprinkling_request_t()
    x%t0=t0; x%t1=t0+1.0_real64; x%dvs=dvs
    x%potential_transpiration_day_cm=iptra; x%dry_reduction_day_cm=iqdry
    x%selection_opportunity=.true.; x%irrigation_enabled=.true.; x%schedule_enabled=.true.
    x%crop_emerged=.true.; x%irrigation_window_open=.true.
  end subroutine
  subroutine require(ok,n)
    logical,intent(in)::ok; integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'F_VQ124_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fvq124_fapp07_tcs1_dcs2_independent
