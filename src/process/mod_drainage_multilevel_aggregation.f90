module mod_drainage_multilevel_aggregation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: DRAINAGE_AGGREGATION_OK = 0
  integer, parameter, public :: DRAINAGE_AGGREGATION_EMPTY = 1
  integer, parameter, public :: DRAINAGE_AGGREGATION_LEVEL_IDENTITY = 2
  integer, parameter, public :: DRAINAGE_AGGREGATION_INVALID_FLUX = 3
  integer, parameter, public :: DRAINAGE_AGGREGATION_FLUX_NUMERICAL_DOMAIN = 4

  type, public :: drainage_level_exchange_t
    integer :: level_index = 0
    logical :: flux_defined = .false.
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
    logical :: branch_boundary = .false.
    logical :: singular_tangent = .false.
  end type drainage_level_exchange_t

  type, public :: drainage_multilevel_aggregate_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
  end type drainage_multilevel_aggregate_t

  type, public :: drainage_multilevel_diagnostics_t
    integer :: status = DRAINAGE_AGGREGATION_OK
    logical :: evaluated = .false.
    integer :: level_count = 0
    integer :: invalid_level_index = 0
    integer :: derivative_unavailable_level_count = 0
    integer :: derivative_nonfinite_level_count = 0
    integer :: branch_boundary_level_count = 0
    integer :: singular_tangent_level_count = 0
    logical :: contains_positive_exchange = .false.
    logical :: contains_negative_exchange = .false.
    logical :: contains_zero_exchange = .false.
    logical :: aggregate_derivative_numerically_unrepresentable = .false.
    logical :: total_is_derived_view_not_additional_transfer = .true.
    logical :: deterministic_level_order = .true.
    logical :: persistent_process_state = .false.
    logical :: fixed_legacy_level_capacity = .false.
  end type drainage_multilevel_diagnostics_t

  public :: aggregate_drainage_levels

contains

  subroutine aggregate_drainage_levels(levels, aggregate, diagnostics)
    type(drainage_level_exchange_t), intent(in) :: levels(:)
    type(drainage_multilevel_aggregate_t), intent(out) :: aggregate
    type(drainage_multilevel_diagnostics_t), intent(out) :: diagnostics

    integer :: level
    real(real64) :: total_rate, total_derivative, candidate_derivative
    logical :: all_derivatives_available

    aggregate = drainage_multilevel_aggregate_t()
    diagnostics = drainage_multilevel_diagnostics_t()
    diagnostics%level_count = size(levels)

    if (size(levels) < 1) then
      diagnostics%status = DRAINAGE_AGGREGATION_EMPTY
      return
    end if

    all_derivatives_available = .true.

    do level = 1, size(levels)
      if (levels(level)%level_index /= level) then
        diagnostics%status = DRAINAGE_AGGREGATION_LEVEL_IDENTITY
        diagnostics%invalid_level_index = level
        return
      end if

      if (.not. levels(level)%flux_defined .or. &
          .not. ieee_is_finite(levels(level)%signed_soil_to_drain_rate)) then
        diagnostics%status = DRAINAGE_AGGREGATION_INVALID_FLUX
        diagnostics%invalid_level_index = level
        return
      end if

      if (levels(level)%signed_soil_to_drain_rate > 0.0_real64) then
        diagnostics%contains_positive_exchange = .true.
      else if (levels(level)%signed_soil_to_drain_rate < 0.0_real64) then
        diagnostics%contains_negative_exchange = .true.
      else
        diagnostics%contains_zero_exchange = .true.
      end if

      if (levels(level)%branch_boundary) then
        diagnostics%branch_boundary_level_count = diagnostics%branch_boundary_level_count + 1
      end if
      if (levels(level)%singular_tangent) then
        diagnostics%singular_tangent_level_count = diagnostics%singular_tangent_level_count + 1
      end if

      if (.not. levels(level)%derivative_defined .or. levels(level)%singular_tangent) then
        diagnostics%derivative_unavailable_level_count = diagnostics%derivative_unavailable_level_count + 1
        all_derivatives_available = .false.
      else if (.not. ieee_is_finite(levels(level)%dq_dgroundwater_level)) then
        diagnostics%derivative_nonfinite_level_count = diagnostics%derivative_nonfinite_level_count + 1
        diagnostics%derivative_unavailable_level_count = diagnostics%derivative_unavailable_level_count + 1
        all_derivatives_available = .false.
      end if
    end do

    total_rate = 0.0_real64
    do level = 1, size(levels)
      total_rate = total_rate + levels(level)%signed_soil_to_drain_rate
      if (.not. ieee_is_finite(total_rate)) then
        aggregate = drainage_multilevel_aggregate_t()
        diagnostics%status = DRAINAGE_AGGREGATION_FLUX_NUMERICAL_DOMAIN
        diagnostics%invalid_level_index = level
        return
      end if
    end do

    aggregate%signed_soil_to_drain_rate = total_rate
    diagnostics%evaluated = .true.

    if (.not. all_derivatives_available) return

    total_derivative = 0.0_real64
    do level = 1, size(levels)
      candidate_derivative = total_derivative + levels(level)%dq_dgroundwater_level
      if (.not. ieee_is_finite(candidate_derivative)) then
        diagnostics%aggregate_derivative_numerically_unrepresentable = .true.
        aggregate%derivative_defined = .false.
        aggregate%dq_dgroundwater_level = 0.0_real64
        return
      end if
      total_derivative = candidate_derivative
    end do

    aggregate%derivative_defined = .true.
    aggregate%dq_dgroundwater_level = total_derivative
  end subroutine aggregate_drainage_levels

end module mod_drainage_multilevel_aggregation
