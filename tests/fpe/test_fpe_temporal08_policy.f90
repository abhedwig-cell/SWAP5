program test_fpe_temporal08_policy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_temporal_budget_policy_t, &
       resolve_fmr_groundwater_temporal_budget
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  implicit none

  type(fmr_b110_physical_state_t) :: physical
  type(kernel_committed_state_t) :: temporal_state, plain_state
  type(fmr_groundwater_temporal_budget_policy_t) :: policy
  type(groundwater_coupling_window_t) :: window
  real(real64) :: derivative(numnod), budget, expected
  logical :: ok, available

  physical%active_nodes = numnod
  allocate(physical%pressure_head(numnod), physical%water_content(numnod))
  physical%pressure_head = -75.0_real64
  physical%water_content = 0.25_real64
  physical%ponding_depth = 0.0_real64
  physical%groundwater_level = -1.0_real64

  window%t0 = 3.0_real64
  window%t1 = 3.0_real64 + 1.0e-4_real64

  policy%enabled = .true.
  policy%coefficient = 0.65_real64
  policy%floor_cm = 1.0e-5_real64
  call require(policy%valid(), 'qualified policy valid')

  derivative = 0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(temporal_state, 880001_int64, physical, window%t0, ok, derivative)
  call require(ok, 'zero-history committed state')
  call resolve_fmr_groundwater_temporal_budget(temporal_state, window, policy, budget, available)
  call require(available, 'floor budget available')
  call require(same_real(budget, 1.0e-5_real64), 'floor budget exact')

  derivative = 0.0_real64
  derivative(1) = 400.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(temporal_state, 880002_int64, physical, window%t0, ok, derivative)
  call require(ok, 'dynamic-history committed state')
  expected = max(1.0e-5_real64, 0.65_real64 * (window%t1-window%t0) * 400.0_real64)
  call resolve_fmr_groundwater_temporal_budget(temporal_state, window, policy, budget, available)
  call require(available, 'history-scaled budget available')
  call require(same_real(budget, expected), 'history-scaled budget exact')

  call fmr_new_b110_committed_state(plain_state, 880003_int64, physical, window%t0, ok)
  call require(ok, 'plain committed state')
  call resolve_fmr_groundwater_temporal_budget(plain_state, window, policy, budget, available)
  call require(.not. available, 'missing history fails closed')
  call require(budget == 0.0_real64, 'missing history publishes no budget')

  policy%coefficient = 0.0_real64
  call require(.not. policy%valid(), 'zero coefficient invalid')
  call resolve_fmr_groundwater_temporal_budget(temporal_state, window, policy, budget, available)
  call require(.not. available, 'invalid policy fails closed')

  policy = fmr_groundwater_temporal_budget_policy_t()
  call require(policy%valid(), 'disabled default policy valid')
  call resolve_fmr_groundwater_temporal_budget(temporal_state, window, policy, budget, available)
  call require(.not. available, 'disabled policy does not override budget')

  write(*,'(A)') 'TEMPORAL08_POLICY_FLOOR=PASS'
  write(*,'(A)') 'TEMPORAL08_POLICY_HISTORY_SCALE=PASS'
  write(*,'(A)') 'TEMPORAL08_POLICY_MISSING_HISTORY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'TEMPORAL08_POLICY_DEFAULT_OFF=PASS'
  write(*,'(A)') 'FPE_TEMPORAL08_POLICY_UNIT=PASS'

contains

  pure logical function same_real(a,b) result(same)
    real(real64), intent(in) :: a,b
    same = abs(a-b) <= 16.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function same_real

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A,1X,A)') 'TEMPORAL08_POLICY_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fpe_temporal08_policy
