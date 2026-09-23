module mod_external_surface_water_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: EXT_SW_TX_INVALID = 0
  integer, parameter, public :: EXT_SW_TX_COMMIT_READY = 1
  integer, parameter, public :: EXT_SW_TX_RECOMPOSITION_REQUIRED = 2
  integer, parameter, public :: EXT_SW_TX_STALE_ORIGIN = 3

  type, public :: external_surface_water_origin_t
    integer(int64) :: swap_revision = -1_int64
    integer(int64) :: ribasim_origin_id = -1_int64
    integer(int64) :: ribasim_revision = -1_int64
  end type external_surface_water_origin_t

  type, public :: external_surface_water_request_t
    type(external_surface_water_origin_t) :: origin
    real(real64) :: accepted_surface_water_head_cm = 0.0_real64
    real(real64) :: requested_signed_soil_to_surface_volume_m3 = 0.0_real64
  end type external_surface_water_request_t

  type, public :: external_surface_water_realization_t
    type(external_surface_water_origin_t) :: origin
    real(real64) :: realized_signed_soil_to_surface_volume_m3 = 0.0_real64
  end type external_surface_water_realization_t

  type, public :: external_surface_water_transaction_result_t
    integer :: disposition = EXT_SW_TX_INVALID
    real(real64) :: accepted_signed_soil_to_surface_volume_m3 = 0.0_real64
    logical :: swap_may_commit = .false.
    logical :: ribasim_may_commit = .false.
    logical :: exactly_once_transfer_ready = .false.
  end type external_surface_water_transaction_result_t

  public :: evaluate_external_surface_water_transaction
  public :: same_external_surface_water_origin

contains

  pure logical function same_external_surface_water_origin(a,b) result(same)
    type(external_surface_water_origin_t), intent(in) :: a,b
    same = a%swap_revision == b%swap_revision .and. &
           a%ribasim_origin_id == b%ribasim_origin_id .and. &
           a%ribasim_revision == b%ribasim_revision
  end function same_external_surface_water_origin

  subroutine evaluate_external_surface_water_transaction(accepted_origin, request, realization, result)
    type(external_surface_water_origin_t), intent(in) :: accepted_origin
    type(external_surface_water_request_t), intent(in) :: request
    type(external_surface_water_realization_t), intent(in) :: realization
    type(external_surface_water_transaction_result_t), intent(out) :: result

    result = external_surface_water_transaction_result_t()

    if (accepted_origin%swap_revision < 0_int64 .or. &
        accepted_origin%ribasim_origin_id < 0_int64 .or. &
        accepted_origin%ribasim_revision < 0_int64) return
    if (.not. ieee_is_finite(request%accepted_surface_water_head_cm)) return
    if (.not. ieee_is_finite(request%requested_signed_soil_to_surface_volume_m3)) return
    if (.not. ieee_is_finite(realization%realized_signed_soil_to_surface_volume_m3)) return

    if (.not. same_external_surface_water_origin(request%origin, accepted_origin) .or. &
        .not. same_external_surface_water_origin(realization%origin, accepted_origin)) then
      result%disposition = EXT_SW_TX_STALE_ORIGIN
      return
    end if

    if (same_real_bits(request%requested_signed_soil_to_surface_volume_m3, &
                       realization%realized_signed_soil_to_surface_volume_m3)) then
      result%disposition = EXT_SW_TX_COMMIT_READY
      result%accepted_signed_soil_to_surface_volume_m3 = &
           realization%realized_signed_soil_to_surface_volume_m3
      result%swap_may_commit = .true.
      result%ribasim_may_commit = .true.
      result%exactly_once_transfer_ready = .true.
    else
      result%disposition = EXT_SW_TX_RECOMPOSITION_REQUIRED
      result%accepted_signed_soil_to_surface_volume_m3 = &
           realization%realized_signed_soil_to_surface_volume_m3
      result%swap_may_commit = .false.
      result%ribasim_may_commit = .false.
      result%exactly_once_transfer_ready = .false.
    end if
  end subroutine evaluate_external_surface_water_transaction

  pure logical function same_real_bits(a,b) result(same)
    real(real64), intent(in) :: a,b
    same = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_real_bits

end module mod_external_surface_water_transaction
