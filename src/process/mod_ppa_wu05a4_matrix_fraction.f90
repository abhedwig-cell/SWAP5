! B1.11 macropore.f90 initialisation: FrArMtrx = 1 - VlMpStCp / Dz.
! Input is STATIC pore volume, never total static + dynamic crack volume.
module mod_ppa_wu05a4_matrix_fraction
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  public::static_matrix_fraction
contains
  pure subroutine static_matrix_fraction(static_volume,dz,fraction,ok)
    real(real64),intent(in)::static_volume(:),dz(:)
    real(real64),allocatable,intent(out)::fraction(:)
    logical,intent(out)::ok
    ok=.false.
    if(size(dz)<1.or.size(static_volume)/=size(dz))return
    if(.not.all(ieee_is_finite(dz)).or..not.all(ieee_is_finite(static_volume)))return
    if(any(dz<=0).or.any(static_volume<0).or.any(static_volume>dz))return
    fraction=1.0_real64-static_volume/dz
    ok=.true.
  end subroutine
end module
