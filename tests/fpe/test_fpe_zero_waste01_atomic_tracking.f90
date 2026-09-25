program test_fpe_zero_waste01_atomic_tracking
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none

  integer(int64), parameter :: iterations = 10000000_int64
  integer(int64) :: c0, c1, rate, i, checksum_atomic, checksum_plain
  integer :: active, observed, max_seen
  real(real64) :: atomic_seconds, plain_seconds, atomic_ns, plain_ns

  active = 0
  observed = 0
  max_seen = 0
  checksum_atomic = 0_int64

  call system_clock(c0, rate)
  do i = 1_int64, iterations
    !$omp atomic capture
    active = active + 1
    observed = active
    !$omp end atomic
    max_seen = max(max_seen, observed)
    !$omp atomic update
    active = active - 1
    !$omp end atomic
    checksum_atomic = checksum_atomic + int(observed, int64)
  end do
  call system_clock(c1)

  atomic_seconds = real(c1-c0,real64)/real(rate,real64)
  atomic_ns = 1.0e9_real64*atomic_seconds/real(iterations,real64)

  checksum_plain = 0_int64
  observed = 1
  call system_clock(c0)
  do i = 1_int64, iterations
    checksum_plain = checksum_plain + int(observed, int64)
  end do
  call system_clock(c1)

  plain_seconds = real(c1-c0,real64)/real(rate,real64)
  plain_ns = 1.0e9_real64*plain_seconds/real(iterations,real64)

  if (active /= 0) error stop 'atomic tracking active counter did not return to zero'
  if (max_seen /= 1) error stop 'single-thread atomic tracking max concurrency not one'
  if (checksum_atomic /= iterations .or. checksum_plain /= iterations) error stop 'atomic tracking checksum mismatch'

  write(*,'(A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'ZW_ATOMIC_TRACKING,iterations=',iterations,',atomic_ns_per_solve=',atomic_ns, &
       ',plain_ns_per_solve=',plain_ns,',delta_ns_per_solve=',atomic_ns-plain_ns
  write(*,'(A)') 'FPE_ZERO_WASTE01_ATOMIC_TRACKING=PASS'
end program test_fpe_zero_waste01_atomic_tracking
