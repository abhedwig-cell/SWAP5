module mod_local_soil_water_temperature_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  implicit none
  private

  integer, parameter, public :: LOCAL_SOIL_TEMP_NOT_REQUIRED = 0
  integer, parameter, public :: LOCAL_SOIL_TEMP_AVAILABLE = 1
  integer, parameter, public :: LOCAL_SOIL_TEMP_INVALID_TRANSFER = 2
  integer, parameter, public :: LOCAL_SOIL_TEMP_INVALID_VIEW = 3
  integer, parameter, public :: LOCAL_SOIL_TEMP_INVALID_DONOR_NODE = 4
  integer, parameter, public :: LOCAL_SOIL_TEMP_INVALID_TEMPERATURE = 5

  type, public :: local_soil_water_temperature_result_t
    integer :: status = LOCAL_SOIL_TEMP_INVALID_TRANSFER
    logical :: required = .false.
    integer :: donor_node = 0
    real(real64) :: temperature_c = 0.0_real64
  end type local_soil_water_temperature_result_t

  public :: resolve_local_soil_water_donor_temperature

contains

  pure subroutine resolve_local_soil_water_donor_temperature(outflow_amount, donor_node, temperature_view, result)
    real(real64), intent(in) :: outflow_amount
    integer, intent(in) :: donor_node
    type(soil_temperature_field_view_t), intent(in) :: temperature_view
    type(local_soil_water_temperature_result_t), intent(out) :: result

    result = local_soil_water_temperature_result_t()

    if (.not. ieee_is_finite(outflow_amount)) then
      result%status = LOCAL_SOIL_TEMP_INVALID_TRANSFER
      return
    end if

    if (outflow_amount < 0.0_real64) then
      result%status = LOCAL_SOIL_TEMP_INVALID_TRANSFER
      return
    end if

    if (outflow_amount > 0.0_real64) then
      result%required = .true.

      if (temperature_view%active_nodes <= 0) then
        result%status = LOCAL_SOIL_TEMP_INVALID_VIEW
        return
      end if
      if (.not. allocated(temperature_view%temperature_c)) then
        result%status = LOCAL_SOIL_TEMP_INVALID_VIEW
        return
      end if
      if (size(temperature_view%temperature_c) /= temperature_view%active_nodes) then
        result%status = LOCAL_SOIL_TEMP_INVALID_VIEW
        return
      end if
      if (donor_node < 1 .or. donor_node > temperature_view%active_nodes) then
        result%status = LOCAL_SOIL_TEMP_INVALID_DONOR_NODE
        return
      end if
      if (.not. ieee_is_finite(temperature_view%temperature_c(donor_node))) then
        result%status = LOCAL_SOIL_TEMP_INVALID_TEMPERATURE
        return
      end if

      result%donor_node = donor_node
      result%temperature_c = temperature_view%temperature_c(donor_node)
      result%status = LOCAL_SOIL_TEMP_AVAILABLE
      return
    end if

    result%status = LOCAL_SOIL_TEMP_NOT_REQUIRED
  end subroutine resolve_local_soil_water_donor_temperature

end module mod_local_soil_water_temperature_binding
