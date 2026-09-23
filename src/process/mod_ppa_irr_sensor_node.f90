module mod_ppa_irr_sensor_node
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  real(real64), parameter :: SENSOR_DEPTH_TOLERANCE = 1.0e-5_real64
  public :: locate_irrigation_sensor_node

contains

  pure subroutine locate_irrigation_sensor_node(dcrit, compartment_bottom, sensor_node, found)
    real(real64), intent(in) :: dcrit
    real(real64), intent(in) :: compartment_bottom(:)
    integer, intent(out) :: sensor_node
    logical, intent(out) :: found

    sensor_node = 1
    found = .false.
    do while (sensor_node <= size(compartment_bottom))
      if (compartment_bottom(sensor_node) <= dcrit + SENSOR_DEPTH_TOLERANCE) then
        found = .true.
        return
      end if
      sensor_node = sensor_node + 1
    end do
  end subroutine locate_irrigation_sensor_node

end module mod_ppa_irr_sensor_node
