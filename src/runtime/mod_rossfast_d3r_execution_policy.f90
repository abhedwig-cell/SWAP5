module mod_rossfast_d3r_execution_policy
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  implicit none
  private

  real(real64), parameter, public :: ROSSFAST_D3R_OUTER_HORIZON_DAY = 0.0016_real64
  real(real64), parameter, public :: ROSSFAST_D3R_RETRY_SCALE = 0.5_real64
  integer, parameter, public :: ROSSFAST_D3R_MAX_FULL_INDEX = 8
  integer, parameter, public :: ROSSFAST_D3R_HALF_ONLY_INDEX = 9
  real(real64), parameter, public :: ROSSFAST_D3R_ENDPOINT_ULP_MULTIPLIER = 2.0_real64
  real(real64), parameter, public :: ROSSFAST_D3R_MIN_FULL_DURATION_DAY = &
       ROSSFAST_D3R_OUTER_HORIZON_DAY * ROSSFAST_D3R_RETRY_SCALE**ROSSFAST_D3R_MAX_FULL_INDEX

  public :: apply_rossfast_d3r_retry_policy
  public :: rossfast_d3r_full_duration_for_index
  public :: rossfast_d3r_select_transaction_window

contains

  pure function rossfast_d3r_full_duration_for_index(index) result(duration)
    integer, intent(in) :: index
    real(real64) :: duration

    if (index < 0 .or. index > ROSSFAST_D3R_MAX_FULL_INDEX) then
      duration = 0.0_real64
    else
      duration = ROSSFAST_D3R_OUTER_HORIZON_DAY * ROSSFAST_D3R_RETRY_SCALE**index
    end if
  end function rossfast_d3r_full_duration_for_index

  subroutine apply_rossfast_d3r_retry_policy(config)
    type(canonical_numerical_config_t), intent(inout) :: config

    config%transaction%retry_scale = ROSSFAST_D3R_RETRY_SCALE
    config%transaction%max_retries = ROSSFAST_D3R_MAX_FULL_INDEX
  end subroutine apply_rossfast_d3r_retry_policy

  subroutine rossfast_d3r_select_transaction_window(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    real(real64) :: remainder, duration, expected_t1, endpoint_tol
    real(real64) :: grid_value, grid_tol, units_real
    integer :: index, grid_units

    target_t1 = cursor
    max_retries_cap = 0
    valid = .false.

    if (.not. ieee_is_finite(cursor) .or. .not. ieee_is_finite(requested_t1)) return
    if (requested_t1 <= cursor) return

    remainder = requested_t1 - cursor
    if (.not. ieee_is_finite(remainder)) return

    endpoint_tol = ROSSFAST_D3R_ENDPOINT_ULP_MULTIPLIER * &
         max(spacing(cursor), spacing(requested_t1), spacing(remainder), &
             spacing(ROSSFAST_D3R_OUTER_HORIZON_DAY))
    if (remainder > ROSSFAST_D3R_OUTER_HORIZON_DAY + endpoint_tol) return

    ! Exact D3R K_RUNTIME scope: every submitted remainder must lie on the
    ! level-8 full-attempt integer grid.  This rejects off-grid outer requests
    ! before any physical trial rather than accepting a private partial chain.
    units_real = remainder / ROSSFAST_D3R_MIN_FULL_DURATION_DAY
    grid_units = nint(units_real)
    if (grid_units < 1) return
    grid_value = real(grid_units, real64) * ROSSFAST_D3R_MIN_FULL_DURATION_DAY
    grid_tol = ROSSFAST_D3R_ENDPOINT_ULP_MULTIPLIER * &
         max(spacing(cursor), spacing(requested_t1), spacing(remainder), &
             spacing(grid_value), spacing(ROSSFAST_D3R_MIN_FULL_DURATION_DAY))
    if (abs(remainder - grid_value) > grid_tol) return

    ! Greedy largest qualified full-attempt duration not exceeding remainder.
    ! Index 9 is half-step-only evidence and is deliberately never selected as
    ! a standalone transaction window.  Retry depth is capped so a segment at
    ! full index j can reach at most full index 8.
    do index = 0, ROSSFAST_D3R_MAX_FULL_INDEX
      duration = rossfast_d3r_full_duration_for_index(index)
      expected_t1 = cursor + duration
      endpoint_tol = ROSSFAST_D3R_ENDPOINT_ULP_MULTIPLIER * &
           max(spacing(cursor), spacing(requested_t1), spacing(expected_t1), spacing(duration))

      if (duration <= remainder + endpoint_tol) then
        if (abs(requested_t1 - expected_t1) <= endpoint_tol) then
          target_t1 = requested_t1
        else
          target_t1 = expected_t1
        end if
        max_retries_cap = ROSSFAST_D3R_MAX_FULL_INDEX - index
        valid = .true.
        return
      end if
    end do
  end subroutine rossfast_d3r_select_transaction_window

end module mod_rossfast_d3r_execution_policy
