module mod_crop_b111_germination_sum_candidate
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: B111_SUM_OK=0, B111_SUM_INVALID=1
  public :: b111_germination_sum_candidate
contains
  ! Exact daily temperature-sum arithmetic from B1.11 MOD_cropdevelopment.f90
  ! germination task=3 (lines 755-777). This is pure, untrusted candidate
  ! arithmetic, not meteorological certification or event publication.
  subroutine b111_germination_sum_candidate(tav,tbasem,teffmx,tsumemeopt, &
       tsumemesub,previous_sum,new_sum,germinated,dvs,status)
    real(real64), intent(in) :: tav,tbasem,teffmx,tsumemeopt,tsumemesub,previous_sum
    real(real64), intent(out) :: new_sum,dvs
    logical, intent(out) :: germinated
    integer, intent(out) :: status
    new_sum=previous_sum;dvs=0.0_real64;germinated=.false.;status=B111_SUM_INVALID
    if (.not.all(ieee_is_finite([tav,tbasem,teffmx,tsumemeopt,tsumemesub,previous_sum]))) return
    if (tsumemeopt<=0.0_real64.or.teffmx<=tbasem.or.previous_sum<0.0_real64) return
    if (tav>tbasem) then
      if (tav<teffmx) then
        if (tsumemesub<0.1_real64) then
          new_sum=previous_sum+(tav-tbasem)
        else
          new_sum=previous_sum+(tsumemeopt/tsumemesub)*(tav-tbasem)
        end if
      else
        if (tsumemesub<0.1_real64) then
          new_sum=previous_sum+(teffmx-tbasem)
        else
          new_sum=previous_sum+(tsumemeopt/tsumemesub)*(teffmx-tbasem)
        end if
      end if
    end if
    if (.not.ieee_is_finite(new_sum)) then
      new_sum=previous_sum;return
    end if
    germinated=new_sum>=tsumemeopt
    if (.not.germinated) then
      dvs=-0.1_real64*max(1.0_real64-(new_sum/tsumemeopt),0.0_real64)
    else
      dvs=0.0_real64
    end if
    status=B111_SUM_OK
  end subroutine
end module
