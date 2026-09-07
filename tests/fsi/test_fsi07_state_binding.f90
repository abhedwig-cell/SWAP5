program test_fsi07_state_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, copy_reference_state
  implicit none

  type(reference_richards_state_binding_t) :: a, b
  integer :: failures, i

  failures = 0
  call a%ensure_shape(4)
  do i = 1, 4
     a%h(i) = -10.0_real64*real(i, real64)
     a%theta(i) = 0.20_real64 + 0.01_real64*real(i, real64)
     a%hm1(i) = a%h(i)
     a%thetm1(i) = a%theta(i)
     a%k(i) = real(i, real64)
     a%dimoca(i) = 0.1_real64*real(i, real64)
  end do
  do i = 1, 5
     a%kmean(i) = 0.5_real64*real(i, real64)
  end do
  a%pond = 0.03_real64
  a%pondm1 = 0.02_real64
  a%gwl = -2.0_real64
  a%gwlm1 = -2.1_real64
  a%qtop = -0.4_real64
  a%qbot = -0.3_real64
  a%hbot = -100.0_real64
  a%gwlinp = -5.0_real64
  a%fllowgwl = .true.
  a%fldecdt = .true.
  a%numbit = 7

  call copy_reference_state(a, b)
  b%h(1) = b%h(1) - 999.0_real64
  b%theta(2) = b%theta(2) + 0.5_real64
  b%kmean(5) = b%kmean(5) + 2.0_real64
  b%pond = 9.0_real64
  b%fldecdt = .false.
  b%numbit = 99

  if (a%h(1) /= -10.0_real64) failures = failures + 1
  if (a%theta(2) /= 0.22_real64) failures = failures + 1
  if (a%kmean(5) /= 2.5_real64) failures = failures + 1
  if (a%pond /= 0.03_real64) failures = failures + 1
  if (.not. a%fldecdt) failures = failures + 1
  if (a%numbit /= 7) failures = failures + 1

  call b%clear_outcome()
  if (b%fllowgwl) failures = failures + 1
  if (b%fldecdt) failures = failures + 1
  if (b%numbit /= 0) failures = failures + 1
  if (.not. a%fllowgwl) failures = failures + 1
  if (.not. a%fldecdt) failures = failures + 1
  if (a%numbit /= 7) failures = failures + 1

  call b%ensure_shape(2)
  if (b%active_nodes /= 2) failures = failures + 1
  if (size(b%h) /= 2 .or. size(b%kmean) /= 3) failures = failures + 1

  if (failures /= 0) then
     write(*,'(A,I0)') 'F-SI07_STATE_BINDING FAIL failures=', failures
     error stop 1
  end if
  write(*,'(A)') 'F-SI07_STATE_BINDING PASS'
end program test_fsi07_state_binding
