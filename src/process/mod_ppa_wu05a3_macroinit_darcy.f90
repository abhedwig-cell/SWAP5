! PPA-WU05-A3 isolated source oracle for MACROINIT Darcy exchange constants.
! This module does not own or initialize production macropore state.
module mod_ppa_wu05a3_macroinit_darcy
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MACROINIT_DARCY_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MACROINIT_DARCY_INVALID = 1_int32
  public :: ppa_wu05a3_macroinit_darcy

contains

  subroutine ppa_wu05a3_macroinit_darcy(shape_factor, domain_fraction, dz, ksat, &
      polygon_diameter, cdarcy, status)
    real(real64), intent(in) :: shape_factor, domain_fraction, dz, ksat, polygon_diameter
    real(real64), intent(out) :: cdarcy
    integer(int32), intent(out) :: status

    status = PPA_WU05A3_MACROINIT_DARCY_INVALID
    cdarcy = 0.0_real64
    if (.not. all(ieee_is_finite([shape_factor,domain_fraction,dz,ksat,polygon_diameter]))) return
    if (shape_factor < 0.0_real64 .or. domain_fraction < 0.0_real64 .or. &
        domain_fraction > 1.0_real64 .or. dz <= 0.0_real64 .or. ksat < 0.0_real64 .or. &
        polygon_diameter <= 0.0_real64) return

    ! B1.11 MACROINIT section F: CDarcy = ShapeFacMp*8*PpDmCp*DZ*Ksat/DiPoCp**2.
    cdarcy = shape_factor*8.0_real64*domain_fraction*dz*ksat / polygon_diameter**2
    if (.not. ieee_is_finite(cdarcy)) then
      cdarcy = 0.0_real64
      return
    end if
    status = PPA_WU05A3_MACROINIT_DARCY_OK
  end subroutine ppa_wu05a3_macroinit_darcy

end module mod_ppa_wu05a3_macroinit_darcy
