program test_fpe_zero_waste01_hdir04_consuming_stage
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_sensitivity, only: &
       accepted_trajectory_direction_t, trajectory_step_token_t, configure_trajectory_direction, &
       begin_or_continue_trajectory, build_trajectory_step_request, stage_trajectory_step_result, &
       stage_trajectory_step_result_consuming, accept_trajectory_step, TRAJECTORY_DIRECTION_FAILED
  implicit none

  integer, parameter :: n = 6
  type(accepted_trajectory_direction_t) :: copy_state, move_state, fail_state
  type(soil_water_accepted_step_direction_request_t) :: copy_request, move_request, fail_request
  type(soil_water_accepted_step_direction_result_t) :: copy_result, move_result, fail_result
  type(trajectory_step_token_t) :: copy_token, move_token, fail_token
  logical :: ok
  real(real64) :: expected_h(n), expected_theta(n)
  integer :: i

  do i=1,n
    expected_h(i)=0.01_real64*real(i,real64)
    expected_theta(i)=-0.02_real64*real(i,real64)
  end do

  call prepare_state(copy_state,copy_request,copy_token)
  call prepare_result(copy_result,expected_h,expected_theta)
  call stage_trajectory_step_result(copy_state,copy_token,copy_result,ok)
  call require(ok,'copy stage accepted')
  call require(allocated(copy_result%outgoing_pressure_head) .and. &
       allocated(copy_result%outgoing_water_content),'copy stage retains result ownership')
  call accept_trajectory_step(copy_state,ok)
  call require(ok,'copy accept')
  call require(all(copy_state%pressure_head_direction == expected_h) .and. &
       all(copy_state%water_content_direction == expected_theta),'copy trajectory values')
  print '(a)', 'FPE_ZERO_WASTE01_HDIR04_COPY_API_PRESERVED=PASS'

  call prepare_state(move_state,move_request,move_token)
  call prepare_result(move_result,expected_h,expected_theta)
  call stage_trajectory_step_result_consuming(move_state,move_token,move_result,ok)
  call require(ok,'consuming stage accepted')
  call require(.not. allocated(move_result%outgoing_pressure_head) .and. &
       .not. allocated(move_result%outgoing_water_content),'consuming stage transfers result ownership')
  call require(allocated(move_state%pending_pressure_head_direction) .and. &
       allocated(move_state%pending_water_content_direction),'pending owns transferred vectors')
  call accept_trajectory_step(move_state,ok)
  call require(ok,'consuming accept')
  call require(all(move_state%pressure_head_direction == expected_h) .and. &
       all(move_state%water_content_direction == expected_theta),'consuming trajectory values')
  call require(.not. allocated(move_state%pending_pressure_head_direction) .and. &
       .not. allocated(move_state%pending_water_content_direction),'accepted pending ownership cleared')
  call require(all(move_state%pressure_head_direction == copy_state%pressure_head_direction) .and. &
       all(move_state%water_content_direction == copy_state%water_content_direction),'copy/move value identity')
  call require(move_state%accepted_steps == copy_state%accepted_steps .and. &
       move_state%additional_tridiagonal_backsolves == copy_state%additional_tridiagonal_backsolves .and. &
       move_state%additional_jacobian_builds == copy_state%additional_jacobian_builds .and. &
       move_state%additional_full_nonlinear_solves == copy_state%additional_full_nonlinear_solves, &
       'copy/move scalar identity')
  print '(a)', 'FPE_ZERO_WASTE01_HDIR04_CONSUMING_IDENTITY=PASS'

  call prepare_state(fail_state,fail_request,fail_token)
  call prepare_result(fail_result,expected_h,expected_theta)
  deallocate(fail_result%outgoing_pressure_head)
  allocate(fail_result%outgoing_pressure_head(n-1))
  fail_result%outgoing_pressure_head=1.0_real64
  call stage_trajectory_step_result_consuming(fail_state,fail_token,fail_result,ok)
  call require(.not. ok,'malformed consuming result rejected')
  call require(fail_state%status == TRAJECTORY_DIRECTION_FAILED,'malformed result fails closed')
  call require(allocated(fail_result%outgoing_pressure_head) .and. &
       allocated(fail_result%outgoing_water_content),'failed validation does not consume result ownership')
  call require(.not. allocated(fail_state%pending_pressure_head_direction) .and. &
       .not. allocated(fail_state%pending_water_content_direction),'failed validation leaves no pending ownership')
  print '(a)', 'FPE_ZERO_WASTE01_HDIR04_PREMOVE_FAIL_CLOSED=PASS'

  print '(a)', 'FPE_ZERO_WASTE01_HDIR04_CONTRACT=PASS'

contains

  subroutine prepare_state(state,request,token)
    type(accepted_trajectory_direction_t), intent(out) :: state
    type(soil_water_accepted_step_direction_request_t), intent(out) :: request
    type(trajectory_step_token_t), intent(out) :: token
    logical :: local_ok

    call configure_trajectory_direction(state,.true.)
    call begin_or_continue_trajectory(state,11,0.0_real64,1.0_real64,SW_STEP_CONTROL_BOTTOM_FLUX,n,local_ok)
    call require(local_ok,'begin trajectory')
    call build_trajectory_step_request(state,0.0_real64,1.0_real64,request,token,local_ok)
    call require(local_ok,'build request')
  end subroutine prepare_state

  subroutine prepare_result(result,h,theta)
    type(soil_water_accepted_step_direction_result_t), intent(out) :: result
    real(real64), intent(in) :: h(:),theta(:)

    result=soil_water_accepted_step_direction_result_t()
    result%status=SW_STEP_DIRECTION_AVAILABLE
    result%available=.true.
    result%fixed_smooth_route=.true.
    result%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
    result%method='same-accepted-tridag-factor'
    result%route='hdir04-test'
    allocate(result%outgoing_pressure_head(size(h)),result%outgoing_water_content(size(theta)))
    result%outgoing_pressure_head=h
    result%outgoing_water_content=theta
    result%outgoing_ponding_depth=0.125_real64
    result%bottom_flux_derivative=0.75_real64
    result%source_sink_direction_covered=.true.
    result%root_sink_direction_covered=.true.
    result%additional_tridiagonal_backsolves=1
    result%additional_jacobian_builds=0
    result%additional_full_nonlinear_solves=0
  end subroutine prepare_result

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FPE_ZERO_WASTE01_HDIR04_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpe_zero_waste01_hdir04_consuming_stage
