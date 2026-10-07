module mod_irrigation_availability_scaling
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_AVAIL_OK = 0
  integer, parameter, public :: IRR_AVAIL_INVALID = 1

  type, public :: irrigation_availability_result_t
    real(real64) :: scaled_rate_cm_per_day = 0.0_real64
    real(real64) :: scaled_duration_day = 0.0_real64
    real(real64) :: delivered_amount_cm = 0.0_real64
  end type irrigation_availability_result_t

  public :: apply_legacy_irrigation_availability

contains

  pure subroutine apply_legacy_irrigation_availability(base_rate_cm_per_day, base_duration_day, &
                                                        configured_rate_cm_per_day, availability_factor, &
                                                        result, status)
    real(real64), intent(in) :: base_rate_cm_per_day
    real(real64), intent(in) :: base_duration_day
    real(real64), intent(in) :: configured_rate_cm_per_day
    real(real64), intent(in) :: availability_factor
    type(irrigation_availability_result_t), intent(out) :: result
    integer, intent(out) :: status

    result = irrigation_availability_result_t()
    status = IRR_AVAIL_INVALID

    if (.not. ieee_is_finite(base_rate_cm_per_day) .or. base_rate_cm_per_day < 0.0_real64) return
    if (.not. ieee_is_finite(base_duration_day) .or. base_duration_day < 0.0_real64) return
    if (.not. ieee_is_finite(configured_rate_cm_per_day) .or. configured_rate_cm_per_day < 0.0_real64) return
    if (.not. ieee_is_finite(availability_factor) .or. availability_factor < 0.0_real64) return

    ! Literal B1.11 TASK=4 semantics:
    !   gird = gird * f_irr_avail
    !   if (irr_rate > 0.0d0) dt_irr_event = dt_irr_event * f_irr_avail
    result%scaled_rate_cm_per_day = base_rate_cm_per_day * availability_factor
    result%scaled_duration_day = base_duration_day
    if (configured_rate_cm_per_day > 0.0_real64) then
      result%scaled_duration_day = base_duration_day * availability_factor
    end if
    result%delivered_amount_cm = result%scaled_rate_cm_per_day * result%scaled_duration_day

    if (.not. ieee_is_finite(result%scaled_rate_cm_per_day)) return
    if (.not. ieee_is_finite(result%scaled_duration_day)) return
    if (.not. ieee_is_finite(result%delivered_amount_cm)) return
    status = IRR_AVAIL_OK
  end subroutine apply_legacy_irrigation_availability

end module mod_irrigation_availability_scaling
