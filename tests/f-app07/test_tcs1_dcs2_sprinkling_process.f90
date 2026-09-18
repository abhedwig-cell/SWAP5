program test_fapp07_tcs1_dcs2_sprinkling
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_tcs1_dcs2_sprinkling_irrigation_process
  implicit none

  type(tcs1_dcs2_sprinkling_parameters_t) :: p
  type(tcs1_dcs2_sprinkling_state_t) :: s, c
  type(tcs1_dcs2_sprinkling_request_t) :: r
  type(tcs1_dcs2_sprinkling_result_t) :: y
  type(tcs1_dcs2_sprinkling_diagnostics_t) :: d
  real(real64), parameter :: tol = 1.0e-12_real64
  real(real64) :: event_duration

  call setup_hupsel(p)
  event_duration = 2.0_real64/36.0_real64

  ! Outer management gate: no implicit selection.
  s = tcs1_dcs2_sprinkling_state_t()
  r = tcs1_dcs2_sprinkling_request_t()
  r%t0 = 158.0_real64; r%t1 = 159.0_real64
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. .not. y%applied .and. c%dayfix == 366,1)

  ! Hupsel no-stress opportunity: Tred=1, no event and mature dayfix remains 366.
  call setup_request(r,158.0_real64,0.0_real64,4.050658455243042e-24_real64,0.0_real64,0.0_real64)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. d%selection_evaluated .and. .not. d%stress_triggered,2)
  call require(.not. y%applied .and. c%dayfix == 366,3)

  ! 7 Aug 2003 source vector. A full-day trial must split at the event end.
  call setup_request(r,218.0_real64,1.3505714285714288_real64,0.5471354589029818_real64, &
                     0.2123937335777891_real64,0.0_real64)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_SPLIT_REQUIRED .and. d%split_required,4)
  call require(abs(d%transpiration_ratio-0.6118077705955248_real64) < tol,5)
  call require(abs(d%split_time-(218.0_real64+event_duration)) < tol,6)
  call require(.not. y%applied .and. c%dayfix == s%dayfix .and. .not. c%active_event,7)

  ! Retry ending at the exact split is the legacy event.
  r%t1 = 218.0_real64 + event_duration
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. y%applied .and. y%event_started .and. y%event_finished,8)
  call require(abs(d%interpolated_trel-0.85_real64) < tol,9)
  call require(abs(d%interpolated_depth_cm-2.0_real64) < tol,10)
  call require(abs(y%gross_surface_rate_cm_per_day-36.0_real64) < tol,11)
  call require(abs(y%event_duration_day-event_duration) < tol,12)
  call require(abs(y%external_inflow_amount_cm-2.0_real64) < tol,13)
  call require(c%dayfix == 1 .and. .not. c%active_event,14)

  ! 13 Aug 2003: raw TCS1 trigger is suppressed because pre-dayfix is 6.
  s = tcs1_dcs2_sprinkling_state_t(); s%dayfix = 6
  call setup_request(r,224.0_real64,1.4145952380952382_real64,0.5623513394029622_real64, &
                     0.18022047755438408_real64,0.0_real64)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. d%stress_triggered .and. .not. d%interval_gate_passed,15)
  call require(.not. y%applied .and. c%dayfix == 7,16)

  ! 14 Aug 2003: same stress family now passes TCSFIX and starts the 2 cm event.
  s = c
  call setup_request(r,225.0_real64,1.4235476190476193_real64,0.40396776352969294_real64, &
                     0.14829717147207683_real64,0.0_real64)
  r%t1 = 225.0_real64 + event_duration
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. d%interval_gate_passed .and. y%applied,17)
  call require(abs(d%transpiration_ratio-0.6328985011667236_real64) < tol .and. c%dayfix == 1,18)

  ! 26 Aug 2003 frozen Hupsel trigger.
  s = tcs1_dcs2_sprinkling_state_t(); s%dayfix = 12
  call setup_request(r,237.0_real64,1.5060476190476193_real64,0.31534971046284993_real64, &
                     0.11551480616973946_real64,0.0_real64)
  r%t1 = 237.0_real64 + event_duration
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. y%applied,19)
  call require(abs(d%transpiration_ratio-0.633693000700098_real64) < tol,20)

  ! Continuation is independent of a new selection opportunity.
  s = tcs1_dcs2_sprinkling_state_t(); s%dayfix = 7
  call setup_request(r,300.0_real64,1.5_real64,0.4_real64,0.1_real64,0.0_real64)
  r%t1 = 300.0_real64 + 0.5_real64*event_duration
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. y%event_started .and. y%event_remains_active .and. c%active_event,21)
  s = c
  r = tcs1_dcs2_sprinkling_request_t()
  r%t0 = 300.0_real64 + 0.5_real64*event_duration
  r%t1 = 300.0_real64 + event_duration
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. y%event_finished .and. .not. c%active_event,22)

  ! Fixed-event precedence: scheduled selection is not evaluated and dayfix is unchanged.
  s = tcs1_dcs2_sprinkling_state_t(); s%dayfix = 4
  call setup_request(r,310.0_real64,1.5_real64,0.4_real64,0.1_real64,0.0_real64)
  r%fixed_event_already_selected = .true.
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_OK .and. .not. d%selection_evaluated .and. c%dayfix == 4,23)

  ! Fail closed outside the explicit partial-table domain.
  s = tcs1_dcs2_sprinkling_state_t()
  call setup_request(r,320.0_real64,2.1_real64,0.4_real64,0.2_real64,0.0_real64)
  call evaluate_tcs1_dcs2_sprinkling_interval(p,s,r,c,y,d)
  call require(d%status == TCS1_DCS2_INVALID_PARAMETERS .and. .not. y%applied,24)

  print '(A)','F_APP07_TCS1_DCS2_HUPSEL_PROCESS=PASS'
  print '(A)','F_APP07_TCS1_DCS2_SPLIT_REPLAY=PASS'
  print '(A)','F_APP07_TCSFIX_DAYFIX=PASS'
  print '(A)','F_APP07_O0_O2_STABLE=PASS'

contains

  subroutine setup_hupsel(parameters)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(out) :: parameters
    parameters = tcs1_dcs2_sprinkling_parameters_t()
    parameters%enabled = .true.
    parameters%rate_cm_per_day = 36.0_real64
    parameters%threshold_knot_count = 2
    parameters%threshold_dvs(1:2) = [0.0_real64,2.0_real64]
    parameters%threshold_trel(1:2) = [0.85_real64,0.85_real64]
    parameters%depth_knot_count = 2
    parameters%depth_dvs(1:2) = [0.0_real64,2.0_real64]
    parameters%depth_cm(1:2) = [2.0_real64,2.0_real64]
    parameters%minimum_interval_days = 7
  end subroutine setup_hupsel

  subroutine setup_request(request,t0,dvs,iptra,iqdry,iqsol)
    type(tcs1_dcs2_sprinkling_request_t), intent(out) :: request
    real(real64), intent(in) :: t0,dvs,iptra,iqdry,iqsol
    request = tcs1_dcs2_sprinkling_request_t()
    request%t0 = t0
    request%t1 = t0 + 1.0_real64
    request%dvs = dvs
    request%potential_transpiration_day_cm = iptra
    request%dry_reduction_day_cm = iqdry
    request%salinity_reduction_day_cm = iqsol
    request%selection_opportunity = .true.
    request%irrigation_enabled = .true.
    request%schedule_enabled = .true.
    request%crop_emerged = .true.
    request%irrigation_window_open = .true.
  end subroutine setup_request

  subroutine require(ok,n)
    logical, intent(in) :: ok
    integer, intent(in) :: n
    if (.not. ok) then
      write(*,'(A,I0)') 'F_APP07_FAIL=',n
      error stop 1
    end if
  end subroutine require
end program test_fapp07_tcs1_dcs2_sprinkling
