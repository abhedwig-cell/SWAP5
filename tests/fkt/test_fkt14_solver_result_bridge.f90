program test_fkt14_solver_result_bridge
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solve_result_t, &
       SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED, SW_SOLVE_FAILED
  use mod_transaction_reference, only: trial_outcome_t, &
       TX_INTERFACE_SENSITIVITY_NONE
  use mod_soil_water_transaction_result_bridge, only: &
       map_soil_water_interface_sensitivity_to_trial
  implicit none

  type(soil_water_solve_result_t) :: solve_result
  type(trial_outcome_t) :: trial

  call test_converged_native_value()
  call test_converged_unavailable()
  call test_retry_fail_closed()
  call test_failed_fail_closed()

  print '(a)', 'F-KT14 PASS: soil-water solver result bridge'

contains

  subroutine fail(message)
    character(len=*), intent(in) :: message
    write(*,'(a)') 'F-KT14 BRIDGE FAIL: '//trim(message)
    error stop 1
  end subroutine fail

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) call fail(message)
  end subroutine require

  subroutine seed_stale_trial()
    trial = trial_outcome_t()
    trial%interface_sensitivity%available = .true.
    trial%interface_sensitivity%semantic = 99
    trial%interface_sensitivity%dh_bottom_dq_bottom = 9999.0_real64
    trial%interface_sensitivity%method = 'stale'
    trial%interface_sensitivity%origin_t0 = -7.0_real64
    trial%interface_sensitivity%origin_t1 = -6.0_real64
    trial%interface_sensitivity%covers_requested_interval = .true.
  end subroutine seed_stale_trial

  subroutine require_cleared(message)
    character(len=*), intent(in) :: message
    call require(.not. trial%interface_sensitivity%available, trim(message)//': available')
    call require(trial%interface_sensitivity%semantic == TX_INTERFACE_SENSITIVITY_NONE, &
         trim(message)//': semantic')
    call require(trial%interface_sensitivity%dh_bottom_dq_bottom == 0.0_real64, trim(message)//': value')
    call require(trim(trial%interface_sensitivity%method) == 'not-available', trim(message)//': method')
    call require(trial%interface_sensitivity%origin_t0 == 0.0_real64, trim(message)//': origin_t0')
    call require(trial%interface_sensitivity%origin_t1 == 0.0_real64, trim(message)//': origin_t1')
    call require(.not. trial%interface_sensitivity%covers_requested_interval, trim(message)//': coverage')
  end subroutine require_cleared

  subroutine test_converged_native_value()
    solve_result = soil_water_solve_result_t()
    solve_result%status = SW_SOLVE_CONVERGED
    solve_result%interface_sensitivity%available = .true.
    solve_result%interface_sensitivity%dh_bottom_dq_bottom = -37.25_real64
    solve_result%interface_sensitivity%method = 'same-tridag-factor'
    call seed_stale_trial()

    call map_soil_water_interface_sensitivity_to_trial(solve_result, trial)

    call require(trial%interface_sensitivity%available, 'converged source not transported')
    call require(trial%interface_sensitivity%dh_bottom_dq_bottom == -37.25_real64, &
         'native value/sign changed')
    call require(trim(trial%interface_sensitivity%method) == 'same-tridag-factor', &
         'producer method provenance changed')
    call require(trial%interface_sensitivity%semantic == TX_INTERFACE_SENSITIVITY_NONE, &
         'bridge claimed transaction temporal semantic')
    call require(trial%interface_sensitivity%origin_t0 == 0.0_real64 .and. &
         trial%interface_sensitivity%origin_t1 == 0.0_real64, &
         'bridge invented temporal provenance')
    call require(.not. trial%interface_sensitivity%covers_requested_interval, &
         'bridge invented interval coverage')
  end subroutine test_converged_native_value

  subroutine test_converged_unavailable()
    solve_result = soil_water_solve_result_t()
    solve_result%status = SW_SOLVE_CONVERGED
    solve_result%interface_sensitivity%available = .false.
    solve_result%interface_sensitivity%dh_bottom_dq_bottom = 12.0_real64
    solve_result%interface_sensitivity%method = 'malformed-unavailable'
    call seed_stale_trial()

    call map_soil_water_interface_sensitivity_to_trial(solve_result, trial)
    call require_cleared('unavailable producer result not fail-closed')
  end subroutine test_converged_unavailable

  subroutine test_retry_fail_closed()
    solve_result = soil_water_solve_result_t()
    solve_result%status = SW_SOLVE_RETRY_ADVISED
    solve_result%retry_advised = .true.
    ! Deliberately malformed source metadata: the bridge must still clear it.
    solve_result%interface_sensitivity%available = .true.
    solve_result%interface_sensitivity%dh_bottom_dq_bottom = 1234.0_real64
    solve_result%interface_sensitivity%method = 'malformed-retry'
    call seed_stale_trial()

    call map_soil_water_interface_sensitivity_to_trial(solve_result, trial)
    call require_cleared('retry producer result leaked sensitivity')
  end subroutine test_retry_fail_closed

  subroutine test_failed_fail_closed()
    solve_result = soil_water_solve_result_t()
    solve_result%status = SW_SOLVE_FAILED
    solve_result%interface_sensitivity%available = .true.
    solve_result%interface_sensitivity%dh_bottom_dq_bottom = -4321.0_real64
    solve_result%interface_sensitivity%method = 'malformed-failed'
    call seed_stale_trial()

    call map_soil_water_interface_sensitivity_to_trial(solve_result, trial)
    call require_cleared('failed producer result leaked sensitivity')
  end subroutine test_failed_fail_closed

end program test_fkt14_solver_result_bridge
