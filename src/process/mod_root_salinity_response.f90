module mod_root_salinity_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SALINITY_OK=0, SALINITY_INVALID=1
  public :: evaluate_maas_hoffman_response

contains

  ! Maas-Hoffman node response for the historical SWSALINITY=1 family.
  ! CML and SALTMAX are mg/cm3; SALTSLOPE is cm3/mg; alpha is dimensionless.
  ! This function owns no concentration, salt mass, water sink, or state.
  subroutine evaluate_maas_hoffman_response(cml_mg_cm3,saltmax_mg_cm3,saltslope_cm3_mg,alpha,status)
    real(real64), intent(in) :: cml_mg_cm3(:),saltmax_mg_cm3,saltslope_cm3_mg
    real(real64), intent(out) :: alpha(:)
    integer, intent(out) :: status
    integer :: i

    alpha=0.0_real64;status=SALINITY_INVALID
    if(size(cml_mg_cm3)==0.or.size(alpha)/=size(cml_mg_cm3)) return
    if(.not.all(ieee_is_finite(cml_mg_cm3)).or. &
       .not.all(ieee_is_finite([saltmax_mg_cm3,saltslope_cm3_mg]))) return
    if(any(cml_mg_cm3<0.0_real64).or.saltmax_mg_cm3<0.0_real64.or.saltslope_cm3_mg<0.0_real64) return
    do i=1,size(cml_mg_cm3)
      if(cml_mg_cm3(i)<=saltmax_mg_cm3.or.saltslope_cm3_mg<=0.0_real64) then
        alpha(i)=1.0_real64
      else
        ! Branch before subtraction and multiplication keeps the lower bound
        ! explicit and avoids relying on a later arbitrary clamp.
        if(cml_mg_cm3(i)-saltmax_mg_cm3>=1.0_real64/saltslope_cm3_mg) then
          alpha(i)=0.0_real64
        else
          alpha(i)=1.0_real64-(cml_mg_cm3(i)-saltmax_mg_cm3)*saltslope_cm3_mg
        end if
      end if
    end do
    status=SALINITY_OK
  end subroutine

end module
