module mod_b111_age_pond_exchange
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer,parameter,public::B111_AGE_POND_OK=0
  integer,parameter,public::B111_AGE_POND_INVALID=1

  type,public::b111_age_pond_result_t
    integer::status=B111_AGE_POND_INVALID
    real(real64)::pond_age_concentration=0.0_real64
    real(real64)::pond_age_amount_after=0.0_real64
    real(real64)::soil_age_transfer=0.0_real64
    real(real64)::rain_age_input=0.0_real64
    real(real64)::irrigation_age_input=0.0_real64
  end type

  public::evaluate_b111_age_pond_exchange

contains

  pure subroutine evaluate_b111_age_pond_exchange(committed_pond_age_amount,rain_rate,rain_age, &
       irrigation_rate,irrigation_age,qtop,macropore_area,pond_end,dt,result)
    real(real64),intent(in)::committed_pond_age_amount
    real(real64),intent(in)::rain_rate,rain_age,irrigation_rate,irrigation_age
    real(real64),intent(in)::qtop,macropore_area,pond_end,dt
    type(b111_age_pond_result_t),intent(out)::result
    real(real64)::available,denom

    result=b111_age_pond_result_t()
    if(.not.all(ieee_is_finite([committed_pond_age_amount,rain_rate,rain_age,irrigation_rate, &
       irrigation_age,qtop,macropore_area,pond_end,dt])))return
    if(committed_pond_age_amount<0.0_real64.or.rain_rate<0.0_real64.or.rain_age<0.0_real64.or. &
       irrigation_rate<0.0_real64.or.irrigation_age<0.0_real64.or.macropore_area<0.0_real64.or. &
       macropore_area>1.0_real64.or.pond_end<0.0_real64.or.dt<=0.0_real64)return

    result%rain_age_input=rain_rate*rain_age*dt
    result%irrigation_age_input=irrigation_rate*irrigation_age*dt
    available=committed_pond_age_amount+result%rain_age_input+result%irrigation_age_input

    if(qtop < -1.0e-6_real64)then
      denom=pond_end-qtop*dt
      if(denom<=0.0_real64)return
      result%pond_age_concentration=available/denom
      result%soil_age_transfer=-qtop*(1.0_real64-macropore_area)*result%pond_age_concentration*dt
      result%pond_age_amount_after=available-result%soil_age_transfer
      if(result%pond_age_amount_after<0.0_real64.and.abs(result%pond_age_amount_after)<= &
         1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,available))result%pond_age_amount_after=0.0_real64
      if(result%pond_age_amount_after<0.0_real64)return
    else
      ! Literal AgeTracer resets Agepond to zero outside the infiltration branch.
      result%pond_age_concentration=0.0_real64
      result%soil_age_transfer=0.0_real64
      result%pond_age_amount_after=0.0_real64
    end if

    if(.not.all(ieee_is_finite([result%pond_age_concentration,result%soil_age_transfer, &
       result%pond_age_amount_after,result%rain_age_input,result%irrigation_age_input])))return
    result%status=B111_AGE_POND_OK
  end subroutine
end module
