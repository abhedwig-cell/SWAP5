module mod_b111_solute_sorption
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: B111_SORP_OK=0, B111_SORP_INVALID=1, B111_SORP_NOCONV=2
  type, public :: b111_sorption_result_t
    integer :: status=B111_SORP_OK
    real(real64) :: concentration=0.0_real64
    real(real64) :: dissolved_density=0.0_real64
    real(real64) :: sorbed_density=0.0_real64
    real(real64) :: total_density=0.0_real64
    integer :: iterations=0
  end type
  public :: b111_sorption_storage_from_concentration, b111_sorption_partition_total
contains
  pure subroutine b111_sorption_storage_from_concentration(theta,bdens,kf,cref,frexp,c,result)
    real(real64),intent(in)::theta,bdens,kf,cref,frexp,c
    type(b111_sorption_result_t),intent(out)::result
    real(real64)::sorbed
    result=b111_sorption_result_t()
    if(.not.all(ieee_is_finite([theta,bdens,kf,cref,frexp,c])))then
      result%status=B111_SORP_INVALID;return
    end if
    if(theta<0d0.or.bdens<0d0.or.kf<0d0.or.cref<=0d0.or.frexp<=0d0.or.c<0d0)then
      result%status=B111_SORP_INVALID;return
    end if
    sorbed=bdens*kf*cref*(c/cref)**frexp
    result%concentration=c
    result%dissolved_density=theta*c
    result%sorbed_density=sorbed
    result%total_density=result%dissolved_density+sorbed
    if(.not.all(ieee_is_finite([result%dissolved_density,result%sorbed_density,result%total_density])))then
      result=b111_sorption_result_t();result%status=B111_SORP_INVALID;return
    end if
  end subroutine
  subroutine b111_sorption_partition_total(theta,bdens,kf,cref,frexp,total_density,initial_c,result)
    real(real64),intent(in)::theta,bdens,kf,cref,frexp,total_density,initial_c
    type(b111_sorption_result_t),intent(out)::result
    real(real64),parameter::rer=1d-3,vsmall=1d-15
    real(real64)::c,old,dummy,bdenskf
    integer::iter
    result=b111_sorption_result_t()
    if(.not.all(ieee_is_finite([theta,bdens,kf,cref,frexp,total_density,initial_c])))then
      result%status=B111_SORP_INVALID;return
    end if
    if(theta<0d0.or.bdens<0d0.or.kf<0d0.or.cref<=0d0.or.frexp<=0d0.or.total_density<0d0.or.initial_c<0d0)then
      result%status=B111_SORP_INVALID;return
    end if
    if(total_density<vsmall)then
      call b111_sorption_storage_from_concentration(theta,bdens,kf,cref,frexp,0d0,result)
      return
    end if
    bdenskf=bdens*kf
    if(abs(frexp-1d0)<1d-3)then
      if(theta+bdenskf<=0d0)then
        result%status=B111_SORP_INVALID;return
      end if
      c=total_density/(theta+bdenskf)
      call b111_sorption_storage_from_concentration(theta,bdens,kf,cref,frexp,c,result)
      return
    end if
    c=max(initial_c,vsmall)
    do iter=1,100000
      old=c
      dummy=bdenskf*(c/cref)**(frexp-1d0)
      if(theta+dummy<=0d0.or..not.ieee_is_finite(dummy))then
        result%status=B111_SORP_INVALID;return
      end if
      c=total_density/(theta+dummy)
      if(.not.ieee_is_finite(c).or.c<=0d0)then
        result%status=B111_SORP_INVALID;return
      end if
      if(abs(c-old)<rer*c)then
        call b111_sorption_storage_from_concentration(theta,bdens,kf,cref,frexp,c,result)
        result%iterations=iter
        return
      end if
    end do
    result%status=B111_SORP_NOCONV
  end subroutine
end module
