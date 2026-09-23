module mod_ppa_irr_water_deficit
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  public :: evaluate_root_zone_water_deficit

contains

  pure subroutine evaluate_root_zone_water_deficit(noddrz, layer, dz, ztopcp, rd, wclos, wcmes, wchis, wcac, &
                                                   awlh, awmh, awah, cdef)
    integer, intent(in) :: noddrz
    integer, intent(in) :: layer(:)
    real(real64), intent(in) :: dz(:), ztopcp(:), rd
    real(real64), intent(in) :: wclos(:), wcmes(:), wchis(:), wcac(:)
    real(real64), intent(out) :: awlh, awmh, awah, cdef
    real(real64) :: frlow, wclo, wcme, wchi, wcactual
    integer :: node

    frlow = (ztopcp(noddrz) + rd) / dz(noddrz)
    awlh = 0.0_real64
    awmh = 0.0_real64
    awah = 0.0_real64
    cdef = 0.0_real64
    do node = 1, noddrz
      wclo = wclos(layer(node)) * dz(node)
      if (node == noddrz) wclo = wclo * frlow
      wcme = wcmes(layer(node)) * dz(node)
      if (node == noddrz) wcme = wcme * frlow
      wchi = wchis(layer(node)) * dz(node)
      if (node == noddrz) wchi = wchi * frlow
      wcactual = wcac(node) * dz(node)
      if (node == noddrz) wcactual = wcactual * frlow
      awlh = awlh + (wclo - wchi)
      awmh = awmh + (wcme - wchi)
      awah = awah + (wcactual - wchi)
      cdef = cdef + (wclo - wcactual)
    end do
  end subroutine evaluate_root_zone_water_deficit

end module mod_ppa_irr_water_deficit
