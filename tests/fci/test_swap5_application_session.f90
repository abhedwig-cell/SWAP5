program test_swap5_application_session
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_swap5_application_session, only: swap5_application_session_t, SWAP5_SESSION_OK, SWAP5_SESSION_INVALID
  implicit none
  type(swap5_application_session_t) :: session
  type(canonical_interval_t) :: interval
  integer :: status

  call session%initialize(17_int64, status)
  if (status /= SWAP5_SESSION_OK .or. .not. session%initialized_ok()) error stop 'valid initialization rejected'
  interval%t0 = 0.0_real64
  interval%t1 = 1.0_real64
  if (.not. session%validate_interval(interval)) error stop 'valid interval rejected'
  interval%t1 = interval%t0
  if (session%validate_interval(interval)) error stop 'zero interval accepted'
  call session%initialize(0_int64, status)
  if (status /= SWAP5_SESSION_INVALID .or. session%initialized_ok()) error stop 'invalid generation accepted'
  print '(a)', 'SWAP5_APPLICATION_SESSION_FAIL_CLOSED=PASS'
end program test_swap5_application_session
