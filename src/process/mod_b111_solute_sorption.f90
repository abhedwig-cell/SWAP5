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
    real(real64),parameter::vsmall=1d-15
    real(real64)::c,lo,hi,bdenskf,scale
    type(b111_sorption_result_t)::probe
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
    ! Legacy fixed-point stopping at rer=1e-3 is not a mass-closure
    ! certificate. Solve the monotone Freundlich storage relation with a
    ! bracket so that dissolved+sorbed equals total within roundoff.
    lo=0d0
    hi=max(initial_c,total_density/max(theta+bdenskf,vsmall),vsmall)
    do iter=1,1024
      call b111_sorption_storage_from_concentration(theta,bdens,kf,cref,frexp,hi,probe)
      if(probe%status/=B111_SORP_OK)then
        result%status=B111_SORP_INVALID;return
      end if
      if(probe%total_density>=total_density)exit
      if(hi>=huge(hi)/2d0)then
        result%status=B111_SORP_NOCONV;return
      end if
      hi=hi*2d0
    end do
    if(probe%total_density<total_density)then
      result%status=B111_SORP_NOCONV;return
    end if
    scale=max(1d0,abs(total_density))
    do iter=1,256
      c=lo+0.5d0*(hi-lo)
      call b111_sorption_storage_from_concentration(theta,bdens,kf,cref,frexp,c,probe)
      if(probe%status/=B111_SORP_OK)then
        result%status=B111_SORP_INVALID;return
      end if
      if(abs(probe%total_density-total_density)<=32d0*epsilon(1d0)*scale)then
        result=probe
        result%iterations=iter
        return
      end if
      if(probe%total_density>total_density)then
        hi=c
      else
        lo=c
      end if
      if(hi<=lo.or.c==lo.or.c==hi)exit
    end do
    result%status=B111_SORP_NOCONV
  end subroutine
end module
