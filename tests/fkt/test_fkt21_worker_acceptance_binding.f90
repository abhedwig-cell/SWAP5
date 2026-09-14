program test_fkt21_worker_acceptance_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_sensitivity, only: trajectory_step_token_t, &
       configure_trajectory_direction, begin_or_continue_trajectory, build_trajectory_step_request, &
       stage_trajectory_step_result
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker, &
       a23bu_release_worker, a23bu_discard_unaccepted_trajectory_step, a23bu_accept_pending_trajectory_step
  implicit none

  type(a23bu_worker_context_t) :: worker
  type(soil_water_accepted_step_direction_request_t) :: request
  type(soil_water_accepted_step_direction_result_t) :: result
  type(trajectory_step_token_t) :: token
  logical :: ok
  real(real64), parameter :: tol = 1.0e-13_real64

  call a23bu_initialize_worker(worker, 3, worker_id=17)
  call configure_trajectory_direction(worker%trajectory_direction, .true.)
  call begin_or_continue_trajectory(worker%trajectory_direction, 17, 2.25_real64, 2.75_real64, &
       SW_STEP_CONTROL_BOTTOM_FLUX, 3, ok, generation_seed=101_int64)
  call require(ok, 'initial trajectory begin')

  ! First physical task-2 candidate is staged but then retried. A replacement
  ! task-2 call must discard it before any accepted trajectory mutation occurs.
  call build_trajectory_step_request(worker%trajectory_direction, 2.25_real64, 2.35_real64, request, token, ok)
  call require(ok, 'first step request')
  call make_available_result(result, 1.0_real64, 2.0_real64)
  call stage_trajectory_step_result(worker%trajectory_direction, token, result, ok)
  call require(ok .and. worker%trajectory_direction%pending, 'first result staged')
  call a23bu_discard_unaccepted_trajectory_step(worker)
  call require(.not. worker%trajectory_direction%pending .and. .not. worker%trajectory_direction%issued, &
       'retry discard clears pending candidate')
  call require(worker%trajectory_direction%accepted_steps == 0, 'retry discard leaves accepted count')
  call require(abs(worker%trajectory_direction%current_t1-2.25_real64) <= tol, 'retry discard leaves trajectory time')
  call require(abs(worker%trajectory_direction%integrated_bottom_exchange_derivative) <= tol, &
       'retry discard leaves exchange derivative')
  write(*,'(a)') 'FKT21_WORKER_RETRY_DISCARD=PASS'

  ! Replacement task-2 candidate is staged and then SoilWater task 3 accepts it.
  call build_trajectory_step_request(worker%trajectory_direction, 2.25_real64, 2.35_real64, request, token, ok)
  call require(ok, 'replacement step request')
  call make_available_result(result, 3.0_real64, 2.0_real64)
  call stage_trajectory_step_result(worker%trajectory_direction, token, result, ok)
  call require(ok, 'replacement result staged')
  call a23bu_accept_pending_trajectory_step(worker)
  call require(worker%trajectory_direction%accepted_steps == 1, 'task3 accepted one step')
  call require(abs(worker%trajectory_direction%current_t1-2.35_real64) <= tol, 'task3 advances trajectory time')
  call require(abs(worker%trajectory_direction%pressure_head_direction(1)-3.0_real64) <= tol, &
       'task3 promotes direction vector')
  call require(abs(worker%trajectory_direction%integrated_bottom_exchange_derivative-0.2_real64) <= 5.0e-13_real64, &
       'task3 promotes integrated exchange derivative')
  write(*,'(a)') 'FKT21_TASK3_ACCEPT_BINDING=PASS'

  call a23bu_release_worker(worker)
  write(*,'(a)') 'FKT21_WORKER_ACCEPTANCE_BINDING PASS'

contains

  subroutine make_available_result(value)
    type(soil_water_accepted_step_direction_result_t), intent(out) :: value
    real(real64), intent(in), optional :: dummy
  end subroutine make_available_result

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FKT21_WORKER_ACCEPTANCE_BINDING FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fkt21_worker_acceptance_binding
