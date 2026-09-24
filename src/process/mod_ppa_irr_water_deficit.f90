module mod_ppa_irr_water_deficit
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  public :: evaluate_root_zone_water_deficit
  public :: evaluate_root_zone_water_deficit_checked
  integer, parameter, public :: IRR_DEFICIT_OK=0, IRR_DEFICIT_INVALID_INPUT=1

contains

  pure subroutine evaluate_root_zone_water_deficit_checked(noddrz, layer, dz, ztopcp, rd, &
       wclos, wcmes, wchis, wcac, awlh, awmh, awah, cdef, status)
    integer, intent(in) :: noddrz, layer(:)
    real(real64), intent(in) :: dz(:), ztopcp(:), rd, wclos(:), wcmes(:), wchis(:), wcac(:)
    real(real64), intent(out) :: awlh, awmh, awah, cdef
    integer, intent(out) :: status
    integer :: node, soil
    real(real64) :: rooted_length

    awlh=0.0_real64; awmh=0.0_real64; awah=0.0_real64; cdef=0.0_real64
    status=IRR_DEFICIT_INVALID_INPUT
    if (noddrz<1) return
    if (size(layer)<noddrz.or.size(dz)<noddrz.or.size(ztopcp)<noddrz.or.size(wcac)<noddrz) return
    if (.not.ieee_is_finite(rd)) return
    if (rd<0.0_real64.or.rd>1.0e6_real64) return
    do node=1,noddrz
      soil=layer(node)
      if (soil<1) return
      if (soil>size(wclos).or.soil>size(wcmes).or.soil>size(wchis)) return
      if (.not.ieee_is_finite(dz(node)).or..not.ieee_is_finite(ztopcp(node))) return
      if (dz(node)<=0.0_real64.or.dz(node)>1.0e6_real64.or.abs(ztopcp(node))>1.0e6_real64) return
      if (.not.valid_content(wcac(node))) return
      if (.not.valid_content(wclos(soil)).or..not.valid_content(wcmes(soil))) return
      if (.not.valid_content(wchis(soil))) return
    end do
    rooted_length=ztopcp(noddrz)+rd
    if (rooted_length<0.0_real64.or.rooted_length>dz(noddrz)) return
    call evaluate_root_zone_water_deficit(noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis,wcac, &
         awlh,awmh,awah,cdef)
    status=IRR_DEFICIT_OK
  end subroutine evaluate_root_zone_water_deficit_checked

  pure logical function valid_content(value)
    real(real64), intent(in) :: value
    valid_content=.false.
    if (.not.ieee_is_finite(value)) return
    valid_content=value>=0.0_real64.and.value<=1.0_real64
  end function valid_content

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
