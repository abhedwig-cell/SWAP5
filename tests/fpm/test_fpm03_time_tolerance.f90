program test_fpm03_time_tolerance
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process, only: fixed_irrigation_event_t, irrigation_parameters_t, irrigation_state_t, &
       irrigation_management_request_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_fixed_irrigation_interval, IRRIGATION_OK, IRRIGATION_INVALID_STATE, IRRIGATION_SPLIT_REQUIRED, &
       IRRIGATION_APPLICATION_SURFACE
  implicit none

  type(irrigation_parameters_t) :: p
  type(irrigation_state_t) :: committed, candidate, active, perturbed
  type(irrigation_management_request_t) :: req
  type(irrigation_flux_result_t) :: flux
  type(irrigation_diagnostics_t) :: diag
  real(real64) :: event_end, scale, near_delta, far_delta

  p%fixed_irrigation_enabled = .true.
  allocate(p%fixed_events(1))
  p%fixed_events(1) = fixed_irrigation_event_t(100.0_real64, IRRIGATION_APPLICATION_SURFACE, &
       0.5_real64, 1.0_real64, 2.0_real64)
  event_end = 100.5_real64
  scale = max(1.0_real64,abs(event_end))
  near_delta = 16.0_real64 * epsilon(1.0_real64) * scale
  far_delta = 128.0_real64 * epsilon(1.0_real64) * scale

  ! A numerically equivalent event end is admitted and clamped to the exact
  ! physical event end, so mass does not depend on the caller's final ulps.
  req%t0 = 100.0_real64
  req%t1 = event_end + near_delta
  call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
  call require(diag%status == IRRIGATION_OK .and. .not. diag%split_required, 'near event end admitted')
  call require(flux%event_finished .and. .not. flux%event_remains_active, 'near event end finishes')
  call require(flux%active_duration == 0.5_real64, 'near event end duration clamped')
  call require(flux%external_inflow_amount == 0.5_real64, 'near event end mass clamped')
  call require(.not. candidate%active_event .and. candidate%next_fixed_event_index == 2, 'near event end state')

  ! A materially later end is still fail-closed and requests an exact split.
  req%t0 = 100.0_real64
  req%t1 = event_end + far_delta
  call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
  call require(diag%status == IRRIGATION_SPLIT_REQUIRED .and. diag%split_required, 'far event end split')
  call require(diag%split_time == event_end, 'far event end split time')
  call require(.not. flux%applied, 'far event end no flux')
  call require(candidate%next_fixed_event_index == committed%next_fixed_event_index .and. &
               candidate%active_event .eqv. committed%active_event, 'far event end no mutation')

  ! Build an active candidate, then perturb only the stored end by a few ulps.
  ! The continuation must remain valid because the physical end is reconstructed
  ! from immutable event data and active_event_start.
  req%t0 = 100.0_real64
  req%t1 = 100.25_real64
  call evaluate_fixed_irrigation_interval(p, committed, req, active, flux, diag)
  call require(diag%status == IRRIGATION_OK .and. active%active_event, 'active fixture')
  perturbed = active
  perturbed%active_event_end = perturbed%active_event_end + near_delta
  req%t0 = 100.25_real64
  req%t1 = event_end
  call evaluate_fixed_irrigation_interval(p, perturbed, req, candidate, flux, diag)
  call require(diag%status == IRRIGATION_OK .and. flux%event_finished, 'near stored end accepted')
  call require(flux%active_duration == 0.25_real64, 'continuation duration exact')

  perturbed = active
  perturbed%active_event_end = perturbed%active_event_end + far_delta
  call evaluate_fixed_irrigation_interval(p, perturbed, req, candidate, flux, diag)
  call require(diag%status == IRRIGATION_INVALID_STATE, 'far stored end rejected')
  call require(.not. flux%applied, 'far stored end no flux')

  write(*,'(A)') 'FPM03_TIME_NEAR_END_CLAMP=PASS'
  write(*,'(A)') 'FPM03_TIME_FAR_END_SPLIT=PASS'
  write(*,'(A)') 'FPM03_TIME_PERSISTED_END_ULP_TOLERANCE=PASS'
  write(*,'(A)') 'FPM03_TIME_TOLERANCE_TEST PASS'

contains

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM03_TIME_TOLERANCE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm03_time_tolerance
