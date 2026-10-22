module mod_crop_fixed_phenology
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: FIXED_CROP_OK=0, FIXED_CROP_INVALID=1
  type, public :: fixed_crop_parameters_t
    integer :: development_mode=0, cycle_days=0
    real(real64) :: emergence_anthesis_degree_days=0d0, anthesis_maturity_degree_days=0d0
    real(real64) :: base_temperature_c=0d0
  end type
  type, public :: fixed_crop_state_t
    logical :: initialized=.false.
    integer :: completed_days=0
    real(real64) :: development_stage=0d0, temperature_sum_degree_days=0d0
  end type
  public :: initialize_fixed_crop, propose_fixed_crop_day
contains
  pure logical function valid_parameters(p) result(ok)
    type(fixed_crop_parameters_t),intent(in)::p
    ok=.false.
    if(.not.all(ieee_is_finite([p%base_temperature_c,p%emergence_anthesis_degree_days, &
      p%anthesis_maturity_degree_days])))return
    if(p%base_temperature_c< -10d0.or.p%base_temperature_c>30d0)return
    select case(p%development_mode)
    case(1)
      if(p%cycle_days<1.or.p%cycle_days>366)return
    case(2)
      ! The original zero denominators are outside executable science.
      if(p%emergence_anthesis_degree_days<=0d0.or.p%emergence_anthesis_degree_days>1d4)return
      if(p%anthesis_maturity_degree_days<=0d0.or.p%anthesis_maturity_degree_days>1d4)return
    case default
      return
    end select
    ok=.true.
  end function

  pure subroutine initialize_fixed_crop(p,state,status)
    type(fixed_crop_parameters_t),intent(in)::p
    type(fixed_crop_state_t),intent(out)::state
    integer,intent(out)::status
    state=fixed_crop_state_t();status=FIXED_CROP_INVALID
    if(.not.valid_parameters(p))return
    state%initialized=.true.;status=FIXED_CROP_OK
  end subroutine

  ! One biological day event, independent of hydraulic solver substeps.
  ! Caller owns commit. Rejection returns an empty candidate and never changes
  ! the input state. B1.11 fixed.f90 update_cropfixed supplies both equations.
  pure subroutine propose_fixed_crop_day(p,committed,mean_air_temperature_c,candidate,status)
    type(fixed_crop_parameters_t),intent(in)::p
    type(fixed_crop_state_t),intent(in)::committed
    real(real64),intent(in)::mean_air_temperature_c
    type(fixed_crop_state_t),intent(out)::candidate
    integer,intent(out)::status
    real(real64)::dtsum,dvr,denominator
    candidate=fixed_crop_state_t();status=FIXED_CROP_INVALID
    if(.not.valid_parameters(p).or..not.committed%initialized)return
    if(committed%completed_days<0.or.committed%completed_days>=100000)return
    if(.not.all(ieee_is_finite([committed%development_stage,committed%temperature_sum_degree_days, &
      mean_air_temperature_c])))return
    if(committed%development_stage<0d0.or.committed%development_stage>2d0)return
    if(committed%temperature_sum_degree_days<0d0.or.committed%temperature_sum_degree_days>1d10)return
    if(abs(mean_air_temperature_c)>1d5)return
    dtsum=max(0d0,mean_air_temperature_c-p%base_temperature_c)
    if(committed%temperature_sum_degree_days>1d10-dtsum)return
    if(p%development_mode==1)then
      dvr=2d0/real(p%cycle_days,real64)
    else
      denominator=p%anthesis_maturity_degree_days
      if(committed%development_stage<1d0)denominator=p%emergence_anthesis_degree_days
      ! Only increments below two can affect min(DVS+dvr,2). Avoid overflow
      ! for a positive subnormal denominator without changing that result.
      if(dtsum>=2d0*denominator)then
        dvr=2d0
      else
        dvr=dtsum/denominator
      end if
    end if
    candidate=committed
    candidate%development_stage=min(committed%development_stage+dvr,2d0)
    candidate%temperature_sum_degree_days=committed%temperature_sum_degree_days+dtsum
    candidate%completed_days=committed%completed_days+1
    status=FIXED_CROP_OK
  end subroutine
end module
