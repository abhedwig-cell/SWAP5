program co2_contract
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_crop_atmospheric_co2_forcing
  use mod_crop_co2_response_resolver
  use mod_swap_daily_weather_file_adapter,only:swap_weather_calendar_day
  implicit none
  type(crop_atmospheric_co2_forcing_t)::forcing,bad
  type(crop_co2_response_parameters_t)::p,off
  type(crop_co2_response_t)::r
  real(real64)::eff(6),amax(6),tra(6),expected(3),ppm,nan
  integer::i,s
  interface
    subroutine b111_co2_response(co2,eff,amax,tra,factors)
      import real64
      real(real64),intent(in)::co2,eff(6),amax(6),tra(6)
      real(real64),intent(out)::factors(3)
    end subroutine
  end interface
  eff=[300._real64,.8_real64,500._real64,1.1_real64,900._real64,1.4_real64]
  amax=[350._real64,.9_real64,550._real64,1.3_real64,1000._real64,1.6_real64]
  tra=[250._real64,1.0_real64,450._real64,.9_real64,800._real64,.7_real64]
  call construct_crop_co2_response_parameters(eff(1::2),eff(2::2),amax(1::2),amax(2::2), &
    tra(1::2),tra(2::2),.true.,p,s)
  if(s/=CROP_CO2_RESPONSE_OK)error stop 'response parameters'
  do i=10,3000
    ppm=real(i,real64)
    call b111_co2_response(ppm,eff,amax,tra,expected)
    call evaluate_crop_co2_response(p,ppm,r,s)
    if(s/=CROP_CO2_RESPONSE_OK)error stop 'valid response'
    if(maxval(abs([r%efficiency_factor,r%amax_factor,r%transpiration_factor]-expected))>1.e-14_real64) &
      error stop 'literal three independent source tables'
  end do
  call construct_crop_atmospheric_co2_forcing([1999,2000,2002],[400._real64,600._real64,800._real64],forcing,s)
  if(s/=CROP_ATMOSPHERIC_CO2_OK.or..not.forcing%ready())error stop 'annual constructor'
  call forcing%resolve(swap_weather_calendar_day(1999,12,31),ppm,s)
  if(s/=CROP_ATMOSPHERIC_CO2_OK.or.ppm/=400)error stop 'previous source year'
  call forcing%resolve(swap_weather_calendar_day(2000,1,1),ppm,s)
  if(s/=CROP_ATMOSPHERIC_CO2_OK.or.ppm/=600)error stop 'new source year'
  call forcing%resolve(swap_weather_calendar_day(2000,2,29),ppm,s)
  if(s/=CROP_ATMOSPHERIC_CO2_OK.or.ppm/=600)error stop 'leap year'
  call forcing%resolve(swap_weather_calendar_day(2001,1,1),ppm,s)
  if(s/=CROP_ATMOSPHERIC_CO2_MISSING_YEAR.or.ppm/=0)error stop 'no interpolation of missing year'
  call forcing%resolve(swap_weather_calendar_day(2002,1,1),ppm,s)
  if(s/=CROP_ATMOSPHERIC_CO2_OK.or.ppm/=800)error stop 'A B A missing-year nonmutation'
  call forcing%resolve(0,ppm,s)
  if(s/=CROP_ATMOSPHERIC_CO2_MISSING_YEAR.or.ppm/=0)error stop 'invalid ordinal'
  call construct_crop_atmospheric_co2_forcing([1999,1999],[400._real64,600._real64],bad,s)
  if(s/=CROP_ATMOSPHERIC_CO2_INVALID.or.bad%ready())error stop 'duplicate year'
  call construct_crop_atmospheric_co2_forcing([2000,1999],[400._real64,600._real64],bad,s)
  if(s/=CROP_ATMOSPHERIC_CO2_INVALID.or.bad%ready())error stop 'unsorted years'
  call construct_crop_atmospheric_co2_forcing([999],[400._real64],bad,s)
  if(s/=CROP_ATMOSPHERIC_CO2_INVALID.or.bad%ready())error stop 'historical year domain'
  call construct_crop_atmospheric_co2_forcing([1999],[9._real64],bad,s)
  if(s/=CROP_ATMOSPHERIC_CO2_INVALID.or.bad%ready())error stop 'historical ppm domain'
  call construct_crop_atmospheric_co2_forcing([1999],[3001._real64],bad,s)
  if(s/=CROP_ATMOSPHERIC_CO2_INVALID.or.bad%ready())error stop 'upper ppm domain'
  nan=ieee_value(0._real64,ieee_quiet_nan)
  call construct_crop_atmospheric_co2_forcing([1999],[nan],bad,s)
  if(s/=CROP_ATMOSPHERIC_CO2_INVALID.or.bad%ready())error stop 'NaN ppm'
  call construct_crop_atmospheric_co2_forcing([integer::],[real(real64)::],bad,s)
  if(s/=CROP_ATMOSPHERIC_CO2_INVALID.or.bad%ready())error stop 'empty forcing'
  call construct_crop_co2_response_parameters([1._real64],[1._real64],[1._real64],[1._real64], &
    [1._real64],[1._real64],.false.,off,s)
  call evaluate_crop_co2_response(off,nan,r,s)
  if(s/=CROP_CO2_RESPONSE_OK.or.r%efficiency_factor/=1.or.r%amax_factor/=1.or.r%transpiration_factor/=1) &
    error stop 'OFF has no atmospheric dependency'
  print '(a)','CO2_LITERAL_SOURCE_CASES=2991'
  print '(a)','CO2_ANNUAL_SOURCE_CONTRACT=PASS'
end program
