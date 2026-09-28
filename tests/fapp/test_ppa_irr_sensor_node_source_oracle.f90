program test_ppa_irr_sensor_node_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_sensor_node, only: locate_irrigation_sensor_node
  implicit none

  integer, parameter :: max_nodes = 32, vector_count = 100000
  real(real64), parameter :: tolerance = 1.0e-5_real64
  real(real64) :: bottoms(max_nodes), dcrit, unit_value
  integer :: node_count, actual_node, i, j
  integer(int64) :: random_state
  logical :: found

  bottoms(1:3) = [-1.0_real64, -2.0_real64, -3.0_real64]
  dcrit = -1.0_real64-tolerance
  call check_case(dcrit, bottoms(1:3), 1)
  dcrit = nearest(-1.0_real64-tolerance, -1.0_real64)
  call check_case(dcrit, bottoms(1:3), 2)
  dcrit = -2.0_real64-tolerance
  call check_case(dcrit, bottoms(1:3), 3)
  dcrit = nearest(-2.0_real64-tolerance, -1.0_real64)
  call check_case(dcrit, bottoms(1:3), 4)

  random_state = 20260923_int64
  do i = 1, vector_count
    node_count = 1 + modulo(i-1, max_nodes)
    call random_unit(random_state, unit_value)
    bottoms(1) = -0.1_real64-0.5_real64*unit_value
    do j = 2, node_count
      call random_unit(random_state, unit_value)
      bottoms(j) = bottoms(j-1)-0.1_real64-2.0_real64*unit_value
    end do
    call random_unit(random_state, unit_value)
    dcrit = bottoms(node_count)*unit_value
    call check_case(dcrit, bottoms(1:node_count), 10)
  end do

  print '(A)', 'PPA_IRR_SENSOR_NODE_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_SENSOR_NODE_TOLERANCE_BOUNDARIES=PASS'
  print '(A)', 'PPA_IRR_SENSOR_NODE_SOURCE_ORACLE=PASS'

contains

  subroutine check_case(depth, profile_bottoms, code)
    real(real64), intent(in) :: depth, profile_bottoms(:)
    integer, intent(in) :: code
    integer :: source_node
    logical :: source_found

    source_node = 1
    do while (profile_bottoms(source_node) > depth+tolerance)
      source_node = source_node+1
    end do
    call locate_irrigation_sensor_node(depth, profile_bottoms, actual_node, found)
    source_found = source_node <= size(profile_bottoms)
    call require(found .eqv. source_found, code)
    call require(.not. found .or. actual_node == source_node, code+100)
  end subroutine check_case

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_SENSOR_NODE_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_sensor_node_source_oracle
