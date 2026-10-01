module mod_external_top_surface_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: EXT_TOP_TRANSFER_OK = 0
  integer, parameter, public :: EXT_TOP_TRANSFER_INVALID = 1

  type, public :: external_top_surface_balance_t
    real(real64) :: previous_ponding_cm = 0.0_real64
    real(real64) :: candidate_ponding_cm = 0.0_real64
    real(real64) :: atmospheric_source_cm = 0.0_real64
    real(real64) :: evaporation_cm = 0.0_real64
    real(real64) :: soil_entry_cm = 0.0_real64
    real(real64) :: runoff_external_cm = 0.0_real64
  end type

  type, public :: external_top_surface_transfer_t
    integer :: status = EXT_TOP_TRANSFER_INVALID
    real(real64) :: ribasim_to_swap_cm = 0.0_real64
    real(real64) :: legacy_runots_cm = 0.0_real64
    real(real64) :: closure_residual_cm = 0.0_real64
  end type

  public :: materialize_external_top_surface_transfer

contains

  pure subroutine materialize_external_top_surface_transfer(balance, result)
    type(external_top_surface_balance_t), intent(in) :: balance
    type(external_top_surface_transfer_t), intent(out) :: result
    real(real64) :: ds, x

    result = external_top_surface_transfer_t()
    if (.not. all(ieee_is_finite([balance%previous_ponding_cm, balance%candidate_ponding_cm, &
         balance%atmospheric_source_cm, balance%evaporation_cm, balance%soil_entry_cm, &
         balance%runoff_external_cm]))) return
    if (balance%previous_ponding_cm < 0.0_real64 .or. balance%candidate_ponding_cm < 0.0_real64 .or. &
        balance%atmospheric_source_cm < 0.0_real64 .or. balance%evaporation_cm < 0.0_real64 .or. &
        balance%runoff_external_cm < 0.0_real64) return

    ds = balance%candidate_ponding_cm - balance%previous_ponding_cm
    x = ds - balance%atmospheric_source_cm + balance%evaporation_cm + &
        balance%soil_entry_cm + balance%runoff_external_cm

    result%ribasim_to_swap_cm = x
    result%legacy_runots_cm = -x
    result%closure_residual_cm = ds - (balance%atmospheric_source_cm + x - balance%evaporation_cm - &
         balance%soil_entry_cm - balance%runoff_external_cm)
    if (.not. ieee_is_finite(x) .or. .not. ieee_is_finite(result%closure_residual_cm)) return
    result%status = EXT_TOP_TRANSFER_OK
  end subroutine

end module mod_external_top_surface_transfer
