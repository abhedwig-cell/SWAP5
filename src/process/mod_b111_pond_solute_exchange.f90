module mod_b111_pond_solute_exchange
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::B111_POND_SOL_OK=0,B111_POND_SOL_INVALID=1
 type,public::b111_pond_solute_result_t
  integer::status=B111_POND_SOL_OK
  real(real64)::mass_before=0d0
  real(real64)::rain_input=0d0
  real(real64)::irrigation_input=0d0
  real(real64)::pond_concentration=0d0
  real(real64)::soil_transfer=0d0
  real(real64)::mass_after=0d0
  real(real64)::balance_residual=0d0
 end type
 public::evaluate_b111_pond_solute_exchange
contains
 pure subroutine evaluate_b111_pond_solute_exchange(mass_before,rain_rate,rain_c,irr_rate,irr_c, &
      qtop,macropore_area,pond_end,dt,result)
  real(real64),intent(in)::mass_before,rain_rate,rain_c,irr_rate,irr_c,qtop,macropore_area,pond_end,dt
  type(b111_pond_solute_result_t),intent(out)::result
  real(real64)::available,denom,cfluxt
  result=b111_pond_solute_result_t();result%status=B111_POND_SOL_INVALID
  if(.not.all(ieee_is_finite([mass_before,rain_rate,rain_c,irr_rate,irr_c,qtop,macropore_area,pond_end,dt])))return
  if(mass_before<0d0.or.rain_rate<0d0.or.rain_c<0d0.or.irr_rate<0d0.or.irr_c<0d0.or. &
     macropore_area<0d0.or.macropore_area>1d0.or.pond_end<0d0.or.dt<=0d0)return
  result%mass_before=mass_before
  result%rain_input=rain_rate*rain_c*dt
  result%irrigation_input=irr_rate*irr_c*dt
  available=mass_before+result%rain_input+result%irrigation_input
  if(qtop < -1d-6)then
    denom=pond_end-qtop*dt
    if(denom<=0d0)return
    result%pond_concentration=available/denom
    cfluxt=qtop*(1d0-macropore_area)*result%pond_concentration*dt
    result%soil_transfer=-cfluxt
    result%mass_after=available+cfluxt
  else
    result%pond_concentration=0d0
    result%soil_transfer=0d0
    result%mass_after=available
  end if
  if(result%mass_after<0d0.or..not.all(ieee_is_finite([result%pond_concentration,result%soil_transfer,result%mass_after])))return
  result%balance_residual=result%mass_after+result%soil_transfer-available
  result%status=B111_POND_SOL_OK
 end subroutine
end module
