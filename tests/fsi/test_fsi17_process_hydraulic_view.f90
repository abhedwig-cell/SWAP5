program test_fsi17_process_hydraulic_view
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view, &
       validate_process_hydraulic_view
  implicit none

  type(soil_water_physical_state_t) :: state_a, state_b, invalid_state
  type(process_hydraulic_view_t) :: view_a1, view_b, view_a2, isolated_view
  logical :: ok

  call make_state(state_a, [ -10.0_real64, -20.0_real64, -30.0_real64 ], &
       [ 0.31_real64, 0.29_real64, 0.27_real64 ], 0.4_real64, -125.0_real64)
  call make_state(state_b, [ -5.0_real64, -15.0_real64, -25.0_real64 ], &
       [ 0.35_real64, 0.33_real64, 0.30_real64 ], 0.0_real64, -80.0_real64)

  call build_process_hydraulic_view(state_a, view_a1, ok)
  call require(ok, 'valid A build failed')
  call validate_process_hydraulic_view(view_a1, ok)
  call require(ok, 'valid A validation failed')
  call require_view(view_a1, state_a, 'A1')

  call build_process_hydraulic_view(state_b, view_b, ok)
  call require(ok, 'valid B build failed')
  call require_view(view_b, state_b, 'B')

  call build_process_hydraulic_view(state_a, view_a2, ok)
  call require(ok, 'valid A replay build failed')
  call require_same_view(view_a1, view_a2, 'A/B/A repeatability failed')

  call build_process_hydraulic_view(state_a, isolated_view, ok)
  call require(ok, 'isolation build failed')
  state_a%pressure_head(1) = 999.0_real64
  state_a%water_content(2) = 0.99_real64
  state_a%ponding_depth = 99.0_real64
  state_a%groundwater_level = 99.0_real64
  call require(isolated_view%pressure_head(1) == -10.0_real64, 'pressure-head alias detected')
  call require(isolated_view%water_content(2) == 0.29_real64, 'water-content alias detected')
  call require(isolated_view%ponding_depth == 0.4_real64, 'ponding alias detected')
  call require(isolated_view%groundwater_level == -125.0_real64, 'groundwater alias detected')

  invalid_state%active_nodes = 2
  allocate(invalid_state%pressure_head(2))
  invalid_state%pressure_head = 0.0_real64
  call build_process_hydraulic_view(invalid_state, isolated_view, ok)
  call require(.not. ok, 'missing water content did not fail closed')
  call require(isolated_view%active_nodes == 0, 'failed build retained active nodes')
  call require(.not. allocated(isolated_view%pressure_head), 'failed build retained pressure head')

  allocate(invalid_state%water_content(3))
  invalid_state%water_content = 0.0_real64
  call build_process_hydraulic_view(invalid_state, isolated_view, ok)
  call require(.not. ok, 'shape mismatch did not fail closed')

  call emit_view('A', view_a1)
  call emit_view('B', view_b)
  call emit_view('A_REPLAY', view_a2)
  write(*,'(a)') 'FSI17_PROCESS_HYDRAULIC_VIEW PASS'

contains

  subroutine make_state(state, h, theta, pond, gwl)
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), intent(in) :: h(:), theta(:), pond, gwl
    integer :: n

    n = size(h)
    call require(size(theta) == n, 'fixture shape mismatch')
    state%active_nodes = n
    allocate(state%pressure_head(n), state%water_content(n))
    state%pressure_head = h
    state%water_content = theta
    state%ponding_depth = pond
    state%groundwater_level = gwl
  end subroutine make_state

  subroutine require_view(view, state, label)
    type(process_hydraulic_view_t), intent(in) :: view
    type(soil_water_physical_state_t), intent(in) :: state
    character(len=*), intent(in) :: label

    call require(view%active_nodes == state%active_nodes, label // ': active_nodes')
    call require(all(view%pressure_head == state%pressure_head), label // ': pressure_head')
    call require(all(view%water_content == state%water_content), label // ': water_content')
    call require(view%ponding_depth == state%ponding_depth, label // ': ponding_depth')
    call require(view%groundwater_level == state%groundwater_level, label // ': groundwater_level')
  end subroutine require_view

  subroutine require_same_view(left, right, message)
    type(process_hydraulic_view_t), intent(in) :: left, right
    character(len=*), intent(in) :: message

    call require(left%active_nodes == right%active_nodes, message)
    call require(all(left%pressure_head == right%pressure_head), message)
    call require(all(left%water_content == right%water_content), message)
    call require(left%ponding_depth == right%ponding_depth, message)
    call require(left%groundwater_level == right%groundwater_level, message)
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

end program test_fsi17_process_hydraulic_view
