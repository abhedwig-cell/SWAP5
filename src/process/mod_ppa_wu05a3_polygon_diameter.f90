module mod_ppa_wu05a3_polygon_diameter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_WU05A3_POLYGON_DIAMETER_OK = 0
  integer, parameter, public :: PPA_WU05A3_POLYGON_DIAMETER_INVALID_INPUT = 1
  public :: ppa_wu05a3_polygon_diameter
contains
  pure subroutine ppa_wu05a3_polygon_diameter(diameter_max, diameter_min, layer_thickness, &
       polygon_volume, polygon_surface, macro_volume_layer, macro_volume_surface, z1, z, z_diameter_max, &
       diameter, status)
    real(real64), intent(in) :: diameter_max, diameter_min, layer_thickness
    real(real64), intent(in) :: polygon_volume, polygon_surface, macro_volume_layer, macro_volume_surface
    real(real64), intent(in) :: z1, z, z_diameter_max
    real(real64), intent(out) :: diameter
    integer, intent(out) :: status
    real(real64) :: macro_density

    diameter = 0.0_real64
    status = PPA_WU05A3_POLYGON_DIAMETER_INVALID_INPUT
    if (.not. all(ieee_is_finite([diameter_max,diameter_min,layer_thickness,polygon_volume, &
        polygon_surface,macro_volume_layer,macro_volume_surface,z1,z,z_diameter_max]))) return

    ! Source: B1.11 macropore.f90 DiamPolyg (662-695).
    if (diameter_max - diameter_min > 1.0e-3_real64) then
      if (macro_volume_surface > 1.0e-6_real64) then
        if (layer_thickness <= 0.0_real64) return
        macro_density = macro_volume_layer / layer_thickness / macro_volume_surface
      else if (polygon_surface > 1.0e-6_real64) then
        macro_density = polygon_volume / polygon_surface
      else
        if (abs(z1 - z_diameter_max) <= tiny(1.0_real64)) return
        macro_density = max(0.0_real64, 1.0_real64 - ((z1-z)/(z1-z_diameter_max)))
      end if
      diameter = diameter_min + (diameter_max-diameter_min)*(1.0_real64-macro_density)
    else
      diameter = diameter_min
    end if
    if (.not. ieee_is_finite(diameter)) then
      diameter = 0.0_real64
      return
    end if
    status = PPA_WU05A3_POLYGON_DIAMETER_OK
  end subroutine ppa_wu05a3_polygon_diameter
end module mod_ppa_wu05a3_polygon_diameter
