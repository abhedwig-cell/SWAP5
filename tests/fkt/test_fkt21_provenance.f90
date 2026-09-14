program test_fkt21_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_sensitivity, only: &
       accepted_trajectory_direction_t, trajectory_step_token_t, TRAJECTORY_DIRECTION_FAILED, &
       configure_trajectory_direction, begin_or_continue_trajectory, build_trajectory_step_request, &
       stage_trajectory_step_result, discard_trajectory_step
  implicit none

  call test_cross_candidate_generation()
  call test_endpoint_bound_token()
  call test_nonmonotone_generation_rejected()
  call test_retry_aba_token_rejected()
  print '(A)', 'FKT21_PROVENANCE_HARDENING PASS'
  print '(A)', 'FKT21_CROSS_CANDIDATE_GENERATION=PASS'
  print '(A)', 'FKT21_STEP_ENDPOINT_TOKEN_BINDING=PASS'
  print '(A)', 'FKT21_NONMONOTONE_GENERATION_REJECTED=PASS'
  print '(A)', 'FKT21_RETRY_ABA_TOKEN_REJECTED=PASS'

contains

  subroutine test_cross_candidate_generation()
    type(accepted_trajectory_direction_t) :: s
    type(soil_water_accepted_step_direction_request_t) :: req
    type(soil_water_accepted_step_direction_result_t) :: res
    type(trajectory_step_token_t) :: stale, current
    logical :: ok

    call configure_trajectory_direction(s, .true.)
    call begin_or_continue_trajectory(s, 9, 0.25_real64, 0.75_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 101_int64)
    call assert_true(ok, 'first candidate begin')
    call build_trajectory_step_request(s, 0.25_real64, 0.50_real64, req, stale, ok)
    call assert_true(ok, 'first candidate token')

    ! Simulate outer rollback to the same committed physical origin followed by
    ! a distinct candidate. The runtime-owned generation is monotone and is not
    ! part of the rollback image.
    call discard_trajectory_step(s)
    call configure_trajectory_direction(s, .true.)
    call begin_or_continue_trajectory(s, 9, 0.25_real64, 0.75_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 102_int64)
    call assert_true(ok, 'second candidate begin')
    call build_trajectory_step_request(s, 0.25_real64, 0.50_real64, req, current, ok)
    call assert_true(ok, 'second candidate token')

    call available_result(res)
    call stage_trajectory_step_result(s, stale, res, ok)
    call assert_true(.not. ok .and. s%status == TRAJECTORY_DIRECTION_FAILED, &
         'stale previous-candidate token rejected')
  end subroutine test_cross_candidate_generation

  subroutine test_endpoint_bound_token()
    type(accepted_trajectory_direction_t) :: s
    type(soil_water_accepted_step_direction_request_t) :: req
    type(soil_water_accepted_step_direction_result_t) :: res
    type(trajectory_step_token_t) :: token, tampered
    logical :: ok

    call configure_trajectory_direction(s, .true.)
    call begin_or_continue_trajectory(s, 10, 0.11_real64, 0.91_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 201_int64)
    call build_trajectory_step_request(s, 0.11_real64, 0.37_real64, req, token, ok)
    call assert_true(ok, 'endpoint token build')
    tampered = token
    tampered%step_t1 = token%step_t1 + 0.01_real64
    call available_result(res)
    call stage_trajectory_step_result(s, tampered, res, ok)
    call assert_true(.not. ok .and. s%status == TRAJECTORY_DIRECTION_FAILED, &
         'endpoint-substituted token rejected')
  end subroutine test_endpoint_bound_token

  subroutine test_nonmonotone_generation_rejected()
    type(accepted_trajectory_direction_t) :: s
    logical :: ok

    call configure_trajectory_direction(s, .true.)
    call begin_or_continue_trajectory(s, 11, 0.20_real64, 0.80_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 301_int64)
    call assert_true(ok, 'monotone generation initial begin')
    call configure_trajectory_direction(s, .true.)
    call begin_or_continue_trajectory(s, 11, 0.20_real64, 0.80_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 301_int64)
    call assert_true(.not. ok .and. s%status == TRAJECTORY_DIRECTION_FAILED, &
         'reused generation rejected')
  end subroutine test_nonmonotone_generation_rejected

  subroutine test_retry_aba_token_rejected()
    type(accepted_trajectory_direction_t) :: s
    type(soil_water_accepted_step_direction_request_t) :: req
    type(soil_water_accepted_step_direction_result_t) :: res
    type(trajectory_step_token_t) :: stale, current
    logical :: ok

    call configure_trajectory_direction(s, .true.)
    call begin_or_continue_trajectory(s, 12, 0.30_real64, 0.90_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 401_int64)
    call assert_true(ok, 'retry ABA initial begin')
    call build_trajectory_step_request(s, 0.30_real64, 0.50_real64, req, stale, ok)
    call assert_true(ok, 'retry ABA first token')

    ! Reject the attempt before it can become an accepted step, then retry the
    ! exact same [t0,t1] inside the same outer candidate. The new issue must have
    ! distinct token identity; otherwise a delayed result from the rejected
    ! attempt could be mistaken for the retry (ABA replay).
    call discard_trajectory_step(s)
    call build_trajectory_step_request(s, 0.30_real64, 0.50_real64, req, current, ok)
    call assert_true(ok, 'retry ABA second token')
    call assert_true(current%step_sequence /= stale%step_sequence, &
         'retry ABA issue sequence advanced')

    call available_result(res)
    call stage_trajectory_step_result(s, stale, res, ok)
    call assert_true(.not. ok .and. s%status == TRAJECTORY_DIRECTION_FAILED, &
         'stale rejected-retry token rejected')
  end subroutine test_retry_aba_token_rejected

  subroutine available_result(res)
    type(soil_water_accepted_step_direction_result_t), intent(out) :: res
    res = soil_water_accepted_step_direction_result_t()
    res%status = SW_STEP_DIRECTION_AVAILABLE
    res%available = .true.
    allocate(res%outgoing_pressure_head(2), res%outgoing_water_content(2))
    res%outgoing_pressure_head = 0.0_real64
    res%outgoing_water_content = 0.0_real64
    res%bottom_flux_derivative = 1.0_real64
  end subroutine available_result

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,*) 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine assert_true

end program test_fkt21_provenance
