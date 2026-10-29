program duration_interception_driver
 use iso_fortran_env,only:real64
 use mod_pmdirect_swetr0_process
 use MOD_meteo,only:interception_daily,ProcessMeteoDT,fl_update_meteo,rainflx,rain_rec,fprecnosnow, &
   grai,swevap,ptra_dry,ptra_wet,eintc,aintc,aintcdt,nraidt,ptra,wfrac
 use MOD_swap_base,only:swrain,swmetdetail
 use plant_interface,only:lai,cofab,vcover,sw_inter
 use MOD_irrigation,only:gird,isua
 use MOD_snow,only:gsnow,ssnow
 implicit none
 type(pmdirect_swetr0_weather_t)::weather
 type(pmdirect_swetr0_canopy_t)::canopy
 type(pmdirect_swetr0_daily_result_t)::daily
 type(pmdirect_swetr0_interval_result_t)::actual
 type(pmdirect_swetr0_diagnostics_t)::diagnostic
 real(real64)::intensity,error,largest
 integer::i,j,count
 allocate(rainflx(1));largest=0d0;count=0
 do i=1,6
  weather%day_of_year=1;weather%gross_rain_cm_d=.58d0
  weather%minimum_air_temperature_c=-.8d0;weather%maximum_air_temperature_c=2.3d0
  canopy%crop_emerged=.true.;canopy%lai=.973d0;canopy%cofab_cm=.5d0
  canopy%vegetation_cover_fraction=1d0-exp(-.75d0*.6d0*canopy%lai)
  daily%potential_transpiration_dry_cm_per_day=.02d0
  daily%potential_transpiration_wet_cm_per_day=.005d0
  daily%interception_evaporation_capacity_cm_per_day=.01d0
  if(i==2)weather%gross_rain_cm_d=.06d0
  if(i==3)weather%gross_rain_cm_d=0d0
  if(i==4)canopy%lai=0d0
  if(i==5)daily%interception_evaporation_capacity_cm_per_day=.00099d0
  if(i==6)weather%gross_rain_cm_d=1d-7
  grai=weather%gross_rain_cm_d;lai=canopy%lai;cofab=canopy%cofab_cm;vcover=canopy%vegetation_cover_fraction
  sw_inter=1;swmetdetail=0;swevap=0;isua=0;gird=0d0;gsnow=0d0;ssnow=0d0
  ptra_dry=daily%potential_transpiration_dry_cm_per_day;ptra_wet=daily%potential_transpiration_wet_cm_per_day
  eintc=daily%interception_evaporation_capacity_cm_per_day
  call interception_daily()
  do j=1,3
   swrain=2;intensity=weather%gross_rain_cm_d/.092d0
   if(j==2)intensity=0d0
   if(j==3)then
    swrain=0;intensity=weather%gross_rain_cm_d
   end if
   rainflx(1)=intensity;rain_rec=1;fprecnosnow=1d0;fl_update_meteo=.false.
   call ProcessMeteoDT()
   diagnostic=pmdirect_swetr0_diagnostics_t();diagnostic%daily_result_produced=.true.
   call apply_swinter1_duration_interval(weather,canopy,daily,intensity,actual,diagnostic)
   if(diagnostic%status/=0.or..not.diagnostic%interval_result_produced)error stop 'new duration interface'
   error=maxval(abs([nraidt,aintcdt,ptra,wfrac]-[actual%net_rain_cm_per_day,actual%interception_rate_cm_per_day, &
     actual%potential_transpiration_cm_per_day,actual%wet_canopy_fraction]))
   largest=max(largest,error);count=count+1
   if(error/=0d0)then
    print *,i,j,error,[nraidt,aintcdt,ptra,wfrac]
    print *,actual
    error stop 'original ProcessMeteoDT differential'
   end if
  end do
 end do
 call apply_swinter1_duration_interval(weather,canopy,daily,-1d0,actual,diagnostic)
 if(diagnostic%status==0.or.diagnostic%interval_result_produced)error stop 'invalid interval rate'
 write(*,*)'ORIGINAL_DURATION_INTERCEPTION_PASS',count,largest
end program
