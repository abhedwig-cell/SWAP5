program test_fpm08c4_multilevel_aggregation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_drainage_multilevel_aggregation, only: drainage_level_exchange_t, drainage_multilevel_aggregate_t, &
       drainage_multilevel_diagnostics_t, aggregate_drainage_levels, DRAINAGE_AGGREGATION_OK, &
       DRAINAGE_AGGREGATION_EMPTY, DRAINAGE_AGGREGATION_LEVEL_IDENTITY, DRAINAGE_AGGREGATION_INVALID_FLUX
  implicit none

  type(drainage_level_exchange_t), allocatable :: levels(:)
  type(drainage_multilevel_aggregate_t) :: a, a2, b
  type(drainage_multilevel_diagnostics_t) :: d, d2, db
  real(real64) :: expected, nan_value, large_derivative
  integer :: i

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

  allocate(levels(1))
  call set_level(levels(1), 1, 2.5_real64, .true., 0.25_real64)
  call aggregate_drainage_levels(levels, a, d)
  call require(d%status == DRAINAGE_AGGREGATION_OK .and. d%evaluated, 'one-level evaluated')
  call require(bits_equal(a%signed_soil_to_drain_rate, 2.5_real64), 'one-level flux identity')
  call require(a%derivative_defined .and. bits_equal(a%dq_dgroundwater_level, 0.25_real64), 'one-level derivative identity')
  call require(d%level_count == 1 .and. d%contains_positive_exchange, 'one-level diagnostics')
  write(*,'(A)') 'FPM08C4_ONE_LEVEL_IDENTITY=PASS'
  deallocate(levels)

  allocate(levels(3))
  call set_level(levels(1), 1, 1.25_real64, .true., 0.10_real64)
  call set_level(levels(2), 2, 2.50_real64, .true., 0.20_real64)
  call set_level(levels(3), 3, 4.00_real64, .true., 0.40_real64)
  call aggregate_drainage_levels(levels, a, d)
  expected = 0.0_real64
  do i = 1, size(levels)
    expected = expected + levels(i)%signed_soil_to_drain_rate
  end do
  call require(bits_equal(a%signed_soil_to_drain_rate, expected), 'deterministic level-order sum')
  call require(a%derivative_defined .and. close(a%dq_dgroundwater_level, 0.70_real64), 'defined derivative sum')
  write(*,'(A)') 'FPM08C4_DETERMINISTIC_MULTILEVEL_SUM=PASS'
  write(*,'(A)') 'FPM08C4_ALL_DEFINED_DERIVATIVE_SUM=PASS'

  levels(1)%signed_soil_to_drain_rate = 3.0_real64
  levels(2)%signed_soil_to_drain_rate = -1.5_real64
  levels(3)%signed_soil_to_drain_rate = 0.0_real64
  call aggregate_drainage_levels(levels, a, d)
  call require(close(a%signed_soil_to_drain_rate, 1.5_real64), 'mixed signed total')
  call require(d%contains_positive_exchange .and. d%contains_negative_exchange .and. d%contains_zero_exchange, 'mixed sign diagnostics')
  call require(d%total_is_derived_view_not_additional_transfer, 'total is derived view')
  write(*,'(A)') 'FPM08C4_MIXED_SIGNED_TRANSFER_AGGREGATION=PASS'
  write(*,'(A)') 'FPM08C4_TOTAL_IS_DERIVED_MASS_VIEW=PASS'

  levels(2)%derivative_defined = .false.
  levels(2)%branch_boundary = .true.
  levels(3)%singular_tangent = .true.
  levels(3)%branch_boundary = .true.
  call aggregate_drainage_levels(levels, a, d)
  call require(d%evaluated .and. close(a%signed_soil_to_drain_rate, 1.5_real64), 'flux preserved with unavailable derivative')
  call require(.not. a%derivative_defined, 'aggregate derivative unavailable')
  call require(d%derivative_unavailable_level_count == 2, 'unavailable derivative count')
  call require(d%branch_boundary_level_count == 2 .and. d%singular_tangent_level_count == 1, 'branch union counts')
  write(*,'(A)') 'FPM08C4_UNAVAILABLE_TANGENT_PRESERVES_FLUX=PASS'
  write(*,'(A)') 'FPM08C4_BRANCH_AND_SINGULARITY_UNION=PASS'

  levels(2)%derivative_defined = .true.
  levels(2)%branch_boundary = .false.
  levels(2)%dq_dgroundwater_level = nan_value
  levels(3)%singular_tangent = .false.
  levels(3)%branch_boundary = .false.
  call aggregate_drainage_levels(levels, a, d)
  call require(d%evaluated .and. close(a%signed_soil_to_drain_rate, 1.5_real64), 'nonfinite tangent preserves flux')
  call require(.not. a%derivative_defined .and. d%derivative_nonfinite_level_count == 1, 'nonfinite tangent diagnosed')
  write(*,'(A)') 'FPM08C4_NONFINITE_TANGENT_METADATA_PRESERVES_FLUX=PASS'
  deallocate(levels)

  allocate(levels(2))
  call set_level(levels(1), 1, 1.0_real64, .true., 0.1_real64)
  call set_level(levels(2), 2, nan_value, .true., 0.2_real64)
  call aggregate_drainage_levels(levels, a, d)
  call require(d%status == DRAINAGE_AGGREGATION_INVALID_FLUX .and. .not. d%evaluated, 'invalid flux fails closed')
  call require(d%invalid_level_index == 2, 'invalid flux level diagnostic')
  write(*,'(A)') 'FPM08C4_INVALID_FLUX_FAILS_CLOSED=PASS'

  call set_level(levels(2), 3, 2.0_real64, .true., 0.2_real64)
  call aggregate_drainage_levels(levels, a, d)
  call require(d%status == DRAINAGE_AGGREGATION_LEVEL_IDENTITY .and. .not. d%evaluated, 'level identity fails closed')
  write(*,'(A)') 'FPM08C4_LEVEL_IDENTITY_ORDER_FAILS_CLOSED=PASS'
  deallocate(levels)

  allocate(levels(0))
  call aggregate_drainage_levels(levels, a, d)
  call require(d%status == DRAINAGE_AGGREGATION_EMPTY .and. .not. d%evaluated, 'empty collection fails closed')
  write(*,'(A)') 'FPM08C4_EMPTY_COLLECTION_FAILS_CLOSED=PASS'
  deallocate(levels)

  allocate(levels(64))
  expected = 0.0_real64
  do i = 1, size(levels)
    call set_level(levels(i), i, real(i, real64) / 1000.0_real64, .true., real(i, real64) / 10000.0_real64)
    expected = expected + levels(i)%signed_soil_to_drain_rate
  end do
  call aggregate_drainage_levels(levels, a, d)
  call require(d%evaluated .and. d%level_count == 64, 'dynamic level count 64')
  call require(bits_equal(a%signed_soil_to_drain_rate, expected), 'dynamic level deterministic sum')
  call require(.not. d%fixed_legacy_level_capacity, 'no legacy capacity contract')
  write(*,'(A)') 'FPM08C4_DYNAMIC_LEVEL_COUNT_ABOVE_LEGACY_CAPACITY=PASS'
  deallocate(levels)

  allocate(levels(2))
  large_derivative = huge(1.0_real64) * 0.75_real64
  call set_level(levels(1), 1, 1.0_real64, .true., large_derivative)
  call set_level(levels(2), 2, 2.0_real64, .true., large_derivative)
  call aggregate_drainage_levels(levels, a, d)
  call require(d%evaluated .and. close(a%signed_soil_to_drain_rate, 3.0_real64), 'derivative overflow preserves flux')
  call require(.not. a%derivative_defined .and. d%aggregate_derivative_numerically_unrepresentable, 'aggregate derivative overflow diagnosed')
  write(*,'(A)') 'FPM08C4_AGGREGATE_DERIVATIVE_OVERFLOW_PRESERVES_FLUX=PASS'
  deallocate(levels)

  allocate(levels(4))
  do i = 1, 4
    call set_level(levels(i), i, real(i*i, real64) / 7.0_real64, .true., real(i, real64) / 11.0_real64)
  end do
  call aggregate_drainage_levels(levels, a, d)
  levels(3)%signed_soil_to_drain_rate = -9.0_real64
  call aggregate_drainage_levels(levels, b, db)
  levels(3)%signed_soil_to_drain_rate = 9.0_real64 / 7.0_real64
  call aggregate_drainage_levels(levels, a2, d2)
  call require(.not. same_aggregate_bits(a, b), 'A differs from B')
  call require(same_aggregate_bits(a, a2), 'A/B/A aggregate identity')
  call require(same_diagnostic_bits(d, d2), 'A/B/A diagnostic identity')
  call require(.not. d%persistent_process_state .and. d%deterministic_level_order, 'stateless deterministic diagnostics')
  write(*,'(A)') 'FPM08C4_STATELESS_A_B_A_IDENTITY=PASS'

  write(*,'(A)') 'FPM08C4_MULTILEVEL_AGGREGATION_TEST PASS'

contains

  subroutine set_level(item, index, rate, derivative_defined, derivative)
    type(drainage_level_exchange_t), intent(out) :: item
    integer, intent(in) :: index
    real(real64), intent(in) :: rate, derivative
    logical, intent(in) :: derivative_defined

    item = drainage_level_exchange_t()
    item%level_index = index
    item%flux_defined = .true.
    item%signed_soil_to_drain_rate = rate
    item%derivative_defined = derivative_defined
    item%dq_dgroundwater_level = derivative
  end subroutine set_level

  logical function close(x, y) result(equal)
    real(real64), intent(in) :: x, y
    equal = abs(x-y) <= 8192.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(x), abs(y))
  end function close

  logical function bits_equal(x, y) result(equal)
    real(real64), intent(in) :: x, y
    integer(int64) :: ix, iy
    ix = transfer(x, ix)
    iy = transfer(y, iy)
    equal = ix == iy
  end function bits_equal

  logical function same_aggregate_bits(x, y) result(equal)
    type(drainage_multilevel_aggregate_t), intent(in) :: x, y
    equal = bits_equal(x%signed_soil_to_drain_rate, y%signed_soil_to_drain_rate) .and. &
         (x%derivative_defined .eqv. y%derivative_defined) .and. bits_equal(x%dq_dgroundwater_level, y%dq_dgroundwater_level)
  end function same_aggregate_bits

  logical function same_diagnostic_bits(x, y) result(equal)
    type(drainage_multilevel_diagnostics_t), intent(in) :: x, y
    equal = x%status == y%status .and. (x%evaluated .eqv. y%evaluated) .and. x%level_count == y%level_count .and. &
         x%invalid_level_index == y%invalid_level_index .and. &
         x%derivative_unavailable_level_count == y%derivative_unavailable_level_count .and. &
         x%derivative_nonfinite_level_count == y%derivative_nonfinite_level_count .and. &
         x%branch_boundary_level_count == y%branch_boundary_level_count .and. &
         x%singular_tangent_level_count == y%singular_tangent_level_count .and. &
         (x%contains_positive_exchange .eqv. y%contains_positive_exchange) .and. &
         (x%contains_negative_exchange .eqv. y%contains_negative_exchange) .and. &
         (x%contains_zero_exchange .eqv. y%contains_zero_exchange) .and. &
         (x%aggregate_derivative_numerically_unrepresentable .eqv. y%aggregate_derivative_numerically_unrepresentable) .and. &
         (x%total_is_derived_view_not_additional_transfer .eqv. y%total_is_derived_view_not_additional_transfer) .and. &
         (x%deterministic_level_order .eqv. y%deterministic_level_order) .and. &
         (x%persistent_process_state .eqv. y%persistent_process_state) .and. &
         (x%fixed_legacy_level_capacity .eqv. y%fixed_legacy_level_capacity)
  end function same_diagnostic_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08C4_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm08c4_multilevel_aggregation
