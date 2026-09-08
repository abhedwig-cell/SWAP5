module mod_wofost_leaf_cohort_reallocation
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: WOFLEAF_OK = 0
  integer, parameter, public :: WOFLEAF_INVALID_COHORT_BIOMASS = 1
  integer, parameter, public :: WOFLEAF_INVALID_APPLIED_TRANSFER = 2
  integer, parameter, public :: WOFLEAF_TRANSFER_EXCEEDS_AVAILABLE = 3
  integer, parameter, public :: WOFLEAF_NUMERICAL_CLOSURE_FAILURE = 4

  type, public :: wofost_leaf_cohort_reallocation_diagnostics_t
    integer :: status = WOFLEAF_OK
    real(real64) :: available = 0.0_real64
    real(real64) :: applied = 0.0_real64
    real(real64) :: scale = 1.0_real64
    real(real64) :: removed = 0.0_real64
    real(real64) :: mass_residual = 0.0_real64
    real(real64) :: closure_tolerance = 0.0_real64
  end type wofost_leaf_cohort_reallocation_diagnostics_t

  public :: apply_wofost_leaf_reallocation_to_surviving_cohorts

contains

  pure subroutine apply_wofost_leaf_reallocation_to_surviving_cohorts(committed_weights, applied_leaf, &
                                                                      candidate_weights, diagnostics)
    real(real64), intent(in) :: committed_weights(:)
    real(real64), intent(in) :: applied_leaf
    real(real64), intent(out) :: candidate_weights(size(committed_weights))
    type(wofost_leaf_cohort_reallocation_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: available, candidate_total, scale, tolerance

    candidate_weights = committed_weights
    diagnostics = wofost_leaf_cohort_reallocation_diagnostics_t()

    if (.not. all(ieee_is_finite(committed_weights)) .or. any(committed_weights < 0.0_real64)) then
      diagnostics%status = WOFLEAF_INVALID_COHORT_BIOMASS
      return
    end if

    if (.not. ieee_is_finite(applied_leaf) .or. applied_leaf < 0.0_real64) then
      diagnostics%status = WOFLEAF_INVALID_APPLIED_TRANSFER
      return
    end if

    available = sum(committed_weights)
    diagnostics%available = available
    diagnostics%applied = applied_leaf
    tolerance = 256.0_real64 * epsilon(1.0_real64) * &
                max(1.0_real64, available, abs(applied_leaf))
    diagnostics%closure_tolerance = tolerance

    if (applied_leaf > available) then
      diagnostics%status = WOFLEAF_TRANSFER_EXCEEDS_AVAILABLE
      return
    end if

    if (available == 0.0_real64) then
      diagnostics%scale = 1.0_real64
      return
    end if

    if (applied_leaf == available) then
      candidate_weights = 0.0_real64
      diagnostics%scale = 0.0_real64
      diagnostics%removed = available
      diagnostics%mass_residual = available - applied_leaf
      return
    end if

    scale = (available - applied_leaf) / available
    candidate_weights = committed_weights * scale
    candidate_total = sum(candidate_weights)

    diagnostics%scale = scale
    diagnostics%removed = available - candidate_total
    diagnostics%mass_residual = diagnostics%removed - applied_leaf

    if (abs(diagnostics%mass_residual) > tolerance) then
      candidate_weights = committed_weights
      diagnostics%status = WOFLEAF_NUMERICAL_CLOSURE_FAILURE
      return
    end if
  end subroutine apply_wofost_leaf_reallocation_to_surviving_cohorts

end module mod_wofost_leaf_cohort_reallocation
