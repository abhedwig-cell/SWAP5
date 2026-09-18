program test_hupsel_swcf2_pmdirect_daily
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pmdirect_swetr0_process
  implicit none
  real(real64),parameter::tol=1d-12
  call check(227,20370000d0,9.1d0,23.2d0,1.1493d0,4.17d0,0d0,67.904761904761884d0,3.8691959409102386d0, &
    0.94508105761722561d0,0.19d0,205.8d0,0d0,0.021039381230798154d0,0.023947155536827004d0, &
    0.36989155956560815d0,0.11806407365914319d0,0.53714123774061084d0)
  call check(15,1710000d0,0.2d0,5.8d0,0.706437d0,5.33d0,0.56d0,12d0,0.7420000000000001d0, &
    0.28387460881418058d0,0.23d0,79.1d0,0d0,0.008694520223257186d0,0.02230865944195139d0, &
    0.011621209174202582d0,0.0047014973566050335d0,0.010184502512019959d0)
  call check(289,7730000d0,7.5d0,14d0,0.987604d0,2.67d0,0.47d0,12d0,2.2434682834446562d0, &
    0.63562099391997362d0,0.23d0,79.1d0,0d0,0.028500468106518691d0,0.040972914017102416d0, &
    0.0818009159111939d0,0.03749398442638522d0,0.052357843735008791d0)
  print '(A)','F-APP05_HUPSEL_SWCF2_PMDIRECT_DAILY_PASS'
contains
  subroutine check(doy,rad,tmin,tmax,hum,wind,rain,ch,lai,vcover,alb,rsc,rsw,peva,epond,pdry,pwet,eintc)
    integer,intent(in)::doy
    real(real64),intent(in)::rad,tmin,tmax,hum,wind,rain,ch,lai,vcover,alb,rsc,rsw,peva,epond,pdry,pwet,eintc
    type(pmdirect_swetr0_weather_t)::w
    type(pmdirect_swetr0_site_t)::s
    type(pmdirect_swetr0_canopy_t)::c
    type(pmdirect_swetr0_daily_result_t)::r
    type(pmdirect_swetr0_diagnostics_t)::d
    w%day_of_year=doy;w%radiation_j_m2_d=rad;w%minimum_air_temperature_c=tmin;w%maximum_air_temperature_c=tmax
    w%vapour_pressure_kpa=hum;w%wind_speed_m_s=wind;w%gross_rain_cm_d=rain
    s%latitude_degrees=52d0;s%altitude_m=10d0;s%wind_measurement_height_m=10d0;s%humidity_measurement_height_m=1.5d0
    s%angstrom_a=0.25d0;s%angstrom_b=0.5d0;s%wind_function_factor=1d0;s%soil_surface_resistance_s_m=600d0
    c%crop_emerged=.true.;c%use_crop_height_for_aerodynamics=.true.;c%crop_height_cm=ch;c%lai=lai
    c%vegetation_cover_fraction=vcover;c%albedo=alb;c%dry_canopy_resistance_s_m=rsc;c%wet_canopy_resistance_s_m=rsw
    c%co2_transpiration_factor=1d0
    call evaluate_pmdirect_swetr0_daily(w,s,c,r,d)
    if(d%status/=PMDIRECT_SWETR0_OK.or..not.d%daily_result_produced) error stop 1
    if(abs(r%potential_soil_evaporation_cm_per_day-peva)>tol) error stop 2
    if(abs(r%potential_pond_evaporation_cm_per_day-epond)>tol) error stop 3
    if(abs(r%potential_transpiration_dry_cm_per_day-pdry)>tol) error stop 4
    if(abs(r%potential_transpiration_wet_cm_per_day-pwet)>tol) error stop 5
    if(abs(r%interception_evaporation_capacity_cm_per_day-eintc)>tol) error stop 6
  end subroutine
end program
