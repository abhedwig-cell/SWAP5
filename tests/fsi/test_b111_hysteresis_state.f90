program test_b111_hysteresis_state
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_hysteresis_state
  implicit none
  type(b111_hysteresis_parameters_t) :: p
  type(b111_hysteresis_state_t) :: s
  type(b111_hysteresis_transition_t) :: transition(1)
  integer :: status
  real(real64) :: h(1), theta(1)

  call initialize_b111_hysteresis(p,[0.05_real64],[0.45_real64],[0.01_real64],[0.02_real64], &
       [1.6_real64],[1.0_real64],status)
  if (status /= B111_HYST_OK) error stop 1
  h=-100.0_real64; theta=0.25_real64
  call initialize_b111_hysteresis_state(p,1,h,theta,s,status)
  if (status /= B111_HYST_OK .or. s%branch(1) /= B111_HYST_WETTING) error stop 2
  call initialize_b111_hysteresis_state(p,2,h,theta,s,status)
  if (status /= B111_HYST_OK .or. s%branch(1) /= B111_HYST_DRYING) error stop 2
  h=-50.0_real64; theta=0.30_real64
  call advance_b111_hysteresis_accepted(p,s,h,theta,transition,status)
  if (status /= B111_HYST_OK .or. .not.transition(1)%reversed .or. s%branch(1) /= B111_HYST_WETTING) error stop 3
  h=-40.0_real64; theta=0.32_real64
  call advance_b111_hysteresis_accepted(p,s,h,theta,transition,status)
  if (status /= B111_HYST_OK .or. transition(1)%reversed .or. s%branch(1) /= B111_HYST_WETTING) error stop 4
  h=-80.0_real64; theta=0.27_real64
  call advance_b111_hysteresis_accepted(p,s,h,theta,transition,status)
  if (status /= B111_HYST_OK .or. .not.transition(1)%reversed .or. s%branch(1) /= B111_HYST_DRYING) error stop 5
  print '(a)', 'B111_HYST_STATE_PASS'
end program test_b111_hysteresis_state
