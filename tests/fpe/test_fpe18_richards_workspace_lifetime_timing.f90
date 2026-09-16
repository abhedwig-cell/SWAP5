program test_fpe18_richards_workspace_lifetime_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, &
       initialize_reference_workspace, release_reference_workspace, reference_workspace_payload_bytes
  implicit none

  character(len=16) :: arm
  integer :: nodes, calls, warmup, i
  integer(int64) :: tick0, tick1, tick_rate, payload_bytes
  real(real64) :: cpu0, cpu1, wall_seconds, cpu_seconds, touch
  type(reference_richards_workspace_t) :: reusable

  call read_args(arm, nodes, calls, warmup)

  select case (trim(arm))
  case ('fresh')
    do i = 1, warmup
      call fresh_cycle(nodes, touch)
    end do
    touch = 0.0_real64
    call cpu_time(cpu0)
    call system_clock(tick0, tick_rate)
    do i = 1, calls
      call fresh_cycle(nodes, touch)
    end do
    call system_clock(tick1)
    call cpu_time(cpu1)
    call fresh_payload_probe(nodes, payload_bytes)

  case ('reuse')
    touch = 0.0_real64
    do i = 1, warmup
      call initialize_reference_workspace(reusable, nodes)
      touch = touch + reusable%residual(1)
    end do
    if (reusable%generation /= int(warmup, int64)) error stop 'F-PE18 reuse warmup generation mismatch'
    touch = 0.0_real64
    call cpu_time(cpu0)
    call system_clock(tick0, tick_rate)
    do i = 1, calls
      call initialize_reference_workspace(reusable, nodes)
      touch = touch + reusable%residual(1)
    end do
    call system_clock(tick1)
    call cpu_time(cpu1)
    if (reusable%generation /= int(warmup + calls, int64)) error stop 'F-PE18 reuse generation mismatch'
    payload_bytes = reference_workspace_payload_bytes(reusable)
    call verify_workspace(reusable, nodes, payload_bytes)
    call release_reference_workspace(reusable)

  case default
    error stop 'F-PE18 arm must be fresh or reuse'
  end select

  if (tick_rate <= 0_int64) error stop 'F-PE18 invalid system_clock rate'
  wall_seconds = real(tick1 - tick0, real64) / real(tick_rate, real64)
  cpu_seconds = cpu1 - cpu0
  if (wall_seconds <= 0.0_real64 .or. cpu_seconds < 0.0_real64) error stop 'F-PE18 invalid timing result'
  if (abs(touch) > 0.0_real64) error stop 'F-PE18 reset touch must remain zero'

  write(*,'(A,A,A,I0,A,I0,A,I0,A,ES24.15E3,A,ES24.15E3,A,I0,A,ES24.15E3)') &
       'FPE18_TIMING arm=', trim(arm), ',nodes=', nodes, ',calls=', calls, ',warmup=', warmup, &
       ',wall_s=', wall_seconds, ',cpu_s=', cpu_seconds, ',payload_bytes=', payload_bytes, ',touch=', touch

contains

  subroutine fresh_cycle(n, accumulator)
    integer, intent(in) :: n
    real(real64), intent(inout) :: accumulator
    type(reference_richards_workspace_t) :: workspace

    call initialize_reference_workspace(workspace, n)
    if (workspace%generation /= 1_int64) error stop 'F-PE18 fresh workspace generation must be one'
    accumulator = accumulator + workspace%residual(1)
    ! Allocatable components are intentionally left to normal scope-exit
    ! deallocation. This mirrors the current call-local adapter lifetime.
  end subroutine fresh_cycle

  subroutine fresh_payload_probe(n, bytes)
    integer, intent(in) :: n
    integer(int64), intent(out) :: bytes
    type(reference_richards_workspace_t) :: workspace

    call initialize_reference_workspace(workspace, n)
    bytes = reference_workspace_payload_bytes(workspace)
    call verify_workspace(workspace, n, bytes)
  end subroutine fresh_payload_probe

  subroutine verify_workspace(workspace, n, bytes)
    type(reference_richards_workspace_t), intent(in) :: workspace
    integer, intent(in) :: n
    integer(int64), intent(in) :: bytes

    if (workspace%active_nodes /= n) error stop 'F-PE18 active node mismatch'
    if (.not. allocated(workspace%residual)) error stop 'F-PE18 residual not allocated'
    if (size(workspace%residual) /= n) error stop 'F-PE18 residual shape mismatch'
    if (size(workspace%vertical_flux) /= n + 1) error stop 'F-PE18 vertical flux shape mismatch'
    if (size(workspace%band_matrix,1) /= n .or. size(workspace%band_matrix,2) /= 3) &
         error stop 'F-PE18 band matrix shape mismatch'
    if (bytes <= 0_int64) error stop 'F-PE18 workspace payload must be positive'
    if (any(workspace%residual /= 0.0_real64)) error stop 'F-PE18 reset residual mismatch'
    if (any(workspace%dfdh_main /= 0.0_real64)) error stop 'F-PE18 reset Jacobian mismatch'
    if (workspace%has_warm_start) error stop 'F-PE18 warm start must reset false'
    if (workspace%poisoned) error stop 'F-PE18 workspace must reset unpoisoned'
  end subroutine verify_workspace

  subroutine read_args(selected_arm, n, ncall, nwarm)
    character(len=*), intent(out) :: selected_arm
    integer, intent(out) :: n, ncall, nwarm
    character(len=64) :: arg
    integer :: stat

    if (command_argument_count() /= 4) &
         error stop 'usage: test_fpe18 <fresh|reuse> <nodes> <calls> <warmup>'
    call get_command_argument(1, selected_arm)
    call get_command_argument(2, arg)
    read(arg,*,iostat=stat) n
    if (stat /= 0 .or. n <= 0) error stop 'F-PE18 invalid nodes'
    call get_command_argument(3, arg)
    read(arg,*,iostat=stat) ncall
    if (stat /= 0 .or. ncall <= 0) error stop 'F-PE18 invalid calls'
    call get_command_argument(4, arg)
    read(arg,*,iostat=stat) nwarm
    if (stat /= 0 .or. nwarm <= 0) error stop 'F-PE18 invalid warmup'
  end subroutine read_args

end program test_fpe18_richards_workspace_lifetime_timing
