program test_fpe_zero_waste01_attempt_context
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_attempt_context_t
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t
  use mod_fmr_top_sensible_boundary_carrier, only: fmr_top_sensible_boundary_carrier_t
  use mod_accepted_trajectory_directional_sensitivity, only: accepted_trajectory_direction_t
  implicit none

  integer(int64), parameter :: reps = 5000000_int64

  type, extends(transaction_attempt_context_t) :: mirror_attempt_context_t
    logical :: bottom_thermal_active = .false.
    logical :: bottom_thermal_valid = .true.
    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier
    logical :: top_sensible_boundary_active = .false.
    logical :: top_sensible_boundary_valid = .true.
    type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier
    logical :: drainage_response_window_exchange_available = .false.
    real(real64) :: drainage_response_window_signed_exchange_native = 0.0_real64
    type(accepted_trajectory_direction_t) :: trajectory_direction
  end type mirror_attempt_context_t

  class(transaction_attempt_context_t), allocatable :: context
  type(fmr_bottom_thermal_carrier_t) :: bottom_source
  type(fmr_top_sensible_boundary_carrier_t) :: top_source
  type(accepted_trajectory_direction_t) :: trajectory_source
  integer(int64) :: c0,c1,rate,i,checksum
  real(real64) :: seconds

  checksum=0_int64
  call system_clock(c0,rate)
  do i=1_int64,reps
    allocate(mirror_attempt_context_t :: context)
    select type (typed => context)
    type is (mirror_attempt_context_t)
      typed%bottom_thermal_valid=.true.
      if (typed%bottom_thermal_valid) checksum=checksum+1_int64
    class default
      error stop 'attempt context allocation wrong dynamic type'
    end select
    deallocate(context)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  call emit('polymorphic_alloc_dealloc',seconds,checksum)

  checksum=0_int64
  call system_clock(c0,rate)
  do i=1_int64,reps
    allocate(mirror_attempt_context_t :: context)
    select type (typed => context)
    type is (mirror_attempt_context_t)
      typed%bottom_thermal_active=.false.
      typed%bottom_thermal_valid=.true.
      call bottom_source%copy_to(typed%bottom_thermal_carrier)
      typed%top_sensible_boundary_active=.false.
      typed%top_sensible_boundary_valid=.true.
      call top_source%copy_to(typed%top_sensible_boundary_carrier)
      typed%drainage_response_window_exchange_available=.false.
      typed%drainage_response_window_signed_exchange_native=0.0_real64
      typed%trajectory_direction=trajectory_source
      if (typed%bottom_thermal_valid .and. typed%top_sensible_boundary_valid) checksum=checksum+1_int64
    class default
      error stop 'attempt context capture wrong dynamic type'
    end select
    deallocate(context)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  call emit('inactive_capture_context',seconds,checksum)

  ! Restore-only cost for the inactive specialized context. This mirrors the
  ! serialized restore path after a context has already been captured.
  allocate(mirror_attempt_context_t :: context)
  checksum=0_int64
  call system_clock(c0,rate)
  do i=1_int64,reps
    select type (typed => context)
    type is (mirror_attempt_context_t)
      call typed%bottom_thermal_carrier%restore_from(bottom_source)
      call typed%top_sensible_boundary_carrier%restore_from(top_source)
      typed%trajectory_direction=trajectory_source
      if (typed%bottom_thermal_valid .and. typed%top_sensible_boundary_valid) checksum=checksum+1_int64
    class default
      error stop 'attempt context restore wrong dynamic type'
    end select
  end do
  call system_clock(c1)
  deallocate(context)
  seconds=real(c1-c0,real64)/real(rate,real64)
  call emit('inactive_restore_context',seconds,checksum)

  if(checksum /= reps) error stop 'attempt context checksum mismatch'

  call benchmark_directional_context(60, 100000_int64)
  call benchmark_directional_context(200, 30000_int64)
  call benchmark_directional_context(1000, 5000_int64)

  print '(a)', 'FPE_ZERO_WASTE01_ATTEMPT_CONTEXT=PASS'

contains
  subroutine benchmark_directional_context(n, repetitions)
    integer, intent(in) :: n
    integer(int64), intent(in) :: repetitions
    type(accepted_trajectory_direction_t) :: source, restored
    class(transaction_attempt_context_t), allocatable :: local_context
    integer(int64) :: j, start_clock, end_clock, clock_rate, local_checksum
    real(real64) :: elapsed

    source%requested = .true.
    source%status = 1
    source%worker_id = 17
    source%generation = 23_int64
    source%control_coordinate = 1
    source%accepted_steps = 2
    source%next_step_sequence = 3
    source%origin_t0 = 100.0_real64
    source%current_t1 = 100.5_real64
    source%requested_t1 = 101.0_real64
    allocate(source%pressure_head_direction(n), source%water_content_direction(n))
    allocate(source%pending_pressure_head_direction(n), source%pending_water_content_direction(n))
    source%pressure_head_direction = 1.0_real64
    source%water_content_direction = 2.0_real64
    source%pending_pressure_head_direction = 3.0_real64
    source%pending_water_content_direction = 4.0_real64
    source%pending = .true.
    source%pending_available = .true.

    local_checksum = 0_int64
    call system_clock(start_clock,clock_rate)
    do j=1_int64,repetitions
      allocate(mirror_attempt_context_t :: local_context)
      select type (typed => local_context)
      type is (mirror_attempt_context_t)
        typed%trajectory_direction = source
        local_checksum = local_checksum + int(size(typed%trajectory_direction%pressure_head_direction),int64)
      class default
        error stop 'directional capture wrong dynamic type'
      end select
      deallocate(local_context)
    end do
    call system_clock(end_clock)
    elapsed=real(end_clock-start_clock,real64)/real(clock_rate,real64)
    write(*,'(a,i0,a,i0,a,es24.16,a,es24.16,a,i0)') &
      'ZW_ATTEMPT_DIRECTIONAL,metric=capture,n=',n,',reps=',repetitions,',seconds=',elapsed, &
      ',ns_per_context=',1.0e9_real64*elapsed/real(repetitions,real64),',checksum=',local_checksum

    allocate(mirror_attempt_context_t :: local_context)
    select type (typed => local_context)
    type is (mirror_attempt_context_t)
      typed%trajectory_direction = source
    class default
      error stop 'directional restore fixture wrong dynamic type'
    end select
    restored = source
    local_checksum = 0_int64
    call system_clock(start_clock)
    do j=1_int64,repetitions
      select type (typed => local_context)
      type is (mirror_attempt_context_t)
        restored = typed%trajectory_direction
        local_checksum = local_checksum + int(size(restored%pressure_head_direction),int64)
      class default
        error stop 'directional restore wrong dynamic type'
      end select
    end do
    call system_clock(end_clock)
    elapsed=real(end_clock-start_clock,real64)/real(clock_rate,real64)
    write(*,'(a,i0,a,i0,a,es24.16,a,es24.16,a,i0)') &
      'ZW_ATTEMPT_DIRECTIONAL,metric=restore,n=',n,',reps=',repetitions,',seconds=',elapsed, &
      ',ns_per_context=',1.0e9_real64*elapsed/real(repetitions,real64),',checksum=',local_checksum
    deallocate(local_context)

    if(local_checksum /= repetitions*int(n,int64)) error stop 'directional context checksum mismatch'
  end subroutine benchmark_directional_context

  subroutine emit(metric,elapsed,sumv)
    character(len=*), intent(in) :: metric
    real(real64), intent(in) :: elapsed
    integer(int64), intent(in) :: sumv
    write(*,'(a,a,a,i0,a,es24.16,a,es24.16,a,i0)') &
      'ZW_ATTEMPT,metric=',trim(metric),',reps=',reps,',seconds=',elapsed, &
      ',ns_per_capture=',1.0e9_real64*elapsed/real(reps,real64),',checksum=',sumv
  end subroutine emit
end program test_fpe_zero_waste01_attempt_context
