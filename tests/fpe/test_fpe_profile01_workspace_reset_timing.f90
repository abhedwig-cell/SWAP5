program test_fpe_profile01_workspace_reset_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       reset_reference_workspace, reference_workspace_payload_bytes
  implicit none

  type(reference_richards_workspace_t) :: workspace
  character(len=64) :: arg
  integer :: n, calls, i, warmups
  integer(int64) :: c0, c1, rate, bytes_per_reset
  real(real64) :: seconds, ns_per_reset, gib_per_second

  call get_command_argument(1, arg)
  read(arg,*) n
  call get_command_argument(2, arg)
  read(arg,*) calls
  if (n <= 0 .or. calls <= 0) error stop 'PROFILE01 invalid timing arguments'

  call initialize_reference_workspace(workspace, n)
  bytes_per_reset = reference_workspace_payload_bytes(workspace)
  warmups = min(2000, max(100, calls/100))
  do i = 1, warmups
    call reset_reference_workspace(workspace)
  end do

  call system_clock(c0, rate)
  do i = 1, calls
    call reset_reference_workspace(workspace)
  end do
  call system_clock(c1)

  seconds = real(c1-c0, real64)/real(rate, real64)
  ns_per_reset = 1.0e9_real64 * seconds / real(calls, real64)
  if (seconds > 0.0_real64) then
    gib_per_second = real(bytes_per_reset, real64) * real(calls, real64) / seconds / (1024.0_real64**3)
  else
    gib_per_second = 0.0_real64
  end if

  write(*,'(A,I0,A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'PROFILE01_RESET_TIMING,nodes=', n, ',calls=', calls, ',bytes_per_reset=', bytes_per_reset, &
       ',seconds=', seconds, ',ns_per_reset=', ns_per_reset, ',gib_per_second=', gib_per_second
end program test_fpe_profile01_workspace_reset_timing
