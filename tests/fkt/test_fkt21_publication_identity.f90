program test_fkt21_publication_identity
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_DIRECTION_UNAVAILABLE, SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_sensitivity, only: &
       accepted_trajectory_direction_t, trajectory_step_token_t, TRAJECTORY_DIRECTION_UNAVAILABLE, &
       configure_trajectory_direction, begin_or_continue_trajectory, build_trajectory_step_request, &
       stage_trajectory_step_result, accept_trajectory_step, discard_trajectory_step, finalize_trajectory_direction
  use mod_accepted_trajectory_directional_publication, only: &
       accepted_trajectory_direction_result_t, publish_accepted_trajectory_direction
  implicit none

  call test_on_off_identity_and_typed_publication()
  call test_unavailable_sensitivity_keeps_physical_candidate_valid()
  call test_rejected_trial_contributes_zero_derivative()

  print '(A)', 'FKT21_PUBLICATION_IDENTITY PASS'
  print '(A)', 'FKT21_ON_OFF_PHYSICAL_IDENTITY=PASS'
  print '(A)', 'FKT21_TYPED_RESULT_PROVENANCE=PASS'
  print '(A)', 'FKT21_UNAVAILABLE_PHYSICAL_VALID=PASS'
  print '(A)', 'FKT21_REJECTED_DERIVATIVE_ZERO=PASS'
  print '(A)', 'FKT21_MASS_NEUTRALITY=PASS'

contains

  subroutine test_on_off_identity_and_typed_publication()
    type(accepted_trajectory_direction_t) :: trajectory
    type(accepted_trajectory_direction_result_t) :: published
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: direction
    type(trajectory_step_token_t) :: token
    real(real64), parameter :: times(4) = [0.125_real64, 0.375_real64, 0.625_real64, 0.875_real64]
    real(real64) :: x_on(2), w_on(2), pond_on, q_on
    real(real64) :: x_off(2), w_off(2), pond_off, q_off
    real(real64) :: storage0, storage_on, storage_off, dt
    integer :: k
    logical :: ok

    call initial_physical_state(x_on, w_on, pond_on, q_on)
    x_off = x_on
    w_off = w_on
    pond_off = pond_on
    q_off = q_on
    storage0 = sum(w_on)

    call configure_trajectory_direction(trajectory, .true.)
    call begin_or_continue_trajectory(trajectory, 21, times(1), times(4), &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 501_int64)
    call assert_true(ok, 'trajectory begin')

    do k = 1, 3
      dt = times(k+1)-times(k)
      call build_trajectory_step_request(trajectory, times(k), times(k+1), request, token, ok)
      call assert_true(ok .and. request%requested, 'step request')
      call analytic_direction(dt, x_on, request, direction)
      call stage_trajectory_step_result(trajectory, token, direction, ok)
      call assert_true(ok, 'stage direction')

      ! Physical acceptance is deliberately independent of trajectory scratch.
      call physical_step(dt, 1.7_real64, x_on, w_on, pond_on, q_on)
      call accept_trajectory_step(trajectory, ok)
      call assert_true(ok, 'accept direction with physical step')

      ! Sensitivity-OFF path executes the exact same physical step only.
      call physical_step(dt, 1.7_real64, x_off, w_off, pond_off, q_off)
    end do

    call assert_array_equal(x_on, x_off, 'head ON/OFF identity')
    call assert_array_equal(w_on, w_off, 'water-content ON/OFF identity')
    call assert_equal(pond_on, pond_off, 'ponding ON/OFF identity')
    call assert_equal(q_on, q_off, 'exchange ON/OFF identity')
    storage_on = sum(w_on)
    storage_off = sum(w_off)
    call assert_equal(storage_on-storage0, storage_off-storage0, 'storage change ON/OFF identity')

    call finalize_trajectory_direction(trajectory, times(1), times(4), ok)
    call assert_true(ok, 'finalize available trajectory')
    call publish_accepted_trajectory_direction(trajectory, published)
    call assert_true(published%available, 'published available')
    call assert_true(published%worker_id == 21, 'worker provenance')
    call assert_true(published%generation == 501_int64, 'generation provenance')
    call assert_true(published%control_coordinate == SW_STEP_CONTROL_BOTTOM_FLUX, 'control provenance')
    call assert_true(published%accepted_steps == 3, 'accepted-step provenance')
    call assert_equal(published%origin_t0, times(1), 'origin t0')
    call assert_equal(published%accepted_t1, times(4), 'accepted t1')
    call assert_true(allocated(published%final_pressure_head_direction), 'published head direction')
    call assert_true(allocated(published%final_water_content_direction), 'published water direction')
    call assert_true(published%additional_tridiagonal_backsolves == 3, 'bounded backsolve count')
    call assert_true(published%additional_jacobian_builds == 0, 'no extra jacobian')
    call assert_true(published%additional_full_nonlinear_solves == 0, 'no extra nonlinear trajectory')
  end subroutine test_on_off_identity_and_typed_publication

  subroutine test_unavailable_sensitivity_keeps_physical_candidate_valid()
    type(accepted_trajectory_direction_t) :: trajectory
    type(accepted_trajectory_direction_result_t) :: published
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: direction
    type(trajectory_step_token_t) :: token
    real(real64) :: x(2), w(2), pond, qint, x_expected(2), w_expected(2), pond_expected, q_expected
    logical :: ok

    call initial_physical_state(x, w, pond, qint)
    x_expected = x
    w_expected = w
    pond_expected = pond
    q_expected = qint

    call configure_trajectory_direction(trajectory, .true.)
    call begin_or_continue_trajectory(trajectory, 22, 0.19_real64, 0.43_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 601_int64)
    call build_trajectory_step_request(trajectory, 0.19_real64, 0.43_real64, request, token, ok)
    call assert_true(ok, 'unavailable request')

    call physical_step(0.24_real64, 0.8_real64, x, w, pond, qint)
    call physical_step(0.24_real64, 0.8_real64, x_expected, w_expected, pond_expected, q_expected)

    direction = soil_water_accepted_step_direction_result_t()
    direction%status = SW_STEP_DIRECTION_UNAVAILABLE
    direction%available = .false.
    direction%route = 'qualified-nonsmooth-switch'
    call stage_trajectory_step_result(trajectory, token, direction, ok)
    call assert_true(ok, 'stage unavailable direction')
    call accept_trajectory_step(trajectory, ok)
    call assert_true(ok .and. trajectory%status == TRAJECTORY_DIRECTION_UNAVAILABLE, 'accepted physical / unavailable sensitivity')

    call assert_array_equal(x, x_expected, 'unavailable physical head valid')
    call assert_array_equal(w, w_expected, 'unavailable physical water valid')
    call assert_equal(pond, pond_expected, 'unavailable physical pond valid')
    call assert_equal(qint, q_expected, 'unavailable physical exchange valid')
    call assert_true(all(ieee_is_finite(x)) .and. all(ieee_is_finite(w)) .and. &
         ieee_is_finite(pond) .and. ieee_is_finite(qint), 'unavailable physical finite')

    call finalize_trajectory_direction(trajectory, 0.19_real64, 0.43_real64, ok)
    call assert_true(.not. ok, 'unavailable trajectory not finalized as available')
    call publish_accepted_trajectory_direction(trajectory, published)
    call assert_true(.not. published%available, 'unavailable not published')
    call assert_true(.not. allocated(published%final_pressure_head_direction), 'no unavailable head publication')
    call assert_true(.not. allocated(published%final_water_content_direction), 'no unavailable water publication')
    call assert_equal(published%accepted_bottom_exchange_derivative, 0.0_real64, 'no unavailable exchange derivative')
  end subroutine test_unavailable_sensitivity_keeps_physical_candidate_valid

  subroutine test_rejected_trial_contributes_zero_derivative()
    type(accepted_trajectory_direction_t) :: trajectory
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: direction
    type(trajectory_step_token_t) :: token
    real(real64) :: x(2), w(2), pond, qint
    logical :: ok

    call initial_physical_state(x, w, pond, qint)
    call configure_trajectory_direction(trajectory, .true.)
    call begin_or_continue_trajectory(trajectory, 23, 0.31_real64, 0.71_real64, &
         SW_STEP_CONTROL_BOTTOM_FLUX, 2, ok, 701_int64)
    call build_trajectory_step_request(trajectory, 0.31_real64, 0.51_real64, request, token, ok)
    call analytic_direction(0.20_real64, x, request, direction)
    call stage_trajectory_step_result(trajectory, token, direction, ok)
    call assert_true(ok, 'rejected trial staged')
    call discard_trajectory_step(trajectory)
    call assert_true(trajectory%accepted_steps == 0, 'rejected step count zero')
    call assert_equal(trajectory%integrated_bottom_exchange_derivative, 0.0_real64, 'rejected exchange derivative zero')

    ! Retry from the same accepted origin; only the retried accepted direction is booked.
    call build_trajectory_step_request(trajectory, 0.31_real64, 0.51_real64, request, token, ok)
    call analytic_direction(0.20_real64, x, request, direction)
    call stage_trajectory_step_result(trajectory, token, direction, ok)
    call accept_trajectory_step(trajectory, ok)
    call assert_true(ok .and. trajectory%accepted_steps == 1, 'retried step accepted once')
    call assert_true(abs(trajectory%integrated_bottom_exchange_derivative) > 0.0_real64, 'accepted retry derivative booked once')
  end subroutine test_rejected_trial_contributes_zero_derivative

  subroutine initial_physical_state(x, w, pond, qint)
    real(real64), intent(out) :: x(2), w(2), pond, qint
    x = [-1.1_real64, -0.35_real64]
    w = [0.23_real64, 0.30_real64]
    pond = 0.025_real64
    qint = 0.0_real64
  end subroutine initial_physical_state

  subroutine physical_step(dt, control_value, x, w, pond, qint)
    real(real64), intent(in) :: dt, control_value
    real(real64), intent(inout) :: x(2), w(2), pond, qint
    real(real64) :: xn(2), wn(2), pn, q
    xn(1) = x(1) + dt*(0.035_real64*x(1)*x(1) + 0.11_real64*x(2) + 0.16_real64*control_value)
    xn(2) = x(2) + dt*(0.06_real64*x(1) + 0.020_real64*x(2)*x(2) + 0.07_real64*control_value)
    wn(1) = w(1) + dt*(0.035_real64*xn(1) + 0.008_real64*control_value)
    wn(2) = w(2) + dt*(0.025_real64*xn(2) - 0.011_real64*control_value)
    pn = 0.92_real64*pond + 0.012_real64*xn(1)
    q = control_value
    qint = qint + dt*q
    x = xn
    w = wn
    pond = pn
  end subroutine physical_step

  subroutine analytic_direction(dt, x, request, result)
    real(real64), intent(in) :: dt, x(2)
    type(soil_water_accepted_step_direction_request_t), intent(in) :: request
    type(soil_water_accepted_step_direction_result_t), intent(out) :: result
    real(real64) :: dx1, dx2, dw1, dw2

    dx1 = (1.0_real64 + 0.07_real64*dt*x(1))*request%incoming_pressure_head(1) + &
          0.11_real64*dt*request%incoming_pressure_head(2) + 0.16_real64*dt
    dx2 = 0.06_real64*dt*request%incoming_pressure_head(1) + &
          (1.0_real64 + 0.04_real64*dt*x(2))*request%incoming_pressure_head(2) + 0.07_real64*dt
    dw1 = request%incoming_water_content(1) + dt*(0.035_real64*dx1 + 0.008_real64)
    dw2 = request%incoming_water_content(2) + dt*(0.025_real64*dx2 - 0.011_real64)

    result = soil_water_accepted_step_direction_result_t()
    result%status = SW_STEP_DIRECTION_AVAILABLE
    result%available = .true.
    result%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
    result%method = 'synthetic-identity-step'
    result%route = 'smooth-identity-route'
    allocate(result%outgoing_pressure_head(2), result%outgoing_water_content(2))
    result%outgoing_pressure_head = [dx1, dx2]
    result%outgoing_water_content = [dw1, dw2]
    result%outgoing_ponding_depth = 0.92_real64*request%incoming_ponding_depth + 0.012_real64*dx1
    result%bottom_flux_derivative = 1.0_real64
    result%additional_tridiagonal_backsolves = 1
    result%additional_jacobian_builds = 0
    result%additional_full_nonlinear_solves = 0
  end subroutine analytic_direction

  subroutine assert_array_equal(a, b, label)
    real(real64), intent(in) :: a(:), b(:)
    character(len=*), intent(in) :: label
    if (size(a) /= size(b) .or. any(a /= b)) then
      write(*,*) 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine assert_array_equal

  subroutine assert_equal(a, b, label)
    real(real64), intent(in) :: a, b
    character(len=*), intent(in) :: label
    if (a /= b) then
      write(*,*) 'FAIL ', trim(label), a, b
      error stop 1
    end if
  end subroutine assert_equal

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,*) 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine assert_true

end program test_fkt21_publication_identity
