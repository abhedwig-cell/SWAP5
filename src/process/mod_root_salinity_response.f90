module mod_root_salinity_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SALINITY_OK=0, SALINITY_INVALID=1
  public :: evaluate_maas_hoffman_response, evaluate_mobile_root_salinity_sink

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
    if(any(cml_mg_cm3<0.0_real64).or.saltmax_mg_cm3<0.0_real64.or.saltmax_mg_cm3>100.0_real64.or. &
       saltslope_cm3_mg<0.0_real64.or.saltslope_cm3_mg>1.0_real64) return
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

  ! Builds CML and the salinity-reduced water sink from one matching trial
  ! mass/water view. Mass is authoritative (mg/cm2); theta is cm3/cm3 and
  ! dz is cm. The routine owns no state and never changes the supplied sink.
  subroutine evaluate_mobile_root_salinity_sink(mass_mg_cm2,water_content,dz_cm,saltmax_mg_cm3, &
       saltslope_cm3_mg,potential_sink_cm_day,cml_mg_cm3,alpha,salinity_sink_cm_day, &
       node_loss_cm_day,total_loss_cm_day,status)
    real(real64),intent(in)::mass_mg_cm2(:),water_content(:),dz_cm(:),saltmax_mg_cm3,saltslope_cm3_mg
    real(real64),intent(in)::potential_sink_cm_day(:)
    real(real64),allocatable,intent(out)::cml_mg_cm3(:),alpha(:),salinity_sink_cm_day(:),node_loss_cm_day(:)
    real(real64),intent(out)::total_loss_cm_day
    integer,intent(out)::status
    integer::n
    total_loss_cm_day=0.0_real64;status=SALINITY_INVALID
    n=size(mass_mg_cm2)
    if(n<=0.or.size(water_content)/=n.or.size(dz_cm)/=n.or.size(potential_sink_cm_day)/=n)return
    if(.not.all(ieee_is_finite(mass_mg_cm2)).or..not.all(ieee_is_finite(water_content)).or. &
       .not.all(ieee_is_finite(dz_cm)).or..not.all(ieee_is_finite(potential_sink_cm_day)))return
    if(any(mass_mg_cm2<0.0_real64).or.any(water_content<=0.0_real64).or.any(dz_cm<=0.0_real64).or. &
       any(potential_sink_cm_day<0.0_real64))return
    allocate(cml_mg_cm3(n),alpha(n),salinity_sink_cm_day(n),node_loss_cm_day(n))
    cml_mg_cm3=mass_mg_cm2/(water_content*dz_cm)
    if(any(.not.ieee_is_finite(cml_mg_cm3)))goto 900
    call evaluate_maas_hoffman_response(cml_mg_cm3,saltmax_mg_cm3,saltslope_cm3_mg,alpha,status)
    if(status/=SALINITY_OK)goto 900
    salinity_sink_cm_day=potential_sink_cm_day*alpha
    node_loss_cm_day=potential_sink_cm_day-salinity_sink_cm_day
    if(any(.not.ieee_is_finite(salinity_sink_cm_day)).or.any(.not.ieee_is_finite(node_loss_cm_day)))goto 900
    total_loss_cm_day=sum(node_loss_cm_day)
    if(.not.ieee_is_finite(total_loss_cm_day))goto 900
    return
900 continue
    if(allocated(cml_mg_cm3))deallocate(cml_mg_cm3)
    if(allocated(alpha))deallocate(alpha)
    if(allocated(salinity_sink_cm_day))deallocate(salinity_sink_cm_day)
    if(allocated(node_loss_cm_day))deallocate(node_loss_cm_day)
    total_loss_cm_day=0.0_real64;status=SALINITY_INVALID
  end subroutine

end module
