program test_ppa_irr_rate_materialization_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_rate_materialization
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64), allocatable :: node_rates(:)
  real(real64) :: depth, rate, expected_rate, expected_duration, expected_sum
  real(real64) :: effective_rate, duration, rate_sum
  integer(int64) :: random_state
  integer :: i, active_nodes, status
  logical :: is_subsurface

  call check_case(nearest(1.0_real64, -1.0_real64), 1.0_real64, .false., 1, &
                  1.0_real64, nearest(1.0_real64, -1.0_real64), 0.0_real64, 1)
  call check_case(nearest(1.0_real64, 1.0_real64), 1.0_real64, .false., 1, &
                  nearest(1.0_real64, 1.0_real64), 1.0_real64, 0.0_real64, 2)
  call check_case(2.0_real64, 0.0_real64, .false., 1, 2.0_real64, 1.0_real64, 0.0_real64, 3)
  call check_case(0.5_real64, 0.5_real64, .true., 4, 0.5_real64, 1.0_real64, 2.0_real64, 4)

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, depth)
    depth = 100.0_real64*depth
    call random_unit(random_state, rate)
    rate = 240.0_real64*rate
    is_subsurface = modulo(i, 2) == 0
    active_nodes = 1 + modulo(i, 8)
    call source_rate(depth, rate, expected_rate, expected_duration)
    expected_sum = 0.0_real64
    if (is_subsurface) expected_sum = sum([(expected_rate, status=1,active_nodes)])
    call materialize_irrigation_rate(depth, rate, is_subsurface, active_nodes, effective_rate, duration, &
                                     node_rates, rate_sum, status)
    call require(status == IRR_RATE_MATERIALIZATION_OK, 10)
    call require(transfer(effective_rate, 0_int64) == transfer(expected_rate, 0_int64), 11)
    call require(transfer(duration, 0_int64) == transfer(expected_duration, 0_int64), 12)
    call require(transfer(rate_sum, 0_int64) == transfer(expected_sum, 0_int64), 13)
    if (is_subsurface) then
      call require(allocated(node_rates), 14)
      call require(size(node_rates) == active_nodes, 15)
      call require(maxval(abs(node_rates-effective_rate)) <= 0.0_real64, 16)
    else
      call require(.not. allocated(node_rates), 17)
    end if
  end do

  call materialize_irrigation_rate(1.0_real64, 241.0_real64, .false., 1, &
                                   effective_rate, duration, node_rates, rate_sum, status)
  call require(status == IRR_RATE_MATERIALIZATION_INVALID_INPUT, 18)

  print '(A)', 'PPA_IRR_RATE_MATERIALIZATION_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_RATE_DURATION_STRICT_ONE_DAY_ADAPTATION=PASS'
  print '(A)', 'PPA_IRR_RATE_ZERO_RATE_AND_SSDI_NODE_ASSIGNMENT=PASS'
  print '(A)', 'PPA_IRR_RATE_MATERIALIZATION_SOURCE_ORACLE=PASS'

contains

  subroutine source_rate(source_depth, source_rate_value, selected_rate, selected_duration)
    real(real64), intent(in) :: source_depth, source_rate_value
    real(real64), intent(out) :: selected_rate, selected_duration
    if (source_rate_value > 0.0_real64) then
      if (source_depth/source_rate_value > 1.0_real64) then
        selected_rate = source_depth
        selected_duration = 1.0_real64
      else
        selected_rate = source_rate_value
        selected_duration = source_depth/source_rate_value
      end if
    else
      selected_rate = source_depth
      selected_duration = 1.0_real64
    end if
  end subroutine source_rate

  subroutine check_case(source_depth, source_rate_value, subsurface, node_count, expected_rate_value, &
                        expected_duration_value, expected_sum_value, code)
    real(real64), intent(in) :: source_depth, source_rate_value, expected_rate_value
    real(real64), intent(in) :: expected_duration_value, expected_sum_value
    logical, intent(in) :: subsurface
    integer, intent(in) :: node_count, code
    real(real64) :: actual_rate, actual_duration, actual_sum
    integer :: actual_status
    call materialize_irrigation_rate(source_depth, source_rate_value, subsurface, node_count, &
                                     actual_rate, actual_duration, node_rates, actual_sum, actual_status)
    call require(actual_status == IRR_RATE_MATERIALIZATION_OK, 30+code)
    call require(abs(actual_rate-expected_rate_value) <= 2.0_real64*epsilon(actual_rate), 40+code)
    call require(abs(actual_duration-expected_duration_value) <= 2.0_real64*epsilon(actual_duration), 50+code)
    call require(abs(actual_sum-expected_sum_value) <= 2.0_real64*epsilon(actual_sum), 60+code)
  end subroutine check_case

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_RATE_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_rate_materialization_source_oracle
