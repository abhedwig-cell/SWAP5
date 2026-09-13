program test_eb_i08_external_liquid_water_temperature
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use mod_external_liquid_water_temperature, only: &
       external_liquid_water_temperature_t, external_liquid_water_temperature_result_t, &
       resolve_external_liquid_water_temperature, EXT_LIQ_TEMP_NOT_REQUIRED, EXT_LIQ_TEMP_AVAILABLE, &
       EXT_LIQ_TEMP_MISSING, EXT_LIQ_TEMP_INVALID_TRANSFER, EXT_LIQ_TEMP_INVALID_TEMPERATURE
  implicit none

  type(external_liquid_water_temperature_t) :: provenance
  type(external_liquid_water_temperature_result_t) :: result
  real(real64) :: nan_value, tiny_transfer, large_finite_temperature

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  tiny_transfer = tiny(1.0_real64)
  large_finite_temperature = huge(1.0_real64) / 4.0_real64

  provenance = external_liquid_water_temperature_t()
  call resolve_external_liquid_water_temperature(0.0_real64, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_NOT_REQUIRED, 101)
  call require(.not. result%required, 102)

  provenance%available = .true.
  provenance%temperature_c = nan_value
  call resolve_external_liquid_water_temperature(0.0_real64, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_NOT_REQUIRED, 103)
  call require(.not. result%required, 104)

  provenance = external_liquid_water_temperature_t()
  call resolve_external_liquid_water_temperature(tiny_transfer, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_MISSING, 105)
  call require(result%required, 106)

  provenance%available = .true.
  provenance%temperature_c = 7.25_real64
  call resolve_external_liquid_water_temperature(tiny_transfer, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_AVAILABLE, 107)
  call require(result%required, 108)
  call require(same_real_bits(result%temperature_c, provenance%temperature_c), 109)

  provenance = external_liquid_water_temperature_t()
  call resolve_external_liquid_water_temperature(1.25_real64, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_MISSING, 110)
  call require(result%required, 111)

  provenance%available = .true.
  provenance%temperature_c = -3.5_real64
  call resolve_external_liquid_water_temperature(1.25_real64, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_AVAILABLE, 112)
  call require(same_real_bits(result%temperature_c, -3.5_real64), 113)

  provenance%temperature_c = nan_value
  call resolve_external_liquid_water_temperature(1.25_real64, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_INVALID_TEMPERATURE, 114)
  call require(result%required, 115)

  provenance%temperature_c = 12.0_real64
  call resolve_external_liquid_water_temperature(-tiny_transfer, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_INVALID_TRANSFER, 116)
  call require(.not. result%required, 117)

  call resolve_external_liquid_water_temperature(nan_value, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_INVALID_TRANSFER, 118)
  call require(.not. result%required, 119)

  provenance%temperature_c = large_finite_temperature
  call resolve_external_liquid_water_temperature(2.0_real64, provenance, result)
  call require(result%status == EXT_LIQ_TEMP_AVAILABLE, 120)
  call require(same_real_bits(result%temperature_c, large_finite_temperature), 121)

  print '(a)', 'EB-I08 external liquid water temperature: PASS'

contains

  pure logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) error stop code
  end subroutine require

end program test_eb_i08_external_liquid_water_temperature
