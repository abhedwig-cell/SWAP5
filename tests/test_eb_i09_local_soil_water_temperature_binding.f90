program test_eb_i09_local_soil_water_temperature_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_local_soil_water_temperature_binding, only: &
       local_soil_water_temperature_result_t, resolve_local_soil_water_donor_temperature, &
       LOCAL_SOIL_TEMP_NOT_REQUIRED, LOCAL_SOIL_TEMP_AVAILABLE, LOCAL_SOIL_TEMP_INVALID_TRANSFER, &
       LOCAL_SOIL_TEMP_INVALID_VIEW, LOCAL_SOIL_TEMP_INVALID_DONOR_NODE, LOCAL_SOIL_TEMP_INVALID_TEMPERATURE
  implicit none

  type(soil_temperature_field_view_t) :: view
  type(local_soil_water_temperature_result_t) :: result
  real(real64) :: nan_value, tiny_transfer

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  tiny_transfer = tiny(1.0_real64)

  call resolve_local_soil_water_donor_temperature(0.0_real64, -999, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_NOT_REQUIRED, 101)
  call require(.not. result%required, 102)

  call resolve_local_soil_water_donor_temperature(tiny_transfer, 1, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_INVALID_VIEW, 103)
  call require(result%required, 104)

  view%active_nodes = 3
  allocate(view%temperature_c(3))
  view%temperature_c = [8.0_real64, nan_value, 14.0_real64]

  call resolve_local_soil_water_donor_temperature(tiny_transfer, 1, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_AVAILABLE, 105)
  call require(result%required, 106)
  call require(result%donor_node == 1, 107)
  call require(same_real_bits(result%temperature_c, 8.0_real64), 108)

  call resolve_local_soil_water_donor_temperature(1.0_real64, 2, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_INVALID_TEMPERATURE, 109)
  call require(result%required, 110)

  call resolve_local_soil_water_donor_temperature(1.0_real64, 3, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_AVAILABLE, 111)
  call require(result%donor_node == 3, 112)
  call require(same_real_bits(result%temperature_c, 14.0_real64), 113)

  call resolve_local_soil_water_donor_temperature(1.0_real64, 0, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_INVALID_DONOR_NODE, 114)

  call resolve_local_soil_water_donor_temperature(1.0_real64, 4, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_INVALID_DONOR_NODE, 115)

  view%active_nodes = 4
  call resolve_local_soil_water_donor_temperature(1.0_real64, 1, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_INVALID_VIEW, 116)

  view%active_nodes = 3
  call resolve_local_soil_water_donor_temperature(-tiny_transfer, 1, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_INVALID_TRANSFER, 117)
  call require(.not. result%required, 118)

  call resolve_local_soil_water_donor_temperature(nan_value, 1, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_INVALID_TRANSFER, 119)
  call require(.not. result%required, 120)

  view%temperature_c(1) = -7.5_real64
  call resolve_local_soil_water_donor_temperature(2.0_real64, 1, view, result)
  call require(result%status == LOCAL_SOIL_TEMP_AVAILABLE, 121)
  call require(same_real_bits(result%temperature_c, -7.5_real64), 122)

  print '(a)', 'EB-I09 local soil water donor temperature: PASS'

contains

  pure logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      print '(a,i0)', 'EB-I09 failed check: ', code
      error stop 1
    end if
  end subroutine require

end program test_eb_i09_local_soil_water_temperature_binding
