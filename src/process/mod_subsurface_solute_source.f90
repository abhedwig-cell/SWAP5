module mod_subsurface_solute_source
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: SUBSOL_OK=0, SUBSOL_INVALID=1, SUBSOL_SHAPE=2, SUBSOL_OVERFLOW=3
  public :: evaluate_subsurface_solute_source
contains
  ! Water allocation belongs to the irrigation/water owner. Each supplied node
  ! rate is used literally, including original per-compartment interval delivery.
  ! This pure source evaluation owns no transport, state, clock or restart data.
  ! mg/cm2 = (cm/day)*(mg/cm3)*day; bulk increment is mg/cm3 soil.
  ! Outputs are candidate-local and remain untouched on every refused request.
  pure subroutine evaluate_subsurface_solute_source(water_rate_cm_day, concentration_mg_cm3, &
      thickness_cm, interval_day, mass_input_mg_cm2, bulk_increment_mg_cm3, total_input_mg_cm2, status)
    real(real64), intent(in) :: water_rate_cm_day(:), concentration_mg_cm3, thickness_cm(:), interval_day
    real(real64), intent(inout) :: mass_input_mg_cm2(:), bulk_increment_mg_cm3(:), total_input_mg_cm2
    integer, intent(out) :: status
    real(real64) :: amounts(size(water_rate_cm_day)), increments(size(water_rate_cm_day))
    real(real64) :: rate, amount, total, bound
    integer :: n, i

    status=SUBSOL_SHAPE
    n=size(water_rate_cm_day)
    if(n<1.or.size(thickness_cm)/=n.or.size(mass_input_mg_cm2)/=n.or.size(bulk_increment_mg_cm3)/=n)return
    status=SUBSOL_INVALID
    ! Keep finite checks separate from comparisons: invalid IEEE arguments must
    ! be refused even under the original checked floating-point trap policy.
    if(.not.all(ieee_is_finite(water_rate_cm_day)))return
    if(.not.all(ieee_is_finite(thickness_cm)))return
    if(.not.ieee_is_finite(concentration_mg_cm3))return
    if(.not.ieee_is_finite(interval_day))return
    if(any(water_rate_cm_day<0.0_real64).or.any(thickness_cm<=0.0_real64))return
    if(concentration_mg_cm3<0.0_real64.or.interval_day<=0.0_real64)return

    status=SUBSOL_OVERFLOW
    total=0.0_real64
    bound=huge(1.0_real64)
    do i=1,n
      ! Test before each operation, so a rejected extreme input cannot trap or
      ! partially publish candidate outputs. No finite physical value is clipped.
      if(concentration_mg_cm3>1.0_real64)then
        if(water_rate_cm_day(i)>bound/concentration_mg_cm3)return
      end if
      rate=water_rate_cm_day(i)*concentration_mg_cm3
      if(interval_day>1.0_real64)then
        if(rate>bound/interval_day)return
      end if
      amount=rate*interval_day
      if(thickness_cm(i)<1.0_real64)then
        if(amount>bound*thickness_cm(i))return
      end if
      increments(i)=amount/thickness_cm(i)
      if(amount>bound-total)return
      total=total+amount
      amounts(i)=amount
    end do
    mass_input_mg_cm2=amounts
    bulk_increment_mg_cm3=increments
    total_input_mg_cm2=total
    status=SUBSOL_OK
  end subroutine evaluate_subsurface_solute_source
end module mod_subsurface_solute_source
