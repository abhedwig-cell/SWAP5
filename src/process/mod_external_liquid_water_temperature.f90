module mod_external_liquid_water_temperature
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: EXT_LIQ_TEMP_NOT_REQUIRED = 0
  integer, parameter, public :: EXT_LIQ_TEMP_AVAILABLE = 1
  integer, parameter, public :: EXT_LIQ_TEMP_MISSING = 2
  integer, parameter, public :: EXT_LIQ_TEMP_INVALID_TRANSFER = 3
  integer, parameter, public :: EXT_LIQ_TEMP_INVALID_TEMPERATURE = 4

  type, public :: external_liquid_water_temperature_t
    logical :: available = .false.
    real(real64) :: temperature_c = 0.0_real64
  end type external_liquid_water_temperature_t

  type, public :: external_liquid_water_temperature_result_t
    integer :: status = EXT_LIQ_TEMP_INVALID_TRANSFER
    logical :: required = .false.
    real(real64) :: temperature_c = 0.0_real64
  end type external_liquid_water_temperature_result_t

  public :: resolve_external_liquid_water_temperature

contains

  pure subroutine resolve_external_liquid_water_temperature(inflow_amount, provenance, result)
    real(real64), intent(in) :: inflow_amount
    type(external_liquid_water_temperature_t), intent(in) :: provenance
    type(external_liquid_water_temperature_result_t), intent(out) :: result

    result = external_liquid_water_temperature_result_t()

    if (.not. ieee_is_finite(inflow_amount)) then
      result%status = EXT_LIQ_TEMP_INVALID_TRANSFER
      return
    end if

    if (inflow_amount < 0.0_real64) then
      result%status = EXT_LIQ_TEMP_INVALID_TRANSFER
      return
    end if

    if (inflow_amount > 0.0_real64) then
      result%required = .true.

      if (.not. provenance%available) then
        result%status = EXT_LIQ_TEMP_MISSING
        return
      end if

      if (.not. ieee_is_finite(provenance%temperature_c)) then
        result%status = EXT_LIQ_TEMP_INVALID_TEMPERATURE
        return
      end if

      result%temperature_c = provenance%temperature_c
      result%status = EXT_LIQ_TEMP_AVAILABLE
      return
    end if

    result%status = EXT_LIQ_TEMP_NOT_REQUIRED
  end subroutine resolve_external_liquid_water_temperature

end module mod_external_liquid_water_temperature
