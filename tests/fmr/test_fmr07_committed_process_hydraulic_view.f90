program test_fmr07_committed_process_hydraulic_view
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  implicit none

  type(fmr_b110_physical_state_t) :: state_a, state_b, state_snow
  type(kernel_committed_state_t) :: committed_a, committed_b, committed_snow, uninitialized
  type(process_hydraulic_view_t) :: a1, b1, a2, after_clone_mutation, snow_view, invalid_view
  class(transaction_state_t), allocatable :: detached
  logical :: ok, available

  call configure_state(state_a, [-10.0_real64, -20.0_real64, -30.0_real64], &
       [0.31_real64, 0.29_real64, 0.27_real64], 0.4_real64, -125.0_real64, .false.)
  call configure_state(state_b, [-5.0_real64, -15.0_real64, -25.0_real64], &
       [0.35_real64, 0.33_real64, 0.30_real64], 0.0_real64, -80.0_real64, .false.)
  call configure_state(state_snow, [-7.0_real64, -17.0_real64, -27.0_real64], &
       [0.34_real64, 0.32_real64, 0.28_real64], 0.2_real64, -95.0_real64, .true.)

  call fmr_new_b110_committed_state(committed_a, 7001_int64, state_a, 25.25_real64, ok)
  call require(ok, 'committed A init')
  call fmr_new_b110_committed_state(committed_b, 7002_int64, state_b, 25.25_real64, ok)
  call require(ok, 'committed B init')
  call fmr_new_b110_committed_state(committed_snow, 7003_int64, state_snow, 25.25_real64, ok)
  call require(ok, 'committed snow init')

  call fmr_build_committed_process_hydraulic_view(uninitialized, invalid_view, ok)
  call require(.not. ok, 'uninitialized committed state did not fail closed')
  call require(invalid_view%active_nodes == 0, 'failed view retained active nodes')
  call require(.not. allocated(invalid_view%pressure_head), 'failed view retained pressure head')
  call require(.not. allocated(invalid_view%water_content), 'failed view retained water content')

  call fmr_build_committed_process_hydraulic_view(committed_a, a1, ok)
  call require(ok, 'A view build')
  call require_matches(a1, state_a, 'A1')

  call fmr_build_committed_process_hydraulic_view(committed_b, b1, ok)
  call require(ok, 'B view build')
  call require_matches(b1, state_b, 'B1')

  call fmr_build_committed_process_hydraulic_view(committed_a, a2, ok)
  call require(ok, 'A replay view build')
  call require_same_view(a1, a2, 'A/B/A repeatability')

  call committed_a%snapshot(detached, available)
  call require(available, 'committed snapshot unavailable')
  select type (physical => detached)
  type is (fmr_b110_physical_state_t)
    physical%pressure_head = 999.0_real64
    physical%water_content = 0.99_real64
    physical%ponding_depth = 99.0_real64
    physical%groundwater_level = 99.0_real64
  class default
    call require(.false., 'unexpected detached snapshot type')
  end select
  call fmr_build_committed_process_hydraulic_view(committed_a, after_clone_mutation, ok)
  call require(ok, 'view after detached mutation')
  call require_same_view(a1, after_clone_mutation, 'detached snapshot mutated committed view')

  a1%pressure_head(1) = 12345.0_real64
  a1%water_content(2) = 0.12345_real64
  a1%ponding_depth = 12345.0_real64
  a1%groundwater_level = 12345.0_real64
  call fmr_build_committed_process_hydraulic_view(committed_a, after_clone_mutation, ok)
  call require(ok, 'view after returned-view mutation')
  call require_matches(after_clone_mutation, state_a, 'returned view aliases committed state')

  call fmr_build_committed_process_hydraulic_view(committed_snow, snow_view, ok)
  call require(ok, 'snow-active view build')
  call require_matches(snow_view, state_snow, 'snow-active hydraulic identity')
  call require(state_snow%snow%process%snow_water_storage == 2.5_real64, 'snow fixture unexpectedly changed')
  call require(state_snow%snow%process%liquid_water_storage == 0.3_real64, 'snow liquid fixture unexpectedly changed')

  call emit_view('A_COMMITTED', after_clone_mutation)
  call emit_view('B_COMMITTED', b1)
  call emit_view('SNOW_COMMITTED', snow_view)
  write(*,'(a)') 'FMR07_COMMITTED_PROCESS_HYDRAULIC_VIEW PASS'

contains

  subroutine configure_state(state, h, theta, pond, gwl, with_snow)
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(in) :: h(:), theta(:), pond, gwl
    logical, intent(in) :: with_snow
    integer :: n

    n = size(h)
    call require(size(theta) == n, 'fixture shape mismatch')
    state%active_nodes = n
    allocate(state%pressure_head(n), state%water_content(n))
    state%pressure_head = h
    state%water_content = theta
    state%ponding_depth = pond
    state%groundwater_level = gwl
    if (with_snow) then
      allocate(state%snow)
      state%snow%process%snow_water_storage = 2.5_real64
      state%snow%process%liquid_water_storage = 0.3_real64
      state%snow%event_applied = .true.
      state%snow%event_t0 = 24.25_real64
    end if
  end subroutine configure_state

  subroutine require_matches(view, state, label)
    type(process_hydraulic_view_t), intent(in) :: view
    type(fmr_b110_physical_state_t), intent(in) :: state
    character(len=*), intent(in) :: label

    call require(view%active_nodes == state%active_nodes, label // ': active nodes')
    call require(all(view%pressure_head == state%pressure_head), label // ': pressure head')
    call require(all(view%water_content == state%water_content), label // ': water content')
    call require(view%ponding_depth == state%ponding_depth, label // ': ponding depth')
    call require(view%groundwater_level == state%groundwater_level, label // ': groundwater level')
  end subroutine require_matches

  subroutine require_same_view(left, right, label)
    type(process_hydraulic_view_t), intent(in) :: left, right
    character(len=*), intent(in) :: label

    call require(left%active_nodes == right%active_nodes, label // ': active nodes')
    call require(all(left%pressure_head == right%pressure_head), label // ': pressure head')
    call require(all(left%water_content == right%water_content), label // ': water content')
    call require(left%ponding_depth == right%ponding_depth, label // ': ponding depth')
    call require(left%groundwater_level == right%groundwater_level, label // ': groundwater level')
  end subroutine require_same_view

  subroutine emit_view(label, view)
    character(len=*), intent(in) :: label
    type(process_hydraulic_view_t), intent(in) :: view
    integer :: i

    write(*,'(a,1x,i0,1x,es24.16,1x,es24.16)') trim(label), view%active_nodes, &
         view%ponding_depth, view%groundwater_level
    do i = 1, view%active_nodes
      write(*,'(i0,1x,es24.16,1x,es24.16)') i, view%pressure_head(i), view%water_content(i)
    end do
  end subroutine emit_view

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FAIL: ' // trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fmr07_committed_process_hydraulic_view
